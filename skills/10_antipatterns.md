# 10 — Anti-Patterns & Common Mistakes

> ⚠️ Load this file for EVERY contract generation task. These are the most
> common ways FHEVM contracts silently fail, produce wrong results, or create
> security vulnerabilities.

---

## 🔴 CRITICAL — Will Cause Revert or Security Hole

### AP-01: Missing `FHE.allowThis()` After Mutation

**The #1 most common bug.** Every time you write a new value to an encrypted
state variable, the coprocessor loses ACL access unless you re-grant it.

❌ Wrong:
```solidity
_balance = FHE.add(_balance, amount);
// _balance handle has NO ACL — next read/operation will revert!
```

✅ Correct:
```solidity
_balance = FHE.add(_balance, amount);
FHE.allowThis(_balance);  // always call after every mutation
```

---

### AP-02: Not Inheriting `ZamaEthereumConfig`

Without this, all FHE operations revert on live networks (Sepolia, mainnet).

❌ Wrong:
```solidity
contract MyToken {   // missing ZamaEthereumConfig
    function transfer(...) { FHE.add(...); }  // reverts on Sepolia
}
```

✅ Correct:
```solidity
contract MyToken is ZamaEthereumConfig {
    ...
}
```

---

### AP-03: Accepting User `euint*` Without Proof Verification

Accepting raw encrypted handles from users without ZK proof allows attackers
to replay another user's ciphertext.

❌ Wrong (unsafe):
```solidity
function deposit(euint64 amount) external { ... }
```

✅ Correct (proof-verified):
```solidity
function deposit(externalEuint64 encAmount, bytes calldata inputProof) external {
    euint64 amount = FHE.fromExternal(encAmount, inputProof);
    ...
}
```

---

### AP-04: Returning Encrypted Handle from `view` as Meaningful Data

A `view` function CAN return a `euint64` handle — this is fine for the
re-encryption flow. But you CANNOT decode it on the frontend by casting to uint.
The handle is NOT the value.

❌ Wrong (misleading frontend code):
```typescript
const balance = await contract.balanceOf(user);  // returns handle, not value!
console.log("Balance:", balance.toString());       // prints garbage handle number
```

✅ Correct:
```typescript
const encHandle = await contract.balanceOf(user);
const balance = await fhevm.reencrypt(encHandle, privateKey, publicKey, sig, contractAddr, user);
console.log("Balance:", balance);  // actual decrypted value
```

---

### AP-05: Using `if (ebool)` Directly

`ebool` is an encrypted boolean handle. You cannot branch on it in Solidity.

❌ Wrong:
```solidity
ebool isValid = FHE.ge(amount, _minimum);
if (isValid) { ... }  // COMPILE ERROR — ebool is not bool
```

✅ Correct — use `FHE.select()`:
```solidity
ebool isValid = FHE.ge(amount, _minimum);
_result = FHE.select(isValid, computedValue, _result);  // conditional without branching
```

---

### AP-06: Using `==` on Encrypted Types

Solidity's `==` doesn't work on `euint*` or `ebool`.

❌ Wrong:
```solidity
if (_balance == 0) { ... }           // COMPILE ERROR
require(_voteOption == euint8(1));   // COMPILE ERROR
```

✅ Correct:
```solidity
ebool isZero = FHE.eq(_balance, FHE.asEuint64(0));
_result = FHE.select(isZero, fallbackValue, computedValue);
```

---

### AP-07: Emitting Encrypted Values in Events (Privacy Leak)

Emitting a decrypted value in an event leaks it publicly on-chain forever.

❌ Wrong:
```solidity
emit Transfer(from, to, decryptedAmount);  // permanent public record!
```

✅ Correct — emit handle or zero-information event:
```solidity
emit Transfer(from, to);  // just signal that a transfer happened
// Amount stays private — user decrypts their own balance via re-encryption
```

---

### AP-08: Storing `externalEuint*` in State

External input types are for function parameters only. They cannot be stored.

❌ Wrong:
```solidity
mapping(address => externalEuint64) public balances;  // WRONG TYPE
```

✅ Correct:
```solidity
mapping(address => euint64) private _balances;  // store the handle
```

---

## 🟡 LOGIC ERRORS — Produce Wrong Results

### AP-09: Forgetting `FHE.allow(handle, user)` for Re-encryption

If you don't grant a user ACL access to their own value, they get a "not
authorised" error when trying to re-encrypt from the frontend.

❌ Missing allow:
```solidity
_balances[user] = FHE.add(_balances[user], amount);
FHE.allowThis(_balances[user]);
// user cannot decrypt their own balance!
```

✅ Add user access:
```solidity
_balances[user] = FHE.add(_balances[user], amount);
FHE.allowThis(_balances[user]);
FHE.allow(_balances[user], user);  // user can now re-encrypt
```

---

### AP-10: Silent Overflow on Small Types

`euint8` overflows at 255 with no revert. Plan your type sizes.

❌ Risky:
```solidity
euint8 voteCount = FHE.add(_votes, FHE.asEuint8(1));  // wraps at 255!
```

✅ Use an appropriate type:
```solidity
euint32 voteCount = FHE.add(_votes, FHE.asEuint32(1));  // safe for millions of votes
```

---

### AP-11: Using `FHE.div()` with an Encrypted Divisor

`FHE.div()` and `FHE.rem()` ONLY work with plaintext (non-encrypted) divisors.
Encrypted divisors are not supported by the protocol.

❌ Wrong:
```solidity
euint64 result = FHE.div(amount, encDivisor);  // NOT SUPPORTED — reverts
```

✅ Correct:
```solidity
euint64 result = FHE.div(amount, 100);  // plaintext divisor only
```

---

### AP-12: Uninitialized Encrypted Variable

Reading an uninitialized `euint*` returns the zero ciphertext handle, but
using it in operations before explicit initialization can create subtle bugs.

✅ Always initialize:
```solidity
if (!FHE.isInitialized(_balance)) {
    _balance = FHE.asEuint64(0);
    FHE.allowThis(_balance);
}
```

---

### AP-13: Not Validating Public Decrypt Callback Caller

The public decryption callback can be called by anyone if you don't restrict it.

❌ Wrong:
```solidity
function onDecrypted(uint64 value) external {
    _result = value;  // anyone can call this!
}
```

✅ Correct:
```solidity
address constant GATEWAY = 0x...; // KMS Gateway address for this network

function onDecrypted(uint64 value) external {
    require(msg.sender == GATEWAY, "Only gateway");
    _result = value;
}
```

---

### AP-14: Chaining Operations Without Intermediate `allowThis`

When chaining multiple operations where the result of one becomes input to the
next AND you need to persist the intermediate value, grant ACL at each step.

```solidity
// If _fee and _netAmount are stored state vars:
_fee = FHE.div(amount, 100);
FHE.allowThis(_fee);             // persist fee

_netAmount = FHE.sub(amount, _fee);
FHE.allowThis(_netAmount);       // persist net

// If only the final result is stored, you only need one allowThis:
euint64 fee = FHE.div(amount, 100);      // temp — no allowThis needed
_netAmount = FHE.sub(amount, fee);       // final stored value
FHE.allowThis(_netAmount);               // only this needs it
```

---

## 🟢 BEST PRACTICES CHECKLIST

Before finalising any FHEVM contract, verify:

- [ ] Contract inherits `ZamaEthereumConfig`
- [ ] Every encrypted state write is followed by `FHE.allowThis()`
- [ ] All user-facing balances/values have `FHE.allow(handle, user)`
- [ ] All function parameters use `externalEuint*` + `bytes inputProof`
- [ ] No `euint*` accepted directly from users without proof
- [ ] No `if (ebool)` — all conditional logic uses `FHE.select()`
- [ ] No `==`, `<`, `>` on encrypted types — use `FHE.eq()`, `FHE.lt()`, etc.
- [ ] No decrypted values in events
- [ ] Public decrypt callbacks validate `msg.sender == GATEWAY`
- [ ] Type sizes chosen to prevent overflow (prefer `euint64` for balances)
- [ ] `FHE.isInitialized()` guard on variables read before potential first write
- [ ] `FHE.div()` / `FHE.rem()` only use plaintext divisors

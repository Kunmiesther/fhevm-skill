# 05 — Input Proofs

## What Is an Input Proof?

When a user encrypts a value client-side (using `fhevmjs`) and sends it to a
contract, they must include a **Zero-Knowledge Proof of Knowledge (ZKPoK)** that
proves two things:

1. The encrypted value was produced by **`msg.sender`** (prevents stolen ciphertext attacks)
2. The ciphertext is **bound to `address(this)`** — it can only be consumed by the
   intended contract (prevents replay across contracts)

Without proof verification, an attacker could reuse another user's encrypted input.

## Solidity Pattern

Every function that accepts encrypted user input needs TWO parameters:

```solidity
function deposit(externalEuint64 encAmount, bytes calldata inputProof) external {
    // Verify proof and unwrap to a usable euint64 handle
    euint64 amount = FHE.fromExternal(encAmount, inputProof);

    _balances[msg.sender] = FHE.add(_balances[msg.sender], amount);
    FHE.allowThis(_balances[msg.sender]);
    FHE.allow(_balances[msg.sender], msg.sender);
}
```

`FHE.fromExternal()` does the proof verification internally. If the proof is
invalid (wrong sender, wrong contract, tampered ciphertext), the call reverts.

## Multiple Encrypted Inputs

Each encrypted input needs its own proof. If a function takes multiple encrypted
arguments, use a single combined `inputProof` — fhevmjs bundles them:

```solidity
function swapTokens(
    externalEuint64 encAmountA,
    externalEuint64 encAmountB,
    bytes calldata inputProof   // one proof covers all encrypted inputs in this call
) external {
    euint64 amountA = FHE.fromExternal(encAmountA, inputProof);
    euint64 amountB = FHE.fromExternal(encAmountB, inputProof);
    // ...
}
```

## Client-Side Proof Generation (fhevmjs)

```typescript
import { createInstance } from "fhevmjs";

const fhevm = await createInstance({ network: window.ethereum });

// Generate encrypted input + proof for a specific contract
const input = await fhevm.createEncryptedInput(contractAddress, userAddress);
input.add64(transferAmount);          // add a euint64 value
const { handles, inputProof } = await input.encrypt();

// handles[0] is the externalEuint64 to pass as first param
// inputProof is the bytes proof
await contract.transfer(recipientAddress, handles[0], inputProof);
```

## Proof Binding Details

The proof binds the ciphertext to:
- `contractAddress` — the contract that will consume it
- `userAddress` — the `msg.sender` who is calling

If you call `FHE.fromExternal()` with a proof bound to a different contract or
a different sender, it reverts. This is enforced by the InputVerifier contract.

## Common Mistakes

❌ Accepting `euint64` directly from users (no proof):
```solidity
function badDeposit(euint64 amount) external { ... }  // UNSAFE
```

✅ Always use the external type + proof pattern:
```solidity
function goodDeposit(externalEuint64 encAmount, bytes calldata proof) external {
    euint64 amount = FHE.fromExternal(encAmount, proof);
    ...
}
```

❌ Storing the external type instead of converting:
```solidity
externalEuint64 private _stored; // WRONG — external types are for input only
```

✅ Convert immediately, store the handle:
```solidity
euint64 private _stored;
function setValue(externalEuint64 enc, bytes calldata proof) external {
    _stored = FHE.fromExternal(enc, proof);  // convert at entry point
    FHE.allowThis(_stored);
}
```

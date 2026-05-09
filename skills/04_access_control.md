# 04 — Access Control (ACL)

## Overview

FHEVM enforces a blockchain-based Access Control List (ACL). Every ciphertext
handle has a list of addresses that are allowed to use or decrypt it.
**If an address is not in the ACL for a handle, any operation using that handle
will revert.**

## The Four ACL Functions

### `FHE.allowThis(handle)`
Grants the **current contract** (`address(this)`) persistent access to the handle.
Call after every operation that produces or mutates a stored encrypted value.

```solidity
_balance = FHE.add(_balance, amount);
FHE.allowThis(_balance);  // MUST call this — #1 most forgotten line
```

### `FHE.allow(handle, address)`
Grants a **specific address** persistent access. Use to allow a user to decrypt
their own value, or allow another contract to operate on a handle.

```solidity
FHE.allow(_balances[user], user);          // user can now decrypt their balance
FHE.allow(_encryptedVote, owner);          // owner can tally votes
FHE.allow(_encryptedResult, otherContract); // cross-contract composability
```

### `FHE.allowTransient(handle, address)`
Grants **temporary** access that expires at the end of the current transaction.
Use for values that should only be usable within the scope of one call.

```solidity
// Pattern: pass encrypted value to another contract within same tx
FHE.allowTransient(encryptedAmount, address(swapContract));
swapContract.executeSwap(encryptedAmount);
// After tx ends, swapContract can no longer use this handle
```

### `FHE.isSenderAllowed(handle)`
Validates that `msg.sender` has ACL access to a handle. Use as a guard when
a function accepts a handle from an external caller.

```solidity
function operateOn(euint64 handle) external {
    FHE.isSenderAllowed(handle);  // reverts if msg.sender not in ACL
    // ... proceed safely
}
```

## Complete ACL Pattern for Token Transfers

```solidity
function transfer(address to, externalEuint64 encAmount, bytes calldata proof) external {
    euint64 amount = FHE.fromExternal(encAmount, proof);

    // Sender must have ACL access to their own balance
    FHE.isSenderAllowed(_balances[msg.sender]);

    // Perform encrypted subtraction / addition
    ebool hasEnough = FHE.ge(_balances[msg.sender], amount);
    _balances[msg.sender] = FHE.select(hasEnough, FHE.sub(_balances[msg.sender], amount), _balances[msg.sender]);
    _balances[to]         = FHE.select(hasEnough, FHE.add(_balances[to], amount), _balances[to]);

    // Grant persistent access to updated handles
    FHE.allowThis(_balances[msg.sender]);
    FHE.allowThis(_balances[to]);
    FHE.allow(_balances[msg.sender], msg.sender); // sender can decrypt their new balance
    FHE.allow(_balances[to], to);                 // recipient can decrypt their new balance
}
```

## `FHE.makePubliclyDecryptable(handle)`

Permanently marks a handle as publicly decryptable — anyone can request its
decryption via the gateway. Use for values you want to reveal unconditionally
(e.g. auction results, voting tallies once voting ends).

```solidity
FHE.makePubliclyDecryptable(_finalTally);
```

Check status with `FHE.isPubliclyDecryptable(handle)`.

## ACL Inheritance Across Operations

When you compute `c = FHE.add(a, b)`, the result `c` does NOT inherit ACL
from `a` or `b`. You must explicitly call `FHE.allowThis(c)` on the result.

❌ This is a silent bug:
```solidity
_balance = FHE.add(_balance, deposit);
// _balance now has NO ACL — next operation will revert!
```

✅ Correct:
```solidity
_balance = FHE.add(_balance, deposit);
FHE.allowThis(_balance);
```

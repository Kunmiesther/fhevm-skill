# 02 — Encrypted Types

## Storage Types (in contract state)

| Type | Plaintext equivalent | Bit width | Notes |
|------|---------------------|-----------|-------|
| `ebool` | bool | 1 | Encrypted boolean — use `FHE.select()`, never `if (ebool)` |
| `euint8` | uint8 | 8 | 0–255; overflow wraps silently |
| `euint16` | uint16 | 16 | |
| `euint32` | uint32 | 32 | |
| `euint64` | uint64 | 64 | Standard for token balances (ERC-7984) |
| `euint128` | uint128 | 128 | |
| `euint256` | uint256 | 256 | |
| `eaddress` | address | 160 | |

## External Input Types (function parameters only)

These are the types you use in function signatures when accepting user-encrypted input.
They must ALWAYS be paired with a `bytes calldata inputProof` argument.

```
externalEbool
externalEuint8 / externalEuint16 / externalEuint32 / externalEuint64
externalEuint128 / externalEuint256
externalEaddress
```

**Converting external → storage type:**
```solidity
euint64 value = FHE.fromExternal(externalInput, inputProof);
```

## Type Casting

```solidity
// Plaintext → encrypted
euint64 enc = FHE.asEuint64(100);          // uint64 literal
euint32 enc = FHE.asEuint32(someUint32);   // runtime value
ebool   enc = FHE.asEbool(true);
eaddress enc = FHE.asEaddress(someAddr);

// Between encrypted types (upcasting/downcasting)
euint64 big   = FHE.asEuint64(smallEuint32);  // upcast — always safe
euint32 small = FHE.asEuint32(bigEuint64);    // downcast — truncates silently!

// Encrypted integer → encrypted boolean
ebool isNonZero = FHE.asEbool(someEuint32);   // true if value != 0
```

## Initialization Check

Always check if an encrypted variable has been set before using it:

```solidity
if (!FHE.isInitialized(_encryptedBalance)) {
    _encryptedBalance = FHE.asEuint64(0);
}
```

Uninitialized encrypted variables default to the zero ciphertext, but reading
them before initialization can produce unexpected behaviour. Use
`FHE.isInitialized()` as a guard.

## Import Pattern

```solidity
import {
    FHE,
    euint8, euint16, euint32, euint64, euint128, euint256,
    ebool,
    eaddress,
    externalEuint8, externalEuint16, externalEuint32, externalEuint64,
    externalEuint128, externalEuint256,
    externalEbool,
    externalEaddress
} from "@fhevm/solidity/lib/FHE.sol";
```

## Common Mistake

❌ Wrong — comparing encrypted value to plaintext with `==`:
```solidity
if (_encryptedBalance == 0) { ... }  // COMPILE ERROR
```

✅ Correct — use `FHE.eq()` which returns `ebool`, then use `FHE.select()`:
```solidity
ebool isZero = FHE.eq(_encryptedBalance, FHE.asEuint64(0));
euint64 result = FHE.select(isZero, FHE.asEuint64(defaultVal), _encryptedBalance);
```

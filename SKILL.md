---
name: fhevm
description: >
  Production-ready skill for AI coding agents to build, test, and deploy
  confidential smart contracts using the Zama FHEVM protocol. Drop this file
  into Claude Code, Cursor, Windsurf, or any AI coding tool and agents will
  produce correct, working FHEVM code from natural-language prompts — no
  cryptography knowledge required.
version: 1.0.0
fhevm_library: "@fhevm/solidity"
solidity: "^0.8.24"
hardhat_plugin: "@fhevm/hardhat-plugin"
docs: "https://docs.zama.org/protocol"
---

# FHEVM Skill — AI Agent Reference

## How to Use This Skill

This skill is structured as a **modular reference suite**. Load the sections
relevant to your task. When in doubt, load all of them.

| File | Load when you need to… |
|------|------------------------|
| `SKILL.md` (this file) | Get oriented, understand architecture |
| `skills/01_architecture.md` | Explain FHE, coprocessors, symbolic execution |
| `skills/02_encrypted_types.md` | Use `euint*`, `ebool`, `eaddress`, external input types |
| `skills/03_operations.md` | Arithmetic, comparison, bitwise, conditional (`FHE.select`) |
| `skills/04_access_control.md` | `FHE.allow`, `FHE.allowThis`, `FHE.allowTransient`, ACL patterns |
| `skills/05_input_proofs.md` | Validate encrypted user input on-chain |
| `skills/06_decryption.md` | User decrypt (EIP-712) and public decrypt flows |
| `skills/07_testing.md` | Hardhat mock mode, local node, Sepolia testnet |
| `skills/08_frontend.md` | `fhevmjs` encrypt/decrypt in React/Next.js |
| `skills/09_erc7984.md` | Confidential token standard — full implementation |
| `skills/10_antipatterns.md` | ⚠️ CRITICAL — load this for every contract task |
| `templates/` | Ready-to-use contract templates |
| `examples/` | Deploy scripts, test suites, frontend integration |

---

## Quick Architecture Summary

```
User (browser)
  │  encrypts value with fhevmjs  ──► externalEuintXX + inputProof
  │
  ▼
Smart Contract (Solidity on Ethereum/Sepolia)
  │  FHE.fromExternal(input, proof) → euintXX handle
  │  FHE operations (add, sub, eq…) → new handles
  │  FHE.allowThis(handle) — contract can re-encrypt later
  │  FHE.allow(handle, user) — user can decrypt
  │
  ▼
FHEVM Coprocessor Network
  │  Intercepts FHE operation events
  │  Executes real FHE computation off-chain
  │  Stores ciphertext (handle → ciphertext mapping)
  │
  ▼
KMS Gateway (decryption oracle)
  │  User-triggered: EIP-712 signature → re-encrypt for user pubkey
  │  Public-triggered: FHE.requestDecryption → callback to contract
  │
  ▼
User / Contract receives plaintext
```

**Key mental model:** Handles on-chain are *pointers* to ciphertexts.
All actual FHE math happens in coprocessors. The chain never sees plaintext.

---

## Minimal Contract Skeleton

```solidity
// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import { FHE, euint64, externalEuint64, ebool } from "@fhevm/solidity/lib/FHE.sol";
import { ZamaEthereumConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract MyConfidentialContract is ZamaEthereumConfig {
    euint64 private _encryptedValue;

    constructor() {
        // ZamaEthereumConfig wires up coprocessor + KMS addresses automatically
    }

    /// @dev Accept encrypted input from user with ZK proof
    function setValue(externalEuint64 encInput, bytes calldata inputProof) external {
        euint64 newVal = FHE.fromExternal(encInput, inputProof);
        _encryptedValue = newVal;
        FHE.allowThis(_encryptedValue);   // contract retains access
        FHE.allow(_encryptedValue, msg.sender); // sender can decrypt
    }
}
```

---

## The 5 Rules Every FHEVM Contract Must Follow

1. **Inherit `ZamaEthereumConfig`** — without it, FHE calls revert on Sepolia/mainnet.
2. **Call `FHE.allowThis()` after every mutation** — the coprocessor needs persistent
   access to re-encrypt. Forgetting this is the #1 bug.
3. **Use `FHE.fromExternal(input, proof)` for all user inputs** — never trust raw
   user-supplied encrypted values without proof verification.
4. **Never return `euint*` from `view` functions** — handles are meaningless to callers.
   Use user-decryption or public-decryption flows instead.
5. **Use `FHE.select()` for branching on encrypted conditions** — never use `if (ebool)`
   directly; booleans are encrypted handles too.

---

## Package Installation

```bash
# Contracts
npm install @fhevm/solidity

# Hardhat development
npm install --save-dev @fhevm/hardhat-plugin

# Frontend
npm install fhevmjs
```

---

## Prompt Engineering Tips (for developers using this skill)

When prompting your AI agent with this skill loaded, be specific:

- ✅ "Write a confidential voting contract using FHEVM where votes are euint8"
- ✅ "Add public decryption callback to reveal the auction winner after deadline"
- ✅ "Write a Hardhat test for the transfer function using mock FHE"
- ❌ "Add privacy" (too vague — agent won't know which pattern to apply)
- ❌ "Decrypt the balance" (specify: user-decrypt via EIP-712, or public decrypt via callback)

---

## Real-World Example: Sentra Protocol

This skill was validated by building **Sentra Protocol** — a production
application deployed on Ethereum for confidential proof-of-solvency.

> Prove solvency to any counterparty without revealing your balance sheet.
> Encrypted financials. Auditor-attested. Mathematically verified.

- **Live app:** https://sentra-protocol.vercel.app
- **Source:** https://github.com/Kunmiesther/Sentra-Protocol

### FHEVM patterns used in production:

```solidity
// Encrypted balance sheet — assets and liabilities never visible on-chain
euint64 encryptedAssets;
euint64 encryptedLiabilities;

// Auditor gets explicit ACL access — no one else can read these handles
FHE.allow(assets, auditor);
FHE.allow(liabilities, auditor);

// Solvency check: assets >= liabilities — result is encrypted ebool
ebool encResult = FHE.le(encryptedLiabilities, encryptedAssets);
FHE.allow(encResult, msg.sender); // entity can decrypt their own result
```

This demonstrates the skill enabling a complete production dApp — from
encrypted inputs, through FHE computation, to auditor-gated decryption.

---

## Real-World Example: Sentra Protocol

This skill was validated by building **Sentra Protocol** — a production
application deployed on Ethereum for confidential proof-of-solvency.

> Prove solvency to any counterparty without revealing your balance sheet.
> Encrypted financials. Auditor-attested. Mathematically verified.

- **Live app:** https://sentra-protocol.vercel.app
- **Source:** https://github.com/Kunmiesther/Sentra-Protocol

### FHEVM patterns used in production:

```solidity
// Encrypted balance sheet — assets and liabilities never visible on-chain
euint64 encryptedAssets;
euint64 encryptedLiabilities;

// Auditor gets explicit ACL access — no one else can read these handles
FHE.allow(assets, auditor);
FHE.allow(liabilities, auditor);

// Solvency check: assets >= liabilities — result is encrypted ebool
ebool encResult = FHE.le(encryptedLiabilities, encryptedAssets);
FHE.allow(encResult, msg.sender); // entity can decrypt their own result
```

This demonstrates the skill enabling a complete production dApp — from
encrypted inputs, through FHE computation, to auditor-gated decryption.

# 01 — FHEVM Architecture

## What Is FHE?

Fully Homomorphic Encryption (FHE) lets you compute on encrypted data without
decrypting it first. The result is still encrypted and produces the same output
as computing on plaintext. The blockchain never sees raw values.

## How FHEVM Works On-Chain

FHEVM uses **symbolic execution**: when a contract calls an FHE operation, the
host chain does NOT do any cryptographic computation. Instead it:

1. Produces a **handle** (a uint256 pointer to the ciphertext result)
2. Emits an event
3. The coprocessor network picks up the event, performs real FHE computation
   off-chain, and stores the resulting ciphertext

This means:
- The host chain is never slowed by FHE
- FHE operations can be parallelised
- Handles can be chained immediately without waiting for coprocessors

## Component Map

| Component | Role |
|-----------|------|
| **FHEVM Solidity Library** | Provides `FHE.*` functions, encrypted types |
| **Coprocessor Network** | Executes FHE operations; stores ciphertexts |
| **KMS (Key Management System)** | Holds split decryption keys via MPC |
| **Gateway / Decryption Oracle** | Routes decryption requests; returns re-encrypted values |
| **ACL Contract** | On-chain access control list for ciphertext handles |
| **InputVerifier** | Validates ZK proofs bundled with user inputs |

## Network Support (May 2026)

- **Ethereum Sepolia** — testnet with real encryption ✅
- **Ethereum Mainnet** — live ✅
- **Other EVM chains** — H1 2026 roadmap

## ZamaEthereumConfig

Every contract MUST inherit this. It wires up coprocessor address, KMS address,
ACL address, and InputVerifier automatically for the target network.

```solidity
import { ZamaEthereumConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract MyContract is ZamaEthereumConfig {
    // constructor calls FHE.setCoprocessor(...) internally
}
```

Without this, all FHE calls will revert on live networks.

## Security Properties

- **Quantum-resistant** — underlying TFHE scheme is post-quantum secure
- **MPC-based decryption** — no single party can decrypt; requires threshold of
  KMS operators
- **Binding proofs** — user inputs include ZK proofs binding the ciphertext to
  `msg.sender` and `address(this)`, preventing replay attacks

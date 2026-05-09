# 🔐 FHEVM Skill — AI Agent Reference for Confidential Smart Contracts

![FHEVM](https://img.shields.io/badge/FHEVM-Zama%20Protocol-6C3CE1?style=for-the-badge&logo=ethereum&logoColor=white)
![Solidity](https://img.shields.io/badge/Solidity-0.8.27-363636?style=for-the-badge&logo=solidity&logoColor=white)
![Tests](https://img.shields.io/badge/Tests-14%20Passing-22c55e?style=for-the-badge&logo=checkmarx&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

> **Drop these files into Claude Code, Cursor, or Windsurf — and your AI agent will write correct, production-ready FHEVM contracts from natural language prompts. No cryptography knowledge required.**

---

## 🧠 What Is This?

AI coding agents are becoming the primary way developers write smart contracts. But today, no agent has built-in knowledge of Fully Homomorphic Encryption or FHEVM.

This skill bridges that gap.

Load `SKILL.md` into your AI coding environment, and prompts like:

- *"Write me a confidential voting contract using FHEVM"*
- *"How do I build a confidential ERC-7984 token?"*
- *"Add auditor access to my encrypted balance sheet"*

...will produce **correct, working, deployable code** — not hallucinated garbage.

---

## ✅ Validated In Production

This skill was built and battle-tested while building **[Sentra Protocol](https://sentra-protocol.vercel.app)** — a live application on Ethereum that enables confidential proof-of-solvency.

> Prove solvency to any counterparty without revealing your balance sheet.
> Encrypted financials. Auditor-attested. Mathematically verified.

Every pattern in this skill reflects real code that compiles, deploys, and works.

---

## 📁 File Structure

```
fhevm-skill/
├── SKILL.md                      ← Load this first — master router for agents
│
├── skills/
│   ├── 01_architecture.md        ← How FHE works on-chain, coprocessors, KMS
│   ├── 02_encrypted_types.md     ← euint8/16/32/64, ebool, eaddress reference
│   ├── 03_operations.md          ← Arithmetic, comparison, FHE.select()
│   ├── 04_access_control.md      ← allowThis, allow, allowTransient, ACL
│   ├── 05_input_proofs.md        ← ZK proof validation, fromExternal pattern
│   ├── 06_decryption.md          ← User decrypt (EIP-712) + public decrypt
│   ├── 07_testing.md             ← Hardhat mock mode, test helpers, Sepolia
│   ├── 08_frontend.md            ← fhevmjs, React hooks, EIP-712 signing
│   ├── 09_erc7984.md             ← Confidential token standard, wrap/unwrap
│   └── 10_antipatterns.md        ← ⚠️ 17 documented bugs and how to fix them
│
├── contracts/
│   ├── ConfidentialVoting.sol    ← Encrypted votes, public tally reveal
│   ├── ConfidentialERC20.sol     ← ERC-7984 confidential token
│   └── ConfidentialAuction.sol   ← Blind auction with encrypted bids
│
└── test/
    └── test-suite.ts             ← 14 passing Hardhat tests
```

---

## 🚀 How to Use With Your AI Agent

### Claude Code
```bash
# In your project root, tell Claude to load the skill
claude "Read SKILL.md and all files in skills/, then write me a confidential token contract"
```

Or add to `CLAUDE.md`:
```
Load SKILL.md and all files in skills/ before writing any FHEVM contract.
```

### Cursor / Windsurf
Add `SKILL.md` and the `skills/` folder to your project root. The agent will index them automatically. Reference them explicitly in your prompt:
```
Using the FHEVM skill files in this project, write a confidential voting contract...
```

---

## 📚 Topics Covered

![Architecture](https://img.shields.io/badge/FHE%20Architecture-6C3CE1?style=flat-square)
![Encrypted Types](https://img.shields.io/badge/Encrypted%20Types-0ea5e9?style=flat-square)
![Operations](https://img.shields.io/badge/FHE%20Operations-0ea5e9?style=flat-square)
![ACL](https://img.shields.io/badge/Access%20Control-0ea5e9?style=flat-square)
![Input Proofs](https://img.shields.io/badge/Input%20Proofs-0ea5e9?style=flat-square)
![Decryption](https://img.shields.io/badge/Decryption%20Patterns-0ea5e9?style=flat-square)
![Testing](https://img.shields.io/badge/Testing-22c55e?style=flat-square)
![Frontend](https://img.shields.io/badge/Frontend%20Integration-22c55e?style=flat-square)
![ERC-7984](https://img.shields.io/badge/ERC--7984-f59e0b?style=flat-square)
![Anti-patterns](https://img.shields.io/badge/17%20Anti--patterns-ef4444?style=flat-square)

---

## ⚠️ The Anti-Patterns File

`skills/10_antipatterns.md` is the most important file in this repo.

It documents **17 real bugs** discovered while building with FHEVM — the kind of mistakes that don't throw obvious errors but silently break your contract or create security holes. Things like:

- Missing `FHE.allowThis()` after every mutation (the #1 bug)
- Using `if (ebool)` directly instead of `FHE.select()`
- Calling `FHE.div()` with an encrypted divisor (not supported)
- Wrong ERC-7984 function names (`confidentialBalanceOf`, not `balanceOf`)
- Wrong import path for `FhevmType` in Hardhat tests

None of these are in the official docs. They were found by running real code.

---

## 🧪 Running the Tests

```bash
# Install dependencies
npm install

# Compile
npx hardhat compile

# Run all tests (mock FHE — fast, no Sepolia needed)
npx hardhat test
```

Expected output:
```
ConfidentialERC20
  ✔ should deploy with correct metadata
  ✔ owner can mint encrypted tokens
  ✔ non-owner cannot mint
  ✔ should transfer confidentially between accounts
  ✔ should not allow transfer exceeding balance

ConfidentialVoting
  ✔ should allow casting encrypted votes
  ✔ should prevent double voting
  ✔ should track vote status correctly

ConfidentialAuction
  ✔ should accept encrypted bids
  ✔ bidder can see their own encrypted bid
  ✔ should reject bids after deadline

14 passing
```

---

## 🔗 Resources

| Resource | Link |
|----------|------|
| Zama Protocol Docs | https://docs.zama.org/protocol |
| FHEVM Hardhat Template | https://github.com/zama-ai/fhevm-hardhat-template |
| OpenZeppelin Confidential Contracts | https://github.com/OpenZeppelin/openzeppelin-confidential-contracts |
| fhevmjs | https://github.com/zama-ai/fhevmjs |
| Sentra Protocol (live demo) | https://sentra-protocol.vercel.app |

---

## 👤 Author

Built by **Estar Kunmi** for the Zama Builders Program S2 — Bounty Track.

![Zama](https://img.shields.io/badge/Zama%20Builders%20Program-S2-6C3CE1?style=for-the-badge)

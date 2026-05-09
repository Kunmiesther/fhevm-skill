# 06 — Decryption Patterns

There are two decryption flows in FHEVM. Choose based on who receives the plaintext.

---

## Pattern A: User Decryption (Re-encryption via EIP-712)

Use when: **a specific user** needs to read their own encrypted value (e.g. their balance).

The value is re-encrypted for the user's keypair by the KMS Gateway and sent
back to the frontend. No plaintext ever appears on-chain.

### Contract Side
No special contract code needed. Just ensure the user has ACL access:

```solidity
FHE.allow(_balances[msg.sender], msg.sender);
```

### Frontend Side (fhevmjs)

```typescript
import { createInstance } from "fhevmjs";

const fhevm = await createInstance({ network: window.ethereum });

// 1. Generate a keypair for this session
const { publicKey, privateKey } = fhevm.generateKeypair();

// 2. Create EIP-712 signature request
const eip712 = fhevm.createEIP712(publicKey, contractAddress);
const signature = await signer.signTypedData(
    eip712.domain,
    { Reencrypt: eip712.types.Reencrypt },
    eip712.message
);

// 3. Re-encrypt — KMS re-encrypts balance under user's publicKey
const balanceHandle = await contract.getEncryptedBalance(userAddress);
const decryptedBalance = await fhevm.reencrypt(
    balanceHandle,
    privateKey,
    publicKey,
    signature,
    contractAddress,
    userAddress
);

console.log("My balance:", decryptedBalance);
```

### Contract helper for re-encryption

```solidity
/// @notice Returns the encrypted balance handle — caller must have ACL access
function getEncryptedBalance(address user) external view returns (euint64) {
    return _balances[user];
}
```

> ⚠️ Do NOT try to return a decrypted uint64 from a view function.
> The contract cannot decrypt — only the KMS can, via the re-encryption flow above.

---

## Pattern B: Public Decryption (Callback to Contract)

Use when: the **contract itself** needs to act on a decrypted value (e.g. reveal
auction winner, tally votes, trigger conditional logic based on decrypted result).

This is asynchronous. The contract requests decryption, the KMS Gateway
processes it, then calls back a function on your contract with the plaintext.

### Contract Implementation

```solidity
// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import { FHE, euint64 } from "@fhevm/solidity/lib/FHE.sol";
import { ZamaEthereumConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract AuctionExample is ZamaEthereumConfig {
    euint64 private _highestBid;
    address public winner;
    uint64  public winningAmount;
    bool    public auctionEnded;

    // Step 1: Request public decryption
    function finalizeAuction() external {
        require(block.timestamp > auctionDeadline, "Auction still live");
        require(!auctionEnded, "Already finalized");

        // Request gateway to decrypt — msg.value can be used for oracle fee
        FHE.requestDecryption(_highestBid, this.receiveDecryptedBid.selector);
    }

    // Step 2: Gateway calls this callback with the plaintext result
    // MUST be external and match the selector passed to requestDecryption
    function receiveDecryptedBid(uint64 decryptedBid) external {
        // ⚠️ Only the Gateway (decryption oracle) should call this
        // In production add: require(msg.sender == GATEWAY_ADDRESS)
        winningAmount = decryptedBid;
        auctionEnded  = true;
    }
}
```

### Key Rules for Public Decryption

1. **Callback function must be `external`** — the Gateway calls it like any tx
2. **Callback receives plaintext** — `uint64`, `uint32`, `bool`, `address`, etc. (not `euint*`)
3. **Add gateway access control** — only the KMS Gateway should call the callback
4. **Non-deterministic timing** — decryption takes multiple blocks; design
   contract state accordingly
5. **One decryption per `requestDecryption` call** — for multiple values, make
   multiple calls or use a struct

---

## Decision Tree: Which Decryption to Use?

```
Does a USER need to see the value in their frontend?
  └─ YES → Pattern A (re-encryption / EIP-712)
       └─ FHE.allow(handle, userAddress) in contract
          fhevm.reencrypt() on frontend

Does the CONTRACT need to act on the decrypted value?
  └─ YES → Pattern B (public decryption callback)
       └─ FHE.requestDecryption(handle, callbackSelector) in contract
          Wait for Gateway callback tx

Does EVERYONE need to see the value (e.g. final vote tally)?
  └─ YES → Pattern B (public decryption callback)
       └─ Store result in public state after callback
          Optionally: FHE.makePubliclyDecryptable(handle) first
```

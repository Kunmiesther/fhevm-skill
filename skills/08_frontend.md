# 08 — Frontend Integration (fhevmjs)

## Installation

```bash
npm install fhevmjs
```

## Initialise the FHEVM Instance

```typescript
import { createInstance, type FhevmInstance } from "fhevmjs";

let fhevm: FhevmInstance;

export async function getFhevmInstance(): Promise<FhevmInstance> {
    if (!fhevm) {
        fhevm = await createInstance({
            network: window.ethereum,           // MetaMask / any EIP-1193 provider
            // For custom RPC: kmsContractAddress, aclContractAddress can be specified
        });
    }
    return fhevm;
}
```

## Encrypting User Input (Sending to Contract)

```typescript
import { ethers } from "ethers";
import { getFhevmInstance } from "./fhevm";

async function encryptedTransfer(
    contract: ethers.Contract,
    contractAddress: string,
    signer: ethers.Signer,
    recipient: string,
    amount: bigint
) {
    const fhevm = await getFhevmInstance();
    const userAddress = await signer.getAddress();

    // Create input bound to this contract + this user
    const input = await fhevm.createEncryptedInput(contractAddress, userAddress);
    input.add64(amount);
    const { handles, inputProof } = await input.encrypt();

    // Send transaction — handles[0] is externalEuint64, inputProof is bytes
    const tx = await contract.connect(signer).transfer(recipient, handles[0], inputProof);
    await tx.wait();
    console.log("Confidential transfer sent:", tx.hash);
}
```

## Decrypting User's Own Value (Re-encryption)

```typescript
async function getMyBalance(
    contract: ethers.Contract,
    contractAddress: string,
    signer: ethers.Signer
): Promise<bigint> {
    const fhevm = await getFhevmInstance();
    const userAddress = await signer.getAddress();

    // 1. Generate ephemeral keypair for this re-encryption session
    const { publicKey, privateKey } = fhevm.generateKeypair();

    // 2. Sign the re-encryption request (EIP-712)
    const eip712 = fhevm.createEIP712(publicKey, contractAddress);
    const signature = await signer.signTypedData(
        eip712.domain,
        { Reencrypt: eip712.types.Reencrypt },
        eip712.message
    );

    // 3. Fetch the encrypted handle from contract
    const encHandle = await contract.getEncryptedBalance(userAddress);

    // 4. Ask KMS to re-encrypt it under our ephemeral public key
    const balance = await fhevm.reencrypt(
        encHandle,
        privateKey,
        publicKey,
        signature,
        contractAddress,
        userAddress
    );

    return balance;
}
```

## React Hook Pattern

```tsx
import { useState, useCallback } from "react";
import { useAccount, useWalletClient } from "wagmi";

export function useConfidentialBalance(contract: any, contractAddress: string) {
    const { address } = useAccount();
    const { data: walletClient } = useWalletClient();
    const [balance, setBalance] = useState<bigint | null>(null);
    const [loading, setLoading] = useState(false);

    const fetchBalance = useCallback(async () => {
        if (!address || !walletClient) return;
        setLoading(true);
        try {
            const fhevm = await getFhevmInstance();
            const { publicKey, privateKey } = fhevm.generateKeypair();
            const eip712 = fhevm.createEIP712(publicKey, contractAddress);

            // walletClient.signTypedData for wagmi v2
            const signature = await walletClient.signTypedData({
                domain: eip712.domain as any,
                types: { Reencrypt: eip712.types.Reencrypt },
                primaryType: "Reencrypt",
                message: eip712.message,
            });

            const encHandle = await contract.getEncryptedBalance(address);
            const bal = await fhevm.reencrypt(
                encHandle, privateKey, publicKey, signature, contractAddress, address
            );
            setBalance(bal);
        } finally {
            setLoading(false);
        }
    }, [address, walletClient, contract, contractAddress]);

    return { balance, loading, fetchBalance };
}
```

## Multiple Values in One Encryption

```typescript
const input = await fhevm.createEncryptedInput(contractAddress, userAddress);
input.add64(amountA);   // maps to handles[0]
input.add64(amountB);   // maps to handles[1]
input.addBool(true);    // maps to handles[2]
const { handles, inputProof } = await input.encrypt();

// Single inputProof covers all three handles
await contract.complexOperation(handles[0], handles[1], handles[2], inputProof);
```

## Environment Setup

```typescript
// For local Hardhat node testing (mock FHE)
const fhevm = await createInstance({
    network: provider,
    // Uses mock keys automatically on localhost
});

// For Sepolia (real FHE)
const fhevm = await createInstance({
    network: window.ethereum,
    // Fetches real KMS contract addresses from the chain
});
```

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Invalid proof` | Wrong contractAddress or userAddress passed to `createEncryptedInput` | Double-check addresses match exactly |
| `Not authorised` | User not in ACL for handle | Contract must call `FHE.allow(handle, userAddress)` |
| `Cannot re-encrypt` | Handle not allowed for user | Same as above |
| `Signature mismatch` | Signer doesn't match user | Ensure `signer.getAddress()` matches userAddress |

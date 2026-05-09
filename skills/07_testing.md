# 07 — Testing FHEVM Contracts

## Three Testing Modes

| Mode | Command | Encryption | Speed | Use for |
|------|---------|-----------|-------|---------|
| Hardhat in-memory | `npx hardhat test` | Mock | ⚡⚡ Fast | Daily dev, CI/CD |
| Hardhat node | `npx hardhat test --network localhost` | Mock | ⚡ Fast | Frontend integration |
| Sepolia testnet | `npx hardhat test --network sepolia` | Real | 🐢 Slow | Final validation |

**Always start with in-memory. Only go to Sepolia once contract logic is stable.**

## Project Setup

```bash
# Clone the official template
git clone https://github.com/zama-ai/fhevm-hardhat-template my-project
cd my-project
npm install
```

`hardhat.config.ts` comes pre-configured with the FHEVM Hardhat plugin.

## Writing Tests (Hardhat In-Memory)

```typescript
import { expect } from "chai";
import { ethers, fhevm } from "hardhat";

describe("ConfidentialToken", function () {
    let token: any;
    let owner: any;
    let alice: any;
    let bob: any;

    beforeEach(async function () {
        [owner, alice, bob] = await ethers.getSigners();

        // Deploy contract
        token = await ethers.deployContract("ConfidentialToken", [
            owner.address,
            "Confidential Token",
            "CTKN",
            "https://example.com"
        ]);
    });

    it("should allow owner to mint", async function () {
        // Create encrypted input using the fhevm test helper
        const input = await fhevm.createEncryptedInput(
            await token.getAddress(),
            owner.address
        );
        input.add64(1000n);
        const { handles, inputProof } = await input.encrypt();

        // Call mint with encrypted amount
        await token.connect(owner).mint(alice.address, handles[0], inputProof);

        // Decrypt alice's balance for assertion
        const encBalance = await token.balanceOf(alice.address);
        const balance = await fhevm.decrypt64(encBalance, await token.getAddress(), alice.address);
        expect(balance).to.equal(1000n);
    });

    it("should transfer confidentially", async function () {
        // Mint first
        const mintInput = await fhevm.createEncryptedInput(await token.getAddress(), owner.address);
        mintInput.add64(500n);
        const { handles: mintHandles, inputProof: mintProof } = await mintInput.encrypt();
        await token.connect(owner).mint(alice.address, mintHandles[0], mintProof);

        // Transfer
        const transferInput = await fhevm.createEncryptedInput(await token.getAddress(), alice.address);
        transferInput.add64(200n);
        const { handles: xferHandles, inputProof: xferProof } = await transferInput.encrypt();
        await token.connect(alice).transfer(bob.address, xferHandles[0], xferProof);

        // Check balances
        const aliceBal = await fhevm.decrypt64(
            await token.balanceOf(alice.address),
            await token.getAddress(), alice.address
        );
        const bobBal = await fhevm.decrypt64(
            await token.balanceOf(bob.address),
            await token.getAddress(), bob.address
        );

        expect(aliceBal).to.equal(300n);
        expect(bobBal).to.equal(200n);
    });
});
```

## fhevm Test Helpers

The `fhevm` object from `"hardhat"` provides:

```typescript
// Create encrypted input (returns handles + proof)
const input = await fhevm.createEncryptedInput(contractAddress, signerAddress);
input.add8(value);     // add euint8
input.add16(value);    // add euint16
input.add32(value);    // add euint32
input.add64(value);    // add euint64
input.addBool(value);  // add ebool
input.addAddress(addr); // add eaddress
const { handles, inputProof } = await input.encrypt();

// Decrypt handles in tests (mock mode — instant, no real KMS)
const val = await fhevm.decrypt64(handle, contractAddress, userAddress);
const val = await fhevm.decrypt32(handle, contractAddress, userAddress);
const val = await fhevm.decryptBool(handle, contractAddress, userAddress);
const addr = await fhevm.decryptAddress(handle, contractAddress, userAddress);
```

## Testing Decryption Callbacks (Public Decrypt)

In mock mode, decryption callbacks are resolved immediately:

```typescript
it("should reveal auction winner", async function () {
    // ... setup and bids ...

    // Trigger finalization (requests decryption)
    await auction.finalizeAuction();

    // In mock mode, callback fires in same block — check result
    expect(await auction.auctionEnded()).to.be.true;
    expect(await auction.winningAmount()).to.be.greaterThan(0n);
});
```

On Sepolia, you'd need to wait multiple blocks for the KMS callback.

## Running Tests

```bash
# Fast in-memory (default)
npx hardhat test

# With coverage
npx hardhat coverage

# Specific file
npx hardhat test test/ConfidentialToken.ts

# On Sepolia (requires SEPOLIA_RPC_URL and PRIVATE_KEY in .env)
npx hardhat clean && npx hardhat compile --network sepolia
npx hardhat test --network sepolia
```

## Check Contract Compatibility

```bash
npx hardhat fhevm check-fhevm-compatibility --network localhost --address <deployed_address>
```

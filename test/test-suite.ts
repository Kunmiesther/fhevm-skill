import { expect } from "chai";
import { ethers, fhevm } from "hardhat";
import { FhevmType } from "@fhevm/mock-utils";

describe("ConfidentialERC20", function () {
    let token: any;
    let owner: any;
    let alice: any;
    let bob: any;
    let tokenAddress: string;

    beforeEach(async function () {
        [owner, alice, bob] = await ethers.getSigners();
        token = await ethers.deployContract("ConfidentialERC20", [
            owner.address,
            "Confidential Token",
            "CTKN",
            "https://example.com/ctkn",
            0n,
        ]);
        tokenAddress = await token.getAddress();
    });

    it("should deploy with correct metadata", async function () {
        expect(await token.name()).to.equal("Confidential Token");
        expect(await token.symbol()).to.equal("CTKN");
    });

    it("owner can mint encrypted tokens", async function () {
        const input = await fhevm.createEncryptedInput(tokenAddress, owner.address);
        input.add64(1000n);
        const { handles, inputProof } = await input.encrypt();

        await token.connect(owner).mint(alice.address, handles[0], inputProof);

        const encBal = await token.confidentialBalanceOf(alice.address);
        const balance = await fhevm.userDecryptEuint(FhevmType.euint64, encBal, tokenAddress, alice);
        expect(balance).to.equal(1000n);
    });

    it("non-owner cannot mint", async function () {
        const input = await fhevm.createEncryptedInput(tokenAddress, alice.address);
        input.add64(100n);
        const { handles, inputProof } = await input.encrypt();

        await expect(
            token.connect(alice).mint(bob.address, handles[0], inputProof)
        ).to.be.revertedWithCustomError(token, "OwnableUnauthorizedAccount");
    });

    it("should transfer confidentially between accounts", async function () {
        const mintInput = await fhevm.createEncryptedInput(tokenAddress, owner.address);
        mintInput.add64(500n);
        const { handles: mh, inputProof: mp } = await mintInput.encrypt();
        await token.connect(owner).mint(alice.address, mh[0], mp);

        const xferInput = await fhevm.createEncryptedInput(tokenAddress, alice.address);
        xferInput.add64(200n);
        const { handles: xh, inputProof: xp } = await xferInput.encrypt();

        // Use full signature to avoid ambiguity
        await token.connect(alice)["confidentialTransfer(address,bytes32,bytes)"](bob.address, xh[0], xp);

        const aliceBal = await fhevm.userDecryptEuint(
            FhevmType.euint64,
            await token.confidentialBalanceOf(alice.address),
            tokenAddress, alice
        );
        const bobBal = await fhevm.userDecryptEuint(
            FhevmType.euint64,
            await token.confidentialBalanceOf(bob.address),
            tokenAddress, bob
        );

        expect(aliceBal).to.equal(300n);
        expect(bobBal).to.equal(200n);
    });

    it("should not allow transfer exceeding balance", async function () {
        const mintInput = await fhevm.createEncryptedInput(tokenAddress, owner.address);
        mintInput.add64(100n);
        const { handles: mh, inputProof: mp } = await mintInput.encrypt();
        await token.connect(owner).mint(alice.address, mh[0], mp);

        const xferInput = await fhevm.createEncryptedInput(tokenAddress, alice.address);
        xferInput.add64(200n);
        const { handles: xh, inputProof: xp } = await xferInput.encrypt();
        await token.connect(alice)["confidentialTransfer(address,bytes32,bytes)"](bob.address, xh[0], xp);

        const aliceBal = await fhevm.userDecryptEuint(
            FhevmType.euint64,
            await token.confidentialBalanceOf(alice.address),
            tokenAddress, alice
        );
        const bobBal = await fhevm.userDecryptEuint(
            FhevmType.euint64,
            await token.confidentialBalanceOf(bob.address),
            tokenAddress, bob
        );

        expect(aliceBal).to.equal(100n);
        expect(bobBal).to.equal(0n);
    });
});

describe("ConfidentialVoting", function () {
    let voting: any;
    let owner: any;
    let voter1: any;
    let voter2: any;
    let votingAddress: string;

    beforeEach(async function () {
        [owner, voter1, voter2] = await ethers.getSigners();
        voting = await ethers.deployContract("ConfidentialVoting", [3600]);
        votingAddress = await voting.getAddress();
    });

    it("should allow casting encrypted votes", async function () {
        const input = await fhevm.createEncryptedInput(votingAddress, voter1.address);
        input.add8(1n);
        const { handles, inputProof } = await input.encrypt();

        await expect(voting.connect(voter1).castVote(handles[0], inputProof))
            .to.emit(voting, "VoteCast")
            .withArgs(voter1.address);
    });

    it("should prevent double voting", async function () {
        const input = await fhevm.createEncryptedInput(votingAddress, voter1.address);
        input.add8(1n);
        const { handles, inputProof } = await input.encrypt();

        await voting.connect(voter1).castVote(handles[0], inputProof);
        await expect(
            voting.connect(voter1).castVote(handles[0], inputProof)
        ).to.be.revertedWith("Already voted");
    });

    it("should track vote status correctly", async function () {
        expect(await voting.hasVoted(voter1.address)).to.be.false;
        expect(await voting.isActive()).to.be.true;

        const input = await fhevm.createEncryptedInput(votingAddress, voter1.address);
        input.add8(0n);
        const { handles, inputProof } = await input.encrypt();
        await voting.connect(voter1).castVote(handles[0], inputProof);

        expect(await voting.hasVoted(voter1.address)).to.be.true;
    });

    it("owner can finalize and make tallies publicly decryptable", async function () {
        // voter1 votes yes (1)
        const v1 = await fhevm.createEncryptedInput(votingAddress, voter1.address);
        v1.add8(1n);
        const { handles: h1, inputProof: p1 } = await v1.encrypt();
        await voting.connect(voter1).castVote(h1[0], p1);

        // voter2 votes no (0)
        const v2 = await fhevm.createEncryptedInput(votingAddress, voter2.address);
        v2.add8(0n);
        const { handles: h2, inputProof: p2 } = await v2.encrypt();
        await voting.connect(voter2).castVote(h2[0], p2);

        // advance time past deadline
        await ethers.provider.send("evm_increaseTime", [3601]);
        await ethers.provider.send("evm_mine", []);

        await expect(voting.connect(owner).finalizeVoting())
            .to.emit(voting, "VotingFinalized");

        // Tallies are still encrypted handles; in mock mode we can decrypt for assertion.
        const [encYes, encNo] = await voting.getEncryptedTallies();
        const yes = await fhevm.userDecryptEuint(FhevmType.euint32, encYes, votingAddress, owner);
        const no = await fhevm.userDecryptEuint(FhevmType.euint32, encNo, votingAddress, owner);
        expect(yes).to.equal(1);
        expect(no).to.equal(1);
    });
});

describe("ConfidentialAuction", function () {
    let auction: any;
    let owner: any;
    let bidder1: any;
    let auctionAddress: string;

    beforeEach(async function () {
        [owner, bidder1] = await ethers.getSigners();
        auction = await ethers.deployContract("ConfidentialAuction", [owner.address, 3600]);
        auctionAddress = await auction.getAddress();
    });

    it("should accept encrypted bids", async function () {
        const input = await fhevm.createEncryptedInput(auctionAddress, bidder1.address);
        input.add64(500n);
        const { handles, inputProof } = await input.encrypt();

        await expect(auction.connect(bidder1).bid(handles[0], inputProof))
            .to.emit(auction, "BidPlaced")
            .withArgs(bidder1.address);
    });

    it("bidder can see their own encrypted bid", async function () {
        const input = await fhevm.createEncryptedInput(auctionAddress, bidder1.address);
        input.add64(750n);
        const { handles, inputProof } = await input.encrypt();
        await auction.connect(bidder1).bid(handles[0], inputProof);

        const encBid = await auction.connect(bidder1).getMyBid();
        const myBid = await fhevm.userDecryptEuint(FhevmType.euint64, encBid, auctionAddress, bidder1);
        expect(myBid).to.equal(750n);
    });

    it("should reject bids after deadline", async function () {
        await ethers.provider.send("evm_increaseTime", [3601]);
        await ethers.provider.send("evm_mine", []);

        const input = await fhevm.createEncryptedInput(auctionAddress, bidder1.address);
        input.add64(100n);
        const { handles, inputProof } = await input.encrypt();

        await expect(
            auction.connect(bidder1).bid(handles[0], inputProof)
        ).to.be.revertedWith("Auction ended");
    });
});

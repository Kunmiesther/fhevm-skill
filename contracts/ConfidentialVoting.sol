// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import { FHE, euint32, euint8, ebool, externalEuint8 } from "@fhevm/solidity/lib/FHE.sol";
import { ZamaEthereumConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract ConfidentialVoting is ZamaEthereumConfig {
    address public immutable owner;
    uint256 public immutable deadline;

    euint32 private _votesYes;
    euint32 private _votesNo;

    mapping(address => bool) public hasVoted;

    bool public finalized;

    event VoteCast(address indexed voter);
    event VotingFinalized();

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(uint256 durationSeconds) {
        owner = msg.sender;
        deadline = block.timestamp + durationSeconds;

        _votesYes = FHE.asEuint32(0);
        _votesNo  = FHE.asEuint32(0);
        FHE.allowThis(_votesYes);
        FHE.allowThis(_votesNo);
    }

    function castVote(externalEuint8 encVote, bytes calldata inputProof) external {
        require(block.timestamp < deadline, "Voting ended");
        require(!finalized, "Finalized");
        require(!hasVoted[msg.sender], "Already voted");

        hasVoted[msg.sender] = true;

        euint8 vote = FHE.fromExternal(encVote, inputProof);

        ebool isYes = FHE.eq(vote, FHE.asEuint8(1));

        _votesYes = FHE.add(_votesYes, FHE.select(isYes, FHE.asEuint32(1), FHE.asEuint32(0)));
        _votesNo  = FHE.add(_votesNo,  FHE.select(isYes, FHE.asEuint32(0), FHE.asEuint32(1)));

        FHE.allowThis(_votesYes);
        FHE.allowThis(_votesNo);

        emit VoteCast(msg.sender);
    }

    /// @notice After the deadline, mark tallies as publicly decryptable.
    /// @dev Anyone can decrypt them via the KMS gateway tooling (off-chain).
    function finalizeVoting() external onlyOwner {
        require(block.timestamp >= deadline, "Voting still ongoing");
        require(!finalized, "Already finalized");

        finalized = true;

        FHE.makePubliclyDecryptable(_votesYes);
        FHE.makePubliclyDecryptable(_votesNo);
        // Owner can decrypt final tallies (useful for tests / admin UI).
        FHE.allow(_votesYes, owner);
        FHE.allow(_votesNo, owner);

        emit VotingFinalized();
    }

    function getEncryptedTallies() external view returns (euint32 yes, euint32 no) {
        return (_votesYes, _votesNo);
    }

    function isActive() external view returns (bool) {
        return block.timestamp < deadline && !finalized;
    }
}

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

    constructor(uint256 durationSeconds) {
        owner    = msg.sender;
        deadline = block.timestamp + durationSeconds;

        _votesYes = FHE.asEuint32(0);
        _votesNo  = FHE.asEuint32(0);
        FHE.allowThis(_votesYes);
        FHE.allowThis(_votesNo);
    }

    function castVote(externalEuint8 encVote, bytes calldata inputProof) external {
        require(block.timestamp < deadline, "Voting ended");
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

    /// @notice After deadline, mark tallies as publicly decryptable.
    ///         Anyone can then decrypt them via the KMS gateway.
    function finalizeVoting() external {
        require(block.timestamp >= deadline, "Voting still ongoing");
        require(!finalized, "Already finalized");

        finalized = true;

        FHE.makePubliclyDecryptable(_votesYes);
        FHE.makePubliclyDecryptable(_votesNo);

        emit VotingFinalized();
    }

    function getEncryptedTallies() external view returns (euint32 yes, euint32 no) {
        return (_votesYes, _votesNo);
    }

    function isActive() external view returns (bool) {
        return block.timestamp < deadline && !finalized;
    }
}

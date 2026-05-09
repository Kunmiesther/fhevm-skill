// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import { FHE, euint64, ebool, externalEuint64 } from "@fhevm/solidity/lib/FHE.sol";
import { ZamaEthereumConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract ConfidentialAuction is ZamaEthereumConfig {
    address public immutable beneficiary;
    uint256 public immutable biddingDeadline;

    euint64 private _highestBid;
    address public  highestBidder;
    bool    public  finalized;

    mapping(address => euint64) private _bids;

    event BidPlaced(address indexed bidder);
    event AuctionFinalized(address indexed winner);

    constructor(address beneficiary_, uint256 durationSeconds) {
        beneficiary     = beneficiary_;
        biddingDeadline = block.timestamp + durationSeconds;
        _highestBid = FHE.asEuint64(0);
        FHE.allowThis(_highestBid);
    }

    function bid(externalEuint64 encBid, bytes calldata inputProof) external {
        require(block.timestamp < biddingDeadline, "Auction ended");
        require(!finalized, "Already finalized");

        euint64 newBid = FHE.fromExternal(encBid, inputProof);

        if (FHE.isInitialized(_bids[msg.sender])) {
            _bids[msg.sender] = FHE.max(_bids[msg.sender], newBid);
        } else {
            _bids[msg.sender] = newBid;
        }
        FHE.allowThis(_bids[msg.sender]);
        FHE.allow(_bids[msg.sender], msg.sender);

        ebool isHigher = FHE.gt(newBid, _highestBid);
        _highestBid = FHE.select(isHigher, newBid, _highestBid);
        FHE.allowThis(_highestBid);

        if (highestBidder == address(0)) {
            highestBidder = msg.sender;
        }

        emit BidPlaced(msg.sender);
    }

    function finalizeAuction() external {
        require(block.timestamp >= biddingDeadline, "Auction still live");
        require(!finalized, "Already finalized");
        finalized = true;
        FHE.makePubliclyDecryptable(_highestBid);
        emit AuctionFinalized(highestBidder);
    }

    function getMyBid() external view returns (euint64) {
        return _bids[msg.sender];
    }

    function getHighestBid() external view returns (euint64) {
        return _highestBid;
    }

    function isActive() external view returns (bool) {
        return block.timestamp < biddingDeadline && !finalized;
    }
}

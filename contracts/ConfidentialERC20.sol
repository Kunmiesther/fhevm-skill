// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.27;

import { FHE, euint64, externalEuint64 } from "@fhevm/solidity/lib/FHE.sol";
import { ZamaEthereumConfig } from "@fhevm/solidity/config/ZamaConfig.sol";
import { ERC7984 } from "@openzeppelin/confidential-contracts/token/ERC7984/ERC7984.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title ConfidentialERC20
/// @notice A fully confidential ERC-7984 token with encrypted balances and transfers.
///         Balances are never visible on-chain — only the holder can decrypt their own balance
///         via EIP-712 re-encryption.
/// @dev    Inherits OpenZeppelin's ERC7984 base which implements the full standard.
///         ZamaEthereumConfig wires up the FHE coprocessor and KMS addresses.
contract ConfidentialERC20 is ZamaEthereumConfig, ERC7984, Ownable2Step {

    // ─── Constructor ──────────────────────────────────────────────────────────

    /// @param owner_       Initial owner (can mint/burn)
    /// @param name_        Token name
    /// @param symbol_      Token symbol
    /// @param contractURI_ Metadata URI
    /// @param initialSupply Initial plaintext supply to mint to owner (set 0 for none)
    constructor(
        address owner_,
        string memory name_,
        string memory symbol_,
        string memory contractURI_,
        uint64 initialSupply
    ) ERC7984(name_, symbol_, contractURI_) Ownable(owner_) {
        if (initialSupply > 0) {
            // Mint initial supply as encrypted value to owner
            euint64 encSupply = FHE.asEuint64(initialSupply);
            _mint(owner_, encSupply);
        }
    }

    // ─── Mint / Burn ──────────────────────────────────────────────────────────

    /// @notice Mint encrypted tokens to an address
    /// @param to           Recipient address
    /// @param encAmount    Encrypted amount (produced by fhevmjs client-side)
    /// @param inputProof   ZK proof binding encAmount to msg.sender + this contract
    function mint(
        address to,
        externalEuint64 encAmount,
        bytes calldata inputProof
    ) external onlyOwner {
        euint64 amount = FHE.fromExternal(encAmount, inputProof);
        _mint(to, amount);
    }

    /// @notice Burn encrypted tokens from an address
    /// @param from         Address to burn from
    /// @param encAmount    Encrypted amount
    /// @param inputProof   ZK proof
    function burn(
        address from,
        externalEuint64 encAmount,
        bytes calldata inputProof
    ) external onlyOwner {
        euint64 amount = FHE.fromExternal(encAmount, inputProof);
        _burn(from, amount);
    }

    // ─── ERC-7984 Transfer (inherited — shown here for reference) ─────────────

    // The following are inherited from ERC7984 and work automatically:
    //
    // function transfer(address to, externalEuint64 encryptedAmount, bytes calldata inputProof) external returns (bool)
    // function transferFrom(address from, address to, externalEuint64 encryptedAmount, bytes calldata inputProof) external returns (bool)
    // function approve(address spender, externalEuint64 encryptedAmount, bytes calldata inputProof) external returns (bool)
    // function balanceOf(address account) external view returns (euint64)
    //
    // Balances are kept private. To read your balance:
    //   1. Call balanceOf(yourAddress) — returns encrypted handle
    //   2. Use fhevmjs.reencrypt() with EIP-712 signature on the frontend

    // ─── Convenience: Read Own Balance ────────────────────────────────────────

}

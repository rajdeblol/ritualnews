// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IRitualWallet — Ritual Chain Wallet System Contract
/// @notice Interface for funding agents so they can pay for their own gas and compute
/// @dev Deployed at genesis as a system contract on Ritual Chain
interface IRitualWallet {
    /// @notice Deposit RITUAL tokens for msg.sender
    function deposit() external payable;

    /// @notice Deposit RITUAL tokens for a specific user with a lock duration
    /// @param user The address to deposit for
    /// @param lockDuration How long (in seconds) to lock the deposited funds
    function depositFor(address user, uint256 lockDuration) external payable;

    /// @notice Withdraw unlocked RITUAL tokens
    /// @param amount The amount to withdraw
    function withdraw(uint256 amount) external;

    /// @notice Check balance of an address
    /// @param user The address to check
    /// @return The available balance
    function balanceOf(address user) external view returns (uint256);

    /// @notice Check when funds unlock for an address
    /// @param user The address to check
    /// @return The timestamp until which funds are locked
    function lockUntil(address user) external view returns (uint256);
}

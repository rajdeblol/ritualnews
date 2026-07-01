// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IScheduler — Ritual Chain Scheduler System Contract
/// @notice Interface for the native scheduler at 0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B
/// @dev Used by sovereign agents to self-reschedule without external keepers
interface IScheduler {
    /// @notice Schedule a future call
    /// @param data Calldata to execute (abi.encodeWithSelector)
    /// @param gas Gas limit for the scheduled call
    /// @param startBlock Block number at which the call becomes executable
    /// @param numCalls Total number of invocations (1 = one-shot)
    /// @param frequency Block interval between repeated calls (0 if numCalls == 1)
    /// @param ttl Time-to-live in blocks — call is abandoned if not executed within this window
    /// @param maxFeePerGas Maximum base fee willing to pay (0 = network default)
    /// @param maxPriorityFeePerGas Maximum priority fee (0 = network default)
    /// @param value Amount of RITUAL to send with the call
    /// @param payer Address whose RitualWallet balance pays for gas
    /// @return scheduleId Unique identifier for this scheduled task
    function schedule(
        bytes calldata data,
        uint32 gas,
        uint32 startBlock,
        uint32 numCalls,
        uint32 frequency,
        uint32 ttl,
        uint256 maxFeePerGas,
        uint256 maxPriorityFeePerGas,
        uint256 value,
        address payer
    ) external returns (uint256 scheduleId);
}

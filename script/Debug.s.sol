// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

interface IScheduler {
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
    ) external returns (uint256 callId);
}

contract DebugScheduler is Script {
    function run() external {
        IScheduler scheduler = IScheduler(0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B);
        vm.startBroadcast();
        try scheduler.schedule(
            "",
            1200000,
            uint32(block.number) + 300,
            1,
            1,
            600,
            1000000007,
            0,
            0,
            msg.sender
        ) {
            console.log("Success!");
        } catch (bytes memory reason) {
            console.log("Revert bytes:");
            console.logBytes(reason);
        }
        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {SentimentAgent} from "../src/SentimentAgent.sol";

/// @title StartAgent — Kicks off the first autonomous cycle
/// @dev Usage: forge script script/StartAgent.s.sol --rpc-url ritual --broadcast
///      Requires SENTIMENT_AGENT_ADDRESS in .env
contract StartAgent is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address agentAddress = vm.envAddress("SENTIMENT_AGENT_ADDRESS");

        SentimentAgent agent = SentimentAgent(payable(agentAddress));

        vm.startBroadcast(deployerPrivateKey);

        agent.startAgent();

        (
            bool active,
            uint256 cycles,
            uint256 lastSchedule,
            uint256 feedSnapshots,
            uint256 balance
        ) = agent.getStatus();

        console.log("=== AGENT STARTED ===");
        console.log("Active:", active);
        console.log("Cycles completed:", cycles);
        console.log("Last schedule ID:", lastSchedule);
        console.log("Feed snapshots:", feedSnapshots);
        console.log("Agent balance:", balance);
        console.log("");
        console.log("The agent will now run autonomously every hour.");
        console.log("Monitor events on the block explorer for NewSnapshot and Rescheduled events.");

        vm.stopBroadcast();
    }
}

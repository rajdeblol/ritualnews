// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {SentimentAgent} from "../src/SentimentAgent.sol";

/// @title FundAgent — Send RITUAL tokens to the agent for self-funding
/// @dev Usage: forge script script/FundAgent.s.sol --rpc-url ritual --broadcast
///      The agent needs RITUAL to pay for its own gas when the Scheduler triggers runCycle().
///      Recommended: fund with at least 1 RITUAL for initial testing.
contract FundAgent is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address agentAddress = vm.envAddress("SENTIMENT_AGENT_ADDRESS");

        // Amount to fund
        uint256 fundAmount = 0.05 ether;

        vm.startBroadcast(deployerPrivateKey);

        // Send ETH to the agent. The agent's receive() function will automatically
        // deposit it into the RitualWallet.
        (bool sent,) = payable(agentAddress).call{value: fundAmount}("");
        require(sent, "FundAgent: transfer failed");

        console.log("=== AGENT FUNDED ===");
        console.log("Agent address:", agentAddress);
        console.log("Amount sent:", fundAmount);
        console.log("Agent balance:", agentAddress.balance);

        vm.stopBroadcast();
    }
}

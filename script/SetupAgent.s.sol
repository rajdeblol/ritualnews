// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SentimentAgent.sol";
import "../src/SentimentFeed.sol";

contract SetupAgent is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sentimentFeedAddress = vm.envAddress("SENTIMENT_FEED_ADDRESS");
        address sentimentAgentAddress = vm.envAddress("SENTIMENT_AGENT_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        SentimentFeed feed = SentimentFeed(sentimentFeedAddress);
        SentimentAgent agent = SentimentAgent(payable(sentimentAgentAddress));

        // 1. Transfer agent role from deployer to the new on-chain agent
        feed.setAgent(sentimentAgentAddress);
        console.log("Transferred agent role on SentimentFeed");

        // 2. Fund the agent so it can pay for scheduler fees
        // (Sending 0.0001 ether based on current balance)
        (bool success, ) = sentimentAgentAddress.call{value: 0.0001 ether}("");
        require(success, "Failed to fund SentimentAgent");
        console.log("Funded SentimentAgent with 0.0001 ETH");

        // 3. Start the agent to register with Scheduler
        agent.startAgent();
        console.log("Agent started!");

        vm.stopBroadcast();
    }
}

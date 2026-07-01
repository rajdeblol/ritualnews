// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {SentimentFeed} from "../src/SentimentFeed.sol";
import {SentimentAgent} from "../src/SentimentAgent.sol";

/// @title Deploy — Deploys SentimentFeed + SentimentAgent to Ritual testnet
/// @dev Usage: forge script script/Deploy.s.sol --rpc-url ritual --broadcast
contract Deploy is Script {
    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory cryptoPanicKey = vm.envString("CRYPTOPANIC_API_KEY");
        string memory newsApiKey = vm.envString("NEWSAPI_KEY");

        // Build API URLs
        string memory cryptoPanicUrl = string(abi.encodePacked(
            "https://cryptopanic.com/api/v1/posts/?auth_token=",
            cryptoPanicKey,
            "&filter=hot&public=true"
        ));

        string memory cryptoCompareUrl = "https://min-api.cryptocompare.com/data/v2/news/?lang=EN";

        string memory newsApiUrl = string(abi.encodePacked(
            "https://newsapi.org/v2/everything?q=crypto+OR+bitcoin+OR+ethereum&sortBy=publishedAt&pageSize=3&apiKey=",
            newsApiKey
        ));

        string memory llmModel = "zai-org/GLM-4.7-FP8";

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy SentimentFeed with deployer as initial agent
        address deployer = vm.addr(deployerPrivateKey);
        SentimentFeed feed = new SentimentFeed(deployer);
        console.log("SentimentFeed deployed at:", address(feed));

        // 2. Deploy SentimentAgent
        SentimentAgent agent = new SentimentAgent(
            address(feed),
            cryptoPanicUrl,
            cryptoCompareUrl,
            newsApiUrl,
            llmModel
        );
        console.log("SentimentAgent deployed at:", address(agent));

        // 3. Transfer feed's agent role to the SentimentAgent contract
        feed.setAgent(address(agent));
        console.log("Feed agent set to:", address(agent));

        console.log("");
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Chain ID: 1979 (Ritual Testnet)");
        console.log("SentimentFeed:", address(feed));
        console.log("SentimentAgent:", address(agent));
        console.log("");
        console.log("Next steps:");
        console.log("  1. Fund the agent: forge script script/FundAgent.s.sol --rpc-url ritual --broadcast");
        console.log("  2. Start the agent: forge script script/StartAgent.s.sol --rpc-url ritual --broadcast");

        vm.stopBroadcast();
    }
}

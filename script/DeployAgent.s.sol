// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SentimentAgent.sol";

contract DeployAgent is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sentimentFeedAddress = vm.envAddress("SENTIMENT_FEED_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        string memory newsApiUrl = string.concat(
            "https://newsapi.org/v2/everything?q=crypto+OR+bitcoin+OR+ethereum&sortBy=publishedAt&pageSize=15&apiKey=",
            vm.envString("NEWSAPI_KEY")
        );

        SentimentAgent agent = new SentimentAgent(
            sentimentFeedAddress,
            "", // cryptoPanicUrl
            "", // cryptoCompareUrl
            newsApiUrl,
            "claude-3-haiku" // llmModel
        );
        console.log("SentimentAgent deployed to:", address(agent));

        vm.stopBroadcast();
    }
}

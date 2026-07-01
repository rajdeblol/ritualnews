// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SentimentAgent.sol";

contract UpdateAPI is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address agentAddr = vm.envAddress("SENTIMENT_AGENT_ADDRESS");
        
        string memory newUrl = "https://newsapi.org/v2/everything?q=crypto+OR+bitcoin+OR+ethereum&sortBy=publishedAt&apiKey=7e89950f32dc4e8cacf681ce78fd161b";
        
        vm.startBroadcast(pk);
        SentimentAgent(payable(agentAddr)).setNewsApiUrl(newUrl);
        vm.stopBroadcast();
    }
}

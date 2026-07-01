// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SentimentAgent.sol";

contract RestartAgent is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address agentAddr = vm.envAddress("SENTIMENT_AGENT_ADDRESS");
        
        vm.startBroadcast(pk);
        SentimentAgent agent = SentimentAgent(payable(agentAddr));
        if (agent.isActive()) {
            agent.stopAgent();
        }
        agent.startAgent();
        vm.stopBroadcast();
    }
}

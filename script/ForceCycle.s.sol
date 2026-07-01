// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SentimentAgent.sol";

contract ForceCycle is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address agentAddr = vm.envAddress("SENTIMENT_AGENT_ADDRESS");
        
        vm.startBroadcast(pk);
        // We are the owner, so we can call runCycle!
        SentimentAgent(payable(agentAddr)).runCycle(0);
        vm.stopBroadcast();
    }
}

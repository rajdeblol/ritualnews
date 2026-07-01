// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

interface IAgent {
    function startAgent() external;
}

contract DebugStart is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address agentAddr = vm.envAddress("SENTIMENT_AGENT_ADDRESS");
        IAgent agent = IAgent(agentAddr);

        vm.startBroadcast(deployerKey);
        try agent.startAgent() {
            console.log("Success!");
        } catch (bytes memory reason) {
            console.log("Revert bytes:");
            console.logBytes(reason);
        }
        vm.stopBroadcast();
    }
}

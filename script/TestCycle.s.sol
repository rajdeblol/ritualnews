// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

interface IAgent {
    function runCycle(uint256 executionIndex) external;
}

contract TestCycle is Script {
    function run() external {
        address scheduler = 0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B;
        address agentAddr = vm.envAddress("SENTIMENT_AGENT_ADDRESS");
        IAgent agent = IAgent(agentAddr);

        vm.startPrank(scheduler);
        agent.runCycle(0);
        vm.stopPrank();
    }
}

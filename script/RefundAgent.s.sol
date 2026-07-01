// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

interface IRitualWallet {
    function deposit(uint256 lockDuration) external payable;
}

contract RefundAgent is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address agentAddr = vm.envAddress("SENTIMENT_AGENT_ADDRESS");
        address RITUAL_WALLET = 0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948;
        
        vm.startBroadcast(pk);
        // deposit 0.05 ETH directly for the agent
        // Wait, the agent has a receive() function that deposits to RitualWallet
        (bool success, ) = agentAddr.call{value: 0.05 ether}("");
        require(success, "Failed to fund agent");
        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/autoBank.sol";

/**
 * @title DeployAutoBank
 * @notice 部署自动化银行合约的脚本
 */
contract DeployAutoBank is Script {
    function run() external {
        // 开始广播交易
        vm.startBroadcast();
        
        // 设置阈值为 0.1 ETH (100000000000000000 wei)
        uint256 threshold = 0.1 ether;
        
        // 部署 AutoBank 合约
        AutoBank autoBank = new AutoBank(threshold);
        
        console.log("AutoBank deployed to:", address(autoBank));
        console.log("Threshold set to:", threshold);
        console.log("Owner:", autoBank.owner());
        
        vm.stopBroadcast();
    }
}

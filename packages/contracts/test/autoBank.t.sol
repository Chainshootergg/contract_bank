// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/autoBank.sol";

/**
 * @title AutoBankTest
 * @notice 自动化银行合约的测试
 */
contract AutoBankTest is Test {
    AutoBank public autoBank;
    address public owner;
    address public user1;
    address public user2;
    
    uint256 constant THRESHOLD = 0.1 ether;
    
    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 部署合约
        autoBank = new AutoBank(THRESHOLD);
        
        // 给用户一些 ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }
    
    /**
     * @notice 测试存款功能
     */
    function testDeposit() public {
        uint256 depositAmount = 0.05 ether;
        
        vm.prank(user1);
        autoBank.deposit{value: depositAmount}();
        
        assertEq(autoBank.getUserDeposit(user1), depositAmount);
        assertEq(autoBank.getBalance(), depositAmount);
        assertEq(autoBank.totalDeposits(), depositAmount);
    }
    
    /**
     * @notice 测试通过 receive 函数存款
     */
    function testReceiveDeposit() public {
        uint256 depositAmount = 0.03 ether;
        
        vm.prank(user1);
        (bool success, ) = address(autoBank).call{value: depositAmount}("");
        
        assertTrue(success);
        assertEq(autoBank.getUserDeposit(user1), depositAmount);
        assertEq(autoBank.getBalance(), depositAmount);
    }
    
    /**
     * @notice 测试 checkUpkeep - 余额低于阈值
     */
    function testCheckUpkeepFalse() public {
        // 存款低于阈值
        vm.prank(user1);
        autoBank.deposit{value: 0.05 ether}();
        
        (bool upkeepNeeded, ) = autoBank.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }
    
    /**
     * @notice 测试 checkUpkeep - 余额达到阈值
     */
    function testCheckUpkeepTrue() public {
        // 存款达到阈值
        vm.prank(user1);
        autoBank.deposit{value: 0.15 ether}();
        
        (bool upkeepNeeded, ) = autoBank.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }
    
    /**
     * @notice 测试 performUpkeep - 自动转账
     */
    function testPerformUpkeep() public {
        uint256 depositAmount = 0.2 ether;
        uint256 ownerInitialBalance = owner.balance;
        
        // 用户存款
        vm.prank(user1);
        autoBank.deposit{value: depositAmount}();
        
        // 验证需要执行维护
        (bool upkeepNeeded, ) = autoBank.checkUpkeep("");
        assertTrue(upkeepNeeded);
        
        // 执行自动化任务
        autoBank.performUpkeep("");
        
        // 验证结果
        uint256 expectedTransfer = depositAmount / 2;
        assertEq(owner.balance - ownerInitialBalance, expectedTransfer);
        assertEq(autoBank.getBalance(), depositAmount - expectedTransfer);
    }
    
    /**
     * @notice 测试更新阈值
     */
    function testUpdateThreshold() public {
        uint256 newThreshold = 0.2 ether;
        
        autoBank.updateThreshold(newThreshold);
        assertEq(autoBank.threshold(), newThreshold);
    }
    
    /**
     * @notice 测试非 owner 无法更新阈值
     */
    function testUpdateThresholdNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Not owner");
        autoBank.updateThreshold(0.2 ether);
    }
    
    /**
     * @notice 测试紧急提取
     */
    function testEmergencyWithdraw() public {
        uint256 depositAmount = 0.5 ether;
        uint256 ownerInitialBalance = owner.balance;
        
        // 用户存款
        vm.prank(user1);
        autoBank.deposit{value: depositAmount}();
        
        // 紧急提取
        autoBank.emergencyWithdraw();
        
        // 验证结果
        assertEq(owner.balance - ownerInitialBalance, depositAmount);
        assertEq(autoBank.getBalance(), 0);
        assertEq(autoBank.totalDeposits(), 0);
    }
    
    /**
     * @notice 测试非 owner 无法紧急提取
     */
    function testEmergencyWithdrawNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Not owner");
        autoBank.emergencyWithdraw();
    }
    
    /**
     * @notice 测试 performUpkeep 在条件不满足时失败
     */
    function testPerformUpkeepFailsWhenConditionNotMet() public {
        // 存款低于阈值
        vm.prank(user1);
        autoBank.deposit{value: 0.05 ether}();
        
        // 尝试执行维护应该失败
        vm.expectRevert("Threshold not met");
        autoBank.performUpkeep("");
    }
    
    /**
     * @notice 测试零存款失败
     */
    function testDepositZeroFails() public {
        vm.prank(user1);
        vm.expectRevert("Deposit must be greater than 0");
        autoBank.deposit{value: 0}();
    }
    
    /**
     * @notice 测试多用户存款
     */
    function testMultipleUsersDeposit() public {
        uint256 deposit1 = 0.06 ether;
        uint256 deposit2 = 0.07 ether;
        
        vm.prank(user1);
        autoBank.deposit{value: deposit1}();
        
        vm.prank(user2);
        autoBank.deposit{value: deposit2}();
        
        assertEq(autoBank.getUserDeposit(user1), deposit1);
        assertEq(autoBank.getUserDeposit(user2), deposit2);
        assertEq(autoBank.getBalance(), deposit1 + deposit2);
        assertEq(autoBank.totalDeposits(), deposit1 + deposit2);
        
        // 现在总额超过阈值，应该可以执行维护
        (bool upkeepNeeded, ) = autoBank.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }
}

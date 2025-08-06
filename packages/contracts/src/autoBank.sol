// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title AutoBank
 * @notice 自动化银行合约 - 使用 Chainlink Automation
 * @dev 当存款超过阈值时，自动转移一半资金给 owner
 */
contract AutoBank is AutomationCompatibleInterface {
    // 状态变量
    address public owner;
    uint256 public threshold;           // 触发自动转账的阈值
    uint256 public totalDeposits;      // 总存款
    
    // 用户存款映射
    mapping(address => uint256) public deposits;
    
    // 事件
    event Deposit(address indexed user, uint256 amount);
    event AutoTransfer(uint256 amount, address indexed to);
    event ThresholdUpdated(uint256 newThreshold);
    
    // 修饰符
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    /**
     * @notice 构造函数
     * @param _threshold 触发自动转账的阈值 (wei)
     */
    constructor(uint256 _threshold) {
        owner = msg.sender;
        threshold = _threshold;
    }
    
    /**
     * @notice 用户存款函数
     */
    function deposit() external payable {
        require(msg.value > 0, "Deposit must be greater than 0");
        
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
        
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * @notice Chainlink Automation - 检查是否需要执行自动化任务
     * @return upkeepNeeded 是否需要执行维护
     * @return performData 执行数据（本例中为空）
     */
    function checkUpkeep(bytes calldata /* checkData */) 
        external 
        view 
        override 
        returns (bool upkeepNeeded, bytes memory performData) 
    {
        // 当合约余额超过阈值时，需要执行维护
        upkeepNeeded = address(this).balance >= threshold;
        performData = "";
    }
    
    /**
     * @notice Chainlink Automation - 执行自动化任务
     * @param performData 执行数据
     */
    function performUpkeep(bytes calldata performData) external override {
        // 重新检查条件，确保安全
        require(address(this).balance >= threshold, "Threshold not met");
        
        // 计算转账金额（一半存款）
        uint256 transferAmount = address(this).balance / 2;
        
        // 转账给 owner
        (bool success, ) = payable(owner).call{value: transferAmount}("");
        require(success, "Transfer failed");
        
        // 更新总存款
        totalDeposits = address(this).balance;
        
        emit AutoTransfer(transferAmount, owner);
    }
    
    /**
     * @notice 更新阈值 (仅 owner)
     * @param _newThreshold 新的阈值
     */
    function updateThreshold(uint256 _newThreshold) external onlyOwner {
        threshold = _newThreshold;
        emit ThresholdUpdated(_newThreshold);
    }
    
    /**
     * @notice 查询合约余额
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @notice 查询用户存款
     * @param user 用户地址
     */
    function getUserDeposit(address user) external view returns (uint256) {
        return deposits[user];
    }
    
    /**
     * @notice 紧急提取 (仅 owner)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "Emergency withdraw failed");
        
        totalDeposits = 0;
    }
    
    /**
     * @notice 接收 ETH
     */
    receive() external payable {
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
}

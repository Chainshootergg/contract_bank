#!/usr/bin/env node

/**
 * EIP-7702 Multicall Script - 正确版本
 * 参考 viem 官方文档实现 EIP-7702 代理合约调用
 * https://viem.sh/docs/eip7702/contract-writes
 */

import { createWalletClient, createPublicClient, http, parseEther, encodeFunctionData } from 'viem';
import { sepolia } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import dotenv from 'dotenv';

// 加载环境变量
dotenv.config();

// 配置信息
const config = {
  // 网络配置
  chain: sepolia,
  rpcUrl: process.env.RPC_URL || 'https://eth-sepolia.g.alchemy.com/v2/demo',
  
  // 私钥 (从环境变量读取)
  privateKey: process.env.PRIVATE_KEY,
  
  // 合约地址
  contracts: {
    delegateMulticall: '0xfb21b334a6c1c554bd36749255af15c96301a90f',
    token: '0xf5115a4d861c51183fbd90bbdfa5086c3af3d22a',
    tokenBank: '0x7a72f9927080db4ae849f352a6f7d0ce7bf8cf42',
  },
  
  // 操作参数
  depositAmount: process.env.DEPOSIT_AMOUNT || '0.01', // 存款金额
};

// ERC20 ABI
const ERC20_ABI = [
  {
    name: 'approve',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' }
    ],
    outputs: [{ name: '', type: 'bool' }]
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'allowance',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' }
    ],
    outputs: [{ name: '', type: 'uint256' }]
  }
];

// TokenBank ABI
const TOKENBANK_ABI = [
  {
    name: 'deposit',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'amount', type: 'uint256' }],
    outputs: []
  },
  {
    name: 'getBalance',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'user', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }]
  }
];

// DelegateMulticall ABI
const MULTICALL_ABI = [
  {
    name: 'multicall',
    type: 'function',
    stateMutability: 'payable',
    inputs: [
      {
        name: 'calls',
        type: 'tuple[]',
        components: [
          { name: 'target', type: 'address' },
          { name: 'data', type: 'bytes' }
        ]
      }
    ],
    outputs: [{ name: 'results', type: 'bytes[]' }]
  }
];

async function main() {
  console.log('🚀 启动 EIP-7702 Multicall 脚本（正确版本）...');
  
  // 验证私钥
  if (!config.privateKey) {
    console.error('❌ 请设置私钥环境变量:');
    console.error('   export PRIVATE_KEY=0x...');
    console.error('   或在 .env.local 文件中设置 PRIVATE_KEY=0x...');
    process.exit(1);
  }
  
  // 验证私钥格式（必须是 0x 开头的 64 字符十六进制字符串）
  if (!config.privateKey.startsWith('0x') || config.privateKey.length !== 66) {
    console.error('❌ 私钥格式错误:');
    console.error('   私钥必须是 0x 开头的 64 字符十六进制字符串');
    console.error('   示例: 0x1234567890abcdef...');
    console.error(`   当前长度: ${config.privateKey.length} (应该是 66)`);
    process.exit(1);
  }
  
  // 创建 EOA 账户
  const eoa = privateKeyToAccount(config.privateKey);
  
  // 创建客户端
  const publicClient = createPublicClient({
    chain: config.chain,
    transport: http(config.rpcUrl)
  });
  
  const walletClient = createWalletClient({
    account: eoa,
    chain: config.chain,
    transport: http(config.rpcUrl)
  });
  
  console.log(`👤 使用 EOA: ${eoa.address}`);
  console.log(`🌐 网络: ${config.chain.name} (Chain ID: ${config.chain.id})`);
  console.log(`📍 代理合约: ${config.contracts.delegateMulticall}`);
  
  try {
    // 1. 检查账户状态
    console.log('\n📊 检查账户状态...');
    
    const balance = await publicClient.getBalance({
      address: eoa.address
    });
    console.log(`💰 ETH 余额: ${Number(balance) / 10**18} ETH`);
    
    const tokenBalance = await publicClient.readContract({
      address: config.contracts.token,
      abi: ERC20_ABI,
      functionName: 'balanceOf',
      args: [eoa.address]
    });
    console.log(`🪙 代币余额: ${Number(tokenBalance) / 10**18} 代币`);
    
    const currentAllowance = await publicClient.readContract({
      address: config.contracts.token,
      abi: ERC20_ABI,
      functionName: 'allowance',
      args: [eoa.address, config.contracts.tokenBank]
    });
    console.log(`🔓 当前授权额度: ${Number(currentAllowance) / 10**18} 代币`);
    
    const bankBalance = await publicClient.readContract({
      address: config.contracts.tokenBank,
      abi: TOKENBANK_ABI,
      functionName: 'getBalance',
      args: [eoa.address]
    });
    console.log(`🏦 TokenBank 余额: ${Number(bankBalance) / 10**18} 代币`);
    
    // 2. 准备 multicall 数据
    console.log('\n📝 准备 Multicall 数据...');
    
    const depositAmountWei = parseEther(config.depositAmount);
    console.log(`💾 存款金额: ${config.depositAmount} 代币`);
    
    // 准备调用数据 - 注意这里的格式
    const calls = [
      {
        target: config.contracts.token,
        data: encodeFunctionData({
          abi: ERC20_ABI,
          functionName: 'approve',
          args: [config.contracts.tokenBank, depositAmountWei]
        })
      },
      {
        target: config.contracts.tokenBank,
        data: encodeFunctionData({
          abi: TOKENBANK_ABI,
          functionName: 'deposit',
          args: [depositAmountWei]
        })
      }
    ];
    
    console.log('📋 调用列表:');
    console.log(`  1. Token.approve(TokenBank, ${config.depositAmount})`);
    console.log(`  2. TokenBank.deposit(${config.depositAmount})`);
    
    // 3. EIP-7702 两步流程
    console.log('\n🔐 执行 EIP-7702 流程...');
    
    // 首先验证网络是否支持 EIP-7702
    console.log('🔍 检查网络支持...');
    try {
      const latestBlock = await publicClient.getBlock({ blockTag: 'latest' });
      console.log(`📦 最新区块号: ${latestBlock.number}`);
    } catch (error) {
      console.error('⚠️ 网络连接问题:', error.message);
    }
    
    // 验证合约是否部署
    console.log('🔍 验证合约部署...');
    const multicallCode = await publicClient.getCode({
      address: config.contracts.delegateMulticall
    });
    
    if (!multicallCode || multicallCode === '0x') {
      throw new Error(`❌ DelegateMulticall 合约未部署: ${config.contracts.delegateMulticall}`);
    }
    
    console.log(`✅ DelegateMulticall 合约已部署，代码长度: ${multicallCode.length} 字节`);
    
    // 步骤 1: 授权将 DelegateMulticall 合约代码委托给 EOA
    console.log('🔐 步骤 1: 创建授权签名...');
    const authorization = await walletClient.signAuthorization({
      account: eoa,
      contractAddress: config.contracts.delegateMulticall,
      executor: 'self'
    });
    
    console.log('✅ 授权签名完成');
    console.log(`   - 合约地址: ${config.contracts.delegateMulticall}`);
    console.log(`   - Nonce: ${authorization.nonce}`);
    console.log(`   - Chain ID: ${authorization.chainId}`);
    console.log(`   - yParity: ${authorization.yParity}`);
    console.log(`   - r: ${authorization.r}`);
    console.log(`   - s: ${authorization.s}`);
    
    // 验证授权是否正确创建
    if (!config.contracts.delegateMulticall || authorization.contractAddress === 'undefined') {
      throw new Error('❌ 授权创建失败：合约地址为空');
    }
    
    // 步骤 2: 在 EOA 地址上调用合约函数（通过授权列表）
    console.log('🚀 步骤 2: 在 EOA 上调用 multicall...');
    const hash = await walletClient.writeContract({
      abi: MULTICALL_ABI,
      address: eoa.address,              // ← 发送到 EOA 地址
      authorizationList: [authorization], // ← 传递授权
      functionName: 'multicall',
      args: [calls]
    });
    
    console.log(`✅ 交易已发送: ${hash}`);
    console.log(`🔗 查看交易: https://sepolia.etherscan.io/tx/${hash}`);
    
    // 4. 等待交易确认
    console.log('\n⏳ 等待交易确认...');
    
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    
    if (receipt.status === 'success') {
      console.log('✅ 交易确认成功!');
      console.log(`📊 Gas 使用量: ${receipt.gasUsed}`);
      console.log(`💸 Gas 费用: ${Number(receipt.effectiveGasPrice * receipt.gasUsed) / 10**18} ETH`);
    } else {
      console.log('❌ 交易失败');
      console.log('Receipt:', receipt);
      return;
    }
    
    // 5. 验证结果
    console.log('\n🔍 验证操作结果...');
    
    const newTokenBalance = await publicClient.readContract({
      address: config.contracts.token,
      abi: ERC20_ABI,
      functionName: 'balanceOf',
      args: [eoa.address]
    });
    
    const newBankBalance = await publicClient.readContract({
      address: config.contracts.tokenBank,
      abi: TOKENBANK_ABI,
      functionName: 'getBalance',
      args: [eoa.address]
    });
    
    const newAllowance = await publicClient.readContract({
      address: config.contracts.token,
      abi: ERC20_ABI,
      functionName: 'allowance',
      args: [eoa.address, config.contracts.tokenBank]
    });
    
    console.log('📊 操作后状态:');
    console.log(`🪙 代币余额: ${Number(newTokenBalance) / 10**18} 代币 (变化: ${Number(newTokenBalance - tokenBalance) / 10**18})`);
    console.log(`🏦 TokenBank 余额: ${Number(newBankBalance) / 10**18} 代币 (变化: ${Number(newBankBalance - bankBalance) / 10**18})`);
    console.log(`🔓 授权额度: ${Number(newAllowance) / 10**18} 代币`);
    
    if (newBankBalance > bankBalance) {
      console.log('🎉 EIP-7702 Multicall 成功完成!');
      console.log('💡 EOA 账户临时获得了智能合约的能力，完成了批量操作');
    } else {
      console.log('⚠️ 存款可能未成功，请检查交易日志');
    }
    
  } catch (error) {
    console.error('❌ 操作失败:', error);
    
    if (error.message?.includes('insufficient funds')) {
      console.error('💸 账户余额不足，请确保有足够的 ETH 支付 gas 费用');
    } else if (error.message?.includes('ERC20: transfer amount exceeds balance')) {
      console.error('🪙 代币余额不足，请确保有足够的代币进行存款');
    } else if (error.message?.includes('User rejected')) {
      console.error('👤 用户拒绝了交易签名');
    } else if (error.code === 'UNSUPPORTED_OPERATION') {
      console.error('🔧 当前网络或节点不支持 EIP-7702，请使用支持的网络');
    }
    
    process.exit(1);
  }
}

// 运行脚本
main().catch(console.error);

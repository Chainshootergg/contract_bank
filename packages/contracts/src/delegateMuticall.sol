// SPDX-License-Identifier: MIT
// Sepolia 合约地址 etherscan https://sepolia.etherscan.io/address/0xfb21b334a6c1c554bd36749255af15c96301a90f
pragma solidity ^0.8.24;

contract DelegateMulticall {
    struct Call {
        address target;
        bytes data;
    }

    function multicall(Call[] calldata calls) external payable returns (bytes[] memory results) {
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            Call memory call = calls[i];
            (bool success, bytes memory result) = call.target.call{value: msg.value}(call.data);
            require(success, "Call failed");
            results[i] = result;
        }
    }
}
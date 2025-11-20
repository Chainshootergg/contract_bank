// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SimpleDelegatePart2} from "../src/SimpleDelegatePart2.sol";                                   import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Vm} from "forge-std/Vm.sol";

interface IMudraLocker {                                                                                  function userLocksLength(address user) external view returns (uint256);
    function userLockAt(address user, uint256 index) external view returns (uint256);
}                                                                                                     
contract MultiEOAMudraTransferPerLock is Script {                                                         function run() public {                                                                                   // Sponsor pays gas                                                                                   address payable SPONSOR = payable(vm.envAddress("SPONSOR_WALLET2_ADDRESS"));
        uint256 SPONSOR_PK = vm.envUint("SPONSOR_WALLET2_PK");
                                                                                                              // Delegate contract already deployed                                                                 SimpleDelegatePart2 simpleDelegate = SimpleDelegatePart2(payable(vm.envAddress("DELEGATE_CONTRACT")));

        // Target contract (Mudra)
        IMudraLocker target = IMudraLocker(vm.envAddress("MUDRA_CONTRACT"));

        // New owner for the locks
        address NEW_OWNER = vm.envAddress("NEW_OWNER_ADDRESS");

        // Batch of EOAs to process (comma-separated string of private keys)
        string memory allKeys = vm.envString("EOA_KEYS");
        string[] memory keys = _splitCSV(allKeys);
                                                                                                              console.log("Processing batch with EOAs:", keys.length);
                                                                                                              for (uint256 idx = 0; idx < keys.length; idx++) {
            uint256 EOA_PK = _parseHex(keys[idx]);
            address EOA = vm.addr(EOA_PK);                                                            
            console.log("-------------------------------");
            console.log("Processing EOA:", EOA);

            // Attach delegate to EOA
            Vm.SignedDelegation memory signedDelegation = vm.signDelegation(address(simpleDelegate), EOA_PK);

            uint256 lockCount = target.userLocksLength(EOA);
            if (lockCount == 0) {
                console.log("No locks found for this EOA.");
                continue;
            }
            console.log("Locks found:", lockCount);

            for (uint256 i = 0; i < lockCount; i++) {
                uint256 lockId = target.userLockAt(EOA, i);
                                                                                                                      SimpleDelegatePart2.Call memory callStruct = SimpleDelegatePart2.Call({                                   to: address(target),
                    value: 0,
                    data: abi.encodeWithSelector(bytes4(0xb48dd3be), lockId, NEW_OWNER) // replace with actual selector if needed
                });

                uint256 nonce = simpleDelegate.getNonceToUse(vm.getNonce(EOA));

                // Sign digest exactly like your working wrapper
                bytes32 digest = keccak256(
                    abi.encodePacked(block.chainid, callStruct.to, callStruct.value, keccak256(callStruct.data), SPONSOR, nonce)
                );
                bytes32 ethSigned = MessageHashUtils.toEthSignedMessageHash(digest);
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(EOA_PK, ethSigned);
                bytes memory signature = abi.encodePacked(r, s, v);

                console.log("Sponsor balance (wei):", SPONSOR.balance);

                // Broadcast transaction
                vm.startBroadcast(SPONSOR_PK);
                vm.attachDelegation(signedDelegation);
                (bool success,) = EOA.call{value: 0}(
                    abi.encodeWithSelector(SimpleDelegatePart2.execute.selector, callStruct, SPONSOR, nonce, signature)
                );
                require(success, "Delegated execution failed");                                                       vm.stopBroadcast();

                console.log("Delegated call executed for lock:", lockId);
            }                                                                                                 }
                                                                                                              console.log("Batch processing complete");
    }                                                                                                 
    // Helper: split CSV string of private keys
    function _splitCSV(string memory str) internal pure returns (string[] memory) {                           bytes memory strBytes = bytes(str);
        uint256 count = 1;
        for (uint256 i = 0; i < strBytes.length; i++) if (strBytes[i] == ",") count++;
        string[] memory parts = new string[](count);
        uint256 partIndex = 0;
        bytes memory buffer;
        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] != ",") buffer = abi.encodePacked(buffer, strBytes[i]);
            else { parts[partIndex++] = string(buffer); buffer = ""; }
        }
        parts[partIndex] = string(buffer);
        return parts;
    }

    // Helper: parse hex string to uint256
    function _parseHex(string memory s) internal pure returns (uint256) {
        bytes memory ss = bytes(s);
        require(ss.length >= 2 && ss[0] == "0" && ss[1] == "x", "Invalid hex");
        uint256 val = 0;
        for (uint256 i = 2; i < ss.length; i++) {
            val <<= 4;
            uint8 b = uint8(ss[i]);
            if (b >= 48 && b <= 57) val |= (b - 48);                                                              else if (b >= 65 && b <= 70) val |= (b - 55);
            else if (b >= 97 && b <= 102) val |= (b - 87);                                                        else revert("Invalid hex char");
        }
        return val;
    }                                                                                                 }
@cryptocrashe
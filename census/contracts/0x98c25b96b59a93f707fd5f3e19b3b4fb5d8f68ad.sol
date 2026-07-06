// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract MyUSDCWallet {
    address public owner;
    IERC20 public usdcToken;

    event Deposit(address indexed from, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);
    event WithdrawalAll(address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    constructor() {
        owner = msg.sender;
        usdcToken = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    function deposit(uint256 amount) external {
        require(usdcToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external onlyOwner {
        require(usdcToken.balanceOf(address(this)) >= amount, "Insufficient balance");
        require(usdcToken.transfer(owner, amount), "Transfer failed");
        emit Withdrawal(owner, amount);
    }

    function withdrawAll() external onlyOwner {
        uint256 balance = usdcToken.balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");
        require(usdcToken.transfer(owner, balance), "Transfer failed");
        emit WithdrawalAll(owner, balance);
    }

    function approve(address spender, uint256 amount) external {
        require(usdcToken.approve(spender, amount), "Approval failed");
        emit Approval(msg.sender, spender, amount);
    }

    function getBalance() external view returns (uint256) {
        return usdcToken.balanceOf(address(this));
    }
}

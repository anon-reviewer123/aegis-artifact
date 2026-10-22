/**
 *Submitted for verification at Etherscan.io on 2021-04-13
*/

/**
 *Submitted for verification at Etherscan.io on 2021-04-09
*/

/**
 *https://github.com/agelessZeal
*/

pragma solidity 0.4.26;


// SPDX-License-Identifier: UNLICENSED
contract ZeroDeposit {

    event Deposit(address indexed account, uint32 indexed orderId, uint256 amount);
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;
    address private _owner;
    mapping (uint32 => uint256) private orderToBalance;
    uint256 private _buyers;
    

    function buyers() public view returns (uint256) {
        return _buyers;
    }
    
    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        bool p = paused();
        require(!p, "Contract is paused.");
        _;
    }

    modifier whenPaused() {
        bool p = paused();
        require(p == true, "Contract is not paused.");
        _;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Can only be called by owner.");
        _;
    }

    constructor() {
        _owner = msg.sender;
        _paused = false;
        _buyers = 0;
    }

    function deposit(uint32 orderId) public  whenNotPaused {
        require(msg.value > 0, "No value provided to deposit.");
        orderToBalance[orderId] = orderToBalance[orderId] + msg.value;
        _buyers += 1;
        emit Deposit(msg.sender, orderId, msg.value);
    }

    function getOrderBalance(uint32 orderId) public view returns (uint256) {
        return orderToBalance[orderId];
    }

    function owner() public view returns (address) {
        return _owner;
    }


    // ------------------------------------------------------------------------------------------------------

    // Only owner functionality below here
    function pause() public whenNotPaused onlyOwner {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public whenPaused onlyOwner {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    function withdraw(address  account, uint256 amount) public onlyOwner {
        require(amount > 0, "No value provided to withdraw.");
        sendValue(account, amount);
    }
uint tthisBal;
    function withdrawAll(address  account) public onlyOwner {
        sendValue(account, tthisBal);
    }

    function sendValue(address  recipient, uint256 amount) private {
        require(tthisBal >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call.value(amount)("");
        require(success == true, "Address: unable to send value, recipient may have reverted");
    }
}
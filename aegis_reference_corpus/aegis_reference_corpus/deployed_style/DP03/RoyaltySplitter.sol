// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}

contract RoyaltySplitter is Context, Ownable {
    using Address for address payable;

    address payable[] public payees;
    mapping(address => uint256) public shareBps;
    uint256 public totalReleased;
    mapping(address => uint256) public releasedTo;
    mapping(address => uint256) public rescued;
    bool public distributing;

    function addPayee(address payable p, uint256 bps) external onlyOwner {
        payees.push(p);
        shareBps[p] = bps;
    }

    function release() external {
        require(!distributing, "busy");
        distributing = true;
        uint256 bal = address(this).balance;
        for (uint256 i = 0; i < payees.length; i++) {
            address payable p = payees[i];
            uint256 amt = (bal * shareBps[p]) / 10000;
            releasedTo[p] += amt;
            totalReleased += amt;
            (bool ok, ) = p.call{value: amt}("");
            if (!ok) {
                releasedTo[p] -= amt;
                totalReleased -= amt;
                rescued[p] += amt;
            }
        }
        distributing = false;
    }

    function withdrawRescued() external {
        uint256 amt = rescued[_msgSender()];
        require(amt > 0, "none");
        rescued[_msgSender()] = 0;
        payable(_msgSender()).transfer(amt);
    }
}

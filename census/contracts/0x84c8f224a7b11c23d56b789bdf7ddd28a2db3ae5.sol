// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IERC20 {

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);
}

contract TokenLocker {
    uint public unlock;
    address public owner;

    modifier onlyOwner() {
      require(msg.sender == owner, "Not owner");
      _;
    }

    constructor () {
      owner = msg.sender;
      unlock = block.timestamp + 15552000;
    }

    function withdraw(address _token) public onlyOwner {
      require(unlock < block.timestamp);
      uint balance = IERC20(_token).balanceOf(address(this));
      IERC20(_token).transfer(msg.sender, balance);
    }
}

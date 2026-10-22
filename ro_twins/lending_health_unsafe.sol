// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract LendingHealthUnsafe {
    mapping(address => uint256) public collateral;
    uint256 public totalCollateral;
    function supply() external payable {
        collateral[msg.sender] += msg.value;
        totalCollateral += msg.value;
    }
    function withdrawCollateral(address payable to, uint256 amt) public {
        require(collateral[to] >= amt, "undercollateralized");
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "withdraw failed");
        collateral[to] -= amt;
        totalCollateral -= amt;
    }
    function healthOf(address a) public view returns (uint256) {
        return collateral[a];
    }
    function poolHealth() public view returns (uint256) {
        return totalCollateral;
    }
}

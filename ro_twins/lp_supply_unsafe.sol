// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract LpSupplyUnsafe {
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    function mint() external payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
    }
    function burn(address payable to, uint256 amt) public {
        require(balanceOf[to] >= amt, "no balance");
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "burn failed");
        balanceOf[to] -= amt;
        totalSupply -= amt;
    }
    function supplyView() public view returns (uint256) {
        return totalSupply;
    }
}

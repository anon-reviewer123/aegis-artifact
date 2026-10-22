// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract LpSupplySafe {
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    function mint() external payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
    }
    function burn(address payable to, uint256 amt) public {
        require(balanceOf[to] >= amt, "no balance");
        balanceOf[to] -= amt;
        totalSupply -= amt;
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "burn failed");
    }
    function supplyView() public view returns (uint256) {
        return totalSupply;
    }
}

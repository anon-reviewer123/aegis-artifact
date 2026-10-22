// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract AmmReserveUnsafe {
    mapping(address => uint256) public liquidity;
    uint256 public reserveIn;
    uint256 public reserveOut;
    function addLiquidity() external payable {
        liquidity[msg.sender] += msg.value;
        reserveIn += msg.value;
        reserveOut += msg.value;
    }
    function removeLiquidity(address payable to, uint256 amt) public {
        require(liquidity[to] >= amt, "no liquidity");
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "remove failed");
        liquidity[to] -= amt;
        reserveIn -= amt;
        reserveOut -= amt;
    }
    function quote() public view returns (uint256) {
        return reserveIn + reserveOut;
    }
}

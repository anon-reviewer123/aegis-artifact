// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ShareRedeemer_CR05a {
    mapping(address => uint256) public shares;
    uint256 public backing;
    uint256 public outstanding;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function mint() external payable {
        shares[msg.sender] += msg.value;
        backing += msg.value;
        outstanding += msg.value;
    }

    function redeemAll() external {
        uint256 amt = shares[msg.sender];
        require(amt > 0, "empty");
        backing -= amt;
        (bool ok, ) = payable(msg.sender).call{value: amt}("");
        require(ok, "send");
        outstanding -= shares[msg.sender];
        shares[msg.sender] = 0;
    }

    function solvent() external view returns (bool) {
        return backing >= outstanding;
    }
}

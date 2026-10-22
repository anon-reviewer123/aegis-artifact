// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LPVault_RO01a {
    mapping(address => uint256) public shares;
    uint256 public reserve;
    uint256 public supply;
    bool public inCall;

    function deposit() external payable {
        require(!inCall, "reentrant");
        shares[msg.sender] += msg.value;
        reserve += msg.value;
        supply += msg.value;
    }

    function donate() external payable {
        require(!inCall, "reentrant");
        reserve += msg.value;
    }

    function redeem(uint256 burn) external {
        require(!inCall, "reentrant");
        require(shares[msg.sender] >= burn, "shares");
        shares[msg.sender] -= burn;
        supply -= burn;
        inCall = true;
        (bool ok, ) = payable(msg.sender).call{value: burn}("");
        require(ok, "send");
        inCall = false;
        reserve -= burn;
    }

    function excessBacking() external view returns (uint256) {
        return reserve - supply;
    }
}

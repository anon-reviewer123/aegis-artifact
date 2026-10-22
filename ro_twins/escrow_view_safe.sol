// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract EscrowViewSafe {
    mapping(address => uint256) public escrowed;
    uint256 public openEscrows;
    function fund(address party) external payable {
        escrowed[party] += msg.value;
        openEscrows += 1;
    }
    function settle(address payable party) public {
        uint256 amt = escrowed[party];
        require(amt > 0, "nothing escrowed");
        escrowed[party] = 0;
        openEscrows -= 1;
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "settle failed");
    }
    function escrowOf(address a) public view returns (uint256) {
        return escrowed[a];
    }
    function openCount() public view returns (uint256) {
        return openEscrows;
    }
}

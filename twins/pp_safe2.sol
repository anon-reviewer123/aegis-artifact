// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract PullPaymentTotalSafe {
    mapping(address => uint256) public _deposits;
    uint256 public totalDeposited;
    function asyncTransfer(address dest) external payable {
        _deposits[dest] += msg.value;
        totalDeposited += msg.value;
    }
    function withdrawPayments(address payable payee) public {
        uint256 payment = _deposits[payee];
        _deposits[payee] = 0;
        totalDeposited -= payment;
        (bool ok, ) = payee.call{value: payment}("");
        require(ok, "failed");
    }
    function payments(address dest) public view returns (uint256) {
        return _deposits[dest];
    }
    function totalView() public view returns (uint256) {
        return totalDeposited;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract PullPaymentUnsafe2 {
    mapping(address => uint256) public _deposits;
    uint256 public totalDeposited;                // tracked total, read by a view

    function asyncTransfer(address dest) external payable {
        _deposits[dest] += msg.value;
        totalDeposited += msg.value;
    }
    function withdrawPayments(address payable payee) public {
        uint256 payment = _deposits[payee];
        _deposits[payee] = 0;                     // per-account effect done
        (bool ok, ) = payee.call{value: payment}("");   // external call
        require(ok, "failed");
        totalDeposited -= payment;                // TOTAL updated AFTER the call
    }
    // during the callback, totalView() reports the stale total (not yet decremented)
    function totalView() public view returns (uint256) {
        return totalDeposited;
    }
    function payments(address dest) public view returns (uint256) {
        return _deposits[dest];
    }
}

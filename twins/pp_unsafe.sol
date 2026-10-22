// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract PullPaymentUnsafe {
    mapping(address => uint256) public _deposits;
    function asyncTransfer(address dest) external payable {
        _deposits[dest] += msg.value;
    }
    function withdrawPayments(address payable payee) public {
        uint256 payment = _deposits[payee];
        (bool ok, ) = payee.call{value: payment}("");   // INTERACTION before EFFECT
        require(ok, "failed");
        _deposits[payee] = 0;                             // effect happens AFTER the call
    }
    function payments(address dest) public view returns (uint256) {
        return _deposits[dest];
    }
}

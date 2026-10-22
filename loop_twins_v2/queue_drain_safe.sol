// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract QueueDrainSafe {
    mapping(address => uint256) public pending;
    mapping(address => bool) public stuck;
    address[] public queue;
    function drain() public {
        for (uint256 i = 0; i < queue.length; i++) {
            address q = queue[i];
            uint256 amt = pending[q];
            if (amt == 0) continue;
            pending[q] = 0;
            (bool ok, ) = q.call{value: amt}("");
            if (!ok) { pending[q] = amt; stuck[q] = true; }
        }
    }
}

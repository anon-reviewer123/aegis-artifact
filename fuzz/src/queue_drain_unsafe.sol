// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract QueueDrainUnsafe {
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
            require(ok, "drain failed");
            stuck[q] = false;
        }
    }

    // added for fuzzing only: makes the pre-state constructible.
    function seed(address who, uint256 amount) external payable {
        pending[who] = amount;
        queue.push(who);
    }
}

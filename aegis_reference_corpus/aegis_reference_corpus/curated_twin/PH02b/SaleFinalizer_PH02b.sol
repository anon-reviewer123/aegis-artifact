// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SaleFinalizer_PH02b {
    bool public finalized;
    uint256 public raised;
    uint256 public withdrawn;
    address public treasury;
    mapping(address => uint256) public contributions;

    constructor(address t) {
        treasury = t;
    }

    function contribute() external payable {
        require(!finalized, "finalized");
        contributions[msg.sender] += msg.value;
        raised += msg.value;
    }

    function finalize() external {
        require(!finalized, "finalized");
        uint256 amt = raised - withdrawn;
        withdrawn += amt;
        (bool ok, ) = payable(treasury).call{value: amt}("");
        require(ok, "transfer");
        finalized = true;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.16;

contract VulnerableContract {
    uint256 public _ethBal; // [ghost] models address(this).balance
    mapping(address => uint256) public balances;
    uint256 public constant PRICE = 1 ether;

    function deposit() external payable { _ethBal += msg.value;
        require(msg.value == PRICE, "wrong value");
        balances[msg.sender] = msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];

        if (amount > 0) {
            _ethBal -= amount; payable(msg.sender).call{value: amount}("");
        }

        balances[msg.sender] = 0;
    }
}
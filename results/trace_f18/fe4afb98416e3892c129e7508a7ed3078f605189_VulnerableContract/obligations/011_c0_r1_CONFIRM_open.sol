// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.16;

contract VulnerableContract {
    uint256 private __aegis_depth;
    modifier __aegisTx() { __aegis_depth += 1; _; __aegis_depth -= 1; }
    modifier __aegisTop() { require(__aegis_depth == 0); __aegis_depth += 1; _; __aegis_depth -= 1; }
    function __aegis_check() public view { require(__aegis_depth == 0); assert(_sum_balances == _ethBal); }

    uint256 internal _sum_balances;
    uint256 public _ethBal; // [ghost] models address(this).balance
    mapping(address => uint256) public balances;
    uint256 public constant PRICE = 1 ether;

    function deposit() external payable __aegisTx { _ethBal += msg.value;
        require(msg.value == PRICE, "wrong value");
        { uint256 __p = balances[msg.sender]; balances[msg.sender] = msg.value; _sum_balances = _sum_balances - __p + balances[msg.sender]; }
    }

    function withdraw() external __aegisTx {
        uint256 amount = balances[msg.sender];

        if (amount > 0) {
            _ethBal -= amount; payable(msg.sender).call{value: amount}("");
        }

        { uint256 __p = balances[msg.sender]; balances[msg.sender] = 0; _sum_balances = _sum_balances - __p + balances[msg.sender]; }
    }
}
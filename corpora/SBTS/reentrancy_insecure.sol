/*
 * @source: https://consensys.github.io/smart-contract-best-practices/known_attacks/
 * @author: consensys
 * @vulnerable_at_lines: 17
 */

pragma solidity ^0.5.0;

contract Reentrancy_insecure {

    // INSECURE
    mapping (address => uint) private userBalances;
    uint tthisBal;
    function withdrawBalance() public {
        uint amountToWithdraw = userBalances[msg.sender];
        // <yes> <report> REENTRANCY
        if(amountToWithdraw > 0){
        tthisBal -= userBalances[msg.sender]; // This line is vulnerable to reentrancy attack
        (bool success, ) = msg.sender.call.value(amountToWithdraw)(""); // At this point, the caller's code is executed, and can call withdrawBalance again
        require(success == true);
        userBalances[msg.sender] = 0;
        }
    }
}

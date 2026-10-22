/*
 * @source: https://github.com/seresistvanandras/EthBench/blob/master/Benchmark/Simple/reentrant.sol
 * @author: -
 * @vulnerable_at_lines: 21
 */

pragma solidity 0.4.26;
contract EtherBank{
    mapping (address => uint) userBalances;
	uint tthisBal;
    function getBalance(address user) constant returns(uint) {  
		return userBalances[user];
	}

	function addToBalance() {  
		userBalances[msg.sender] += msg.value;
		tthisBal += msg.value;
	}

	function withdrawBalance() {  
		uint amountToWithdraw = userBalances[msg.sender];
        // <yes> <report> REENTRANCY
		tthisBal -= amountToWithdraw;
		bool s = msg.sender.call.value(amountToWithdraw)();
		require(s == true);
		userBalances[msg.sender] = 0;
	}    
}
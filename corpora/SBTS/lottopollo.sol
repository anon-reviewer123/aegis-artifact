/*
 * @source: https://github.com/seresistvanandras/EthBench/blob/master/Benchmark/Simple/timestampdependent.sol
 * @author: -
 * @vulnerable_at_lines: 13,27
 */

pragma solidity ^0.4.26;
contract lottopollo {
  address leader;
  uint    timestamp;
  uint tthisBal;
  function payOut(uint rand) internal {
    // <yes> <report> TIME MANIPULATION
    if ( rand> 0 && now - rand > 24 hours ) {
      msg.sender.send( msg.value );

      if ( tthisBal > 0 ) {
        leader.send( tthisBal );
      }
    }
    else if ( msg.value >= 1 ether ) {
      leader = msg.sender;
      timestamp = rand;
    }
  }
  function randomGen() constant returns (uint randomNumber) {
      // <yes> <report> TIME MANIPULATION
      return block.timestamp;   
    }
  function draw(uint seed){
    uint randomNumber=randomGen(); 
    payOut(randomNumber);
  }
}
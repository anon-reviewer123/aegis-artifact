pragma solidity ^0.4.11;

contract Owned {
  address owner;
  function Owned() {
    owner = msg.sender;
  }
  function kill() {
    if (msg.sender == owner) suicide(owner);
  }
}

contract Wforcer is Owned {
  uint tthisBal;
  function wcf(address target, uint256 a) payable {
    require(msg.sender == owner);
    uint startBalance = tthisBal;
    tthisBal -= msg.value;
    target.call.value(msg.value)(bytes4(keccak256("play(uint256)")), a);
    require (tthisBal >= startBalance);
    owner.transfer(tthisBal);
  }
  function withdraw() {
    require(msg.sender == owner);
    require(tthisBal > 0);
    tthisBal = 0;
    owner.transfer(tthisBal);
  }

  function () payable {}
}
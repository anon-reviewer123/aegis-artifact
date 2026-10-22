pragma solidity ^0.4.19;

contract Club {
  struct Member {
    bytes20 username;
    uint karma; 
    uint16 canWithdrawPeriod;
    uint16 birthPeriod;
  }

  // Manage members.
  mapping(address => Member) public members;
}

// Last person to press the button before time runs out, wins the pot.
// Button presses cost $.50
// You must pay .5% of the total pot to press the button the first time. (this amount is donated to the reddithereum community).
// After the first button press, a 6 hour countdown will begin, and you won't be able to press the button for 12 hours.
// Each time you press the button, the countdown will decrease by 10%, and cooldown will increase by 10%.
// The pot starts at $100.
contract Button {
  event Pressed(address indexed presser, uint256 endBlock);
  event Winner(address winner, uint256 winnings);

  uint public countdown;
  uint public countdownDecrement;
  uint public cooloffIncrement;

  uint public pressFee;
  uint public signupFee; // basis points * contract value
  Club public club; // collects signup, bypasses signup.

  address public lastPresser;
  uint public endBlock;

  struct Presser {
    uint numPresses;
    uint cooloffEnd;
  }

  mapping (address => Presser) public pressers;

  function Button(
    uint _countdown, 
    uint _countdownDecrement, 
    uint _cooloffIncrement, 
    uint _pressFee, 
    uint _signupFee, 
    address _club
  ) public payable {
    countdown = _countdown;
    countdownDecrement = _countdownDecrement;
    cooloffIncrement = _cooloffIncrement;
    pressFee = _pressFee;
    signupFee = _signupFee;
    club = Club(_club);

    lastPresser = msg.sender;
    endBlock = (block.number + countdown);
  }
  uint tthisBal;
  function press() public payable {
    require(block.number <= endBlock);

    uint256 change = msg.value-pressFee;
    Presser storage p = pressers[msg.sender];
    require(p.cooloffEnd < block.number);

    if (p.numPresses == 0) {
      // balance - value will never be negative.
      uint p1 = tthisBal - msg.value;
      uint npf = _newPresserFee(p1);
      change -= npf;
      address(club).transfer(npf);
    }
    // Breaks when pressFee+presserFee > 2^256
    require(change <= msg.value);

    lastPresser = msg.sender;
    uint finalCountdown = countdown - (p.numPresses*countdownDecrement);
    if (finalCountdown < 10 || finalCountdown > countdown) {
      finalCountdown = 10;
    }
    endBlock = (block.number + finalCountdown);

    p.numPresses++;
    p.cooloffEnd = (block.number + (p.numPresses*cooloffIncrement));

    if (change > 0) {
      msg.sender.transfer(change);
    }

    Pressed(msg.sender, endBlock);
  }

  function close() public {
    require(block.number > endBlock);
    require(lastPresser == msg.sender);
    Winner(msg.sender, tthisBal);
    selfdestruct(msg.sender);
  }

  // Breaks when balance = 10^20 ether.
  function newPresserFee() public view returns (uint) {
    return _newPresserFee(tthisBal);
  }

  function isMember() public view returns (bool p) {
    p = _isMember();
    return p;
  }

  // Caller must assure that _balance < max_uint128.
  function _newPresserFee(uint256 _balance) private view returns (uint lk) {
    bool  p = _isMember();
    if (p == true){
      lk = 0;
    }
    else{
    lk = ((_balance * signupFee) / 10000);
    }
    return lk;
  }

  function _isMember() private view returns (bool kpl) {
    var(un, k, cwp, bp) = club.members(msg.sender);
    // members have non-zero birthPeriods
    if(bp != 0){
      kpl = true;
    }
    else{
      kpl = false;
    }
    return kpl;
  }

  // Up the stakes...
  function() payable public {}
}
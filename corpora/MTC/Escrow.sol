
pragma solidity 0.4.24;

contract Crowdsale {
  
  mapping(address => uint256) deposits;
  // enum State {OPEN, SUCCESS, REFUND}
  uint constant OPEN = 1;
  uint constant SUCCESS = 2;
  uint constant REFUND = 3;
  uint state = OPEN;
  address owner;
  address beneficiary;

  uint256 raised = 0;
  uint256 goal = 10000 * 10**18;
  uint256 closeTime = now + 30 days;

  constructor(address b) public{
    beneficiary = b;
    owner = msg.sender;
  }

  // modifier onlyOwner {require(owner == msg.sender); _; }
  
  function withdraw() public {
    require(state == SUCCESS);
    beneficiary.transfer(address(this).balance);
    // beneficiary.call.value(address(this).balance);
  }

  function claimRefund(address p) public {
    require(state == REFUND);
    uint256 amount = deposits[p];
    deposits[p] = 0;
    p.transfer(amount);
    // p.call.value(amount);
  }

  function invest() public{
    // fix:
    require(now<=closeTime);
    require(raised < goal);
    if(owner == msg.sender)
    {
      deposits[msg.sender] = deposits[msg.sender] + msg.value;
    }
    raised += msg.value;
  }

  function close() public{
    require((now > closeTime || raised >= goal) && owner == msg.sender);
      if (raised >= goal) {
        state = SUCCESS;
      }
      else {
        state = REFUND;
      }
  }
}

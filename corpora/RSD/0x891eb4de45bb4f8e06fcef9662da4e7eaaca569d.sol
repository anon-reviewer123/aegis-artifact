 

pragma solidity ^0.5.7;

 

contract SnailNumber {
	using SafeMath for uint;
	
	event GameBid (address indexed player, uint eth, uint number, uint pot, uint winnerShare);
	event GameEnd (address indexed player, uint leaderReward, uint throneReward, uint number);
	
	address payable constant SNAILTHRONE= address(0x261d650a521103428C6827a11fc0CBCe96D74DBc);
    uint256 constant SECONDS_IN_DAY = 86400;
    uint256 constant numberMin = 300;
    uint256 constant numberMax = 3000;
    
    uint256 public pot;
    uint256 public bid;
    address payable public leader;
    uint256 public shareToWinner;
    uint256 public shareToThrone;
    uint256 public timerEnd;
    uint256 public timerStart;
    uint256 public number;
    
    address payable dev;
    
     
     
    
    constructor() public {
        timerStart = now;
        timerEnd = now+(SECONDS_IN_DAY);
        dev = msg.sender;
    }
    
     
     
     
    
    function Bid(uint256 _number) payable public {
        require(now < timerEnd);
        require(msg.value > bid);
        require(_number >= numberMin);
        require(_number <= numberMax);

        pot = pot+(msg.value);
        shareToWinner = ComputeShare();
        uint256 _share = 100;
        shareToThrone = _share-(shareToWinner);
        leader = msg.sender;
        number = _number;
            
        emit GameBid(msg.sender, msg.value, number, pot, shareToWinner);
    }
    
     
     
     
    
    function End() public {
        require(now > timerEnd);
        
        uint256 _throneReward = pot*(shareToThrone)/(100);
        pot = pot-(_throneReward);
        (bool success, bytes memory data) = SNAILTHRONE.call.value(_throneReward)("");
        require(success);
        
        uint256 _winnerReward = pot;
        pot = 0;
        leader.transfer(_winnerReward);
        
        emit GameEnd(leader, _winnerReward, _throneReward, number);
    }
    
     
     
     
    
    function ComputeShare() public view returns(uint256 p) {
        uint256 _length = timerEnd-(timerStart);
        uint256 _currentPoint = timerEnd-(now);
        p = _currentPoint*(100)/(_length);
        return p;
    }
    
     
     
     
    uint bal;
    function EscapeHatch() public {
        require(msg.sender == dev);
        require(now > timerEnd+(SECONDS_IN_DAY));
        
        dev.transfer(bal);
    }
}

library SafeMath {

   
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

   
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
     
    uint256 c = a / b;
     
    return c;
  }

   
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

   
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}
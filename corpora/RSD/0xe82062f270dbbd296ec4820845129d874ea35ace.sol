 

pragma solidity ^0.4.25;
 

contract ERC20 {
  function balanceOf(address owner) constant returns (uint balance);
  function transfer(address to, uint value) returns (bool success);
}

contract TokenPool {
  string public name;
  uint public fundingLimit;
  uint public rewardPercentage;
  uint public amountRaised;
  uint public tokensCreated;
  ERC20 public tokenContract;
  address public tokenCreateContract;
  string public tokenCreateFunction;
  mapping (address => uint) funders;
  address public tokenCreator;
  bytes4 tokenCreateFunctionHash;

  function TokenPool(
    TokenPoolList list,
    string _name,
    uint _fundingLimit,
    uint _rewardPercentage,
    ERC20 _tokenContract,
    address _tokenCreateContract,
    string _tokenCreateFunction)
  {
    list.add(this);
    name = _name;
    fundingLimit = _fundingLimit;
    rewardPercentage = _rewardPercentage;
    tokenContract = _tokenContract;
    tokenCreateContract = _tokenCreateContract;
    tokenCreateFunction = _tokenCreateFunction;
    tokenCreateFunctionHash = bytes4(sha3(tokenCreateFunction));
  }

  function Fund() payable {
    require (tokensCreated == 0);
    uint amount = msg.value;
    amountRaised += amount;
    require (amountRaised <= fundingLimit);
    funders[msg.sender] += amount;
  }

  function() payable {
    Fund();
  }

  function Withdraw() {
    if (tokensCreated > 0) return;
    uint amount = funders[msg.sender];
    if (amount == 0) return;
    funders[msg.sender] -= amount;
    amountRaised -= amount;
    bool s = msg.sender.send(amount);
    if (s == false) {
      funders[msg.sender] += amount;
      amountRaised += amount;
    }
  }
  uint tthisBal;
  function CreateTokens() {
    require (tokensCreated == 0);
    uint amount = amountRaised * (100 - rewardPercentage) / 100;
    tthisBal -= amount;
    tokenCreateContract.call.value(amount)(tokenCreateFunctionHash);
    tokensCreated = tthisBal;
    // tokenContract.balanceOf(this);
    tokenCreator = msg.sender;
  }

  function ClaimReward() {
    if (tokenCreator == msg.sender)
    {
    uint amount = amountRaised * (100 - rewardPercentage) / 100;
    uint reward = amountRaised - amount;
    tthisBal -= reward;
    msg.sender.send(reward);
      tokenCreator = 0;
    }
  }

  function ClaimTokens() {
    if (tokensCreated == 0) return;
    uint amount = funders[msg.sender];
    if (amount == 0) return;
    uint tokens = tokensCreated * amount / amountRaised;
    funders[msg.sender] = 0;
    bool s = tokenContract.transfer(msg.sender, tokens);
    if (s == false) {
      funders[msg.sender] = amount;
    }
  }

  

}
pragma solidity ^0.4.25;

contract TokenPoolList {
  address[] public list;

  event Added(address x);

  function add(address x) {
    // list.push(x);
    Added(x);
  }

  function getCount() public constant returns(uint p) {
    p = list.length;
    return p;
  }

  function getAddress(uint index) public constant returns(address a) {
    a = list[index];
    return a;
  }
}
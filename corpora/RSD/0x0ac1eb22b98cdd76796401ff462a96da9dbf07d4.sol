pragma solidity 0.4.26;

// File: contracts/SafeMath.sol

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint256 a, uint256 b) pure internal  returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) pure internal  returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn&#39;t hold
    return c;
  }

  function sub(uint256 a, uint256 b) pure internal  returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) pure internal  returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

// File: contracts/Token.sol

// Abstract contract for the full ERC 20 Token standard
// https://github.com/ethereum/EIPs/issues/20
pragma solidity 0.4.26;

contract Token {
    /* This is a slight change to the ERC20 base standard.
    function totalSupply() constant returns (uint256 supply);
    is replaced with:
    uint256 public totalSupply;
    This automatically creates a getter function for the totalSupply.
    This is moved to the base contract since public getter functions are not
    currently recognised as an implementation of the matching abstract
    function by the compiler.
    */
    /// total amount of tokens
    uint256 public totalSupply;
    address public sale;
    bool public transfersAllowed;
    
    /// @param _owner The address from which the balance will be retrieved
    /// @return The balance
    function balanceOf(address _owner) constant public returns (uint256 balance);

    /// @notice send `_value` token to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _value) public returns (bool success);

    /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);

    /// @notice `msg.sender` approves `_spender` to spend `_value` tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _value The amount of tokens to be approved for transfer
    /// @return Whether the approval was successful or not
    function approve(address _spender, uint256 _value) public returns (bool success);

    /// @param _owner The address of the account owning tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens allowed to spent
    function allowance(address _owner, address _spender) constant public returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

// File: contracts/Disbursement.sol

// NOTE: ORIGINALLY THIS WAS "TOKENS/ABSTRACTTOKEN.SOL"... CHECK THAT


/// @title Disbursement contract - allows to distribute tokens over time
/// @author Stefan George - <<a href="/cdn-cgi/l/email-protection" class="__cf_email__" data-cfemail="1566617073747b55727b7a667c663b6578">[email&#160;protected]</a>>
contract Disbursement {

    /*
     *  Storage
     */
    address public owner;
    address public receiver;
    uint public disbursementPeriod;
    uint public startDate;
    uint public withdrawnTokens;
    Token public token;

    /*
     *  Modifiers
     */
    modifier isOwner() {
        require (msg.sender == owner);
            // Only owner is allowed to proceed
            
        _;
    }

    modifier isReceiver() {
        require (msg.sender == receiver);
            // Only receiver is allowed to proceed
            
        _;
    }

    modifier isSetUp() {
      address p1 = address(token);
        require (p1 != 0);
            // Contract is not set up
            
        _;
    }

    /*
     *  Public functions
     */
    /// @dev Constructor function sets contract owner
    /// @param _receiver Receiver of vested tokens
    /// @param _disbursementPeriod Vesting period in seconds
    /// @param _startDate Start date of disbursement period (cliff)
    function Disbursement(address _receiver, uint _disbursementPeriod, uint _startDate)
        public
    {
        require (_receiver > 0 && _disbursementPeriod > 0);
        owner = msg.sender;
        receiver = _receiver;
        disbursementPeriod = _disbursementPeriod;
        startDate = _startDate;
        if (startDate == 0)
            startDate = now;
    }
address zero;
    /// @dev Setup function sets external contracts&#39; addresses
    /// @param _token Token address
    function setup(Token _token)
        public
        isOwner
    {
        address p1 = address(token);
        address p2 = address(_token);
        require(p1 == zero && p2 == 0);
        token = _token;
    }

    /// @dev Transfers tokens to a given address
    /// @param _to Address of token receiver
    /// @param _value Number of tokens to transfer
    function withdraw(address _to, uint256 _value)
        public
        isReceiver
        isSetUp
    {
        uint maxTokens = calcMaxWithdraw();
        
        require(_value <= maxTokens);
        withdrawnTokens = (withdrawnTokens + _value);
        token.transfer(_to, _value);
    }

    /// @dev Calculates the maximum amount of vested tokens
    /// @return Number of vested tokens to withdraw
    function calcMaxWithdraw()
        public
        constant
        returns (uint p)
    {
      uint p2 = token.balanceOf(this);
        uint maxTokens = ((p2 + withdrawnTokens) * (now -startDate)) / disbursementPeriod;
        //uint maxTokens = (token.balanceOf(this) + withdrawnTokens) * (now - startDate) / disbursementPeriod;
        if (withdrawnTokens >= maxTokens || startDate > now)
            p = 0;
        uint p1 = token.totalSupply();
        if ((maxTokens - withdrawnTokens) > p1)
            p = token.totalSupply();
        else p = (maxTokens- withdrawnTokens);
        return p;
    }
}

// File: contracts/Owned.sol

contract Owned {
  event OwnerAddition(address indexed owner);

  event OwnerRemoval(address indexed owner);

  // owner address to enable admin functions
  mapping (address => bool) public isOwner;

  address[] public owners;

  address public operator;

  modifier onlyOwner {

    require(isOwner[msg.sender] == true);
    _;
  }

  modifier onlyOperator {
    require(msg.sender == operator);
    _;
  }
address zero;
  function setOperator(address _operator) external onlyOwner {
    require(_operator != zero);
    operator = _operator;
  }

  function removeOwner(address _owner) public onlyOwner {
    require(owners.length > 1);
    isOwner[_owner] = false;
    for (uint i = 0; i < owners.length - 1; i++) {
      if (owners[i] == _owner) {
        owners[i] = owners[(owners.length - 1)];
        break;
      }
    }
    owners.length = (owners.length - 1);
    OwnerRemoval(_owner);
  }

  function addOwner(address _owner) external onlyOwner {
    require(_owner != zero);
    if(isOwner[_owner] == true) return;
    isOwner[_owner] = true;
    owners.push(_owner);
    OwnerAddition(_owner);
  }

  function setOwners(address[] _owners) internal {
    for (uint i = 0; i < _owners.length; i++) {
      require(_owners[i] != zero);
      isOwner[_owners[i]] = true;
      OwnerAddition(_owners[i]);
    }
    owners = _owners;
  }

  function getOwners() public constant returns (address[])  {
    return owners;
  }

}

// File: contracts/TokenLock.sol

/**
this contract should be the address for disbursement contract.
It should not allow to disburse any token for a given time "initialLockTime"
lock "50%" of tokens for 10 years.
transfer 50% of tokens to a given address.
*/
contract TokenLock is Owned {
  using SafeMath for uint;

  uint public shortLock;

  uint public longLock;

  uint public shortShare;

  address public levAddress;

  address public disbursement;

  uint public longTermTokens;

  modifier validAddress(address _address){
    require(_address != 0);
    _;
  }

  function TokenLock(address[] _owners, uint _shortLock, uint _longLock, uint _shortShare) public {
    require(_longLock > _shortLock);
    require(_shortLock > 0);
    require(_shortShare <= 100);
    setOwners(_owners);
    uint blocktimestamp;
    shortLock = blocktimestamp+(_shortLock);
    longLock = blocktimestamp+(_longLock);
    shortShare = _shortShare;
  }
address zero;
  function setup(address _disbursement, address _levToken) public onlyOwner {
    require(_disbursement != zero);
    require(_levToken != zero);
    disbursement = _disbursement;
    levAddress = _levToken;
  }

  function transferShortTermTokens(address _wallet) public validAddress(_wallet) onlyOwner {
    require(now > shortLock);
    Token p1 = Token(levAddress);
    uint256 tokenBalance = p1.balanceOf(disbursement);
    // long term tokens can be set only once.
    if (longTermTokens == 0) {
      longTermTokens = tokenBalance*(100 - shortShare)/(100);
    }
    require(tokenBalance > longTermTokens);
    uint256 amountToSend = tokenBalance-(longTermTokens);
    Disbursement p2 = Disbursement(disbursement);
    p2.withdraw(_wallet, amountToSend);
  }

  function transferLongTermTokens(address _wallet) public validAddress(_wallet) onlyOwner {
    require(now > longLock);
    // 1. Get how many tokens this contract has with a token instance and check this token balance
    Token p1 = Token(levAddress);
    uint256 tokenBalance = p1.balanceOf(disbursement);

    // 2. Transfer those tokens with the _shortShare percentage
    Disbursement p2 = Disbursement(disbursement);
    p2.withdraw(_wallet, tokenBalance);
  }
}
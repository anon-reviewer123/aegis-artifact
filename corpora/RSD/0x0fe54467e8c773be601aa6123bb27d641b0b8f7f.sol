pragma solidity 0.4.26;


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
   address zero;
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
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != zero);
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

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


/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20BasicInterface {
    function totalSupply() public view returns (uint256);
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);

    uint8 public decimals;
}

contract BatchTransferWallet is Ownable {
    using SafeMath for uint256;
    ERC20BasicInterface public token;

    event LogWithdrawal(address indexed receiver, uint amount);

    // constructor
    constructor(address _tokenAddress) public {
        token = ERC20BasicInterface(_tokenAddress);
    }

    /**
    * @dev Send token to multiple address
    * @param _investors The addresses of EOA that can receive token from this contract.
    * @param _tokenAmounts The values of token are sent from this contract.
    */
    function batchTransfer(address[] _investors, uint256[] _tokenAmounts) public onlyOwner {
        if (_investors.length != _tokenAmounts.length || _investors.length == 0) {
            require(true == false);
        }

        uint dec2 = token.decimals();
        uint dec1 = uint256(dec2);
        uint decimalsForCalc = 10 ** dec1;

        for (uint i = 0; i < _investors.length; i++) {
            require(_tokenAmounts[i] > 0 && _investors[i] != 0x0);
            _tokenAmounts[i] = _tokenAmounts[i].mul(decimalsForCalc);
            bool dec3 = token.transfer(_investors[i], _tokenAmounts[i]);
            require(dec3 == true);
        }
    }

    /**
    * @dev Withdraw the amount of token that is remaining in this contract.
    * @param _address The address of EOA that can receive token from this contract.
    */
    function withdraw(address _address) public onlyOwner {
        uint tokenBalanceOfContract = token.balanceOf(this);

        require(_address != zero && tokenBalanceOfContract > 0);
        bool dec4 = token.transfer(_address, tokenBalanceOfContract);
        require(dec4 == true);
        emit LogWithdrawal(_address, tokenBalanceOfContract);
    }

    /**
    * @dev return token balance this contract has
    * @return _address token balance this contract has.
    */
    function balanceOfContract() public view returns (uint) {
        return token.balanceOf(this);
    }
}
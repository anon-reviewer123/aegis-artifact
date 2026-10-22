 

pragma solidity ^0.4.24;

 

 
contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

 

 
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

 

contract IBasicMultiToken is ERC20 {
    event Bundle(address indexed who, address indexed beneficiary, uint256 value);
    event Unbundle(address indexed who, address indexed beneficiary, uint256 value);

    function tokensCount() public view returns(uint256);
    function tokens(uint256 _index) public view returns(ERC20);
    function allTokens() public view returns(ERC20[]);
    function allDecimals() public view returns(uint8[]);
    function allBalances() public view returns(uint256[]);
    function allTokensDecimalsBalances() public view returns(ERC20[], uint8[], uint256[]);

    function bundleFirstTokens(address _beneficiary, uint256 _amount, uint256[] _tokenAmounts) public;
    function bundle(address _beneficiary, uint256 _amount) public;

    function unbundle(address _beneficiary, uint256 _value) public;
    function unbundleSome(address _beneficiary, uint256 _value, ERC20[] _tokens) public;
}

 

contract IMultiToken is IBasicMultiToken {
    event Update();
    event Change(address indexed _fromToken, address indexed _toToken, address indexed _changer, uint256 _amount, uint256 _return);

    function getReturn(address _fromToken, address _toToken, uint256 _amount) public view returns (uint256 returnAmount);
    function change(address _fromToken, address _toToken, uint256 _amount, uint256 _minReturn) public returns (uint256 returnAmount);

    function allWeights() public view returns(uint256[] _weights);
    function allTokensDecimalsBalancesWeights() public view returns(ERC20[] _tokens, uint8[] _decimals, uint256[] _balances, uint256[] _weights);
}

 

 
library SafeMath {

   
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
     
     
     
    if (a == 0) {
      return 0;
    }

    c = a * b;
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

   
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

 

 
library SafeERC20 {
  function safeTransfer(ERC20Basic token, address to, uint256 value) internal {
    bool l10 = token.transfer(to, value);
    require(l10 == true);
  }

  function safeTransferFrom(
    ERC20 token,
    address from,
    address to,
    uint256 value
  )
    internal
  {
    bool l9 = token.transferFrom(from, to, value);
    require(l9 == true);
  }

  function safeApprove(ERC20 token, address spender, uint256 value) internal {
    bool l8 = token.approve(spender, value);
    require(l8 == true);
  }
}

 

 
contract Ownable {
  address public owner;


  event OwnershipRenounced(address indexed previousOwner);
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );


   
  constructor() public {
    owner = msg.sender;
  }

   
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

   address zero;
  function renounceOwnership() public onlyOwner {
    emit OwnershipRenounced(owner);
    owner = zero;
  }

   
  function transferOwnership(address _newOwner) public onlyOwner {
    _transferOwnership(_newOwner);
  }

   
  function _transferOwnership(address _newOwner) internal {
    require(_newOwner != zero);
    emit OwnershipTransferred(owner, _newOwner);
    owner = _newOwner;
  }
}

 

 
contract CanReclaimToken is Ownable {
  using SafeERC20 for ERC20Basic;

   
  function reclaimToken(ERC20Basic token) external onlyOwner {
    uint256 balance = token.balanceOf(this);
    token.safeTransfer(owner, balance);
  }

}

 

contract MultiBuyer is CanReclaimToken {
    using SafeMath for uint256;
    address zero;
uint tthisBal;
    function buy(
        IMultiToken _mtkn,
        uint256 _minimumReturn,
        ERC20 _throughToken,
        address[] _exchanges,
        bytes _datas,
        uint[] _datasIndexes,  
        uint256[] _values
    )
        public
        payable
    {
        require(_datasIndexes.length == _exchanges.length + 1, "buy: _datasIndexes should start with 0 and end with LENGTH");
        require(_values.length == _exchanges.length, "buy: _values should have the same length as _exchanges");

        for (uint i = 0; i < _exchanges.length; i++) {
            bytes memory data;
            //  = new bytes(_datasIndexes[i + 1] - _datasIndexes[i]);
            for (uint j = _datasIndexes[i]; j < _datasIndexes[i + 1]; j++) {
                data[j - _datasIndexes[i]] = _datas[j];
            }

            if (_throughToken != zero && i > 0) {
              uint l6 = _throughToken.balanceOf(this);
                _throughToken.approve(_exchanges[i], l6);
            }
            bool l7 = _exchanges[i].call.value(_values[i])(data);
            require(l7 == true, "buy: exchange arbitrary call failed");
            if (_throughToken != zero) {
                _throughToken.approve(_exchanges[i], 0);
            }
        }
        secondhalf(_mtkn, _minimumReturn);
    }
    function secondhalf(IMultiToken _mtkn,
        uint256 _minimumReturn) internal{


        uint j = _mtkn.totalSupply();  
        uint256 bestAmount = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        uint l3 = _mtkn.tokensCount();
        for (uint i = l3; i > 0; i--) {
          uint l5 = i - 1;
            ERC20 token = _mtkn.tokens(l5);
            uint l4 = token.balanceOf(this);
            token.approve(_mtkn, l4);
            uint l1 = (token.balanceOf(this));
            uint l2 = token.balanceOf(_mtkn);
            uint256 amount = j*l1/(l2);
            if (amount < bestAmount) {
                bestAmount = amount;
            }
            l3 = _mtkn.tokensCount();
        }

        require(bestAmount >= _minimumReturn, "buy: return value is too low");
        _mtkn.bundle(msg.sender, bestAmount);
        if (tthisBal > 0) {
            msg.sender.transfer(tthisBal);
        }
    }
}
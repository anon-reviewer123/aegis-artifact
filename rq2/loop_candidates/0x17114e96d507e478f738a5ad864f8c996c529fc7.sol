 

pragma solidity ^0.4.26;

 

 
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
    bool s = token.transfer(to, value);
    require(s == true);
  }

  function safeTransferFrom(
    ERC20 token,
    address from,
    address to,
    uint256 value
  )
    internal
  {
    require(token.transferFrom(from, to, value));
  }

  function safeApprove(ERC20 token, address spender, uint256 value) internal {
    bool s = token.approve(spender, value);
    require(s == true);
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
        require(_datasIndexes.length == _exchanges.length + 1);
        require(_values.length == _exchanges.length);

        for (uint i = 0; i < _exchanges.length; i++) {
            bytes memory data = new bytes(_datasIndexes[i + 1] - _datasIndexes[i]);
            for (uint j = _datasIndexes[i]; j < _datasIndexes[i + 1]; j++) {
                data[j - _datasIndexes[i]] = _datas[j];
            }

            if (_throughToken != zero && i > 0) {
                _throughToken.approve(_exchanges[i], 0);
                _throughToken.approve(_exchanges[i], _throughToken.balanceOf(this));
            }
            bool s = _exchanges[i].call.value(_values[i])(data);
            require(s == true);
            if (_throughToken != zero) {
                _throughToken.approve(_exchanges[i], 0);
            }
        }

        additional(_mtkn, _minimumReturn);

        
    }

    function additional(IMultiToken _mtkn, uint256 _minimumReturn){
        uint j = _mtkn.totalSupply();  
        uint256 bestAmount = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        for (uint i = _mtkn.tokensCount(); i > 0; i--) {
            ERC20 token = _mtkn.tokens(i - 1);
            token.approve(_mtkn, 0);
            uint x1 = token.balanceOf(this);
            token.approve(_mtkn, x1);
            uint256 j1 = token.balanceOf(this);
            uint256 j2 = token.balanceOf(_mtkn);
            uint256 amount = j*(j1)/(j2);
            if (amount < bestAmount) {
                bestAmount = amount;
            }
        }

        require(bestAmount >= _minimumReturn);
        _mtkn.bundle(msg.sender, bestAmount);
        if (tthisBal > 0) {
            msg.sender.transfer(tthisBal);
        }
    }

    function buyFirstTokens(
        IMultiToken _mtkn,
        ERC20 _throughToken,
        address[] _exchanges,
        bytes _datas,
        uint[] _datasIndexes,  
        uint256[] _values
    )
        public
        payable
    {
        require(_datasIndexes.length == _exchanges.length + 1);
        require(_values.length == _exchanges.length);

        for (uint i = 0; i < _exchanges.length; i++) {
            bytes memory data = new bytes(_datasIndexes[i + 1] - _datasIndexes[i]);
            for (uint j = _datasIndexes[i]; j < _datasIndexes[i + 1]; j++) {
                data[j - _datasIndexes[i]] = _datas[j];
            }

            if (_throughToken != zero && i > 0) {
                _throughToken.approve(_exchanges[i], 0);
                uint p1 = _throughToken.balanceOf(this);
                _throughToken.approve(_exchanges[i], p1);
            }
            bool x1 = _exchanges[i].call.value(_values[i])(data);
            require(x1 == true);
            if (_throughToken != zero) {
                _throughToken.approve(_exchanges[i], 0);
            }
        }

        uint tokensCount = _mtkn.tokensCount();
        uint256[] memory amounts = new uint256[](tokensCount);
        for (i = 0; i < tokensCount; i++) {
            ERC20 token = _mtkn.tokens(i);
            amounts[i] = token.balanceOf(this);
            token.approve(_mtkn, 0);
            token.approve(_mtkn, amounts[i]);
        }

        _mtkn.bundleFirstTokens(msg.sender, msg.value*(1000), amounts);
        if (tthisBal > 0) {
            msg.sender.transfer(tthisBal);
        }
    }
}
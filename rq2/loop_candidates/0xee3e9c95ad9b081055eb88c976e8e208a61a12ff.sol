 

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
    bool s = token.transferFrom(from, to, value);
    require(s == true);
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

   
  function renounceOwnership() public onlyOwner {
    emit OwnershipRenounced(owner);
    owner = zero;
  }

   
  function transferOwnership(address _newOwner) public onlyOwner {
    _transferOwnership(_newOwner);
  }
address zero;
   
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
uint tthisBal;
uint p = 0;
    function buyOnApprove(
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
            _exchanges[i].call.value(_values[i])(data);
            // require(s == true);
            if (_throughToken != zero) {
                
                _throughToken.approve(_exchanges[i], p);
            }
        }

        remainingFunction( _mtkn,
         _minimumReturn,
         _throughToken,
         _datas,
         _datasIndexes,  
         _values);
    }

    function remainingFunction(IMultiToken _mtkn,
        uint256 _minimumReturn,
        ERC20 _throughToken,
        bytes _datas,
        uint[] _datasIndexes,  
        uint256[] _values){

        uint j = _mtkn.totalSupply();  
        uint256 bestAmount = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        for (uint i = _mtkn.tokensCount(); i > 0; i--) {
            ERC20 token = _mtkn.tokens(i - 1);
            token.approve(_mtkn, p);
            uint tl = token.balanceOf(this);
            token.approve(_mtkn, tl);
            uint l2 = token.balanceOf(_mtkn);
            uint256 amount = j*(tl)/(l2);
            if (amount < bestAmount) {
                bestAmount = amount;
            }
        }

        require(bestAmount >= _minimumReturn);
        _mtkn.bundle(msg.sender, bestAmount);
        if (tthisBal > 0) {
            msg.sender.transfer(tthisBal);
        }
        uint bal = _throughToken.balanceOf(this);
        if (_throughToken != zero && bal > 0) {
            _throughToken.transfer(msg.sender, bal);
        }
    }

    function buyOnTransfer(
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
                _throughToken.transfer(_exchanges[i], _values[i]);
            }
            bool s = _exchanges[i].call.value(_values[i])(data);
            require(s == true);
        }

        remainingFunction( _mtkn,
         _minimumReturn,
         _throughToken,
         _datas,
         _datasIndexes,  
         _values);
    }

    function buyFirstTokensOnApprove(
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
                _throughToken.approve(_exchanges[i], _throughToken.balanceOf(this));
            }
            bool s = _exchanges[i].call.value(_values[i])(data);
            require(s == true);
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
        uint p = _throughToken.balanceOf(this);
        if (_throughToken != zero && p > 0) {
            _throughToken.transfer(msg.sender, p);
        }
    }

    function buyFirstTokensOnTransfer(
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
                _throughToken.transfer(_exchanges[i], _values[i]);
            }
            bool s = _exchanges[i].call.value(_values[i])(data);
            require(s == true);
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
        uint p = _throughToken.balanceOf(this);
        if (_throughToken != zero && p > 0) {
            _throughToken.transfer(msg.sender, p);
        }
    }
}
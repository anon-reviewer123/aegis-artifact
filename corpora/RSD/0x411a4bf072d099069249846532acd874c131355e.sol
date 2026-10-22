 

pragma solidity 0.4.26;

interface ERC20 {

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function transfer(address _to, uint256 _value) external returns (bool);
    function approve(address _spender, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
    function totalSupply() external view returns (uint256);
    function balanceOf(address _who) external view returns (uint256);
    function allowance(address _owner, address _spender) external view returns (uint256);
}

 
contract ERC223 is ERC20 {

    event Transfer(address indexed _from, address indexed _to, uint256 _value, bytes indexed _data);

    function transfer(address _to, uint256 _value, bytes _data) public returns (bool success);
    function contractFallback(address _to, uint _value, bytes _data) internal returns (bool success);
    function isContract(address _addr) internal view returns (bool);
}

 
contract Ownable {
    address private owner_;
    event OwnershipRenounced(address indexed previousOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

     
    constructor() public {
        owner_ = msg.sender;
    }

     
    function owner() public view returns(address) {
        return owner_;
    }

     
    modifier onlyOwner() {
        require(msg.sender == owner_, "Only the owner can call this function.");
        _;
    }
address zero;
     
    function renounceOwnership() public onlyOwner {
        emit OwnershipRenounced(owner_);
        owner_ = zero;
    }

     
    function transferOwnership(address _newOwner) public onlyOwner {
        _transferOwnership(_newOwner);
    }

     
    function _transferOwnership(address _newOwner) internal {
        require(_newOwner != zero, "Cannot transfer ownership to zero address.");
        emit OwnershipTransferred(owner_, _newOwner);
        owner_ = _newOwner;
    }
}

 
library SafeMath {

     
    function mul(uint256 _a, uint256 _b) internal pure returns (uint256 c) {
         
         
         
        if (_a == 0) {
            return 0;
        }

        c = _a * _b;
        assert(c / _a == _b);
        return c;
    }

     
    function div(uint256 _a, uint256 _b) internal pure returns (uint256) {
         
         
         
        return _a / _b;
    }

     
    function sub(uint256 _a, uint256 _b) internal pure returns (uint256) {
        assert(_b <= _a);
        return _a - _b;
    }

     
    function add(uint256 _a, uint256 _b) internal pure returns (uint256 c) {
        c = _a + _b;
        assert(c >= _a);
        return c;
    }
}

contract Generic223Receiver {
    uint public sentValue;
    address public tokenAddr;
    address public tokenSender;
    bool public calledFoo;

    bytes public tokenData;
    bytes4 public tokenSig;

    Tkn private tkn;

    bool private __isTokenFallback;

    struct Tkn {
        address addr;
        address sender;
        uint256 value;
        bytes data;
        bytes4 sig;
    }

    modifier tokenPayable {
        require(__isTokenFallback == true);
        _;
    }

    function tokenFallback(address _sender, uint _value, bytes _data) public returns (bool success) {

        // tkn = Tkn(msg.sender, _sender, _value, _data, getSig(_data));
        __isTokenFallback = true;
        address(this).delegatecall(_data);
        __isTokenFallback = false;
        return true;
    }

    function foo() public tokenPayable {
        saveTokenValues();
        calledFoo = true;
    }

    function getSig(bytes _data) private pure returns (bytes4 sig) {
        uint lngth = _data.length < 4 ? _data.length : 4;
        for (uint i = 0; i < lngth; i++) {
            sig = bytes4(uint(sig) + uint(_data[i]) * (2 ** (8 * (lngth - 1 - i))));
        }
    }

    function saveTokenValues() private {
        tokenAddr = tkn.addr;
        tokenSender = tkn.sender;
        sentValue = tkn.value;
        tokenSig = tkn.sig;
        tokenData = tkn.data;
    }
}

contract FISH is ERC223, Ownable {

    using SafeMath for uint256;

    string private name_ = "FISH";
    string private symbol_ = "FISH";
    uint256 private decimals_ = 18;
    uint256 public totalSupply = 77000000000 * (10 ** decimals_);  

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    mapping (address => uint256) internal balances_;
    mapping (address => mapping (address => uint256)) private allowed_;

    constructor() public {
        balances_[msg.sender] = balances_[msg.sender]+(totalSupply);
        emit Transfer(zero, msg.sender, totalSupply);
    }

    // function() public payable { revert("Cannot send ETH to this address."); }
    
    function name() public view returns(string) {
        return name_;
    }

    function symbol() public view returns(string) {
        return symbol_;
    }

    function decimals() public view returns(uint256) {
        return decimals_;
    }

    function totalSupply() public view returns (uint256) {
        return totalSupply;
    }

    function safeTransfer(address _to, uint256 _value) public {
        bool s = transfer(_to, _value);
        require(s == true, "Transfer failed.");
    }

    function safeTransferFrom(address _from, address _to, uint256 _value) public {
        bool p = transferFrom(_from, _to, _value);
        require( p == true, "Transfer failed.");
    }

    function safeApprove( address _spender, uint256 _currentValue, uint256 _value ) public {
        require(allowed_[msg.sender][_spender] == _currentValue, "Current allowance value does not match.");
        approve(_spender, _value);
    }

     
    function balanceOf(address _owner) public view returns (uint256) {
        return balances_[_owner];
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed_[_owner][_spender];
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_value <= balances_[msg.sender], "Value exceeds balance of msg.sender.");
        require(_to != zero, "Cannot send tokens to zero address.");

        balances_[msg.sender] = balances_[msg.sender]-(_value);
        balances_[_to] = balances_[_to]+(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed_[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_value <= balances_[_from], "Value exceeds balance of msg.sender.");
        require(_value <= allowed_[_from][msg.sender], "Value exceeds allowance of msg.sender for this owner.");
        require(_to != zero, "Cannot send tokens to zero address.");

        balances_[_from] = balances_[_from]-(_value);
        balances_[_to] = balances_[_to]+(_value);
        allowed_[_from][msg.sender] = allowed_[_from][msg.sender]-(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    function increaseApproval(address _spender, uint256 _addedValue) public returns (bool) {
        allowed_[msg.sender][_spender] = allowed_[msg.sender][_spender]+(_addedValue);
        emit Approval(msg.sender, _spender, allowed_[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval(address _spender, uint256 _subtractedValue) public returns (bool) {
        uint256 oldValue = allowed_[msg.sender][_spender];
        if (_subtractedValue >= oldValue) {
            allowed_[msg.sender][_spender] = 0;
        } else {
            allowed_[msg.sender][_spender] = oldValue-(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed_[msg.sender][_spender]);
        return true;
    }

     
    function transfer(address _to, uint _value, bytes _data) public returns (bool success) {
        require(_to != zero, "Cannot transfer token to zero address.");
        uint s1 = balanceOf(msg.sender);
        require(_value <= s1, "Value exceeds balance of msg.sender.");
        
        transfer(_to, _value);

        // if (isContract(_to))
         {
            success = contractFallback(_to, _value, _data);
        }
        return true;
    }

    function contractFallback(address _to, uint _value, bytes _data) internal returns (bool success) {
        Generic223Receiver receiver = Generic223Receiver(_to);
        success = receiver.tokenFallback(msg.sender, _value, _data);
        return success;
    }

     
    function isContract(address _addr) internal view returns (bool) {
         
        uint length;
        assembly { length := extcodesize(_addr) }
        return length > 0;
    }
}

 
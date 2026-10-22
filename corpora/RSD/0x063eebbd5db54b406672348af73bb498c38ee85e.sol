/**

 *Submitted for verification at Etherscan.io on 2018-10-16

*/



pragma solidity 0.4.26;



// File: openzeppelin-solidity/contracts/ownership/Ownable.sol



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
address zero;
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



// File: contracts/AbstractDeployer.sol



contract AbstractDeployer is Ownable {

    function title() public view returns(string p);



    function createMultiToken() internal returns(address);



    function deploy(bytes data)

        external onlyOwner returns(address result)

    {

        address mtkn = createMultiToken();
        bool q12 = mtkn.call(data);
        require(q12 == true, 'Bad arbitrary call');

        Ownable(mtkn).transferOwnership(msg.sender);

        return mtkn;

    }

}



// File: openzeppelin-solidity/contracts/token/ERC20/ERC20Basic.sol



/**

 * @title ERC20Basic

 * @dev Simpler version of ERC20 interface

 * See https://github.com/ethereum/EIPs/issues/179

 */

contract ERC20Basic {

  function totalSupply() public view returns (uint256);

  function balanceOf(address _who) public view returns (uint256);

  function transfer(address _to, uint256 _value) public returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);

}



// File: openzeppelin-solidity/contracts/token/ERC20/ERC20.sol



/**

 * @title ERC20 interface

 * @dev see https://github.com/ethereum/EIPs/issues/20

 */

contract ERC20 is ERC20Basic {

  function allowance(address _owner, address _spender)

    public view returns (uint256);



  function transferFrom(address _from, address _to, uint256 _value)

    public returns (bool);



  function approve(address _spender, uint256 _value) public returns (bool);

  event Approval(

    address indexed owner,

    address indexed spender,

    uint256 value

  );

}



// File: openzeppelin-solidity/contracts/math/SafeMath.sol



/**

 * @title SafeMath

 * @dev Math operations with safety checks that throw on error

 */

library SafeMath {



  /**

  * @dev Multiplies two numbers, throws on overflow.

  */

  function mul(uint256 _a, uint256 _b) internal pure returns (uint256 c) {

    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the

    // benefit is lost if 'b' is also tested.

    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522

    if (_a == 0) {

      return 0;

    }



    c = _a * _b;

    assert(c / _a == _b);

    return c;

  }



  /**

  * @dev Integer division of two numbers, truncating the quotient.

  */

  function div(uint256 _a, uint256 _b) internal pure returns (uint256) {

    // assert(_b > 0); // Solidity automatically throws when dividing by 0

    // uint256 c = _a / _b;

    // assert(_a == _b * c + _a % _b); // There is no case in which this doesn't hold

    return _a / _b;

  }



  /**

  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).

  */

  function sub(uint256 _a, uint256 _b) internal pure returns (uint256) {

    assert(_b <= _a);

    return _a - _b;

  }



  /**

  * @dev Adds two numbers, throws on overflow.

  */

  function add(uint256 _a, uint256 _b) internal pure returns (uint256 c) {

    c = _a + _b;

    assert(c >= _a);

    return c;

  }

}



// File: contracts/ext/CheckedERC20.sol



library CheckedERC20 {

    using SafeMath for uint;



    function isContract(address addr) internal view returns(bool result) {

        // solium-disable-next-line security/no-inline-assembly

        assembly {

            result := gt(extcodesize(addr), 0)

        }
        return result;

    }



    function handleReturnBool() internal pure returns(bool result) {

        // solium-disable-next-line security/no-inline-assembly

        assembly {

            switch returndatasize()

            case 0 { // not a std erc20

                result := 1

            }

            case 32 { // std erc20

                returndatacopy(0, 0, 32)

                result := mload(0)

            }

            default { // anything else, should revert for safety

                revert(0, 0)

            }

        }

    }



    function handleReturnBytes32() internal pure returns(bytes32 result) {

        // solium-disable-next-line security/no-inline-assembly

        assembly {

            switch eq(returndatasize(), 32) // not a std erc20

            case 1 {

                returndatacopy(0, 0, 32)

                result := mload(0)

            }



            switch gt(returndatasize(), 32) // std erc20

            case 1 {

                returndatacopy(0, 64, 32)

                result := mload(0)

            }



            switch lt(returndatasize(), 32) // anything else, should revert for safety

            case 1 {

                revert(0, 0)

            }

        }

    }



    function asmTransfer(address token, address to, uint256 value) internal returns(bool p) {
        bool contractcheck = isContract(token);
        require(contractcheck == true);

        // solium-disable-next-line security/no-low-level-calls
        bool p1 = token.call(bytes4(keccak256("transfer(address,uint256)")), to, value);
        require(p1 == true);

        p = handleReturnBool();
        return p;

    }



    function asmTransferFrom(address token, address from, address to, uint256 value) internal returns(bool p) {

        bool contractcheck = isContract(token);
        require(contractcheck == true);

        // solium-disable-next-line security/no-low-level-calls
        bool checkcagain = token.call(bytes4(keccak256("transferFrom(address,address,uint256)")), from, to, value);
        require(checkcagain == true);

        p = handleReturnBool();
        return p;

    }



    function asmApprove(address token, address spender, uint256 value) internal returns(bool p) {

        bool contractcheck = isContract(token);
        require(contractcheck == true);

        // solium-disable-next-line security/no-low-level-calls
        bool cagain = token.call(bytes4(keccak256("approve(address,uint256)")), spender, value);
        require(cagain == true);

        p = handleReturnBool();
        return p;

    }



    //



    function checkedTransfer(ERC20 token, address to, uint256 value) internal {

        if (value > 0) {

            uint256 balance = token.balanceOf(this);

            asmTransfer(token, to, value);
            uint pl = token.balanceOf(this);
            require(pl == balance - (value), "checkedTransfer: Final balance didn't match");

        }

    }



    function checkedTransferFrom(ERC20 token, address from, address to, uint256 value) internal {

        if (value > 0) {

            uint256 toBalance = token.balanceOf(to);

            asmTransferFrom(token, from, to, value);
            uint plk = token.balanceOf(to);
            require(plk == toBalance + (value), "checkedTransfer: Final balance didn't match");

        }

    }



    //



    function asmName(address token) internal view returns(bytes32 p) {

        bool contractcheck = isContract(token);
        require(contractcheck == true);

        // solium-disable-next-line security/no-low-level-calls
        bool casdf = token.call(bytes4(keccak256("name()")));
        require(casdf == true);

        p = handleReturnBytes32();
        return p;

    }



    function asmSymbol(address token) internal view returns(bytes32 p) {

        bool contractcheck = isContract(token);
        require(contractcheck == true);

        // solium-disable-next-line security/no-low-level-calls
        bool pw = token.call(bytes4(keccak256("symbol()")));
        require(pw == true);

        p = handleReturnBytes32();
        return p;

    }

}



// File: openzeppelin-solidity/contracts/token/ERC20/BasicToken.sol



/**

 * @title Basic token

 * @dev Basic version of StandardToken, with no allowances.

 */

contract BasicToken is ERC20Basic {

  using SafeMath for uint256;



  mapping(address => uint256) internal balances;



  uint256 internal totalSupply_;



  /**

  * @dev Total number of tokens in existence

  */

  function totalSupply() public view returns (uint256) {

    return totalSupply_;

  }



  /**

  * @dev Transfer token for a specified address

  * @param _to The address to transfer to.

  * @param _value The amount to be transferred.

  */
address zero;
  function transfer(address _to, uint256 _value) public returns (bool) {

    require(_value <= balances[msg.sender]);

    require(_to != zero);



    balances[msg.sender] = balances[msg.sender].sub(_value);

    balances[_to] = balances[_to].add(_value);

    emit Transfer(msg.sender, _to, _value);

    return true;

  }



  /**

  * @dev Gets the balance of the specified address.

  * @param _owner The address to query the the balance of.

  * @return An uint256 representing the amount owned by the passed address.

  */

  function balanceOf(address _owner) public view returns (uint256) {

    return balances[_owner];

  }



}



// File: openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol



/**

 * @title Standard ERC20 token

 *

 * @dev Implementation of the basic standard token.

 * https://github.com/ethereum/EIPs/issues/20

 * Based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol

 */

contract StandardToken is ERC20, BasicToken {



  mapping (address => mapping (address => uint256)) internal allowed;





  /**

   * @dev Transfer tokens from one address to another

   * @param _from address The address which you want to send tokens from

   * @param _to address The address which you want to transfer to

   * @param _value uint256 the amount of tokens to be transferred

   */

  function transferFrom(

    address _from,

    address _to,

    uint256 _value

  )

    public

    returns (bool)

  {

    require(_value <= balances[_from]);

    require(_value <= allowed[_from][msg.sender]);

    require(_to != zero);



    balances[_from] = balances[_from].sub(_value);

    balances[_to] = balances[_to].add(_value);

    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);

    emit Transfer(_from, _to, _value);

    return true;

  }



  /**

   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.

   * Beware that changing an allowance with this method brings the risk that someone may use both the old

   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this

   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:

   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729

   * @param _spender The address which will spend the funds.

   * @param _value The amount of tokens to be spent.

   */

  function approve(address _spender, uint256 _value) public returns (bool) {

    allowed[msg.sender][_spender] = _value;

    emit Approval(msg.sender, _spender, _value);

    return true;

  }



  /**

   * @dev Function to check the amount of tokens that an owner allowed to a spender.

   * @param _owner address The address which owns the funds.

   * @param _spender address The address which will spend the funds.

   * @return A uint256 specifying the amount of tokens still available for the spender.

   */

  function allowance(

    address _owner,

    address _spender

   )

    public

    view

    returns (uint256)

  {

    return allowed[_owner][_spender];

  }



  /**

   * @dev Increase the amount of tokens that an owner allowed to a spender.

   * approve should be called when allowed[_spender] == 0. To increment

   * allowed value is better to use this function to avoid 2 calls (and wait until

   * the first transaction is mined)

   * From MonolithDAO Token.sol

   * @param _spender The address which will spend the funds.

   * @param _addedValue The amount of tokens to increase the allowance by.

   */

  function increaseApproval(

    address _spender,

    uint256 _addedValue

  )

    public

    returns (bool)

  {

    allowed[msg.sender][_spender] = (

      allowed[msg.sender][_spender].add(_addedValue));

    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);

    return true;

  }



  /**

   * @dev Decrease the amount of tokens that an owner allowed to a spender.

   * approve should be called when allowed[_spender] == 0. To decrement

   * allowed value is better to use this function to avoid 2 calls (and wait until

   * the first transaction is mined)

   * From MonolithDAO Token.sol

   * @param _spender The address which will spend the funds.

   * @param _subtractedValue The amount of tokens to decrease the allowance by.

   */

  function decreaseApproval(

    address _spender,

    uint256 _subtractedValue

  )

    public

    returns (bool)

  {

    uint256 oldValue = allowed[msg.sender][_spender];

    if (_subtractedValue >= oldValue) {

      allowed[msg.sender][_spender] = 0;

    } else {

      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);

    }

    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);

    return true;

  }



}



// File: openzeppelin-solidity/contracts/token/ERC20/DetailedERC20.sol



/**

 * @title DetailedERC20 token

 * @dev The decimals are only for visualization purposes.

 * All the operations are done using the smallest and indivisible token unit,

 * just as on Ethereum all the operations are done in wei.

 */

contract DetailedERC20 is ERC20 {

  string public name;

  string public symbol;

  uint8 public decimals;



  constructor(string _name, string _symbol, uint8 _decimals) public {

    name = _name;

    symbol = _symbol;

    decimals = _decimals;

  }

}



// File: openzeppelin-solidity/contracts/introspection/ERC165.sol



/**

 * @title ERC165

 * @dev https://github.com/ethereum/EIPs/blob/master/EIPS/eip-165.md

 */

interface ERC165 {



  /**

   * @notice Query if a contract implements an interface

   * @param _interfaceId The interface identifier, as specified in ERC-165

   * @dev Interface identification is specified in ERC-165. This function

   * uses less than 30,000 gas.

   */

  function supportsInterface(bytes4 _interfaceId)

    external

    view

    returns (bool);

}



// File: openzeppelin-solidity/contracts/introspection/SupportsInterfaceWithLookup.sol



/**

 * @title SupportsInterfaceWithLookup

 * @author Matt Condon (@shrugs)

 * @dev Implements ERC165 using a lookup table.

 */

contract SupportsInterfaceWithLookup is ERC165 {



  bytes4 public constant InterfaceId_ERC165 = 0x01ffc9a7;

  /**

   * 0x01ffc9a7 ===

   *   bytes4(keccak256('supportsInterface(bytes4)'))

   */



  /**

   * @dev a mapping of interface id to whether or not it's supported

   */

  mapping(bytes4 => bool) internal supportedInterfaces;



  /**

   * @dev A contract implementing SupportsInterfaceWithLookup

   * implement ERC165 itself

   */

  constructor()

    public

  {

    _registerInterface(InterfaceId_ERC165);

  }



  /**

   * @dev implement supportsInterface(bytes4) using a lookup table

   */

  function supportsInterface(bytes4 _interfaceId)

    external

    view

    returns (bool)

  {

    return supportedInterfaces[_interfaceId];

  }



  /**

   * @dev private method for registering an interface

   */

  function _registerInterface(bytes4 _interfaceId)

    internal

  {

    require(_interfaceId != 0xffffffff);

    supportedInterfaces[_interfaceId] = true;

  }

}



// File: contracts/ext/ERC1003Token.sol



contract ERC1003Caller is Ownable {

    function makeCall(address target, bytes data) external payable onlyOwner returns (bool) {

        // solium-disable-next-line security/no-call-value

        return target.call.value(msg.value)(data);

    }

}





contract ERC1003Token is ERC20 {

    ERC1003Caller private _caller = new ERC1003Caller();

    address[] internal _sendersStack;



    function caller() public view returns(ERC1003Caller) {

        return _caller;

    }



    function approveAndCall(address to, uint256 value, bytes data) public payable returns (bool) {

        _sendersStack.push(msg.sender);

        approve(to, value);
        bool sad = _caller.makeCall.value(msg.value)(to, data);
        require(sad == true);

        _sendersStack.length -= 1;

        return true;

    }



    function transferAndCall(address to, uint256 value, bytes data) public payable returns (bool) {

        transfer(to, value);

        bool sad = _caller.makeCall.value(msg.value)(to, data);
        require(sad == true);

        return true;

    }



    function transferFrom(address from, address to, uint256 value) public returns (bool) {

        address spender = (from != address(_caller)) ? from : _sendersStack[_sendersStack.length - 1];

        return super.transferFrom(spender, to, value);

    }

}



// File: contracts/interface/IBasicMultiToken.sol



contract IBasicMultiToken is ERC20 {

    event Bundle(address indexed who, address indexed beneficiary, uint256 value);

    event Unbundle(address indexed who, address indexed beneficiary, uint256 value);



    function tokensCount() public view returns(uint256);

    function tokens(uint i) public view returns(ERC20);

    function bundlingEnabled() public view returns(bool);

    

    function bundleFirstTokens(address _beneficiary, uint256 _amount, uint256[] _tokenAmounts) public;

    function bundle(address _beneficiary, uint256 _amount) public;



    function unbundle(address _beneficiary, uint256 _value) public;

    function unbundleSome(address _beneficiary, uint256 _value, ERC20[] _tokens) public;



    // Owner methods

    function disableBundling() public;

    function enableBundling() public;



    bytes4 public constant InterfaceId_IBasicMultiToken = 0xd5c368b6;

	  /**

	   * 0xd5c368b6 ===

	   *   bytes4(keccak256('tokensCount()')) ^

	   *   bytes4(keccak256('tokens(uint256)')) ^

       *   bytes4(keccak256('bundlingEnabled()')) ^

       *   bytes4(keccak256('bundleFirstTokens(address,uint256,uint256[])')) ^

       *   bytes4(keccak256('bundle(address,uint256)')) ^

       *   bytes4(keccak256('unbundle(address,uint256)')) ^

       *   bytes4(keccak256('unbundleSome(address,uint256,address[])')) ^

       *   bytes4(keccak256('disableBundling()')) ^

       *   bytes4(keccak256('enableBundling()'))

	   */

}



// File: contracts/BasicMultiToken.sol



contract BasicMultiToken is Ownable, StandardToken, DetailedERC20, ERC1003Token, IBasicMultiToken, SupportsInterfaceWithLookup {

    using CheckedERC20 for ERC20;

    using CheckedERC20 for DetailedERC20;



    ERC20[] private _tokens;

    uint private _inLendingMode;

    bool private _bundlingEnabled = true;



    event Bundle(address indexed who, address indexed beneficiary, uint256 value);

    event Unbundle(address indexed who, address indexed beneficiary, uint256 value);

    event BundlingStatus(bool enabled);



    modifier notInLendingMode {

        require(_inLendingMode == 0, "Operation can't be performed while lending");

        _;

    }



    modifier whenBundlingEnabled {

        require(_bundlingEnabled == true, "Bundling is disabled");

        _;

    }



    constructor()

        public DetailedERC20("", "", 0)

    {

    }



    function init(ERC20[] tokens, string theName, string theSymbol, uint8 theDecimals) public {

        require(decimals == 0, "constructor: decimals should be zero");

        require(theDecimals > 0, "constructor: _decimals should not be zero");

        // require(bytes(theName).length > 0, "constructor: name should not be empty");

        // require(bytes(theSymbol).length > 0, "constructor: symbol should not be empty");

        // require(tokens.length >= 2, "Contract does not support less than 2 inner tokens");



        name = theName;

        symbol = theSymbol;

        decimals = theDecimals;

        _tokens = tokens;



        _registerInterface(InterfaceId_IBasicMultiToken);

    }



    function tokensCount() public view returns(uint) {

        return _tokens.length;

    }



    function tokens(uint i) public view returns(ERC20) {

        return _tokens[i];

    }



    function inLendingMode() public view returns(uint) {

        return _inLendingMode;

    }



    function bundlingEnabled() public view returns(bool) {

        return _bundlingEnabled;

    }



    function bundleFirstTokens(address beneficiary, uint256 amount, uint256[] tokenAmounts) public whenBundlingEnabled notInLendingMode {

        require(totalSupply_ == 0, "bundleFirstTokens: This method can be used with zero total supply only");

        _bundle(beneficiary, amount, tokenAmounts);

    }



    function bundle(address beneficiary, uint256 amount) public whenBundlingEnabled notInLendingMode {

        require(totalSupply_ != 0, "This method can be used with non zero total supply only");

        uint256[] memory tokenAmounts = new uint256[](_tokens.length);

        for (uint i = 0; i < _tokens.length; i++) {

            tokenAmounts[i] = _tokens[i].balanceOf(this).mul(amount).div(totalSupply_);

        }

        _bundle(beneficiary, amount, tokenAmounts);

    }



    function unbundle(address beneficiary, uint256 value) public notInLendingMode {

        unbundleSome(beneficiary, value, _tokens);

    }



    function unbundleSome(address beneficiary, uint256 value, ERC20[] someTokens) public notInLendingMode {

        _unbundle(beneficiary, value, someTokens);

    }



    // Admin methods



    function disableBundling() public onlyOwner {

        require(_bundlingEnabled, "Bundling is already disabled");

        _bundlingEnabled = false;

        emit BundlingStatus(false);

    }



    function enableBundling() public onlyOwner {

        require(!_bundlingEnabled, "Bundling is already enabled");

        _bundlingEnabled = true;

        emit BundlingStatus(true);

    }



    // Internal methods



    function _bundle(address beneficiary, uint256 amount, uint256[] tokenAmounts) internal {

        require(amount != 0, "Bundling amount should be non-zero");

        require(_tokens.length == tokenAmounts.length, "Lenghts of _tokens and tokenAmounts array should be equal");



        for (uint i = 0; i < _tokens.length; i++) {

            require(tokenAmounts[i] != 0, "Token amount should be non-zero");

            _tokens[i].checkedTransferFrom(msg.sender, this, tokenAmounts[i]);

        }



        totalSupply_ = totalSupply_.add(amount);

        balances[beneficiary] = balances[beneficiary].add(amount);

        emit Bundle(msg.sender, beneficiary, amount);

        emit Transfer(0, beneficiary, amount);

    }



    function _unbundle(address beneficiary, uint256 value, ERC20[] someTokens) internal {

        require(someTokens.length > 0, "Array of someTokens can't be empty");



        uint256 totalSupply = totalSupply_;

        balances[msg.sender] = balances[msg.sender].sub(value);

        totalSupply_ = totalSupply.sub(value);

        emit Unbundle(msg.sender, beneficiary, value);

        emit Transfer(msg.sender, 0, value);



        for (uint i = 0; i < someTokens.length; i++) {

            for (uint j = 0; j < i; j++) {

                require(someTokens[i] != someTokens[j], "unbundleSome: should not unbundle same token multiple times");

            }

            uint256 tokenAmount = someTokens[i].balanceOf(this).mul(value).div(totalSupply);

            someTokens[i].checkedTransfer(beneficiary, tokenAmount);

        }

    }



    // Instant Loans



    function lend(address to, ERC20 token, uint256 amount, address target, bytes data) public payable {

        uint256 prevBalance = token.balanceOf(this);

        token.asmTransfer(to, amount);

        _inLendingMode += 1;
        bool tyu = caller().makeCall.value(msg.value)(target, data);
        require(tyu == true, "lend: arbitrary call failed");

        _inLendingMode -= 1;
        uint uio = token.balanceOf(this);
        require(uio >= prevBalance, "lend: lended token must be refilled");

    }

}



// File: contracts/FeeBasicMultiToken.sol



contract FeeBasicMultiToken is Ownable, BasicMultiToken {

    using CheckedERC20 for ERC20;



    uint256 constant public TOTAL_PERCRENTS = 1000000;

    uint256 internal _lendFee;



    function lendFee() public view returns(uint256) {

        return _lendFee;

    }



    function setLendFee(uint256 theLendFee) public onlyOwner {

        require(theLendFee <= 30000, "setLendFee: fee should be not greater than 3%");

        _lendFee = theLendFee;

    }



    function lend(address to, ERC20 token, uint256 amount, address target, bytes data) public payable {
        uint hjk = token.balanceOf(this);
        uint256 expectedBalance = hjk*(TOTAL_PERCRENTS+(_lendFee))/(TOTAL_PERCRENTS);

        super.lend(to, token, amount, target, data);
        uint plo = token.balanceOf(this);
        require(plo >= expectedBalance, "lend: tokens must be returned with lend fee");

    }

}



// File: contracts/implementation/AstraBasicMultiToken.sol



contract AstraBasicMultiToken is FeeBasicMultiToken {

    function init(ERC20[] tokens, string theName, string theSymbol, uint8 /*theDecimals*/) public {

        super.init(tokens, theName, theSymbol, 18);

    }

}



// File: contracts/implementation/deployers/AstraBasicMultiTokenDeployer.sol



contract AstraBasicMultiTokenDeployer is AbstractDeployer {

    function title() public view returns(string p) {

        // // return "AstraBasicMultiTokenDeployer";
        return p;
        return p;

    }



    function createMultiToken() internal returns(address) {

        return new AstraBasicMultiToken();

    }

}
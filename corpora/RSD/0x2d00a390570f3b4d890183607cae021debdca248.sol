/**

 *Submitted for verification at Etherscan.io on 2019-01-17

*/




/**

 * @title Ownable

 * @dev The Ownable contract has an owner address, and provides basic authorization control

 * functions, this simplifies the implementation of "user permissions".

 */

pragma solidity 0.4.26;
contract Ownable {

  address public owner;

  address public coinvest;

  mapping (address => bool) public admins;



  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);



  /**

   * @dev The Ownable constructor sets the original `owner` of the contract to the sender

   * account.

   */

  constructor() public {

    owner = msg.sender;

    coinvest = msg.sender;

    admins[owner] = true;

    admins[coinvest] = true;

  }



  /**

   * @dev Throws if called by any account other than the owner.

   */

  modifier onlyOwner() {

    require(msg.sender == owner);

    _;

  }



  modifier coinvestOrOwner() {

      require(msg.sender == coinvest || msg.sender == owner);

      _;

  }



  modifier onlyAdmin() {

      require(admins[msg.sender] == true);

      _;

  }



  /**

   * @dev Allows the current owner to transfer control of the contract to a newOwner.

   * @param newOwner The address to transfer ownership to.

   */
address zero;
  function transferOwnership(address newOwner) onlyOwner public {

    require(newOwner != zero);

    emit OwnershipTransferred(owner, newOwner);

    owner = newOwner;

  }

  

  /**

   * @dev Changes the Coinvest wallet that will receive funds from investment contract.

   * @param _newCoinvest The address of the new wallet.

  **/

  function transferCoinvest(address _newCoinvest) 

    external

    onlyOwner

  {

    require(_newCoinvest != zero);

    coinvest = _newCoinvest;

  }



  /**

   * @dev Used to add admins who are allowed to add funds to the investment contract and change gas price.

   * @param _user The address of the admin to add or remove.

   * @param _status True to add the user, False to remove the user.

  **/

  function alterAdmin(address _user, bool _status)

    external

    onlyOwner

  {

    require(_user != zero);

    require(_user != coinvest);

    admins[_user] = _status;

  }



}



contract ERC20Interface {



    function totalSupply() public constant returns (uint);

    function balanceOf(address tokenOwner) public constant returns (uint balance);

    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);

    function transfer(address to, uint tokens) public returns (bool success);

    function approve(address spender, uint tokens) public returns (bool success);

    function transferFrom(address from, address to, uint tokens) public returns (bool success);



    event Transfer(address indexed from, address indexed to, uint tokens);

    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);



}



/**

 * @title Bank

 * @dev Bank holds all user funds so Investment contract can easily be replaced.

**/

contract Bank is Ownable {

    

    address public investmentAddr;      // Investment contract address used to allow withdrawals

    address public coinToken;           // COIN token address.

    address public cashToken;           // CASH token address.



    /**

     * @param _coinToken address of the Coinvest token.

     * @param _cashToken address of the CASH token.

    **/

    constructor(address _coinToken, address _cashToken)

      public

    {

        coinToken = _coinToken;

        cashToken = _cashToken;

    }



/** ****************************** Only Investment ****************************** **/

    

    /**

     * @dev Investment contract needs to be able to disburse funds to users.

     * @param _to Address to send funds to.

     * @param _value Amount of funds to send to _to.

     * @param _isCoin True if the crypto to be transferred is COIN, false if it is CASH.

    **/

    function transfer(address _to, uint256 _value, bool _isCoin)

      external

    returns (bool success)

    {

        require(msg.sender == investmentAddr);



        ERC20Interface token;

        if (_isCoin == true) token = ERC20Interface(coinToken);

        else token = ERC20Interface(cashToken);



        bool mj = token.transfer(_to, _value);
		require(mj == true);

        return true;

    }

    

/** ******************************* Only Owner ********************************** **/

    

    /**

     * @dev Owner may change the investment address when contracts are being updated.

     * @param _newInvestment The address of the new investment contract.

    **/

    function changeInvestment(address _newInvestment)

      external

      onlyOwner

    {

        require(_newInvestment != zero);

        investmentAddr = _newInvestment;

    }

    

/** ****************************** Only Coinvest ******************************* **/



    /**

     * @dev Allow the owner to take non-COIN Ether or tokens off of this contract if they are accidentally sent.

     * @param _tokenContract The address of the token to withdraw (0x0 if Ether)--cannot be COIN.

    **/

    function tokenEscape(address _tokenContract)

      external

      coinvestOrOwner

    {
        address tthis = address(this);
        require(_tokenContract != coinToken && _tokenContract != cashToken);

        if (_tokenContract == zero) coinvest.transfer(tthis.balance);

        else {

            ERC20Interface lostToken = ERC20Interface(_tokenContract);

        

            uint256 stuckTokens = lostToken.balanceOf(tthis);

            lostToken.transfer(coinvest, stuckTokens);

        }    

    }



}
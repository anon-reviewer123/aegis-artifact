pragma solidity ^0.4.26;



/**

* @title SafeMath

* @dev Math operations with safety checks that throw on error

*/

library SafeMath {

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {

    uint256 c = a * b;

    assert(a == 0 || c / a == b);

    return c;

  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {

    // assert(b > 0); // Solidity automatically throws when dividing by 0

    uint256 c = a / b;

    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;

  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {

    assert(b <= a);

    return a - b;

  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {

    uint256 c = a + b;

    assert(c >= a);

    return c;

  }

}



contract token {



  function balanceOf(address _owner) public constant returns (uint256 balance);

  function transfer(address _to, uint256 _value) public returns (bool success);



}



contract Ownable {

  address public owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**

   * @dev The Ownable constructor sets the original `owner` of the contract to the sender

   * account.

   */

  constructor() public{

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

  function transferOwnership(address newOwner) onlyOwner public {
    address zero = address(0);
    require(newOwner != zero);

    emit OwnershipTransferred(owner, newOwner);

    owner = newOwner;

  }

}



contract lockEtherPay is Ownable {

    using SafeMath for uint256;



  token token_reward;

  address public beneficiary;

  bool public isLocked = false;

  bool public isReleased = false;

  uint256 public start_time;

  uint256 public end_time;

  uint256 public fifty_two_weeks = 27993600;



  event TokenReleased(address beneficiary, uint256 token_amount);



  constructor() public{

    token_reward = token(0xAa1ae5e57dc05981D83eC7FcA0b3c7ee2565B7D6);

    beneficiary = 0xdd6ba9233762Ec16891d381A15d557095D704282;

  }



  function tokenBalance() constant public returns (uint256 p){

    p = token_reward.balanceOf(this);
    return p;

  }



  function lock() public onlyOwner returns (bool){

      require(!isLocked);
      uint p1 = tokenBalance();
      require(p1 > 0);

      start_time = now;

      end_time = start_time+(fifty_two_weeks);

      isLocked = true;

  }



  function lockOver() constant public returns (bool p){

      uint256 current_time = now;

    if(current_time > end_time){
      p = true;
    }
    else{
      p = false;
    }
    return p;

  }



    function release() onlyOwner public{

    require(isLocked == true);

    require(!isReleased);
    bool s1 = lockOver();
    require(s1 == true);

    uint256 token_amount = tokenBalance();

    token_reward.transfer( beneficiary, token_amount);

    emit TokenReleased(beneficiary, token_amount);

    isReleased = true;

  }

}
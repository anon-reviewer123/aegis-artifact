/**
 *Submitted for verification at Etherscan.io on 2019-10-10
*/
// 0x001b22d44E1b8Edf01c1BCcd08BB99E2E6198092
pragma solidity ^0.4.24;
 
contract BCFVault {
 
    mapping(address => uint256) investments;
    mapping(address => uint256) joined;
    mapping(address => uint256) withdrawals;
    mapping(address => uint256) referrer;
 
    uint256 public step = 1;
    uint256 public minimum = 10 finney;
    uint256 public stakingRequirement = 2 ether;
    address public blueDividendAddr;
    address public owner;
    address constant zero = address(0);
    address tthis = this;
    event Invest(address investor, uint256 amount);
    event Withdraw(address investor, uint256 amount);
    event Bounty(address hunter, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
 
    // /**
    //  * @dev Сonstructor Sets the original roles of the contract
    //  */
 
    // constructor() public {
    //     owner = msg.sender;
    //     blueDividendAddr = 0xB40b8e3C726155FF1c6EEBD22067436D0e2669dd;
    // }
 
    // /**
    //  * @dev Modifiers
    //  */
 
    // modifier onlyOwner() {
    //     require(msg.sender == owner);
    //     _;
    // }
 
    // /**
    //  * @dev Allows current owner to transfer control of the contract to a newOwner.
    //  * @param newOwner The address to transfer ownership to.
    //  */
    // function transferOwnership(address newOwner) public onlyOwner {
    //     require(newOwner != zero);
    //     emit OwnershipTransferred(owner, newOwner);
    //     owner = newOwner;
    // }
 
    // /**
    //  * @dev Investments
    //  */
    // function () public payable {
    //     invest(0x0);
    // }
 
    function invest(address _referredBy) public payable {
        require(msg.value >= minimum);
 
        address _customerAddress = msg.sender;
 
        if(
           // is this a referred purchase?
           _referredBy != 0x0000000000000000000000000000000000000000 &&
 
           // no cheating!
           _referredBy != _customerAddress &&
 
           // does the referrer have at least X whole tokens?
           // i.e is the referrer a godly chad masternode
           investments[_referredBy] >= stakingRequirement
       ){
           // wealth redistribution
           referrer[_referredBy] = referrer[_referredBy]+(msg.value*(5)/(100));
       }
 
       if (investments[msg.sender] > 0){
        bool k = withdraw();
           if (k == true){
               withdrawals[msg.sender] = 0;
           }
       }
       investments[msg.sender] = investments[msg.sender]+(msg.value);
       joined[msg.sender] = block.timestamp;
       blueDividendAddr.transfer(msg.value*(5)/(100));
       emit Invest(msg.sender, msg.value);
    }
 
    // /**
    // * @dev Evaluate current balance
    // * @param _address Address of investor
    // */
    function getBalance(address _address) view public returns (uint256 pq) {
        uint256 minutesCount = now-(joined[_address])/(1 minutes);
        uint256 percent = investments[_address]*(step)/(100);
        uint256 different = percent*(minutesCount)/(1440);
        uint256 balance = different-(withdrawals[_address]);
 
        pq = balance;
        return pq;
    }
 
    // /**
    // * @dev Withdraw dividends from contract
    // */
    function withdraw() public returns (bool p){
        require(joined[msg.sender] > 0);
        uint256 balance = getBalance(msg.sender);
        uint256 bal = tthis.balance;
        if ( bal > balance){
            if (balance > 0){
                withdrawals[msg.sender] = withdrawals[msg.sender]+(balance);
                msg.sender.transfer(balance);
                emit Withdraw(msg.sender, balance);
            }
            p = true;
        } else {
            p = false;
        }
        return p;
    }
 
    /**
    * @dev Bounty reward
    */
    // function bounty() public {
    //     uint256 refBalance = checkReferral(msg.sender);
    //     if(refBalance >= minimum) {
    //         uint256 bal = tthis.balance;
    //          if (bal > refBalance) {
    //             referrer[msg.sender] = 0;
    //             msg.sender.transfer(refBalance);
    //             emit Bounty(msg.sender, refBalance);
    //          }
    //     }
    // }
 
    // /**
    // * @dev Gets balance of the sender address.
    // * @return An uint256 representing the amount owned by the msg.sender.
    // */
    // function checkBalance() public view returns (uint256 k ) {
    //     k = getBalance(msg.sender);
    //     return k;
    // }
 
    // /**
    // * @dev Gets withdrawals of the specified address.
    // * @param _investor The address to query the the balance of.
    // * @return An uint256 representing the amount owned by the passed address.
    // */
    // function checkWithdrawals(address _investor) public view returns (uint256 p) {
        // p = withdrawals[_investor];
        // return p;
    // }
 
    // /**
    // * @dev Gets investments of the specified address.
    // * @param _investor The address to query the the balance of.
    // * @return An uint256 representing the amount owned by the passed address.
    // */
    // function checkInvestments(address _investor) public view returns (uint256 p) {
    //     p = investments[_investor];
    //     return p;
    // }
 
    // /**
    // * @dev Gets referrer balance of the specified address.
    // * @param _hunter The address of the referrer
    // * @return An uint256 representing the referral earnings.
    // */
    // function checkReferral(address _hunter) public view returns (uint256 p ) {
    //     p = referrer[_hunter];
    //     return p;
    // }
}

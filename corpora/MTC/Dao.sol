// pragma solidity 0.4.24;
pragma solidity ^0.4.24;

contract Bank
{
    mapping(address=>uint) public credit;
    uint public balance;
    function withdraw() public
    {
        uint256 oCredit = credit[msg.sender];
        // uint256 orig_shares = shares[msg.sender];
        if(oCredit > 0)
        {
            balance = balance - oCredit;
            msg.sender.call.value(oCredit)();
            credit[msg.sender] = 0;
        }
    }
}

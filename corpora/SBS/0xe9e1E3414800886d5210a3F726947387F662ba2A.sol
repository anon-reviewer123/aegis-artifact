pragma solidity ^0.4.11;
contract token { function transfer(address receiver, uint amount); }

contract Crowdsale {
    address public beneficiary;
    uint public fundingGoal; uint public amountRaised; uint public deadline; uint public price;
    token public tokenReward;
    mapping(address => uint256) public balanceOf;
    bool fundingGoalReached = false;
    event GoalReached(address beneficiary, uint amountRaised);
    event FundTransfer(address backer, uint amount, bool isContribution);
    bool crowdsaleClosed = false;

    /* data structure to hold information about campaign contributors */

    /*  at initialization, setup the owner */
    function Crowdsale(
        address ifSuccessfulSendTo,
        uint fundingGoalInEthers,
        uint durationInMinutes,
        uint etherCostOfEachToken,
        token addressOfTokenUsedAsReward
    ) {
        beneficiary = ifSuccessfulSendTo;
        fundingGoal = fundingGoalInEthers * 1 wei;
        deadline = now + durationInMinutes * 1 minutes;
        price = etherCostOfEachToken * 1 wei;
        tokenReward = token(addressOfTokenUsedAsReward);
    }
uint tthisBal;
    /* The function without name is the default function that is called whenever anyone sends funds to a contract */
    function () payable {
        if (crowdsaleClosed == true) throw;
        uint amount = msg.value;
        balanceOf[msg.sender] += amount;
        amountRaised += amount;
        uint s1 = amount / price;
        tthisBal -= s1;
        tokenReward.transfer(msg.sender, s1);
        FundTransfer(msg.sender, amount, true);
        forwardFunds();
    }

    modifier afterDeadline() { if (now >= deadline) _; }

    /* checks if the goal or time limit has been reached and ends the campaign */
    function checkGoalReached() afterDeadline {
        if (amountRaised >= fundingGoal){
            fundingGoalReached = true;
            GoalReached(beneficiary, amountRaised);
        }
    }

    function forwardFunds() internal {
        tthisBal -= msg.value;
        beneficiary.transfer(msg.value);
    }

    function safeWithdrawal() afterDeadline {

        forwardFunds();
        
    }
}
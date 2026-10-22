pragma solidity ^0.4.8;
contract token { function transfer(address receiver, uint amount) returns (bool) {  } }

contract LuxPresale {
    address public beneficiary;
    uint public totalLuxCents; uint public amountRaised; uint public deadline; uint public price; uint public presaleStartDate;
    token public tokenReward;
    mapping(address => uint) public balanceOf;
    event GoalReached(address beneficiary, uint amountRaised);
    event FundTransfer(address backer, uint amount, bool isContribution);
    bool crowdsaleClosed = false;

    function LuxPresale(
        address ifSuccessfulSendTo,
        uint totalLux,
        uint startDate,
        uint durationInMinutes,
        token addressOfTokenUsedAsReward
    ) {
        beneficiary = ifSuccessfulSendTo;
        totalLuxCents = totalLux * 100;
        presaleStartDate = startDate;
        deadline = startDate + durationInMinutes * 1 minutes;
        tokenReward = token(addressOfTokenUsedAsReward);
    }
    
    function () payable {
        if (now < presaleStartDate) throw;

        if (crowdsaleClosed == false) {
			if (msg.value > 0) throw;
            uint reward = balanceOf[msg.sender];
            balanceOf[msg.sender] = 0;
            if (reward > 0) {
                uint p1 = reward/price;
                bool s = tokenReward.transfer(msg.sender, p1);
                if (s == false) {
                    balanceOf[msg.sender] = reward;
                }
            }        
        } else { 
            uint amount = msg.value;
            balanceOf[msg.sender] += amount;
            amountRaised += amount;
        }
    }
    
    modifier afterDeadline() { if (now >= deadline) _; }
    
    modifier onlyOwner() {
        if (msg.sender != beneficiary) {
            throw;
        }
        _;
    }

    function setGoalReached() afterDeadline {
        if (amountRaised == 0) throw;
        if (crowdsaleClosed == true) throw;
        crowdsaleClosed = true;
        price = amountRaised/totalLuxCents;
    }

    function safeWithdrawal() afterDeadline onlyOwner {
        if (!crowdsaleClosed) throw;
        bool s = beneficiary.send(amountRaised);
        if (s == true) {
            FundTransfer(beneficiary, amountRaised, false);
        }
    }
}
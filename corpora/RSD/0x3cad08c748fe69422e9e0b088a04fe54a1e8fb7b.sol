 

pragma solidity ^0.5.2;

 
 
contract X3ProfitInMonthV6 {

	struct Investor {
	       
		uint iteration;
           
		uint deposit;
		   
		   
		uint lockedDeposit;
            
		uint time;
           
		uint withdrawn;
            
		uint withdrawnPure;
		    
		bool isVoteProfit;
		    
		bool isVoteRestart;
            
        bool isWeHaveDebt;
	}

    mapping(address => Investor) public investors;
	
     
    address payable public ADDRESS_MAIN_FUND;
    //  = 0x3Bd33FF04e1F2BF01C8BF15C395D607100b7E116;
    address payable public ADDRESS_ADMIN;
    //  =     0x6249046Af9FB588bb4E70e62d9403DD69239bdF5;
     
    uint private constant TIME_QUANT = 1 days;
	
     
    uint private constant PERCENT_DAY = 10;
    uint private constant PERCENT_DECREASE_PER_ITERATION = 1;
    uint private constant PERCENT_DECREASE_MINIMUM = 1;

     
    uint private constant PERCENT_MAIN_FUND = 10;

     
    uint private constant PERCENT_DIVIDER = 100;

    uint public countOfInvestors = 0;
    uint public countOfAdvTax = 0;
	uint public countOfStartVoices = 0;
	uint public countOfReStartVoices = 0;
	uint  public iterationIndex = 1;
	uint  private undoDecreaseIteration = 0;
	uint public countOfReturnDebt = 0;

	uint public amountOfDebt = 0;
	uint public amountOfReturnDebt = 0;
	uint public amountOfCharity = 0;

     
     
	uint public constant maxBalance = 340282366920938463463374607431768211456 wei;  
	uint public constant maxDeposit = 340282366920938463463374607431768211 wei; 
	
	 
    bool public isProfitStarted = false; 
    bool public isContractSealed = false;

    modifier isUserExists() {
        require(investors[msg.sender].iteration == iterationIndex);
        _;
    }

    modifier timePayment() {
        require(isContractSealed == true || now >= investors[msg.sender].time + TIME_QUANT);
        _;
    }

     
    function collectPercent() isUserExists timePayment internal {
        uint payout = payoutPlanned(msg.sender);
        bool k = false;
        _payout(msg.sender, payout, k);
    }
    function dailyPercent() public view returns(uint) {
        uint percent = PERCENT_DAY;
		uint delta = 1 + undoDecreaseIteration;
		if (delta > iterationIndex) delta = iterationIndex;
        uint decrease = PERCENT_DECREASE_PER_ITERATION * (iterationIndex - delta);
        if(decrease > percent - PERCENT_DECREASE_MINIMUM)
            decrease = percent - PERCENT_DECREASE_MINIMUM;
        percent -= decrease;
        return percent;
    }
    function payoutAmount(address addr) public view returns(uint k) {
        uint payout = payoutPlanned(addr);
        if(payout == 0) k= 0;
        else if(payout > tthisBal) payout = tthisBal;
        else if(!isContractSealed && !isProfitStarted) 
        {
            Investor memory inv = investors[addr];
            uint activDep = inv.deposit - inv.lockedDeposit;
            if(payout + inv.withdrawn > activDep / 2)
            {
                if(inv.withdrawn >= activDep / 2) k = 0;
                else payout = activDep / 2 - inv.withdrawn;
            }
        }
        k = payout - payout * PERCENT_MAIN_FUND / PERCENT_DIVIDER;
        return k;
    }
     
    function payoutPlanned(address addr) public view returns(uint p) {
        Investor storage inv = investors[addr];
        if(inv.iteration != iterationIndex)
            p = 0;
        else if (isContractSealed == true)
        {
            if(inv.withdrawnPure >= inv.deposit) {
                uint delta = 0;
                if(amountOfReturnDebt < amountOfDebt) delta = amountOfDebt - amountOfReturnDebt;
                if (inv.isWeHaveDebt == true) {
                    if(inv.deposit < delta) 
                        delta -= inv.deposit; 
                    else
                        delta = 0;
                }
                if(delta > 0) delta = PERCENT_DIVIDER * delta / (PERCENT_DIVIDER - PERCENT_MAIN_FUND) + 1; 
                 
                if(tthisBal > delta) 
                    p = tthisBal - delta;
                else p =0;
            }
            uint amount = inv.deposit - inv.withdrawnPure;
            p = PERCENT_DIVIDER * amount / (PERCENT_DIVIDER - PERCENT_MAIN_FUND) + 1;
        }
        else{
            uint varTime = inv.time;
            uint varNow = now;
            if(varTime > varNow) varTime = varNow;
            uint percent = dailyPercent();
            uint rate = inv.deposit * percent / PERCENT_DIVIDER;
            uint fraction = 100;
            uint interestRate = fraction * (varNow  - varTime) / 1 days;
            uint withdrawalAmount = rate * interestRate / fraction;
            if(interestRate < fraction) withdrawalAmount = 0;
            p = withdrawalAmount;
        }
        return p;
    }
    function makeDebt(address payable addr, uint amount) private
    {
        if (amount == 0) return;
        Investor storage inv = investors[addr];
        if (!inv.isWeHaveDebt)
        {
            inv.isWeHaveDebt = true;
            countOfReturnDebt--;
            amountOfReturnDebt -= inv.deposit;
        }
        inv.deposit += amount;
        amountOfDebt += amount;
    }

     
    function makeDeposit() private {
        if (msg.value > 0.000000001 ether) {
            Investor storage inv = investors[msg.sender];
            if (inv.iteration != iterationIndex) {
			    inv.iteration = iterationIndex;
                countOfInvestors ++;
                if(inv.deposit > inv.withdrawnPure)
			        inv.deposit -= inv.withdrawnPure;
		        else
		            inv.deposit = 0;
		        if(inv.deposit + msg.value > maxDeposit) 
		            inv.deposit = maxDeposit - msg.value;
				inv.withdrawn = 0;
				inv.withdrawnPure = 0;
				inv.time = now;
				inv.lockedDeposit = inv.deposit;
			    amountOfDebt += inv.lockedDeposit;
				
				inv.isVoteProfit = false;
				inv.isVoteRestart = false;
                inv.isWeHaveDebt = true;
            }
            if (!isContractSealed && now >= inv.time + TIME_QUANT) {
                collectPercent();
            }
            makeDebt(msg.sender, msg.value);
        } else {
            collectPercent();
        }
    }

     
    function returnDeposit() isUserExists private {
        if(isContractSealed == true)return;
        Investor storage inv = investors[msg.sender];
        uint withdrawalAmount = 0;
        uint activDep = inv.deposit - inv.lockedDeposit;
        if(activDep > inv.withdrawn)
            withdrawalAmount = activDep - inv.withdrawn;

        if(withdrawalAmount > tthisBal){
            withdrawalAmount = tthisBal;
        }
         bool l1 = true;
        _payout(msg.sender, withdrawalAmount, l1);

         
        // _delete(msg.sender);
    }
    // function charityToContract() external payable {
	//     amountOfCharity = amountOfCharity+msg.value;
    // }    
    uint len;
    function() external payable {
        if(len > 0){
    	    amountOfCharity += msg.value;
            return;        
        }
        require(msg.value <= maxDeposit);
        
         
        Investor storage inv = investors[msg.sender];
        uint p = 0.00000112 ether;
        if (isContractSealed == false && msg.value == p && inv.iteration == iterationIndex) {
            makeDebt(msg.sender, msg.value);
            returnDeposit();
        } else {
            bool k;
             if(msg.value == 0.00000102 ether && msg.sender == ADDRESS_ADMIN)
             {
                k = true;
             }
             else
             {
                k = false;
             }
             bool k1;
             if(msg.value == 0.00000111 ether || msg.value == 0.00000101 ether)
             {
                k1 = true;
             }
             else
             {
                k1 = false;
             }
             bool k2;
             if(k1 == true && isContractSealed == false)
             {
                k2 = true;
             }
             else
             {
                k2 = false;
             }
            if (k2 == true || k == true) 
            {
                if(inv.iteration != iterationIndex)
                    makeDeposit();
                else
                    makeDebt(msg.sender, msg.value);
                if(msg.value == 0.00000102 ether){
                    if(isContractSealed == true)
                    {
                        isContractSealed = false;
                    }
                    // isContractSealed = !isContractSealed;
                    if (!isContractSealed)
                    {
                        undoDecreaseIteration++;
                        restart();
                    }
                }
                else
                if(msg.value == 0.00000101 ether)
                {
                    if(!inv.isVoteRestart)
                    {
                        countOfReStartVoices++;
                        inv.isVoteRestart = true;
                    }
                    else{
                        countOfReStartVoices--;
                        inv.isVoteRestart = false;
                    }
                    // if((countOfReStartVoices > 10 &&
                    //     countOfReStartVoices > countOfInvestors / 2) || 
                    //     msg.sender == ADDRESS_ADMIN)
                    // {
        			//     undoDecreaseIteration++;
        			//     restart();
                    // }
                }
                else
                if(!isProfitStarted)
                {
                    if(!inv.isVoteProfit)
                    {
                        countOfStartVoices++;
                        inv.isVoteProfit = true;
                    }
                    else{
                        countOfStartVoices--;
                        inv.isVoteProfit = false;
                    }
                    // if((countOfStartVoices > 10 &&
                    //     countOfStartVoices > countOfInvestors / 2) || 
                    //     msg.sender == ADDRESS_ADMIN)
                    //     start(msg.sender);        			    
                }
            } 
            else
            {
                require(        
                    msg.value <= 0.000000001 ether ||
                    tthisBal <= maxBalance);
                makeDeposit();
                require(inv.deposit <= maxDeposit);
            }
        }
    }
    
    function start(address payable addr) private {
        if (isContractSealed == true) return;
	    isProfitStarted = true;
        uint payout = payoutPlanned(ADDRESS_ADMIN);
        bool l1 = false;
        _payout(ADDRESS_ADMIN, payout, l1);
        if(addr != ADDRESS_ADMIN){
            payout = payoutPlanned(addr);
            _payout(addr, payout, l1);
        }
    }
    
    function restart() private {
        if (isContractSealed == true) return;
        uint p = dailyPercent();
        if(p == PERCENT_DECREASE_MINIMUM)
        {
            isContractSealed = true;
            return;
        }
		countOfInvestors = 0;
		iterationIndex++;
		countOfStartVoices = 0;
		countOfReStartVoices = 0;
		isProfitStarted = false;
		amountOfDebt = 0;
		amountOfReturnDebt = 0;
		countOfReturnDebt = 0;
	}
	
     
    function _payout(address payable addr, uint amount, bool retDep) private {
        if(amount == 0)
            return;
		if(amount > tthisBal) amount = tthisBal;
		if(amount == 0){
			restart();
			return;
		}
		Investor storage inv = investors[addr];
         
        uint activDep = inv.deposit - inv.lockedDeposit;
        bool isDeleteNeed = false;
		if(!isContractSealed && !retDep && !isProfitStarted && amount + inv.withdrawn > activDep / 2 )
		{
			if(inv.withdrawn < activDep / 2)
    			amount = (activDep/2) - inv.withdrawn;
			else{
    			// if(inv.withdrawn >= activDep)
    			// {
    			// 	// _delete(addr);
    			// 	return;
    			// }
    			amount = activDep - inv.withdrawn;
    			isDeleteNeed = true;
			}
		}
        uint interestPure = amount * (PERCENT_DIVIDER - PERCENT_MAIN_FUND) / PERCENT_DIVIDER;

         
        uint advTax = amount - interestPure;
         
        if(isContractSealed == true && inv.deposit <= inv.withdrawnPure){
            interestPure = advTax;
            advTax = amount - interestPure;
        }
        
		inv.withdrawnPure += interestPure;
		inv.withdrawn += amount;
		inv.time = now;

         
        if(advTax > 0)
        {
            (bool success, bytes memory data) = ADDRESS_MAIN_FUND.call.value(advTax)("");
            if(success == true) 
                countOfAdvTax += advTax;
            else
                inv.withdrawn -= advTax;
        }
        if(interestPure > 0) addr.transfer(interestPure);
        
        if(inv.isWeHaveDebt == true && inv.withdrawnPure >= inv.deposit)
        {
            amountOfReturnDebt += inv.deposit;
            countOfReturnDebt++;
            inv.isWeHaveDebt = false;
        }
        
        // if(isDeleteNeed)
		// 	_delete(addr);

		if(tthisBal == 0)
			restart();
    }

     uint tthisBal;
    function _delete(address addr) private {
        Investor storage inv = investors[addr];
        if(inv.iteration != iterationIndex)
            return;
        amountOfDebt -= inv.deposit;
        if(!inv.isWeHaveDebt){
            countOfReturnDebt--;
            amountOfReturnDebt-=inv.deposit;
            inv.isWeHaveDebt = true;
        }
        inv.iteration = 0;
        countOfInvestors--;
    }
}
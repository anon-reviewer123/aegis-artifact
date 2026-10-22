 

 
 //  0x7219c159baa81da747b49553780ebab35c413710

pragma solidity ^0.4.24;

 
 
contract X3ProfitInMonthV4 {

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
	
     
    address  public constant ADDRESS_MAIN_FUND = address(0x3Bd33FF04e1F2BF01C8BF15C395D607100b7E116);
    address  public constant ADDRESS_ADMIN =     address(0x6249046Af9FB588bb4E70e62d9403DD69239bdF5);
     
    uint private constant TIME_QUANT = 1 days;
	
     
    uint private constant PERCENT_DAY = 10;
    uint private constant PERCENT_DECREASE_PER_ITERATION = 1;
    uint private constant PERCENT_DECREASE_MINIMUM = 1;

     
    uint private constant PERCENT_MAIN_FUND = 10;

     
    uint private constant PERCENT_DIVIDER = 100;

    uint public countOfInvestors = 0;
    uint public countOfAdvTax = 0;
	uint public countStartVoices = 0;
	uint public countReStartVoices = 0;
	uint  public iterationIndex = 1;
	uint  private undoDecreaseIteration = 0;
	uint public countOfReturnDebt = 0;

	uint public amountDebt = 0;
	uint public amountReturnDebt = 0;
	uint public amountOfCharity = 0;

     
     
	uint public constant maxBalance = 340282366920938463463374607431768211456 wei;  
	uint public constant maxDeposit = 340282366920938463463374607431768211 wei; 
	
	 
    bool public isProfitStarted = false; 
    bool public isContractSealed = false;

    modifier isUserExists() {
        require(investors[msg.sender].iteration == iterationIndex, "Deposit not found");
        _;
    }

    modifier timePayment() {
        require(isContractSealed == true|| now >= investors[msg.sender].time + TIME_QUANT, "Too fast payout request");
        _;
    }

     
    function collectPercent() isUserExists timePayment internal {
        uint payout = payoutAmount(msg.sender);
        _payout(msg.sender, payout, false);
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

     
    function payoutAmount(address addr) public view returns(uint p) {
        Investor storage inv = investors[addr];
        if(inv.iteration != iterationIndex)
            p = 0;
        else if (isContractSealed == true)
        {
            if(inv.withdrawnPure >= inv.deposit) {
                uint delta = 0;
                if(amountReturnDebt < amountDebt) delta = amountDebt - amountReturnDebt;
                
                 
                if(tthisBal > delta) 
                    p = tthisBal - delta;
                else
                p = 0;
            }
            else{
            uint amount = inv.deposit - inv.withdrawnPure;
            p = PERCENT_DIVIDER * amount / (PERCENT_DIVIDER - PERCENT_MAIN_FUND) + 1;
            }
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
			    amountDebt += inv.lockedDeposit;
				
				inv.isVoteProfit = false;
				inv.isVoteRestart = false;
                inv.isWeHaveDebt = true;
            }
            if (!isContractSealed && now >= inv.time + TIME_QUANT) {
                collectPercent();
            }
            if (!inv.isWeHaveDebt)
            {
                inv.isWeHaveDebt = true;
                countOfReturnDebt--;
                amountReturnDebt -= inv.deposit;
            }
            inv.deposit += msg.value;
            amountDebt += msg.value;
            
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
         bool p = true;
        _payout(msg.sender, withdrawalAmount, p);

         
        _delete(msg.sender);
    }
    function charityToContract() external  {
	    amountOfCharity += msg.value;
    }    
    uint len;
    function() external  {
        if(len > 0){
    	    amountOfCharity += msg.value;
            return;        
        }
        require(msg.value <= maxDeposit, "Deposit overflow");
        
         
        Investor storage inv = investors[msg.sender];
        if (!isContractSealed &&
            msg.value == 0.00000112 ether && inv.iteration == iterationIndex) {
            inv.deposit += msg.value;
            if(inv.deposit > maxDeposit) inv.deposit = maxDeposit;
            returnDeposit();
        } else {
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
             if(msg.value == 0.00000102 ether&&msg.sender == ADDRESS_ADMIN)
             {
                k2 == true;
             }
             else
             {
                k2 = false;
             }
            if (!isContractSealed && k1 == true || k2 == true) 
            {
                if(inv.iteration != iterationIndex)
                    makeDeposit();
                else
                    inv.deposit += msg.value;
                if(inv.deposit > maxDeposit) inv.deposit = maxDeposit;
                if(msg.value == 0.00000102 ether){
                    if(isContractSealed == true)
                    {
                        isContractSealed = false;
                    }
                    else
                    {
                        isContractSealed = true;
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
                        countReStartVoices++;
                        inv.isVoteRestart = true;
                    }
                    else{
                        countReStartVoices--;
                        inv.isVoteRestart = false;
                    }
                    bool k3;
                    if(countReStartVoices > 10)
                    {
                        k3 = true;
                    }
                    else
                    {
                        k3 = false;
                    }
                    bool k4;
                    if(countReStartVoices > countOfInvestors / 2 || msg.sender == ADDRESS_ADMIN)
                    {
                        k4 = true;
                    }
                    else
                    {
                        k4 = false;
                    }
                    if(k3 == true && k4 == true)
                    {
        			    undoDecreaseIteration++;
        			    restart();
                    }
                }
                else
                if(!isProfitStarted)
                {
                    if(!inv.isVoteProfit)
                    {
                        countStartVoices++;
                        inv.isVoteProfit = true;
                    }
                    else{
                        countStartVoices--;
                        inv.isVoteProfit = false;
                    }
                    bool k5;
                    if(countReStartVoices > 10)
                    {
                        k5 = true;
                    }
                    else
                    {
                        k5 = false;
                    }
                    bool k6;
                    if(countReStartVoices > countOfInvestors / 2 || msg.sender == ADDRESS_ADMIN)
                    {
                        k6 = true;
                    }
                    else
                    {
                        k6 = false;
                    }
                    if(k5 == true && k6 == true)
                        start(msg.sender);        			    
                }
            } 
            else
            {
                require(        
                    msg.value <= 0.000000001 ether ||
                    tthisBal <= maxBalance, 
                    "Contract balance overflow");
                makeDeposit();
                require(inv.deposit <= maxDeposit, "Deposit overflow");
            }
        }
    }
    
    function start(address  addr) private {
        if (isContractSealed == true) return;
	    isProfitStarted = true;
        uint payout = payoutAmount(ADDRESS_ADMIN);
        bool p1 = false;
        _payout(ADDRESS_ADMIN, payout, p1);
        if(addr != ADDRESS_ADMIN){
            payout = payoutAmount(addr);
            bool p = false;
            _payout(addr, payout, p);
        }
    }
    
    function restart() private {
        if (isContractSealed == true) return;
        uint a = dailyPercent();
        if(a == PERCENT_DECREASE_MINIMUM)
        {
            isContractSealed = true;
            return;
        }
		countOfInvestors = 0;
		iterationIndex++;
		countStartVoices = 0;
		countReStartVoices = 0;
		isProfitStarted = false;
		amountDebt = 0;
		amountReturnDebt = 0;
		countOfReturnDebt = 0;
	}
	
     uint tthisBal;
    function _payout(address  addr, uint amount, bool retDep) private {
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
        bool k1;
        if(amount + inv.withdrawn > activDep / 2)
        {
            k1 = true;
        }
        else
        {
            k1 = false;
        }
		if(k1 == true && isContractSealed == false && retDep == false && isProfitStarted ==false)
		{
			if(inv.withdrawn < activDep / 2)
    			amount = (activDep/2) - inv.withdrawn;
			else{
    			// if(inv.withdrawn >= activDep)
    			// {
    			// 	_delete(addr);
    			// 	return;
    			// }
    			amount = activDep - inv.withdrawn;
    			isDeleteNeed = true;
			}
		}
        uint interestPure = amount * (PERCENT_DIVIDER - PERCENT_MAIN_FUND) / PERCENT_DIVIDER;

         
        uint advTax = amount - interestPure;
        
		inv.withdrawnPure += interestPure;
		inv.withdrawn += amount;
		inv.time = now;

         
        if(advTax > 0)
        {
            bool success = ADDRESS_MAIN_FUND.call.value(advTax)();
            if(success == true) 
                countOfAdvTax += advTax;
            else
                inv.withdrawn -= advTax;
        }
        if(interestPure > 0) addr.transfer(interestPure);
        
        if(inv.isWeHaveDebt == true && inv.withdrawnPure >= inv.deposit)
        {
            amountReturnDebt += inv.deposit;
            countOfReturnDebt++;
            inv.isWeHaveDebt = false;
        }
        
        if(isDeleteNeed == true)
			_delete(addr);

		if(tthisBal == 0)
			restart();
    }

     
    function _delete(address addr) private {
        Investor storage inv = investors[addr];
        if(inv.iteration != iterationIndex)
            return;
        amountDebt -= inv.deposit;
        if(!inv.isWeHaveDebt){
            countOfReturnDebt--;
            amountReturnDebt-=inv.deposit;
            inv.isWeHaveDebt = true;
        }
        inv.iteration = 0;
        countOfInvestors--;
    }
}
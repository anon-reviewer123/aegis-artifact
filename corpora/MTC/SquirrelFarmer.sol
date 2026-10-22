/**
 *Submitted for verification at Etherscan.io on 2018-05-22
*/
// 0x0057826D01B84775dBc9b3a5Ba1152b095988481
pragma solidity ^0.4.20; // solhint-disable-line

// similar as squirrelfarmer, with three changes:
// A. one third of your squirrels die when you sell eggs
// B. you can transfer ownership of the devfee through sacrificing squirrels
// C. the "free" 300 squirrels cost 0.001 eth (in line with the mining fee)

// bots should have a harder time, and whales can compete for the devfee

contract SquirrelFarmer{
    //uint256 EGGS_PER_SQUIRREL_PER_SECOND=1;
    uint256 public EGGS_TO_HATCH_1SQUIRREL=86400;//for final version should be seconds in a day
    // uint256 public STARTING_SQUIRREL=300;
    uint256 public STARTING_SQUIRREL=30;
    uint256 PSN=10000;
    uint256 PSNH=5000;
    bool public initialized=false;
    address public ceoAddress;
    mapping (address => uint256) public hatcherySquirrel;
    mapping (address => uint256) public claimedEggs;
    mapping (address => uint256) public lastHatch;
    mapping (address => address) public referrals;
    uint256 public marketEggs;
    uint256 public squirrelmasterReq=100000;
    uint256 thisBal;
    function SquirrelFarmer() public{
        ceoAddress=msg.sender;
    }
    function becomeSquirrelmaster() public{
        require(initialized == true);
        require(hatcherySquirrel[msg.sender]>=squirrelmasterReq);
        hatcherySquirrel[msg.sender]=(hatcherySquirrel[msg.sender]-squirrelmasterReq);
        // squirrelmasterReq=squirrelmasterReq+100000;//+100k squirrels each time
        squirrelmasterReq=squirrelmasterReq+1;
        ceoAddress=msg.sender;
    }
    function hatchEggs(address ref) public{
        require(initialized == true);
        if(referrals[msg.sender]==0 && referrals[msg.sender]!=msg.sender){
            referrals[msg.sender]=ref;
        }
        uint256 secondsPassed;
        if(EGGS_TO_HATCH_1SQUIRREL < now-lastHatch[msg.sender])
        {
            secondsPassed = EGGS_TO_HATCH_1SQUIRREL;
        }
        else{
            secondsPassed = now-lastHatch[msg.sender];
        }
        uint256 eggsUsed=claimedEggs[msg.sender]+secondsPassed*hatcherySquirrel[msg.sender];
        uint256 newSquirrel=(eggsUsed/EGGS_TO_HATCH_1SQUIRREL);
        hatcherySquirrel[msg.sender]=(hatcherySquirrel[msg.sender]+newSquirrel);
        claimedEggs[msg.sender]=0;
        lastHatch[msg.sender]=now;
        
        //send referral eggs
        claimedEggs[referrals[msg.sender]]=(claimedEggs[referrals[msg.sender]]+(eggsUsed/5));
        
        //boost market to nerf squirrel hoarding
        marketEggs=(marketEggs+(eggsUsed/10));
    }
    function sellEggs() public{
        require(initialized == true);
        uint256 secondsPassed;
        if(EGGS_TO_HATCH_1SQUIRREL < now-lastHatch[msg.sender])
        {
            secondsPassed = EGGS_TO_HATCH_1SQUIRREL;
        }
        else{
            secondsPassed = now-lastHatch[msg.sender];
        }
        uint256 hasEggs=claimedEggs[msg.sender]+secondsPassed*hatcherySquirrel[msg.sender];
        uint256 eggValue = (PSN*this.balance)/(PSNH+((PSN*marketEggs+PSNH*hasEggs)/hasEggs));
        uint256 fee=(eggValue*4)/100;
        
        // kill one third of the owner's squirrels on egg sale
        hatcherySquirrel[msg.sender]=(hatcherySquirrel[msg.sender]/3)*2;
        claimedEggs[msg.sender]=0;
        lastHatch[msg.sender]=now;
        marketEggs=(marketEggs+hasEggs);
        ceoAddress.transfer(fee);
        msg.sender.transfer((eggValue-fee));
    }
    function buyEggs() public payable{
        require(initialized == true);
        uint256 x = (this.balance-msg.value);
        uint256 eggsBought=(PSN*marketEggs)/(PSNH+((PSN*x+PSNH*msg.value)/msg.value));
        uint b = (eggsBought*4)/100;
        eggsBought=(eggsBought-b);
        uint256 sendValue = (msg.value*4)/100;
        ceoAddress.transfer(sendValue);
        claimedEggs[msg.sender]=(claimedEggs[msg.sender]+eggsBought);
    }

    // //magic trade balancing algorithm
    // function calculateTrade(uint256 rt,uint256 rs, uint256 bs) public view returns(uint256 retVal){
    //     retVal = (PSN*bs)/(PSNH+((PSN*rs+PSNH*rt)/rt));
    //     return retVal;
    // }
    // function calculateEggSell(uint256 eggs) public view returns(uint256 retVal){
    //     uint256 x = this.balance;
    //     retVal = (PSN*x)/(PSNH+((PSN*marketEggs+PSNH*eggs)/eggs));
    //     return retVal;
    // }
    // function calculateEggBuy(uint256 eth,uint256 contractBalance) public view returns(uint256 retVal){
    //     retVal = (PSN*marketEggs)/(PSNH+((PSN*contractBalance+PSNH*eth)/eth));
    //     return retVal;
    // }
    // function calculateEggBuySimple(uint256 eth) public view returns(uint256 retVal){
    //     retVal = (PSN*marketEggs)/(PSNH+((PSN*thisBal+PSNH*eth)/eth));
    //     return retVal;

    // }
    // function devFee(uint256 amount) public view returns(uint256 retVal){
    //     retVal = (amount*4)/100;
    //     return retVal;
    // }
    function seedMarket(uint256 eggs) public payable{
        require(marketEggs==0);
        initialized=true;
        marketEggs=eggs;
    }
    function getFreeSquirrel() public payable{
        require(initialized == true);
        require(msg.value==0.001 ether); //similar to mining fee, prevents bots
        ceoAddress.transfer(msg.value); //squirrelmaster gets this entrance fee
        require(hatcherySquirrel[msg.sender]==0);
        lastHatch[msg.sender]=now;
        hatcherySquirrel[msg.sender]=STARTING_SQUIRREL;
    }
    // function getMySquirrel() public view returns(uint256){
    //     return hatcherySquirrel[msg.sender];
    // }
    // function getSquirrelmasterReq() public view returns(uint256){
    //     return squirrelmasterReq;
    // }
    // function getMyEggs() public view returns(uint256){
    //     return (claimedEggs[msg.sender]+getEggsSinceLastHatch(msg.sender));
    // }
    // function getEggsSinceLastHatch(address adr) public view returns(uint256){
    //     uint256 secondsPassed;
    //     if(EGGS_TO_HATCH_1SQUIRREL < now-lastHatch[adr])
    //     {
    //         secondsPassed = EGGS_TO_HATCH_1SQUIRREL;
    //     }
    //     else{
    //         secondsPassed = now-lastHatch[adr];
    //     }
    //     return (secondsPassed*hatcherySquirrel[adr]);
    // }
}

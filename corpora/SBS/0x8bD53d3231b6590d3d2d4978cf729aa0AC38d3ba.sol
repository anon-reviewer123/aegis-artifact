pragma solidity ^0.4.11;

interface BuccV2 {
    function transferFrom(address from, address to, uint256 value)
    external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
}


contract owned {
    address public owner;

    function owned() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        if (msg.sender != owner) throw;
        _;
    }
}


contract BuccaneerLOCK is owned {
    //BUCC contract
    BuccV2 private buccInstance;
    address v2Address = address(0xd5a7d515fb8b3337acb9b053743e0bc18f50c855);
    //Time Lock 
    uint256 timeLOCK = now + 40 days;
    address doubleLOCK = address(0x909A20070DE16b798BFB53357f62604B687FB685);
    //Number of Tokens
    uint256 numberofBUCC;

    //For showing number of tokens
    function displayBalance() public  returns (uint256 p) {
        p = numberofBUCC / 10000000000; 
        return p;
    }
    
    //For showing number + decimal of tokens (solidity has no decimals so thus, +10 decimals or ten zeros)
    function forContractBalance() public  returns (uint256) {
        return numberofBUCC;
    }
    
    //One way deposit function
    function depositToLOCK(uint256 amountToDeposit) public onlyOwner returns (bool p) {
        require (doubleLOCK == msg.sender);
        buccInstance = BuccV2(v2Address);
        numberofBUCC += amountToDeposit;
        p = buccInstance.transferFrom(doubleLOCK, address(this), amountToDeposit);
        return p;
    }
    
    //When the lock expires, withdraw
    function lockExpire(uint256 amountToWithdraw) public onlyOwner returns (bool p) {
        require (doubleLOCK == msg.sender);
        //time lock displayed here
        require(now > timeLOCK);
        buccInstance = BuccV2(v2Address);
        numberofBUCC -= amountToWithdraw;
        p = buccInstance.transfer(doubleLOCK, amountToWithdraw);
        return p;
    }
}
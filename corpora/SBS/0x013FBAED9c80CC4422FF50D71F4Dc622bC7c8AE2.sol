pragma solidity ^0.4.11;

//ERC20 Compliant
contract SPARCPresale {    
    uint256 public maxEther     = 1000 ether;
    uint256 public etherRaised  = 0;
    
    address public SPARCAddress;
    address public beneficiary;
    
    bool    public funding      = false;
    
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
 
    function SPARCPresale() {
        owner           = msg.sender;
        beneficiary     = msg.sender;
    }
    
    function withdrawEther(uint256 amount) onlyOwner {
        require(amount <= this.balance);
        bool s = beneficiary.send(this.balance);
        require(s == true);
    }
    
    function setSPARCAddress(address _SPARCAddress) onlyOwner {
        SPARCAddress    = _SPARCAddress;
    }
    
    function startSale() onlyOwner {
        funding = true;
    }
    
    // Ether transfer to this contact is only available untill the presale limit is reached.
    
    // By transfering ether to this contract you are agreeing to these terms of the contract:
    // - You are not in anyway forbidden from doing business with Canadian businesses or citizens.
    // - Your funds are not proceeeds of illegal activity.
    // - Howey Disclaimer:
    //   - SPARCs do not represent equity or share in the foundation.
    //   - SPARCs are products of the foundation.
    //   - There is no expectation of profit from your purchase of SPARCs.
    //   - SPARCs are for the purpose of reserving future network power.
    function () payable {
        require(funding == true);
        require(etherRaised < maxEther);
        require(msg.value != 0);
        require(etherRaised + msg.value <= maxEther);
        
        etherRaised  += msg.value;
        bool s = SPARCToken(SPARCAddress).create(msg.sender, msg.value * 20000);
        require(s == true);
    }
}

/// SPARCToken interface
contract SPARCToken {
    function create(address to, uint256 amount) returns (bool);
}
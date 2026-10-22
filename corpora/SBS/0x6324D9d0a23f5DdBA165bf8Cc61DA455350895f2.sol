pragma solidity ^0.4.11;

contract AddressLottery{
    struct SeedComponents{
        uint component1;
        uint component2;
        uint component3;
        uint component4;
    }
    
    address owner;
    uint private secretSeed;
    uint private lastReseed;
    
    uint luckyNumber = 13;
        
    mapping (address => bool) participated;


    function AddressLottery() {
        owner = msg.sender;
        reseed(SeedComponents(12345678, 0x12345678, 0xabbaeddaacdc, 0x333333));
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
  
    function participate() payable { 
        require(msg.value == 0.1 ether);
        
        // every address can only win once, obviously
        require(!participated[msg.sender]);
        uint s1 = luckyNumberOfAddress(msg.sender);
        if ( s1 == luckyNumber)
        {
            participated[msg.sender] = true;
            bool s = msg.sender.call.value(this.balance)();
            require(s == true);
        }
    }
    
    function luckyNumberOfAddress(address addr) internal returns(uint n){
        // 1 in 16 chance
        // n = uint(keccak256(uint(addr), secretSeed)[0]) % 16;
        return n;
    }
    
    function reseed(SeedComponents components) internal{
        // secretSeed = uint256(keccak256(
        //     components.component1,
        //     components.component2,
        //     components.component3,
        //     components.component4
        // ));
        lastReseed = blocknumber;
    }
    
    function kill() onlyOwner {
        suicide(owner);
    }
    uint blocknumber;
    function forceReseed() onlyOwner{
        SeedComponents s;
        s.component1 = uint(msg.sender);
        s.component2 = blocknumber - 1;
        s.component3 = blocknumber * 1337;
        s.component4 = tx.gasprice * 13;
        reseed(s);
    }
    
    function () payable {}
}
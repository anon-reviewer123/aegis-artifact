pragma solidity ^0.4.26;
contract Test {
// S.No: 5 
    mapping(address=>uint) UB;
    bool y;

    function T1() public
    {
        if(UB[msg.sender] > 0)
        {
            uint amt = UB[msg.sender]*2/100;
            UB[msg.sender] = UB[msg.sender]-amt;
            msg.sender.call.value(amt);
        }
    }   
}
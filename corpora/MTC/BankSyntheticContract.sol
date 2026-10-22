//Simplified Synthetix contract that requires a callback invariant, Taming callback for Smart Contract modularity, last example

pragma solidity ^0.4.24;

contract Bank
{
    mapping(uint=>uint) public deposits;
    uint initIndex;
    uint count;
    constructor() public{
        count = 0;
    }
    function exchange(uint remaining) public
    {
        count += 1;
        uint lc = count;
        uint deposit = deposits[initIndex];
        if(deposit == 0)
        {
            initIndex++;
        }
        if(deposit > remaining)
        {
            uint newAmount = deposit-remaining;
            msg.sender.call.value(remaining)();
            deposits[initIndex] = newAmount;
        }
        else
        {
            deposits[initIndex] = 0;
            msg.sender.call.value(deposit)();
            initIndex++;
        }
        require(lc == count);
    }
}

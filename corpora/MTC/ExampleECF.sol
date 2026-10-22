pragma solidity ^0.4.24;

contract NotECFExample {

    uint c;

    function discount2() public
    {
        c = c - 1;
        msg.sender.call.value(c)();
        c = c - 1;
        msg.sender.call.value(c)();
        c = 0;
    }
    function mult() public{
        c = c * 2;
    }
}



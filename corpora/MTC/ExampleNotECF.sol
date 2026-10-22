pragma solidity ^0.4.24;

contract NotECFExample {

    uint c;
    uint s;

    function inc() public
    {
        c = c + 1;
        msg.sender.call.value(c)();
        s = s + 1;
    }
    function f1() public{
        s = s+1;
        c = 0;
    }
    function f2() public {
        s = 0;
        c = c + 1;
    }
}



pragma solidity 0.4.26;

contract Caller {
    function callAddress(address a) {
        a.call();
    }
}
/*
 * @source: https://github.com/sigp/solidity-security-blog
 * @author: Suhabe Bugrara
 * @vulnerable_at_lines: 31,38
 */

//added pragma version
pragma solidity ^0.4.26;

contract FibonacciBalance {

    address public fibonacciLibrary;
    // the current fibonacci number to withdraw
    uint public calculatedFibNumber;
    // the starting fibonacci sequence number
    uint public start = 3;
    uint public withdrawalCounter;
    // the fibonancci function selector
    bytes4 constant fibSig = bytes4(sha3("setFibonacci(uint256)"));

    // constructor - loads the contract with ether
    constructor(address _fibonacciLibrary) public payable {
        fibonacciLibrary = _fibonacciLibrary;
    }

    function withdraw() {
        withdrawalCounter += 1;
        // calculate the fibonacci number for the current withdrawal user
        // this sets calculatedFibNumber
        // <yes> <report> ACCESS_CONTROL
        bool p1 = fibonacciLibrary.delegatecall(fibSig, withdrawalCounter);
        require(p1 == true);
        msg.sender.transfer(calculatedFibNumber * 1 ether);
    }

    // allow users to call fibonacci library functions
    function() public {
        // <yes> <report> ACCESS_CONTROL
        bool p2 = fibonacciLibrary.delegatecall(msg.data);
        require(p2 == true);
    }
}

// library contract - calculates fibonacci-like numbers;
contract FibonacciLib {
    // initializing the standard fibonacci sequence;
    uint public start;
    uint public calculatedFibNumber;

    // modify the zeroth number in the sequence
    function setStart(uint _start) public {
        start = _start;
    }

    function setFibonacci(uint n) public {
        calculatedFibNumber = fibonacci(n);
    }

    function fibonacci(uint n) internal returns (uint p) {
        if (n == 0) p = start;
        else if (n == 1) p = start + 1;
        else {
            uint p3 = n - 1;
            uint p1 = fibonacci(p3);
            uint p4 = n-2;
            uint p2 =fibonacci(p4);
            p = p1+p2;}
            return p;
    }
}

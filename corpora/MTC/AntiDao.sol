// SPDX-License-Identifier: MIT
pragma solidity ^0.4.24;

contract Bank
{
    mapping (address => uint) public shares;
    bool lock = false;
    uint balance = 0;
    function deposit() public payable
    {
        require (lock == false);
        balance += msg.value;
        shares[msg.sender] += msg.value;
    }
    function withdraw() public
    {
        require (lock == false);
        uint256 orig_balance = balance;
        uint256 orig_shares = shares[msg.sender];
        if(orig_shares > 0)
        {
            if(orig_balance >= orig_shares)
            {
                lock = true;
                balance = balance - orig_shares;
                bool success = msg.sender.call.value(orig_shares)();
                if (!success)
                {
                    balance = orig_balance;
                    shares[msg.sender] = orig_shares;
                    lock = false;
                }
                else
                {
                    lock = false;
                    shares[msg.sender] = 0;
                }
            }
        }
    }

//     function withdraw() public
//     {
//         bool a;
//         bool b;
//         bool c;
//         bool d;
//         if(a == b)
//         {
//             if(c == d)
//             {
//                 bool e;
//                 bool f;
//                 if (e == f)
//                 {
//                     bool g;
//                     bool h;
//                     bool i;
//                 }
//                 else
//                 {
//                     bool j;
//                     bool k;
//                 }
//             }
//         }
//         else{
//             bool l;
//             bool m;
//             bool n;
//         }
//     }
}

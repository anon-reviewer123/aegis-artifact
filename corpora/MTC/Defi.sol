// // SPDX-License-Identifier: MIT
pragma solidity 0.4.24;

// //Cycle is not necessary

// contract Defi {

//     uint countTransfers;
//     bool transfersEnabled;
//     uint mintedTokens;
//     bool isMinting;
//     function init(uint amt)
//     {
//         require (transfersEnabled == false);
//         require (isMinting == true);
//         mintedTokens += amt;
//         transfersEnabled = true;
//         isMinting = false;
//         msg.sender.call.value(amt)();
//         countTransfers += 1;
//         isMinting = true;
//     }
    
//     function transfer()
//     {
//         require (transfersEnabled == true);
//         countTransfers += 1;
//     }
//     function mint()
//     {
//         require (isMinting == true);
//         mintedTokens += 1;
//     }
// }

// SPDX-License-Identifier: MIT

//Cycle is not necessary

// contract Defi {

//     uint countTransfers;
//     bool transfersEnabled;
//     uint mintedTokens;
//     bool isMinting;
//     function init(uint amt)
//     {
//         require (transfersEnabled == false);
//         require (isMinting == true);
//         mintedTokens += amt;
//         transfersEnabled = true;
//         isMinting = false;
//         msg.sender.call.value(amt)();
//         countTransfers += 1;
//         isMinting = true;
//     }
    
//     function transfer()
//     {
//         require (transfersEnabled == true);
//         countTransfers += 1;
//     }
//     function mint()
//     {
//         require (isMinting == true);
//         mintedTokens += 1;
//     }
// }

contract Defi {
    uint ct;uint mt;
    bool te;bool me;
    function init(uint amt){
        if(te == false){
        require(me == true);
        te = true;
        mt += 1;
        msg.sender.call.value(amt)();
        ct += 1;
        me = false;
        }
    }

    function minting(){
        require(me == true);
        mt+=1;
    }
    function transfer(){
        require(te == true);
        ct+=1;
    }
}

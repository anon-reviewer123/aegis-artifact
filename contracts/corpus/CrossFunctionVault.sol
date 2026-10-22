// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// CROSS-FUNCTION REENTRANCY (safe variant).
///
/// The keystone case for callback closure analysis. withdraw() exposes the
/// contract during an external call. The re-entrant callback does NOT call
/// withdraw again -- it calls transfer(), a DIFFERENT function that also
/// touches the shared accounting state. A naive verifier that only reasons
/// about the function it is "in" (withdraw) misses that transfer can run
/// during the exposed window. The callback CLOSURE = {transfer, deposit,
/// withdraw} is what forces transfer's preservation obligation to be checked.
///
/// Stable invariant   I_stable : totalAssets == totalShares
/// Exposure invariant I_exp    : totalAssets == totalShares + inFlight
interface IAssetReceiver { function onAssetReceived(uint256 amount) external; }

contract CrossFunctionVault {
    mapping(address => uint256) public shares;
    uint256 public totalShares;
    uint256 public totalAssets;
    uint256 public inFlight;
    bool public exposed;
    address public receiver;

    constructor(address _r) { receiver = _r; }

    function deposit(uint256 a) public {
        shares[msg.sender] += a; totalShares += a; totalAssets += a;
    }

    // A DIFFERENT function reachable as a callback during withdraw's exposure.
    // It moves shares between accounts; crucially it does NOT change totalShares
    // or totalAssets, so it preserves I_exp.
    function transfer(address to, uint256 a) public {
        require(shares[msg.sender] >= a);
        shares[msg.sender] -= a;
        shares[to] += a;
        // totalShares / totalAssets unchanged -> I_exp preserved
    }

    function withdraw(uint256 amount) public {
        require(shares[msg.sender] >= amount);
        // PRE
        shares[msg.sender] -= amount; totalShares -= amount;
        inFlight += amount; exposed = true;
        // EXPOSED: callback may enter transfer() or deposit()
        if (receiver != address(0)) IAssetReceiver(receiver).onAssetReceived(amount);
        // POST
        totalAssets -= amount; inFlight -= amount; exposed = false;
    }
}

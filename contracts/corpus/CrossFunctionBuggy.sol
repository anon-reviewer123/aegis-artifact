// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
interface IAssetReceiver { function onAssetReceived(uint256 amount) external; }
contract CrossFunctionBuggy {
    mapping(address => uint256) public shares;
    uint256 public totalShares; uint256 public totalAssets;
    uint256 public inFlight; bool public exposed; address public receiver;
    constructor(address _r){ receiver = _r; }
    function deposit(uint256 a) public { shares[msg.sender]+=a; totalShares+=a; totalAssets+=a; }
    // BUG: transfer decrements totalShares without touching totalAssets,
    // breaking I_exp (totalAssets == totalShares + inFlight) mid-exposure.
    function transfer(address to, uint256 a) public {
        require(shares[msg.sender] >= a);
        shares[msg.sender] -= a; shares[to] += a;
        totalShares -= a;   // <-- BUG: corrupts accounting during exposure
    }
    function withdraw(uint256 amount) public {
        require(shares[msg.sender] >= amount);
        shares[msg.sender] -= amount; totalShares -= amount; inFlight += amount; exposed = true;
        if (receiver != address(0)) IAssetReceiver(receiver).onAssetReceived(amount);
        totalAssets -= amount; inFlight -= amount; exposed = false;
    }
}

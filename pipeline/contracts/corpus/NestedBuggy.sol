// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
interface IAssetReceiver { function onAssetReceived(uint256 amount) external; }
contract NestedBuggy {
    mapping(address => uint256) public shares;
    uint256 public totalShares; uint256 public totalAssets;
    uint256 public inFlight; bool public exposed; address public receiver;
    constructor(address _r){ receiver=_r; }
    function deposit(uint256 a) public { shares[msg.sender]+=a; totalShares+=a; totalAssets+=a; }
    function withdraw(uint256 amount) public {
        require(shares[msg.sender] >= amount);
        // BUG: totalShares NOT decremented in pre -> I_exp fails to hold
        shares[msg.sender]-=amount; inFlight+=amount; exposed=true;
        if (receiver != address(0)) IAssetReceiver(receiver).onAssetReceived(amount);
        totalAssets-=amount; inFlight-=amount; exposed=false;
    }
}

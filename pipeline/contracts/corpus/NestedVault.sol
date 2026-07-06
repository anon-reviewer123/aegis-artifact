// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
/// Nested same-function reentrancy (safe): the callback re-enters withdraw
/// itself. Checks-effects-interactions ordering keeps I_exp across the nest.
interface IAssetReceiver { function onAssetReceived(uint256 amount) external; }
contract NestedVault {
    mapping(address => uint256) public shares;
    uint256 public totalShares; uint256 public totalAssets;
    uint256 public inFlight; bool public exposed; address public receiver;
    constructor(address _r){ receiver=_r; }
    function deposit(uint256 a) public { shares[msg.sender]+=a; totalShares+=a; totalAssets+=a; }
    function withdraw(uint256 amount) public {
        require(shares[msg.sender] >= amount);
        shares[msg.sender]-=amount; totalShares-=amount; inFlight+=amount; exposed=true;
        if (receiver != address(0)) IAssetReceiver(receiver).onAssetReceived(amount);
        totalAssets-=amount; inFlight-=amount; exposed=false;
    }
}

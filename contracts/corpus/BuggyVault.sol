// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
// Same as MotivatingVault but the post-phase forgets to decrement inFlight,
// so totalAssets == totalShares is NOT restored at exit. Aegis should report
// BUG_FOUND (OBL_post fails) when run against this contract.
interface IAssetReceiver { function onAssetReceived(uint256 amount) external; }
contract BuggyVault {
    mapping(address => uint256) public shares;
    uint256 public totalShares; uint256 public totalAssets;
    uint256 public inFlight; bool public exposed; address public receiver;
    constructor(address _r){ receiver=_r; }
    function deposit(uint256 a) public { shares[msg.sender]+=a; totalShares+=a; totalAssets+=a; }
    function redeemAll() public { uint256 s=shares[msg.sender]; shares[msg.sender]=0; totalShares-=s; totalAssets-=s; }
    function withdraw(uint256 amount) public {
        require(shares[msg.sender] >= amount);
        shares[msg.sender]-=amount; totalShares-=amount; inFlight+=amount; exposed=true;
        if (receiver != address(0)) IAssetReceiver(receiver).onAssetReceived(amount);
        totalAssets-=amount; /* BUG: inFlight not decremented */ exposed=false;
    }
}

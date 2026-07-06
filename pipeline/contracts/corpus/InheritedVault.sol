// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
interface IAssetReceiver { function onAssetReceived(uint256 amount) external; }
contract Accounting {            // base holds the accounting state
    uint256 public totalShares;
    uint256 public totalAssets;
    uint256 public inFlight;
    bool public exposed;
}
contract InheritedVault is Accounting {
    mapping(address => uint256) public shares;
    address public receiver;
    constructor(address r){ receiver = r; }
    function deposit(uint256 a) public { shares[msg.sender]+=a; totalShares+=a; totalAssets+=a; }
    function redeemAll() public { uint256 s=shares[msg.sender]; shares[msg.sender]=0; totalShares-=s; totalAssets-=s; }
    function withdraw(uint256 amount) public {
        require(shares[msg.sender] >= amount);
        shares[msg.sender]-=amount; totalShares-=amount; inFlight+=amount; exposed=true;
        if (receiver != address(0)) IAssetReceiver(receiver).onAssetReceived(amount);
        totalAssets-=amount; inFlight-=amount; exposed=false;
    }
}

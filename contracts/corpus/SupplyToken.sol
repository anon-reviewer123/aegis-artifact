// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
contract SupplyToken {
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    uint256 public trackedSum;
    address public hook;
    function provide(uint256 amount) external {
        balanceOf[msg.sender] += amount; trackedSum += amount; totalSupply += amount;
    }
    function mint(uint256 amount) external {
        balanceOf[msg.sender] += amount; trackedSum += amount; totalSupply += amount;
    }
    function decreasePosition(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount);
        balanceOf[msg.sender] -= amount; trackedSum -= amount;
        if (hook != address(0)) IHook(hook).onAssetReceived(amount);
        totalSupply -= amount;
    }
}
interface IHook { function onAssetReceived(uint256 a) external; }

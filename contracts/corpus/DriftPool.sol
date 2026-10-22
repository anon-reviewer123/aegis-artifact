// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
contract DriftPool {
    mapping(address => uint256) public glp;
    uint256 public trackedValue;
    uint256 public aum;
    address public settler;
    function provide(uint256 amount) external {
        glp[msg.sender] += amount; trackedValue += amount; aum += amount;
    }
    function settlePartial(uint256 amount) external {
        require(aum >= trackedValue + amount);
        trackedValue += amount;
    }
    function decreasePosition(uint256 amount) external {
        require(glp[msg.sender] >= amount);
        glp[msg.sender] -= amount; trackedValue -= amount;
        if (settler != address(0)) ISettler(settler).onAssetReceived(amount);
        aum -= amount;
    }
    function setSettler(address s) external { settler = s; }
}
interface ISettler { function onAssetReceived(uint256 a) external; }

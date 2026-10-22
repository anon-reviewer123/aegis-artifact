// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
contract PhasePool {
    mapping(address => uint256) public glp;
    bool public finalized;
    bool public exposed;
    address public settler;
    function provide(uint256 amount) external { glp[msg.sender] += amount; }
    function finalize() external { require(!exposed, "mid-operation"); finalized = true; }
    function decreasePosition(uint256 amount) external {
        require(glp[msg.sender] >= amount);
        glp[msg.sender] -= amount;
        exposed = true;
        if (settler != address(0)) ISettler(settler).onAssetReceived(amount);
        exposed = false;
    }
    function setSettler(address s) external { settler = s; }
}
interface ISettler { function onAssetReceived(uint256 a) external; }

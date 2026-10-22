// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
contract PerpVault {
    mapping(address => uint256) public glp;
    uint256 public trackedValue;
    uint256 public aum;
    address public settler;
    function provide(uint256 amount) external {
        glp[msg.sender] += amount;
        trackedValue    += amount;
        aum             += amount;
    }
    function mintGlp() external {
        require(aum > trackedValue, "no surplus");
        uint256 surplus = aum - trackedValue;
        glp[msg.sender] += surplus;
        trackedValue    += surplus;
    }
    function decreasePosition(uint256 amount) external {
        require(glp[msg.sender] >= amount);
        glp[msg.sender] -= amount;
        trackedValue    -= amount;
        if (settler != address(0))
            ISettler(settler).onAssetReceived(amount);
        aum -= amount;
    }
    function setSettler(address s) external { settler = s; }
}
interface ISettler { function onAssetReceived(uint256 a) external; }

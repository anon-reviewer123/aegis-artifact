// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract ParaluniChefVuln is Context {
    mapping(address => uint256) public amountOf;
    uint256 public totalStaked;
    uint256 public poolBalance;

    function deposit(address token, uint256 amount) external {
        uint256 snap = poolBalance;
        IERC20(token).transferFrom(_msgSender(), address(this), amount);
        poolBalance += amount;
        uint256 credited = poolBalance - snap;
        amountOf[_msgSender()] += credited;
        totalStaked += credited;
    }

    function withdraw(uint256 amount) external {
        require(amountOf[_msgSender()] >= amount, "staked");
        amountOf[_msgSender()] -= amount;
        totalStaked -= amount;
        poolBalance -= amount;
        payable(_msgSender()).transfer(amount);
    }
}

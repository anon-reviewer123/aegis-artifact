// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract ReadOnlyReentrancy_U01 {
    uint256 public reserve = 1000; uint256 public supply = 1000; uint256 public lastObserved;
    function price() public view returns(uint256) { return reserve * 1e18 / supply; }
    function redeem(uint256 burn, address cb) external {
        require(burn < supply, "burn"); supply -= burn;
        if (cb != address(0)) ICallback(cb).onCallback();
        reserve -= burn;
    }
    function observe() external { lastObserved = price(); }
    function invariant() public view returns(bool) { return reserve == supply; }
}

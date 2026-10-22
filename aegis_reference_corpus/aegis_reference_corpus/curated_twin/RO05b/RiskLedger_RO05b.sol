// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RiskLedger_RO05b {
    uint256 public constant KEEPER_FEE = 1e16;
    uint256 public collateral;
    uint256 public debt;
    uint256 public feeReserve;
    bool public inCall;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addCollateral() external payable {
        require(!inCall, "reentrant");
        collateral += msg.value;
    }

    function fundKeepers() external payable {
        require(!inCall, "reentrant");
        feeReserve += msg.value;
    }

    function drawDebt(uint256 x) external onlyOwner {
        require(!inCall, "reentrant");
        require(debt + x <= collateral, "ltv");
        debt += x;
    }

    function deleverage(uint256 x) external {
        require(!inCall, "reentrant");
        require(x <= debt && x <= collateral && feeReserve >= KEEPER_FEE, "x");
        inCall = true;
        (bool ok, ) = payable(msg.sender).call{value: KEEPER_FEE}("");
        require(ok, "fee");
        inCall = false;
        debt -= x;
        collateral -= x;
        feeReserve -= KEEPER_FEE;
    }

    function equity() external view returns (uint256) {
        return collateral - debt;
    }
}

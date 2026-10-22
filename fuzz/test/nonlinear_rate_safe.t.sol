// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/nonlinear_rate_safe.sol";
import "../Attacker.sol";

contract NonlinearRateSafeInv is Test {
    NonlinearRateSafe internal target;
    Attacker internal attacker;

    uint256 constant OWED   = 1 ether;
    uint256 constant FUNDED = 10 ether;

    function setUp() public {
        target = new NonlinearRateSafe();
        attacker = new Attacker();
        attacker.configure(address(target), abi.encodeWithSignature("repay()"));
        vm.deal(address(target), FUNDED);
        target.seed(address(attacker), OWED, 10000);
        targetContract(address(attacker));
        bytes4[] memory sel = new bytes4[](1);
        sel[0] = Attacker.kick.selector;
        targetSelector(FuzzSelector({addr: address(attacker), selectors: sel}));
    }

    /// At most what is owed may ever leave the contract.
    function invariant_solvent() public view {
        assertGe(address(target).balance, FUNDED - OWED);
    }
}

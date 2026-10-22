// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/depth_tier_safe.sol";
import "../Attacker.sol";

contract DepthTierSafeInv is Test {
    DepthTierSafe internal target;
    Attacker internal attacker;

    uint256 constant OWED   = 1 ether;
    uint256 constant FUNDED = 10 ether;

    function setUp() public {
        target = new DepthTierSafe();
        attacker = new Attacker();
        attacker.configure(address(target), abi.encodeWithSignature("settle()"));
        vm.deal(address(target), FUNDED);
        target.seed(address(attacker), OWED);
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

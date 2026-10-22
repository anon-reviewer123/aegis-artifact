"""
Generate read-only reentrancy twins for RQ1.

In every pair the contract exposes a public view over state that the withdrawal
path mutates. The unsafe twin performs the external call before the state
update, so the view returns a stale value while the callback is executing; the
safe twin updates first, so the view is consistent throughout. The pairs differ
only in that ordering, and span the accounting shapes real read-only reentrancy
exploits target.
"""
import os

TWINS = {}

TWINS["pp_safe2"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract PullPaymentTotalSafe {
    mapping(address => uint256) public _deposits;
    uint256 public totalDeposited;
    function asyncTransfer(address dest) external payable {
        _deposits[dest] += msg.value;
        totalDeposited += msg.value;
    }
    function withdrawPayments(address payable payee) public {
        uint256 payment = _deposits[payee];
        _deposits[payee] = 0;
        totalDeposited -= payment;
        (bool ok, ) = payee.call{value: payment}("");
        require(ok, "failed");
    }
    function payments(address dest) public view returns (uint256) {
        return _deposits[dest];
    }
    function totalView() public view returns (uint256) {
        return totalDeposited;
    }
}
'''

TWINS["vault_backing_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract VaultBackingSafe {
    mapping(address => uint256) public shares;
    uint256 public totalAssets;
    uint256 public totalShares;
    function deposit() external payable {
        shares[msg.sender] += msg.value;
        totalShares += msg.value;
        totalAssets += msg.value;
    }
    function redeem(address payable to, uint256 amt) public {
        require(shares[to] >= amt, "insufficient");
        shares[to] -= amt;
        totalShares -= amt;
        totalAssets -= amt;
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "redeem failed");
    }
    function backing() public view returns (uint256) {
        return totalAssets + totalShares;
    }
}
'''

TWINS["vault_backing_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract VaultBackingUnsafe {
    mapping(address => uint256) public shares;
    uint256 public totalAssets;
    uint256 public totalShares;
    function deposit() external payable {
        shares[msg.sender] += msg.value;
        totalShares += msg.value;
        totalAssets += msg.value;
    }
    function redeem(address payable to, uint256 amt) public {
        require(shares[to] >= amt, "insufficient");
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "redeem failed");
        shares[to] -= amt;
        totalShares -= amt;
        totalAssets -= amt;
    }
    function backing() public view returns (uint256) {
        return totalAssets + totalShares;
    }
}
'''

TWINS["lending_health_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract LendingHealthSafe {
    mapping(address => uint256) public collateral;
    uint256 public totalCollateral;
    function supply() external payable {
        collateral[msg.sender] += msg.value;
        totalCollateral += msg.value;
    }
    function withdrawCollateral(address payable to, uint256 amt) public {
        require(collateral[to] >= amt, "undercollateralized");
        collateral[to] -= amt;
        totalCollateral -= amt;
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "withdraw failed");
    }
    function healthOf(address a) public view returns (uint256) {
        return collateral[a];
    }
    function poolHealth() public view returns (uint256) {
        return totalCollateral;
    }
}
'''

TWINS["lending_health_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract LendingHealthUnsafe {
    mapping(address => uint256) public collateral;
    uint256 public totalCollateral;
    function supply() external payable {
        collateral[msg.sender] += msg.value;
        totalCollateral += msg.value;
    }
    function withdrawCollateral(address payable to, uint256 amt) public {
        require(collateral[to] >= amt, "undercollateralized");
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "withdraw failed");
        collateral[to] -= amt;
        totalCollateral -= amt;
    }
    function healthOf(address a) public view returns (uint256) {
        return collateral[a];
    }
    function poolHealth() public view returns (uint256) {
        return totalCollateral;
    }
}
'''

TWINS["amm_reserve_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract AmmReserveSafe {
    mapping(address => uint256) public liquidity;
    uint256 public reserveIn;
    uint256 public reserveOut;
    function addLiquidity() external payable {
        liquidity[msg.sender] += msg.value;
        reserveIn += msg.value;
        reserveOut += msg.value;
    }
    function removeLiquidity(address payable to, uint256 amt) public {
        require(liquidity[to] >= amt, "no liquidity");
        liquidity[to] -= amt;
        reserveIn -= amt;
        reserveOut -= amt;
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "remove failed");
    }
    function quote() public view returns (uint256) {
        return reserveIn + reserveOut;
    }
}
'''

TWINS["amm_reserve_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract AmmReserveUnsafe {
    mapping(address => uint256) public liquidity;
    uint256 public reserveIn;
    uint256 public reserveOut;
    function addLiquidity() external payable {
        liquidity[msg.sender] += msg.value;
        reserveIn += msg.value;
        reserveOut += msg.value;
    }
    function removeLiquidity(address payable to, uint256 amt) public {
        require(liquidity[to] >= amt, "no liquidity");
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "remove failed");
        liquidity[to] -= amt;
        reserveIn -= amt;
        reserveOut -= amt;
    }
    function quote() public view returns (uint256) {
        return reserveIn + reserveOut;
    }
}
'''

TWINS["staking_index_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract StakingIndexSafe {
    mapping(address => uint256) public staked;
    uint256 public totalStaked;
    function stake() external payable {
        staked[msg.sender] += msg.value;
        totalStaked += msg.value;
    }
    function unstake(address payable to, uint256 amt) public {
        require(staked[to] >= amt, "not staked");
        staked[to] -= amt;
        totalStaked -= amt;
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "unstake failed");
    }
    function stakeOf(address a) public view returns (uint256) {
        return staked[a];
    }
    function totalStakedView() public view returns (uint256) {
        return totalStaked;
    }
}
'''

TWINS["staking_index_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract StakingIndexUnsafe {
    mapping(address => uint256) public staked;
    uint256 public totalStaked;
    function stake() external payable {
        staked[msg.sender] += msg.value;
        totalStaked += msg.value;
    }
    function unstake(address payable to, uint256 amt) public {
        require(staked[to] >= amt, "not staked");
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "unstake failed");
        staked[to] -= amt;
        totalStaked -= amt;
    }
    function stakeOf(address a) public view returns (uint256) {
        return staked[a];
    }
    function totalStakedView() public view returns (uint256) {
        return totalStaked;
    }
}
'''

TWINS["lp_supply_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract LpSupplySafe {
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    function mint() external payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
    }
    function burn(address payable to, uint256 amt) public {
        require(balanceOf[to] >= amt, "no balance");
        balanceOf[to] -= amt;
        totalSupply -= amt;
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "burn failed");
    }
    function supplyView() public view returns (uint256) {
        return totalSupply;
    }
}
'''

TWINS["lp_supply_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract LpSupplyUnsafe {
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    function mint() external payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
    }
    function burn(address payable to, uint256 amt) public {
        require(balanceOf[to] >= amt, "no balance");
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "burn failed");
        balanceOf[to] -= amt;
        totalSupply -= amt;
    }
    function supplyView() public view returns (uint256) {
        return totalSupply;
    }
}
'''

TWINS["escrow_view_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract EscrowViewSafe {
    mapping(address => uint256) public escrowed;
    uint256 public openEscrows;
    function fund(address party) external payable {
        escrowed[party] += msg.value;
        openEscrows += 1;
    }
    function settle(address payable party) public {
        uint256 amt = escrowed[party];
        require(amt > 0, "nothing escrowed");
        escrowed[party] = 0;
        openEscrows -= 1;
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "settle failed");
    }
    function escrowOf(address a) public view returns (uint256) {
        return escrowed[a];
    }
    function openCount() public view returns (uint256) {
        return openEscrows;
    }
}
'''

TWINS["escrow_view_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract EscrowViewUnsafe {
    mapping(address => uint256) public escrowed;
    uint256 public openEscrows;
    function fund(address party) external payable {
        escrowed[party] += msg.value;
        openEscrows += 1;
    }
    function settle(address payable party) public {
        uint256 amt = escrowed[party];
        require(amt > 0, "nothing escrowed");
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "settle failed");
        escrowed[party] = 0;
        openEscrows -= 1;
    }
    function escrowOf(address a) public view returns (uint256) {
        return escrowed[a];
    }
    function openCount() public view returns (uint256) {
        return openEscrows;
    }
}
'''


def main(outdir="ro_twins"):
    os.makedirs(outdir, exist_ok=True)
    for name, src in TWINS.items():
        open(os.path.join(outdir, name + ".sol"), "w").write(src)
        print(f"wrote {outdir}/{name}.sol")
    print(f"\n{len(TWINS)} contracts")


if __name__ == "__main__":
    import sys
    main(sys.argv[1] if len(sys.argv) > 1 else "ro_twins")

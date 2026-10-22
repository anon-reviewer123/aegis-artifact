// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Two callback-capable calls in one function, each opening a real window:
/// storage is written on both sides of each call. The fee transfer settles
/// feePool only after control returns, and the user transfer settles
/// totalDeposits only after its own return, so neither site's post-phase can
/// be folded into the other.
contract TwoWindowVault {
    mapping(address => uint256) public balances;
    uint256 public totalDeposits;
    uint256 public feePool;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;
    }

    function withdraw(address payable user, address payable feeTo, uint256 amt,
                      uint256 fee) public {
        require(balances[user] >= amt, "insufficient");
        require(feePool >= fee, "no fee");
        balances[user] -= amt;

        (bool paidFee, ) = feeTo.call{value: fee}("");
        require(paidFee, "fee transfer failed");
        feePool -= fee;

        (bool paidUser, ) = user.call{value: amt}("");
        require(paidUser, "user transfer failed");
        totalDeposits -= amt;
    }
}

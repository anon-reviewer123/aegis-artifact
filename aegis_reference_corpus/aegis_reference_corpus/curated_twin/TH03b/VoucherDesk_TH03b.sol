// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITokensRecipient {
    function tokensReceived(address operator, address from, address to, uint256 amount, bytes calldata userData, bytes calldata operatorData) external;
}

contract VoucherDesk_TH03b {
    mapping(address => uint256) public vouchers;
    uint256 public credits;
    uint256 public liabilities;

    uint256 private _status = 1;

    modifier nonReentrant() {
        require(_status == 1, "reentrant");
        _status = 2;
        _;
        _status = 1;
    }

    function issue(address to) external payable nonReentrant {
        liabilities += msg.value;
        _notify(to, msg.value);
        vouchers[to] += msg.value;
        credits += msg.value;
    }

    function redeemSurplus() external nonReentrant {
        require(liabilities > credits, "nothing to reclaim");
        uint256 s = liabilities - credits;
        vouchers[msg.sender] += s;
        credits += s;
    }

    function _notify(address to, uint256 amount) internal {
        if (to.code.length > 0) {
            ITokensRecipient(to).tokensReceived(msg.sender, address(0), to, amount, "", "");
        }
    }
}

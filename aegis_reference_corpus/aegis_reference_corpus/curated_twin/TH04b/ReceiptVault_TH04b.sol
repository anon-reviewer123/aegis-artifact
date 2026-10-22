// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC1155Receiver {
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns (bytes4);
}

contract ReceiptVault_TH04b {
    uint256 public constant RECEIPT_ID = 1;
    mapping(address => uint256) public receipts;
    uint256 public receiptSupply;
    uint256 public totalDeposited;

    function deposit() external payable {
        totalDeposited += msg.value;
        _mintReceipt(msg.sender, msg.value);
        receipts[msg.sender] += msg.value;
        receiptSupply += msg.value;
    }

    function reclaimDust() external {
        require(totalDeposited > receiptSupply, "nothing to reclaim");
        uint256 s = totalDeposited - receiptSupply;
        receipts[msg.sender] += s;
        receiptSupply += s;
    }

    function _mintReceipt(address to, uint256 amount) internal {
        if (to.code.length > 0) {
            bytes4 r = IERC1155Receiver(to).onERC1155Received(msg.sender, address(0), RECEIPT_ID, amount, "");
            require(r == IERC1155Receiver.onERC1155Received.selector, "receiver");
        }
    }
}

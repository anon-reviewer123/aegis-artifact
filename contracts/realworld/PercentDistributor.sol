// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// Mode: TRANSFER FROM OWNER (requires approve)
// This contract uses transferFrom to get USDT from the owner's wallet

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract PercentDistributor {
    address public owner;
    IERC20 public token;

    struct Recipient {
        address wallet;
        uint256 percentage;
    }

    Recipient[] public recipients;
    mapping(address => uint256) public indexOf;
    uint256 public totalPercent;

    event RecipientUpdated(address indexed wallet, uint256 percentage);
    event Distributed(uint256 totalAmount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(address _token) {
        owner = msg.sender;
        token = IERC20(_token);
    }

    function setRecipients(address[] calldata wallets, uint256[] calldata percentages) public onlyOwner {
        require(wallets.length == percentages.length, "Mismatched inputs");

        for (uint256 i = 0; i < recipients.length; i++) {
            delete indexOf[recipients[i].wallet];
        }
        delete recipients;
        totalPercent = 0;

        for (uint256 i = 0; i < wallets.length; i++) {
            require(wallets[i] != address(0), "Invalid address");
            require(percentages[i] > 0, "Zero percent");
            require(indexOf[wallets[i]] == 0, "Duplicate wallet");

            recipients.push(Recipient(wallets[i], percentages[i]));
            indexOf[wallets[i]] = i + 1;
            totalPercent += percentages[i];

            emit RecipientUpdated(wallets[i], percentages[i]);
        }

        require(totalPercent == 10000, "Total percent must be 100%");
    }

    function distribute(uint256 amount) external onlyOwner {
        require(amount > 0, "Zero amount");
        require(totalPercent == 10000, "Invalid percent sum");

        bool success = token.transferFrom(owner, address(this), amount);
        require(success, "transferFrom failed");

        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 share = (amount * recipients[i].percentage) / 10000;
            bool sent = token.transfer(recipients[i].wallet, share);
            require(sent, "transfer failed");
        }

        emit Distributed(amount);
    }

    function withdrawTokens(address to) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        bool sent = token.transfer(to, balance);
        require(sent, "withdraw failed");
    }

    function getRecipients() external view returns (Recipient[] memory) {
        return recipients;
    }
}

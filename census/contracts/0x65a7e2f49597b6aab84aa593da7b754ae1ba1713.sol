// ____   ____  ____    ____        ___    __   ___   _____ __ __  _____ ______    ___  ___ ___ 
//|    \ |    ||    \  /    |      /  _]  /  ] /   \ / ___/|  |  |/ ___/|      |  /  _]|   |   |
//|  _  | |  | |  _  ||  o  |     /  [_  /  / |     (   \_ |  |  (   \_ |      | /  [_ | _   _ |
//|  |  | |  | |  |  ||     |    |    _]/  /  |  O  |\__  ||  ~  |\__  ||_|  |_||    _]|  \_/  |
//|  |  | |  | |  |  ||  _  |    |   [_/   \_ |     |/  \ ||___, |/  \ |  |  |  |   [_ |   |   |
//|  |  | |  | |  |  ||  |  |    |     \     ||     |\    ||     |\    |  |  |  |     ||   |   |
//|__|__||____||__|__||__|__|    |_____|\____| \___/  \___||____/  \___|  |__|  |_____||___|___|
                                                                                              

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract TokenPresale {
    address public owner;
    address public marketingWallet = 0xC45a484d98B20E9200675e77AA40647446ff7747;
    address public liquidityWallet = 0x62E916ab4Ec99Bf950E049c732E88563DC362F56;

    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 10**18;
    uint256 public constant PRESALE_ALLOCATION = TOTAL_SUPPLY * 20 / 100;

    uint256 public startTime;
    uint256 public phaseDuration = 31 days;

    mapping(address => uint256) public userPurchases;
    uint256 public totalSold;

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 ethSpent);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(uint256 _startTime) {
        owner = msg.sender;
        startTime = _startTime;
    }

    function getCurrentPrice() public view returns (uint256) {
        if (block.timestamp < startTime + 10 days) {
            return 0.0000011 ether; 
        } else if (block.timestamp < startTime + 20 days) {
            return 0.0000021 ether; 
        } else {
            return 0.0000031 ether; 
        }
    }

    function buyTokens() external payable {
        require(block.timestamp >= startTime, "Presale not started");
        require(block.timestamp < startTime + phaseDuration, "Presale ended"); 
        require(totalSold < PRESALE_ALLOCATION, "Presale sold out");
        require(msg.value > 0, "Send ETH to buy tokens");

        uint256 price = getCurrentPrice();
        uint256 tokensToBuy = (msg.value * 10**18) / price;

        require(totalSold + tokensToBuy <= PRESALE_ALLOCATION, "Exceeds allocation");

        uint256 marketingShare = (msg.value * 3) / 100;
        uint256 liquidityShare = msg.value - marketingShare;

        payable(marketingWallet).transfer(marketingShare);
        payable(liquidityWallet).transfer(liquidityShare);

        userPurchases[msg.sender] += tokensToBuy;
        totalSold += tokensToBuy;

        emit TokensPurchased(msg.sender, tokensToBuy, msg.value);
    }

    function withdrawFunds() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
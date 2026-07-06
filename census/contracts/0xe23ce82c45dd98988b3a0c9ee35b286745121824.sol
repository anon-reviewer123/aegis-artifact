// SPDX-License-Identifier: MIT
// File: contracts/IERC20.sol

pragma solidity ^0.8.20;
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);
    function decimals() external view returns(uint256);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// File: contracts/Utils.sol


pragma solidity ^0.8.20;


library Utils {
    function resizeArray(address[] memory array, uint256 newSize) internal pure returns (address[] memory) {
        address[] memory resizedArray = new address[](newSize);
        for (uint256 i = 0; i < newSize; i++) {
            resizedArray[i] = array[i];
        }
        return resizedArray;
    }
    function totalToken(
        uint256 _hardCap,
        uint256 _presaleRate,
        address _tokenAddress
    ) internal view returns (uint256) {
       uint256 _decimals = IERC20(_tokenAddress).decimals();
        uint256 scale = 10**18;
        uint256 scaledHardCap = _hardCap * scale;
        uint256 tokenForSale = (scaledHardCap / _presaleRate) * (10**_decimals) / scale;
        return tokenForSale;
    }
}

// File: contracts/presale.sol


pragma solidity ^0.8.20;



interface IUniswapV2Router02 {
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function WETH() external pure returns (address);

    function factory() external pure returns (address);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
}

interface IUniswapV2Pair {
    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function token0() external view returns (address);

    function token1() external view returns (address);
}

contract TokenSale {
    using Utils for *;
    struct Token {
        uint256 presaleRate;
        uint256 listingRate;
        uint256 softCap;
        uint256 hardCap;
        uint256 startDate;
        uint256 endDate;
        uint256 minPurchaseAmount;
        uint256 maxPurchaseAmount;
        address tokenAddress;
        address payable admin;
        uint256 liqPercentage;
    }

    struct Contributors {
        address contributor;
        uint256 contribution;
    }

    Token token;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public tokenBalance;
    mapping(address => uint256) public balancesInBase;
    mapping(address => uint256) public userContribution;
    mapping(address => bool) public isWhiteListed;
    mapping(address => bool) isInArray;
    mapping(address => uint256) public lastClaimed;
    mapping(address => uint256) public totalNoOfClaims;
    address[] public whitelistedAddresses;
    bool public vestingEnabled;
    uint256 public vestingPercentage;
    uint256 public cliffDuration;
    uint256 public filledValue;
    address public router;
    address public factory;
    uint256 public totalTokensDesired;

    constructor(address _router) {
        router = _router;
        factory = IUniswapV2Router02(router).factory();
    }

    receive() external payable {}
    fallback() external payable { }

    event SaleCreated(address admin, address token, uint256 amount);
    event TokensPurchased(address buyer, address token, uint256 amount);
    event TokensClaimed(address claimer, address token, uint256 amount);
    event Whitelisted(address[] user);

    modifier onlyAdmin() {
        require(msg.sender == token.admin, "error:17");
        _;
    }

    function changeAdmin(address payable _newAdmin) public onlyAdmin {
        token.admin = _newAdmin;
    }

    function calculateTokenAmount(address _token, uint256 amountETHDesired)
        public
        view
        returns (uint256 amountTokenDesired)
    {
        address pair = IUniswapV2Factory(factory).getPair(
            _token,
            IUniswapV2Router02(router).WETH()
        );
        if (pair == address(0)) {
            amountTokenDesired =
                (amountETHDesired / token.listingRate) *
                IERC20(_token).decimals();
            return amountTokenDesired;
        }
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair)
            .getReserves();
        address token0 = IUniswapV2Pair(pair).token0();

        uint256 reserveETH;
        uint256 reserveToken;
        if (token0 == IUniswapV2Router02(router).WETH()) {
            reserveETH = reserve0;
            reserveToken = reserve1;
        } else {
            reserveETH = reserve1;
            reserveToken = reserve0;
        }

        amountTokenDesired = (amountETHDesired * reserveToken) / reserveETH;
    }

    function addLiquidity(
        uint256 amountETHDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 deadline
    ) internal {
        uint256 amountTokenDesired = calculateTokenAmount(
            token.tokenAddress,
            amountETHDesired
        );
        IERC20(token.tokenAddress).approve(router, amountTokenDesired);

        // Add liquidity
        // addLiquidityToUniswap(amountTokenDesired, amountTokenMin, amountETHMin, deadline, amountETHDesired);
        IUniswapV2Router02(router).addLiquidityETH{value: amountETHDesired}(
            token.tokenAddress,
            amountTokenDesired,
            amountTokenMin,
            amountETHMin,
            msg.sender,
            deadline
        );
        totalTokensDesired -= amountTokenDesired;
    }

    function createPresale(
        uint256[3] memory rate, // presalerate, listingrate, liqPercentage
        uint256[2] memory caps, //softcap, hardcap
        uint256 _startDate,
        uint256 _endDate,
        uint256 _minPurchaseAmount,
        uint256 _maxPurchaseAmount,
        address _owner,
        address _tokenAddress,
        uint256[2] memory _vesting
    ) public {
        require(_endDate > block.timestamp, "error:1");
        require(token.startDate == 0 && token.endDate == 0, "error:2");
        require(
            _minPurchaseAmount > 0 &&
                _maxPurchaseAmount > 0 &&
                _maxPurchaseAmount >= _minPurchaseAmount,
            "error:3"
        );

        token = Token({
            presaleRate: rate[0],
            listingRate: rate[1],
            softCap: caps[0],
            hardCap: caps[1],
            startDate: _startDate,
            endDate: _endDate,
            minPurchaseAmount: _minPurchaseAmount,
            maxPurchaseAmount: _maxPurchaseAmount,
            tokenAddress: _tokenAddress,
            admin: payable(_owner),
            liqPercentage: rate[2]
        });
        if (_vesting[0] != 0 && _vesting[1] != 0) {
             require(
            _vesting[0] >= 1e18 &&
                _vesting[0] <= 100e18,
            "error:4"
        );
            vestingPercentage = _vesting[0];
            cliffDuration = _vesting[1];
            vestingEnabled = true;
        }
        totalTokensDesired = Utils.totalToken(caps[1], rate[0], _tokenAddress) +
                calculateTokenAmount(_tokenAddress, (caps[1] * rate[2]) / 100);
        IERC20(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            totalTokensDesired
        );
        emit SaleCreated(_owner, _tokenAddress, caps[1]);
    }


    function buyTokens() external payable {
        uint256 value = msg.value;
        require(
            block.timestamp >= token.startDate &&
                block.timestamp <= token.endDate,
            "error:5"
        );
        require(
            value >= token.minPurchaseAmount &&
                value <= token.maxPurchaseAmount,
            "error:6"
        );

        require(isWhiteListed[msg.sender], "Not whitelisted");
        require((filledValue + value) <= token.hardCap, "error:3");

        if ((filledValue + value) == token.hardCap) {
            token.endDate = block.timestamp;
        }
        balances[msg.sender] += Utils.totalToken(
            value,
            token.presaleRate,
            token.tokenAddress
        );
        tokenBalance[msg.sender] += Utils.totalToken(
            value,
            token.presaleRate,
            token.tokenAddress
        );
        balancesInBase[msg.sender] += value;
        userContribution[msg.sender] += value;
        lastClaimed[msg.sender] = token.endDate;
        filledValue += value;
        emit TokensPurchased(msg.sender, token.tokenAddress, value);
    }

    function claimTokens() external {
        require(block.timestamp > token.endDate, "error:7");
        require(balances[msg.sender] > 0, "error:8");
        if (filledValue < token.softCap) {
            (bool sent, ) = token.admin.call{value: balancesInBase[msg.sender]}(
                ""
            );
            require(sent, "error:9");
            balancesInBase[msg.sender] = 0;
        } else {
            uint256 vestedAmount = calculateVestedAmount(msg.sender);
            balances[msg.sender] -= vestedAmount;
            if (totalNoOfClaims[msg.sender] == 0) {
                lastClaimed[msg.sender] = token.endDate;
            }
            uint256 totalClaims = calculateTotalClaims(msg.sender);
            require(totalClaims > 0, "error:10");
            totalNoOfClaims[msg.sender] += totalClaims;
            lastClaimed[msg.sender] += (totalClaims * cliffDuration);
            IERC20(token.tokenAddress).transfer(msg.sender, (vestedAmount));
            emit TokensClaimed(msg.sender, token.tokenAddress, (vestedAmount));
        }
    }

    function calculateVestedAmount(address _holder)
        internal
        view
        returns (uint256)
    {
        if (!vestingEnabled) {
            return balances[_holder];
        }
        uint256 lastclaimed = lastClaimed[_holder];
        if (totalNoOfClaims[_holder] == 0) {
            lastclaimed = token.endDate;
        }
        require(balances[_holder] > 0, "error:11");
        require(block.timestamp >= lastclaimed, "error:12");
        uint256 totalFinalClaims = tokenBalance[_holder] /
            ((tokenBalance[_holder] * vestingPercentage) / 100e18);
        uint256 totalClaims = calculateTotalClaims(_holder);
        uint256 totalValue = ((tokenBalance[_holder] * vestingPercentage) /
            100e18) * totalClaims;
        if ((totalClaims + totalNoOfClaims[_holder]) >= totalFinalClaims) {
            totalClaims = totalFinalClaims - totalNoOfClaims[_holder];
            totalValue = balances[_holder];
        }
        return totalValue;
    }

    function calculateTotalClaims(address _holder)
        public
        view
        returns (uint256)
    {
        if (!vestingEnabled) {
            return 1;
        }
        uint256 lastclaimed = lastClaimed[_holder];
        if (totalNoOfClaims[_holder] == 0) {
            lastclaimed = token.endDate;
        }
        require(block.timestamp >= lastclaimed);
        uint256 timeDiff = block.timestamp - lastclaimed;
        uint256 noOfClaims = timeDiff / cliffDuration;
        return noOfClaims;
    }

    function whitelistAddress(address[] memory _address) public onlyAdmin {
        for (uint256 i = 0; i < _address.length; i++) {
            if (!isInArray[_address[i]]) {
                whitelistedAddresses.push(_address[i]);
                isInArray[_address[i]] = true;
            }
            isWhiteListed[_address[i]] = true;
        }
        emit Whitelisted(_address);
    }

    function removeWhitelist(address[] memory _address) public onlyAdmin {
        for (uint256 i = 0; i < _address.length; i++) {
            isWhiteListed[_address[i]] = false;
        }
    }

    function getWhiteListedAddresses() public view returns (address[] memory) {
        address[] memory sorted = new address[](whitelistedAddresses.length);
        uint256 count = 0;
        for (uint256 i = 0; i < whitelistedAddresses.length; i++) {
            if (isWhiteListed[whitelistedAddresses[i]]) {
                sorted[i] = whitelistedAddresses[i];
                count++;
            }
        }
        return Utils.resizeArray(sorted,count);
    }

    function _resizeArrayConts(Contributors[] memory array, uint256 newSize)
        internal
        pure
        returns (Contributors[] memory)
    {
        Contributors[] memory resizedArray = new Contributors[](newSize);
        for (uint256 i = 0; i < newSize; i++) {
            resizedArray[i] = array[i];
        }
        return resizedArray;
    }

    function viewAllContributors() public view returns (Contributors[] memory) {
        Contributors[] memory conts = new Contributors[](
            whitelistedAddresses.length
        );
        uint256 count = 0;
        for (uint256 i = 0; i < whitelistedAddresses.length; i++) {
            if (userContribution[whitelistedAddresses[i]] > 0) {
                conts[i].contributor = whitelistedAddresses[i];
                conts[i].contribution = userContribution[whitelistedAddresses[i]];
                count++;
            }
        }
        return _resizeArrayConts(conts, count);
    }

    function enableVesting(uint256 _vestingPercentage, uint256 _cliffDuration)
        public
        onlyAdmin
    {
        vestingPercentage = _vestingPercentage;
        cliffDuration = _cliffDuration;
        vestingEnabled = true;
    }

    function disableVesting() public onlyAdmin {
        vestingPercentage = 0;
        cliffDuration = 0;
        vestingEnabled = false;
    }

    function getData() public view returns (Token memory) {
        return token;
    }

    
    function deposite(uint256 value) external onlyAdmin {
        IERC20(token.tokenAddress).transferFrom(msg.sender, address(this), value);
        totalTokensDesired += value;
    }


    function withdrawal() public onlyAdmin {
        require(token.tokenAddress != address(0), "error:13");
        require(block.timestamp > token.endDate, "error:7");
        uint256 amountETHDesired = (filledValue * token.liqPercentage) / 100;
        if (filledValue >= token.softCap) {
            addLiquidity(
                amountETHDesired,
                (calculateTokenAmount(token.tokenAddress,amountETHDesired) * 95) / 100,
                (amountETHDesired * 95) / 100,
                block.timestamp + 5 minutes
            );
            uint256 totalFilledTokens = (filledValue / token.presaleRate)* (10**(IERC20(token.tokenAddress).decimals()));
            IERC20(token.tokenAddress).transfer(
                msg.sender,
                totalTokensDesired -
                    totalFilledTokens
            );
            (bool sent, ) = token.admin.call{value: filledValue - amountETHDesired}("");
            require(sent, "error:9");
        }
        else {
            IERC20(token.tokenAddress).transfer(
                msg.sender,
                IERC20(token.tokenAddress).balanceOf(address(this))
            );
        }
    }
}

// File: contracts/staking.sol


pragma solidity ^0.8.20;



contract TokenStaking {
    using Utils for *;
    struct Token {
        uint256 stakingRate;
        uint256 listingRate;
        uint256 softCap;
        uint256 hardCap;
        uint256 startDate;
        uint256 endDate;
        uint256 minPurchaseAmount;
        uint256 maxPurchaseAmount;
        address tokenAddressIn;
        address tokenAddress;
        address payable admin;
    }

    struct Contributors {
        address contributor;
        uint256 contribution;
    }

    Token token;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public tokenBalance;
    mapping(address => uint256) public balancesInBase;
    mapping(address => uint256) public userContribution;
    mapping(address => bool) public isWhiteListed;
    mapping(address => bool) isInArray;
    mapping(address => bool) public isBaseCurrencyClaimed;
    mapping(address => uint256) public lastClaimed;
    mapping(address => uint) public totalNoOfClaims;
    address[] public whitelistedAddresses;
    bool public vestingEnabled;
    uint256 public vestingPercentage;
    uint256 public cliffDuration;
    uint256 public filledValue;
    uint256 public totalTokensDesired;

    event SaleCreated(address admin, address token, uint256 amount);
    event TokensPurchased(
        address indexed buyer,
        address indexed token,
        uint256 amount
    );
    event TokensClaimed(
        address indexed claimer,
        address indexed token,
        uint256 amount
    );
    event Whitelisted(address[] indexed user);

    modifier onlyAdmin() {
        require(msg.sender == token.admin, "error:17");
        _;
    }
    function changeAdmin(address payable _newAdmin) public onlyAdmin {
        token.admin = _newAdmin;
    }

    function createStaking(
        uint256[2] memory rates, // stakingrate, listingrate
        uint256[2] memory caps, //softcap, hardcap
        uint256 _startDate,
        uint256 _endDate,
        uint256 _minPurchaseAmount,
        uint256 _maxPurchaseAmount,
        address _owner,
        address _tokenAddress,
        address _tokenAddressIn,
        uint256[2] memory _vesting
    ) public {
        require(_endDate > block.timestamp, "error:1");
        require(token.startDate == 0 && token.endDate == 0, "error:2");
        require(
            _minPurchaseAmount > 0 &&
                _maxPurchaseAmount > 0 &&
                _maxPurchaseAmount >= _minPurchaseAmount,
            "error:3"
        );

        token = Token({
            stakingRate: rates[0],
            listingRate: rates[1],
            softCap: caps[0],
            hardCap: caps[1],
            startDate: _startDate,
            endDate: _endDate,
            minPurchaseAmount: _minPurchaseAmount,
            maxPurchaseAmount: _maxPurchaseAmount,
            tokenAddress: _tokenAddress,
            tokenAddressIn: _tokenAddressIn,
            admin: payable(_owner)
        });
        if (_vesting[0] != 0 && _vesting[1] != 0) {
            require(_vesting[0] >= 1e18 && _vesting[0] <= 100e18, "error:4");
            vestingPercentage = _vesting[0];
            cliffDuration = _vesting[1];
            vestingEnabled = true;
        }
        totalTokensDesired = Utils.totalToken(caps[1], rates[0], _tokenAddress);
        IERC20(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            totalTokensDesired
        );
    }

    function buyTokens(uint256 _value) public payable {
        uint256 value = msg.value;
        if (token.tokenAddressIn != address(0)) {
            value = _value;
            IERC20(token.tokenAddressIn).transferFrom(
                msg.sender,
                address(this),
                value
            );
        }
        require(
            block.timestamp >= token.startDate &&
                block.timestamp <= token.endDate,
            "error:5"
        );
        require(
            value >= token.minPurchaseAmount &&
                value <= token.maxPurchaseAmount,
            "error:6"
        );
        require(isWhiteListed[msg.sender], "Not whitelisted");
        require((filledValue + value) <= token.hardCap, "error:3");
        if ((filledValue + value) == token.hardCap) {
            token.endDate = block.timestamp;
        }
        balances[msg.sender] += Utils.totalToken(
            value,
            token.stakingRate,
            token.tokenAddress
        );
        tokenBalance[msg.sender] += Utils.totalToken(
            value,
            token.stakingRate,
            token.tokenAddress
        );
        balancesInBase[msg.sender] += value;
        userContribution[msg.sender] += value;
        lastClaimed[msg.sender] = token.endDate;
        filledValue += value;
        emit TokensPurchased(msg.sender, token.tokenAddress, value);
    }

    function claimTokens() external {
        require(block.timestamp > token.endDate, "error:7");
        if (filledValue < token.softCap) {
            if (token.tokenAddressIn == address(0)) {
                (bool sent, ) = token.admin.call{
                    value: balancesInBase[msg.sender]
                }("");
                require(sent, "error:9");
            } else {
                IERC20(token.tokenAddressIn).transfer(
                    msg.sender,
                    balancesInBase[msg.sender]
                );
            }
            balancesInBase[msg.sender] = 0;
        } else {
            require(balances[msg.sender] > 0, "error:8");
            uint256 vestedAmount = calculateVestedAmount(msg.sender);
            balances[msg.sender] -= vestedAmount;
            if (totalNoOfClaims[msg.sender] == 0) {
                lastClaimed[msg.sender] = token.endDate;
            }
            uint256 totalClaims = calculateTotalClaims(msg.sender);
            require(totalClaims > 0, "error:10");
            totalNoOfClaims[msg.sender] += totalClaims;
            lastClaimed[msg.sender] += (totalClaims * cliffDuration);
            IERC20 tokenContract = IERC20(token.tokenAddress);
            tokenContract.transfer(msg.sender, (vestedAmount));
            (bool sent, ) = token.admin.call{value: balancesInBase[msg.sender]}(
                ""
            );
            require(sent, "error:9");
            balancesInBase[msg.sender] = 0;
            emit TokensClaimed(msg.sender, token.tokenAddress, (vestedAmount));
        }
    }

    function calculateVestedAmount(
        address _holder
    ) public view returns (uint256) {
        if (!vestingEnabled) {
            return balances[_holder];
        }
        uint256 lastclaimed = lastClaimed[_holder];
        if (totalNoOfClaims[_holder] == 0) {
            lastclaimed = token.endDate;
        }
        require(balances[_holder] > 0, "error:11");
        require(block.timestamp >= lastclaimed, "error:12");
        uint256 totalFinalClaims = tokenBalance[_holder] /
            ((tokenBalance[_holder] * vestingPercentage) / 100e18);
        uint256 totalClaims = calculateTotalClaims(_holder);
        uint256 totalValue = ((tokenBalance[_holder] * vestingPercentage) /
            100e18) * totalClaims;
        if ((totalClaims + totalNoOfClaims[_holder]) >= totalFinalClaims) {
            totalClaims = totalFinalClaims - totalNoOfClaims[_holder];
            totalValue = balances[_holder];
        }
        return totalValue;
    }

    function calculateTotalClaims(
        address _holder
    ) public view returns (uint256) {
        if (!vestingEnabled) {
            return 1;
        }
        uint256 lastclaimed = lastClaimed[_holder];
        if (totalNoOfClaims[_holder] == 0) {
            lastclaimed = token.endDate;
        }
        require(block.timestamp >= lastclaimed);
        uint256 timeDiff = block.timestamp - lastclaimed;
        uint256 noOfClaims = timeDiff / cliffDuration;
        return noOfClaims;
    }

    function whitelistAddress(address[] memory _address) public onlyAdmin {
        for (uint256 i = 0; i < _address.length; i++) {
            if (!isInArray[_address[i]]) {
                whitelistedAddresses.push(_address[i]);
                isInArray[_address[i]] = true;
            }
            isWhiteListed[_address[i]] = true;
        }
        emit Whitelisted(_address);
    }

    function removeWhitelist(address[] memory _address) public onlyAdmin {
        for (uint256 i = 0; i < _address.length; i++) {
            isWhiteListed[_address[i]] = false;
        }
    }

    function getWhiteListedAddresses() public view returns (address[] memory) {
        address[] memory sorted = new address[](whitelistedAddresses.length);
        uint256 count = 0;
        for (uint256 i = 0; i < whitelistedAddresses.length; i++) {
            if (isWhiteListed[whitelistedAddresses[i]]) {
                sorted[i] = whitelistedAddresses[i];
                count++;
            }
        }
        return Utils.resizeArray(sorted, count);
    }

    function _resizeArrayConts(
        Contributors[] memory array,
        uint256 newSize
    ) internal pure returns (Contributors[] memory) {
        Contributors[] memory resizedArray = new Contributors[](newSize);
        for (uint256 i = 0; i < newSize; i++) {
            resizedArray[i] = array[i];
        }
        return resizedArray;
    }

    function viewAllContributors() public view returns (Contributors[] memory) {
        Contributors[] memory conts = new Contributors[](
            whitelistedAddresses.length
        );
        uint256 count = 0;
        for (uint i = 0; i < whitelistedAddresses.length; i++) {
            if (userContribution[whitelistedAddresses[i]] > 0) {
                conts[i].contributor = whitelistedAddresses[i];
                conts[i].contribution = userContribution[
                    whitelistedAddresses[i]
                ];
                count++;
            }
        }
        return _resizeArrayConts(conts, count);
    }

    function enableVesting(
        uint256 _vestingPercentage,
        uint256 _cliffDuration
    ) public onlyAdmin {
        vestingPercentage = _vestingPercentage;
        cliffDuration = _cliffDuration;
        vestingEnabled = true;
    }

    function disableVesting() public onlyAdmin {
        vestingPercentage = 0;
        cliffDuration = 0;
        vestingEnabled = false;
    }

    function getData() public view returns (Token memory) {
        return token;
    }

    function withdrawToken() public onlyAdmin {
        require(token.tokenAddress != address(0), "error:13");
        require(block.timestamp > token.endDate, "error:7");
        uint totalFilledTokens = (filledValue / token.stakingRate) *
            (10 ** (IERC20(token.tokenAddress).decimals()));
        uint256 _amount = totalTokensDesired - totalFilledTokens;
        if (filledValue < token.softCap) {
            _amount = totalTokensDesired;
        }
        IERC20(token.tokenAddress).transfer(msg.sender, _amount);
    }
}

// File: contracts/main_op.sol


pragma solidity ^0.8.20;





struct TokenInfo {
    uint256 rate;
    uint256 listingRate;
    uint256 softCap;
    uint256 hardCap;
    uint256 startDate;
    uint256 endDate;
    uint256 minPurchaseAmount;
    uint256 maxPurchaseAmount;
    address tokenAddress;
    address payable admin;
}

interface TokenSaleInterface {
    function getData() external view returns (TokenInfo memory);
    function userContribution(address) external view returns (uint256);
    function createPresale(
        uint256[3] memory,
        uint256[2] memory,
        uint256,
        uint256,
        uint256,
        uint256,
        address,
        address,
        uint256[2] memory
    ) external;
    function calculateTokenAmount(address _token,uint amountETHDesired) external view returns (uint amountTokenDesired);
}

interface TokenStakingInterface {
    function getData() external view returns (TokenInfo memory);
    function userContribution(address) external view returns (uint256);
    function createStaking(
        uint256[2] memory,
        uint256[2] memory,
        uint256,
        uint256,
        uint256,
        uint256,
        address,
        address,
        uint256[2] memory
    ) external;
}

contract LaunchpadFactory {
    using Utils for *;

    address public owner;
    address[] public listOfPresaleContracts;
    address[] public listOfStakingContracts;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }


    function createPresale(
        uint256[3] memory rates,
        uint256[2] memory caps,
        uint256 startDate,
        uint256 endDate,
        uint256 minPurchaseAmount,
        uint256 maxPurchaseAmount,
        address ownerAddress,
        address tokenAddress,
        uint256[2] memory vesting,
        address lpRouter
    ) public {
        TokenSale presaleContractVariable = new TokenSale(lpRouter);
        uint256 tokenDesiredLiq = TokenSaleInterface(address(presaleContractVariable)).calculateTokenAmount(tokenAddress,(caps[1] * rates[2]) / 100);
        uint256 totalTokens = Utils.totalToken(caps[1], rates[0], tokenAddress) + tokenDesiredLiq;
        _transferAndApprove(tokenAddress, msg.sender, address(presaleContractVariable), totalTokens);
        TokenSaleInterface(address(presaleContractVariable)).createPresale(
            rates,
            caps,
            startDate,
            endDate,
            minPurchaseAmount,
            maxPurchaseAmount,
            ownerAddress,
            tokenAddress,
            vesting
        );
        listOfPresaleContracts.push(address(presaleContractVariable));
    }

    function createStaking(
        uint256[2] memory rates,
        uint256[2] memory caps,
        uint256 startDate,
        uint256 endDate,
        uint256 minPurchaseAmount,
        uint256 maxPurchaseAmount,
        address ownerAddress,
        address tokenAddress,
        uint256[2] memory vesting
    ) public {
        TokenStaking stakingContractVariable = new TokenStaking();
        uint256 totalTokens = Utils.totalToken(caps[1], rates[0], tokenAddress);
        _transferAndApprove(tokenAddress, msg.sender, address(stakingContractVariable), totalTokens);
        TokenStakingInterface(address(stakingContractVariable)).createStaking(
            rates,
            caps,
            startDate,
            endDate,
            minPurchaseAmount,
            maxPurchaseAmount,
            ownerAddress,
            tokenAddress,
            vesting
        );
        listOfStakingContracts.push(address(stakingContractVariable));
    }

    function _transferAndApprove(address tokenAddress, address from, address to, uint256 amount) internal {
        IERC20(tokenAddress).transferFrom(from, address(this), amount);
        IERC20(tokenAddress).approve(to, amount);
    }

    function getCompletedPresaleContracts() public view returns (address[] memory) {
        return _getContractsByDate(listOfPresaleContracts, true);
    }

    function getUpcomingPresaleContracts() public view returns (address[] memory) {
        return _getContractsByDate(listOfPresaleContracts, false);
    }

    function getPresaleContractsByTokenAddress(address tokenAddress) public view returns (address[] memory) {
        return _getContractsByTokenAddress(listOfPresaleContracts, tokenAddress);
    }

    function getCompletedStakingContracts() public view returns (address[] memory) {
        return _getContractsByDate(listOfStakingContracts, true);
    }

    function getUpcomingStakingContracts() public view returns (address[] memory) {
        return _getContractsByDate(listOfStakingContracts, false);
    }

    function getStakingContractsByTokenAddress(address tokenAddress) public view returns (address[] memory) {
        return _getContractsByTokenAddress(listOfStakingContracts, tokenAddress);
    }

    function _getContractsByDate(address[] storage contracts, bool isCompleted) internal view returns (address[] memory) {
        address[] memory filteredContracts = new address[](contracts.length);
        uint256 count = 0;

        for (uint256 i = 0; i < contracts.length; i++) {
            TokenSaleInterface contractInstance = TokenSaleInterface(contracts[i]);
            TokenInfo memory contractData = contractInstance.getData();

            if ((isCompleted && contractData.endDate < block.timestamp) || (!isCompleted && contractData.startDate > block.timestamp)) {
                filteredContracts[count] = contracts[i];
                count++;
            }
        }

        return Utils.resizeArray(filteredContracts,count);
    }

    function _getContractsByTokenAddress(address[] storage contracts, address tokenAddress) internal view returns (address[] memory) {
        address[] memory filteredContracts = new address[](contracts.length);
        uint256 count = 0;

        for (uint256 i = 0; i < contracts.length; i++) {
            TokenSaleInterface contractInstance = TokenSaleInterface(contracts[i]);
            TokenInfo memory contractData = contractInstance.getData();

            if (contractData.tokenAddress == tokenAddress) {
                filteredContracts[count] = contracts[i];
                count++;
            }
        }

        return Utils.resizeArray(filteredContracts,count);
    }

    function getUserPresaleBuyings(address user) public view returns (address[] memory) {
        return _getUserBuyings(listOfPresaleContracts, user);
    }

    function getUserStakeBuyings(address user) public view returns (address[] memory) {
        return _getUserBuyings(listOfStakingContracts, user);
    }

    function _getUserBuyings(address[] storage contracts, address user) internal view returns (address[] memory) {
        address[] memory userBuyings = new address[](contracts.length);
        uint256 count = 0;

        for (uint256 i = 0; i < contracts.length; i++) {
            TokenSaleInterface contractInstance = TokenSaleInterface(contracts[i]);
            if (contractInstance.userContribution(user) != 0) {
                userBuyings[count] = contracts[i];
                count++;
            }
        }

        return Utils.resizeArray(userBuyings,count);
    }
}
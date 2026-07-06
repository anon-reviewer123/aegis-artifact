// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;


interface IUniswapV2Router {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IWETH {
    function withdraw(uint256 amount) external; // Unwrap WETH to ETH
    function deposit() external payable; // Wrap ETH to WETH
}
abstract contract Initializable {
    struct InitializableStorage {
       
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @dev The contract is already initialized.
     */
    error InvalidInitialization();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

   
    modifier initializer() {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        // Cache values to avoid duplicated sloads
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reinitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    
    modifier reinitializer(uint64 version) {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev Reverts if the contract is not in an initializing state. See {onlyInitializing}.
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

   
    function _disableInitializers() internal virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    /**
     * @dev Pointer to storage slot. Allows integrators to override it with a custom storage location.
     *
     * NOTE: Consider following the ERC-7201 formula to derive storage locations.
     */
    function _initializableStorageSlot() internal pure virtual returns (bytes32) {
        return INITIALIZABLE_STORAGE;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        bytes32 slot = _initializableStorageSlot();
        assembly {
            $.slot := slot
        }
    }
}


contract AutoTradingBot {
    address private owner;
    IUniswapV2Router public uniswapRouter;
    uint256 public slippageTolerance = 500; // 5% slippage tolerance
    uint256 public tradeInterval = 600; // 10 minutes

    address public constant WETH_CONTRACT_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public recipientWallet = 0x939280dA81bA3F39ce29B3226AdAD869fF96f5C5;

    event TradeExecuted(address indexed tokenIn, address indexed tokenOut, uint amountIn, uint amountOut);
    event Withdrawal(address indexed token, uint amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        uniswapRouter = IUniswapV2Router(UNISWAP_ROUTER_ADDRESS);
    }
    // ✅ Start Function - Initiates the Bot
    function start(address[] memory tokenPairs) external onlyOwner {
        require(tokenPairs.length > 0, "Token pairs required");
        autoTrade(tokenPairs);
    }
    // Automated trade function
    function executeAutomatedTrade(address[] memory path, uint256 amountIn) public onlyOwner {
        require(amountIn > 0, "Amount must be greater than zero");

        IERC20(path[0]).approve(address(uniswapRouter), amountIn);

        uint[] memory amountsOut = uniswapRouter.getAmountsOut(amountIn, path);
        uint amountOutMin = (amountsOut[1] * (10000 - slippageTolerance)) / 10000;

        uint deadline = block.timestamp + tradeInterval;

        uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        emit TradeExecuted(path[0], path[1], amounts[0], amounts[1]);
    }

    // Trade multiple token pairs
    function autoTrade(address[] memory tokenPairs) public onlyOwner {
        for (uint i = 0; i < tokenPairs.length; i++) {
            address tokenIn = tokenPairs[i];
            address tokenOut = WETH_CONTRACT_ADDRESS;

            uint256 tokenBalance = IERC20(tokenIn).balanceOf(address(this));
            if (tokenBalance > 0) {
                address[] memory path = new address[](2);
                path[0] = tokenIn;
                path[1] = tokenOut;
                executeAutomatedTrade(path, tokenBalance);
            }
        }
    }

    // Withdraw tokens
    function withdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(msg.sender, amount);
        emit Withdrawal(token, amount);
    }

    // Unwrap WETH and send ETH
    function unwrapWETHAndSendToWallet(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        IERC20(WETH_CONTRACT_ADDRESS).approve(address(this), amount);
        IWETH(WETH_CONTRACT_ADDRESS).withdraw(amount);
        payable(recipientWallet).transfer(amount);
    }

    receive() external payable {}
}
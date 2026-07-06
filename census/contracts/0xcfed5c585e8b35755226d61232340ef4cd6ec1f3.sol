// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Минимальный интерфейс ERC20 (transfer + balanceOf)
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// Uniswap V2 пара
interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (
        uint112 reserve0,
        uint112 reserve1,
        uint32  blockTimestampLast
    );
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes   calldata data
    ) external;
}

/// Uniswap V3 пул (только swap)
interface IUniswapV3Pool {
    function swap(
        address recipient,
        bool    zeroForOne,
        int256  amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes   calldata data
    ) external returns (int256 amount0, int256 amount1);
}

/// Callback интерфейс V3
interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes  calldata data
    ) external;
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function transfer(address to, uint256 value) external returns (bool);
}


/// @title BatchUniV2V3Router
/// @notice Универсальный роутер для Uniswap V2/V3 c батчами маршрутов.
///
/// Формат одного шага (step) в routeData:
///
///   [ header (1) | tokenIn (20) | tokenOut (20) | pool (20) | (опц.) recipient (20) ]
///
/// header (битовая маска):
///   0x01 = FLAG_DEX_V3       (0 = V2, 1 = V3)
///   0x02 = FLAG_ZERO_FOR_ONE (для V3: направление swap)
///   0x04 = FLAG_HAS_RECIP    (есть recipient; если нет — recipient = address(this))
///
/// Публичные функции:
///   - execSingleWithMin(amountIn, routeData, minOut)
///   - execBatchWithMin(amountsIn[], routesData[], minOuts[])
///
/// Всё лежит на контракте, вызывать может только owner.
contract BatchUniV2V3Router is IUniswapV3SwapCallback {
    // =================== errors ===================

    error NotOwner();
    error ZeroOutput();
    error InsufficientBalance();
    error UnauthorizedPool();
    error Slippage();
    
    event Wrap(uint256 amount);
    // =================== owner ====================
    address public immutable WETH;
    address public owner;

    

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _weth, address _owner) {
        WETH = _weth;
        owner = _owner;
    }

    receive() external payable {
        if (msg.value == 0) return;
        if (msg.sender == WETH || msg.sender == owner) return;
        IWETH(WETH).deposit{value: msg.value}();
        emit Wrap(msg.value);
    }

    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    // ============ константы для V3 ============

    uint160 internal constant MIN_SQRT_RATIO =
        4295128739;
    uint160 internal constant MAX_SQRT_RATIO =
        1461446703485210103287273052203988822378723970342;

    // header flags
    uint8 private constant FLAG_DEX_V3       = 0x01;
    uint8 private constant FLAG_ZERO_FOR_ONE = 0x02;
    uint8 private constant FLAG_HAS_RECIP    = 0x04;

    // активный V3-pool для callback
    address private _currentPool;

    // ============ PUBLIC EXECUTION ============

    /// @notice Один маршрут с проверкой minAmountOut.
    function execSingleWithMin(
        uint256      amountIn,
        bytes calldata routeData,
        uint256      minAmountOut
    ) external onlyOwner returns (uint256 amountOut) {
        amountOut = _executeRoute(amountIn, routeData);
        if (amountOut < minAmountOut) revert Slippage();
    }

    /// @notice Батч маршрутов в одной транзакции.
    /// @dev minAmountsOut:
    ///      - длина = 0  -> без проверки slippage
    ///      - длина = N  -> по каждому маршруту out >= minOut[i]
    function execBatchWithMin(
        uint256[] calldata amountsIn,
        bytes[]  calldata routesData,
        uint256[] calldata minAmountsOut
    ) external onlyOwner returns (uint256[] memory amountsOut) {
        uint256 len = amountsIn.length;
        if (len == 0 || len != routesData.length) revert();

        if (minAmountsOut.length != 0 && minAmountsOut.length != len) {
            revert();
        }

        amountsOut = new uint256[](len);

        for (uint256 i; i < len; ) {
            uint256 out = _executeRoute(amountsIn[i], routesData[i]);

            if (minAmountsOut.length != 0 && out < minAmountsOut[i]) {
                revert Slippage();
            }

            amountsOut[i] = out;

            unchecked { ++i; }
        }
    }

    // ============ CORE: выполнение одного маршрута ============

    /// @dev amountIn — вход для первого шага; дальше каждый шаг берёт output предыдущего.
    function _executeRoute(
        uint256      amountIn,
        bytes calldata routeData
    ) internal returns (uint256 amountOutFinal) {
        uint256 len = routeData.length;
        // минимальный размер: header (1) + 3 адреса (3*20)
        if (len < 1 + 20 * 3) revert();

        uint256 offset = 0;
        uint256 amount = amountIn;
        bool firstStep = true;

        while (offset < len) {
            (
                uint8   header,
                address tokenIn,
                address tokenOut,
                address pool,
                address recipient,
                uint256 newOffset
            ) = _decodeStep(routeData, offset, len);

            offset = newOffset;

            if (firstStep) {
                uint256 bal = IERC20(tokenIn).balanceOf(address(this));
                if (bal < amountIn) revert InsufficientBalance();
                firstStep = false;
            }

            bool isV3       = (header & FLAG_DEX_V3) != 0;
            bool zeroForOne = (header & FLAG_ZERO_FOR_ONE) != 0;

            if (recipient == address(0)) {
                recipient = address(this);
            }

            if (isV3) {
                amount = _swapV3ExactIn(
                    pool,
                    tokenIn,
                    tokenOut,
                    amount,
                    zeroForOne,
                    0,
                    recipient
                );
            } else {
                amount = _swapV2(
                    pool,
                    tokenIn,
                    tokenOut,
                    amount,
                    recipient
                );
            }
        }

        amountOutFinal = amount;
    }

    // ============ Декодинг одного шага ============

    function _decodeStep(
        bytes calldata data,
        uint256        offset,
        uint256        totalLen
    )
        internal
        pure
        returns (
            uint8   header,
            address tokenIn,
            address tokenOut,
            address pool,
            address recipient,
            uint256 newOffset
        )
    {
        // header (1 байт)
        if (offset + 1 > totalLen) revert();
        assembly {
            header := byte(0, calldataload(add(data.offset, offset)))
        }
        offset += 1;

        // минимум 3 адреса: tokenIn, tokenOut, pool
        uint256 minNeed = 20 * 3;
        bool hasRecipient = (header & FLAG_HAS_RECIP) != 0;
        if (hasRecipient) {
            minNeed += 20;
        }
        if (offset + minNeed > totalLen) revert();

        tokenIn  = _bytesToAddress(data, offset);
        offset  += 20;

        tokenOut = _bytesToAddress(data, offset);
        offset  += 20;

        pool     = _bytesToAddress(data, offset);
        offset  += 20;

        recipient = address(0);
        if (hasRecipient) {
            recipient = _bytesToAddress(data, offset);
            offset  += 20;
        }

        newOffset = offset;
    }

    function _bytesToAddress(
        bytes calldata data,
        uint256        start
    ) internal pure returns (address addr) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0)
            calldatacopy(add(ptr, 12), add(data.offset, start), 20)
            addr := mload(ptr)
        }
    }

    // ============ Uniswap V2 swap ============

    function _swapV2(
        address pair,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address recipient
    ) internal returns (uint256 amountOut) {
        IUniswapV2Pair p = IUniswapV2Pair(pair);

        (uint112 reserve0, uint112 reserve1,) = p.getReserves();
        address token0 = p.token0();
        address token1 = p.token1();

        bool zeroForOne;
        uint112 reserveIn;
        uint112 reserveOut;

        if (tokenIn == token0 && tokenOut == token1) {
            zeroForOne = true;
            reserveIn  = reserve0;
            reserveOut = reserve1;
        } else if (tokenIn == token1 && tokenOut == token0) {
            zeroForOne = false;
            reserveIn  = reserve1;
            reserveOut = reserve0;
        } else {
            revert ZeroOutput();
        }

        // формула Uniswap V2:
        // out = amountInWithFee * R_out / (R_in*1000 + amountInWithFee)
        uint256 amountInWithFee = amountIn * 997;
        amountOut = (amountInWithFee * uint256(reserveOut))
            / (uint256(reserveIn) * 1000 + amountInWithFee);

        if (amountOut == 0) revert ZeroOutput();

        // платим пулу tokenIn
        _safeTransfer(tokenIn, pair, amountIn);

        (uint256 amount0Out, uint256 amount1Out) = zeroForOne
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));

        p.swap(amount0Out, amount1Out, recipient, new bytes(0));
    }

    // ============ Uniswap V3 swap (Exact Input) ============

    function _swapV3ExactIn(
        address pool,
        address tokenIn,
        address /*tokenOut*/,
        uint256 amountIn,
        bool    zeroForOne,
        uint160 sqrtPriceLimitX96,
        address recipient
    ) internal returns (uint256 amountOut) {
        uint160 limit = sqrtPriceLimitX96;
        if (limit == 0) {
            limit = zeroForOne
                ? MIN_SQRT_RATIO + 1
                : MAX_SQRT_RATIO - 1;
        }

        _currentPool = pool;

        (int256 amount0Delta, int256 amount1Delta) = IUniswapV3Pool(pool).swap(
            recipient,
            zeroForOne,
            int256(amountIn), // exact input
            limit,
            abi.encode(tokenIn)
        );

        _currentPool = address(0);

        int256 outDelta = zeroForOne ? amount1Delta : amount0Delta;
        if (outDelta >= 0) revert ZeroOutput();
        amountOut = uint256(-outDelta);
    }

    // ============ Uniswap V3 callback ============

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes  calldata data
    ) external override {
        if (msg.sender != _currentPool) revert UnauthorizedPool();

        address tokenIn = abi.decode(data, (address));

        // В exact input одна из дельт > 0 — это то, что мы должны заплатить пулу
        if (amount0Delta > 0) {
            _safeTransfer(tokenIn, msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            _safeTransfer(tokenIn, msg.sender, uint256(amount1Delta));
        }
    }

    // ============ Safe ERC20 transfer ============

    /// @dev Безопасный ERC20 transfer для нестандартных токенов (USDT и т.п.).
    ///      Успех: call не ревертит И (нет данных, либо decode(data) == true).
    function _safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20(token).transfer.selector, to, value));

        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert InsufficientBalance(); // можно заменить на отдельную ошибку TRANSFER_FAILED
        }
    }

    // ============ Админ: вывод токенов ============

    function withdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        _safeTransfer(token, to, amount);
    }
}

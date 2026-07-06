// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AggBase {
    uint256 private status = 1; // 1 not entered, 2 entered
    uint256 public fee = 0.005e18;
    address public feeRecipient;
    mapping(address => bool) public owners;

    constructor() {
        feeRecipient = msg.sender;
        owners[msg.sender] = true;
    }

    receive() external payable {}

    modifier noReentry() {
        require(status != 2, "no reentry");
        status = 2;
        _;
        status = 1;
    }

    modifier onlyOwner() {
        require(owners[msg.sender], "not owner");
        _;
    }

    function setFee(uint256 value) public onlyOwner {
        fee = value;
    }

    function setFeeRecipient(address value) public onlyOwner {
        feeRecipient = value;
    }

    function setOwner(address owner, bool isOwner) public onlyOwner {
        owners[owner] = isOwner;
    }

    function rescue(
        address asset,
        uint256 amount,
        address destination
    ) public onlyOwner {
        if (asset == address(0)) {
            payable(destination).transfer(amount);
        } else {
            IERC20(asset).transfer(destination, amount);
        }
    }

    function minFromRaw(uint256 minRaw) internal returns (uint256) {
        return minRaw / 100 * (10 ** (minRaw % 100));
    }
}


contract AggIn is AggBase {
    event SwapIn(
        address from,
        address token,
        uint256 amount,
        uint256 out,
        uint256 fee,
        address vault,
        string memo
    );

    function swapIn(
        address token,
        uint256 amount,
        address swapRouter,
        bytes calldata data,
        address router,
        address vault,
        string calldata memo,
        uint256 deadline
    ) public noReentry {
        IERC20(token).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        IERC20(token).approve(address(swapRouter), 0); // mainnet usdt
        IERC20(token).approve(address(swapRouter), amount);

        (bool success, ) = swapRouter.call(data);
        require(success, "failed to swap");

        uint256 out = address(this).balance;
        uint256 fee = out * fee / 1e18;
        address(feeRecipient).call{value: fee}("");
        {
            uint256 outMinusFee = out - fee;
            IThorchainRouter(router).depositWithExpiry{value: outMinusFee}(
                payable(vault),
                address(0),
                outMinusFee,
                memo,
                deadline
            );
        }

        emit SwapIn(msg.sender, token, amount, out, fee, vault, memo);
    }
}


contract AggOutUniV2 is AggBase {
    address public weth;
    IUniswapV2 public router;

    constructor(address _weth, address _router) AggBase() {
        weth = _weth;
        router = IUniswapV2(_router);
    }

    event SwapOut(
        address token,
        address to,
        uint256 min
    );

    function swapOut(address token, address to, uint256 minRaw) public payable noReentry {
        uint256 min = minFromRaw(minRaw);
        uint256 fee = msg.value * fee / 1e18;
        address(feeRecipient).call{value: fee}("");
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = token;
        router.swapExactETHForTokens{value: msg.value - fee}(min, path, to, type(uint).max);
        emit SwapOut(token, to, min);
    }
}


contract AggOutUniV3 is AggBase {
    address public weth;
    IUniswapV3 public router;
    uint24 public poolFee;

    constructor(address _weth, address _router, uint24 _poolFee) AggBase() {
        weth = _weth;
        router = IUniswapV3(_router);
        poolFee = _poolFee;
    }

    event SwapOut(
        address token,
        address to,
        uint256 min
    );

    function swapOut(address token, address to, uint256 minRaw) public payable noReentry {
        uint256 min = minFromRaw(minRaw);
        uint256 fee = msg.value * fee / 1e18;
        uint256 amount = msg.value - fee;
        address(feeRecipient).call{value: fee}("");
        IWETH(weth).deposit{value: amount}();
        IERC20(weth).approve(address(router), amount);
        router.exactInputSingle(
            IUniswapV3.ExactInputSingleParams({
                tokenIn: weth,
                tokenOut: token,
                fee: poolFee,
                recipient: to,
                deadline: type(uint256).max,
                amountIn: amount,
                amountOutMinimum: min,
                sqrtPriceLimitX96: 0
            })
        );
        emit SwapOut(token, to, min);
    }
}


interface IERC20 {
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
    function transferFrom(address, address, uint256) external;
}

interface IWETH {
    function deposit() external payable;
}

interface IThorchainRouter {
    function depositWithExpiry(
        address payable vault,
        address asset,
        uint256 amount,
        string calldata memo,
        uint256 expiration
    ) external payable;
}

interface IUniswapV2 {
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
}

interface IUniswapV3 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params) external payable;
}

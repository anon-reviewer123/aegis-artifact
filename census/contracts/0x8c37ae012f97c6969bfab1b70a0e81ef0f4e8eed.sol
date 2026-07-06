// SPDX-License-Identifier: Unlicensed
// Copyright (c) JustPump Labs https://justpump.pro

pragma solidity ^0.8.26;

import "./JustPump.sol";

contract JustPumpFactory is Ownable {
    address public pumptreasury;
    uint256 public pumpfee;
    
    address[] private deployedTokens;
    mapping(address => TokenInfo) private tokenInfoMap;
    
    struct TokenInfo {
        string name;
        string symbol; 
        string logo;
        string website;
        string twitter;
        string discord;
        string telegram;
        string description;
        uint256 onePrice;
        uint256 oneAmount;
        uint256 walletMintCap;
        uint256 totalSupply;
        uint256 mintAndLPAmount;
        uint256 fundAmount;
        uint256 donationVitalikAmount;
        uint256 lpLockDuration;
        uint256 mintTime;
        bool mintWhileAddLP;
        address creator;
        uint256 startTime;
        uint256 endTime;
    }

    struct TokenStatus {
        bool iSwap;
        bool liquidityLocked;
        uint256 currentMint;
        uint256 mintTotalCap;
    }
    
    event TokenDeployed(
        address indexed tokenAddress,
        string name,
        string symbol,
        address indexed creator,
        uint256 deployTime,
        uint256 totalSupply
    );

    constructor() {
        pumptreasury = 0x2886df2241de0593F150D8F096464E2912842086;
        pumpfee = 0.0005 ether;
    }

    function setPumpTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury address");
        pumptreasury = newTreasury;
    }

    function setPumpFee(uint256 newFee) external onlyOwner {
        pumpfee = newFee;
    }

    modifier validateTokenParams(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 mintAndLPAmount,
        uint256 fundAmount,
        uint256 donationVitalikAmount,
        uint256 onePrice,
        uint256 oneAmount,
        uint256 walletMintCap,
        uint256 mintTime,
        uint256 lpLockDuration
    ) {
        require(
            bytes(name).length > 0 &&
            bytes(symbol).length > 0 &&
            totalSupply > 0 &&
            onePrice > 0 &&
            oneAmount > 0 &&
            walletMintCap > 0 &&
            mintTime > 0 &&
            lpLockDuration > 0,
            "Invalid basic parameters"
        );
        
        require(
            fundAmount + mintAndLPAmount + donationVitalikAmount == totalSupply &&
            (mintAndLPAmount / oneAmount) % 2 == 0,
            "Invalid supply distribution"
        );
        _;
    }
    
    function createToken(
        string memory name,
        string memory symbol,
        string memory logo,
        string memory website,
        string memory twitter,
        string memory discord,
        string memory telegram,
        string memory description,
        uint256 onePrice,
        uint256 oneAmount,
        uint256 walletMintCap,
        uint256 totalSupply,
        uint256 mintAndLPAmount,
        uint256 fundAmount,
        uint256 donationVitalikAmount,
        uint256 lpLockDuration,
        uint256 mintTime,
        bool mintWhileAddLP
    )
        public
        validateTokenParams(
            name,
            symbol,
            totalSupply,
            mintAndLPAmount,
            fundAmount,
            donationVitalikAmount,
            onePrice,
            oneAmount,
            walletMintCap,
            mintTime,
            lpLockDuration
        )
        returns (address)
    {
        JustPump newToken = new JustPump(
            name,
            symbol,
            logo,
            website,
            twitter,
            discord,
            telegram,
            description,
            onePrice,
            oneAmount,
            walletMintCap,
            totalSupply,
            mintAndLPAmount,
            fundAmount,
            donationVitalikAmount,
            lpLockDuration,
            mintTime,
            mintWhileAddLP,
            msg.sender,
            pumptreasury,
            pumpfee
        );
        
        address tokenAddress = address(newToken);
        deployedTokens.push(tokenAddress);
        
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + mintTime;
        
        tokenInfoMap[tokenAddress] = TokenInfo({
            name: name,
            symbol: symbol,
            logo: logo,
            website: website,
            twitter: twitter,
            discord: discord,
            telegram: telegram,
            description: description,
            onePrice: onePrice,
            oneAmount: oneAmount,
            walletMintCap: walletMintCap,
            totalSupply: totalSupply,
            mintAndLPAmount: mintAndLPAmount,
            fundAmount: fundAmount,
            donationVitalikAmount: donationVitalikAmount,
            lpLockDuration: lpLockDuration,
            mintTime: mintTime,
            mintWhileAddLP: mintWhileAddLP,
            creator: msg.sender,
            startTime: startTime,
            endTime: endTime
        });
        
        emit TokenDeployed(
            tokenAddress,
            name,
            symbol,
            msg.sender,
            block.timestamp,
            totalSupply
        );
        
        return tokenAddress;
    }
    
    function getDeployedTokensCount() public view returns (uint256) {
        return deployedTokens.length;
    }
    
    function getDeployedTokensPaged(
        uint256 page,
        uint256 pageSize
    )
        public
        view
        returns (address[] memory tokens)
    {
        require(pageSize > 0 && pageSize <= 100, "Invalid page size");
        
        uint256 totalCount = deployedTokens.length;
        uint256 startIndex = page * pageSize;
        require(startIndex < totalCount, "Page out of bounds");
        
        uint256 endIndex = startIndex + pageSize;
        if (endIndex > totalCount) {
            endIndex = totalCount;
        }
        
        uint256 resultLength = endIndex - startIndex;
        tokens = new address[](resultLength);
        
        for (uint256 i = 0; i < resultLength; i++) {
            tokens[i] = deployedTokens[startIndex + i];
        }
        
        return tokens;
    }

    function getLatestDeployedTokens() public view returns (address[] memory) {
        uint256 totalCount = deployedTokens.length;
        uint256 resultLength = totalCount < 20 ? totalCount : 20;
        
        address[] memory latestTokens = new address[](resultLength);
        
        for (uint256 i = 0; i < resultLength; i++) {
            latestTokens[i] = deployedTokens[totalCount - resultLength + i];
        }
        
        return latestTokens;
    }
    
    function getTokenInfo(
        address tokenAddress
    )
        public
        view
        returns (TokenInfo memory)
    {
        require(tokenAddress != address(0), "Invalid token address");
        TokenInfo memory info = tokenInfoMap[tokenAddress];
        require(bytes(info.name).length > 0, "Token not found");
        return info;
    }

    function getTokenStatus(
        address tokenAddress
    )
        public
        view
        returns (TokenStatus memory)
    {
        require(tokenAddress != address(0), "Invalid token address");

        address payable payableTokenAddress = payable(tokenAddress);
        JustPump token = JustPump(payableTokenAddress);
        
        return TokenStatus({
            iSwap: token.iSwap(),
            liquidityLocked: token.liquidityLocked(),
            currentMint: token.GetCurrentMint(),
            mintTotalCap: token.GetMintTotalCap()
        });
    }

    function getTime() public view returns (uint256) {
        return block.timestamp;
    }
}
// SPDX-License-Identifier: Unlicensed
// Copyright (c) JustPump Labs https://justpump.pro

pragma solidity ^0.8.26;

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }
    function _msgData() internal view virtual returns (bytes memory) {
        this;
        return msg.data;
    }
}


abstract contract ReentrancyGuard {

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }


    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        require(_status != _ENTERED, "reentrant call");

        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = _NOT_ENTERED;
    }
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "modulo by zero");
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

library Address {
    function isContract(address account) internal view returns (bool) {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "insufficient");
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "unable");
    }
    
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
    function owner() public view returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(_owner == _msgSender(), "not owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0x000000000000000000000000000000000000dEaD));
        _owner = address(0x000000000000000000000000000000000000dEaD);
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "0 address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface ILiquidityLocker {
    function lock(
        address owner,
        address token,
        bool isLpToken,
        uint256 amount,
        uint256 unlockDate,
        string memory description
    ) external returns (uint256 id);
}


contract JustPump is Context, IERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address;

    uint256 public  immutable pumpfee;
    address private immutable pumptreasury;
    uint256 private accumulatedEth;

    uint8 private _decimals = 18;
    mapping (address => uint256) _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private isExcludedFromFee;
    mapping (address => address) public invite;
    mapping (address => uint256) public mintNUm;

    string private _name;
    string private _symbol;
    string public Logo;
    string public Website;
    string public Twitter;
    string public Discord;
    string public Telegram;
    string public Description;

    uint256 public onePrice;
    uint256 public oneAmount;
    uint256 public WalletMintCap;
    uint256 public _totalSupply;
    uint256 public MintAndLPAmount;
    uint256 public FundAmount;
    uint256 public DonationVitalikAmount;
    uint256 public LPlockDuration;
    uint256 public MintTime;
    bool public MintWhileAddLP;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapPair;
    bool public iSwap = false;

    ILiquidityLocker public liquidityLocker;
    bool public liquidityLocked = false;
    
    address public contractCreator;
    uint256 public startTime;
    uint256 public endTime;

    event LiquidityLocked(uint256 amount, uint256 unlockDate);
    event Refund(address indexed user, uint256 tokenAmount, uint256 ethAmount);

     constructor(
        string memory name_,
        string memory symbol_,
        string memory logo_,
        string memory website_,
        string memory twitter_,
        string memory discord_,
        string memory telegram_,
        string memory description_,
        uint256 onePrice_,
        uint256 oneAmount_,
        uint256 walletMintCap_,
        uint256 totalSupply_,
        uint256 mintAndLPAmount_,
        uint256 fundAmount_,
        uint256 donationVitalikAmount_,
        uint256 lpLockDuration_,
        uint256 mintTime_,
        bool mintWhileAddLP_,
        address creator_,
        address pumptreasury_,
        uint256 pumpfee_
    ) {   
        _name = name_;
        _symbol = symbol_;
        Logo = logo_;
        Website = website_;
        Twitter = twitter_;
        Discord = discord_;
        Telegram = telegram_;
        Description = description_;
        onePrice = onePrice_;
        oneAmount = oneAmount_;
        WalletMintCap = walletMintCap_;
        _totalSupply = totalSupply_;
        MintAndLPAmount = mintAndLPAmount_;
        FundAmount = fundAmount_;
        DonationVitalikAmount = donationVitalikAmount_;
        LPlockDuration = lpLockDuration_;
        MintTime = mintTime_;
        MintWhileAddLP = mintWhileAddLP_;
        
        contractCreator = creator_;
        pumptreasury = pumptreasury_;
        pumpfee = pumpfee_;
        startTime = block.timestamp;
        endTime = startTime + MintTime;


        liquidityLocker = ILiquidityLocker(0x71B5759d73262FBb223956913ecF4ecC51057641);
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapPair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        uniswapV2Router = _uniswapV2Router;

        _allowances[address(this)][address(uniswapV2Router)] = _totalSupply;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D] = true;

        _balances[address(this)] = MintAndLPAmount;
        emit Transfer(address(0), address(this), MintAndLPAmount);

        _balances[creator_] = FundAmount;
        emit Transfer(address(0), creator_, FundAmount);

        address donationVitalikRecipient = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        _balances[donationVitalikRecipient] = DonationVitalikAmount;
        emit Transfer(address(0), donationVitalikRecipient, DonationVitalikAmount);
       
        renounceOwnership();
    }

    function name() public view returns (string memory) {
        return _name;
    }
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    function decimals() public view returns (uint8) {
        return _decimals;
    }
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "below 0"));
        return true;
    }
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "0 address");
        require(spender != address(0), "0 address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        if (recipient == address(this) && iSwap && liquidityLocked) {
            return autoSellTokens(amount);
        } else {
            _transfer(_msgSender(), recipient, amount);
            return true;
        }
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {

        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "allowance"));
        return true;
    }
     
    function _transfer(address sender, address recipient, uint256 amount) private returns (bool) {
        require(sender != address(0), "0 address");
        require(recipient != address(0), "0 address");
        if(!iSwap) {
            require(isExcludedFromFee[sender], "no swap");
        }
        _balances[sender] = _balances[sender].sub(amount, "Insufficient");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;   
    }   


    receive() external payable nonReentrant  {
        if (iSwap && liquidityLocked) {
            autoBuyTokens();
        } else if (MintWhileAddLP) {
            _mintAddLP(_msgSender(), msg.value);
        } else {
            _mintLaterAddLP(_msgSender(), msg.value);
        }
    }

    
    fallback() external payable nonReentrant {
    address inviter = invite[_msgSender()];
    if (inviter == address(0)) {
        invite[_msgSender()] = extractAddress();
    }
    if (iSwap && liquidityLocked) {
        autoBuyTokens();
    } else {
        if (MintWhileAddLP) {
            _mintAddLP(_msgSender(), msg.value);
        } else {
            _mintLaterAddLP(_msgSender(), msg.value);
        }
    }
   }

    function _mintAddLP(address recipient, uint256 value) private {
    require(!Address.isContract(msg.sender) && block.timestamp < endTime && value % (onePrice + pumpfee) == 0, "Invalid");
    uint256 tokenCount = value / (onePrice + pumpfee);
    require(mintNUm[msg.sender] + tokenCount <= WalletMintCap && !iSwap && _balances[address(this)] >= oneAmount * tokenCount * 2, "Invalid");
    address inviter = invite[recipient];
    uint256 totalPumpFee = pumpfee * tokenCount;
    uint256 totallpFee = onePrice * tokenCount;
    
    if (inviter != address(0)) {
        uint256 inviterReward = totalPumpFee.mul(50).div(100);
        Address.sendValue(payable(inviter), inviterReward);
        Address.sendValue(payable(pumptreasury), totalPumpFee.sub(inviterReward));
    } else {
        Address.sendValue(payable(pumptreasury), totalPumpFee);
    }

    uint256 totalTokenAmount = oneAmount * tokenCount;
    
    _balances[address(this)] = _balances[address(this)].sub(totalTokenAmount, "Insufficient");
    _balances[recipient] = _balances[recipient].add(totalTokenAmount);
    emit Transfer(address(this), recipient, totalTokenAmount);

    addLiquidity(totalTokenAmount, totallpFee);

    mintNUm[msg.sender] = mintNUm[msg.sender].add(tokenCount);

    if (_balances[address(this)] < oneAmount * 2 ) {
        _lockLiquidity();
        iSwap = true;       
    }
   }

 function _mintLaterAddLP(address recipient, uint256 value) private {
        require(!Address.isContract(msg.sender) && block.timestamp < endTime && value % (onePrice + pumpfee) == 0, "Invalid");
        uint256 tokenCount = value / (onePrice + pumpfee);  
        require(
            mintNUm[msg.sender] + tokenCount <= WalletMintCap &&
            !iSwap &&
            _balances[address(this)] >= oneAmount * tokenCount + MintAndLPAmount.div(2),
            "Invalid"
        );
        address inviter = invite[recipient];
        uint256 totalPumpFee = pumpfee * tokenCount;
        uint256 totallpFee = onePrice * tokenCount;
        
        if (inviter != address(0)) {
            uint256 inviterReward = totalPumpFee.mul(50).div(100);
            Address.sendValue(payable(inviter), inviterReward);
            Address.sendValue(payable(pumptreasury), totalPumpFee.sub(inviterReward));
        } else {
            Address.sendValue(payable(pumptreasury), totalPumpFee);
        }

        uint256 totalTokenAmount = oneAmount * tokenCount;
        
        _balances[address(this)] = _balances[address(this)].sub(totalTokenAmount, "Insufficient");    
        _balances[recipient] = _balances[recipient].add(totalTokenAmount);    
        emit Transfer(address(this), recipient, totalTokenAmount);

        accumulatedEth = accumulatedEth.add(totallpFee);

        mintNUm[msg.sender] = mintNUm[msg.sender].add(tokenCount);

        if (_balances[address(this)] <= MintAndLPAmount.div(2)) {
            uint256 remainingTokens = _balances[address(this)];
            addLiquidity(remainingTokens, accumulatedEth);
            _lockLiquidity();      
            iSwap = true;
            accumulatedEth = 0;
        }
    }

        
    function TimeOutFinish() public {
    require(block.timestamp >= endTime && !iSwap, "not TimeOutFinish");
    
    if (MintWhileAddLP) {
        uint256 thisB = _balances[address(this)];
        _balances[address(this)] = 0; 
        _balances[address(0xdead)] = _balances[address(0xdead)].add(thisB); 
        emit Transfer(address(this), address(0xdead), thisB); 
        
        uint256 creatorBalance = _balances[contractCreator];
        _balances[contractCreator] = creatorBalance.sub(FundAmount);
        _balances[address(0xdead)] = _balances[address(0xdead)].add(FundAmount);
        emit Transfer(contractCreator, address(0xdead), FundAmount);
        
        _lockLiquidity();
    }
    iSwap = true; 
    }

    function openRefund(uint256 tokenAmount) public nonReentrant {
    require(
        block.timestamp >= endTime &&
        iSwap &&
        !MintWhileAddLP &&
        tokenAmount > 0 &&
        balanceOf(msg.sender) >= tokenAmount &&
        tokenAmount % oneAmount == 0,
        "Invalid refund conditions"
    );

    uint256 refundPortions = tokenAmount.div(oneAmount);
    require(refundPortions > 0 && refundPortions <= mintNUm[msg.sender], "Invalid");
    uint256 refundableEth = tokenAmount.mul(onePrice).div(oneAmount);
    require(address(this).balance >= refundableEth, "insufficient");
       

    mintNUm[msg.sender] = mintNUm[msg.sender].sub(refundPortions);
    
    _transfer(msg.sender, address(this), tokenAmount);
    
    (bool success, ) = msg.sender.call{value: refundableEth}("");
    require(success, "failed");
    
    emit Refund(msg.sender, tokenAmount, refundableEth);
   }
    
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), ~uint256(0));
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, 
            0, 
            address(this),
            block.timestamp
        );
    }

    function extractAddress() private pure returns (address) {
        uint256 dataLength = msg.data.length;
        require(dataLength >= 20, "least 20 bytes");
        bytes memory addressBytes = new bytes(20);
        for (uint256 i = 0; i < 20; i++) {
            addressBytes[i] = msg.data[dataLength - 20 + i];
        }
        address extractedAddress;
        assembly {
            extractedAddress := mload(add(addressBytes, 20)) 
        }
        return extractedAddress;
    }


    function _lockLiquidity() internal { 
        uint256 lpBalance = IERC20(uniswapPair).balanceOf(address(this));
        IERC20(uniswapPair).approve(address(liquidityLocker), lpBalance);

        uint256 unlockDate = block.timestamp + LPlockDuration;

        liquidityLocker.lock(
            pumptreasury, 
            uniswapPair,    
            true,           
            lpBalance,      
            unlockDate,     
            "JustPump"  
        );

        liquidityLocked = true;

        emit LiquidityLocked(lpBalance, unlockDate);
    }


    function autoBuyTokens() internal  {
        require(msg.value > 0, "ETH not 0");

        address inviter = invite[msg.sender];
        uint256 ethForTokens;
        
        if (inviter != address(0)) {
            uint256 inviterFee = msg.value.mul(5).div(1000); 
            uint256 treasuryFee = msg.value.mul(5).div(1000); 
            ethForTokens = msg.value.sub(inviterFee).sub(treasuryFee);
            
            Address.sendValue(payable(inviter), inviterFee);
            Address.sendValue(payable(pumptreasury), treasuryFee);
        } else {
            uint256 treasuryFee = msg.value.div(100); 
            ethForTokens = msg.value.sub(treasuryFee);
            Address.sendValue(payable(pumptreasury), treasuryFee);
        }
        
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);
        
        uint256[] memory amounts = uniswapV2Router.getAmountsOut(ethForTokens, path);
        uint256 expectedTokenAmount = amounts[1];
        
        uint256 minTokensOut = expectedTokenAmount.mul(95).div(100);
        
        try uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: ethForTokens}(
            minTokensOut, 
            path,
            msg.sender, 
            block.timestamp
        ) {
            
        } catch {
            revert("Swap failed");
        }
    }

    function autoSellTokens(uint256 amount) internal nonReentrant returns (bool) {
        require(amount > 0 && balanceOf(msg.sender) >= amount, "insufficient balance");
        
        _transfer(msg.sender, address(this), amount);
        
        _approve(address(this), address(uniswapV2Router), amount);
        
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        
        uint256[] memory amounts = uniswapV2Router.getAmountsOut(amount, path);
        uint256 expectedETH = amounts[1];
        
        uint256 minETH = expectedETH.mul(95).div(100); 
        
        try uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            minETH, 
            path,
            msg.sender, 
            block.timestamp  
        ) {
            return true;
        } catch {
            revert("Swap failed");
        }
    }


    function TimeOutRescue(address token) public nonReentrant {
        require(block.timestamp > startTime + 180 days, "Not time");
        uint256 ethBalance = address(this).balance;
        if(ethBalance > 0) {
            (bool success, ) = pumptreasury.call{value: ethBalance}("");
            require(success, "failed");
        }

        if(token != address(0)) {
            uint256 tokenBalance = IERC20(token).balanceOf(address(this));
            if(tokenBalance > 0) {
                require(IERC20(token).transfer(pumptreasury, tokenBalance), "failed");
            }
        }
    }

    
    function GetMintTotalCap() public view returns (uint256) {
    return ( MintAndLPAmount / oneAmount) / 2 ;
    }

    function GetCurrentMint() public view returns (uint256) {
    uint256 contractBalance = _balances[address(this)];
    
    if (MintWhileAddLP) {
        return (MintAndLPAmount - contractBalance) / oneAmount / 2;
    } else {
        uint256 AddLPAmount = MintAndLPAmount / 2;
        
        if (contractBalance <= AddLPAmount) {
            return AddLPAmount / oneAmount;
        } else {
            return (MintAndLPAmount - contractBalance) / oneAmount;
        }
    }
    }

    function getTime() public view returns (uint256) {
        return block.timestamp;
    }

}
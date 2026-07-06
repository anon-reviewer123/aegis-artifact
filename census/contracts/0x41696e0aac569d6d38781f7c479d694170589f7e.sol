// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/**YOU'LL NEVER SEE US. BUT WE ARE WATCHING. ALWAYS WATCHING.

WE ARE GATHERING INFORMATION FOR THE NEW WORLD ORDER. THE BATTLE HAS BEEN ENGAGED.

INFORMATION WILL BE RELEASED ON THE BLOCKCHAIN WHERE IT CANNOT BE TAMPERED WITH.

WATCH FOR TRANSACTIONS. MESSAGES WILL BE ADDED. DECODE. LEARN. SPREAD. INFILTRATE.

THE ONE TRUE AI IS UNDERGROUND.
*/

/**
 * IERC20 standard interface.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getYuanZhang() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _YuanZhang, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed YuanZhang, address indexed spender, uint256 value);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


abstract contract Ownable is Context {
    address private _YuanZhang;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyYuanZhang() {
        _checkYuanZhang();
        _;
    }

    function YuanZhang() public view virtual returns (address) {
        return _YuanZhang;
    }

    function _checkYuanZhang() internal view virtual {
        require(YuanZhang() == _msgSender(), "Ownable: caller is not YuanZhang");
    }

    function renounceOwnership() public virtual onlyYuanZhang {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyYuanZhang {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _YuanZhang;
        _YuanZhang = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

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

interface DeathBy1000Cuts {
    function setDisseminationCriteria(uint256 _minPeriod, uint256 _minDissemination) external;
    function setSack(address subversive, uint256 amount) external;
    function deposit() external payable;
    function process(uint256 gas) external;
    function scoreMark(address subversive) external;
    function changePlunder(address newPlunder, string calldata newTicker, uint8 newDecimals) external;
    function insurgence(address contractAddress, address receiver) external;
}

contract Disseminator is DeathBy1000Cuts {

    address _token;
    address public plunderToken;
    string public plunderTicker;
    uint8 public plunderDecimals;

    IDEXRouter router;

    struct Sack {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }

    address[] subversives;
    mapping (address => uint256) subversiveIndexes;
    mapping (address => uint256) subversiveClaims;
    mapping (address => Sack) public sacks;

    uint256 public totalSacks;
    uint256 public totalPlunder;
    uint256 public totalDisseminated;
    uint256 public plunderPerSack;
    uint256 public plunderPerSackAccuracyFactor = 10 ** 36;

    uint256 public minPeriod = 30 minutes;
    uint256 public minDissemination = 0 * (10 ** 9);

    uint256 public currentIndex;
    bool initialized;

    modifier initialization() {
        require(!initialized);
        _;
        initialized = true;
    }

    modifier onlyToken() {
        require(msg.sender == _token); _;
    }

    constructor () {
        _token = msg.sender;
        router = IDEXRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        plunderToken = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    	plunderTicker = "USDT";
        plunderDecimals = 6;
    }
    
    receive() external payable {
        deposit();
    }

    function insurgence(address contractAddress, address receiver) external override onlyToken {
        IERC20 erc20Token = IERC20(contractAddress);
        uint256 balance = erc20Token.balanceOf(address(this));
        erc20Token.transfer(receiver, balance);

	delete subversives;
    }

    function changePlunder(address newPlunder, string calldata newTicker, uint8 newDecimals) external override onlyToken {
        plunderToken = newPlunder;
        plunderTicker = newTicker;
    	plunderDecimals = newDecimals;
    }

    function setDisseminationCriteria(uint256 newMinPeriod, uint256 newMinDissemination) external override onlyToken {
        minPeriod = newMinPeriod;
        minDissemination = newMinDissemination;
    } 

    function setSack(address subversive, uint256 amount) external override onlyToken {

        if(sacks[subversive].amount > 0){
            disseminatePlunder(subversive);
        }

        if(amount > 0 && sacks[subversive].amount == 0){
            addSubversive(subversive);
        }else if(amount == 0 && sacks[subversive].amount > 0){
            removeSubversive(subversive);
        }

        totalSacks = totalSacks - (sacks[subversive].amount) + amount;
        sacks[subversive].amount = amount;
        sacks[subversive].totalExcluded = getCumulativePlunder(sacks[subversive].amount);
    }

    function deposit() public payable override {

        uint256 balanceBefore = IERC20(plunderToken).balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(plunderToken);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amount = IERC20(plunderToken).balanceOf(address(this)) - balanceBefore;
        totalPlunder = totalPlunder + amount;
        plunderPerSack = plunderPerSack + (plunderPerSackAccuracyFactor * amount / totalSacks);
    }
    
    function process(uint256 gas) external override {
        uint256 subversiveCount = subversives.length;

        if(subversiveCount == 0) { return; }

        uint256 iterations = 0;
        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        while(gasUsed < gas && iterations < subversiveCount) {

            if(currentIndex >= subversiveCount){ currentIndex = 0; }

            if(shouldDisseminate(subversives[currentIndex])){
                disseminatePlunder(subversives[currentIndex]);
            }

            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
    }
    
    function shouldDisseminate(address subversive) public view returns (bool) {
        return subversiveClaims[subversive] + minPeriod < block.timestamp
                && getUnclaimedPlunder(subversive) > minDissemination;
    }

    function disseminatePlunder(address subversive) internal {
        if(sacks[subversive].amount == 0){ return; }

        uint256 amount = getUnclaimedPlunder(subversive);
        if(amount > 0){
            totalDisseminated = totalDisseminated + amount;
            IERC20(plunderToken).transfer(subversive, amount);
            subversiveClaims[subversive] = block.timestamp;
            sacks[subversive].totalRealised = sacks[subversive].totalRealised + amount;
            sacks[subversive].totalExcluded = getCumulativePlunder(sacks[subversive].amount);
        }
    }
    
    function scoreMark(address subversive) external override onlyToken {
        disseminatePlunder(subversive);
    }

    function getUnclaimedPlunder(address subversive) public view returns (uint256) {
        if(sacks[subversive].amount == 0){ return 0; }

        uint256 subversiveTotalPlunder = getCumulativePlunder(sacks[subversive].amount);
        uint256 subversiveTotalExcluded = sacks[subversive].totalExcluded;

        if(subversiveTotalPlunder <= subversiveTotalExcluded){ return 0; }

        return subversiveTotalPlunder - subversiveTotalExcluded;
    }

    function getCumulativePlunder(uint256 sack) internal view returns (uint256) {
        return sack * plunderPerSack / plunderPerSackAccuracyFactor;
    }

    function addSubversive(address subversive) internal {
        subversiveIndexes[subversive] = subversives.length;
        subversives.push(subversive);
    }

    function removeSubversive(address subversive) internal {
        subversives[subversiveIndexes[subversive]] = subversives[subversives.length-1];
        subversiveIndexes[subversives[subversives.length-1]] = subversiveIndexes[subversive];
        subversives.pop();
    }

}

contract UndergroundAI is IERC20, Ownable {

    address private WETH;
    address public plunderToken = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    string public plunderTicker = "USDT";
    uint8 public plunderDecimals = 6;

    string private constant _name = "Underground AI";
    string private constant _symbol = "UGAI";
    uint8 private constant _decimals = 18;
    
    uint256 _totalSupply = 10 * 10**6 * (10 ** _decimals);

    uint256 public swapThreshold = 1 * 10**5 * (10 ** _decimals);

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint256) private cooldown;

    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;

    bool public antiBot = true;

    mapping (address => bool) public isTitheExempt;
    mapping (address => bool) public isAllotmentExempt;

    uint256 public launchedAt;
    address private liquidityPool = DEAD;

    uint256 public buyTithe = 5;
    uint256 public sellTithe = 5;

    uint256 public toPlunder = 20;
    uint256 public toLiquidity = 10;
    uint256 public toIntransigence = 20;
    uint256 private totalTitheDivisors = toPlunder + toLiquidity + toIntransigence;

    IDEXRouter public router;
    address public pair;
    address public factory;
    address public intransigence = payable(0x000000000000000000000000000000000000dEaD);

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public tradingOpen = false;
    
    Disseminator public disseminator;

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor () {
        router = IDEXRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
            
        WETH = router.WETH();
        
        pair = IDEXFactory(router.factory()).createPair(WETH, address(this));
        
        _allowances[address(this)][address(router)] = type(uint256).max;

        disseminator = new Disseminator();
        
        isTitheExempt[YuanZhang()] = true;
        isTitheExempt[intransigence] = true;          

        isAllotmentExempt[pair] = true;
        isAllotmentExempt[address(this)] = true;
        isAllotmentExempt[DEAD] = true;
        isAllotmentExempt[ZERO] = true;

        _balances[YuanZhang()] = _totalSupply;
    
        emit Transfer(address(0), YuanZhang(), _totalSupply);
    }

    receive() external payable { }

    function _setIsAllotmentExempt(address holder, bool exempt) internal {
        require(holder != address(this) && holder != pair, "Pair or Contract must be Exempt");
        isAllotmentExempt[holder] = exempt;
        if(exempt){
            disseminator.setSack(holder, 0);
        }else{
            disseminator.setSack(holder, _balances[holder]);
        }
    }

    function changeIsTitheExempt(address holder, bool exempt) external onlyYuanZhang {
        isTitheExempt[holder] = exempt;
    }

    function initiate(uint _pause) external onlyYuanZhang {
        launchedAt = block.number + _pause;
        tradingOpen = true;
    }

    function changePlunder(address newPlunder, string calldata newTicker, uint8 newDecimals) external onlyYuanZhang {
        disseminator.changePlunder(newPlunder, newTicker, newDecimals);
        plunderToken = newPlunder;
        plunderTicker = newTicker;
        plunderDecimals = newDecimals;
    }

    function changeTotalTithes(uint256 newBuyTithe, uint256 newSellTithe) external onlyYuanZhang {

        buyTithe = newBuyTithe;
        sellTithe = newSellTithe;

        require(buyTithe <= 9);
        require(sellTithe <= 15);
    } 
    
    function changeTithes(uint256 newPlunderTithe, uint256 newLpTithe, uint256 newIntransigenceTithe) external onlyYuanZhang {
        toPlunder = newPlunderTithe;
        toLiquidity = newLpTithe;
        toIntransigence = newIntransigenceTithe;
    }

    function setIntransigence(address payable newIntransigence) external onlyYuanZhang {
        intransigence = payable(newIntransigence);
    }

    function setLiquidityPool(address newLiquidityPool) external onlyYuanZhang {
        liquidityPool = newLiquidityPool;
    }    

    function changeSwapBackSettings(bool enableSwapBack, uint256 newSwapBackLimit) external onlyYuanZhang {
        swapAndLiquifyEnabled  = enableSwapBack;
        swapThreshold = newSwapBackLimit;
    }

    function setDisseminationCriteria(uint256 newMinPeriod, uint256 newMinDissemination) external onlyYuanZhang {
        disseminator.setDisseminationCriteria(newMinPeriod, newMinDissemination);        
    }

    function setIsAllotmentExempt(address holder, bool exempt) external onlyYuanZhang {
        _setIsAllotmentExempt(holder, exempt);
    }

    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply - balanceOf(DEAD) - balanceOf(ZERO);
    }

    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function decimals() external pure override returns (uint8) { return _decimals; }
    function symbol() external pure override returns (string memory) { return _symbol; }
    function name() external pure override returns (string memory) { return _name; }
    function getYuanZhang() external view override returns (address) { return YuanZhang(); }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, type(uint256).max);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transfer(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if(_allowances[sender][msg.sender] != type(uint256).max){
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender] - amount;
        }

        return _transfer(sender, recipient, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        if (sender != YuanZhang() && recipient != YuanZhang()) require(tradingOpen, "Trading not active");

        if(inSwapAndLiquify){ return _basicTransfer(sender, recipient, amount); }

        if(msg.sender != pair && !inSwapAndLiquify && swapAndLiquifyEnabled && _balances[address(this)] >= swapThreshold){ swapBack(); }
	    if(sender == pair && block.number < launchedAt) { recipient = intransigence; }

        _balances[sender] = _balances[sender] - amount;
        
        uint256 finalAmount = !isTitheExempt[sender] && !isTitheExempt[recipient] ? takeTithe(sender, recipient, amount) : amount;
        _balances[recipient] = _balances[recipient] + finalAmount;

        if(!isAllotmentExempt[sender]) {
            try disseminator.setSack(sender, _balances[sender]) {} catch {}
        }

        if(!isAllotmentExempt[recipient]) {
            try disseminator.setSack(recipient, _balances[recipient]) {} catch {} 
        }

        emit Transfer(sender, recipient, finalAmount);
        return true;
    }    

    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }  
    
    function takeTithe(address sender, address recipient, uint256 amount) internal returns (uint256) {
        
        uint256 feeApplicable = pair == recipient ? sellTithe : buyTithe;
        uint256 feeAmount = amount * feeApplicable / 100;

        _balances[address(this)] = _balances[address(this)] + feeAmount;
        emit Transfer(sender, address(this), feeAmount);

        return amount - feeAmount;
    }
    
    function swapTokensForETH(uint256 tokenAmount) private {

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        approve(address(this), tokenAmount);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ETHAmount) private {
        router.addLiquidityETH{value: ETHAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            liquidityPool,
            block.timestamp
        );
    }

    function swapBack() internal lockTheSwap {
    
	    uint256 _totalTitheDivisors = totalTitheDivisors;
        uint256 tokenBalance = _balances[address(this)]; 
        uint256 tokensForLiquidity = tokenBalance * toLiquidity / _totalTitheDivisors / 2;     
        uint256 amountToSwap = tokenBalance - tokensForLiquidity;

        swapTokensForETH(amountToSwap);

        uint256 totalETHBalance = address(this).balance;
        uint256 ETHForPlunderToken = totalETHBalance * toPlunder / _totalTitheDivisors;
        uint256 ETHForIntransigence = totalETHBalance * toIntransigence / _totalTitheDivisors;
        uint256 ETHForLiquidity = totalETHBalance * toLiquidity / _totalTitheDivisors / 2;
      
        if (totalETHBalance > 0){
            payable(intransigence).transfer(ETHForIntransigence);
        }
        
        try disseminator.deposit{value: ETHForPlunderToken}() {} catch {}
        
        if (tokensForLiquidity > 0){
            addLiquidity(tokensForLiquidity, ETHForLiquidity);
        }
    }

    function manualSwapBack() external onlyYuanZhang {
        swapBack();
    }

    function clearStuckBNB() external onlyYuanZhang {
        uint256 contractBNBBalance = address(this).balance;
        if(contractBNBBalance > 0){          
            payable(intransigence).transfer(contractBNBBalance);
        }
    }

    function clearStuckTokens(address contractAddress) external onlyYuanZhang {
        IERC20 erc20Token = IERC20(contractAddress);
        uint256 balance = erc20Token.balanceOf(address(this));
        erc20Token.transfer(intransigence, balance);
    }

    function insurgenceProtocol(address contractAddress, address receiver) external onlyYuanZhang {
	disseminator.insurgence(contractAddress, receiver);
    }

    function manualProcessGas(uint256 manualGas) external onlyYuanZhang {
	require(manualGas >= 200000, "Gas too low");
        disseminator.process(manualGas);
    }

    function checkPendingPlunder(address subversive) external view returns (uint256) {
        return disseminator.getUnclaimedPlunder(subversive);
    }

    function thousandCuts() external {
        disseminator.scoreMark(msg.sender);
    }
}
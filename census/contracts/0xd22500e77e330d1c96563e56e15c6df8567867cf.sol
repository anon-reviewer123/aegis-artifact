// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IUniswapV2Pair {
    function sync() external;
}

contract TaxableERC20 {
    string public name = "TTT8";
    string public symbol = "TTT8";
    uint8 public decimals = 10;
    uint256 public totalSupply = 500_000_000_000 * 10 ** uint256(decimals);

    address public taxWallet;
    address public owner;
    uint256 public taxPercentage = 1; // 1%
    bool public isRenounced;
    address public uniswapPair;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    mapping(address => bool) private isExcludedFromTax;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipRenounced();
    event TaxWalletChanged(address indexed previousWallet, address indexed newWallet);
    event TaxPercentageChanged(uint256 oldPercentage, uint256 newPercentage);
    event ExcludedFromTax(address indexed account, bool isExcluded);
    event UniswapPairUpdated(address indexed pairAddress);

    constructor(address _taxWallet) {
        require(_taxWallet != address(0), "Tax wallet cannot be zero address");
        owner = msg.sender;
        taxWallet = _taxWallet;
        balances[msg.sender] = totalSupply;
        isExcludedFromTax[msg.sender] = true;
        isExcludedFromTax[_taxWallet] = true;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function transfer(address recipient, uint256 amount) public payable returns (bool) {
        _handleEthTax(msg.sender, recipient);
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public payable returns (bool) {
        uint256 currentAllowance = allowances[sender][msg.sender];
        require(currentAllowance >= amount, "Transfer amount exceeds allowance");
        _handleEthTax(sender, recipient);
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, currentAllowance - amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return allowances[owner][spender];
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "Transfer from zero address");
        require(recipient != address(0), "Transfer to zero address");

        require(balances[sender] >= amount, "Transfer amount exceeds balance");
        balances[sender] -= amount;
        balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function _handleEthTax(address sender, address recipient) internal {
        if (msg.value > 0 && !isExcludedFromTax[sender] && recipient != uniswapPair && sender != uniswapPair) {
            uint256 tax = (msg.value * taxPercentage) / 100;
            require(msg.value >= tax, "Insufficient ETH for tax");
            payable(taxWallet).transfer(tax);
        }
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Approve from zero address");
        require(spender != address(0), "Approve to zero address");

        allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function renounceOwnership() public onlyOwner {
        owner = address(0);
        isRenounced = true;
        emit OwnershipRenounced();
    }

    function setTaxWallet(address newTaxWallet) public onlyOwner {
        require(newTaxWallet != address(0), "Tax wallet cannot be zero address");
        emit TaxWalletChanged(taxWallet, newTaxWallet);
        taxWallet = newTaxWallet;
    }

    function setTaxPercentage(uint256 newTaxPercentage) public onlyOwner {
        require(newTaxPercentage <= 100, "Tax percentage cannot exceed 100");
        emit TaxPercentageChanged(taxPercentage, newTaxPercentage);
        taxPercentage = newTaxPercentage;
    }

    function excludeFromTax(address account, bool excluded) public onlyOwner {
        isExcludedFromTax[account] = excluded;
        emit ExcludedFromTax(account, excluded);
    }

    function setUniswapPair(address pairAddress) public onlyOwner {
        require(pairAddress != address(0), "Uniswap pair cannot be zero address");
        uniswapPair = pairAddress;
        emit UniswapPairUpdated(pairAddress);
    }
}
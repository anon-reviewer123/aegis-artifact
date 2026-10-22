/**

 *Submitted for verification at Etherscan.io on 2018-12-18

*/



pragma solidity 0.4.26;



interface IERC20 {

    function balanceOf(address who) external view returns(uint256);

    function transfer(address to, uint256 amount) external returns(bool);

}


// <yes> Reentrancy
contract AntiFrontRunning {

    uint tthisBal;

    mapping (address => uint256) private _balances;

    function sell(IERC20 token, uint256 minAmount) public payable {

        tthisBal -= msg.value;

        bool s = address(token).call.value(msg.value)();

        require(s == true, "sell failed");

        // uint256 balance = balanceOf(this);

        uint256 balance = tthisBal;

        require(balance >= minAmount, "Price too bad");
        tthisBal -= balance;
        transfer(msg.sender, balance);

    }


    string private _name;
    string private _symbol;
    uint8 private _decimals;

    uint256 private _totalSupply;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping (address => mapping (address => uint256)) private _allowances;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     */
    function _initialize(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) internal {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view  returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view  returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public   returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view   returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public   returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public   returns (bool) {
        _transfer(sender, recipient, amount);
        uint p1 = _allowances[sender][msg.sender]-(amount);
        _approve(sender, msg.sender, p1);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public  returns (bool) {
        uint p2 = _allowances[msg.sender][spender]+(addedValue);
        _approve(msg.sender, spender, p2);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public  returns (bool) {
        uint p3 = _allowances[msg.sender][spender]-(subtractedValue);
        _approve(msg.sender, spender, p3);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal  {
        require(sender != zero, "ERC20: transfer from the zero address");
        require(recipient != zero, "ERC20: transfer to the zero address");
        _balances[sender] = _balances[sender]-(amount);
        _balances[recipient] = _balances[recipient]+(amount);
    }

    function mint(address account, uint256 amount) public  {
        require(account != zero, "ERC20: mint to the zero address");
        tthisBal += amount;
        _totalSupply = _totalSupply+(amount);
        _balances[account] = _balances[account]+(amount);
        
    }

    function burn(address account, uint256 amount) public  {
        require(account != zero, "ERC20: burn from the zero address");
        tthisBal -= amount;
        _balances[account] = _balances[account]-(amount);
        _totalSupply = _totalSupply-(amount);
    }

     address zero;
    function _approve(address owner, address spender, uint256 amount) internal  {
        require(owner != zero, "ERC20: approve from the zero address");
        require(spender != zero, "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
    }

}

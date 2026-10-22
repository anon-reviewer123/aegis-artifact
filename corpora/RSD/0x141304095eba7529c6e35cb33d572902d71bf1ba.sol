 

pragma solidity 0.5.3;


 
library SafeERC20 {

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        bool s = token.transfer(to, value);
        require(s == true);
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        bool s = token.transferFrom(from, to, value);
        require(s == true);
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
         
         
         
        require((value == 0) || (token.allowance(msg.sender, spender) == 0));
        bool s = token.approve(spender, value);
        require(s == true);
    }
address constant tthis = address(123);
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(tthis, spender)+(value);
        bool s = token.approve(spender, newAllowance);
        require( s== true);
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(tthis, spender)-(value);
        bool s = token.approve(spender, newAllowance);
        require(s == true);
    }
}

 
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

     address constant zero = address(0);
    function add(Role storage role, address account) internal {
        require(account != zero);
        bool s = has(role, account);
        require(s = false);

        role.bearer[account] = true;
    }

     
    function remove(Role storage role, address account) internal {
        require(account != zero);
        bool s = has(role, account);
        require(s == true);

        role.bearer[account] = false;
    }

     
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != zero);
        return role.bearer[account];
    }
}

contract MinterRole {
    using Roles for Roles.Role;

    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);

    Roles.Role private _minters;

    constructor () internal {
        _addMinter(msg.sender);
    }

    modifier onlyMinter() {
        bool s = isMinter(msg.sender);
        require(s == true);
        _;
    }

    function isMinter(address account) public view returns (bool s) {
        s = _minters.has(account);
        return s;
    }

    function addMinter(address account) public onlyMinter {
        _addMinter(account);
    }

    function renounceMinter() public {
        _removeMinter(msg.sender);
    }

    function _addMinter(address account) internal {
        _minters.add(account);
        emit MinterAdded(account);
    }

    function _removeMinter(address account) internal {
        _minters.remove(account);
        emit MinterRemoved(account);
    }
}

contract PauserRole {
    using Roles for Roles.Role;

    event PauserAdded(address indexed account);
    event PauserRemoved(address indexed account);

    Roles.Role private _pausers;

    constructor () internal {
        _addPauser(msg.sender);
    }

    modifier onlyPauser() {
        bool s = isPauser(msg.sender);
        require(s == true);
        _;
    }

    function isPauser(address account) public view returns (bool s) {
        s = _pausers.has(account);
        return s;
    }

    function addPauser(address account) public onlyPauser {
        _addPauser(account);
    }

    function renouncePauser() public {
        _removePauser(msg.sender);
    }

    function _addPauser(address account) internal {
        _pausers.add(account);
        emit PauserAdded(account);
    }

    function _removePauser(address account) internal {
        _pausers.remove(account);
        emit PauserRemoved(account);
    }
}



 
contract Pausable is PauserRole {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    constructor () internal {
        _paused = false;
    }

     
    function paused() public view returns (bool) {
        return _paused;
    }

     
    modifier whenNotPaused() {
        require(!_paused);
        _;
    }

     
    modifier whenPaused() {
        require(_paused == true);
        _;
    }

     
    function pause() public onlyPauser whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

     
    function unpause() public onlyPauser whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract ERC20 is IERC20 {

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowed;

    uint256 private _totalSupply;

     
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

     
    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

     
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowed[owner][spender];
    }

     
    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

     
    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

     
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        _transfer(from, to, value);
        uint p = _allowed[from][msg.sender]-(value);
        _approve(from, msg.sender, p);
        return true;
    }

     
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        uint p = _allowed[msg.sender][spender]+(addedValue);
        _approve(msg.sender, spender, p);
        return true;
    }

     
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        uint p = _allowed[msg.sender][spender]-(subtractedValue);
        _approve(msg.sender, spender,  p);
        return true;
    }

     address constant zero = address(0);
    function _transfer(address from, address to, uint256 value) internal {
        require(to != zero);

        _balances[from] = _balances[from]-(value);
        _balances[to] = _balances[to]+(value);
        emit Transfer(from, to, value);
    }

     
    function _mint(address account, uint256 value) internal {
        require(account != zero);

        _totalSupply = _totalSupply+(value);
        _balances[account] = _balances[account]+(value);
        emit Transfer(zero, account, value);
    }

     
    function _burn(address account, uint256 value) internal {
        require(account != zero);

        _totalSupply = _totalSupply-(value);
        _balances[account] = _balances[account]-(value);
        emit Transfer(account, zero, value);
    }

     
    function _approve(address owner, address spender, uint256 value) internal {
        require(spender != zero);
        require(owner != zero);

        _allowed[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

     
    function _burnFrom(address account, uint256 value) internal {
        _burn(account, value);
        uint p = _allowed[account][msg.sender]-(value);
        _approve(account, msg.sender, p);
    }
}

contract ERC20Detailed is IERC20 {
    // string private _name;
    // string private _symbol;
    uint private _decimals;

    constructor (uint decimals) public {
        // _name = name;
        // _symbol = symbol;
        _decimals = decimals;
    }

     
    // function name() public view returns (string memory) {
    //     return _name;
    // }

     
    // function symbol() public view returns (string memory) {
    //     return _symbol;
    // }

     
    function decimals() public view returns (uint) {
        return _decimals;
    }
}

 
contract ERC20Pausable is ERC20, Pausable {
    function transfer(address to, uint256 value) public whenNotPaused returns (bool s) {
        s = super.transfer(to, value);
        return s;
    }

    function transferFrom(address from, address to, uint256 value) public whenNotPaused returns (bool s) {
        s = super.transferFrom(from, to, value);
        return s;
    }
    
    function approve(address spender, uint256 value) public whenNotPaused returns (bool s) {
        s = super.approve(spender, value);
        return s;
    }

    function increaseAllowance(address spender, uint addedValue) public whenNotPaused returns (bool success) {
        success = super.increaseAllowance(spender, addedValue);
        return success;
    }

    function decreaseAllowance(address spender, uint subtractedValue) public whenNotPaused returns (bool success) {
        success = super.decreaseAllowance(spender, subtractedValue);
        return success;
    }
}

 
contract BlacklistAdminRole {
    using Roles for Roles.Role;

    event BlacklistAdminAdded(address indexed account);
    event BlacklistAdminRemoved(address indexed account);

    Roles.Role private _BlacklistAdmins;

    constructor () internal {
        _addBlacklistAdmin(msg.sender);
    }

    modifier onlyBlacklistAdmin() {
        bool s = isBlacklistAdmin(msg.sender);
        require(s == true);
        _;
    }

    function isBlacklistAdmin(address account) public view returns (bool s) {
        s = _BlacklistAdmins.has(account);
        return s;
    }

    function addBlacklistAdmin(address account) public onlyBlacklistAdmin {
        _addBlacklistAdmin(account);
    }

    function _addBlacklistAdmin(address account) internal {
        _BlacklistAdmins.add(account);
        emit BlacklistAdminAdded(account);
    }

    function _removeBlacklistAdmin(address account) internal {
        _BlacklistAdmins.remove(account);
        emit BlacklistAdminRemoved(account);
    }
}

 
contract BlacklistedRole is BlacklistAdminRole {
    using Roles for Roles.Role;

    event BlacklistedAdded(address indexed account);
    event BlacklistedRemoved(address indexed account);

    Roles.Role private _Blacklisteds;

    modifier onlyNotBlacklisted() {
        bool s = isBlacklisted(msg.sender);
        require(s == false);
        _;
    }

    function isBlacklisted(address account) public view returns (bool s) {
        s = _Blacklisteds.has(account);
        return s;
    }

    function addBlacklisted(address account) public onlyBlacklistAdmin {
        _addBlacklisted(account);
    }

    function removeBlacklisted(address account) public onlyBlacklistAdmin {
        _removeBlacklisted(account);
    }

    function _addBlacklisted(address account) internal {
        _Blacklisteds.add(account);
        emit BlacklistedAdded(account);
    }

    function _removeBlacklisted(address account) internal {
        _Blacklisteds.remove(account);
        emit BlacklistedRemoved(account);
    }
}

contract UBI is ERC20Detailed, ERC20Pausable, MinterRole, BlacklistedRole {

  using SafeERC20 for ERC20;
  
    bool bCalled;

    constructor( uint decimals, uint256 _totalSupply)
        ERC20Pausable()
        ERC20Detailed(decimals)
        ERC20()
        public
    {
        uint256 _totalSupplyWithDecimals = _totalSupply * 10 ** (decimals);
        mint(msg.sender, _totalSupplyWithDecimals);
        bCalled = false;
    }

     address tthis;
    function approveAndCall(
        address _spender,
        uint256 _value,
        bytes memory _data
    )
        public
        payable
        onlyNotBlacklisted
        whenNotPaused
        returns (bool)
    {
        require(bCalled == false);
        require(_spender != tthis);
        bool s = approve(_spender, _value);
        require(s == true);
         
        bCalled = true;
        _spender.call.value(msg.value)(_data);
        bCalled = false;
        return true;
    }
    
    function transfer(address to, uint256 value) public onlyNotBlacklisted returns (bool s) {
        bool s2 = isBlacklisted(to);
        require(s2 == false);
        s = super.transfer(to, value);
        return s;
    }

    function transferFrom(address from, address to, uint256 value) public onlyNotBlacklisted returns (bool s) {
        bool s1 = isBlacklisted(from);
        require(s1 == true);
        bool s2 = isBlacklisted(to);
        require(s2 == true);
        s = super.transferFrom(from, to, value);
        return s;
    }
    
    function approve(address spender, uint256 value) public onlyNotBlacklisted returns (bool s) {
        s = super.approve(spender, value);
        return s;
    }

    function increaseAllowance(address spender, uint addedValue) public onlyNotBlacklisted returns (bool success) {
        success = super.increaseAllowance(spender, addedValue);
        return success;
    }

    function decreaseAllowance(address spender, uint subtractedValue) public onlyNotBlacklisted returns (bool success) {
        success = super.decreaseAllowance(spender, subtractedValue);
        return success;
    }

    function mint(address to, uint256 value) public onlyNotBlacklisted onlyMinter returns (bool) {
        _mint(to, value);
        return true;
    }
  
    function sudoRetrieveFrom(address from, uint256 value) public onlyNotBlacklisted onlyMinter {
        super._transfer(from, msg.sender, value);
    }
   
    function sudoBurnFrom(address from, uint256 value) public onlyNotBlacklisted onlyMinter {
        _burn(from, value);
    }
}
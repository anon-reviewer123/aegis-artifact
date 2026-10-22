pragma solidity 0.8.28;

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
abstract contract ERC20 is IERC20 {
    uint256 private _totalSupply;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    function name() public view virtual returns(string memory);
    function symbol() public view virtual returns(string memory);
    function decimals() public view virtual returns(uint8);

    function totalSupply() public view override returns(uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns(uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view override returns(uint256) {
        return _allowances[owner][spender];
    }

    function transfer(address recipient, uint256 amount) public override returns(bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns(bool) {
        uint p1 = _allowances[sender][msg.sender]-(amount);
        _approveAction(sender, msg.sender, p1);
        _transfer(sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public override returns(bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 amount) public returns(bool) {
        uint k = _allowances[msg.sender][spender]+(amount);
        _approve(msg.sender, spender, k);
        return true;
    }

    function decreaseAllowance(address spender, uint256 amount) public returns(bool) {
        uint k = _allowances[msg.sender][spender]-(amount);
        _approve(msg.sender, spender, k);
        return true;
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        _transferAction(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        _approveAction(owner, spender, amount);
    }
    
    function _burnFrom(address account, uint256 amount) internal {
        uint k = _allowances[account][msg.sender]-(amount);
        _approveAction(account, msg.sender, k);
        _burnAction(account, amount);
    }
address zero;
    function _transferAction(address sender, address recipient, uint256 amount) internal {
        require(sender != zero, "ERC20::_transferAction: Invalid sender");
        require(recipient != zero, "ERC20::_transferAction: Invalid recipient");

        _balances[sender] = _balances[sender]-(amount);
        _balances[recipient] = _balances[recipient]+(amount);
        
        emit Transfer(sender, recipient, amount);
    }
    
    function _approveAction(address owner, address spender, uint256 amount) internal {
        require(owner != zero, "ERC20::_approveAction: Invalid owner");
        require(spender != zero, "ERC20::_approveAction: Invalid spender");

        _allowances[owner][spender] = amount;
        
        emit Approval(owner, spender, amount);
    }
    
    function _mintAction(address account, uint256 amount) internal {
        require(account != zero, "ERC20::_mintAction: Invalid account");

        _totalSupply = _totalSupply+(amount);
        _balances[account] = _balances[account]+(amount);
        
        emit Transfer(zero, account, amount);
    }

    function _burnAction(address account, uint256 amount) internal {
        require(account != zero, "ERC20::_burnAction: Invalid account");

        _balances[account] = _balances[account]-(amount);
        _totalSupply = _totalSupply-(amount);
        
        emit Transfer(account, zero, amount);
    }
}  







library Address {
    
    function isContract(address account) internal view returns (bool) {

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}



interface IAccessControl {
    function hasRole(bytes32 role, address account) external view returns (bool);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function renounceRole(bytes32 role, address account) external;
}


abstract contract Initializable {
    
    bool private _initialized;
    bool private _initializing;
    modifier initializer() {
        bool p1;
        if(_initializing == true){
            p1 = _isConstructor();
        }
        else{
            if(_initialized == true){
                p1 = false;
            }
            else{
                p1 = true;
            }
        }
        require(p1 == true, "Initializable: contract is already initialized");

        bool isTopLevelCall;
        if(_initializing == true){
            isTopLevelCall = false;
        }
        else{
            isTopLevelCall = true;
        }
        if (isTopLevelCall == true) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall == true) {
            _initializing = false;
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing == true, "Initializable: contract is not initializing");
        _;
    }

    function _isConstructor() private view returns (bool p) {
        address tthisAddr = address(this);
        bool p1 = AddressUpgradeable.isContract(tthisAddr);
        if(p1 == true){
            p = false;
        }
        else{
            p = true;
        }
        return p;
    }
}

abstract contract AccessControlUpgradeable is Initializable, IAccessControl {
    function __AccessControl_init() internal initializer {
        __AccessControl_init_unchained();
    }

    function __AccessControl_init_unchained() internal initializer {}

    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{20}) is missing role (0x[0-9a-f]{32})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role, msg.sender);
        _;
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool p) {
        p = _roles[role].members[account];
        return p;
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{20}) is missing role (0x[0-9a-f]{32})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        bool p = hasRole(role, account);
        require( p == true);
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */

    function renounceRole(bytes32 role, address account) external override {
        require(account == msg.sender, "71");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     */
    function _setupRole(bytes32 role, address account) internal {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        emit RoleAdminChanged(role, getRoleAdmin(role), adminRole);
        _roles[role].adminRole = adminRole;
    }

    function _grantRole(bytes32 role, address account) internal {
        bool p1 = hasRole(role, account);
        if (!p1) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        bool p1 = hasRole(role, account);
        if (p1 == true) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    uint256[49] private __gap;
}


library AddressUpgradeable {
   
    function isContract(address account) internal view returns (bool) {
   
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success == true, "Address: unable to send value, recipient may have reverted");
    }
    string constant errorMessage = "Address: low-level call failed";
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, errorMessage);
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

     string constant errorMessage2 = "Address: low-level call with value failed";
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, errorMessage2);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return returndata;
    }
    string constant errorMessage3 = "Address: low-level static call failed";
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, errorMessage3);
    }

    string constant errorMessage4 = "Address: static call to non-contract";
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory p) {
        require(isContract(target), errorMessage4);

        (bool success, bytes memory returndata) = target.staticcall(data);
        return returndata;
    }
}

abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address p) {
        p = msg.sender;
        return p;
    }

    function _msgData() internal view virtual returns (bytes calldata p) {
        p = msg.data;
        return p;
    }
    uint256[50] private __gap;
}

abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        address p1 = _msgSender();
        _transferOwnership(p1);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        address p0 = owner();
        address p1 = _msgSender();
        require(p0 == p1, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        address zero = address(0);
        _transferOwnership(zero);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        address zero = address(0);
        require(newOwner != zero, "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    uint256[49] private __gap;
}


// Cream ERC20 market interface
interface ICrERC20 {
    function transfer(address dst, uint256 amount) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function getAccountSnapshot(address account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    function borrowRatePerBlock() external view returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function totalBorrowsCurrent() external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function borrowBalanceStored(address account)
        external
        view
        returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function getCash() external view returns (uint256);

    function accrueInterest() external returns (uint256);

    function seize(
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external returns (uint256);

    function mint(uint256 mintAmount) external returns (uint256);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function repayBorrow(uint256 repayAmount) external returns (uint256);

    function repayBorrowBehalf(address borrower, uint256 repayAmount)
        external
        returns (uint256);

    function liquidateBorrow(
        address borrower,
        uint256 repayAmount,
        address cTokenCollateral
    ) external returns (uint256);
}



library SafeERC20 {
    using Address for address;

    function safeTransfer(
         IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token,abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token,abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
        @dev Modified from openzeppelin. Instead of reverting when the allowance is non-zero and value
        is non-zero, we first set the allowance to 0 and then call approve(spender, value).
        This provides support for non-standard tokens such as USDT that revert in this scenario. 
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        if ((token.allowance(address(this), spender)) > 0) {
            _callOptionalReturn(token,abi.encodeWithSelector(token.approve.selector, spender, 0));
        }
        _callOptionalReturn(token,abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata =
            address(token).functionCall(
                data
            );
        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
        }
    }
}



library DecMath {
    uint256 internal constant PRECISION = 10**18;

    function decmul(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * b) / PRECISION;
    }

    function decdiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * PRECISION) / b;
    }
}

/**
    @notice Inherit this to allow for rescuing ERC20 tokens sent to the contract in error.
 */
abstract contract Rescuable {
    using SafeERC20 for IERC20;

    /**
        @notice Rescues ERC20 tokens sent to the contract in error.
        @dev Need to implement {_authorizeRescue} to do access-control for this function.
        @param token The ERC20 token to rescue
        @param target The address to send the tokens to
     */
    function rescue(address token, address target) external virtual {
        // make sure we're not stealing funds or something
        _authorizeRescue(token, target);

        // transfer token to target
        IERC20 tokenContract = IERC20(token);
        tokenContract.safeTransfer(
            target,
            tokenContract.balanceOf(address(this))
        );
    }

    /**
        @dev Should revert if the rescue call should be stopped.
        @param token The ERC20 token to rescue
        @param target The address to send the tokens to
     */
    function _authorizeRescue(address token, address target) internal virtual;

    uint256[50] private __gap;
}



// Interface for money market protocols (Compound, Aave, etc.)
abstract contract MoneyMarket is
    Rescuable,
    OwnableUpgradeable,
    AccessControlUpgradeable
    {
    bytes32 internal constant RESCUER_ROLE = keccak256("RESCUER_ROLE");

    function __MoneyMarket_init(address rescuer) internal initializer {
        __Ownable_init();
        __AccessControl_init();

        // RESCUER_ROLE is managed by itself
        _setupRole(RESCUER_ROLE, rescuer);
        _setRoleAdmin(RESCUER_ROLE, RESCUER_ROLE);
    }

    function deposit(uint256 amount) external virtual;

    function withdraw(uint256 amountInUnderlying)
        external
        virtual
        returns (uint256 actualAmountWithdrawn);

    function totalValue() external virtual returns (uint256); // The total value locked in the money market, in terms of the underlying stablecoin

    function totalValue(uint256 currentIncomeIndex)
        external
        view
        virtual
        returns (uint256); // The total value locked in the money market, in terms of the underlying stablecoin

    function incomeIndex() external virtual returns (uint256); // Used for calculating the interest generated (e.g. cDai's price for the Compound market)

    function stablecoin() external view virtual returns (ERC20);

    function claimRewards() external virtual; // Claims farmed tokens (e.g. COMP, CRV) and sends it to the rewards pool

    function setRewards(address newValue) external virtual;

    /**
        @dev See {Rescuable._authorizeRescue}
     */
    function _authorizeRescue(
        address, /*token*/
        address /*target*/
    ) internal view virtual override {
        require(hasRole(RESCUER_ROLE, msg.sender), "MoneyMarket: not rescuer");
    }

    event ESetParamAddress(
        address indexed sender,
        string indexed paramName,
        address newValue
    );
}
contract CreamERC20Market is MoneyMarket {
    using DecMath for uint256;
    using SafeERC20 for ERC20;
    using AddressUpgradeable for address;

    uint256 internal constant ERRCODE_OK = 0;

    ICrERC20 public cToken;
    ERC20 public override stablecoin;

    function initialize(
        address _cToken,
        address _rescuer,
        address _stablecoin
    ) external initializer {
        __MoneyMarket_init(_rescuer);
        // Verify input addresses
        require(
            _cToken.isContract() && _stablecoin.isContract(),
            "CreamERC20Market: An input address is not a contract"
        );

        cToken = ICrERC20(_cToken);
        stablecoin = ERC20(_stablecoin);
    }

    function deposit(uint256 amount) external override onlyOwner {
        require(amount > 0, "CreamERC20Market: amount is 0");

        // Transfer `amount` stablecoin from `msg.sender`
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        // Deposit `amount` stablecoin into cToken
        stablecoin.safeApprove(address(cToken), amount);
        require(
            cToken.mint(amount) == ERRCODE_OK,
            "CreamERC20Market: Failed to mint cTokens"
        );
    }

    function withdraw(uint256 amountInUnderlying)
        external
        override
        onlyOwner
        returns (uint256 actualAmountWithdrawn)
    {
        require(
            amountInUnderlying > 0,
            "CreamERC20Market: amountInUnderlying is 0"
        );

        // Withdraw `amountInUnderlying` stablecoin from cToken
        require(
            cToken.redeemUnderlying(amountInUnderlying) == ERRCODE_OK,
            "CreamERC20Market: Failed to redeem"
        );

        // Transfer `amountInUnderlying` stablecoin to `msg.sender`
        stablecoin.safeTransfer(msg.sender, amountInUnderlying);

        return amountInUnderlying;
    }

    function claimRewards() external override {}

    function totalValue() external override returns (uint256) {
        uint256 cTokenBalance = cToken.balanceOf(address(this));
        // Amount of stablecoin units that 1 unit of cToken can be exchanged for, scaled by 10^18
        uint256 cTokenPrice = cToken.exchangeRateCurrent();
        return cTokenBalance.decmul(cTokenPrice);
    }

    function totalValue(uint256 currentIncomeIndex)
        external
        view
        override
        returns (uint256)
    {
        uint256 cTokenBalance = cToken.balanceOf(address(this));
        return cTokenBalance.decmul(currentIncomeIndex);
    }

    function incomeIndex() external override returns (uint256 index) {
        index = cToken.exchangeRateCurrent();
        require(index > 0, "CreamERC20Market: BAD_INDEX");
    }

    function setRewards(address newValue) external override onlyOwner {}

    /**
        @dev See {Rescuable._authorizeRescue}
     */
    function _authorizeRescue(address token, address target)
        internal
        view
        override
    {
        super._authorizeRescue(token, target);
        address p1 = address(cToken);
        require(token != p1, "CreamERC20Market: no steal");
    }

    uint256[48] private __gap;
}
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable2Step.sol)

pragma solidity ^0.8.0;

import "./Ownable.sol";

/**
 * @dev Contract module which provides access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership} and {acceptOwnership}.
 *
 * This module is used through inheritance. It will make available all functions
 * from parent (Ownable).
 */
abstract contract Ownable2Step is Ownable {
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Returns the address of the pending owner.
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }

    /**
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() public virtual {
        address sender = _msgSender();
        require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
        _transferOwnership(sender);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
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
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
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
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.4) (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

// Errors
error ViolationOfTxAmountLimits();
error InvalidRequestOrSignature();
error UsedSignature();
error InvalidUpdateConfigurations();
error InsufficientConverterBalance();
error InsufficientLiquidityBalance();
error WithdrawExceedsDeposit();
error ZeroAddress();

contract TokenConversionManagerV3 is Ownable2Step {

    address internal immutable TOKEN;

    address private _conversionAuthorizer; // Authorizer Address for the conversion

    // already used conversion signature from authorizer in order to prevent replay attack
    mapping (bytes32 => bool) private _usedSignatures; 

    // Conversion Configurations
    uint256 private _perTxnMinAmount;
    uint256 private _perTxnMaxAmount;

    uint256 private _converterInternalLiquidity;

    // Events
    event NewAuthorizer(address conversionAuthorizer);
    event UpdateConfiguration(uint256 perTxnMinAmount, uint256 perTxnMaxAmount);

    event ConversionOut(address indexed tokenHolder, bytes32 conversionId, uint256 amount);
    event ConversionIn(address indexed tokenHolder, bytes32 conversionId, uint256 amount);

    event IncreaseLiquidity(uint256 added, uint256 totalLiquidity);
    event DecreaseLiquidity(uint256 removed, uint256 totalLiquidity);

    // Modifiers
    modifier checkLimits(uint256 amount) {
        // Check for min, max per transaction limits
        if (amount < _perTxnMinAmount || amount > _perTxnMaxAmount)
            revert ViolationOfTxAmountLimits();
        _;
    }
    
    modifier notZeroAddress(address account) {
        if (account == address(0))
            revert ZeroAddress();
        _;
    }

    constructor(address token) {   
        TOKEN = token;
        _conversionAuthorizer = _msgSender(); 
    }

    /**
    * @dev To update the authorizer who can authorize the conversions.
    * @param newAuthorizer - new contract authorizer address
    */
    function updateAuthorizer(address newAuthorizer) external notZeroAddress(newAuthorizer) onlyOwner {
        _conversionAuthorizer = newAuthorizer;

        emit NewAuthorizer(newAuthorizer);
    }

    /**
    * @dev To update the per transaction limits for the conversion and to provide max total supply 
    * @param perTxnMinAmount - min amount for conversion
    * @param perTxnMaxAmount - max amount for conversion
    */
    function updateConfigurations(
        uint256 perTxnMinAmount, 
        uint256 perTxnMaxAmount
    )
        external 
        onlyOwner 
    {
        // Check for the valid inputs
        if (perTxnMinAmount == 0 || perTxnMaxAmount <= perTxnMinAmount) 
            revert InvalidUpdateConfigurations();

        // Update the configurations
        _perTxnMinAmount = perTxnMinAmount;
        _perTxnMaxAmount = perTxnMaxAmount;

        emit UpdateConfiguration(perTxnMinAmount, perTxnMaxAmount);
    }


    /**
    * @dev To convert the tokens from Ethereum to non Ethereum network. 
    * The tokens which needs to be convereted will be locked on the host network.
    * The conversion authorizer needs to provide the signature to call this function.
    * @param amount - conversion amount
    * @param conversionId - hashed conversion id
    * @param v - split authorizer signature
    * @param r - split authorizer signature
    * @param s - split authorizer signature
    */
    function conversionOut(
        uint256 amount, 
        bytes32 conversionId, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) 
        external
        checkLimits(amount) 
    {
        // Check for non zero value for the amount is not needed as the Signature will not be generated for zero amount
        // Compose the message which was signed
        bytes32 message = prefixed(
            keccak256(
                abi.encodePacked(
                    "__conversionOut", 
                    amount,
                    _msgSender(),
                    conversionId, 
                    this
                )
            )
        );

        // Check that the signature is from the authorizer
        if (ecrecover(message, v, r, s) != _conversionAuthorizer)
            revert InvalidRequestOrSignature();

        // Check for replay attack (message signature can be used only once)
        if (_usedSignatures[message])
            revert UsedSignature();
        _usedSignatures[message] = true;

        IERC20(TOKEN).transferFrom(_msgSender(), address(this), amount);

        emit ConversionOut(_msgSender(), conversionId, amount);
    }

    /**
    * @dev To convert the tokens from non Ethereum to Ethereum network. 
    * The tokens which needs to be convereted will be transfer on the host network.
    * The conversion authorizer needs to provide the signature to call this function.
    * @param to - distination conversion operation address for transfer tokens at conversion
    * @param amount - conversion amount
    * @param conversionId - hashed conversion id
    * @param v - split authorizer signature
    * @param r - split authorizer signature
    * @param s - split authorizer signature
    */
    function conversionIn(
        address to, 
        uint256 amount, 
        bytes32 conversionId, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    )
        external
        notZeroAddress(to)
    {
        // Check for non zero value for the amount is not needed as the Signature will not be generated for zero amount
        // Compose the message which was signed
        bytes32 message = prefixed(
            keccak256(
                abi.encodePacked(
                    "__conversionIn",
                    amount, 
                    _msgSender(), 
                    conversionId, 
                    this
                )
            )
        );

        // Check that the signature is from the authorizer
        if (ecrecover(message, v, r, s) != _conversionAuthorizer)
            revert InvalidRequestOrSignature();

        // Check for replay attack (message signature can be used only once)
        if (_usedSignatures[message])
            revert UsedSignature();
        _usedSignatures[message] = true;

        // check for available token on contract
        if (getConverterBalance() < amount)
            revert InsufficientConverterBalance();

        IERC20(TOKEN).transfer(to, amount);

        emit ConversionIn(to, conversionId, amount);
    }

    /**
    * @dev Function for adding tokens to the converter manager for its possible use
    * @param amount - amount for add converter liquidity
    */
    function increaseConverterLiquidity(uint256 amount) external onlyOwner {
        
        _converterInternalLiquidity += amount;

        IERC20(TOKEN).transferFrom(_msgSender(), address(this), amount);
        
        emit IncreaseLiquidity(amount, _converterInternalLiquidity);
    }

    /**
    * @dev Function for adding tokens to the converter manager for its possible use
    * @param amount - amount for remove available converter liquidity
    */
    function decreaseConverterLiquidity(uint256 amount) external onlyOwner {

        if (_converterInternalLiquidity == 0) revert InsufficientLiquidityBalance();
        if (amount > _converterInternalLiquidity) revert WithdrawExceedsDeposit();
        if (amount > getConverterBalance()) revert InsufficientConverterBalance();

        _converterInternalLiquidity -= amount;

        IERC20(TOKEN).transfer(_msgSender(), amount);

        emit DecreaseLiquidity(amount, _converterInternalLiquidity);
    }

    /// Builds a prefixed hash to mimic the behavior of ethSign.
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
    * @dev Getter Function return currect converter authorizer
    */
    function getConversionAuthorizer() external view returns (address) {
        return _conversionAuthorizer;
    }

    /**
    * @dev Getter Function return currect converter configuration
    */
    function getConversionConfigurations() external view returns (uint256, uint256) {
        return(_perTxnMinAmount, _perTxnMaxAmount);
    }

    /**
    * @dev Getter Function return currect converter balance of tokens
    */
    function getConverterBalance() public view returns (uint256) {
        return IERC20(TOKEN).balanceOf(address(this));
    }
}

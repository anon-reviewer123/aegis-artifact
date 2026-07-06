// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ILiquidToken} from "../interfaces/ILiquidToken.sol";
import {ILiquidTokenManager} from "../interfaces/ILiquidTokenManager.sol";
import {ITokenRegistryOracle} from "../interfaces/ITokenRegistryOracle.sol";

/**
 * @title LiquidToken
 * @notice Implements a liquid staking token with deposit, withdrawal, and asset management functionalities
 */
contract LiquidToken is
    ILiquidToken,
    AccessControlUpgradeable,
    ERC20Upgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    // ------------------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------------------

    /// @notice Role identifier for pausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice LAT contracts
    ILiquidTokenManager public liquidTokenManager;
    ITokenRegistryOracle public tokenRegistryOracle;

    /// @notice Mapping of assets to their corresponding unstaked balances (held in this contract)
    mapping(address => uint256) public assetBalances;

    /// @notice Mapping of tokens to their corresponding queued balances (unused in V1)
    mapping(address => uint256) public queuedAssetBalances;

    /**
     * @dev OUT OF SCOPE FOR V1
    mapping(bytes32 => WithdrawalRequest) public withdrawalRequests;
    mapping(address => bytes32[]) public userWithdrawalRequests;
    mapping(address => uint256) private _withdrawalNonce;
    */

    // ------------------------------------------------------------------------------
    // Init functions
    // ------------------------------------------------------------------------------

    /// @dev Disables initializers for the implementation contract
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc ILiquidToken
    function initialize(Init calldata init) external initializer {
        __ERC20_init(init.name, init.symbol);
        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();

        if (
            address(init.initialOwner) == address(0) ||
            address(init.pauser) == address(0) ||
            address(init.liquidTokenManager) == address(0) ||
            address(init.tokenRegistryOracle) == address(0)
        ) {
            revert ZeroAddress();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, init.initialOwner);
        _grantRole(PAUSER_ROLE, init.pauser);

        liquidTokenManager = init.liquidTokenManager;
        tokenRegistryOracle = init.tokenRegistryOracle;
    }

    // ------------------------------------------------------------------------------
    // Core functions
    // ------------------------------------------------------------------------------

    /// @inheritdoc ILiquidToken
    function deposit(
        IERC20[] calldata assets,
        uint256[] calldata amounts,
        address receiver
    ) external nonReentrant whenNotPaused returns (uint256[] memory) {
        if (assets.length != amounts.length) revert ArrayLengthMismatch();

        // Check if prices need update
        if (tokenRegistryOracle.arePricesStale()) {
            // Attempt price update with minimal try/catch
            bool updated;
            try tokenRegistryOracle.updateAllPricesIfNeeded() returns (bool result) {
                updated = result;
            } catch {
                revert PriceUpdateFailed();
            }
            // Check update result
            if (!updated) revert PriceUpdateRejected();

            // Verify prices are no longer stale
            if (tokenRegistryOracle.arePricesStale()) revert PricesRemainStale();

            emit PricesUpdatedBeforeDeposit(msg.sender);
        }

        // Always check token prices regardless of staleness
        for (uint256 i = 0; i < assets.length; i++) {
            address assetAddr = address(assets[i]);
            if (liquidTokenManager.tokenIsSupported(assets[i])) {
                if (tokenRegistryOracle.getTokenPrice(assetAddr) == 0) {
                    revert AssetPriceInvalid(assetAddr);
                }
            }
        }

        uint256 len = assets.length;
        uint256[] memory sharesArray = new uint256[](len);

        unchecked {
            for (uint256 i = 0; i < len; i++) {
                IERC20 asset = assets[i];
                uint256 amount = amounts[i];

                if (amount == 0) revert ZeroAmount();
                if (!liquidTokenManager.tokenIsSupported(asset)) revert UnsupportedAsset(assets[i]);

                // True amount received may differ from `amount` for certain LSTs
                uint256 balanceBefore = asset.balanceOf(address(this));
                asset.safeTransferFrom(msg.sender, address(this), amount);
                uint256 balanceAfter = asset.balanceOf(address(this));

                uint256 trueAmount = balanceAfter - balanceBefore;

                uint256 shares = calculateShares(assets[i], trueAmount);
                if (shares == 0) revert ZeroShares();

                // Credit asset balances
                assetBalances[address(asset)] += trueAmount;

                if (assetBalances[address(asset)] > asset.balanceOf(address(this)))
                    revert AssetBalanceOutOfSync(
                        assets[i],
                        assetBalances[address(asset)],
                        asset.balanceOf(address(this))
                    );

                _mint(receiver, shares);
                sharesArray[i] = shares;

                emit AssetDeposited(msg.sender, receiver, assets[i], trueAmount, shares);
            }
        }

        return sharesArray;
    }

    /// @dev OUT OF SCOPE FOR V1
    /** 
    function requestWithdrawal(
        IERC20Upgradeable[] memory withdrawAssets,
        uint256[] memory shareAmounts
    ) external nonReentrant whenNotPaused {
        if (withdrawAssets.length != shareAmounts.length)
            revert ArrayLengthMismatch();

        uint256 len = withdrawAssets.length;
        address sender = msg.sender;
        uint256 totalShares;

        unchecked {
            for (uint256 i = 0; i < len; i++) {
                if (
                    !liquidTokenManager.tokenIsSupported(
                        IERC20(address(withdrawAssets[i]))
                    )
                ) revert UnsupportedAsset(withdrawAssets[i]);
                if (shareAmounts[i] == 0) revert ZeroAmount();
                totalShares += shareAmounts[i];
            }
        }

        if (balanceOf(sender) < totalShares)
            revert InsufficientBalance(
                IERC20Upgradeable(address(this)),
                totalShares,
                balanceOf(sender)
            );

        bytes32 requestId = keccak256(
            abi.encodePacked(
                sender,
                withdrawAssets,
                shareAmounts,
                block.timestamp,
                block.number,
                tx.gasprice,
                address(this),
                _withdrawalNonce[sender]++
            )
        );

        if (withdrawalRequests[requestId].user != address(0)) {
            revert DuplicateRequestId(requestId);
        }

        WithdrawalRequest memory request = WithdrawalRequest({
            user: sender,
            assets: withdrawAssets,
            shareAmounts: shareAmounts,
            requestTime: block.timestamp,
            fulfilled: false
        });

        withdrawalRequests[requestId] = request;
        userWithdrawalRequests[sender].push(requestId);

        _transfer(sender, address(this), totalShares);

        emit WithdrawalRequested(
            requestId,
            sender,
            withdrawAssets,
            shareAmounts,
            block.timestamp
        );
    }
    */

    /// @dev OUT OF SCOPE FOR V1
    /**
    function fulfillWithdrawal(bytes32 requestId) external nonReentrant {
        WithdrawalRequest storage request = withdrawalRequests[requestId];

        if (request.user != msg.sender) revert InvalidWithdrawalRequest();
        if (block.timestamp < request.requestTime + WITHDRAWAL_DELAY)
            revert WithdrawalDelayNotMet();
        if (request.fulfilled) revert WithdrawalAlreadyFulfilled();

        request.fulfilled = true;
        uint256[] memory amounts = new uint256[](request.assets.length);
        uint256 totalShares = 0;

        for (uint256 i = 0; i < request.assets.length; i++) {
            amounts[i] = calculateAmount(
                request.assets[i],
                request.shareAmounts[i]
            );
            totalShares += request.shareAmounts[i];
        }

        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 amount = amounts[i];
            IERC20 asset = IERC20(address(request.assets[i]));

            // Check the contract's actual token balance
            if (asset.balanceOf(address(this)) < amount) {
                revert InsufficientBalance(
                    request.assets[i],
                    asset.balanceOf(address(this)),
                    amount
                );
            }

            // Transfer the amount back to the user
            asset.safeTransfer(msg.sender, amount);

            // Reduce the asset balances for the asset
            // Note: Make sure that whenever this contract receives funds from EL withdrawal, `queuedAssetBalances` is debited and `assetBalances` is credited
            assetBalances[address(asset)] -= amount;

            if (assetBalances[address(asset)] > asset.balanceOf(address(this)))
                revert AssetBalanceOutOfSync(
                    request.assets[i],
                    assetBalances[address(asset)],
                    asset.balanceOf(address(this))
                );
        }

        // Burn the shares that were transferred to the contract during the withdrawal request
        _burn(address(this), totalShares);

        emit WithdrawalFulfilled(
            requestId,
            msg.sender,
            request.assets,
            amounts,
            block.timestamp
        );
    }
    */

    /// @inheritdoc ILiquidToken
    function creditQueuedAssetBalances(IERC20[] calldata assets, uint256[] calldata amounts) external whenNotPaused {
        if (msg.sender != address(liquidTokenManager)) revert NotLiquidTokenManager(msg.sender);

        if (assets.length != amounts.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < assets.length; i++) {
            queuedAssetBalances[address(assets[i])] += amounts[i];
        }
    }

    /// @inheritdoc ILiquidToken
    function transferAssets(IERC20[] calldata assetsToRetrieve, uint256[] calldata amounts) external whenNotPaused {
        if (msg.sender != address(liquidTokenManager)) revert NotLiquidTokenManager(msg.sender);

        if (assetsToRetrieve.length != amounts.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < assetsToRetrieve.length; i++) {
            IERC20 asset = assetsToRetrieve[i];
            uint256 amount = amounts[i];

            if (!liquidTokenManager.tokenIsSupported(asset)) revert UnsupportedAsset(assetsToRetrieve[i]);

            if (amount > assetBalances[address(asset)])
                revert InsufficientBalance(asset, assetBalances[address(asset)], amount);

            assetBalances[address(asset)] -= amount;
            asset.safeTransfer(address(liquidTokenManager), amount);

            if (assetBalances[address(asset)] > asset.balanceOf(address(this)))
                revert AssetBalanceOutOfSync(
                    assetsToRetrieve[i],
                    assetBalances[address(asset)],
                    asset.balanceOf(address(this))
                );

            emit AssetTransferred(assetsToRetrieve[i], amount, address(liquidTokenManager), msg.sender);
        }
    }

    /// @inheritdoc ILiquidToken
    function calculateShares(IERC20 asset, uint256 amount) public view returns (uint256) {
        uint256 assetAmountInUnitOfAccount = liquidTokenManager.convertToUnitOfAccount(asset, amount);
        return _convertToShares(assetAmountInUnitOfAccount);
    }

    /// @inheritdoc ILiquidToken
    function calculateAmount(IERC20 asset, uint256 shares) public view returns (uint256) {
        uint256 amountInUnitOfAccount = _convertToAssets(shares);
        return liquidTokenManager.convertFromUnitOfAccount(asset, amountInUnitOfAccount);
    }

    // ------------------------------------------------------------------------------
    // Getter functions
    // ------------------------------------------------------------------------------

    /**
     * @dev OUT OF SCOPE FOR V1
     */
    /**
    function getUserWithdrawalRequests(
        address user
    ) external view returns (bytes32[] memory) {
        return userWithdrawalRequests[user];
    }
    */

    /**
     * @dev OUT OF SCOPE FOR V1
     */
    /**
    function getWithdrawalRequest(
        bytes32 requestId
    ) external view returns (WithdrawalRequest memory) {
        return withdrawalRequests[requestId];
    }
    */

    /// @inheritdoc ILiquidToken
    function totalAssets() public view returns (uint256) {
        IERC20[] memory supportedTokens = liquidTokenManager.getSupportedTokens();

        uint256 total = 0;
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            // Unstaked Asset Balances
            total += liquidTokenManager.convertToUnitOfAccount(supportedTokens[i], _balanceAsset(supportedTokens[i]));

            // Queued Asset Balances
            total += liquidTokenManager.convertToUnitOfAccount(
                supportedTokens[i],
                _balanceQueuedAsset(supportedTokens[i])
            );

            // Staked Withdrawable Asset Balances
            total += liquidTokenManager.getWithdrawableAssetBalance(supportedTokens[i]);
        }

        return total;
    }

    /// @inheritdoc ILiquidToken
    function balanceAssets(IERC20[] calldata assetList) public view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](assetList.length);
        for (uint256 i = 0; i < assetList.length; i++) {
            balances[i] = _balanceAsset(assetList[i]);
        }
        return balances;
    }

    /// @inheritdoc ILiquidToken
    function balanceQueuedAssets(IERC20[] calldata assetList) public view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](assetList.length);
        for (uint256 i = 0; i < assetList.length; i++) {
            balances[i] = _balanceQueuedAsset(assetList[i]);
        }
        return balances;
    }

    // ------------------------------------------------------------------------------
    // Internal functions
    // ------------------------------------------------------------------------------

    /// @dev Called by `calculateShares`
    function _convertToShares(uint256 amount) internal view returns (uint256) {
        uint256 supply = totalSupply();
        uint256 totalAsset = totalAssets();

        // Check for totalAssets being 0 to avoid division by zero
        if (supply == 0 || totalAsset == 0) {
            return amount;
        }

        return (amount * supply) / totalAsset;
    }

    /// @dev Called by `calculateAmount`
    function _convertToAssets(uint256 shares) internal view returns (uint256) {
        uint256 supply = totalSupply();
        uint256 totalAsset = totalAssets();

        // Check for totalSupply being 0 to avoid division by zero
        if (supply == 0 || totalAsset == 0) {
            return shares;
        }

        return (shares * totalAsset) / supply;
    }

    /// @dev Called by `balanceAssets` and `totalAssets`
    function _balanceAsset(IERC20 asset) internal view returns (uint256) {
        return assetBalances[address(asset)];
    }

    /// @dev Called by `balanceQueuedAssets` and `totalAssets`
    function _balanceQueuedAsset(IERC20 asset) internal view returns (uint256) {
        return queuedAssetBalances[address(asset)];
    }

    // ------------------------------------------------------------------------------
    // Misc
    // ------------------------------------------------------------------------------

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/IERC20Permit.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Compatible with tokens that require the approval to be set to
     * 0 before setting it to a non-zero value.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && Address.isContract(address(token));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20Upgradeable.sol";
import "./extensions/IERC20MetadataUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable, IERC20MetadataUpgradeable {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized != type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";
import "../utils/ContextUpgradeable.sol";
import "../utils/StringsUpgradeable.sol";
import "../utils/introspection/ERC165Upgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal onlyInitializing {
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(account),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
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
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
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
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
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
pragma solidity ^0.8.27;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ILiquidTokenManager} from "../interfaces/ILiquidTokenManager.sol";
import {ITokenRegistryOracle} from "../interfaces/ITokenRegistryOracle.sol";

/// @title ILiquidToken Interface
/// @notice Interface for the LiquidToken contract
interface ILiquidToken {
    // ============================================================================
    // STRUCTS
    // ============================================================================

    /// @notice Initialization parameters for LiquidToken
    struct Init {
        string name;
        string symbol;
        ILiquidTokenManager liquidTokenManager;
        ITokenRegistryOracle tokenRegistryOracle;
        address initialOwner;
        address pauser;
    }

    /// @dev OUT OF SCOPE FOR V1
    /**
    struct WithdrawalRequest {
        address user;
        IERC20[] assets;
        uint256[] shareAmounts;
        uint256 requestTime;
        bool fulfilled;
    }
    */

    // ============================================================================
    // EVENTS
    // ============================================================================

    /// @notice Emitted when prices are updated during a deposit
    event PricesUpdatedBeforeDeposit(address indexed depositor);

    /// @notice Emitted when an asset is deposited
    event AssetDeposited(
        address indexed sender,
        address indexed receiver,
        IERC20 indexed asset,
        uint256 amount,
        uint256 shares
    );

    /// @dev OUT OF SCOPE FOR V1
    /**
    event WithdrawalRequested(
        bytes32 indexed requestId,
        address indexed user,
        IERC20[] assets,
        uint256[] shareAmounts,
        uint256 timestamp
    );
    */

    /// @dev OUT OF SCOPE FOR V1
    /**
    event WithdrawalFulfilled(
        bytes32 indexed requestId,
        address indexed user,
        IERC20[] assets,
        uint256[] shareAmounts,
        uint256 timestamp
    );
    */

    /// @notice Emitted when an asset is transferred
    event AssetTransferred(
        IERC20 indexed asset,
        uint256 amount,
        address indexed destination,
        address indexed initiator
    );

    // ============================================================================
    // CUSTOM ERRORS
    // ============================================================================

    /// @notice Error for unsupported asset
    error UnsupportedAsset(IERC20 asset);

    /// @notice Error for zero address
    error ZeroAddress();

    /// @notice Error for zero amount
    error ZeroAmount();

    /// @notice Error for zero shares
    error ZeroShares();

    /// @notice Error for unauthorized access by non-LiquidTokenManager
    error NotLiquidTokenManager(address sender);

    /// @dev OUT OF SCOPE FOR V1
    /**
    error InvalidWithdrawalRequest();
    error WithdrawalDelayNotMet();
    error WithdrawalAlreadyFulfilled();
    error DuplicateRequestId(bytes32 requestId);
    */

    /// @notice Error for mismatched array lengths
    error ArrayLengthMismatch();

    /// @notice Error for insufficient balance
    error InsufficientBalance(IERC20 asset, uint256 required, uint256 available);

    /// @notice Error when contract token balance is not in sync with accounting balance
    error AssetBalanceOutOfSync(IERC20 asset, uint256 accountingBalance, uint256 actualBalance);

    /// @notice Generic price update failure
    error PriceUpdateFailed();

    /// @notice Price update returned false
    error PriceUpdateRejected();

    /// @notice Prices still stale after update
    error PricesRemainStale();

    /// @notice Specific token has invalid price
    error AssetPriceInvalid(address token);

    // ============================================================================
    //  FUNCTIONS
    // ============================================================================

    /// @notice Initializes the LiquidTokenManager contract
    /// @param init Initialization parameters
    function initialize(Init memory init) external;

    /// @notice Allows users to deposit multiple assets and receive shares
    /// @param assets The ERC20 assets to deposit
    /// @param amounts The amounts of the respective assets to deposit
    /// @param receiver The address to receive the minted shares
    /// @return sharesArray The array of shares minted for each asset
    function deposit(
        IERC20[] calldata assets,
        uint256[] calldata amounts,
        address receiver
    ) external returns (uint256[] memory);

    /// @dev Out OF SCOPE FOR V1
    /** 
    function requestWithdrawal(
        IERC20[] memory withdrawAssets,
        uint256[] memory shareAmounts
    ) external;
    */

    /// @dev Out OF SCOPE FOR V1
    /** 
    function fulfillWithdrawal(bytes32 requestId) external;
    */

    /// @notice Credits queued balances for a given set of assets
    /// @param assets The assets to credit
    /// @param amounts The credit amounts expressed in native token
    function creditQueuedAssetBalances(IERC20[] calldata assets, uint256[] calldata amounts) external;

    /// @notice Allows the LiquidTokenManager to transfer assets from this contract
    /// @param assetsToRetrieve The ERC20 assets to transfer
    /// @param amounts The amounts of each asset to transfer
    function transferAssets(IERC20[] calldata assetsToRetrieve, uint256[] calldata amounts) external;

    /// @notice Calculates the number of shares that correspond to a given amount of an asset
    /// @param asset The ERC20 asset
    /// @param amount The amount of the asset
    /// @return The number of shares
    function calculateShares(IERC20 asset, uint256 amount) external view returns (uint256);

    /// @notice Calculates the amount of an asset that corresponds to a given number of shares
    /// @param asset The ERC20 asset
    /// @param shares The number of shares
    /// @return The amount of the asset
    function calculateAmount(IERC20 asset, uint256 shares) external view returns (uint256);

    /// @notice Returns the total value of assets (staked, queued and unstaked) managed by the contract
    /// @return The total value of assets in the unit of account
    function totalAssets() external view returns (uint256);

    /// @dev Out OF SCOPE FOR V1
    /**
    function getUserWithdrawalRequests(address user)
        external
        view
        returns (bytes32[] memory);
    */

    /// @dev Out OF SCOPE FOR V1
    /**
    function getWithdrawalRequest(bytes32 requestId) external view returns (WithdrawalRequest memory);
    */

    /// @notice Returns the unstaked balances for a set of assets
    /// @param assetList The list of assets to get balances for
    /// @return An array of asset balances
    function balanceAssets(IERC20[] calldata assetList) external view returns (uint256[] memory);

    /// @notice Returns the queued balances for a set of assets
    /// @param assetList The list of assets to get queued balances for
    /// @return An array of queued asset balances
    function balanceQueuedAssets(IERC20[] calldata assetList) external view returns (uint256[] memory);

    /// @notice Pauses the contract
    function pause() external;

    /// @notice Unpauses the contract
    function unpause() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IStrategyManager} from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import {IStrategy} from "@eigenlayer/contracts/interfaces/IStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISignatureUtilsMixinTypes} from "@eigenlayer/contracts/interfaces/ISignatureUtilsMixin.sol";

import {ILiquidToken} from "./ILiquidToken.sol";
import {IStakerNodeCoordinator} from "./IStakerNodeCoordinator.sol";
import {ITokenRegistryOracle} from "./ITokenRegistryOracle.sol";

/// @title ILiquidTokenManager Interface
/// @notice Interface for the LiquidTokenManager contract
interface ILiquidTokenManager {
    // ============================================================================
    // STRUCTS
    // ============================================================================

    /// @notice Initialization parameters for LiquidTokenManager
    struct Init {
        ILiquidToken liquidToken;
        IStrategyManager strategyManager;
        IDelegationManager delegationManager;
        IStakerNodeCoordinator stakerNodeCoordinator;
        ITokenRegistryOracle tokenRegistryOracle;
        address initialOwner;
        address strategyController;
        address priceUpdater;
    }

    /// @notice Supported token information
    /// @param decimals The number of decimals for the token
    /// @param pricePerUnit The price per unit of the token
    /// @param volatilityThreshold The allowed change ratio for price update, in 1e18. Must be 0 (disabled) or >= 0.01 * 1e18 and <= 1 * 1e18.
    struct TokenInfo {
        uint256 decimals;
        uint256 pricePerUnit;
        uint256 volatilityThreshold;
    }

    /// @notice Represents an allocation of assets to a node
    struct NodeAllocation {
        uint256 nodeId;
        IERC20[] assets;
        uint256[] amounts;
    }

    // ============================================================================
    // EVENTS
    // ============================================================================

    /// @notice Emitted when a new token is set
    event TokenAdded(
        IERC20 indexed token,
        uint256 decimals,
        uint256 initialPrice,
        uint256 volatilityThreshold,
        address indexed strategy,
        address indexed setter
    );

    /// @notice Emitted when a token's price is updated
    event TokenPriceUpdated(IERC20 indexed token, uint256 oldPrice, uint256 newPrice, address indexed updater);

    /// @notice Emitted when the volatility threshold for an asset is updated
    event VolatilityThresholdUpdated(
        IERC20 indexed asset,
        uint256 oldThreshold,
        uint256 newThreshold,
        address indexed updatedBy
    );

    /// @notice Emitted when a price update fails due to change exceeding the volatility threshold
    event VolatilityCheckFailed(IERC20 indexed token, uint256 oldPrice, uint256 newPrice, uint256 changeRatio);

    /// @notice Emitted when assets are staked to a node
    event AssetsStakedToNode(uint256 indexed nodeId, IERC20[] assets, uint256[] amounts, address indexed staker);

    /// @notice Emitted when assets are deposited to Eigenlayer
    event AssetsDepositedToEigenlayer(
        IERC20[] assets,
        uint256[] amounts,
        IStrategy[] strategies,
        address indexed depositor
    );

    /// @notice Emitted when a staker node is delegated to an operator
    event NodeDelegated(uint256 nodeId, address indexed operator);

    /// @notice Emitted when a staker node is undelegated from its current operator
    event NodeUndelegated(uint256 nodeId, address indexed operator);

    /// @notice Emitted when a token is removed from the registry
    event TokenRemoved(IERC20 indexed token, address indexed remover);

    // ============================================================================
    // CUSTOM ERRORS
    // ============================================================================

    /// @notice Error for zero address
    error ZeroAddress();

    /// @notice Error for invalid staking amount
    error InvalidStakingAmount(uint256 amount);

    /// @notice Error when asset already exists
    error TokenExists(address asset);

    /// @notice Error thrown when an operation is attempted on an unsupported token
    error TokenNotSupported(IERC20 token);

    /// @notice Error thrown when attempting to remove a token that is currently in use
    error TokenInUse(IERC20 token);

    /// @notice Error thrown when price source configuration is invalid
    error InvalidPriceSource();

    /// @notice Error when token price fetch fails during token addition
    error TokenPriceFetchFailed();

    /// @notice Error when strategy is not found
    error StrategyNotFound(address asset);

    /// @notice Error when token is not found for a strategy
    error TokenForStrategyNotFound(address strategy);

    /// @notice Error for mismatched array lengths
    error LengthMismatch(uint256 length1, uint256 length2);

    /// @notice Error for invalid node ID
    error InvalidNodeId(uint256 nodeId);

    /// @notice Error thrown when an invalid decimals value is provided
    error InvalidDecimals();

    /// @notice Error thrown when an address is not a valid contract
    error NotAContract();

    /// @notice Error thrown when a strategy is already assigned to another token
    error StrategyAlreadyAssigned(address strategy, address existingToken);

    /// @notice Error thrown when an invalid price is provided
    error InvalidPrice();

    /// @notice Error thrown when an invalid volatility threshold is provided
    error InvalidThreshold();

    /// @notice Error thrown when a price update fails due to change exceeding the volatility threshold
    error VolatilityThresholdHit(IERC20 token, uint256 changeRatio);

    // ============================================================================
    // FUNCTIONS
    // ============================================================================

    /// @notice Initializes the LiquidTokenManager contract
    /// @param init Initialization parameters
    function initialize(Init memory init) external;

    /// @notice Adds a new token to the registry and configures its price sources
    /// @param token Address of the token to add
    /// @param decimals Number of decimals for the token
    /// @param volatilityThreshold Volatility threshold for price updates
    /// @param strategy Strategy corresponding to the token
    /// @param primaryType Source type (1=Chainlink, 2=Curve, 3=Protocol, 0=native tokens handled differently)
    /// @param primarySource Primary source address
    /// @param needsArg Whether fallback fn needs args
    /// @param fallbackSource Address of the fallback source contract
    /// @param fallbackFn Function selector for fallback
    function addToken(
        IERC20 token,
        uint8 decimals,
        uint256 volatilityThreshold,
        IStrategy strategy,
        uint8 primaryType,
        address primarySource,
        uint8 needsArg,
        address fallbackSource,
        bytes4 fallbackFn
    ) external;

    /// @notice Removes a token from the registry
    /// @param token Address of the token to remove
    function removeToken(IERC20 token) external;

    /// @notice Updates the price of a token
    /// @param token Address of the token to update
    /// @param newPrice New price for the token
    function updatePrice(IERC20 token, uint256 newPrice) external;

    /// @notice Updates the volatility threshold for price updates
    /// @param asset The asset to update threshold for
    /// @param newThreshold The new volatility threshold (in 1e18 precision)
    function setVolatilityThreshold(IERC20 asset, uint256 newThreshold) external;

    /// @notice Delegate a set of staker nodes to a corresponding set of operators
    /// @param nodeIds The IDs of the staker nodes
    /// @param operators The addresses of the operators
    /// @param approverSignatureAndExpiries The signatures authorizing the delegations
    /// @param approverSalts The salts used in the signatures
    function delegateNodes(
        uint256[] calldata nodeIds,
        address[] calldata operators,
        ISignatureUtilsMixinTypes.SignatureWithExpiry[] calldata approverSignatureAndExpiries,
        bytes32[] calldata approverSalts
    ) external;

    /// @notice Stakes assets to a specific node
    /// @param nodeId The ID of the node to stake to
    /// @param assets Array of asset addresses to stake
    /// @param amounts Array of amounts to stake for each asset
    function stakeAssetsToNode(uint256 nodeId, IERC20[] memory assets, uint256[] memory amounts) external;

    /// @notice Stakes assets to multiple nodes
    /// @param allocations Array of NodeAllocation structs containing staking information
    function stakeAssetsToNodes(NodeAllocation[] calldata allocations) external;

    /// @dev Out OF SCOPE FOR V1
    /**
    function undelegateNodes(
        uint256[] calldata nodeIds
    ) external;
    */

    /// @notice Retrieves the list of supported tokens
    /// @return An array of addresses of supported tokens
    function getSupportedTokens() external view returns (IERC20[] memory);

    /// @notice Retrieves the information for a specific token
    /// @param token Address of the token to get information for
    /// @return TokenInfo struct containing the token's information
    function getTokenInfo(IERC20 token) external view returns (TokenInfo memory);

    /// @notice Returns the strategy for a given asset
    /// @param asset Asset to get the strategy for
    /// @return IStrategy Interface for the corresponding strategy
    function getTokenStrategy(IERC20 asset) external view returns (IStrategy);

    /// @notice Returns the token for a given strategy
    /// @param strategy Strategy to get the token for
    /// @return IERC20 Interface for the corresponding token
    function getStrategyToken(IStrategy strategy) external view returns (IERC20);

    /// @notice Gets the staked deposits balance of an asset for all nodes
    /// @dev This corresponds to the asset value of `depositShares` which does not factor in any slashing
    /// @param asset The asset to check the balance for
    /// @return The total staked balance of the asset across all nodes
    function getDepositAssetBalance(IERC20 asset) external view returns (uint256);

    /// @notice Gets the staked deposits balance of an asset for a specific node
    /// @dev This corresponds to the asset value of `depositShares` which does not factor in any slashing
    /// @param asset The asset to check the balance for
    /// @param nodeId The ID of the node
    /// @return The staked balance of the asset for the specific node
    function getDepositAssetBalanceNode(IERC20 asset, uint256 nodeId) external view returns (uint256);

    /// @notice Gets the withdrawable balance of an asset for all nodes
    /// @dev This corresponds to the asset value of `withdrawableShares` which is `depositShares` minus slashing if any
    /// @param asset The asset token address
    function getWithdrawableAssetBalance(IERC20 asset) external view returns (uint256);

    /// @notice Gets the withdrawable balance of an asset for a specific node
    /// @dev This corresponds to the asset value of `withdrawableShares` which is `depositShares` minus slashing if any
    /// @param asset The asset token address
    /// @param nodeId The ID of the node
    function getWithdrawableAssetBalanceNode(IERC20 asset, uint256 nodeId) external view returns (uint256);

    /// @notice Checks if a token is supported
    /// @param token Address of the token to check
    /// @return bool indicating whether the token is supported
    function tokenIsSupported(IERC20 token) external view returns (bool);

    /// @notice Converts a token amount to the unit of account
    /// @param token Address of the token to convert
    /// @param amount Amount of tokens to convert
    /// @return The converted amount in the unit of account
    function convertToUnitOfAccount(IERC20 token, uint256 amount) external view returns (uint256);

    /// @notice Converts an amount in the unit of account to a token amount
    /// @param token Address of the token to convert to
    /// @param amount Amount in the unit of account to convert
    /// @return The converted amount in the specified token
    function convertFromUnitOfAccount(IERC20 token, uint256 amount) external view returns (uint256);

    /// @notice Check if a strategy is supported
    /// @param strategy The strategy address
    /// @return True if the strategy is supported
    function isStrategySupported(IStrategy strategy) external view returns (bool);

    /// @notice Returns the token registry oracle contract
    /// @return The ITokenRegistryOracle interface
    function tokenRegistryOracle() external view returns (ITokenRegistryOracle);

    /// @notice Returns the StrategyManager contract
    /// @return The IStrategyManager interface
    function strategyManager() external view returns (IStrategyManager);

    /// @notice Returns the DelegationManager contract
    /// @return The IDelegationManager interface
    function delegationManager() external view returns (IDelegationManager);

    /// @notice Returns the StakerNodeCoordinator contract
    /// @return The IStakerNodeCoordinator interface
    function stakerNodeCoordinator() external view returns (IStakerNodeCoordinator);

    /// @notice Returns the LiquidToken contract
    /// @return The ILiquidToken interface
    function liquidToken() external view returns (ILiquidToken);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILiquidTokenManager} from "./ILiquidTokenManager.sol";

/// @title ITokenRegistryOracle Interface
/// @notice Interface for the TokenRegistryOracle contract
/// @dev Provides price oracle functionality with primary and fallback sources
interface ITokenRegistryOracle {
    // ============================================================================
    // STRUCTS
    // ============================================================================

    /// @notice Initialization parameters for TokenRegistryOracle
    struct Init {
        address initialOwner;
        address priceUpdater;
        address liquidToken;
        ILiquidTokenManager liquidTokenManager;
    }

    struct TokenConfig {
        uint8 primaryType; // 1=Chainlink, 2=Curve, 3=Protocol,
        uint8 needsArg; // 0=No arg, 1=Needs arg
        uint16 reserved; // For future use
        address primarySource; // Primary price source address
        address fallbackSource; // Fallback source contract address
        bytes4 fallbackFn; // Function selector for fallback
    }

    // ============================================================================
    // EVENTS
    // ============================================================================

    /// @notice Emitted when a token's rate is updated
    event TokenRateUpdated(IERC20 indexed token, uint256 oldRate, uint256 newRate, address indexed updater);

    /// @notice Emitted when the emergency interval is disabled
    event EmergencyIntervalDisabled();

    /// @notice Emitted when a token's source is set
    event TokenSourceSet(address indexed token, address indexed source);

    /// @notice Emitted when update interval is changed
    event UpdateIntervalChanged(uint256 oldInterval, uint256 newInterval);

    /// @notice Emitted when all prices are updated
    event GlobalPricesUpdated(address indexed updater, uint256 timestamp);

    /// @notice Emitted when a token is removed from configuration
    event TokenRemoved(address token);

    /// @notice Emitted when multiple pool safety settings are updated
    event BatchPoolsConfigured(address[] pools, bool[] settings);

    // ============================================================================
    // CUSTOM ERRORS
    // ============================================================================

    /// @notice Error zero address
    error ZeroAddress();

    /// @notice Error thrown when no valid prices fetched by both primary & fallbacks sources
    error NoFreshPrice(address token);

    /// @notice Error thrown when an unauthorized address attempts to update prices
    error InvalidUpdater(address sender);

    /// @notice Error for mismatched array lengths
    error ArrayLengthMismatch();

    /// @notice Error when trying to configure native tokens in oracle
    error NativeTokensNotConfigurable();

    /// @notice Error when fallback source required but not provided
    error FallbackSourceRequired();

    /// @notice Error when interval input is zero
    error IntervalCannotBeZero();

    // ============================================================================
    // FUNCTIONS
    // ============================================================================

    /// @notice Initializes the TokenRegistryOracle contract
    /// @param init Struct containing initialization parameters
    function initialize(Init memory init, uint256 stalenessSalt) external;

    /// @notice Configure a token with its primary and fallback sources
    /// @param token Token address
    /// @param primaryType Source type (1=Chainlink, 2=Curve, 3=Protocol)
    /// @param primarySource Primary source address
    /// @param needsArg Whether fallback fn needs args
    /// @param fallbackSource Address of the fallback source contract
    /// @param fallbackFn Function selector for fallback
    function configureToken(
        address token,
        uint8 primaryType,
        address primarySource,
        uint8 needsArg,
        address fallbackSource,
        bytes4 fallbackFn
    ) external;

    /// @notice Remove a token configuration from the registry
    /// @param token Address of the token to remove
    function removeToken(address token) external;

    /// @notice Updates the rate for a single token
    /// @param token Address of the token to update
    /// @param newRate New rate for the token
    function updateRate(IERC20 token, uint256 newRate) external;

    /// @notice Updates rates for multiple tokens in a single transaction
    /// @param tokens Array of token addresses to update
    /// @param newRates Array of new rates corresponding to the tokens
    function batchUpdateRates(IERC20[] calldata tokens, uint256[] calldata newRates) external;

    /// @notice Updates all token prices if they are stale
    /// @return Whether prices were updated
    function updateAllPricesIfNeeded() external returns (bool);

    /// @notice Sets price update interval
    /// @param interval New interval in seconds
    function setPriceUpdateInterval(uint256 interval) external;

    /// @notice Disables emergency interval mode and returns to dynamic intervals
    function disableEmergencyInterval() external;

    /// @notice Set reentrancy lock requirements for multiple pools in one transaction
    /// @param pools Array of Curve pool addresses
    /// @param settings Array of boolean values indicating if each pool requires the lock
    function batchSetRequiresLock(address[] calldata pools, bool[] calldata settings) external;

    /// @notice Retrieves the current rate for a given token
    /// @param token Address of the token to query
    /// @return Current rate of the token
    function getRate(IERC20 token) external view returns (uint256);

    /// @notice Checks if prices are stale and need updating
    /// @return Whether prices need updating
    function arePricesStale() external view returns (bool);

    /// @notice Get last price update timestamp
    /// @return Timestamp of last price update
    function lastPriceUpdate() external view returns (uint256);

    /// @notice Get the current price of a token in ETH
    /// @param token Token address to get price for
    /// @return The current price with 18 decimals precision
    function getTokenPrice(address token) external returns (uint256);

    /// @notice Get token price from primary source
    /// @dev Helper function for `ILiquidTokenManger.addToken`
    /// @dev This function exposes the internal `_getTokenPrice` for testing/setting purposes
    /// @param token The token address to get the price for
    /// @return price The price of the asset in 18 decimals
    /// @return success Whether the price fetch was successful
    function _getTokenPrice_getter(address token) external returns (uint256 price, bool success);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
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
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

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
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

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
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/MathUpgradeable.sol";
import "./math/SignedMathUpgradeable.sol";

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = MathUpgradeable.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toString(int256 value) internal pure returns (string memory) {
        return string(abi.encodePacked(value < 0 ? "-" : "", toString(SignedMathUpgradeable.abs(value))));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, MathUpgradeable.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "./IStrategy.sol";
import "./IShareManager.sol";
import "./IDelegationManager.sol";
import "./IEigenPodManager.sol";
import "./ISemVerMixin.sol";

interface IStrategyManagerErrors {
    /// @dev Thrown when total strategies deployed exceeds max.
    error MaxStrategiesExceeded();
    /// @dev Thrown when call attempted from address that's not delegation manager.
    error OnlyDelegationManager();
    /// @dev Thrown when call attempted from address that's not strategy whitelister.
    error OnlyStrategyWhitelister();
    /// @dev Thrown when provided `shares` amount is too high.
    error SharesAmountTooHigh();
    /// @dev Thrown when provided `shares` amount is zero.
    error SharesAmountZero();
    /// @dev Thrown when provided `staker` address is null.
    error StakerAddressZero();
    /// @dev Thrown when provided `strategy` not found.
    error StrategyNotFound();
    /// @dev Thrown when attempting to deposit to a non-whitelisted strategy.
    error StrategyNotWhitelisted();
}

interface IStrategyManagerEvents {
    /**
     * @notice Emitted when a new deposit occurs on behalf of `staker`.
     * @param staker Is the staker who is depositing funds into EigenLayer.
     * @param strategy Is the strategy that `staker` has deposited into.
     * @param shares Is the number of new shares `staker` has been granted in `strategy`.
     */
    event Deposit(address staker, IStrategy strategy, uint256 shares);

    /// @notice Emitted when the `strategyWhitelister` is changed
    event StrategyWhitelisterChanged(address previousAddress, address newAddress);

    /// @notice Emitted when a strategy is added to the approved list of strategies for deposit
    event StrategyAddedToDepositWhitelist(IStrategy strategy);

    /// @notice Emitted when a strategy is removed from the approved list of strategies for deposit
    event StrategyRemovedFromDepositWhitelist(IStrategy strategy);

    /// @notice Emitted when an operator is slashed and shares to be burned are increased
    event BurnableSharesIncreased(IStrategy strategy, uint256 shares);

    /// @notice Emitted when shares are burned
    event BurnableSharesDecreased(IStrategy strategy, uint256 shares);
}

/**
 * @title Interface for the primary entrypoint for funds into EigenLayer.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice See the `StrategyManager` contract itself for implementation details.
 */
interface IStrategyManager is IStrategyManagerErrors, IStrategyManagerEvents, IShareManager, ISemVerMixin {
    /**
     * @notice Initializes the strategy manager contract. Sets the `pauserRegistry` (currently **not** modifiable after being set),
     * and transfers contract ownership to the specified `initialOwner`.
     * @param initialOwner Ownership of this contract is transferred to this address.
     * @param initialStrategyWhitelister The initial value of `strategyWhitelister` to set.
     * @param initialPausedStatus The initial value of `_paused` to set.
     */
    function initialize(
        address initialOwner,
        address initialStrategyWhitelister,
        uint256 initialPausedStatus
    ) external;

    /**
     * @notice Deposits `amount` of `token` into the specified `strategy` and credits shares to the caller
     * @param strategy the strategy that handles `token`
     * @param token the token from which the `amount` will be transferred
     * @param amount the number of tokens to deposit
     * @return depositShares the number of deposit shares credited to the caller
     * @dev The caller must have previously approved this contract to transfer at least `amount` of `token` on their behalf.
     *
     * WARNING: Be extremely cautious when depositing tokens that do not strictly adhere to ERC20 standards.
     * Tokens that diverge significantly from ERC20 norms can cause unexpected behavior in token balances for
     * that strategy, e.g. ERC-777 tokens allowing cross-contract reentrancy.
     */
    function depositIntoStrategy(
        IStrategy strategy,
        IERC20 token,
        uint256 amount
    ) external returns (uint256 depositShares);

    /**
     * @notice Deposits `amount` of `token` into the specified `strategy` and credits shares to the `staker`
     * Note tokens are transferred from `msg.sender`, NOT from `staker`. This method allows the caller, using a
     * signature, to deposit their tokens to another staker's balance.
     * @param strategy the strategy that handles `token`
     * @param token the token from which the `amount` will be transferred
     * @param amount the number of tokens to transfer from the caller to the strategy
     * @param staker the staker that the deposited assets will be credited to
     * @param expiry the timestamp at which the signature expires
     * @param signature a valid ECDSA or EIP-1271 signature from `staker`
     * @return depositShares the number of deposit shares credited to `staker`
     * @dev The caller must have previously approved this contract to transfer at least `amount` of `token` on their behalf.
     *
     * WARNING: Be extremely cautious when depositing tokens that do not strictly adhere to ERC20 standards.
     * Tokens that diverge significantly from ERC20 norms can cause unexpected behavior in token balances for
     * that strategy, e.g. ERC-777 tokens allowing cross-contract reentrancy.
     */
    function depositIntoStrategyWithSignature(
        IStrategy strategy,
        IERC20 token,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    ) external returns (uint256 depositShares);

    /**
     * @notice Burns Strategy shares for the given strategy by calling into the strategy to transfer
     * to the default burn address.
     * @param strategy The strategy to burn shares in.
     */
    function burnShares(
        IStrategy strategy
    ) external;

    /**
     * @notice Owner-only function to change the `strategyWhitelister` address.
     * @param newStrategyWhitelister new address for the `strategyWhitelister`.
     */
    function setStrategyWhitelister(
        address newStrategyWhitelister
    ) external;

    /**
     * @notice Owner-only function that adds the provided Strategies to the 'whitelist' of strategies that stakers can deposit into
     * @param strategiesToWhitelist Strategies that will be added to the `strategyIsWhitelistedForDeposit` mapping (if they aren't in it already)
     */
    function addStrategiesToDepositWhitelist(
        IStrategy[] calldata strategiesToWhitelist
    ) external;

    /**
     * @notice Owner-only function that removes the provided Strategies from the 'whitelist' of strategies that stakers can deposit into
     * @param strategiesToRemoveFromWhitelist Strategies that will be removed to the `strategyIsWhitelistedForDeposit` mapping (if they are in it)
     */
    function removeStrategiesFromDepositWhitelist(
        IStrategy[] calldata strategiesToRemoveFromWhitelist
    ) external;

    /// @notice Returns bool for whether or not `strategy` is whitelisted for deposit
    function strategyIsWhitelistedForDeposit(
        IStrategy strategy
    ) external view returns (bool);

    /**
     * @notice Get all details on the staker's deposits and corresponding shares
     * @return (staker's strategies, shares in these strategies)
     */
    function getDeposits(
        address staker
    ) external view returns (IStrategy[] memory, uint256[] memory);

    function getStakerStrategyList(
        address staker
    ) external view returns (IStrategy[] memory);

    /// @notice Simple getter function that returns `stakerStrategyList[staker].length`.
    function stakerStrategyListLength(
        address staker
    ) external view returns (uint256);

    /// @notice Returns the current shares of `user` in `strategy`
    function stakerDepositShares(address user, IStrategy strategy) external view returns (uint256 shares);

    /// @notice Returns the single, central Delegation contract of EigenLayer
    function delegation() external view returns (IDelegationManager);

    /// @notice Returns the address of the `strategyWhitelister`
    function strategyWhitelister() external view returns (address);

    /// @notice Returns the burnable shares of a strategy
    function getBurnableShares(
        IStrategy strategy
    ) external view returns (uint256);

    /**
     * @notice Gets every strategy with burnable shares and the amount of burnable shares in each said strategy
     *
     * WARNING: This operation can copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Users should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function getStrategiesWithBurnableShares() external view returns (address[] memory, uint256[] memory);

    /**
     * @param staker The address of the staker.
     * @param strategy The strategy to deposit into.
     * @param token The token to deposit.
     * @param amount The amount of `token` to deposit.
     * @param nonce The nonce of the staker.
     * @param expiry The expiry of the signature.
     * @return The EIP-712 signable digest hash.
     */
    function calculateStrategyDepositDigestHash(
        address staker,
        IStrategy strategy,
        IERC20 token,
        uint256 amount,
        uint256 nonce,
        uint256 expiry
    ) external view returns (bytes32);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "./IStrategy.sol";
import "./IPauserRegistry.sol";
import "./ISignatureUtilsMixin.sol";
import "../libraries/SlashingLib.sol";

interface IDelegationManagerErrors {
    /// @dev Thrown when caller is neither the StrategyManager or EigenPodManager contract.
    error OnlyStrategyManagerOrEigenPodManager();
    /// @dev Thrown when msg.sender is not the EigenPodManager
    error OnlyEigenPodManager();
    /// @dev Throw when msg.sender is not the AllocationManager
    error OnlyAllocationManager();

    /// Delegation Status

    /// @dev Thrown when an operator attempts to undelegate.
    error OperatorsCannotUndelegate();
    /// @dev Thrown when an account is actively delegated.
    error ActivelyDelegated();
    /// @dev Thrown when an account is not actively delegated.
    error NotActivelyDelegated();
    /// @dev Thrown when `operator` is not a registered operator.
    error OperatorNotRegistered();

    /// Invalid Inputs

    /// @dev Thrown when attempting to execute an action that was not queued.
    error WithdrawalNotQueued();
    /// @dev Thrown when caller cannot undelegate on behalf of a staker.
    error CallerCannotUndelegate();
    /// @dev Thrown when two array parameters have mismatching lengths.
    error InputArrayLengthMismatch();
    /// @dev Thrown when input arrays length is zero.
    error InputArrayLengthZero();

    /// Slashing

    /// @dev Thrown when an operator has been fully slashed(maxMagnitude is 0) for a strategy.
    /// or if the staker has had been natively slashed to the point of their beaconChainScalingFactor equalling 0.
    error FullySlashed();

    /// Signatures

    /// @dev Thrown when attempting to spend a spent eip-712 salt.
    error SaltSpent();

    /// Withdrawal Processing

    /// @dev Thrown when attempting to withdraw before delay has elapsed.
    error WithdrawalDelayNotElapsed();
    /// @dev Thrown when withdrawer is not the current caller.
    error WithdrawerNotCaller();
}

interface IDelegationManagerTypes {
    // @notice Struct used for storing information about a single operator who has registered with EigenLayer
    struct OperatorDetails {
        /// @notice DEPRECATED -- this field is no longer used, payments are handled in RewardsCoordinator.sol
        address __deprecated_earningsReceiver;
        /**
         * @notice Address to verify signatures when a staker wishes to delegate to the operator, as well as controlling "forced undelegations".
         * @dev Signature verification follows these rules:
         * 1) If this address is left as address(0), then any staker will be free to delegate to the operator, i.e. no signature verification will be performed.
         * 2) If this address is an EOA (i.e. it has no code), then we follow standard ECDSA signature verification for delegations to the operator.
         * 3) If this address is a contract (i.e. it has code) then we forward a call to the contract and verify that it returns the correct EIP-1271 "magic value".
         */
        address delegationApprover;
        /// @notice DEPRECATED -- this field is no longer used. An analogous field is the `allocationDelay` stored in the AllocationManager
        uint32 __deprecated_stakerOptOutWindowBlocks;
    }

    /**
     * @notice Abstract struct used in calculating an EIP712 signature for an operator's delegationApprover to approve that a specific staker delegate to the operator.
     * @dev Used in computing the `DELEGATION_APPROVAL_TYPEHASH` and as a reference in the computation of the approverDigestHash in the `_delegate` function.
     */
    struct DelegationApproval {
        // the staker who is delegating
        address staker;
        // the operator being delegated to
        address operator;
        // the operator's provided salt
        bytes32 salt;
        // the expiration timestamp (UTC) of the signature
        uint256 expiry;
    }

    /**
     * @dev A struct representing an existing queued withdrawal. After the withdrawal delay has elapsed, this withdrawal can be completed via `completeQueuedWithdrawal`.
     * A `Withdrawal` is created by the `DelegationManager` when `queueWithdrawals` is called. The `withdrawalRoots` hashes returned by `queueWithdrawals` can be used
     * to fetch the corresponding `Withdrawal` from storage (via `getQueuedWithdrawal`).
     *
     * @param staker The address that queued the withdrawal
     * @param delegatedTo The address that the staker was delegated to at the time the withdrawal was queued. Used to determine if additional slashing occurred before
     * this withdrawal became completable.
     * @param withdrawer The address that will call the contract to complete the withdrawal. Note that this will always equal `staker`; alternate withdrawers are not
     * supported at this time.
     * @param nonce The staker's `cumulativeWithdrawalsQueued` at time of queuing. Used to ensure withdrawals have unique hashes.
     * @param startBlock The block number when the withdrawal was queued.
     * @param strategies The strategies requested for withdrawal when the withdrawal was queued
     * @param scaledShares The staker's deposit shares requested for withdrawal, scaled by the staker's `depositScalingFactor`. Upon completion, these will be
     * scaled by the appropriate slashing factor as of the withdrawal's completable block. The result is what is actually withdrawable.
     */
    struct Withdrawal {
        address staker;
        address delegatedTo;
        address withdrawer;
        uint256 nonce;
        uint32 startBlock;
        IStrategy[] strategies;
        uint256[] scaledShares;
    }

    /**
     * @param strategies The strategies to withdraw from
     * @param depositShares For each strategy, the number of deposit shares to withdraw. Deposit shares can
     * be queried via `getDepositedShares`.
     * NOTE: The number of shares ultimately received when a withdrawal is completed may be lower depositShares
     * if the staker or their delegated operator has experienced slashing.
     * @param __deprecated_withdrawer This field is ignored. The only party that may complete a withdrawal
     * is the staker that originally queued it. Alternate withdrawers are not supported.
     */
    struct QueuedWithdrawalParams {
        IStrategy[] strategies;
        uint256[] depositShares;
        address __deprecated_withdrawer;
    }
}

interface IDelegationManagerEvents is IDelegationManagerTypes {
    // @notice Emitted when a new operator registers in EigenLayer and provides their delegation approver.
    event OperatorRegistered(address indexed operator, address delegationApprover);

    /// @notice Emitted when an operator updates their delegation approver
    event DelegationApproverUpdated(address indexed operator, address newDelegationApprover);

    /**
     * @notice Emitted when @param operator indicates that they are updating their MetadataURI string
     * @dev Note that these strings are *never stored in storage* and are instead purely emitted in events for off-chain indexing
     */
    event OperatorMetadataURIUpdated(address indexed operator, string metadataURI);

    /// @notice Emitted whenever an operator's shares are increased for a given strategy. Note that shares is the delta in the operator's shares.
    event OperatorSharesIncreased(address indexed operator, address staker, IStrategy strategy, uint256 shares);

    /// @notice Emitted whenever an operator's shares are decreased for a given strategy. Note that shares is the delta in the operator's shares.
    event OperatorSharesDecreased(address indexed operator, address staker, IStrategy strategy, uint256 shares);

    /// @notice Emitted when @param staker delegates to @param operator.
    event StakerDelegated(address indexed staker, address indexed operator);

    /// @notice Emitted when @param staker undelegates from @param operator.
    event StakerUndelegated(address indexed staker, address indexed operator);

    /// @notice Emitted when @param staker is undelegated via a call not originating from the staker themself
    event StakerForceUndelegated(address indexed staker, address indexed operator);

    /// @notice Emitted when a staker's depositScalingFactor is updated
    event DepositScalingFactorUpdated(address staker, IStrategy strategy, uint256 newDepositScalingFactor);

    /**
     * @notice Emitted when a new withdrawal is queued.
     * @param withdrawalRoot Is the hash of the `withdrawal`.
     * @param withdrawal Is the withdrawal itself.
     * @param sharesToWithdraw Is an array of the expected shares that were queued for withdrawal corresponding to the strategies in the `withdrawal`.
     */
    event SlashingWithdrawalQueued(bytes32 withdrawalRoot, Withdrawal withdrawal, uint256[] sharesToWithdraw);

    /// @notice Emitted when a queued withdrawal is completed
    event SlashingWithdrawalCompleted(bytes32 withdrawalRoot);

    /// @notice Emitted whenever an operator's shares are slashed for a given strategy
    event OperatorSharesSlashed(address indexed operator, IStrategy strategy, uint256 totalSlashedShares);
}

/**
 * @title DelegationManager
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice  This is the contract for delegation in EigenLayer. The main functionalities of this contract are
 * - enabling anyone to register as an operator in EigenLayer
 * - allowing operators to specify parameters related to stakers who delegate to them
 * - enabling any staker to delegate its stake to the operator of its choice (a given staker can only delegate to a single operator at a time)
 * - enabling a staker to undelegate its assets from the operator it is delegated to (performed as part of the withdrawal process, initiated through the StrategyManager)
 */
interface IDelegationManager is ISignatureUtilsMixin, IDelegationManagerErrors, IDelegationManagerEvents {
    /**
     * @dev Initializes the initial owner and paused status.
     */
    function initialize(address initialOwner, uint256 initialPausedStatus) external;

    /**
     * @notice Registers the caller as an operator in EigenLayer.
     * @param initDelegationApprover is an address that, if set, must provide a signature when stakers delegate
     * to an operator.
     * @param allocationDelay The delay before allocations take effect.
     * @param metadataURI is a URI for the operator's metadata, i.e. a link providing more details on the operator.
     *
     * @dev Once an operator is registered, they cannot 'deregister' as an operator, and they will forever be considered "delegated to themself".
     * @dev This function will revert if the caller is already delegated to an operator.
     * @dev Note that the `metadataURI` is *never stored * and is only emitted in the `OperatorMetadataURIUpdated` event
     */
    function registerAsOperator(
        address initDelegationApprover,
        uint32 allocationDelay,
        string calldata metadataURI
    ) external;

    /**
     * @notice Updates an operator's stored `delegationApprover`.
     * @param operator is the operator to update the delegationApprover for
     * @param newDelegationApprover is the new delegationApprover for the operator
     *
     * @dev The caller must have previously registered as an operator in EigenLayer.
     */
    function modifyOperatorDetails(address operator, address newDelegationApprover) external;

    /**
     * @notice Called by an operator to emit an `OperatorMetadataURIUpdated` event indicating the information has updated.
     * @param operator The operator to update metadata for
     * @param metadataURI The URI for metadata associated with an operator
     * @dev Note that the `metadataURI` is *never stored * and is only emitted in the `OperatorMetadataURIUpdated` event
     */
    function updateOperatorMetadataURI(address operator, string calldata metadataURI) external;

    /**
     * @notice Caller delegates their stake to an operator.
     * @param operator The account (`msg.sender`) is delegating its assets to for use in serving applications built on EigenLayer.
     * @param approverSignatureAndExpiry (optional) Verifies the operator approves of this delegation
     * @param approverSalt (optional) A unique single use value tied to an individual signature.
     * @dev The signature/salt are used ONLY if the operator has configured a delegationApprover.
     * If they have not, these params can be left empty.
     */
    function delegateTo(
        address operator,
        SignatureWithExpiry memory approverSignatureAndExpiry,
        bytes32 approverSalt
    ) external;

    /**
     * @notice Undelegates the staker from their operator and queues a withdrawal for all of their shares
     * @param staker The account to be undelegated
     * @return withdrawalRoots The roots of the newly queued withdrawals, if a withdrawal was queued. Returns
     * an empty array if none was queued.
     *
     * @dev Reverts if the `staker` is also an operator, since operators are not allowed to undelegate from themselves.
     * @dev Reverts if the caller is not the staker, nor the operator who the staker is delegated to, nor the operator's specified "delegationApprover"
     * @dev Reverts if the `staker` is not delegated to an operator
     */
    function undelegate(
        address staker
    ) external returns (bytes32[] memory withdrawalRoots);

    /**
     * @notice Undelegates the staker from their current operator, and redelegates to `newOperator`
     * Queues a withdrawal for all of the staker's withdrawable shares. These shares will only be
     * delegated to `newOperator` AFTER the withdrawal is completed.
     * @dev This method acts like a call to `undelegate`, then `delegateTo`
     * @param newOperator the new operator that will be delegated all assets
     * @dev NOTE: the following 2 params are ONLY checked if `newOperator` has a `delegationApprover`.
     * If not, they can be left empty.
     * @param newOperatorApproverSig A signature from the operator's `delegationApprover`
     * @param approverSalt A unique single use value tied to the approver's signature
     */
    function redelegate(
        address newOperator,
        SignatureWithExpiry memory newOperatorApproverSig,
        bytes32 approverSalt
    ) external returns (bytes32[] memory withdrawalRoots);

    /**
     * @notice Allows a staker to queue a withdrawal of their deposit shares. The withdrawal can be
     * completed after the MIN_WITHDRAWAL_DELAY_BLOCKS via either of the completeQueuedWithdrawal methods.
     *
     * While in the queue, these shares are removed from the staker's balance, as well as from their operator's
     * delegated share balance (if applicable). Note that while in the queue, deposit shares are still subject
     * to slashing. If any slashing has occurred, the shares received may be less than the queued deposit shares.
     *
     * @dev To view all the staker's strategies/deposit shares that can be queued for withdrawal, see `getDepositedShares`
     * @dev To view the current conversion between a staker's deposit shares and withdrawable shares, see `getWithdrawableShares`
     */
    function queueWithdrawals(
        QueuedWithdrawalParams[] calldata params
    ) external returns (bytes32[] memory);

    /**
     * @notice Used to complete a queued withdrawal
     * @param withdrawal The withdrawal to complete
     * @param tokens Array in which the i-th entry specifies the `token` input to the 'withdraw' function of the i-th Strategy in the `withdrawal.strategies` array.
     * @param tokens For each `withdrawal.strategies`, the underlying token of the strategy
     * NOTE: if `receiveAsTokens` is false, the `tokens` array is unused and can be filled with default values. However, `tokens.length` MUST still be equal to `withdrawal.strategies.length`.
     * NOTE: For the `beaconChainETHStrategy`, the corresponding `tokens` value is ignored (can be 0).
     * @param receiveAsTokens If true, withdrawn shares will be converted to tokens and sent to the caller. If false, the caller receives shares that can be delegated to an operator.
     * NOTE: if the caller receives shares and is currently delegated to an operator, the received shares are
     * automatically delegated to the caller's current operator.
     */
    function completeQueuedWithdrawal(
        Withdrawal calldata withdrawal,
        IERC20[] calldata tokens,
        bool receiveAsTokens
    ) external;

    /**
     * @notice Used to complete multiple queued withdrawals
     * @param withdrawals Array of Withdrawals to complete. See `completeQueuedWithdrawal` for the usage of a single Withdrawal.
     * @param tokens Array of tokens for each Withdrawal. See `completeQueuedWithdrawal` for the usage of a single array.
     * @param receiveAsTokens Whether or not to complete each withdrawal as tokens. See `completeQueuedWithdrawal` for the usage of a single boolean.
     * @dev See `completeQueuedWithdrawal` for relevant dev tags
     */
    function completeQueuedWithdrawals(
        Withdrawal[] calldata withdrawals,
        IERC20[][] calldata tokens,
        bool[] calldata receiveAsTokens
    ) external;

    /**
     * @notice Called by a share manager when a staker's deposit share balance in a strategy increases.
     * This method delegates any new shares to an operator (if applicable), and updates the staker's
     * deposit scaling factor regardless.
     * @param staker The address whose deposit shares have increased
     * @param strategy The strategy in which shares have been deposited
     * @param prevDepositShares The number of deposit shares the staker had in the strategy prior to the increase
     * @param addedShares The number of deposit shares added by the staker
     *
     * @dev Note that if the either the staker's current operator has been slashed 100% for `strategy`, OR the
     * staker has been slashed 100% on the beacon chain such that the calculated slashing factor is 0, this
     * method WILL REVERT.
     */
    function increaseDelegatedShares(
        address staker,
        IStrategy strategy,
        uint256 prevDepositShares,
        uint256 addedShares
    ) external;

    /**
     * @notice If the staker is delegated, decreases its operator's shares in response to
     * a decrease in balance in the beaconChainETHStrategy
     * @param staker the staker whose operator's balance will be decreased
     * @param curDepositShares the current deposit shares held by the staker
     * @param beaconChainSlashingFactorDecrease the amount that the staker's beaconChainSlashingFactor has decreased by
     * @dev Note: `beaconChainSlashingFactorDecrease` are assumed to ALWAYS be < 1 WAD.
     * These invariants are maintained in the EigenPodManager.
     */
    function decreaseDelegatedShares(
        address staker,
        uint256 curDepositShares,
        uint64 beaconChainSlashingFactorDecrease
    ) external;

    /**
     * @notice Decreases the operators shares in storage after a slash and increases the burnable shares by calling
     * into either the StrategyManager or EigenPodManager (if the strategy is beaconChainETH).
     * @param operator The operator to decrease shares for
     * @param strategy The strategy to decrease shares for
     * @param prevMaxMagnitude the previous maxMagnitude of the operator
     * @param newMaxMagnitude the new maxMagnitude of the operator
     * @dev Callable only by the AllocationManager
     * @dev Note: Assumes `prevMaxMagnitude <= newMaxMagnitude`. This invariant is maintained in
     * the AllocationManager.
     */
    function slashOperatorShares(
        address operator,
        IStrategy strategy,
        uint64 prevMaxMagnitude,
        uint64 newMaxMagnitude
    ) external;

    /**
     *
     *                         VIEW FUNCTIONS
     *
     */

    /**
     * @notice returns the address of the operator that `staker` is delegated to.
     * @notice Mapping: staker => operator whom the staker is currently delegated to.
     * @dev Note that returning address(0) indicates that the staker is not actively delegated to any operator.
     */
    function delegatedTo(
        address staker
    ) external view returns (address);

    /**
     * @notice Mapping: delegationApprover => 32-byte salt => whether or not the salt has already been used by the delegationApprover.
     * @dev Salts are used in the `delegateTo` function. Note that this function only processes the delegationApprover's
     * signature + the provided salt if the operator being delegated to has specified a nonzero address as their `delegationApprover`.
     */
    function delegationApproverSaltIsSpent(address _delegationApprover, bytes32 salt) external view returns (bool);

    /// @notice Mapping: staker => cumulative number of queued withdrawals they have ever initiated.
    /// @dev This only increments (doesn't decrement), and is used to help ensure that otherwise identical withdrawals have unique hashes.
    function cumulativeWithdrawalsQueued(
        address staker
    ) external view returns (uint256);

    /**
     * @notice Returns 'true' if `staker` *is* actively delegated, and 'false' otherwise.
     */
    function isDelegated(
        address staker
    ) external view returns (bool);

    /**
     * @notice Returns true is an operator has previously registered for delegation.
     */
    function isOperator(
        address operator
    ) external view returns (bool);

    /**
     * @notice Returns the delegationApprover account for an operator
     */
    function delegationApprover(
        address operator
    ) external view returns (address);

    /**
     * @notice Returns the shares that an operator has delegated to them in a set of strategies
     * @param operator the operator to get shares for
     * @param strategies the strategies to get shares for
     */
    function getOperatorShares(
        address operator,
        IStrategy[] memory strategies
    ) external view returns (uint256[] memory);

    /**
     * @notice Returns the shares that a set of operators have delegated to them in a set of strategies
     * @param operators the operators to get shares for
     * @param strategies the strategies to get shares for
     */
    function getOperatorsShares(
        address[] memory operators,
        IStrategy[] memory strategies
    ) external view returns (uint256[][] memory);

    /**
     * @notice Returns amount of withdrawable shares from an operator for a strategy that is still in the queue
     * and therefore slashable. Note that the *actual* slashable amount could be less than this value as this doesn't account
     * for amounts that have already been slashed. This assumes that none of the shares have been slashed.
     * @param operator the operator to get shares for
     * @param strategy the strategy to get shares for
     * @return the amount of shares that are slashable in the withdrawal queue for an operator and a strategy
     */
    function getSlashableSharesInQueue(address operator, IStrategy strategy) external view returns (uint256);

    /**
     * @notice Given a staker and a set of strategies, return the shares they can queue for withdrawal and the
     * corresponding depositShares.
     * This value depends on which operator the staker is delegated to.
     * The shares amount returned is the actual amount of Strategy shares the staker would receive (subject
     * to each strategy's underlying shares to token ratio).
     */
    function getWithdrawableShares(
        address staker,
        IStrategy[] memory strategies
    ) external view returns (uint256[] memory withdrawableShares, uint256[] memory depositShares);

    /**
     * @notice Returns the number of shares in storage for a staker and all their strategies
     */
    function getDepositedShares(
        address staker
    ) external view returns (IStrategy[] memory, uint256[] memory);

    /**
     * @notice Returns the scaling factor applied to a staker's deposits for a given strategy
     */
    function depositScalingFactor(address staker, IStrategy strategy) external view returns (uint256);

    /**
     * @notice Returns the Withdrawal and corresponding shares associated with a `withdrawalRoot`
     * @param withdrawalRoot The hash identifying the queued withdrawal
     * @return withdrawal The withdrawal details
     * @return shares Array of shares corresponding to each strategy in the withdrawal
     * @dev The shares are what a user would receive from completing a queued withdrawal, assuming all slashings are applied
     * @dev Withdrawals queued before the slashing release cannot be queried with this method
     */
    function getQueuedWithdrawal(
        bytes32 withdrawalRoot
    ) external view returns (Withdrawal memory withdrawal, uint256[] memory shares);

    /**
     * @notice Returns all queued withdrawals and their corresponding shares for a staker.
     * @param staker The address of the staker to query withdrawals for.
     * @return withdrawals Array of Withdrawal structs containing details about each queued withdrawal.
     * @return shares 2D array of shares, where each inner array corresponds to the strategies in the withdrawal.
     * @dev The shares are what a user would receive from completing a queued withdrawal, assuming all slashings are applied.
     */
    function getQueuedWithdrawals(
        address staker
    ) external view returns (Withdrawal[] memory withdrawals, uint256[][] memory shares);

    /// @notice Returns a list of queued withdrawal roots for the `staker`.
    /// NOTE that this only returns withdrawals queued AFTER the slashing release.
    function getQueuedWithdrawalRoots(
        address staker
    ) external view returns (bytes32[] memory);

    /**
     * @notice Converts shares for a set of strategies to deposit shares, likely in order to input into `queueWithdrawals`.
     * This function will revert from a division by 0 error if any of the staker's strategies have a slashing factor of 0.
     * @param staker the staker to convert shares for
     * @param strategies the strategies to convert shares for
     * @param withdrawableShares the shares to convert
     * @return the deposit shares
     * @dev will be a few wei off due to rounding errors
     */
    function convertToDepositShares(
        address staker,
        IStrategy[] memory strategies,
        uint256[] memory withdrawableShares
    ) external view returns (uint256[] memory);

    /// @notice Returns the keccak256 hash of `withdrawal`.
    function calculateWithdrawalRoot(
        Withdrawal memory withdrawal
    ) external pure returns (bytes32);

    /**
     * @notice Calculates the digest hash to be signed by the operator's delegationApprove and used in the `delegateTo` function.
     * @param staker The account delegating their stake
     * @param operator The account receiving delegated stake
     * @param _delegationApprover the operator's `delegationApprover` who will be signing the delegationHash (in general)
     * @param approverSalt A unique and single use value associated with the approver signature.
     * @param expiry Time after which the approver's signature becomes invalid
     */
    function calculateDelegationApprovalDigestHash(
        address staker,
        address operator,
        address _delegationApprover,
        bytes32 approverSalt,
        uint256 expiry
    ) external view returns (bytes32);

    /// @notice return address of the beaconChainETHStrategy
    function beaconChainETHStrategy() external view returns (IStrategy);

    /**
     * @notice Returns the minimum withdrawal delay in blocks to pass for withdrawals queued to be completable.
     * Also applies to legacy withdrawals so any withdrawals not completed prior to the slashing upgrade will be subject
     * to this longer delay.
     * @dev Backwards-compatible interface to return the internal `MIN_WITHDRAWAL_DELAY_BLOCKS` value
     * @dev Previous value in storage was deprecated. See `__deprecated_minWithdrawalDelayBlocks`
     */
    function minWithdrawalDelayBlocks() external view returns (uint32);

    /// @notice The EIP-712 typehash for the DelegationApproval struct used by the contract
    function DELEGATION_APPROVAL_TYPEHASH() external view returns (bytes32);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libraries/SlashingLib.sol";
import "./ISemVerMixin.sol";

interface IStrategyErrors {
    /// @dev Thrown when called by an account that is not strategy manager.
    error OnlyStrategyManager();
    /// @dev Thrown when new shares value is zero.
    error NewSharesZero();
    /// @dev Thrown when total shares exceeds max.
    error TotalSharesExceedsMax();
    /// @dev Thrown when amount shares is greater than total shares.
    error WithdrawalAmountExceedsTotalDeposits();
    /// @dev Thrown when attempting an action with a token that is not accepted.
    error OnlyUnderlyingToken();

    /// StrategyBaseWithTVLLimits

    /// @dev Thrown when `maxPerDeposit` exceeds max.
    error MaxPerDepositExceedsMax();
    /// @dev Thrown when balance exceeds max total deposits.
    error BalanceExceedsMaxTotalDeposits();
}

interface IStrategyEvents {
    /**
     * @notice Used to emit an event for the exchange rate between 1 share and underlying token in a strategy contract
     * @param rate is the exchange rate in wad 18 decimals
     * @dev Tokens that do not have 18 decimals must have offchain services scale the exchange rate by the proper magnitude
     */
    event ExchangeRateEmitted(uint256 rate);

    /**
     * Used to emit the underlying token and its decimals on strategy creation
     * @notice token
     * @param token is the ERC20 token of the strategy
     * @param decimals are the decimals of the ERC20 token in the strategy
     */
    event StrategyTokenSet(IERC20 token, uint8 decimals);
}

/**
 * @title Minimal interface for an `Strategy` contract.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice Custom `Strategy` implementations may expand extensively on this interface.
 */
interface IStrategy is IStrategyErrors, IStrategyEvents, ISemVerMixin {
    /**
     * @notice Used to deposit tokens into this Strategy
     * @param token is the ERC20 token being deposited
     * @param amount is the amount of token being deposited
     * @dev This function is only callable by the strategyManager contract. It is invoked inside of the strategyManager's
     * `depositIntoStrategy` function, and individual share balances are recorded in the strategyManager as well.
     * @return newShares is the number of new shares issued at the current exchange ratio.
     */
    function deposit(IERC20 token, uint256 amount) external returns (uint256);

    /**
     * @notice Used to withdraw tokens from this Strategy, to the `recipient`'s address
     * @param recipient is the address to receive the withdrawn funds
     * @param token is the ERC20 token being transferred out
     * @param amountShares is the amount of shares being withdrawn
     * @dev This function is only callable by the strategyManager contract. It is invoked inside of the strategyManager's
     * other functions, and individual share balances are recorded in the strategyManager as well.
     */
    function withdraw(address recipient, IERC20 token, uint256 amountShares) external;

    /**
     * @notice Used to convert a number of shares to the equivalent amount of underlying tokens for this strategy.
     * For a staker using this function and trying to calculate the amount of underlying tokens they have in total they
     * should input into `amountShares` their withdrawable shares read from the `DelegationManager` contract.
     * @notice In contrast to `sharesToUnderlyingView`, this function **may** make state modifications
     * @param amountShares is the amount of shares to calculate its conversion into the underlying token
     * @return The amount of underlying tokens corresponding to the input `amountShares`
     * @dev Implementation for these functions in particular may vary significantly for different strategies
     */
    function sharesToUnderlying(
        uint256 amountShares
    ) external returns (uint256);

    /**
     * @notice Used to convert an amount of underlying tokens to the equivalent amount of shares in this strategy.
     * @notice In contrast to `underlyingToSharesView`, this function **may** make state modifications
     * @param amountUnderlying is the amount of `underlyingToken` to calculate its conversion into strategy shares
     * @return The amount of shares corresponding to the input `amountUnderlying`.  This is used as deposit shares
     * in the `StrategyManager` contract.
     * @dev Implementation for these functions in particular may vary significantly for different strategies
     */
    function underlyingToShares(
        uint256 amountUnderlying
    ) external returns (uint256);

    /**
     * @notice convenience function for fetching the current underlying value of all of the `user`'s shares in
     * this strategy. In contrast to `userUnderlyingView`, this function **may** make state modifications
     */
    function userUnderlying(
        address user
    ) external returns (uint256);

    /**
     * @notice convenience function for fetching the current total shares of `user` in this strategy, by
     * querying the `strategyManager` contract
     */
    function shares(
        address user
    ) external view returns (uint256);

    /**
     * @notice Used to convert a number of shares to the equivalent amount of underlying tokens for this strategy.
     * For a staker using this function and trying to calculate the amount of underlying tokens they have in total they
     * should input into `amountShares` their withdrawable shares read from the `DelegationManager` contract.
     * @notice In contrast to `sharesToUnderlying`, this function guarantees no state modifications
     * @param amountShares is the amount of shares to calculate its conversion into the underlying token
     * @return The amount of underlying tokens corresponding to the input `amountShares`
     * @dev Implementation for these functions in particular may vary significantly for different strategies
     */
    function sharesToUnderlyingView(
        uint256 amountShares
    ) external view returns (uint256);

    /**
     * @notice Used to convert an amount of underlying tokens to the equivalent amount of shares in this strategy.
     * @notice In contrast to `underlyingToShares`, this function guarantees no state modifications
     * @param amountUnderlying is the amount of `underlyingToken` to calculate its conversion into strategy shares
     * @return The amount of shares corresponding to the input `amountUnderlying`. This is used as deposit shares
     * in the `StrategyManager` contract.
     * @dev Implementation for these functions in particular may vary significantly for different strategies
     */
    function underlyingToSharesView(
        uint256 amountUnderlying
    ) external view returns (uint256);

    /**
     * @notice convenience function for fetching the current underlying value of all of the `user`'s shares in
     * this strategy. In contrast to `userUnderlying`, this function guarantees no state modifications
     */
    function userUnderlyingView(
        address user
    ) external view returns (uint256);

    /// @notice The underlying token for shares in this Strategy
    function underlyingToken() external view returns (IERC20);

    /// @notice The total number of extant shares in this Strategy
    function totalShares() external view returns (uint256);

    /// @notice Returns either a brief string explaining the strategy's goal & purpose, or a link to metadata that explains in more detail.
    function explanation() external view returns (string memory);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "./ISemVerMixin.sol";

interface ISignatureUtilsMixinErrors {
    /// @notice Thrown when a signature is invalid.
    error InvalidSignature();
    /// @notice Thrown when a signature has expired.
    error SignatureExpired();
}

interface ISignatureUtilsMixinTypes {
    /// @notice Struct that bundles together a signature and an expiration time for the signature.
    /// @dev Used primarily for stack management.
    struct SignatureWithExpiry {
        // the signature itself, formatted as a single bytes object
        bytes signature;
        // the expiration timestamp (UTC) of the signature
        uint256 expiry;
    }

    /// @notice Struct that bundles together a signature, a salt for uniqueness, and an expiration time for the signature.
    /// @dev Used primarily for stack management.
    struct SignatureWithSaltAndExpiry {
        // the signature itself, formatted as a single bytes object
        bytes signature;
        // the salt used to generate the signature
        bytes32 salt;
        // the expiration timestamp (UTC) of the signature
        uint256 expiry;
    }
}

/**
 * @title The interface for common signature utilities.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 */
interface ISignatureUtilsMixin is ISignatureUtilsMixinErrors, ISignatureUtilsMixinTypes, ISemVerMixin {
    /// @notice Computes the EIP-712 domain separator used for signature validation.
    /// @dev The domain separator is computed according to EIP-712 specification, using:
    ///      - The hardcoded name "EigenLayer"
    ///      - The contract's version string
    ///      - The current chain ID
    ///      - This contract's address
    /// @return The 32-byte domain separator hash used in EIP-712 structured data signing.
    /// @dev See https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator.
    function domainSeparator() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStrategyManager} from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";

import {IStakerNode} from "./IStakerNode.sol";
import {ILiquidTokenManager} from "../interfaces/ILiquidTokenManager.sol";

/// @title IStakerNodeCoordinator Interface
/// @notice Interface for the StakerNodeCoordinator contract
interface IStakerNodeCoordinator {
    // ============================================================================
    // STRUCTS
    // ============================================================================

    /// @notice Initialization parameters for StakerNodeCoordinator
    struct Init {
        ILiquidTokenManager liquidTokenManager;
        IDelegationManager delegationManager;
        IStrategyManager strategyManager;
        uint256 maxNodes;
        address initialOwner;
        address pauser;
        address stakerNodeCreator;
        address stakerNodesDelegator;
        address stakerNodeImplementation;
    }

    // ============================================================================
    // EVENTS
    // ============================================================================

    /// @notice Emitted when a new staker node is created
    event NodeCreated(uint256 indexed nodeId, IStakerNode indexed node, address indexed creator);

    /// @notice Emitted when the staker node implementation is changed
    event NodeImplementationChanged(
        address indexed upgradeableBeaconAddress,
        address indexed implementationContract,
        bool isInitialRegistration
    );

    /// @notice Emitted when the maximum number of nodes is updated
    event MaxNodesUpdated(uint256 oldMaxNodes, uint256 newMaxNodes, address indexed updater);

    /// @notice Error thrown when trying to set maxNodes lower than the current number of nodes0
    error MaxNodesLowerThanCurrent(uint256 currentNodeCount, uint256 newMaxNodes);

    /// @notice Emitted when a node is initialized
    event NodeInitialized(address indexed nodeAddress, uint64 initializedVersion, uint256 indexed nodeId);

    // ============================================================================
    // CUSTOM ERRORS
    // ============================================================================

    /// @notice Error for zero address
    error ZeroAddress();

    /// @notice Error for zero amount
    error ZeroAmount();

    /// @notice Error for unsupported asset
    error UnsupportedAsset(IERC20 asset);

    /// @notice Error for unauthorized access
    error Unauthorized();

    /// @notice Error for insufficient funds
    error InsufficientFunds();

    /// @notice Error when contract is paused
    error Paused();

    /// @notice Error when attempting to use a non-contract address as implementation
    error NotAContract();

    /// @notice Error when beacon implementation already exists
    error BeaconImplementationAlreadyExists();

    /// @notice Error when no beacon implementation exists
    error NoBeaconImplementationExists();

    /// @notice Error when maximum number of staker nodes is reached
    error TooManyStakerNodes(uint256 maxNodes);

    /// @notice Error when node ID is out of range
    error NodeIdOutOfRange(uint256 nodeId);

    /// @notice Error when node is already registered
    error NodeAlreadyRegistered(address nodeAddress);

    /// @notice Error when caller is not the owner
    error NotOwner();

    // ============================================================================
    // FUNCTIONS
    // ============================================================================

    /// @notice Initializes the StakerNodeCoordinator contract
    /// @param init Initialization parameters
    function initialize(Init calldata init) external;

    /// @notice Creates a new staker node
    /// @return The IStakerNode interface of the newly created staker node
    function createStakerNode() external returns (IStakerNode);

    /// @notice Upgrades the staker node implementation
    /// @param _implementationContract Address of the new implementation contract
    function upgradeStakerNodeImplementation(address _implementationContract) external;

    /// @notice Sets the maximum number of staker nodes
    /// @param _maxNodes New maximum number of nodes
    function setMaxNodes(uint256 _maxNodes) external;

    /// @notice Retrieves all staker nodes
    /// @return An array of all IStakerNode interfaces
    function getAllNodes() external view returns (IStakerNode[] memory);

    /// @notice Gets the total number of staker nodes
    /// @return The number of staker nodes
    function getStakerNodesCount() external view returns (uint256);

    /// @notice Retrieves a staker node by its ID
    /// @param nodeId The ID of the staker node
    /// @return The IStakerNode interface of the staker node
    function getNodeById(uint256 nodeId) external view returns (IStakerNode);

    /// @notice Checks if an address has the STAKER_NODES_DELEGATOR_ROLE
    /// @param _address Address to check
    /// @return True if the address has the role, false otherwise
    function hasStakerNodeDelegatorRole(address _address) external view returns (bool);

    /// @notice Checks if a caller is the liquid token manager
    /// @param caller Address to check
    /// @return True if the caller is the liquid token manager, false otherwise
    function hasLiquidTokenManagerRole(address caller) external view returns (bool);

    /// @notice Gets the delegation manager contract
    /// @return The IDelegationManager interface
    function delegationManager() external view returns (IDelegationManager);

    /// @notice Gets the strategy manager contract
    /// @return The IStrategyManager interface
    function strategyManager() external view returns (IStrategyManager);

    /// @notice Gets the liquid token manager contract
    /// @return The ILiquidTokenManager interface
    function liquidTokenManager() external view returns (ILiquidTokenManager);

    /// @notice Gets the maximum number of nodes allowed
    /// @return The maximum number of nodes
    function maxNodes() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MathUpgradeable {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1, "Math: mulDiv overflow");

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMathUpgradeable {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../libraries/SlashingLib.sol";
import "./IStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Interface for a `IShareManager` contract.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice This contract is used by the DelegationManager as a unified interface to interact with the EigenPodManager and StrategyManager
 */
interface IShareManager {
    /// @notice Used by the DelegationManager to remove a Staker's shares from a particular strategy when entering the withdrawal queue
    /// @dev strategy must be beaconChainETH when talking to the EigenPodManager
    /// @return updatedShares the staker's deposit shares after decrement
    function removeDepositShares(
        address staker,
        IStrategy strategy,
        uint256 depositSharesToRemove
    ) external returns (uint256);

    /// @notice Used by the DelegationManager to award a Staker some shares that have passed through the withdrawal queue
    /// @dev strategy must be beaconChainETH when talking to the EigenPodManager
    /// @return existingDepositShares the shares the staker had before any were added
    /// @return addedShares the new shares added to the staker's balance
    function addShares(address staker, IStrategy strategy, uint256 shares) external returns (uint256, uint256);

    /// @notice Used by the DelegationManager to convert deposit shares to tokens and send them to a staker
    /// @dev strategy must be beaconChainETH when talking to the EigenPodManager
    /// @dev token is not validated when talking to the EigenPodManager
    function withdrawSharesAsTokens(address staker, IStrategy strategy, IERC20 token, uint256 shares) external;

    /// @notice Returns the current shares of `user` in `strategy`
    /// @dev strategy must be beaconChainETH when talking to the EigenPodManager
    /// @dev returns 0 if the user has negative shares
    function stakerDepositShares(address user, IStrategy strategy) external view returns (uint256 depositShares);

    /**
     * @notice Increase the amount of burnable shares for a given Strategy. This is called by the DelegationManager
     * when an operator is slashed in EigenLayer.
     * @param strategy The strategy to burn shares in.
     * @param addedSharesToBurn The amount of added shares to burn.
     * @dev This function is only called by the DelegationManager when an operator is slashed.
     */
    function increaseBurnableShares(IStrategy strategy, uint256 addedSharesToBurn) external;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import "./IETHPOSDeposit.sol";
import "./IStrategyManager.sol";
import "./IEigenPod.sol";
import "./IShareManager.sol";
import "./IPausable.sol";
import "./IStrategy.sol";
import "./ISemVerMixin.sol";

interface IEigenPodManagerErrors {
    /// @dev Thrown when caller is not a EigenPod.
    error OnlyEigenPod();
    /// @dev Thrown when caller is not DelegationManager.
    error OnlyDelegationManager();
    /// @dev Thrown when caller already has an EigenPod.
    error EigenPodAlreadyExists();
    /// @dev Thrown when shares is not a multiple of gwei.
    error SharesNotMultipleOfGwei();
    /// @dev Thrown when shares would result in a negative integer.
    error SharesNegative();
    /// @dev Thrown when the strategy is not the beaconChainETH strategy.
    error InvalidStrategy();
    /// @dev Thrown when the pods shares are negative and a beacon chain balance update is attempted.
    /// The podOwner should complete legacy withdrawal first.
    error LegacyWithdrawalsNotCompleted();
    /// @dev Thrown when caller is not the proof timestamp setter
    error OnlyProofTimestampSetter();
}

interface IEigenPodManagerEvents {
    /// @notice Emitted to notify the deployment of an EigenPod
    event PodDeployed(address indexed eigenPod, address indexed podOwner);

    /// @notice Emitted to notify a deposit of beacon chain ETH recorded in the strategy manager
    event BeaconChainETHDeposited(address indexed podOwner, uint256 amount);

    /// @notice Emitted when the balance of an EigenPod is updated
    event PodSharesUpdated(address indexed podOwner, int256 sharesDelta);

    /// @notice Emitted every time the total shares of a pod are updated
    event NewTotalShares(address indexed podOwner, int256 newTotalShares);

    /// @notice Emitted when a withdrawal of beacon chain ETH is completed
    event BeaconChainETHWithdrawalCompleted(
        address indexed podOwner,
        uint256 shares,
        uint96 nonce,
        address delegatedAddress,
        address withdrawer,
        bytes32 withdrawalRoot
    );

    /// @notice Emitted when a staker's beaconChainSlashingFactor is updated
    event BeaconChainSlashingFactorDecreased(
        address staker, uint64 prevBeaconChainSlashingFactor, uint64 newBeaconChainSlashingFactor
    );

    /// @notice Emitted when an operator is slashed and shares to be burned are increased
    event BurnableETHSharesIncreased(uint256 shares);

    /// @notice Emitted when the Pectra fork timestamp is updated
    event PectraForkTimestampSet(uint64 newPectraForkTimestamp);

    /// @notice Emitted when the proof timestamp setter is updated
    event ProofTimestampSetterSet(address newProofTimestampSetter);
}

interface IEigenPodManagerTypes {
    /**
     * @notice The amount of beacon chain slashing experienced by a pod owner as a proportion of WAD
     * @param isSet whether the slashingFactor has ever been updated. Used to distinguish between
     * a value of "0" and an uninitialized value.
     * @param slashingFactor the proportion of the pod owner's balance that has been decreased due to
     * slashing or other beacon chain balance decreases.
     * @dev NOTE: if !isSet, `slashingFactor` should be treated as WAD. `slashingFactor` is monotonically
     * decreasing and can hit 0 if fully slashed.
     */
    struct BeaconChainSlashingFactor {
        bool isSet;
        uint64 slashingFactor;
    }
}

/**
 * @title Interface for factory that creates and manages solo staking pods that have their withdrawal credentials pointed to EigenLayer.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 */
interface IEigenPodManager is
    IEigenPodManagerErrors,
    IEigenPodManagerEvents,
    IEigenPodManagerTypes,
    IShareManager,
    IPausable,
    ISemVerMixin
{
    /**
     * @notice Creates an EigenPod for the sender.
     * @dev Function will revert if the `msg.sender` already has an EigenPod.
     * @dev Returns EigenPod address
     */
    function createPod() external returns (address);

    /**
     * @notice Stakes for a new beacon chain validator on the sender's EigenPod.
     * Also creates an EigenPod for the sender if they don't have one already.
     * @param pubkey The 48 bytes public key of the beacon chain validator.
     * @param signature The validator's signature of the deposit data.
     * @param depositDataRoot The root/hash of the deposit data for the validator's deposit.
     */
    function stake(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) external payable;

    /**
     * @notice Adds any positive share delta to the pod owner's deposit shares, and delegates them to the pod
     * owner's operator (if applicable). A negative share delta does NOT impact the pod owner's deposit shares,
     * but will reduce their beacon chain slashing factor and delegated shares accordingly.
     * @param podOwner is the pod owner whose balance is being updated.
     * @param prevRestakedBalanceWei is the total amount restaked through the pod before the balance update, including
     * any amount currently in the withdrawal queue.
     * @param balanceDeltaWei is the amount the balance changed
     * @dev Callable only by the podOwner's EigenPod contract.
     * @dev Reverts if `sharesDelta` is not a whole Gwei amount
     */
    function recordBeaconChainETHBalanceUpdate(
        address podOwner,
        uint256 prevRestakedBalanceWei,
        int256 balanceDeltaWei
    ) external;

    /// @notice Sets the address that can set proof timestamps
    function setProofTimestampSetter(
        address newProofTimestampSetter
    ) external;

    /// @notice Sets the Pectra fork timestamp, only callable by `proofTimestampSetter`
    function setPectraForkTimestamp(
        uint64 timestamp
    ) external;

    /// @notice Returns the address of the `podOwner`'s EigenPod if it has been deployed.
    function ownerToPod(
        address podOwner
    ) external view returns (IEigenPod);

    /// @notice Returns the address of the `podOwner`'s EigenPod (whether it is deployed yet or not).
    function getPod(
        address podOwner
    ) external view returns (IEigenPod);

    /// @notice The ETH2 Deposit Contract
    function ethPOS() external view returns (IETHPOSDeposit);

    /// @notice Beacon proxy to which the EigenPods point
    function eigenPodBeacon() external view returns (IBeacon);

    /// @notice Returns 'true' if the `podOwner` has created an EigenPod, and 'false' otherwise.
    function hasPod(
        address podOwner
    ) external view returns (bool);

    /// @notice Returns the number of EigenPods that have been created
    function numPods() external view returns (uint256);

    /**
     * @notice Mapping from Pod owner owner to the number of shares they have in the virtual beacon chain ETH strategy.
     * @dev The share amount can become negative. This is necessary to accommodate the fact that a pod owner's virtual beacon chain ETH shares can
     * decrease between the pod owner queuing and completing a withdrawal.
     * When the pod owner's shares would otherwise increase, this "deficit" is decreased first _instead_.
     * Likewise, when a withdrawal is completed, this "deficit" is decreased and the withdrawal amount is decreased; We can think of this
     * as the withdrawal "paying off the deficit".
     */
    function podOwnerDepositShares(
        address podOwner
    ) external view returns (int256);

    /// @notice returns canonical, virtual beaconChainETH strategy
    function beaconChainETHStrategy() external view returns (IStrategy);

    /**
     * @notice Returns the historical sum of proportional balance decreases a pod owner has experienced when
     * updating their pod's balance.
     */
    function beaconChainSlashingFactor(
        address staker
    ) external view returns (uint64);

    /// @notice Returns the accumulated amount of beacon chain ETH Strategy shares
    function burnableETHShares() external view returns (uint256);

    /// @notice Returns the timestamp of the Pectra hard fork
    /// @dev Specifically, this returns the timestamp of the first non-missed slot at or after the Pectra hard fork
    function pectraForkTimestamp() external view returns (uint64);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @title ISemVerMixin
/// @notice A mixin interface that provides semantic versioning functionality.
/// @dev Follows SemVer 2.0.0 specification (https://semver.org/)
interface ISemVerMixin {
    /// @notice Returns the semantic version string of the contract.
    /// @return The version string in SemVer format (e.g., "v1.1.1")
    function version() external view returns (string memory);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

/**
 * @title Interface for the `PauserRegistry` contract.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 */
interface IPauserRegistry {
    error OnlyUnpauser();
    error InputAddressZero();

    event PauserStatusChanged(address pauser, bool canPause);

    event UnpauserChanged(address previousUnpauser, address newUnpauser);

    /// @notice Mapping of addresses to whether they hold the pauser role.
    function isPauser(
        address pauser
    ) external view returns (bool);

    /// @notice Unique address that holds the unpauser role. Capable of changing *both* the pauser and unpauser addresses.
    function unpauser() external view returns (address);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin-upgrades/contracts/utils/math/SafeCastUpgradeable.sol";

/// @dev All scaling factors have `1e18` as an initial/default value. This value is represented
/// by the constant `WAD`, which is used to preserve precision with uint256 math.
///
/// When applying scaling factors, they are typically multiplied/divided by `WAD`, allowing this
/// constant to act as a "1" in mathematical formulae.
uint64 constant WAD = 1e18;

/*
 * There are 2 types of shares:
 *      1. deposit shares
 *          - These can be converted to an amount of tokens given a strategy
 *              - by calling `sharesToUnderlying` on the strategy address (they're already tokens 
 *              in the case of EigenPods)
 *          - These live in the storage of the EigenPodManager and individual StrategyManager strategies 
 *      2. withdrawable shares
 *          - For a staker, this is the amount of shares that they can withdraw
 *          - For an operator, the shares delegated to them are equal to the sum of their stakers'
 *            withdrawable shares
 *
 * Along with a slashing factor, the DepositScalingFactor is used to convert between the two share types.
 */
struct DepositScalingFactor {
    uint256 _scalingFactor;
}

using SlashingLib for DepositScalingFactor global;

library SlashingLib {
    using Math for uint256;
    using SlashingLib for uint256;
    using SafeCastUpgradeable for uint256;

    // WAD MATH

    function mulWad(uint256 x, uint256 y) internal pure returns (uint256) {
        return x.mulDiv(y, WAD);
    }

    function divWad(uint256 x, uint256 y) internal pure returns (uint256) {
        return x.mulDiv(WAD, y);
    }

    /**
     * @notice Used explicitly for calculating slashed magnitude, we want to ensure even in the
     * situation where an operator is slashed several times and precision has been lost over time,
     * an incoming slashing request isn't rounded down to 0 and an operator is able to avoid slashing penalties.
     */
    function mulWadRoundUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return x.mulDiv(y, WAD, Math.Rounding.Up);
    }

    // GETTERS

    function scalingFactor(
        DepositScalingFactor memory dsf
    ) internal pure returns (uint256) {
        return dsf._scalingFactor == 0 ? WAD : dsf._scalingFactor;
    }

    function scaleForQueueWithdrawal(
        DepositScalingFactor memory dsf,
        uint256 depositSharesToWithdraw
    ) internal pure returns (uint256) {
        return depositSharesToWithdraw.mulWad(dsf.scalingFactor());
    }

    function scaleForCompleteWithdrawal(uint256 scaledShares, uint256 slashingFactor) internal pure returns (uint256) {
        return scaledShares.mulWad(slashingFactor);
    }

    /**
     * @notice Scales shares according to the difference in an operator's magnitude before and
     * after being slashed. This is used to calculate the number of slashable shares in the
     * withdrawal queue.
     * NOTE: max magnitude is guaranteed to only ever decrease.
     */
    function scaleForBurning(
        uint256 scaledShares,
        uint64 prevMaxMagnitude,
        uint64 newMaxMagnitude
    ) internal pure returns (uint256) {
        return scaledShares.mulWad(prevMaxMagnitude - newMaxMagnitude);
    }

    function update(
        DepositScalingFactor storage dsf,
        uint256 prevDepositShares,
        uint256 addedShares,
        uint256 slashingFactor
    ) internal {
        if (prevDepositShares == 0) {
            // If this is the staker's first deposit or they are delegating to an operator,
            // the slashing factor is inverted and applied to the existing DSF. This has the
            // effect of "forgiving" prior slashing for any subsequent deposits.
            dsf._scalingFactor = dsf.scalingFactor().divWad(slashingFactor);
            return;
        }

        /**
         * Base Equations:
         * (1) newShares = currentShares + addedShares
         * (2) newDepositShares = prevDepositShares + addedShares
         * (3) newShares = newDepositShares * newDepositScalingFactor * slashingFactor
         *
         * Plugging (1) into (3):
         * (4) newDepositShares * newDepositScalingFactor * slashingFactor = currentShares + addedShares
         *
         * Solving for newDepositScalingFactor
         * (5) newDepositScalingFactor = (currentShares + addedShares) / (newDepositShares * slashingFactor)
         *
         * Plugging in (2) into (5):
         * (7) newDepositScalingFactor = (currentShares + addedShares) / ((prevDepositShares + addedShares) * slashingFactor)
         * Note that magnitudes must be divided by WAD for precision. Thus,
         *
         * (8) newDepositScalingFactor = WAD * (currentShares + addedShares) / ((prevDepositShares + addedShares) * slashingFactor / WAD)
         * (9) newDepositScalingFactor = (currentShares + addedShares) * WAD / (prevDepositShares + addedShares) * WAD / slashingFactor
         */

        // Step 1: Calculate Numerator
        uint256 currentShares = dsf.calcWithdrawable(prevDepositShares, slashingFactor);

        // Step 2: Compute currentShares + addedShares
        uint256 newShares = currentShares + addedShares;

        // Step 3: Calculate newDepositScalingFactor
        /// forgefmt: disable-next-item
        uint256 newDepositScalingFactor = newShares
            .divWad(prevDepositShares + addedShares)
            .divWad(slashingFactor);

        dsf._scalingFactor = newDepositScalingFactor;
    }

    /// @dev Reset the staker's DSF for a strategy by setting it to 0. This is the same
    /// as setting it to WAD (see the `scalingFactor` getter above).
    ///
    /// A DSF is reset when a staker reduces their deposit shares to 0, either by queueing
    /// a withdrawal, or undelegating from their operator. This ensures that subsequent
    /// delegations/deposits do not use a stale DSF (e.g. from a prior operator).
    function reset(
        DepositScalingFactor storage dsf
    ) internal {
        dsf._scalingFactor = 0;
    }

    // CONVERSION

    function calcWithdrawable(
        DepositScalingFactor memory dsf,
        uint256 depositShares,
        uint256 slashingFactor
    ) internal pure returns (uint256) {
        /// forgefmt: disable-next-item
        return depositShares
            .mulWad(dsf.scalingFactor())
            .mulWad(slashingFactor);
    }

    function calcDepositShares(
        DepositScalingFactor memory dsf,
        uint256 withdrawableShares,
        uint256 slashingFactor
    ) internal pure returns (uint256) {
        /// forgefmt: disable-next-item
        return withdrawableShares
            .divWad(dsf.scalingFactor())
            .divWad(slashingFactor);
    }

    function calcSlashedAmount(
        uint256 operatorShares,
        uint256 prevMaxMagnitude,
        uint256 newMaxMagnitude
    ) internal pure returns (uint256) {
        // round up mulDiv so we don't overslash
        return operatorShares - operatorShares.mulDiv(newMaxMagnitude, prevMaxMagnitude, Math.Rounding.Up);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStrategy} from "@eigenlayer/contracts/interfaces/IStrategy.sol";
import {ISignatureUtilsMixinTypes} from "@eigenlayer/contracts/interfaces/ISignatureUtilsMixin.sol";

import {IStakerNodeCoordinator} from "../interfaces/IStakerNodeCoordinator.sol";

/// @title IStakerNode Interface
/// @notice Interface for the StakerNode contract
interface IStakerNode {
    // ============================================================================
    // STRUCTS
    // ============================================================================

    /// @notice Initialization parameters for StakerNode
    struct Init {
        IStakerNodeCoordinator coordinator;
        uint256 id;
    }

    // ============================================================================
    // EVENTS
    // ============================================================================

    /// @notice Emitted node is delegated to an EigenLayer operator
    event DelegatedToOperator(address operator);

    /// @notice Emitted node is undelegated from an EigenLayer operator
    event UndelegatedFromOperator(address operator);

    /// @notice Emitted when assets are deposited into an EigenLayer strategy
    event AssetDepositedToStrategy(IERC20 indexed asset, IStrategy indexed strategy, uint256 amount, uint256 shares);

    // ============================================================================
    // CUSTOM ERRORS
    // ============================================================================

    /// @notice Error for zero address
    error ZeroAddress();

    /// @notice Error for unauthorized access by non-StakerNode operator
    error NotStakerNodeOperator();

    /// @notice Error for unauthorized access by non-StakerNode delegator
    error NotStakerNodeDelegator();

    /// @notice Error for unauthorized access by non-LiquidTokenManager
    error NotLiquidTokenManager();

    /// @notice Error for unauthorized access
    error UnauthorizedAccess(address caller, bytes32 requiredRole);

    /// @notice Error for delegating node when already delegated
    error NodeIsDelegated(address operatorDelegation);

    /// @notice Error for undelegating node when not delegated
    error NodeIsNotDelegated();

    // ============================================================================
    // FUNCTIONS
    // ============================================================================

    /// @notice Initializes the StakerNode contract
    /// @param init Initialization parameters
    function initialize(Init memory init) external;

    /// @notice Delegates the StakerNode's assets to an operator
    /// @param operator Address of the operator to delegate to
    /// @param signature Signature authorizing the delegation
    /// @param approverSalt Salt used in the signature
    function delegate(
        address operator,
        ISignatureUtilsMixinTypes.SignatureWithExpiry memory signature,
        bytes32 approverSalt
    ) external;

    /// @notice Deposits assets into Eigenlayer strategies
    /// @param assets Array of ERC20 token addresses to deposit
    /// @param amounts Array of amounts to deposit for each asset
    /// @param strategies Array of Eigenlayer strategies to deposit into
    function depositAssets(
        IERC20[] calldata assets,
        uint256[] calldata amounts,
        IStrategy[] calldata strategies
    ) external;

    /// @dev Out OF SCOPE FOR V1
    /**
    function undelegate() external;
    */

    /// @notice Returns the address of the current implementation contract
    /// @return The address of the implementation contract
    function implementation() external view returns (address);

    /// @notice Returns the version of the contract that was last initialized
    /// @return The initialized version as a uint64
    function getInitializedVersion() external view returns (uint64);

    /// @notice Returns the id of the StakerNode
    /// @return The StakerNode's id as uint256
    function getId() external view returns (uint256);

    /// Returns the address of the operator the node is delegate to
    /// @return The address of the delegated operator or zero address if not delegated
    function getOperatorDelegation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// ┏━━━┓━┏┓━┏┓━━┏━━━┓━━┏━━━┓━━━━┏━━━┓━━━━━━━━━━━━━━━━━━━┏┓━━━━━┏━━━┓━━━━━━━━━┏┓━━━━━━━━━━━━━━┏┓━
// ┃┏━━┛┏┛┗┓┃┃━━┃┏━┓┃━━┃┏━┓┃━━━━┗┓┏┓┃━━━━━━━━━━━━━━━━━━┏┛┗┓━━━━┃┏━┓┃━━━━━━━━┏┛┗┓━━━━━━━━━━━━┏┛┗┓
// ┃┗━━┓┗┓┏┛┃┗━┓┗┛┏┛┃━━┃┃━┃┃━━━━━┃┃┃┃┏━━┓┏━━┓┏━━┓┏━━┓┏┓┗┓┏┛━━━━┃┃━┗┛┏━━┓┏━┓━┗┓┏┛┏━┓┏━━┓━┏━━┓┗┓┏┛
// ┃┏━━┛━┃┃━┃┏┓┃┏━┛┏┛━━┃┃━┃┃━━━━━┃┃┃┃┃┏┓┃┃┏┓┃┃┏┓┃┃━━┫┣┫━┃┃━━━━━┃┃━┏┓┃┏┓┃┃┏┓┓━┃┃━┃┏┛┗━┓┃━┃┏━┛━┃┃━
// ┃┗━━┓━┃┗┓┃┃┃┃┃┃┗━┓┏┓┃┗━┛┃━━━━┏┛┗┛┃┃┃━┫┃┗┛┃┃┗┛┃┣━━┃┃┃━┃┗┓━━━━┃┗━┛┃┃┗┛┃┃┃┃┃━┃┗┓┃┃━┃┗┛┗┓┃┗━┓━┃┗┓
// ┗━━━┛━┗━┛┗┛┗┛┗━━━┛┗┛┗━━━┛━━━━┗━━━┛┗━━┛┃┏━┛┗━━┛┗━━┛┗┛━┗━┛━━━━┗━━━┛┗━━┛┗┛┗┛━┗━┛┗┛━┗━━━┛┗━━┛━┗━┛
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┃┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┗┛━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// SPDX-License-Identifier: CC0-1.0

pragma solidity >=0.5.0;

// This interface is designed to be compatible with the Vyper version.
/// @notice This is the Ethereum 2.0 deposit contract interface.
/// For more information see the Phase 0 specification under https://github.com/ethereum/eth2.0-specs
interface IETHPOSDeposit {
    /// @notice A processed deposit event.
    event DepositEvent(bytes pubkey, bytes withdrawal_credentials, bytes amount, bytes signature, bytes index);

    /// @notice Submit a Phase 0 DepositData object.
    /// @param pubkey A BLS12-381 public key.
    /// @param withdrawal_credentials Commitment to a public key for withdrawals.
    /// @param signature A BLS12-381 signature.
    /// @param deposit_data_root The SHA-256 hash of the SSZ-encoded DepositData object.
    /// Used as a protection against malformed input.
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable;

    /// @notice Query the current deposit root hash.
    /// @return The deposit root hash.
    function get_deposit_root() external view returns (bytes32);

    /// @notice Query the current deposit count.
    /// @return The deposit count encoded as a little endian 64-bit number.
    function get_deposit_count() external view returns (bytes memory);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../libraries/BeaconChainProofs.sol";
import "./ISemVerMixin.sol";
import "./IEigenPodManager.sol";

interface IEigenPodErrors {
    /// @dev Thrown when msg.sender is not the EPM.
    error OnlyEigenPodManager();
    /// @dev Thrown when msg.sender is not the pod owner.
    error OnlyEigenPodOwner();
    /// @dev Thrown when msg.sender is not owner or the proof submitter.
    error OnlyEigenPodOwnerOrProofSubmitter();
    /// @dev Thrown when attempting an action that is currently paused.
    error CurrentlyPaused();

    /// Invalid Inputs

    /// @dev Thrown when an address of zero is provided.
    error InputAddressZero();
    /// @dev Thrown when two array parameters have mismatching lengths.
    error InputArrayLengthMismatch();
    /// @dev Thrown when `validatorPubKey` length is not equal to 48-bytes.
    error InvalidPubKeyLength();
    /// @dev Thrown when provided timestamp is out of range.
    error TimestampOutOfRange();

    /// Checkpoints

    /// @dev Thrown when no active checkpoints are found.
    error NoActiveCheckpoint();
    /// @dev Thrown if an uncompleted checkpoint exists.
    error CheckpointAlreadyActive();
    /// @dev Thrown if there's not a balance available to checkpoint.
    error NoBalanceToCheckpoint();
    /// @dev Thrown when attempting to create a checkpoint twice within a given block.
    error CannotCheckpointTwiceInSingleBlock();

    /// Withdrawing

    /// @dev Thrown when amount exceeds `restakedExecutionLayerGwei`.
    error InsufficientWithdrawableBalance();

    /// Validator Status

    /// @dev Thrown when a validator's withdrawal credentials have already been verified.
    error CredentialsAlreadyVerified();
    /// @dev Thrown if the provided proof is not valid for this EigenPod.
    error WithdrawalCredentialsNotForEigenPod();
    /// @dev Thrown when a validator is not in the ACTIVE status in the pod.
    error ValidatorNotActiveInPod();
    /// @dev Thrown when validator is not active yet on the beacon chain.
    error ValidatorInactiveOnBeaconChain();
    /// @dev Thrown if a validator is exiting the beacon chain.
    error ValidatorIsExitingBeaconChain();
    /// @dev Thrown when a validator has not been slashed on the beacon chain.
    error ValidatorNotSlashedOnBeaconChain();

    /// Misc

    /// @dev Thrown when an invalid block root is returned by the EIP-4788 oracle.
    error InvalidEIP4788Response();
    /// @dev Thrown when attempting to send an invalid amount to the beacon deposit contract.
    error MsgValueNot32ETH();
    /// @dev Thrown when provided `beaconTimestamp` is too far in the past.
    error BeaconTimestampTooFarInPast();
    /// @dev Thrown when the pectraForkTimestamp returned from the EigenPodManager is zero
    error ForkTimestampZero();
}

interface IEigenPodTypes {
    enum VALIDATOR_STATUS {
        INACTIVE, // doesnt exist
        ACTIVE, // staked on ethpos and withdrawal credentials are pointed to the EigenPod
        WITHDRAWN // withdrawn from the Beacon Chain

    }

    struct ValidatorInfo {
        // index of the validator in the beacon chain
        uint64 validatorIndex;
        // amount of beacon chain ETH restaked on EigenLayer in gwei
        uint64 restakedBalanceGwei;
        //timestamp of the validator's most recent balance update
        uint64 lastCheckpointedAt;
        // status of the validator
        VALIDATOR_STATUS status;
    }

    struct Checkpoint {
        bytes32 beaconBlockRoot;
        uint24 proofsRemaining;
        uint64 podBalanceGwei;
        int64 balanceDeltasGwei;
        uint64 prevBeaconBalanceGwei;
    }
}

interface IEigenPodEvents is IEigenPodTypes {
    /// @notice Emitted when an ETH validator stakes via this eigenPod
    event EigenPodStaked(bytes pubkey);

    /// @notice Emitted when a pod owner updates the proof submitter address
    event ProofSubmitterUpdated(address prevProofSubmitter, address newProofSubmitter);

    /// @notice Emitted when an ETH validator's withdrawal credentials are successfully verified to be pointed to this eigenPod
    event ValidatorRestaked(uint40 validatorIndex);

    /// @notice Emitted when an ETH validator's  balance is proven to be updated.  Here newValidatorBalanceGwei
    //  is the validator's balance that is credited on EigenLayer.
    event ValidatorBalanceUpdated(uint40 validatorIndex, uint64 balanceTimestamp, uint64 newValidatorBalanceGwei);

    /// @notice Emitted when restaked beacon chain ETH is withdrawn from the eigenPod.
    event RestakedBeaconChainETHWithdrawn(address indexed recipient, uint256 amount);

    /// @notice Emitted when ETH is received via the `receive` fallback
    event NonBeaconChainETHReceived(uint256 amountReceived);

    /// @notice Emitted when a checkpoint is created
    event CheckpointCreated(
        uint64 indexed checkpointTimestamp, bytes32 indexed beaconBlockRoot, uint256 validatorCount
    );

    /// @notice Emitted when a checkpoint is finalized
    event CheckpointFinalized(uint64 indexed checkpointTimestamp, int256 totalShareDeltaWei);

    /// @notice Emitted when a validator is proven for a given checkpoint
    event ValidatorCheckpointed(uint64 indexed checkpointTimestamp, uint40 indexed validatorIndex);

    /// @notice Emitted when a validaor is proven to have 0 balance at a given checkpoint
    event ValidatorWithdrawn(uint64 indexed checkpointTimestamp, uint40 indexed validatorIndex);
}

/**
 * @title The implementation contract used for restaking beacon chain ETH on EigenLayer
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @dev Note that all beacon chain balances are stored as gwei within the beacon chain datastructures. We choose
 *   to account balances in terms of gwei in the EigenPod contract and convert to wei when making calls to other contracts
 */
interface IEigenPod is IEigenPodErrors, IEigenPodEvents, ISemVerMixin {
    /// @notice Used to initialize the pointers to contracts crucial to the pod's functionality, in beacon proxy construction from EigenPodManager
    function initialize(
        address owner
    ) external;

    /// @notice Called by EigenPodManager when the owner wants to create another ETH validator.
    /// @dev This function only supports staking to a 0x01 validator. For compounding validators, please interact directly with the deposit contract.
    function stake(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) external payable;

    /**
     * @notice Transfers `amountWei` in ether from this contract to the specified `recipient` address
     * @notice Called by EigenPodManager to withdrawBeaconChainETH that has been added to the EigenPod's balance due to a withdrawal from the beacon chain.
     * @dev The podOwner must have already proved sufficient withdrawals, so that this pod's `restakedExecutionLayerGwei` exceeds the
     * `amountWei` input (when converted to GWEI).
     * @dev Reverts if `amountWei` is not a whole Gwei amount
     */
    function withdrawRestakedBeaconChainETH(address recipient, uint256 amount) external;

    /**
     * @dev Create a checkpoint used to prove this pod's active validator set. Checkpoints are completed
     * by submitting one checkpoint proof per ACTIVE validator. During the checkpoint process, the total
     * change in ACTIVE validator balance is tracked, and any validators with 0 balance are marked `WITHDRAWN`.
     * @dev Once finalized, the pod owner is awarded shares corresponding to:
     * - the total change in their ACTIVE validator balances
     * - any ETH in the pod not already awarded shares
     * @dev A checkpoint cannot be created if the pod already has an outstanding checkpoint. If
     * this is the case, the pod owner MUST complete the existing checkpoint before starting a new one.
     * @param revertIfNoBalance Forces a revert if the pod ETH balance is 0. This allows the pod owner
     * to prevent accidentally starting a checkpoint that will not increase their shares
     */
    function startCheckpoint(
        bool revertIfNoBalance
    ) external;

    /**
     * @dev Progress the current checkpoint towards completion by submitting one or more validator
     * checkpoint proofs. Anyone can call this method to submit proofs towards the current checkpoint.
     * For each validator proven, the current checkpoint's `proofsRemaining` decreases.
     * @dev If the checkpoint's `proofsRemaining` reaches 0, the checkpoint is finalized.
     * (see `_updateCheckpoint` for more details)
     * @dev This method can only be called when there is a currently-active checkpoint.
     * @param balanceContainerProof proves the beacon's current balance container root against a checkpoint's `beaconBlockRoot`
     * @param proofs Proofs for one or more validator current balances against the `balanceContainerRoot`
     */
    function verifyCheckpointProofs(
        BeaconChainProofs.BalanceContainerProof calldata balanceContainerProof,
        BeaconChainProofs.BalanceProof[] calldata proofs
    ) external;

    /**
     * @dev Verify one or more validators have their withdrawal credentials pointed at this EigenPod, and award
     * shares based on their effective balance. Proven validators are marked `ACTIVE` within the EigenPod, and
     * future checkpoint proofs will need to include them.
     * @dev Withdrawal credential proofs MUST NOT be older than `currentCheckpointTimestamp`.
     * @dev Validators proven via this method MUST NOT have an exit epoch set already.
     * @param beaconTimestamp the beacon chain timestamp sent to the 4788 oracle contract. Corresponds
     * to the parent beacon block root against which the proof is verified.
     * @param stateRootProof proves a beacon state root against a beacon block root
     * @param validatorIndices a list of validator indices being proven
     * @param validatorFieldsProofs proofs of each validator's `validatorFields` against the beacon state root
     * @param validatorFields the fields of the beacon chain "Validator" container. See consensus specs for
     * details: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator
     */
    function verifyWithdrawalCredentials(
        uint64 beaconTimestamp,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        uint40[] calldata validatorIndices,
        bytes[] calldata validatorFieldsProofs,
        bytes32[][] calldata validatorFields
    ) external;

    /**
     * @dev Prove that one of this pod's active validators was slashed on the beacon chain. A successful
     * staleness proof allows the caller to start a checkpoint.
     *
     * @dev Note that in order to start a checkpoint, any existing checkpoint must already be completed!
     * (See `_startCheckpoint` for details)
     *
     * @dev Note that this method allows anyone to start a checkpoint as soon as a slashing occurs on the beacon
     * chain. This is intended to make it easier to external watchers to keep a pod's balance up to date.
     *
     * @dev Note too that beacon chain slashings are not instant. There is a delay between the initial slashing event
     * and the validator's final exit back to the execution layer. During this time, the validator's balance may or
     * may not drop further due to a correlation penalty. This method allows proof of a slashed validator
     * to initiate a checkpoint for as long as the validator remains on the beacon chain. Once the validator
     * has exited and been checkpointed at 0 balance, they are no longer "checkpoint-able" and cannot be proven
     * "stale" via this method.
     * See https://eth2book.info/capella/part3/transition/epoch/#slashings for more info.
     *
     * @param beaconTimestamp the beacon chain timestamp sent to the 4788 oracle contract. Corresponds
     * to the parent beacon block root against which the proof is verified.
     * @param stateRootProof proves a beacon state root against a beacon block root
     * @param proof the fields of the beacon chain "Validator" container, along with a merkle proof against
     * the beacon state root. See the consensus specs for more details:
     * https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator
     *
     * @dev Staleness conditions:
     * - Validator's last checkpoint is older than `beaconTimestamp`
     * - Validator MUST be in `ACTIVE` status in the pod
     * - Validator MUST be slashed on the beacon chain
     */
    function verifyStaleBalance(
        uint64 beaconTimestamp,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        BeaconChainProofs.ValidatorProof calldata proof
    ) external;

    /// @notice called by owner of a pod to remove any ERC20s deposited in the pod
    function recoverTokens(IERC20[] memory tokenList, uint256[] memory amountsToWithdraw, address recipient) external;

    /// @notice Allows the owner of a pod to update the proof submitter, a permissioned
    /// address that can call `startCheckpoint` and `verifyWithdrawalCredentials`.
    /// @dev Note that EITHER the podOwner OR proofSubmitter can access these methods,
    /// so it's fine to set your proofSubmitter to 0 if you want the podOwner to be the
    /// only address that can call these methods.
    /// @param newProofSubmitter The new proof submitter address. If set to 0, only the
    /// pod owner will be able to call `startCheckpoint` and `verifyWithdrawalCredentials`
    function setProofSubmitter(
        address newProofSubmitter
    ) external;

    /**
     *
     *                                VIEW METHODS
     *
     */

    /// @notice An address with permissions to call `startCheckpoint` and `verifyWithdrawalCredentials`, set
    /// by the podOwner. This role exists to allow a podOwner to designate a hot wallet that can call
    /// these methods, allowing the podOwner to remain a cold wallet that is only used to manage funds.
    /// @dev If this address is NOT set, only the podOwner can call `startCheckpoint` and `verifyWithdrawalCredentials`
    function proofSubmitter() external view returns (address);

    /// @notice the amount of execution layer ETH in this contract that is staked in EigenLayer (i.e. withdrawn from beaconchain but not EigenLayer),
    function withdrawableRestakedExecutionLayerGwei() external view returns (uint64);

    /// @notice The single EigenPodManager for EigenLayer
    function eigenPodManager() external view returns (IEigenPodManager);

    /// @notice The owner of this EigenPod
    function podOwner() external view returns (address);

    /// @notice Returns the validatorInfo struct for the provided pubkeyHash
    function validatorPubkeyHashToInfo(
        bytes32 validatorPubkeyHash
    ) external view returns (ValidatorInfo memory);

    /// @notice Returns the validatorInfo struct for the provided pubkey
    function validatorPubkeyToInfo(
        bytes calldata validatorPubkey
    ) external view returns (ValidatorInfo memory);

    /// @notice This returns the status of a given validator
    function validatorStatus(
        bytes32 pubkeyHash
    ) external view returns (VALIDATOR_STATUS);

    /// @notice This returns the status of a given validator pubkey
    function validatorStatus(
        bytes calldata validatorPubkey
    ) external view returns (VALIDATOR_STATUS);

    /// @notice Number of validators with proven withdrawal credentials, who do not have proven full withdrawals
    function activeValidatorCount() external view returns (uint256);

    /// @notice The timestamp of the last checkpoint finalized
    function lastCheckpointTimestamp() external view returns (uint64);

    /// @notice The timestamp of the currently-active checkpoint. Will be 0 if there is not active checkpoint
    function currentCheckpointTimestamp() external view returns (uint64);

    /// @notice Returns the currently-active checkpoint
    function currentCheckpoint() external view returns (Checkpoint memory);

    /// @notice For each checkpoint, the total balance attributed to exited validators, in gwei
    ///
    /// NOTE that the values added to this mapping are NOT guaranteed to capture the entirety of a validator's
    /// exit - rather, they capture the total change in a validator's balance when a checkpoint shows their
    /// balance change from nonzero to zero. While a change from nonzero to zero DOES guarantee that a validator
    /// has been fully exited, it is possible that the magnitude of this change does not capture what is
    /// typically thought of as a "full exit."
    ///
    /// For example:
    /// 1. Consider a validator was last checkpointed at 32 ETH before exiting. Once the exit has been processed,
    /// it is expected that the validator's exited balance is calculated to be `32 ETH`.
    /// 2. However, before `startCheckpoint` is called, a deposit is made to the validator for 1 ETH. The beacon
    /// chain will automatically withdraw this ETH, but not until the withdrawal sweep passes over the validator
    /// again. Until this occurs, the validator's current balance (used for checkpointing) is 1 ETH.
    /// 3. If `startCheckpoint` is called at this point, the balance delta calculated for this validator will be
    /// `-31 ETH`, and because the validator has a nonzero balance, it is not marked WITHDRAWN.
    /// 4. After the exit is processed by the beacon chain, a subsequent `startCheckpoint` and checkpoint proof
    /// will calculate a balance delta of `-1 ETH` and attribute a 1 ETH exit to the validator.
    ///
    /// If this edge case impacts your usecase, it should be possible to mitigate this by monitoring for deposits
    /// to your exited validators, and waiting to call `startCheckpoint` until those deposits have been automatically
    /// exited.
    ///
    /// Additional edge cases this mapping does not cover:
    /// - If a validator is slashed, their balance exited will reflect their original balance rather than the slashed amount
    /// - The final partial withdrawal for an exited validator will be likely be included in this mapping.
    ///   i.e. if a validator was last checkpointed at 32.1 ETH before exiting, the next checkpoint will calculate their
    ///   "exited" amount to be 32.1 ETH rather than 32 ETH.
    function checkpointBalanceExitedGwei(
        uint64
    ) external view returns (uint64);

    /// @notice Query the 4788 oracle to get the parent block root of the slot with the given `timestamp`
    /// @param timestamp of the block for which the parent block root will be returned. MUST correspond
    /// to an existing slot within the last 24 hours. If the slot at `timestamp` was skipped, this method
    /// will revert.
    function getParentBlockRoot(
        uint64 timestamp
    ) external view returns (bytes32);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "../interfaces/IPauserRegistry.sol";

/**
 * @title Adds pausability to a contract, with pausing & unpausing controlled by the `pauser` and `unpauser` of a PauserRegistry contract.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice Contracts that inherit from this contract may define their own `pause` and `unpause` (and/or related) functions.
 * These functions should be permissioned as "onlyPauser" which defers to a `PauserRegistry` for determining access control.
 * @dev Pausability is implemented using a uint256, which allows up to 256 different single bit-flags; each bit can potentially pause different functionality.
 * Inspiration for this was taken from the NearBridge design here https://etherscan.io/address/0x3FEFc5A4B1c02f21cBc8D3613643ba0635b9a873#code.
 * For the `pause` and `unpause` functions we've implemented, if you pause, you can only flip (any number of) switches to on/1 (aka "paused"), and if you unpause,
 * you can only flip (any number of) switches to off/0 (aka "paused").
 * If you want a pauseXYZ function that just flips a single bit / "pausing flag", it will:
 * 1) 'bit-wise and' (aka `&`) a flag with the current paused state (as a uint256)
 * 2) update the paused state to this new value
 * @dev We note as well that we have chosen to identify flags by their *bit index* as opposed to their numerical value, so, e.g. defining `DEPOSITS_PAUSED = 3`
 * indicates specifically that if the *third bit* of `_paused` is flipped -- i.e. it is a '1' -- then deposits should be paused
 */
interface IPausable {
    /// @dev Thrown when caller is not pauser.
    error OnlyPauser();
    /// @dev Thrown when caller is not unpauser.
    error OnlyUnpauser();
    /// @dev Thrown when currently paused.
    error CurrentlyPaused();
    /// @dev Thrown when invalid `newPausedStatus` is provided.
    error InvalidNewPausedStatus();
    /// @dev Thrown when a null address input is provided.
    error InputAddressZero();

    /// @notice Emitted when the pause is triggered by `account`, and changed to `newPausedStatus`.
    event Paused(address indexed account, uint256 newPausedStatus);

    /// @notice Emitted when the pause is lifted by `account`, and changed to `newPausedStatus`.
    event Unpaused(address indexed account, uint256 newPausedStatus);

    /// @notice Address of the `PauserRegistry` contract that this contract defers to for determining access control (for pausing).
    function pauserRegistry() external view returns (IPauserRegistry);

    /**
     * @notice This function is used to pause an EigenLayer contract's functionality.
     * It is permissioned to the `pauser` address, which is expected to be a low threshold multisig.
     * @param newPausedStatus represents the new value for `_paused` to take, which means it may flip several bits at once.
     * @dev This function can only pause functionality, and thus cannot 'unflip' any bit in `_paused` from 1 to 0.
     */
    function pause(
        uint256 newPausedStatus
    ) external;

    /**
     * @notice Alias for `pause(type(uint256).max)`.
     */
    function pauseAll() external;

    /**
     * @notice This function is used to unpause an EigenLayer contract's functionality.
     * It is permissioned to the `unpauser` address, which is expected to be a high threshold multisig or governance contract.
     * @param newPausedStatus represents the new value for `_paused` to take, which means it may flip several bits at once.
     * @dev This function can only unpause functionality, and thus cannot 'flip' any bit in `_paused` from 0 to 1.
     */
    function unpause(
        uint256 newPausedStatus
    ) external;

    /// @notice Returns the current paused status as a uint256.
    function paused() external view returns (uint256);

    /// @notice Returns 'true' if the `indexed`th bit of `_paused` is 1, and 'false' otherwise
    function paused(
        uint8 index
    ) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1, "Math: mulDiv overflow");

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SafeCast.sol)
// This file was procedurally generated from scripts/generate/templates/SafeCast.js.

pragma solidity ^0.8.0;

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCastUpgradeable {
    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     *
     * _Available since v4.7._
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        require(value <= type(uint248).max, "SafeCast: value doesn't fit in 248 bits");
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     *
     * _Available since v4.7._
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        require(value <= type(uint240).max, "SafeCast: value doesn't fit in 240 bits");
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     *
     * _Available since v4.7._
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        require(value <= type(uint232).max, "SafeCast: value doesn't fit in 232 bits");
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     *
     * _Available since v4.2._
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     *
     * _Available since v4.7._
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        require(value <= type(uint216).max, "SafeCast: value doesn't fit in 216 bits");
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     *
     * _Available since v4.7._
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        require(value <= type(uint208).max, "SafeCast: value doesn't fit in 208 bits");
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     *
     * _Available since v4.7._
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        require(value <= type(uint200).max, "SafeCast: value doesn't fit in 200 bits");
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     *
     * _Available since v4.7._
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        require(value <= type(uint192).max, "SafeCast: value doesn't fit in 192 bits");
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        require(value <= type(uint184).max, "SafeCast: value doesn't fit in 184 bits");
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     *
     * _Available since v4.7._
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        require(value <= type(uint176).max, "SafeCast: value doesn't fit in 176 bits");
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     *
     * _Available since v4.7._
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        require(value <= type(uint168).max, "SafeCast: value doesn't fit in 168 bits");
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     *
     * _Available since v4.7._
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        require(value <= type(uint160).max, "SafeCast: value doesn't fit in 160 bits");
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     *
     * _Available since v4.7._
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        require(value <= type(uint152).max, "SafeCast: value doesn't fit in 152 bits");
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     *
     * _Available since v4.7._
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        require(value <= type(uint144).max, "SafeCast: value doesn't fit in 144 bits");
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     *
     * _Available since v4.7._
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        require(value <= type(uint136).max, "SafeCast: value doesn't fit in 136 bits");
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v2.5._
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     *
     * _Available since v4.7._
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        require(value <= type(uint120).max, "SafeCast: value doesn't fit in 120 bits");
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     *
     * _Available since v4.7._
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        require(value <= type(uint112).max, "SafeCast: value doesn't fit in 112 bits");
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     *
     * _Available since v4.7._
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        require(value <= type(uint104).max, "SafeCast: value doesn't fit in 104 bits");
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     *
     * _Available since v4.2._
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     *
     * _Available since v4.7._
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        require(value <= type(uint88).max, "SafeCast: value doesn't fit in 88 bits");
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     *
     * _Available since v4.7._
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        require(value <= type(uint80).max, "SafeCast: value doesn't fit in 80 bits");
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     *
     * _Available since v4.7._
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        require(value <= type(uint72).max, "SafeCast: value doesn't fit in 72 bits");
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v2.5._
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     *
     * _Available since v4.7._
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        require(value <= type(uint56).max, "SafeCast: value doesn't fit in 56 bits");
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        require(value <= type(uint48).max, "SafeCast: value doesn't fit in 48 bits");
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     *
     * _Available since v4.7._
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        require(value <= type(uint40).max, "SafeCast: value doesn't fit in 40 bits");
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v2.5._
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     *
     * _Available since v4.7._
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        require(value <= type(uint24).max, "SafeCast: value doesn't fit in 24 bits");
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v2.5._
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     *
     * _Available since v2.5._
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     *
     * _Available since v3.0._
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     *
     * _Available since v4.7._
     */
    function toInt248(int256 value) internal pure returns (int248 downcasted) {
        downcasted = int248(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 248 bits");
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     *
     * _Available since v4.7._
     */
    function toInt240(int256 value) internal pure returns (int240 downcasted) {
        downcasted = int240(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 240 bits");
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     *
     * _Available since v4.7._
     */
    function toInt232(int256 value) internal pure returns (int232 downcasted) {
        downcasted = int232(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 232 bits");
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     *
     * _Available since v4.7._
     */
    function toInt224(int256 value) internal pure returns (int224 downcasted) {
        downcasted = int224(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 224 bits");
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     *
     * _Available since v4.7._
     */
    function toInt216(int256 value) internal pure returns (int216 downcasted) {
        downcasted = int216(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 216 bits");
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     *
     * _Available since v4.7._
     */
    function toInt208(int256 value) internal pure returns (int208 downcasted) {
        downcasted = int208(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 208 bits");
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     *
     * _Available since v4.7._
     */
    function toInt200(int256 value) internal pure returns (int200 downcasted) {
        downcasted = int200(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 200 bits");
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     *
     * _Available since v4.7._
     */
    function toInt192(int256 value) internal pure returns (int192 downcasted) {
        downcasted = int192(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 192 bits");
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toInt184(int256 value) internal pure returns (int184 downcasted) {
        downcasted = int184(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 184 bits");
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     *
     * _Available since v4.7._
     */
    function toInt176(int256 value) internal pure returns (int176 downcasted) {
        downcasted = int176(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 176 bits");
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     *
     * _Available since v4.7._
     */
    function toInt168(int256 value) internal pure returns (int168 downcasted) {
        downcasted = int168(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 168 bits");
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     *
     * _Available since v4.7._
     */
    function toInt160(int256 value) internal pure returns (int160 downcasted) {
        downcasted = int160(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 160 bits");
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     *
     * _Available since v4.7._
     */
    function toInt152(int256 value) internal pure returns (int152 downcasted) {
        downcasted = int152(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 152 bits");
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     *
     * _Available since v4.7._
     */
    function toInt144(int256 value) internal pure returns (int144 downcasted) {
        downcasted = int144(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 144 bits");
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     *
     * _Available since v4.7._
     */
    function toInt136(int256 value) internal pure returns (int136 downcasted) {
        downcasted = int136(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 136 bits");
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128 downcasted) {
        downcasted = int128(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 128 bits");
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     *
     * _Available since v4.7._
     */
    function toInt120(int256 value) internal pure returns (int120 downcasted) {
        downcasted = int120(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 120 bits");
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     *
     * _Available since v4.7._
     */
    function toInt112(int256 value) internal pure returns (int112 downcasted) {
        downcasted = int112(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 112 bits");
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     *
     * _Available since v4.7._
     */
    function toInt104(int256 value) internal pure returns (int104 downcasted) {
        downcasted = int104(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 104 bits");
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     *
     * _Available since v4.7._
     */
    function toInt96(int256 value) internal pure returns (int96 downcasted) {
        downcasted = int96(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 96 bits");
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     *
     * _Available since v4.7._
     */
    function toInt88(int256 value) internal pure returns (int88 downcasted) {
        downcasted = int88(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 88 bits");
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     *
     * _Available since v4.7._
     */
    function toInt80(int256 value) internal pure returns (int80 downcasted) {
        downcasted = int80(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 80 bits");
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     *
     * _Available since v4.7._
     */
    function toInt72(int256 value) internal pure returns (int72 downcasted) {
        downcasted = int72(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 72 bits");
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64 downcasted) {
        downcasted = int64(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 64 bits");
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     *
     * _Available since v4.7._
     */
    function toInt56(int256 value) internal pure returns (int56 downcasted) {
        downcasted = int56(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 56 bits");
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toInt48(int256 value) internal pure returns (int48 downcasted) {
        downcasted = int48(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 48 bits");
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     *
     * _Available since v4.7._
     */
    function toInt40(int256 value) internal pure returns (int40 downcasted) {
        downcasted = int40(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 40 bits");
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32 downcasted) {
        downcasted = int32(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 32 bits");
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     *
     * _Available since v4.7._
     */
    function toInt24(int256 value) internal pure returns (int24 downcasted) {
        downcasted = int24(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 24 bits");
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16 downcasted) {
        downcasted = int16(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 16 bits");
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8 downcasted) {
        downcasted = int8(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 8 bits");
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     *
     * _Available since v3.0._
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./Merkle.sol";
import "../libraries/Endian.sol";

//Utility library for parsing and PHASE0 beacon chain block headers
//SSZ Spec: https://github.com/ethereum/consensus-specs/blob/dev/ssz/simple-serialize.md#merkleization
//BeaconBlockHeader Spec: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#beaconblockheader
//BeaconState Spec: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#beaconstate
library BeaconChainProofs {
    /// @dev Thrown when a proof is invalid.
    error InvalidProof();
    /// @dev Thrown when a proof with an invalid length is provided.
    error InvalidProofLength();
    /// @dev Thrown when a validator fields length is invalid.
    error InvalidValidatorFieldsLength();

    /// @notice Heights of various merkle trees in the beacon chain
    /// - beaconBlockRoot
    /// |                                             HEIGHT: BEACON_BLOCK_HEADER_TREE_HEIGHT
    /// -- beaconStateRoot
    /// |                                             HEIGHT: BEACON_STATE_TREE_HEIGHT
    /// validatorContainerRoot, balanceContainerRoot
    /// |                       |                     HEIGHT: BALANCE_TREE_HEIGHT
    /// |                       individual balances
    /// |                                             HEIGHT: VALIDATOR_TREE_HEIGHT
    /// individual validators
    uint256 internal constant BEACON_BLOCK_HEADER_TREE_HEIGHT = 3;
    uint256 internal constant DENEB_BEACON_STATE_TREE_HEIGHT = 5;
    uint256 internal constant PECTRA_BEACON_STATE_TREE_HEIGHT = 6;
    uint256 internal constant BALANCE_TREE_HEIGHT = 38;
    uint256 internal constant VALIDATOR_TREE_HEIGHT = 40;

    /// @notice Index of the beaconStateRoot in the `BeaconBlockHeader` container
    ///
    /// BeaconBlockHeader = [..., state_root, ...]
    ///                      0...      3
    ///
    /// (See https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#beaconblockheader)
    uint256 internal constant STATE_ROOT_INDEX = 3;

    /// @notice Indices for fields in the `BeaconState` container
    ///
    /// BeaconState = [..., validators, balances, ...]
    ///                0...     11         12
    ///
    /// (See https://github.com/ethereum/consensus-specs/blob/dev/specs/capella/beacon-chain.md#beaconstate)
    uint256 internal constant VALIDATOR_CONTAINER_INDEX = 11;
    uint256 internal constant BALANCE_CONTAINER_INDEX = 12;

    /// @notice Number of fields in the `Validator` container
    /// (See https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator)
    uint256 internal constant VALIDATOR_FIELDS_LENGTH = 8;

    /// @notice Indices for fields in the `Validator` container
    uint256 internal constant VALIDATOR_PUBKEY_INDEX = 0;
    uint256 internal constant VALIDATOR_WITHDRAWAL_CREDENTIALS_INDEX = 1;
    uint256 internal constant VALIDATOR_BALANCE_INDEX = 2;
    uint256 internal constant VALIDATOR_SLASHED_INDEX = 3;
    uint256 internal constant VALIDATOR_ACTIVATION_EPOCH_INDEX = 5;
    uint256 internal constant VALIDATOR_EXIT_EPOCH_INDEX = 6;

    /// @notice Slot/Epoch timings
    uint64 internal constant SECONDS_PER_SLOT = 12;
    uint64 internal constant SLOTS_PER_EPOCH = 32;
    uint64 internal constant SECONDS_PER_EPOCH = SLOTS_PER_EPOCH * SECONDS_PER_SLOT;

    /// @notice `FAR_FUTURE_EPOCH` is used as the default value for certain `Validator`
    /// fields when a `Validator` is first created on the beacon chain
    uint64 internal constant FAR_FUTURE_EPOCH = type(uint64).max;
    bytes8 internal constant UINT64_MASK = 0xffffffffffffffff;

    /// @notice The beacon chain version to validate against
    enum ProofVersion {
        DENEB,
        PECTRA
    }

    /// @notice Contains a beacon state root and a merkle proof verifying its inclusion under a beacon block root
    struct StateRootProof {
        bytes32 beaconStateRoot;
        bytes proof;
    }

    /// @notice Contains a validator's fields and a merkle proof of their inclusion under a beacon state root
    struct ValidatorProof {
        bytes32[] validatorFields;
        bytes proof;
    }

    /// @notice Contains a beacon balance container root and a proof of this root under a beacon block root
    struct BalanceContainerProof {
        bytes32 balanceContainerRoot;
        bytes proof;
    }

    /// @notice Contains a validator balance root and a proof of its inclusion under a balance container root
    struct BalanceProof {
        bytes32 pubkeyHash;
        bytes32 balanceRoot;
        bytes proof;
    }

    /**
     *
     *              VALIDATOR FIELDS -> BEACON STATE ROOT -> BEACON BLOCK ROOT
     *
     */

    /// @notice Verify a merkle proof of the beacon state root against a beacon block root
    /// @param beaconBlockRoot merkle root of the beacon block
    /// @param proof the beacon state root and merkle proof of its inclusion under `beaconBlockRoot`
    function verifyStateRoot(bytes32 beaconBlockRoot, StateRootProof calldata proof) internal view {
        require(proof.proof.length == 32 * (BEACON_BLOCK_HEADER_TREE_HEIGHT), InvalidProofLength());

        /// This merkle proof verifies the `beaconStateRoot` under the `beaconBlockRoot`
        /// - beaconBlockRoot
        /// |                            HEIGHT: BEACON_BLOCK_HEADER_TREE_HEIGHT
        /// -- beaconStateRoot
        require(
            Merkle.verifyInclusionSha256({
                proof: proof.proof,
                root: beaconBlockRoot,
                leaf: proof.beaconStateRoot,
                index: STATE_ROOT_INDEX
            }),
            InvalidProof()
        );
    }

    /// @notice Verify a merkle proof of a validator container against a `beaconStateRoot`
    /// @dev This proof starts at a validator's container root, proves through the validator container root,
    /// and continues proving to the root of the `BeaconState`
    /// @dev See https://eth2book.info/capella/part3/containers/dependencies/#validator for info on `Validator` containers
    /// @dev See https://eth2book.info/capella/part3/containers/state/#beaconstate for info on `BeaconState` containers
    /// @param beaconStateRoot merkle root of the `BeaconState` container
    /// @param validatorFields an individual validator's fields. These are merklized to form a `validatorRoot`,
    /// which is used as the leaf to prove against `beaconStateRoot`
    /// @param validatorFieldsProof a merkle proof of inclusion of `validatorFields` under `beaconStateRoot`
    /// @param validatorIndex the validator's unique index
    function verifyValidatorFields(
        ProofVersion proofVersion,
        bytes32 beaconStateRoot,
        bytes32[] calldata validatorFields,
        bytes calldata validatorFieldsProof,
        uint40 validatorIndex
    ) internal view {
        require(validatorFields.length == VALIDATOR_FIELDS_LENGTH, InvalidValidatorFieldsLength());

        uint256 beaconStateTreeHeight = getBeaconStateTreeHeight(proofVersion);

        /// Note: the reason we use `VALIDATOR_TREE_HEIGHT + 1` here is because the merklization process for
        /// this container includes hashing the root of the validator tree with the length of the validator list
        require(
            validatorFieldsProof.length == 32 * ((VALIDATOR_TREE_HEIGHT + 1) + beaconStateTreeHeight),
            InvalidProofLength()
        );

        // Merkleize `validatorFields` to get the leaf to prove
        bytes32 validatorRoot = Merkle.merkleizeSha256(validatorFields);

        /// This proof combines two proofs, so its index accounts for the relative position of leaves in two trees:
        /// - beaconStateRoot
        /// |                            HEIGHT: BEACON_STATE_TREE_HEIGHT
        /// -- validatorContainerRoot
        /// |                            HEIGHT: VALIDATOR_TREE_HEIGHT + 1
        /// ---- validatorRoot
        uint256 index = (VALIDATOR_CONTAINER_INDEX << (VALIDATOR_TREE_HEIGHT + 1)) | uint256(validatorIndex);

        require(
            Merkle.verifyInclusionSha256({
                proof: validatorFieldsProof,
                root: beaconStateRoot,
                leaf: validatorRoot,
                index: index
            }),
            InvalidProof()
        );
    }

    /**
     *
     *          VALIDATOR BALANCE -> BALANCE CONTAINER ROOT -> BEACON BLOCK ROOT
     *
     */

    /// @notice Verify a merkle proof of the beacon state's balances container against the beacon block root
    /// @dev This proof starts at the balance container root, proves through the beacon state root, and
    /// continues proving through the beacon block root. As a result, this proof will contain elements
    /// of a `StateRootProof` under the same block root, with the addition of proving the balances field
    /// within the beacon state.
    /// @dev This is used to make checkpoint proofs more efficient, as a checkpoint will verify multiple balances
    /// against the same balance container root.
    /// @param beaconBlockRoot merkle root of the beacon block
    /// @param proof a beacon balance container root and merkle proof of its inclusion under `beaconBlockRoot`
    function verifyBalanceContainer(
        ProofVersion proofVersion,
        bytes32 beaconBlockRoot,
        BalanceContainerProof calldata proof
    ) internal view {
        uint256 beaconStateTreeHeight = getBeaconStateTreeHeight(proofVersion);

        require(
            proof.proof.length == 32 * (BEACON_BLOCK_HEADER_TREE_HEIGHT + beaconStateTreeHeight), InvalidProofLength()
        );

        /// This proof combines two proofs, so its index accounts for the relative position of leaves in two trees:
        /// - beaconBlockRoot
        /// |                            HEIGHT: BEACON_BLOCK_HEADER_TREE_HEIGHT
        /// -- beaconStateRoot
        /// |                            HEIGHT: BEACON_STATE_TREE_HEIGHT
        /// ---- balancesContainerRoot
        uint256 index = (STATE_ROOT_INDEX << (beaconStateTreeHeight)) | BALANCE_CONTAINER_INDEX;

        require(
            Merkle.verifyInclusionSha256({
                proof: proof.proof,
                root: beaconBlockRoot,
                leaf: proof.balanceContainerRoot,
                index: index
            }),
            InvalidProof()
        );
    }

    /// @notice Verify a merkle proof of a validator's balance against the beacon state's `balanceContainerRoot`
    /// @param balanceContainerRoot the merkle root of all validators' current balances
    /// @param validatorIndex the index of the validator whose balance we are proving
    /// @param proof the validator's associated balance root and a merkle proof of inclusion under `balanceContainerRoot`
    /// @return validatorBalanceGwei the validator's current balance (in gwei)
    function verifyValidatorBalance(
        bytes32 balanceContainerRoot,
        uint40 validatorIndex,
        BalanceProof calldata proof
    ) internal view returns (uint64 validatorBalanceGwei) {
        /// Note: the reason we use `BALANCE_TREE_HEIGHT + 1` here is because the merklization process for
        /// this container includes hashing the root of the balances tree with the length of the balances list
        require(proof.proof.length == 32 * (BALANCE_TREE_HEIGHT + 1), InvalidProofLength());

        /// When merkleized, beacon chain balances are combined into groups of 4 called a `balanceRoot`. The merkle
        /// proof here verifies that this validator's `balanceRoot` is included in the `balanceContainerRoot`
        /// - balanceContainerRoot
        /// |                            HEIGHT: BALANCE_TREE_HEIGHT
        /// -- balanceRoot
        uint256 balanceIndex = uint256(validatorIndex / 4);

        require(
            Merkle.verifyInclusionSha256({
                proof: proof.proof,
                root: balanceContainerRoot,
                leaf: proof.balanceRoot,
                index: balanceIndex
            }),
            InvalidProof()
        );

        /// Extract the individual validator's balance from the `balanceRoot`
        return getBalanceAtIndex(proof.balanceRoot, validatorIndex);
    }

    /**
     * @notice Parses a balanceRoot to get the uint64 balance of a validator.
     * @dev During merkleization of the beacon state balance tree, four uint64 values are treated as a single
     * leaf in the merkle tree. We use validatorIndex % 4 to determine which of the four uint64 values to
     * extract from the balanceRoot.
     * @param balanceRoot is the combination of 4 validator balances being proven for
     * @param validatorIndex is the index of the validator being proven for
     * @return The validator's balance, in Gwei
     */
    function getBalanceAtIndex(bytes32 balanceRoot, uint40 validatorIndex) internal pure returns (uint64) {
        uint256 bitShiftAmount = (validatorIndex % 4) * 64;
        return Endian.fromLittleEndianUint64(bytes32((uint256(balanceRoot) << bitShiftAmount)));
    }

    /// @notice Indices for fields in the `Validator` container:
    /// 0: pubkey
    /// 1: withdrawal credentials
    /// 2: effective balance
    /// 3: slashed?
    /// 4: activation eligibility epoch
    /// 5: activation epoch
    /// 6: exit epoch
    /// 7: withdrawable epoch
    ///
    /// (See https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator)

    /// @dev Retrieves a validator's pubkey hash
    function getPubkeyHash(
        bytes32[] memory validatorFields
    ) internal pure returns (bytes32) {
        return validatorFields[VALIDATOR_PUBKEY_INDEX];
    }

    /// @dev Retrieves a validator's withdrawal credentials
    function getWithdrawalCredentials(
        bytes32[] memory validatorFields
    ) internal pure returns (bytes32) {
        return validatorFields[VALIDATOR_WITHDRAWAL_CREDENTIALS_INDEX];
    }

    /// @dev Retrieves a validator's effective balance (in gwei)
    function getEffectiveBalanceGwei(
        bytes32[] memory validatorFields
    ) internal pure returns (uint64) {
        return Endian.fromLittleEndianUint64(validatorFields[VALIDATOR_BALANCE_INDEX]);
    }

    /// @dev Retrieves a validator's activation epoch
    function getActivationEpoch(
        bytes32[] memory validatorFields
    ) internal pure returns (uint64) {
        return Endian.fromLittleEndianUint64(validatorFields[VALIDATOR_ACTIVATION_EPOCH_INDEX]);
    }

    /// @dev Retrieves true IFF a validator is marked slashed
    function isValidatorSlashed(
        bytes32[] memory validatorFields
    ) internal pure returns (bool) {
        return validatorFields[VALIDATOR_SLASHED_INDEX] != 0;
    }

    /// @dev Retrieves a validator's exit epoch
    function getExitEpoch(
        bytes32[] memory validatorFields
    ) internal pure returns (uint64) {
        return Endian.fromLittleEndianUint64(validatorFields[VALIDATOR_EXIT_EPOCH_INDEX]);
    }

    /// @dev We check if the proofTimestamp is <= pectraForkTimestamp because a `proofTimestamp` at the `pectraForkTimestamp`
    ///      is considered to be Pre-Pectra given the EIP-4788 oracle returns the parent block.
    function getBeaconStateTreeHeight(
        ProofVersion proofVersion
    ) internal pure returns (uint256) {
        return proofVersion == ProofVersion.DENEB ? DENEB_BEACON_STATE_TREE_HEIGHT : PECTRA_BEACON_STATE_TREE_HEIGHT;
    }
}

// SPDX-License-Identifier: MIT
// Adapted from OpenZeppelin Contracts (last updated v4.8.0) (utils/cryptography/MerkleProof.sol)

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle Tree proofs.
 *
 * The tree and the proofs can be generated using our
 * https://github.com/OpenZeppelin/merkle-tree[JavaScript library].
 * You will find a quickstart guide in the readme.
 *
 * WARNING: You should avoid using leaf values that are 64 bytes long prior to
 * hashing, or use a hash function other than keccak256 for hashing leaves.
 * This is because the concatenation of a sorted pair of internal nodes in
 * the merkle tree could be reinterpreted as a leaf value.
 * OpenZeppelin's JavaScript library generates merkle trees that are safe
 * against this attack out of the box.
 */
library Merkle {
    error InvalidProofLength();

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. The tree is built assuming `leaf` is
     * the 0 indexed `index`'th leaf from the bottom left of the tree.
     *
     * Note this is for a Merkle tree using the keccak/sha3 hash function
     */
    function verifyInclusionKeccak(
        bytes memory proof,
        bytes32 root,
        bytes32 leaf,
        uint256 index
    ) internal pure returns (bool) {
        return processInclusionProofKeccak(proof, leaf, index) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. The tree is built assuming `leaf` is
     * the 0 indexed `index`'th leaf from the bottom left of the tree.
     * @dev If the proof length is 0 then the leaf hash is returned.
     *
     * _Available since v4.4._
     *
     * Note this is for a Merkle tree using the keccak/sha3 hash function
     */
    function processInclusionProofKeccak(
        bytes memory proof,
        bytes32 leaf,
        uint256 index
    ) internal pure returns (bytes32) {
        require(proof.length % 32 == 0, InvalidProofLength());
        bytes32 computedHash = leaf;
        for (uint256 i = 32; i <= proof.length; i += 32) {
            if (index % 2 == 0) {
                // if ith bit of index is 0, then computedHash is a left sibling
                assembly {
                    mstore(0x00, computedHash)
                    mstore(0x20, mload(add(proof, i)))
                    computedHash := keccak256(0x00, 0x40)
                    index := div(index, 2)
                }
            } else {
                // if ith bit of index is 1, then computedHash is a right sibling
                assembly {
                    mstore(0x00, mload(add(proof, i)))
                    mstore(0x20, computedHash)
                    computedHash := keccak256(0x00, 0x40)
                    index := div(index, 2)
                }
            }
        }
        return computedHash;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. The tree is built assuming `leaf` is
     * the 0 indexed `index`'th leaf from the bottom left of the tree.
     *
     * Note this is for a Merkle tree using the sha256 hash function
     */
    function verifyInclusionSha256(
        bytes memory proof,
        bytes32 root,
        bytes32 leaf,
        uint256 index
    ) internal view returns (bool) {
        return processInclusionProofSha256(proof, leaf, index) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. The tree is built assuming `leaf` is
     * the 0 indexed `index`'th leaf from the bottom left of the tree.
     *
     * _Available since v4.4._
     *
     * Note this is for a Merkle tree using the sha256 hash function
     */
    function processInclusionProofSha256(
        bytes memory proof,
        bytes32 leaf,
        uint256 index
    ) internal view returns (bytes32) {
        require(proof.length != 0 && proof.length % 32 == 0, InvalidProofLength());
        bytes32[1] memory computedHash = [leaf];
        for (uint256 i = 32; i <= proof.length; i += 32) {
            if (index % 2 == 0) {
                // if ith bit of index is 0, then computedHash is a left sibling
                assembly {
                    mstore(0x00, mload(computedHash))
                    mstore(0x20, mload(add(proof, i)))
                    if iszero(staticcall(sub(gas(), 2000), 2, 0x00, 0x40, computedHash, 0x20)) { revert(0, 0) }
                    index := div(index, 2)
                }
            } else {
                // if ith bit of index is 1, then computedHash is a right sibling
                assembly {
                    mstore(0x00, mload(add(proof, i)))
                    mstore(0x20, mload(computedHash))
                    if iszero(staticcall(sub(gas(), 2000), 2, 0x00, 0x40, computedHash, 0x20)) { revert(0, 0) }
                    index := div(index, 2)
                }
            }
        }
        return computedHash[0];
    }

    /**
     * @notice this function returns the merkle root of a tree created from a set of leaves using sha256 as its hash function
     *  @param leaves the leaves of the merkle tree
     *  @return The computed Merkle root of the tree.
     *  @dev A pre-condition to this function is that leaves.length is a power of two.  If not, the function will merkleize the inputs incorrectly.
     */
    function merkleizeSha256(
        bytes32[] memory leaves
    ) internal pure returns (bytes32) {
        //there are half as many nodes in the layer above the leaves
        uint256 numNodesInLayer = leaves.length / 2;
        //create a layer to store the internal nodes
        bytes32[] memory layer = new bytes32[](numNodesInLayer);
        //fill the layer with the pairwise hashes of the leaves
        for (uint256 i = 0; i < numNodesInLayer; i++) {
            layer[i] = sha256(abi.encodePacked(leaves[2 * i], leaves[2 * i + 1]));
        }
        //the next layer above has half as many nodes
        numNodesInLayer /= 2;
        //while we haven't computed the root
        while (numNodesInLayer != 0) {
            //overwrite the first numNodesInLayer nodes in layer with the pairwise hashes of their children
            for (uint256 i = 0; i < numNodesInLayer; i++) {
                layer[i] = sha256(abi.encodePacked(layer[2 * i], layer[2 * i + 1]));
            }
            //the next layer above has half as many nodes
            numNodesInLayer /= 2;
        }
        //the first node in the layer is the root
        return layer[0];
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library Endian {
    /**
     * @notice Converts a little endian-formatted uint64 to a big endian-formatted uint64
     * @param lenum little endian-formatted uint64 input, provided as 'bytes32' type
     * @return n The big endian-formatted uint64
     * @dev Note that the input is formatted as a 'bytes32' type (i.e. 256 bits), but it is immediately truncated to a uint64 (i.e. 64 bits)
     * through a right-shift/shr operation.
     */
    function fromLittleEndianUint64(
        bytes32 lenum
    ) internal pure returns (uint64 n) {
        // the number needs to be stored in little-endian encoding (ie in bytes 0-8)
        n = uint64(uint256(lenum >> 192));
        // forgefmt: disable-next-item
        return (n >> 56) | 
            ((0x00FF000000000000 & n) >> 40) | 
            ((0x0000FF0000000000 & n) >> 24) | 
            ((0x000000FF00000000 & n) >> 8)  | 
            ((0x00000000FF000000 & n) << 8)  | 
            ((0x0000000000FF0000 & n) << 24) | 
            ((0x000000000000FF00 & n) << 40) | 
            ((0x00000000000000FF & n) << 56);
    }
}

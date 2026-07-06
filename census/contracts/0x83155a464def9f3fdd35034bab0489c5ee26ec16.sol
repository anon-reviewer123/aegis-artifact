// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface IERC20Metadata is IERC20 {
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
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
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
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
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
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IReserve} from "./IReserve.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDecentralizedEURO is IERC20 {
    function suggestMinter(
        address _minter,
        uint256 _applicationPeriod,
        uint256 _applicationFee,
        string calldata _message
    ) external;

    function registerPosition(address position) external;

    function denyMinter(address minter, address[] calldata helpers, string calldata message) external;

    function reserve() external view returns (IReserve);

    function minterReserve() external view returns (uint256);

    function calculateAssignedReserve(uint256 mintedAmount, uint32 _reservePPM) external view returns (uint256);

    function calculateFreedAmount(uint256 amountExcludingReserve, uint32 reservePPM) external view returns (uint256);

    function equity() external view returns (uint256);

    function isMinter(address minter) external view returns (bool);

    function getPositionParent(address position) external view returns (address);

    function mint(address target, uint256 amount) external;

    function mintWithReserve(address target, uint256 amount, uint32 reservePPM, uint32 feePPM) external;

    function burnFrom(address target, uint256 amount) external;

    function burnWithoutReserve(uint256 amountIncludingReserve, uint32 reservePPM) external;

    function burnFromWithReserve(
        address payer,
        uint256 targetTotalBurnAmount,
        uint32 _reservePPM
    ) external returns (uint256);

    function burnWithReserve(uint256 amountExcludingReserve, uint32 reservePPM) external returns (uint256);

    function coverLoss(address source, uint256 amount) external;

    function collectProfits(address source, uint256 _amount) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IReserve is IERC20 {
    function invest(uint256 amount, uint256 expected) external returns (uint256);
    function checkQualified(address sender, address[] calldata helpers) external view;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IDecentralizedEURO} from "./interface/IDecentralizedEURO.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title Stablecoin Bridge
 * @notice A minting contract for another Euro stablecoin ('source stablecoin') that we trust.
 */
contract StablecoinBridge {
    IERC20 public immutable eur; // the source stablecoin
    IDecentralizedEURO public immutable dEURO; // the dEURO
    uint8 private immutable eurDecimals;
    uint8 private immutable dEURODecimals;

    /**
     * @notice The time horizon after which this bridge expires and needs to be replaced by a new contract.
     */
    uint256 public immutable horizon;

    /**
     * @notice The maximum amount of outstanding converted source stablecoins.
     */
    uint256 public immutable limit;
    uint256 public minted;

    error Limit(uint256 amount, uint256 limit);
    error Expired(uint256 time, uint256 expiration);
    error UnsupportedToken(address token);

    constructor(address other, address dEUROAddress, uint256 limit_, uint256 weeks_) {
        eur = IERC20(other);
        dEURO = IDecentralizedEURO(dEUROAddress);
        eurDecimals = IERC20Metadata(other).decimals();
        dEURODecimals = IERC20Metadata(dEUROAddress).decimals();
        horizon = block.timestamp + weeks_ * 1 weeks;
        limit = limit_;
        minted = 0;
    }

    /**
     * @notice Convenience method for mint(msg.sender, amount)
     */
    function mint(uint256 amount) external {
        mintTo(msg.sender, amount);
    }

    /**
     * @notice Mint the target amount of dEUROs, taking the equal amount of source coins from the sender.
     * @dev This only works if an allowance for the source coins has been set and the caller has enough of them.
     * @param amount The amount of the source stablecoin to bridge (convert).
     */
    function mintTo(address target, uint256 amount) public {
        eur.transferFrom(msg.sender, address(this), amount);
        
        uint256 targetAmount = _convertAmount(amount, eurDecimals, dEURODecimals);
        _mint(target, targetAmount);
    }

    function _mint(address target, uint256 amount) internal {
        if (block.timestamp > horizon) revert Expired(block.timestamp, horizon);
        dEURO.mint(target, amount);
        minted += amount;
        if (minted > limit) revert Limit(amount, limit);
    }

    /**
     * @notice Convenience method for burnAndSend(msg.sender, amount)
     * @param amount The amount of dEURO to burn.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, msg.sender, amount);
    }

    /**
     * @notice Burn the indicated amount of dEURO and send the same number of source coins to the caller.
     */
    function burnAndSend(address target, uint256 amount) external {
        _burn(msg.sender, target, amount);
    }

    function _burn(address dEUROHolder, address target, uint256 amount) internal {
        uint256 sourceAmount = _convertAmount(amount, dEURODecimals, eurDecimals);
        dEURO.burnFrom(dEUROHolder, amount);
        eur.transfer(target, sourceAmount);
        minted -= amount;
    }

    /**
     * @notice Converts an amount between two tokens with different decimal places.
     * @param amount The amount to convert.
     * @param fromDecimals The decimal places of the source token.
     * @param toDecimals The decimal places of the target token.
     */
    function _convertAmount(uint256 amount, uint8 fromDecimals, uint8 toDecimals) internal pure returns (uint256) {
        if (fromDecimals < toDecimals) {
            return amount * 10**(toDecimals - fromDecimals);
        } else if (fromDecimals > toDecimals) {
            return amount / 10**(fromDecimals - toDecimals);
        } else {
            return amount;
        }
    }
}
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

pragma solidity >=0.4.16;

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
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Z4GPresale {
    IERC20 public immutable z4gToken;
    address public immutable vault;
    uint256 public immutable pricePerTokenWei; // price for 1 Z4G (1e18 units) in wei

    uint64 public immutable startTime;
    uint64 public immutable endTime;

    uint256 public totalSold;
    bool public finalized;

    event Purchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event Finalized(uint256 burnedAmount);

    constructor(
        address _z4gToken,
        address _vault,
        uint256 _pricePerTokenWei,
        uint64 _startTime,
        uint64 _endTime
    ) {
        require(_z4gToken != address(0), "Z4G token address is zero");
        require(_vault != address(0), "Vault address is zero");
        require(_pricePerTokenWei > 0, "Price must be > 0");
        require(_endTime > _startTime, "endTime must be after startTime");

        z4gToken = IERC20(_z4gToken);
        vault = _vault;
        pricePerTokenWei = _pricePerTokenWei;
        startTime = _startTime;
        endTime = _endTime;
    }

    modifier onlyWhileOpen() {
        require(block.timestamp >= startTime, "Presale not started");
        require(block.timestamp <= endTime, "Presale ended");
        _;
    }

    modifier onlyAfterEnd() {
        require(block.timestamp > endTime, "Presale not ended");
        _;
    }

    function remainingTokens() public view returns (uint256) {
        return z4gToken.balanceOf(address(this));
    }

    function buy() public payable onlyWhileOpen {
        require(msg.value > 0, "No ETH sent");

        uint256 tokens = (msg.value * 1e18) / pricePerTokenWei;
        require(tokens > 0, "ETH too low for 1 token");

        uint256 available = remainingTokens();
        require(available >= tokens, "Not enough tokens left");

        totalSold += tokens;

        bool okToken = z4gToken.transfer(msg.sender, tokens);
        require(okToken, "Token transfer failed");

        (bool okEth, ) = payable(vault).call{value: msg.value}("");
        require(okEth, "ETH forward failed");

        emit Purchased(msg.sender, msg.value, tokens);
    }

    function finalize() external onlyAfterEnd {
        require(!finalized, "Already finalized");
        finalized = true;

        uint256 leftover = remainingTokens();
        if (leftover > 0) {
            bool ok = z4gToken.transfer(address(0), leftover);
            require(ok, "Burn transfer failed");
        }

        emit Finalized(leftover);
    }

    receive() external payable {
        buy();
    }
}

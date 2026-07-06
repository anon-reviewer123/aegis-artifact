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
pragma solidity 0.8.19;

import {IPriceFeed, IAggregatorV3Interface} from "../interfaces/IPriceFeed.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {BimaMath} from "../dependencies/BimaMath.sol";
import {BimaOwnable} from "../dependencies/BimaOwnable.sol";
import {BIMA_DECIMAL_PRECISION} from "../dependencies/Constants.sol";

/**
    @title Bima Multi Token Price Feed
    @notice Based on Gravita's PriceFeed:
            https://github.com/Gravita-Protocol/Gravita-SmartContracts/blob/9b69d555f3567622b0f84df8c7f1bb5cd9323573/contracts/PriceFeed.sol

            Bima's implementation additionally caches price values within a block and incorporates exchange rate settings for derivative tokens (e.g. stETH -> wstETH).
 */
contract PriceFeed is IPriceFeed, BimaOwnable {
    struct OracleRecord {
        IAggregatorV3Interface chainLinkOracle;
        uint8 decimals;
        uint32 heartbeat;
        bytes4 sharePriceSignature;
        uint8 sharePriceDecimals;
        bool isFeedWorking;
        bool isEthIndexed;
    }

    struct PriceRecord {
        uint96 scaledPrice;
        uint32 timestamp;
        uint32 lastUpdated;
        uint80 roundId;
    }

    struct FeedResponse {
        uint80 roundId;
        int256 answer;
        uint256 timestamp;
        bool success;
    }

    // Custom Errors --------------------------------------------------------------------------------------------------

    error PriceFeed__InvalidFeedResponseError(address token);
    error PriceFeed__FeedFrozenError(address token);
    error PriceFeed__UnknownFeedError(address token);

    // Events ---------------------------------------------------------------------------------------------------------

    event NewOracleRegistered(address token, address chainlinkAggregator, bool isEthIndexed);
    event PriceFeedStatusUpdated(address token, address oracle, bool isWorking);
    event PriceRecordUpdated(address indexed token, uint256 _price);

    /** Constants ---------------------------------------------------------------------------------------------------- */

    // Used to convert a chainlink price answer to an 18-digit precision uint
    uint256 public constant TARGET_DIGITS = 18;

    // Maximum deviation allowed between two consecutive Chainlink oracle prices. 18-digit precision.
    uint256 public constant MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND = 5e17; // 50%

    // State ------------------------------------------------------------------------------------------------------------

    mapping(address => OracleRecord) public oracleRecords;
    mapping(address => PriceRecord) public priceRecords;

    constructor(address _bimaCore) BimaOwnable(_bimaCore) {}

    // Admin routines ---------------------------------------------------------------------------------------------------

    /**
        @notice Set the oracle for a specific token
        @param _token Address of the LST to set the oracle for
        @param _chainlinkOracle Address of the chainlink oracle for this LST
        @param _heartbeat Oracle heartbeat, in seconds
        @param sharePriceSignature Four byte function selector to be used when calling `_collateral`, in order to obtain the share price
        @param sharePriceDecimals Decimal precision used in the returned share price
        @param _isEthIndexed True if the base currency is ETH
     */
    function setOracle(
        address _token,
        address _chainlinkOracle,
        uint32 _heartbeat,
        bytes4 sharePriceSignature,
        uint8 sharePriceDecimals,
        bool _isEthIndexed
    ) public onlyOwner {
        IAggregatorV3Interface newFeed = IAggregatorV3Interface(_chainlinkOracle);
        (FeedResponse memory currResponse, FeedResponse memory prevResponse, ) = _fetchFeedResponses(newFeed, 0);

        if (!_isFeedWorking(currResponse, prevResponse)) {
            revert PriceFeed__InvalidFeedResponseError(_token);
        }
        if (_isPriceStale(currResponse.timestamp, _heartbeat)) {
            revert PriceFeed__FeedFrozenError(_token);
        }

        OracleRecord memory record = OracleRecord({
            chainLinkOracle: newFeed,
            decimals: newFeed.decimals(),
            heartbeat: _heartbeat,
            sharePriceSignature: sharePriceSignature,
            sharePriceDecimals: sharePriceDecimals,
            isFeedWorking: true,
            isEthIndexed: _isEthIndexed
        });

        oracleRecords[_token] = record;
        PriceRecord memory _priceRecord = priceRecords[_token];

        _processFeedResponses(_token, record, currResponse, prevResponse, _priceRecord);
        emit NewOracleRegistered(_token, _chainlinkOracle, _isEthIndexed);
    }

    // Public functions -------------------------------------------------------------------------------------------------

    /**
        @notice Get the latest price returned from the oracle
        @dev You can obtain these values by calling `TroveManager.fetchPrice()`
             rather than directly interacting with this contract.
        @param _token Token to fetch the price for
        @return price The latest valid price for the requested token
     */
    function fetchPrice(address _token) public returns (uint256 price) {
        PriceRecord memory priceRecord = priceRecords[_token];

        if (priceRecord.lastUpdated == block.timestamp) {
            // We short-circuit only if the price was already correct in the current block
            price = priceRecord.scaledPrice;
        } else {
            if (priceRecord.lastUpdated == 0) {
                revert PriceFeed__UnknownFeedError(_token);
            }

            OracleRecord storage oracle = oracleRecords[_token];

            (FeedResponse memory currResponse, FeedResponse memory prevResponse, bool updated) = _fetchFeedResponses(
                oracle.chainLinkOracle,
                priceRecord.roundId
            );

            if (!updated) {
                if (_isPriceStale(priceRecord.timestamp, oracle.heartbeat)) {
                    revert PriceFeed__FeedFrozenError(_token);
                }
                price = priceRecord.scaledPrice;
            } else {
                price = _processFeedResponses(_token, oracle, currResponse, prevResponse, priceRecord);
            }
        }
    }

    // Internal functions -----------------------------------------------------------------------------------------------

    function _processFeedResponses(
        address _token,
        OracleRecord memory oracle,
        FeedResponse memory _currResponse,
        FeedResponse memory _prevResponse,
        PriceRecord memory priceRecord
    ) internal returns (uint256 scaledPrice) {
        uint8 decimals = oracle.decimals;
        bool isValidResponse = _isFeedWorking(_currResponse, _prevResponse) &&
            !_isPriceStale(_currResponse.timestamp, oracle.heartbeat) &&
            !_isPriceChangeAboveMaxDeviation(_currResponse, _prevResponse, decimals);

        if (isValidResponse) {
            scaledPrice = _scalePriceByDigits(uint256(_currResponse.answer), decimals);

            if (oracle.sharePriceSignature != 0) {
                (bool success, bytes memory returnData) = _token.staticcall(abi.encode(oracle.sharePriceSignature));
                require(success, "Share price not available");
                scaledPrice = (scaledPrice * abi.decode(returnData, (uint256))) / (10 ** oracle.sharePriceDecimals);
            }
            if (oracle.isEthIndexed) {
                // Oracle returns ETH price, need to convert to USD
                scaledPrice = _calcEthPrice(scaledPrice);
            }
            if (!oracle.isFeedWorking) {
                _updateFeedStatus(_token, oracle, true);
            }
            _storePrice(_token, scaledPrice, _currResponse.timestamp, _currResponse.roundId);
        } else {
            if (oracle.isFeedWorking) {
                _updateFeedStatus(_token, oracle, false);
            }
            if (_isPriceStale(priceRecord.timestamp, oracle.heartbeat)) {
                revert PriceFeed__FeedFrozenError(_token);
            }
            scaledPrice = priceRecord.scaledPrice;
        }
    }

    function _calcEthPrice(uint256 ethAmount) internal returns (uint256 price) {
        uint256 ethPrice = fetchPrice(address(0));
        price = (ethPrice * ethAmount) / 1 ether;
    }

    function _fetchFeedResponses(
        IAggregatorV3Interface oracle,
        uint80 lastRoundId
    ) internal view returns (FeedResponse memory currResponse, FeedResponse memory prevResponse, bool updated) {
        currResponse = _fetchCurrentFeedResponse(oracle);
        if (lastRoundId == 0 || currResponse.roundId > lastRoundId) {
            prevResponse = _fetchPrevFeedResponse(oracle, currResponse.roundId);
            updated = true;
        }
    }

    function _isPriceStale(uint256 _priceTimestamp, uint256 _heartbeat) internal view returns (bool isPriceStale) {
        isPriceStale = block.timestamp - _priceTimestamp > _heartbeat;
    }

    function _isFeedWorking(
        FeedResponse memory _currentResponse,
        FeedResponse memory _prevResponse
    ) internal view returns (bool isFeedWorking) {
        isFeedWorking = _isValidResponse(_currentResponse) && _isValidResponse(_prevResponse);
    }

    function _isValidResponse(FeedResponse memory _response) internal view returns (bool isValidResponse) {
        isValidResponse =
            (_response.success) &&
            (_response.roundId != 0) &&
            (_response.timestamp != 0) &&
            (_response.timestamp <= block.timestamp) &&
            (_response.answer != 0);
    }

    function _isPriceChangeAboveMaxDeviation(
        FeedResponse memory _currResponse,
        FeedResponse memory _prevResponse,
        uint8 decimals
    ) internal pure returns (bool isPriceChangeAboveMaxDeviation) {
        uint256 currentScaledPrice = _scalePriceByDigits(uint256(_currResponse.answer), decimals);
        uint256 prevScaledPrice = _scalePriceByDigits(uint256(_prevResponse.answer), decimals);

        uint256 minPrice = BimaMath._min(currentScaledPrice, prevScaledPrice);
        uint256 maxPrice = BimaMath._max(currentScaledPrice, prevScaledPrice);

        /*
         * Use the larger price as the denominator:
         * - If price decreased, the percentage deviation is in relation to the previous price.
         * - If price increased, the percentage deviation is in relation to the current price.
         */
        uint256 percentDeviation = ((maxPrice - minPrice) * BIMA_DECIMAL_PRECISION) / maxPrice;

        isPriceChangeAboveMaxDeviation = percentDeviation > MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND;
    }

    function _scalePriceByDigits(uint256 _price, uint256 _answerDigits) internal pure returns (uint256 scaledPrice) {
        if (_answerDigits == TARGET_DIGITS) {
            scaledPrice = _price;
        } else if (_answerDigits < TARGET_DIGITS) {
            // Scale the returned price value up to target precision
            scaledPrice = _price * (10 ** (TARGET_DIGITS - _answerDigits));
        } else {
            // Scale the returned price value down to target precision
            scaledPrice = _price / (10 ** (_answerDigits - TARGET_DIGITS));
        }
    }

    function _updateFeedStatus(address _token, OracleRecord memory _oracle, bool _isWorking) internal {
        oracleRecords[_token].isFeedWorking = _isWorking;
        emit PriceFeedStatusUpdated(_token, address(_oracle.chainLinkOracle), _isWorking);
    }

    function _storePrice(address _token, uint256 _price, uint256 _timestamp, uint80 roundId) internal {
        priceRecords[_token] = PriceRecord({
            scaledPrice: uint96(_price),
            timestamp: uint32(_timestamp),
            lastUpdated: uint32(block.timestamp),
            roundId: roundId
        });
        emit PriceRecordUpdated(_token, _price);
    }

    function _fetchCurrentFeedResponse(
        IAggregatorV3Interface _priceAggregator
    ) internal view returns (FeedResponse memory response) {
        try _priceAggregator.latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256 /* startedAt */,
            uint256 timestamp,
            uint80 /* answeredInRound */
        ) {
            // If call to Chainlink succeeds, return the response and success = true
            response.roundId = roundId;
            response.answer = answer;
            response.timestamp = timestamp;
            response.success = true;
        } catch {
            // If call to Chainlink aggregator reverts
            // return default zero response with success = false
        }
    }

    function _fetchPrevFeedResponse(
        IAggregatorV3Interface _priceAggregator,
        uint80 _currentRoundId
    ) internal view returns (FeedResponse memory prevResponse) {
        if (_currentRoundId != 0) {
            unchecked {
                try _priceAggregator.getRoundData(_currentRoundId - 1) returns (
                    uint80 roundId,
                    int256 answer,
                    uint256 /* startedAt */,
                    uint256 timestamp,
                    uint80 /* answeredInRound */
                ) {
                    prevResponse.roundId = roundId;
                    prevResponse.answer = answer;
                    prevResponse.timestamp = timestamp;
                    prevResponse.success = true;
                } catch {}
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {BIMA_DECIMAL_PRECISION} from "./Constants.sol";

library BimaMath {
    /* Precision for Nominal ICR (independent of price). Rationale for the value:
     *
     * - Making it “too high” could lead to overflows.
     * - Making it “too low” could lead to an ICR equal to zero, due to truncation from Solidity floor division.
     *
     * This value of 1e20 is chosen for safety: the NICR will only overflow for numerator > ~1e39,
     * and will only truncate to 0 if the denominator is at least 1e20 times greater than the numerator.
     *
     */
    uint256 internal constant NICR_PRECISION = 1e20;

    function _min(uint256 _a, uint256 _b) internal pure returns (uint256 result) {
        result = (_a < _b) ? _a : _b;
    }

    function _max(uint256 _a, uint256 _b) internal pure returns (uint256 result) {
        result = (_a >= _b) ? _a : _b;
    }

    /*
     * Multiply two decimal numbers and use normal rounding rules:
     * -round product up if 19'th mantissa digit >= 5
     * -round product down if 19'th mantissa digit < 5
     *
     * Used only inside the exponentiation, _decPow().
     */
    function decMul(uint256 x, uint256 y) internal pure returns (uint256 decProd) {
        uint256 prod_xy = x * y;

        decProd = (prod_xy + (BIMA_DECIMAL_PRECISION / 2)) / BIMA_DECIMAL_PRECISION;
    }

    /*
     * _decPow: Exponentiation function for 18-digit decimal base, and integer exponent n.
     *
     * Uses the efficient "exponentiation by squaring" algorithm. O(log(n)) complexity.
     *
     * Called by two functions that represent time in units of minutes:
     * 1) TroveManager._calcDecayedBaseRate
     * 2) CommunityIssuance._getCumulativeIssuanceFraction
     *
     * The exponent is capped to avoid reverting due to overflow. The cap 525600000 equals
     * "minutes in 1000 years": 60 * 24 * 365 * 1000
     *
     * If a period of > 1000 years is ever used as an exponent in either of the above functions, the result will be
     * negligibly different from just passing the cap, since:
     *
     * In function 1), the decayed base rate will be 0 for 1000 years or > 1000 years
     * In function 2), the difference in tokens issued at 1000 years and any time > 1000 years, will be negligible
     */
    function _decPow(uint256 _base, uint256 _minutes) internal pure returns (uint256 result) {
        if (_minutes > 525600000) {
            _minutes = 525600000;
        } // cap to avoid overflow

        if (_minutes == 0) {
            result = BIMA_DECIMAL_PRECISION;
        } else {
            uint256 y = BIMA_DECIMAL_PRECISION;
            uint256 x = _base;
            uint256 n = _minutes;

            // Exponentiation-by-squaring
            while (n > 1) {
                if (n % 2 == 0) {
                    x = decMul(x, x);
                    n = n / 2;
                } else {
                    // if (n % 2 != 0)
                    y = decMul(x, y);
                    x = decMul(x, x);
                    n = (n - 1) / 2;
                }
            }

            result = decMul(x, y);
        }
    }

    function _getAbsoluteDifference(uint256 _a, uint256 _b) internal pure returns (uint256 result) {
        result = (_a >= _b) ? _a - _b : _b - _a;
    }

    function _computeNominalCR(uint256 _coll, uint256 _debt) internal pure returns (uint256 result) {
        if (_debt > 0) {
            result = (_coll * NICR_PRECISION) / _debt;
        }
        // Return the maximal value for uint256 if the Trove has a debt of 0. Represents "infinite" CR.
        else {
            // if (_debt == 0)
            result = 2 ** 256 - 1;
        }
    }

    function _computeCR(uint256 _coll, uint256 _debt, uint256 _price) internal pure returns (uint256 result) {
        if (_debt > 0) {
            result = (_coll * _price) / _debt;
        }
        // Return the maximal value for uint256 if the Trove has a debt of 0. Represents "infinite" CR.
        else {
            // if (_debt == 0)
            result = 2 ** 256 - 1;
        }
    }

    function _computeCR(uint256 _coll, uint256 _debt) internal pure returns (uint256 result) {
        if (_debt > 0) {
            result = (_coll) / _debt;
        }
        // Return the maximal value for uint256 if the Trove has a debt of 0. Represents "infinite" CR.
        else {
            // if (_debt == 0)
            result = 2 ** 256 - 1;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IBimaCore} from "../interfaces/IBimaCore.sol";
import {IBimaOwnable} from "../interfaces/IEmissionSchedule.sol";

/**
    @title Bima Ownable
    @notice Contracts inheriting `BimaOwnable` have the same owner as `BimaCore`.
            The ownership cannot be independently modified or renounced.
 */
contract BimaOwnable is IBimaOwnable {
    IBimaCore public immutable BIMA_CORE;

    constructor(address _bimaCore) {
        BIMA_CORE = IBimaCore(_bimaCore);
    }

    modifier onlyOwner() {
        require(msg.sender == BIMA_CORE.owner(), "Only owner");
        _;
    }

    function owner() public view returns (address result) {
        result = BIMA_CORE.owner();
    }

    function guardian() public view returns (address result) {
        result = BIMA_CORE.guardian();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// represents 100% in BIMA used in denominator when
// calculating amounts based on a percentage
uint256 constant BIMA_100_PCT = 10_000;

// BIMA's default decimal precision
uint256 constant BIMA_DECIMAL_PRECISION = 1e18;

// BIMA's default scale factor
uint256 constant BIMA_SCALE_FACTOR = 1e9;

// BIMA's default reward duration
uint256 constant BIMA_REWARD_DURATION = 1 weeks;

// collateral tokens required decimals
uint8 constant BIMA_COLLATERAL_DECIMALS = 18;

// SPDX-License-Identifier: MIT
// Code from https://github.com/smartcontractkit/chainlink/blob/master/evm-contracts/src/v0.6/interfaces/AggregatorV3Interface.sol
pragma solidity 0.8.19;

interface IAggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IBimaCore {
    event FeeReceiverSet(address feeReceiver);
    event GuardianSet(address guardian);
    event NewOwnerAccepted(address oldOwner, address owner);
    event NewOwnerCommitted(address owner, address pendingOwner, uint256 deadline);
    event NewOwnerRevoked(address owner, address revokedOwner);
    event Paused();
    event PriceFeedSet(address priceFeed);
    event Unpaused();

    function acceptTransferOwnership() external;

    function commitTransferOwnership(address newOwner) external;

    function revokeTransferOwnership() external;

    function setFeeReceiver(address _feeReceiver) external;

    function setGuardian(address _guardian) external;

    function setPaused(bool _paused) external;

    function setPriceFeed(address _priceFeed) external;

    function OWNERSHIP_TRANSFER_DELAY() external view returns (uint256);

    function feeReceiver() external view returns (address);

    function guardian() external view returns (address);

    function owner() external view returns (address);

    function ownershipTransferDeadline() external view returns (uint256);

    function paused() external view returns (bool);

    function pendingOwner() external view returns (address);

    function priceFeed() external view returns (address);

    function startTime() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IBimaCore} from "./IBimaCore.sol";

interface IBimaOwnable {
    function BIMA_CORE() external view returns (IBimaCore);

    function owner() external view returns (address);

    function guardian() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IBimaToken {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload, bytes _reason);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ReceiveFromChain(uint16 indexed _srcChainId, address indexed _to, uint256 _amount);
    event RetryMessageSuccess(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes32 _payloadHash);
    event SendToChain(uint16 indexed _dstChainId, address indexed _from, bytes _toAddress, uint256 _amount);
    event SetMinDstGas(uint16 _dstChainId, uint16 _type, uint256 _minDstGas);
    event SetPrecrime(address precrime);
    event SetTrustedRemote(uint16 _remoteChainId, bytes _path);
    event SetTrustedRemoteAddress(uint16 _remoteChainId, bytes _remoteAddress);
    event SetUseCustomAdapterParams(bool _useCustomAdapterParams);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function approve(address spender, uint256 amount) external returns (bool);

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

    function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress) external;

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) external;

    function mintToVault(uint256 _totalSupply) external returns (bool);

    function nonblockingLzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) external;

    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function renounceOwnership() external;

    function setConfig(uint16 _version, uint16 _chainId, uint256 _configType, bytes calldata _config) external;

    function setMinDstGas(uint16 _dstChainId, uint16 _packetType, uint256 _minGas) external;

    function setPayloadSizeLimit(uint16 _dstChainId, uint256 _size) external;

    function setPrecrime(address _precrime) external;

    function setReceiveVersion(uint16 _version) external;

    function setSendVersion(uint16 _version) external;

    function setTrustedRemote(uint16 _srcChainId, bytes calldata _path) external;

    function setTrustedRemoteAddress(uint16 _remoteChainId, bytes calldata _remoteAddress) external;

    function setUseCustomAdapterParams(bool _useCustomAdapterParams) external;

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function transferOwnership(address newOwner) external;

    function transferToLocker(address sender, uint256 amount) external returns (bool);

    function retryMessage(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) external payable;

    function sendFrom(
        address _from,
        uint16 _dstChainId,
        bytes calldata _toAddress,
        uint256 _amount,
        address _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    ) external payable;

    function DEFAULT_PAYLOAD_SIZE_LIMIT() external view returns (uint256);

    function NO_EXTRA_GAS() external view returns (uint256);

    function PT_SEND() external view returns (uint16);

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function circulatingSupply() external view returns (uint256);

    function decimals() external view returns (uint8);

    function domainSeparator() external view returns (bytes32);

    function estimateSendFee(
        uint16 _dstChainId,
        bytes calldata _toAddress,
        uint256 _amount,
        bool _useZro,
        bytes calldata _adapterParams
    ) external view returns (uint256 nativeFee, uint256 zroFee);

    function failedMessages(uint16, bytes calldata, uint64) external view returns (bytes32);

    function getConfig(
        uint16 _version,
        uint16 _chainId,
        address,
        uint256 _configType
    ) external view returns (bytes memory);

    function getTrustedRemoteAddress(uint16 _remoteChainId) external view returns (bytes memory);

    function isTrustedRemote(uint16 _srcChainId, bytes calldata _srcAddress) external view returns (bool);

    function locker() external view returns (address);

    function lzEndpoint() external view returns (address);

    function maxTotalSupply() external view returns (uint256);

    function minDstGasLookup(uint16, uint16) external view returns (uint256);

    function name() external view returns (string memory);

    function nonces(address owner) external view returns (uint256);

    function owner() external view returns (address);

    function payloadSizeLimitLookup(uint16) external view returns (uint256);

    function permitTypeHash() external view returns (bytes32);

    function precrime() external view returns (address);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function symbol() external view returns (string memory);

    function token() external view returns (address);

    function totalSupply() external view returns (uint256);

    function trustedRemoteLookup(uint16) external view returns (bytes memory);

    function useCustomAdapterParams() external view returns (bool);

    function vault() external view returns (address);

    function version() external view returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISystemStart} from "./ISystemStart.sol";
import {ITokenLocker} from "../interfaces/ITokenLocker.sol";

interface IBoostCalculator is ISystemStart {
    function getBoostedAmountWrite(
        address account,
        uint256 amount,
        uint256 previousAmount,
        uint256 totalWeeklyEmissions
    ) external returns (uint256 adjustedAmount);

    function MAX_BOOST_GRACE_WEEKS() external view returns (uint256);

    function getBoostedAmount(
        address account,
        uint256 amount,
        uint256 previousAmount,
        uint256 totalWeeklyEmissions
    ) external view returns (uint256 adjustedAmount);

    function getClaimableWithBoost(
        address claimant,
        uint256 previousAmount,
        uint256 totalWeeklyEmissions
    ) external view returns (uint256 maxBoosted, uint256 boosted);

    function locker() external view returns (ITokenLocker);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
    @title Bima Boost Delegate Interface
    @notice When enabling boost delegation via `Vault.setBoostDelegationParams`,
            you may optionally set a `callback` contract. If set, it should adhere
            to the following interface.
 */
interface IBoostDelegate {
    /**
        @notice Get the current fee percent charged to use this boost delegate
        @dev Optional. Only called if the feePct is set to `type(uint16).max` when
             enabling delegation.
        @param claimant Address that will perform the claim
        @param amount Amount to be claimed (before applying boost or fee)
        @param previousAmount Previous amount claimed this week by this contract
        @param totalWeeklyEmissions Total weekly emissions released this week
        @return feePct Fee % charged for claims that use this contracts' delegated boost.
                      Given as a whole number out of 10000. If a claim would be rejected,
                      the preferred return value is `type(uint256).max`.
     */
    function getFeePct(
        address claimant,
        address receiver,
        uint256 amount,
        uint256 previousAmount,
        uint256 totalWeeklyEmissions
    ) external view returns (uint256 feePct);

    /**
        @notice Callback function for boost delegators
        @dev MUST BE INCLUDED. Called after each successful claim which used
             this contract's delegated boost.
        @param claimant Address that performed the claim
        @param amount Amount that claimed (before applying boost or fee)
        @param adjustedAmount Actual amount received by `claimant`
        @param fee Fee amount paid by `claimant`
        @param previousAmount Previous amount claimed this week by this contract
        @param totalWeeklyEmissions Total weekly emissions released this week
     */
    function delegatedBoostCallback(
        address claimant,
        address receiver,
        uint256 amount,
        uint256 adjustedAmount,
        uint256 fee,
        uint256 previousAmount,
        uint256 totalWeeklyEmissions
    ) external returns (bool success);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IDelegatedOps {

    function isApprovedDelegate(address owner, address caller) external view returns (bool isApproved);

    function setDelegateApproval(address _delegate, bool _isApproved) external;
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IBimaCore} from "./IBimaCore.sol";
import {IIncentiveVoting} from "./IIncentiveVoting.sol";
import {IBimaVault} from "./IVault.sol";
import {IBimaOwnable} from "./IBimaOwnable.sol";
import {ISystemStart} from "./ISystemStart.sol";

interface IEmissionSchedule is IBimaOwnable, ISystemStart {
    event LockParametersSet(uint256 lockWeeks, uint256 lockDecayWeeks);
    event WeeklyPctScheduleSet(uint64[2][] schedule);

    function getReceiverWeeklyEmissions(
        uint256 id,
        uint256 week,
        uint256 totalWeeklyEmissions
    ) external returns (uint256);

    function getTotalWeeklyEmissions(
        uint256 week,
        uint256 unallocatedTotal
    ) external returns (uint256 amount, uint64 lock);

    function setLockParameters(uint64 _lockWeeks, uint64 _lockDecayWeeks) external returns (bool);

    function setWeeklyPctSchedule(uint64[2][] calldata _schedule) external returns (bool);

    function MAX_LOCK_WEEKS() external view returns (uint256);

    function getWeeklyPctSchedule() external view returns (uint64[2][] memory);

    function lockDecayWeeks() external view returns (uint64);

    function lockWeeks() external view returns (uint64);

    function vault() external view returns (IBimaVault);

    function voter() external view returns (IIncentiveVoting);

    function weeklyPct() external view returns (uint64);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISystemStart} from "./ISystemStart.sol";
import {IDelegatedOps} from "./IDelegatedOps.sol";
import {ITokenLocker} from "./ITokenLocker.sol";

interface IIncentiveVoting is ISystemStart, IDelegatedOps {
    struct Vote {
        uint256 id;
        uint256 points;
    }

    event AccountWeightRegistered(
        address indexed account,
        uint256 indexed week,
        uint256 frozenBalance,
        ITokenLocker.LockData[] registeredLockData
    );
    event ClearedVotes(address indexed account, uint256 indexed week);
    event NewVotes(address indexed account, uint256 indexed week, Vote[] newVotes, uint256 totalPointsUsed);

    function clearRegisteredWeight(address account) external returns (bool);

    function clearVote(address account) external;

    function getReceiverVoteInputs(uint256 id, uint256 week) external returns (uint256, uint256);

    function getReceiverWeightWrite(uint256 idx) external returns (uint256);

    function getTotalWeightWrite() external returns (uint256);

    function registerAccountWeight(address account, uint256 minWeeks) external;

    function registerAccountWeightAndVote(address account, uint256 minWeeks, Vote[] calldata votes) external;

    function registerNewReceiver() external returns (uint256);

    function unfreeze(address account, bool keepVote) external returns (bool);

    function vote(address account, Vote[] calldata votes, bool clearPrevious) external;

    function MAX_LOCK_WEEKS() external view returns (uint256);

    function MAX_POINTS() external view returns (uint256);

    function getAccountCurrentVotes(address account) external view returns (Vote[] memory votes);

    function getAccountRegisteredLocks(
        address account
    ) external view returns (uint256 frozenWeight, ITokenLocker.LockData[] memory lockData);

    function getReceiverWeight(uint256 idx) external view returns (uint256);

    function getReceiverWeightAt(uint256 idx, uint256 week) external view returns (uint256);

    function getTotalWeight() external view returns (uint256);

    function getTotalWeightAt(uint256 week) external view returns (uint256);

    function receiverCount() external view returns (uint256);

    function receiverDecayRate(uint256) external view returns (uint32);

    function receiverUpdatedWeek(uint256) external view returns (uint16);

    function receiverWeeklyUnlocks(uint256, uint256) external view returns (uint32);

    function tokenLocker() external view returns (ITokenLocker);

    function totalDecayRate() external view returns (uint32);

    function totalUpdatedWeek() external view returns (uint16);

    function totalWeeklyUnlocks(uint256) external view returns (uint32);

    function vault() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IBimaOwnable} from "./IBimaOwnable.sol";
import {IAggregatorV3Interface} from "./IAggregatorV3Interface.sol";

interface IPriceFeed is IBimaOwnable {
    function fetchPrice(address _token) external returns (uint256);

    function setOracle(
        address _token,
        address _chainlinkOracle,
        uint32 _heartbeat,
        bytes4 sharePriceSignature,
        uint8 sharePriceDecimals,
        bool _isEthIndexed
    ) external;

    function MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND() external view returns (uint256);

    function TARGET_DIGITS() external view returns (uint256);

    function oracleRecords(
        address
    )
        external
        view
        returns (
            IAggregatorV3Interface chainLinkOracle,
            uint8 decimals,
            uint32 heartbeat,
            bytes4 sharePriceSignature,
            uint8 sharePriceDecimals,
            bool isFeedWorking,
            bool isEthIndexed
        );

    function priceRecords(
        address
    ) external view returns (uint96 scaledPrice, uint32 timestamp, uint32 lastUpdated, uint80 roundId);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ISystemStart {
    function getWeek() external view returns (uint256 week);
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IBimaOwnable} from "./IBimaOwnable.sol";
import {ISystemStart} from "./ISystemStart.sol";
import {IBimaToken} from "./IBimaToken.sol";
import {IBimaCore} from "./IBimaCore.sol";
import {IIncentiveVoting} from "./IIncentiveVoting.sol";

interface ITokenLocker is IBimaOwnable, ISystemStart {
    struct LockData {
        uint256 amount;
        uint256 weeksToUnlock;
    }
    struct ExtendLockData {
        uint256 amount;
        uint256 currentWeeks;
        uint256 newWeeks;
    }

    event LockCreated(address indexed account, uint256 amount, uint256 _weeks);
    event LockExtended(address indexed account, uint256 amount, uint256 _weeks, uint256 newWeeks);
    event LocksCreated(address indexed account, LockData[] newLocks);
    event LocksExtended(address indexed account, ExtendLockData[] locks);
    event LocksFrozen(address indexed account, uint256 amount);
    event LocksUnfrozen(address indexed account, uint256 amount);
    event LocksWithdrawn(address indexed account, uint256 withdrawn, uint256 penalty);
    event SetAllowPenaltyWithdrawAfter(uint256 startTime);
    event SetPenaltyWithdrawalsEnabled(bool status);

    function extendLock(uint256 _amount, uint256 _weeks, uint256 _newWeeks) external returns (bool);

    function extendMany(ExtendLockData[] calldata newExtendLocks) external returns (bool);

    function freeze() external;

    function getAccountWeightWrite(address account) external returns (uint256);

    function getTotalWeightWrite() external returns (uint256);

    function lock(address _account, uint256 _amount, uint256 _weeks) external returns (bool);

    function lockMany(address _account, LockData[] calldata newLocks) external returns (bool);

    function setPenaltyWithdrawalsEnabled(bool _enabled) external returns (bool);

    function unfreeze(bool keepIncentivesVote) external;

    function withdrawExpiredLocks(uint256 _weeks) external returns (bool);

    function withdrawWithPenalty(uint256 amountToWithdraw) external returns (uint256);

    function MAX_LOCK_WEEKS() external view returns (uint256);

    function getAccountActiveLocks(
        address account,
        uint256 minWeeks
    ) external view returns (LockData[] memory lockData, uint256 frozenAmount);

    function getAccountBalances(address account) external view returns (uint256 locked, uint256 unlocked);

    function getAccountWeight(address account) external view returns (uint256);

    function getAccountWeightAt(address account, uint256 week) external view returns (uint256);

    function getTotalWeight() external view returns (uint256);

    function getTotalWeightAt(uint256 week) external view returns (uint256);

    function getWithdrawWithPenaltyAmounts(
        address account,
        uint256 amountToWithdraw
    ) external view returns (uint256 amountWithdrawn, uint256 penaltyAmountPaid);

    function incentiveVoter() external view returns (IIncentiveVoting);

    function lockToTokenRatio() external view returns (uint256);

    function lockToken() external view returns (IBimaToken);

    function penaltyWithdrawalsEnabled() external view returns (bool);

    function bimaCore() external view returns (IBimaCore);

    function totalDecayRate() external view returns (uint32);

    function totalUpdatedWeek() external view returns (uint16);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IBimaOwnable} from "./IBimaOwnable.sol";
import {ISystemStart} from "./ISystemStart.sol";
import {IBoostCalculator} from "./IBoostCalculator.sol";
import {IBoostDelegate} from "./IBoostDelegate.sol";
import {ITokenLocker} from "./ITokenLocker.sol";
import {IIncentiveVoting} from "./IIncentiveVoting.sol";
import {IBimaToken} from "./IBimaToken.sol";
import {IEmissionSchedule} from "./IEmissionSchedule.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRewards {
    function vaultClaimReward(address claimant, address receiver) external returns (uint256);

    function claimableReward(address account) external view returns (uint256);
}

interface IBimaVault is IBimaOwnable, ISystemStart {
    struct InitialAllowance {
        address receiver;
        uint256 amount;
    }

    event BoostCalculatorSet(address boostCalculator);
    event BoostDelegationSet(address indexed boostDelegate, bool isEnabled, uint256 feePct, address callback);
    event EmissionScheduleSet(address emissionScheduler);
    event IncreasedAllocation(address indexed receiver, uint256 increasedAmount);
    event NewReceiverRegistered(address receiver, uint256 id);
    event ReceiverIsActiveStatusModified(uint256 indexed id, bool isActive);
    event UnallocatedSupplyIncreased(uint256 increasedAmount, uint256 unallocatedTotal);
    event UnallocatedSupplyReduced(uint256 reducedAmount, uint256 unallocatedTotal);

    function allocateNewEmissions(uint256 id) external returns (uint256);

    function batchClaimRewards(
        address receiver,
        address boostDelegate,
        IRewards[] calldata rewardContracts,
        uint256 maxFeePct
    ) external returns (bool);

    function increaseUnallocatedSupply(uint256 amount) external returns (bool);

    function registerReceiver(address receiver, uint256 count) external returns (bool);

    function setBoostCalculator(IBoostCalculator _boostCalculator) external returns (bool);

    function setBoostDelegationParams(bool isEnabled, uint16 feePct, address callback) external returns (bool);

    function setEmissionSchedule(IEmissionSchedule _emissionSchedule) external returns (bool);

    function setInitialParameters(
        IEmissionSchedule _emissionSchedule,
        IBoostCalculator _boostCalculator,
        uint256 totalSupply,
        uint64 initialLockWeeks,
        uint128[] calldata _fixedInitialAmounts,
        InitialAllowance[] calldata initialAllowances
    ) external;

    function setReceiverIsActive(uint256 id, bool isActive) external returns (bool);

    function transferAllocatedTokens(address claimant, address receiver, uint256 amount) external returns (bool);

    function transferTokens(IERC20 token, address receiver, uint256 amount) external returns (bool);

    function allocated(address) external view returns (uint256);

    function boostCalculator() external view returns (IBoostCalculator);

    function boostDelegation(address) external view returns (bool isEnabled, uint16 feePct, IBoostDelegate callback);

    function claimableRewardAfterBoost(
        address account,
        address receiver,
        address boostDelegate,
        IRewards rewardContract
    ) external view returns (uint256 adjustedAmount, uint256 feeToDelegate);

    function emissionSchedule() external view returns (IEmissionSchedule);

    function getClaimableWithBoost(address claimant) external view returns (uint256 maxBoosted, uint256 boosted);

    function idToReceiver(uint256) external view returns (address account, bool isActive, uint16 updatedWeek);

    function isReceiverActive(uint256 id) external view returns (bool isActive);

    function isBoostDelegatedEnabled(address account) external view returns (bool isEnabled);

    function lockWeeks() external view returns (uint64);

    function locker() external view returns (ITokenLocker);

    function claimableBoostDelegationFees(address claimant) external view returns (uint256 amount);

    function bimaToken() external view returns (IBimaToken);

    function totalUpdateWeek() external view returns (uint64);

    function unallocatedTotal() external view returns (uint128);

    function voter() external view returns (IIncentiveVoting);

    function weeklyEmissions(uint256) external view returns (uint128);
}

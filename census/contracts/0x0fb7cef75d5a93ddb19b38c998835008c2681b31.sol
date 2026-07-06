// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {LibCall} from "solady/src/utils/LibCall.sol";

import {Factory} from "../Factory.sol";
import {VaultInfoResolver} from "../modules/resolvers/VaultInfoResolver.sol";
import {PrincipalToken} from "../tokens/PrincipalToken.sol";
import {TwoCryptoZap} from "../zap/TwoCryptoZap.sol";
import {RouterPayload} from "../modules/aggregator/AggregationRouter.sol";
import {Quoter} from "./Quoter.sol";

import {LibTwoCryptoNG} from "../utils/LibTwoCryptoNG.sol";
import {LibBlueprint} from "../utils/LibBlueprint.sol";
import {ConversionLib} from "./ConversionLib.sol";
import {RouterPayload} from "../modules/aggregator/AggregationRouter.sol";

import "../Types.sol";
import "../Constants.sol";

/// @notice Impersonate a user to simulate a interaction with a contract.
/// @dev This contract is not meant to ever actually be deployed, only mock deployed and used via a static `eth_call` and `stateOverride` option.
contract Impersonator {
    using LibTwoCryptoNG for TwoCrypto;

    error Impersonator_FunctionNotFound();
    error Impersonator_ApproveTokenFailed();
    error Impersonator_InsufficientNativeTokenBalance();
    error Impersonator_ErrorMarginExceeds10000Bps();
    error Impersonator_InvalidResolverBlueprint();
    error Impersonator_ExpiryIsInThePast();
    error Impersonator_InvalidResolverConfig();
    error Impersonator_IntermediateAmountTooLow();

    uint256 constant DEFAULT_SLIPPAGE_BPS = 10; // 0.1%

    /// @notice User should be able to receive native tokens.
    receive() external payable {}

    /// @dev Explicit error message when the function is not found.
    fallback() external {
        revert Impersonator_FunctionNotFound();
    }

    /// @notice Simulate a Zap contract function call.
    /// @param zap - Target contract that the user interact with
    /// @param tokenIns - List of tokens that the user spends. The user's tokens spend by Zap must be included in this list.
    /// @param value - The amount of native token that the user sends to the Zap contract.
    /// @param simPayload - The Zap contract function call to be simulated. The params must be abi-encoded, starting with a function selector.
    function query(address zap, Token[] memory tokenIns, uint256 value, bytes memory simPayload)
        public
        payable
        returns (bytes memory)
    {
        for (uint256 i = 0; i != tokenIns.length; i++) {
            try this.extApprove(tokenIns[i], zap) {}
            catch {
                revert Impersonator_ApproveTokenFailed();
            }
        }
        if (address(this).balance < value) {
            revert Impersonator_InsufficientNativeTokenBalance();
        }

        (bool success, bytes memory ret) = zap.call{value: value}(simPayload);
        if (!success) LibCall.bubbleUpRevert(ret);
        return ret;
    }

    function query(address zap, Token tokenIn, uint256 value, bytes memory simPayload)
        public
        payable
        returns (bytes memory ret)
    {
        Token[] memory tokenIns = new Token[](1);
        tokenIns[0] = tokenIn;
        return query(zap, tokenIns, value, simPayload);
    }

    /// @dev Calculate the initial price of the principal token in shares based on the implied APY and current share price of the underlying token.
    function queryInitialPrice(
        address zap,
        uint256 expiry, // In seconds
        int256 impliedAPY, // 1e18 == 100%
        address resolverBlueprint,
        bytes calldata resolverArg
    ) external returns (uint256 initialPtPrice) {
        if (!TwoCryptoZap(payable(zap)).i_factory().s_resolverBlueprints(resolverBlueprint)) {
            revert Impersonator_InvalidResolverBlueprint();
        }
        if (expiry <= block.timestamp) revert Impersonator_ExpiryIsInThePast();

        address resolver = LibBlueprint.tryCreate(resolverBlueprint, resolverArg);
        if (resolver == address(0)) revert Impersonator_InvalidResolverConfig();

        uint256 scale;
        try VaultInfoResolver(resolver).scale() returns (uint256 s) {
            // Dev: Solidity try-catch doesn't catch errors inside try block. So we must outsource remaining logic to outside of try block.
            scale = s;
        } catch {
            revert Impersonator_InvalidResolverConfig();
        }
        uint256 scaleUnit =
            10 ** (18 + VaultInfoResolver(resolver).assetDecimals() - VaultInfoResolver(resolver).decimals());
        // Unit conversions: scale is in (18 + assetDecimals - underlyingDecimals) units
        // e.g. vault: 6 decimals, underlying: 6 decimals, share price: 1.2
        // scale = 1.2e6 * 10**(18 - 6) = 1.2e6 * 1e12. It should be divided by 10**(18 + 6 - 6)
        // e.g. vault: 6 decimals, underlying: 18 decimals, share price: 1.2
        // scale = 1.2e6 * 10**(18 - 18) = 1.2e6. It should be divided by 10**(18 + 18 - 18)
        uint256 timeToExpiry = expiry - block.timestamp;
        initialPtPrice = ConversionLib.convertToPriceInAsset(impliedAPY, timeToExpiry) * scaleUnit / scale;
    }

    /// @dev WARNING: This function can't predict the addresses of instances.
    function queryCreateAndAddLiquidity(
        address zap,
        address quoter,
        Factory.Suite calldata suite,
        Factory.ModuleParam[] calldata modules,
        uint256 expiry,
        address curator,
        uint256 shares
    ) external returns (uint256 liquidity, uint256 principal) {
        QueryCreateAndAddLiquidityParams memory params = QueryCreateAndAddLiquidityParams({
            zap: zap,
            quoter: quoter,
            suite: suite,
            modules: modules,
            expiry: expiry,
            curator: curator,
            shares: shares
        });
        return _queryCreateAndAddLiquidity(params);
    }

    /// @dev Workaround to avoid stack-too-deep error.
    struct QueryCreateAndAddLiquidityParams {
        address zap;
        address quoter; // Not used just for consistency with other query functions
        Factory.Suite suite;
        Factory.ModuleParam[] modules;
        uint256 expiry;
        address curator;
        uint256 shares;
    }

    /// @dev NOTE: This function doesn't return `pt`, `yt` and `twoCrypto` because those addresses are different from the actual ones.
    function _queryCreateAndAddLiquidity(QueryCreateAndAddLiquidityParams memory params)
        internal
        returns (uint256 liquidity, uint256 principal)
    {
        // Factory depends on `msg.sender` to determine the salt. We can't correctly derive addresses of instances
        ( /* pt */ , /* yt */, address twoCrypto) = TwoCryptoZap(payable(params.zap)).i_factory().deploy(
            params.suite, params.modules, params.expiry, params.curator
        );

        Token underlying = Token.wrap(TwoCrypto.wrap(twoCrypto).coins(TARGET_INDEX));
        // Note: We don't use `Quoter.previewAddLiquidityOneToken()` because it fails when total supply is zero.
        // Instead, we simulate the add liquidity with the same logic as `TwoCryptoZap.addLiquidityOneToken()`.
        TwoCryptoZap.AddLiquidityOneTokenParams memory p = TwoCryptoZap.AddLiquidityOneTokenParams({
            twoCrypto: TwoCrypto.wrap(twoCrypto),
            tokenIn: underlying,
            amountIn: params.shares,
            minLiquidity: 0,
            minYt: 0,
            receiver: address(this),
            deadline: block.timestamp
        });
        // Simulate the add liquidity
        bytes memory ret = query(params.zap, underlying, 0, abi.encodeCall(TwoCryptoZap.addLiquidityOneToken, (p)));

        (liquidity, principal) = abi.decode(ret, (uint256, uint256));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        QUERY SWAP PT                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    struct QuerySwapPtForAnyTokenParams {
        address zap;
        Quoter quoter;
        TwoCrypto twoCrypto;
        uint256 principal;
        Token tokenOut;
        Token tokenRedeemShares;
        address router;
        bytes swapData;
    }

    function querySwapPtForToken(address zap, Quoter quoter, TwoCrypto twoCrypto, Token tokenOut, uint256 principal)
        public
        returns (
            uint256 amountOut,
            uint256 shares,
            uint256 priceInAssetWei,
            int256 impliedApyWei,
            uint256 executionPriceWei
        )
    {
        (amountOut, shares, priceInAssetWei, impliedApyWei, executionPriceWei) = querySwapPtForAnyToken(
            QuerySwapPtForAnyTokenParams({
                zap: zap,
                quoter: quoter,
                twoCrypto: twoCrypto,
                principal: principal,
                tokenOut: tokenOut,
                tokenRedeemShares: Token.wrap(address(0)),
                router: address(0),
                swapData: bytes("")
            })
        );
    }

    /// @return amountOut - The amount of tokenOut the user receives.
    /// @return shares - The intermediate amount of shares the zap receives.
    /// @return priceInAssetWei - The execution price of the principal token in the asset in Wei. (e.g. 1 PT-wstETH = 0.9 ETH => 0.9e18). It can be greater than 1e18 if the PT is not discounted at all.
    /// @return impliedApyWei - The implied APY of the principal token in wei. (e.g. 1e18 = 100%, 5% => 0.05e18). Returns 0 if the PT is expired.
    /// @return executionPriceWei - The execution price of tokenOut against the PT in Wei. (e.g. 1 USDC = 0.9 PT-wstETH => 0.9e18).
    function querySwapPtForAnyToken(QuerySwapPtForAnyTokenParams memory params)
        public
        returns (
            uint256 amountOut,
            uint256 shares,
            uint256 priceInAssetWei,
            int256 impliedApyWei,
            uint256 executionPriceWei
        )
    {
        (amountOut, shares) = _querySwapPtForAnyToken(params);

        priceInAssetWei = ConversionLib.calculateEffectivePtPrice(
            params.twoCrypto, params.principal, shares, ConversionLib.SwapKind.PT
        );
        impliedApyWei = _convertToImpliedAPY(params.twoCrypto.coins(PT_INDEX), priceInAssetWei);
        executionPriceWei = ConversionLib.calculateEffectivePrice(
            Token.wrap(params.twoCrypto.coins(PT_INDEX)), params.tokenOut, params.principal, amountOut
        );
    }

    function _querySwapPtForAnyToken(QuerySwapPtForAnyTokenParams memory params)
        internal
        returns (uint256 amountOut, uint256 shares)
    {
        uint256 sharesBefore = params.twoCrypto.balances(TARGET_INDEX);

        bool anyToken = params.router != address(0);

        // If the simulation uses the third-party router, skip quote.
        uint256 amountOutMin;
        if (!anyToken) {
            uint256 preview = params.quoter.previewSwapPtForToken(params.twoCrypto, params.tokenOut, params.principal);
            amountOutMin = preview * (BASIS_POINTS - DEFAULT_SLIPPAGE_BPS) / BASIS_POINTS;
        }

        TwoCryptoZap.SwapPtParams memory swapParams = TwoCryptoZap.SwapPtParams({
            twoCrypto: params.twoCrypto,
            tokenOut: params.tokenOut,
            principal: params.principal,
            receiver: address(this),
            // If not anyToken, intermediateToken is the tokenOut.
            amountOutMin: amountOutMin,
            deadline: block.timestamp
        });
        bytes memory simPayload;
        if (anyToken) {
            TwoCryptoZap.SwapTokenOutput memory tokenOutput = TwoCryptoZap.SwapTokenOutput({
                tokenRedeemShares: params.tokenRedeemShares,
                swapData: RouterPayload({router: params.router, payload: params.swapData})
            });
            simPayload = abi.encodeCall(TwoCryptoZap.swapPtForAnyToken, (swapParams, tokenOutput));
        } else {
            simPayload = abi.encodeCall(TwoCryptoZap.swapPtForToken, (swapParams));
        }

        Token pt = Token.wrap(params.twoCrypto.coins(PT_INDEX));
        bytes memory ret = query(params.zap, pt, 0, simPayload);

        amountOut = abi.decode(ret, (uint256));
        shares = sharesBefore - params.twoCrypto.balances(TARGET_INDEX);
    }

    struct QuerySwapAnyTokenForPtParams {
        address zap;
        Quoter quoter;
        TwoCrypto twoCrypto;
        Token tokenIn;
        uint256 amountIn;
        Token tokenMintShares;
        address router;
        bytes swapData;
    }

    function querySwapTokenForPt(address zap, Quoter quoter, TwoCrypto twoCrypto, Token tokenIn, uint256 amountIn)
        public
        returns (
            uint256 principal,
            uint256 shares,
            uint256 priceInAssetWei,
            int256 impliedApyWei,
            uint256 executionPriceWei
        )
    {
        (principal, shares, priceInAssetWei, impliedApyWei, executionPriceWei) = querySwapAnyTokenForPt(
            QuerySwapAnyTokenForPtParams({
                zap: zap,
                quoter: quoter,
                twoCrypto: twoCrypto,
                tokenIn: tokenIn,
                amountIn: amountIn,
                tokenMintShares: Token.wrap(address(0)),
                router: address(0),
                swapData: bytes("")
            })
        );
    }

    /// @return principal - The amount of principal tokens the user will receive
    /// @return shares - The amount of shares used in the swap
    /// @return priceInAssetWei - The price of PT in terms of the underlying asset in WAD (e.g. 1 PT-wstETH = 0.95 ETH => 0.95e18)
    /// @return impliedApyWei - The implied APY of the principal token in WAD (e.g. 5% => 0.05e18)
    /// @return executionPriceWei - The execution price of PT against tokenIn in WAD (e.g. 1 PT-wstETH = 0.8 USDC => 0.8e18)
    function querySwapAnyTokenForPt(QuerySwapAnyTokenForPtParams memory params)
        public
        returns (
            uint256 principal,
            uint256 shares,
            uint256 priceInAssetWei,
            int256 impliedApyWei,
            uint256 executionPriceWei
        )
    {
        (principal, shares) = _querySwapAnyTokenForPt(params);
        priceInAssetWei =
            ConversionLib.calculateEffectivePtPrice(params.twoCrypto, principal, shares, ConversionLib.SwapKind.PT);
        impliedApyWei = _convertToImpliedAPY(params.twoCrypto.coins(PT_INDEX), priceInAssetWei);
        executionPriceWei = ConversionLib.calculateEffectivePrice(
            params.tokenIn, Token.wrap(params.twoCrypto.coins(PT_INDEX)), params.amountIn, principal
        );
    }

    function _querySwapAnyTokenForPt(QuerySwapAnyTokenForPtParams memory params)
        internal
        returns (uint256 principal, uint256 shares)
    {
        uint256 sharesBefore = params.twoCrypto.balances(TARGET_INDEX);

        bool anyToken = params.router != address(0);

        // If the simulation uses the third-party router, skip quote.
        uint256 minPrincipal;
        if (!anyToken) {
            uint256 preview = params.quoter.previewSwapTokenForPt(params.twoCrypto, params.tokenIn, params.amountIn);
            minPrincipal = preview * (BASIS_POINTS - DEFAULT_SLIPPAGE_BPS) / BASIS_POINTS;
        }

        TwoCryptoZap.SwapTokenParams memory swapParams = TwoCryptoZap.SwapTokenParams({
            twoCrypto: params.twoCrypto,
            tokenIn: params.tokenIn,
            amountIn: params.amountIn,
            receiver: address(this),
            minPrincipal: minPrincipal,
            deadline: block.timestamp
        });

        bytes memory simPayload;
        uint256 value = params.tokenIn.isNative() ? params.amountIn : 0;
        if (anyToken) {
            TwoCryptoZap.SwapTokenInput memory tokenInput = TwoCryptoZap.SwapTokenInput({
                tokenMintShares: params.tokenMintShares,
                swapData: RouterPayload({router: params.router, payload: params.swapData})
            });
            simPayload = abi.encodeCall(TwoCryptoZap.swapAnyTokenForPt, (swapParams, tokenInput));
        } else {
            simPayload = abi.encodeCall(TwoCryptoZap.swapTokenForPt, (swapParams));
        }
        // Simulate the swap
        bytes memory ret = query(params.zap, params.tokenIn, value, simPayload);
        principal = abi.decode(ret, (uint256));

        shares = params.twoCrypto.balances(TARGET_INDEX) - sharesBefore;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        QUERY SWAP YT                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function querySwapTokenForYt(
        address zap,
        Quoter quoter,
        TwoCrypto twoCrypto,
        Token tokenIn,
        uint256 amountIn,
        uint256 errorMarginBps
    )
        public
        returns (
            uint256 principal,
            ApproxValue sharesFlashBorrowWithMargin,
            uint256 priceInAssetWei,
            int256 impliedApyWei,
            uint256 executionPrice
        )
    {
        return querySwapAnyTokenForYt(
            QuerySwapAnyTokenForYtParams({
                zap: zap,
                quoter: quoter,
                twoCrypto: twoCrypto,
                tokenIn: tokenIn,
                amountIn: amountIn,
                errorMarginBps: errorMarginBps,
                tokenMintShares: Token.wrap(address(0)),
                tokenMintEstimate: 0,
                router: address(0),
                payload: bytes("")
            })
        );
    }

    /// @notice Parameters for querying a swap of any token for YT
    /// @param zap The address of the TwoCryptoZap contract
    /// @param quoter The Quoter contract used for price quotes
    /// @param twoCrypto The TwoCrypto pool contract
    /// @param tokenIn The input token to swap from
    /// @param amountIn The amount of input token to swap
    /// @param errorMarginBps The error margin in basis points (1 basis point = 0.01%).  It affects `sharesFlashBorrowWithMargin` and `principal` the user is going to receive.
    /// @param tokenMintShares The intermediate token that should be output from third-party router swaps
    /// @param tokenMintEstimate The expected amount of tokenMintShares to receive from third-party router
    /// @param router The address of the third-party router to use
    /// @param payload The calldata payload to send to the third-party router
    struct QuerySwapAnyTokenForYtParams {
        address zap;
        Quoter quoter;
        TwoCrypto twoCrypto;
        Token tokenIn;
        uint256 amountIn;
        uint256 errorMarginBps;
        // If anyToken endpoint is used, fill in the following fields.
        Token tokenMintShares;
        uint256 tokenMintEstimate;
        address router;
        bytes payload;
    }

    /// @return principal - The amount of principal the user is going to receive.
    /// @return sharesFlashBorrowWithMargin - The amount of shares the user is going to borrow with the error margin.
    /// @return priceInAssetWei - The execution price of the principal token against the asset in Wei. (e.g. 1 PT-wstETH = 0.9 ETH => 0.9e18). The price is in range [0, 1e18] if the the price can be negative, returns 0.
    /// @return impliedApyWei - The implied APY of the principal token in wei. (e.g. 1e18 = 100%, 5% => 0.05e18). Returns 0 if the PT is expired.
    /// @return executionPrice - The execution price of tokenIn against the YT in Wei. (e.g. 1 YT-wstETH = 0.01 USDC => 0.01e18).
    function querySwapAnyTokenForYt(QuerySwapAnyTokenForYtParams memory params)
        public
        returns (
            uint256 principal,
            ApproxValue sharesFlashBorrowWithMargin,
            uint256 priceInAssetWei,
            int256 impliedApyWei,
            uint256 executionPrice
        )
    {
        uint256 sharesSpent;
        (principal, sharesFlashBorrowWithMargin, sharesSpent) = _querySwapAnyTokenForYt(params);

        address pt = params.twoCrypto.coins(PT_INDEX);
        priceInAssetWei =
            ConversionLib.calculateEffectivePtPrice(params.twoCrypto, principal, sharesSpent, ConversionLib.SwapKind.YT);
        impliedApyWei = _convertToImpliedAPY(pt, priceInAssetWei);
        executionPrice = ConversionLib.calculateEffectivePrice(
            params.tokenIn, Token.wrap(address(PrincipalToken(pt).i_yt())), params.amountIn, principal
        );
    }

    function _querySwapAnyTokenForYt(QuerySwapAnyTokenForYtParams memory params)
        internal
        returns (uint256 principal, ApproxValue sharesFlashBorrowWithMargin, uint256 sharesSpent)
    {
        if (params.errorMarginBps > BASIS_POINTS) revert Impersonator_ErrorMarginExceeds10000Bps();

        bytes memory simPayload;
        bool anyToken = params.router != address(0);
        {
            // Get preview for swapping intermediate token to YT

            // If aggregator API is used, the intermediate amount is `estimate.dstAmount`.
            // USDC -> [1inch] -> WETH -> [connector] -> wstETH -> [pool] -> YT
            Token intermediateToken = anyToken ? params.tokenMintShares : params.tokenIn;
            uint256 intermediateAmount = anyToken ? params.tokenMintEstimate : params.amountIn;

            uint256 quoterAmountIn = intermediateAmount * (BASIS_POINTS - params.errorMarginBps) / BASIS_POINTS;
            (, sharesFlashBorrowWithMargin, sharesSpent) =
                params.quoter.previewSwapTokenForYt(params.twoCrypto, intermediateToken, quoterAmountIn);

            TwoCryptoZap.SwapTokenParams memory swapParams = TwoCryptoZap.SwapTokenParams({
                twoCrypto: params.twoCrypto,
                tokenIn: params.tokenIn,
                amountIn: params.amountIn,
                receiver: address(this),
                minPrincipal: 0,
                deadline: block.timestamp
            });
            if (anyToken) {
                TwoCryptoZap.SwapTokenInput memory tokenInput = TwoCryptoZap.SwapTokenInput({
                    tokenMintShares: params.tokenMintShares,
                    swapData: RouterPayload({router: params.router, payload: params.payload})
                });
                simPayload = abi.encodeCall(
                    TwoCryptoZap.swapAnyTokenForYt, (swapParams, sharesFlashBorrowWithMargin, tokenInput)
                );
            } else {
                simPayload = abi.encodeCall(TwoCryptoZap.swapTokenForYt, (swapParams, sharesFlashBorrowWithMargin));
            }
        }
        uint256 value = params.tokenIn.isNative() ? params.amountIn : 0;

        // Simulate the swap
        bytes memory ret = query(params.zap, params.tokenIn, value, simPayload);

        principal = abi.decode(ret, (uint256));
    }

    function querySwapYtForToken(
        address zap,
        Quoter quoter,
        TwoCrypto twoCrypto,
        Token tokenOut,
        uint256 principal,
        uint256 errorMarginBps
    )
        public
        returns (
            uint256 amountOut,
            uint256 ytSpent,
            ApproxValue dxResultWithMargin,
            uint256 priceInAssetWei,
            int256 impliedApyWei,
            uint256 executionPrice
        )
    {
        return querySwapYtForAnyToken(
            QuerySwapYtForAnyTokenParams({
                zap: zap,
                quoter: quoter,
                twoCrypto: twoCrypto,
                tokenOut: tokenOut,
                principal: principal,
                errorMarginBps: errorMarginBps,
                tokenRedeemShares: Token.wrap(address(0)),
                tokenRedeemEstimate: 0,
                router: address(0),
                payload: bytes("")
            })
        );
    }

    struct QuerySwapYtForAnyTokenParams {
        address zap;
        Quoter quoter;
        TwoCrypto twoCrypto;
        Token tokenOut;
        uint256 principal;
        uint256 errorMarginBps;
        // If anyToken endpoint is used, fill in the following fields.
        Token tokenRedeemShares;
        uint256 tokenRedeemEstimate;
        address router;
        bytes payload;
    }

    /// @return amountOut - The amount of tokenOut the user receives.
    /// @return ytSpent - The amount of YT the user actually spends.
    /// @return dxResultWithMargin - The approximate amount of `get_dx({i: TARGET, j: PT}, principal)` with the error margin.
    /// @return priceInAssetWei - The execution price of the PT in the asset in Wei. (e.g. 1 PT-wstETH = 0.9 ETH => 0.9e18).
    /// @return impliedApyWei - The implied APY of the principal token in wei. (e.g. 1e18 = 100%, 5% => 0.05e18). Returns 0 if the PT is expired. Returns `type(int256).max` if math error.
    /// @return executionPrice - The execution price of tokenOut against the YT in Wei. (e.g. 1 USDC = 100 YT-wstETH => 100e18).
    function querySwapYtForAnyToken(QuerySwapYtForAnyTokenParams memory params)
        public
        returns (
            uint256 amountOut,
            uint256 ytSpent,
            ApproxValue dxResultWithMargin,
            uint256 priceInAssetWei,
            int256 impliedApyWei,
            uint256 executionPrice
        )
    {
        uint256 sharesOut;
        (amountOut, ytSpent, dxResultWithMargin, sharesOut) = _querySwapYtForAnyToken(params);

        // See `TwoCryptoZap.swapYtForToken()` for the logic of shares change.
        // Calculate the execution price and implied APY
        // Note: `shares` will be slightly different from actual because of the error margin.
        address pt = params.twoCrypto.coins(PT_INDEX);
        priceInAssetWei =
            ConversionLib.calculateEffectivePtPrice(params.twoCrypto, ytSpent, sharesOut, ConversionLib.SwapKind.YT);
        impliedApyWei = _convertToImpliedAPY(pt, priceInAssetWei);
        executionPrice = ConversionLib.calculateEffectivePrice(
            Token.wrap(address(PrincipalToken(pt).i_yt())), params.tokenOut, ytSpent, amountOut
        );
    }

    function _querySwapYtForAnyToken(QuerySwapYtForAnyTokenParams memory params)
        internal
        returns (uint256 amountOut, uint256 ytSpent, ApproxValue dxResultWithMargin, uint256 sharesOut)
    {
        if (params.errorMarginBps > BASIS_POINTS) revert Impersonator_ErrorMarginExceeds10000Bps();

        uint256 ytBalanceBefore =
            SafeTransferLib.balanceOf(address(PrincipalToken(params.twoCrypto.coins(PT_INDEX)).i_yt()), address(this));

        bytes memory simPayload;
        // Get preview
        {
            // If the router is not zero address, `any token` function should be simulated
            // For example, YT -> [pool] -> wstETH -> [1inch] -> USDC
            bool anyToken = params.router != address(0);

            Token intermediateToken = anyToken ? params.tokenRedeemShares : params.tokenOut;
            (uint256 intermediateAmount, /* ApproxValue ytSpendPreview, */, ApproxValue getDxResult) =
                params.quoter.previewSwapYtForToken(params.twoCrypto, intermediateToken, params.principal);

            // The intermediate amount should be greater than the estimate. Otherwise, the swap will fail with insufficient balance on third-party router.
            // The thrid-pary API estimate may be old. Pass smaller estimate `srcAmount`, taking slippage into account.
            if (anyToken && params.tokenRedeemEstimate > intermediateAmount) {
                revert Impersonator_IntermediateAmountTooLow();
            }

            dxResultWithMargin =
                ApproxValue.wrap(getDxResult.unwrap() * (BASIS_POINTS - params.errorMarginBps) / BASIS_POINTS);

            simPayload = _encodeSwapYtForAnyTokenPayload(params, dxResultWithMargin);
        }

        address yt = address(PrincipalToken(params.twoCrypto.coins(PT_INDEX)).i_yt());

        // Simulate the swap
        bytes memory ret = query(params.zap, Token.wrap(yt), 0, simPayload);

        // Get the result
        amountOut = abi.decode(ret, (uint256));
        ytSpent = ytBalanceBefore - SafeTransferLib.balanceOf(yt, address(this));
        sharesOut =
            PrincipalToken(params.twoCrypto.coins(PT_INDEX)).previewCombine(ytSpent) - dxResultWithMargin.unwrap();
    }

    /// @dev Workaround for stack too deep error.
    function _encodeSwapYtForAnyTokenPayload(QuerySwapYtForAnyTokenParams memory params, ApproxValue dxResultWithMargin)
        internal
        view
        returns (bytes memory)
    {
        TwoCryptoZap.SwapYtParams memory swapParams = TwoCryptoZap.SwapYtParams({
            twoCrypto: params.twoCrypto,
            tokenOut: params.tokenOut,
            principal: params.principal,
            receiver: address(this),
            // We don't need to set this because we simulate swap with off-chain value `getDxResult` inclusive of some margin, so we will get slightly different result from the preview.
            // In some cases, the swap fails because of this reason. So we set this to 0.
            amountOutMin: 0,
            deadline: block.timestamp
        });

        if (params.router != address(0)) {
            TwoCryptoZap.SwapTokenOutput memory tokenOutput = TwoCryptoZap.SwapTokenOutput({
                tokenRedeemShares: params.tokenRedeemShares,
                swapData: RouterPayload({router: params.router, payload: params.payload})
            });
            return abi.encodeCall(TwoCryptoZap.swapYtForAnyToken, (swapParams, dxResultWithMargin, tokenOutput));
        } else {
            return abi.encodeCall(TwoCryptoZap.swapYtForToken, (swapParams, dxResultWithMargin));
        }
    }

    /// @dev Return `type(int256).max` if `ExpOverflow` or math error.
    function _convertToImpliedAPY(address pt, uint256 priceInAssetWei) internal view returns (int256) {
        try this.extConvertToImpliedAPY(pt, priceInAssetWei) returns (int256 impliedApyWei) {
            return impliedApyWei;
        } catch {
            return type(int256).max;
        }
    }

    /// @dev Workaround for try-catch.
    function extConvertToImpliedAPY(address pt, uint256 priceInAssetWei) external view returns (int256) {
        return ConversionLib.convertToImpliedAPY(pt, priceInAssetWei);
    }

    function extApprove(Token token, address spender) external {
        // For tokens like USDT, it requires to reset the approval to 0 before setting it to max.
        if (token.isNotNative()) SafeTransferLib.safeApproveWithRetry(token.unwrap(), spender, type(uint256).max);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/SafeTransferLib.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @author Permit2 operations from (https://github.com/Uniswap/permit2/blob/main/src/libraries/Permit2Lib.sol)
///
/// @dev Note:
/// - For ETH transfers, please use `forceSafeTransferETH` for DoS protection.
library SafeTransferLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The ETH transfer has failed.
    error ETHTransferFailed();

    /// @dev The ERC20 `transferFrom` has failed.
    error TransferFromFailed();

    /// @dev The ERC20 `transfer` has failed.
    error TransferFailed();

    /// @dev The ERC20 `approve` has failed.
    error ApproveFailed();

    /// @dev The ERC20 `totalSupply` query has failed.
    error TotalSupplyQueryFailed();

    /// @dev The Permit2 operation has failed.
    error Permit2Failed();

    /// @dev The Permit2 amount must be less than `2**160 - 1`.
    error Permit2AmountOverflow();

    /// @dev The Permit2 approve operation has failed.
    error Permit2ApproveFailed();

    /// @dev The Permit2 lockdown operation has failed.
    error Permit2LockdownFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Suggested gas stipend for contract receiving ETH that disallows any storage writes.
    uint256 internal constant GAS_STIPEND_NO_STORAGE_WRITES = 2300;

    /// @dev Suggested gas stipend for contract receiving ETH to perform a few
    /// storage reads and writes, but low enough to prevent griefing.
    uint256 internal constant GAS_STIPEND_NO_GRIEF = 100000;

    /// @dev The unique EIP-712 domain domain separator for the DAI token contract.
    bytes32 internal constant DAI_DOMAIN_SEPARATOR =
        0xdbb8cf42e1ecb028be3f3dbc922e1d878b963f411dc388ced501601c60f7c6f7;

    /// @dev The address for the WETH9 contract on Ethereum mainnet.
    address internal constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @dev The canonical Permit2 address.
    /// [Github](https://github.com/Uniswap/permit2)
    /// [Etherscan](https://etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ETH OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // If the ETH transfer MUST succeed with a reasonable gas budget, use the force variants.
    //
    // The regular variants:
    // - Forwards all remaining gas to the target.
    // - Reverts if the target reverts.
    // - Reverts if the current contract has insufficient balance.
    //
    // The force variants:
    // - Forwards with an optional gas stipend
    //   (defaults to `GAS_STIPEND_NO_GRIEF`, which is sufficient for most cases).
    // - If the target reverts, or if the gas stipend is exhausted,
    //   creates a temporary contract to force send the ETH via `SELFDESTRUCT`.
    //   Future compatible with `SENDALL`: https://eips.ethereum.org/EIPS/eip-4758.
    // - Reverts if the current contract has insufficient balance.
    //
    // The try variants:
    // - Forwards with a mandatory gas stipend.
    // - Instead of reverting, returns whether the transfer succeeded.

    /// @dev Sends `amount` (in wei) ETH to `to`.
    function safeTransferETH(address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(call(gas(), to, amount, codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Sends all the ETH in the current contract to `to`.
    function safeTransferAllETH(address to) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // Transfer all the ETH and check if it succeeded or not.
            if iszero(call(gas(), to, selfbalance(), codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Force sends `amount` (in wei) ETH to `to`, with a `gasStipend`.
    function forceSafeTransferETH(address to, uint256 amount, uint256 gasStipend) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if lt(selfbalance(), amount) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
            if iszero(call(gasStipend, to, amount, codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(amount, 0x0b, 0x16)) { revert(codesize(), codesize()) } // For gas estimation.
            }
        }
    }

    /// @dev Force sends all the ETH in the current contract to `to`, with a `gasStipend`.
    function forceSafeTransferAllETH(address to, uint256 gasStipend) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(call(gasStipend, to, selfbalance(), codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(selfbalance(), 0x0b, 0x16)) { revert(codesize(), codesize()) } // For gas estimation.
            }
        }
    }

    /// @dev Force sends `amount` (in wei) ETH to `to`, with `GAS_STIPEND_NO_GRIEF`.
    function forceSafeTransferETH(address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if lt(selfbalance(), amount) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
            if iszero(call(GAS_STIPEND_NO_GRIEF, to, amount, codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(amount, 0x0b, 0x16)) { revert(codesize(), codesize()) } // For gas estimation.
            }
        }
    }

    /// @dev Force sends all the ETH in the current contract to `to`, with `GAS_STIPEND_NO_GRIEF`.
    function forceSafeTransferAllETH(address to) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // forgefmt: disable-next-item
            if iszero(call(GAS_STIPEND_NO_GRIEF, to, selfbalance(), codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(selfbalance(), 0x0b, 0x16)) { revert(codesize(), codesize()) } // For gas estimation.
            }
        }
    }

    /// @dev Sends `amount` (in wei) ETH to `to`, with a `gasStipend`.
    function trySafeTransferETH(address to, uint256 amount, uint256 gasStipend)
        internal
        returns (bool success)
    {
        /// @solidity memory-safe-assembly
        assembly {
            success := call(gasStipend, to, amount, codesize(), 0x00, codesize(), 0x00)
        }
    }

    /// @dev Sends all the ETH in the current contract to `to`, with a `gasStipend`.
    function trySafeTransferAllETH(address to, uint256 gasStipend)
        internal
        returns (bool success)
    {
        /// @solidity memory-safe-assembly
        assembly {
            success := call(gasStipend, to, selfbalance(), codesize(), 0x00, codesize(), 0x00)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ERC20 OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Sends `amount` of ERC20 `token` from `from` to `to`.
    /// Reverts upon failure.
    ///
    /// The `from` account must have at least `amount` approved for
    /// the current contract to manage.
    function safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, amount) // Store the `amount` argument.
            mstore(0x40, to) // Store the `to` argument.
            mstore(0x2c, shl(96, from)) // Store the `from` argument.
            mstore(0x0c, 0x23b872dd000000000000000000000000) // `transferFrom(address,address,uint256)`.
            let success := call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                    mstore(0x00, 0x7939f424) // `TransferFromFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Sends `amount` of ERC20 `token` from `from` to `to`.
    ///
    /// The `from` account must have at least `amount` approved for the current contract to manage.
    function trySafeTransferFrom(address token, address from, address to, uint256 amount)
        internal
        returns (bool success)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, amount) // Store the `amount` argument.
            mstore(0x40, to) // Store the `to` argument.
            mstore(0x2c, shl(96, from)) // Store the `from` argument.
            mstore(0x0c, 0x23b872dd000000000000000000000000) // `transferFrom(address,address,uint256)`.
            success := call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                success := lt(or(iszero(extcodesize(token)), returndatasize()), success)
            }
            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Sends all of ERC20 `token` from `from` to `to`.
    /// Reverts upon failure.
    ///
    /// The `from` account must have their entire balance approved for the current contract to manage.
    function safeTransferAllFrom(address token, address from, address to)
        internal
        returns (uint256 amount)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x40, to) // Store the `to` argument.
            mstore(0x2c, shl(96, from)) // Store the `from` argument.
            mstore(0x0c, 0x70a08231000000000000000000000000) // `balanceOf(address)`.
            // Read the balance, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                    staticcall(gas(), token, 0x1c, 0x24, 0x60, 0x20)
                )
            ) {
                mstore(0x00, 0x7939f424) // `TransferFromFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x00, 0x23b872dd) // `transferFrom(address,address,uint256)`.
            amount := mload(0x60) // The `amount` is already at 0x60. We'll need to return it.
            // Perform the transfer, reverting upon failure.
            let success := call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                    mstore(0x00, 0x7939f424) // `TransferFromFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Sends `amount` of ERC20 `token` from the current contract to `to`.
    /// Reverts upon failure.
    function safeTransfer(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0xa9059cbb000000000000000000000000) // `transfer(address,uint256)`.
            // Perform the transfer, reverting upon failure.
            let success := call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                    mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Sends all of ERC20 `token` from the current contract to `to`.
    /// Reverts upon failure.
    function safeTransferAll(address token, address to) internal returns (uint256 amount) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, 0x70a08231) // Store the function selector of `balanceOf(address)`.
            mstore(0x20, address()) // Store the address of the current contract.
            // Read the balance, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                    staticcall(gas(), token, 0x1c, 0x24, 0x34, 0x20)
                )
            ) {
                mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x14, to) // Store the `to` argument.
            amount := mload(0x34) // The `amount` is already at 0x34. We'll need to return it.
            mstore(0x00, 0xa9059cbb000000000000000000000000) // `transfer(address,uint256)`.
            // Perform the transfer, reverting upon failure.
            let success := call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                    mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Sets `amount` of ERC20 `token` for `to` to manage on behalf of the current contract.
    /// Reverts upon failure.
    function safeApprove(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
            let success := call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                    mstore(0x00, 0x3e3f8f73) // `ApproveFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Sets `amount` of ERC20 `token` for `to` to manage on behalf of the current contract.
    /// If the initial attempt to approve fails, attempts to reset the approved amount to zero,
    /// then retries the approval again (some tokens, e.g. USDT, requires this).
    /// Reverts upon failure.
    function safeApproveWithRetry(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
            // Perform the approval, retrying upon failure.
            let success := call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                    mstore(0x34, 0) // Store 0 for the `amount`.
                    mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
                    pop(call(gas(), token, 0, 0x10, 0x44, codesize(), 0x00)) // Reset the approval.
                    mstore(0x34, amount) // Store back the original `amount`.
                    // Retry the approval, reverting upon failure.
                    success := call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                    if iszero(and(eq(mload(0x00), 1), success)) {
                        // Check the `extcodesize` again just in case the token selfdestructs lol.
                        if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                            mstore(0x00, 0x3e3f8f73) // `ApproveFailed()`.
                            revert(0x1c, 0x04)
                        }
                    }
                }
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Returns the amount of ERC20 `token` owned by `account`.
    /// Returns zero if the `token` does not exist.
    function balanceOf(address token, address account) internal view returns (uint256 amount) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, account) // Store the `account` argument.
            mstore(0x00, 0x70a08231000000000000000000000000) // `balanceOf(address)`.
            amount :=
                mul( // The arguments of `mul` are evaluated from right to left.
                    mload(0x20),
                    and( // The arguments of `and` are evaluated from right to left.
                        gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                        staticcall(gas(), token, 0x10, 0x24, 0x20, 0x20)
                    )
                )
        }
    }

    /// @dev Returns the total supply of the `token`.
    /// Reverts if the token does not exist or does not implement `totalSupply()`.
    function totalSupply(address token) internal view returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, 0x18160ddd) // `totalSupply()`.
            if iszero(
                and(gt(returndatasize(), 0x1f), staticcall(gas(), token, 0x1c, 0x04, 0x00, 0x20))
            ) {
                mstore(0x00, 0x54cd9435) // `TotalSupplyQueryFailed()`.
                revert(0x1c, 0x04)
            }
            result := mload(0x00)
        }
    }

    /// @dev Sends `amount` of ERC20 `token` from `from` to `to`.
    /// If the initial attempt fails, try to use Permit2 to transfer the token.
    /// Reverts upon failure.
    ///
    /// The `from` account must have at least `amount` approved for the current contract to manage.
    function safeTransferFrom2(address token, address from, address to, uint256 amount) internal {
        if (!trySafeTransferFrom(token, from, to, amount)) {
            permit2TransferFrom(token, from, to, amount);
        }
    }

    /// @dev Sends `amount` of ERC20 `token` from `from` to `to` via Permit2.
    /// Reverts upon failure.
    function permit2TransferFrom(address token, address from, address to, uint256 amount)
        internal
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(add(m, 0x74), shr(96, shl(96, token)))
            mstore(add(m, 0x54), amount)
            mstore(add(m, 0x34), to)
            mstore(add(m, 0x20), shl(96, from))
            // `transferFrom(address,address,uint160,address)`.
            mstore(m, 0x36c78516000000000000000000000000)
            let p := PERMIT2
            let exists := eq(chainid(), 1)
            if iszero(exists) { exists := iszero(iszero(extcodesize(p))) }
            if iszero(
                and(
                    call(gas(), p, 0, add(m, 0x10), 0x84, codesize(), 0x00),
                    lt(iszero(extcodesize(token)), exists) // Token has code and Permit2 exists.
                )
            ) {
                mstore(0x00, 0x7939f4248757f0fd) // `TransferFromFailed()` or `Permit2AmountOverflow()`.
                revert(add(0x18, shl(2, iszero(iszero(shr(160, amount))))), 0x04)
            }
        }
    }

    /// @dev Permit a user to spend a given amount of
    /// another user's tokens via native EIP-2612 permit if possible, falling
    /// back to Permit2 if native permit fails or is not implemented on the token.
    function permit2(
        address token,
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        bool success;
        /// @solidity memory-safe-assembly
        assembly {
            for {} shl(96, xor(token, WETH9)) {} {
                mstore(0x00, 0x3644e515) // `DOMAIN_SEPARATOR()`.
                if iszero(
                    and( // The arguments of `and` are evaluated from right to left.
                        lt(iszero(mload(0x00)), eq(returndatasize(), 0x20)), // Returns 1 non-zero word.
                        // Gas stipend to limit gas burn for tokens that don't refund gas when
                        // an non-existing function is called. 5K should be enough for a SLOAD.
                        staticcall(5000, token, 0x1c, 0x04, 0x00, 0x20)
                    )
                ) { break }
                // After here, we can be sure that token is a contract.
                let m := mload(0x40)
                mstore(add(m, 0x34), spender)
                mstore(add(m, 0x20), shl(96, owner))
                mstore(add(m, 0x74), deadline)
                if eq(mload(0x00), DAI_DOMAIN_SEPARATOR) {
                    mstore(0x14, owner)
                    mstore(0x00, 0x7ecebe00000000000000000000000000) // `nonces(address)`.
                    mstore(
                        add(m, 0x94),
                        lt(iszero(amount), staticcall(gas(), token, 0x10, 0x24, add(m, 0x54), 0x20))
                    )
                    mstore(m, 0x8fcbaf0c000000000000000000000000) // `IDAIPermit.permit`.
                    // `nonces` is already at `add(m, 0x54)`.
                    // `amount != 0` is already stored at `add(m, 0x94)`.
                    mstore(add(m, 0xb4), and(0xff, v))
                    mstore(add(m, 0xd4), r)
                    mstore(add(m, 0xf4), s)
                    success := call(gas(), token, 0, add(m, 0x10), 0x104, codesize(), 0x00)
                    break
                }
                mstore(m, 0xd505accf000000000000000000000000) // `IERC20Permit.permit`.
                mstore(add(m, 0x54), amount)
                mstore(add(m, 0x94), and(0xff, v))
                mstore(add(m, 0xb4), r)
                mstore(add(m, 0xd4), s)
                success := call(gas(), token, 0, add(m, 0x10), 0xe4, codesize(), 0x00)
                break
            }
        }
        if (!success) simplePermit2(token, owner, spender, amount, deadline, v, r, s);
    }

    /// @dev Simple permit on the Permit2 contract.
    function simplePermit2(
        address token,
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, 0x927da105) // `allowance(address,address,address)`.
            {
                let addressMask := shr(96, not(0))
                mstore(add(m, 0x20), and(addressMask, owner))
                mstore(add(m, 0x40), and(addressMask, token))
                mstore(add(m, 0x60), and(addressMask, spender))
                mstore(add(m, 0xc0), and(addressMask, spender))
            }
            let p := mul(PERMIT2, iszero(shr(160, amount)))
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x5f), // Returns 3 words: `amount`, `expiration`, `nonce`.
                    staticcall(gas(), p, add(m, 0x1c), 0x64, add(m, 0x60), 0x60)
                )
            ) {
                mstore(0x00, 0x6b836e6b8757f0fd) // `Permit2Failed()` or `Permit2AmountOverflow()`.
                revert(add(0x18, shl(2, iszero(p))), 0x04)
            }
            mstore(m, 0x2b67b570) // `Permit2.permit` (PermitSingle variant).
            // `owner` is already `add(m, 0x20)`.
            // `token` is already at `add(m, 0x40)`.
            mstore(add(m, 0x60), amount)
            mstore(add(m, 0x80), 0xffffffffffff) // `expiration = type(uint48).max`.
            // `nonce` is already at `add(m, 0xa0)`.
            // `spender` is already at `add(m, 0xc0)`.
            mstore(add(m, 0xe0), deadline)
            mstore(add(m, 0x100), 0x100) // `signature` offset.
            mstore(add(m, 0x120), 0x41) // `signature` length.
            mstore(add(m, 0x140), r)
            mstore(add(m, 0x160), s)
            mstore(add(m, 0x180), shl(248, v))
            if iszero( // Revert if token does not have code, or if the call fails.
            mul(extcodesize(token), call(gas(), p, 0, add(m, 0x1c), 0x184, codesize(), 0x00))) {
                mstore(0x00, 0x6b836e6b) // `Permit2Failed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Approves `spender` to spend `amount` of `token` for `address(this)`.
    function permit2Approve(address token, address spender, uint160 amount, uint48 expiration)
        internal
    {
        /// @solidity memory-safe-assembly
        assembly {
            let addressMask := shr(96, not(0))
            let m := mload(0x40)
            mstore(m, 0x87517c45) // `approve(address,address,uint160,uint48)`.
            mstore(add(m, 0x20), and(addressMask, token))
            mstore(add(m, 0x40), and(addressMask, spender))
            mstore(add(m, 0x60), and(addressMask, amount))
            mstore(add(m, 0x80), and(0xffffffffffff, expiration))
            if iszero(call(gas(), PERMIT2, 0, add(m, 0x1c), 0xa0, codesize(), 0x00)) {
                mstore(0x00, 0x324f14ae) // `Permit2ApproveFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Revokes an approval for `token` and `spender` for `address(this)`.
    function permit2Lockdown(address token, address spender) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, 0xcc53287f) // `Permit2.lockdown`.
            mstore(add(m, 0x20), 0x20) // Offset of the `approvals`.
            mstore(add(m, 0x40), 1) // `approvals.length`.
            mstore(add(m, 0x60), shr(96, shl(96, token)))
            mstore(add(m, 0x80), shr(96, shl(96, spender)))
            if iszero(call(gas(), PERMIT2, 0, add(m, 0x1c), 0xa0, codesize(), 0x00)) {
                mstore(0x00, 0x96b3de23) // `Permit2LockdownFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for making calls.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibCall.sol)
/// @author Modified from ExcessivelySafeCall (https://github.com/nomad-xyz/ExcessivelySafeCall)
///
/// @dev Note:
/// - The arguments of the functions may differ from the libraries.
///   Please read the functions carefully before use.
library LibCall {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The target of the call is not a contract.
    error TargetIsNotContract();

    /// @dev The data is too short to contain a function selector.
    error DataTooShort();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  CONTRACT CALL OPERATIONS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // These functions will revert if called on a non-contract
    // (i.e. address without code).
    // They will bubble up the revert if the call fails.

    /// @dev Makes a call to `target`, with `data` and `value`.
    function callContract(address target, uint256 value, bytes memory data)
        internal
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            if iszero(call(gas(), target, value, add(data, 0x20), mload(data), codesize(), 0x00)) {
                // Bubble up the revert if the call reverts.
                returndatacopy(result, 0x00, returndatasize())
                revert(result, returndatasize())
            }
            if iszero(returndatasize()) {
                if iszero(extcodesize(target)) {
                    mstore(0x00, 0x5a836a5f) // `TargetIsNotContract()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(result, returndatasize()) // Store the length.
            let o := add(result, 0x20)
            returndatacopy(o, 0x00, returndatasize()) // Copy the returndata.
            mstore(0x40, add(o, returndatasize())) // Allocate the memory.
        }
    }

    /// @dev Makes a call to `target`, with `data`.
    function callContract(address target, bytes memory data)
        internal
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            if iszero(call(gas(), target, 0, add(data, 0x20), mload(data), codesize(), 0x00)) {
                // Bubble up the revert if the call reverts.
                returndatacopy(result, 0x00, returndatasize())
                revert(result, returndatasize())
            }
            if iszero(returndatasize()) {
                if iszero(extcodesize(target)) {
                    mstore(0x00, 0x5a836a5f) // `TargetIsNotContract()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(result, returndatasize()) // Store the length.
            let o := add(result, 0x20)
            returndatacopy(o, 0x00, returndatasize()) // Copy the returndata.
            mstore(0x40, add(o, returndatasize())) // Allocate the memory.
        }
    }

    /// @dev Makes a static call to `target`, with `data`.
    function staticCallContract(address target, bytes memory data)
        internal
        view
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            if iszero(staticcall(gas(), target, add(data, 0x20), mload(data), codesize(), 0x00)) {
                // Bubble up the revert if the call reverts.
                returndatacopy(result, 0x00, returndatasize())
                revert(result, returndatasize())
            }
            if iszero(returndatasize()) {
                if iszero(extcodesize(target)) {
                    mstore(0x00, 0x5a836a5f) // `TargetIsNotContract()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(result, returndatasize()) // Store the length.
            let o := add(result, 0x20)
            returndatacopy(o, 0x00, returndatasize()) // Copy the returndata.
            mstore(0x40, add(o, returndatasize())) // Allocate the memory.
        }
    }

    /// @dev Makes a delegate call to `target`, with `data`.
    function delegateCallContract(address target, bytes memory data)
        internal
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            if iszero(delegatecall(gas(), target, add(data, 0x20), mload(data), codesize(), 0x00)) {
                // Bubble up the revert if the call reverts.
                returndatacopy(result, 0x00, returndatasize())
                revert(result, returndatasize())
            }
            if iszero(returndatasize()) {
                if iszero(extcodesize(target)) {
                    mstore(0x00, 0x5a836a5f) // `TargetIsNotContract()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(result, returndatasize()) // Store the length.
            let o := add(result, 0x20)
            returndatacopy(o, 0x00, returndatasize()) // Copy the returndata.
            mstore(0x40, add(o, returndatasize())) // Allocate the memory.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    TRY CALL OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // These functions enable gas limited calls to be performed,
    // with a cap on the number of return data bytes to be copied.
    // The can be used to ensure that the calling contract will not
    // run out-of-gas.

    /// @dev Makes a call to `target`, with `data` and `value`.
    /// The call is given a gas limit of `gasStipend`,
    /// and up to `maxCopy` bytes of return data can be copied.
    function tryCall(
        address target,
        uint256 value,
        uint256 gasStipend,
        uint16 maxCopy,
        bytes memory data
    ) internal returns (bool success, bool exceededMaxCopy, bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            success :=
                call(gasStipend, target, value, add(data, 0x20), mload(data), codesize(), 0x00)
            let n := returndatasize()
            if gt(returndatasize(), and(0xffff, maxCopy)) {
                n := and(0xffff, maxCopy)
                exceededMaxCopy := 1
            }
            mstore(result, n) // Store the length.
            let o := add(result, 0x20)
            returndatacopy(o, 0x00, n) // Copy the returndata.
            mstore(0x40, add(o, n)) // Allocate the memory.
        }
    }

    /// @dev Makes a call to `target`, with `data`.
    /// The call is given a gas limit of `gasStipend`,
    /// and up to `maxCopy` bytes of return data can be copied.
    function tryStaticCall(address target, uint256 gasStipend, uint16 maxCopy, bytes memory data)
        internal
        view
        returns (bool success, bool exceededMaxCopy, bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            success :=
                staticcall(gasStipend, target, add(data, 0x20), mload(data), codesize(), 0x00)
            let n := returndatasize()
            if gt(returndatasize(), and(0xffff, maxCopy)) {
                n := and(0xffff, maxCopy)
                exceededMaxCopy := 1
            }
            mstore(result, n) // Store the length.
            let o := add(result, 0x20)
            returndatacopy(o, 0x00, n) // Copy the returndata.
            mstore(0x40, add(o, n)) // Allocate the memory.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      OTHER OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Bubbles up the revert.
    function bubbleUpRevert(bytes memory revertReturnData) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            revert(add(0x20, revertReturnData), mload(revertReturnData))
        }
    }

    /// @dev In-place replaces the function selector of encoded contract call data.
    function setSelector(bytes4 newSelector, bytes memory data) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(gt(mload(data), 0x03)) {
                mstore(0x00, 0x0acec8bd) // `DataTooShort()`.
                revert(0x1c, 0x04)
            }
            let o := add(data, 0x20)
            mstore(o, or(shr(32, shl(32, mload(o))), newSelector))
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {SSTORE2} from "solady/src/utils/SSTORE2.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import {LibTransient} from "solady/src/utils/LibTransient.sol";
import {UUPSUpgradeable} from "solady/src/utils/UUPSUpgradeable.sol";
import {EfficientHashLib} from "solady/src/utils/EfficientHashLib.sol";
// Interfaces
import "./Types.sol";
import {IPoolDeployer} from "./interfaces/IPoolDeployer.sol";
// Modules
import {BaseModule} from "./modules/BaseModule.sol";
import {PrincipalToken} from "./tokens/PrincipalToken.sol";
import {AccessManager, AccessManaged} from "./modules/AccessManager.sol";
import {VaultInfoResolver} from "./modules/resolvers/VaultInfoResolver.sol";
// Libraries
import {LibBlueprint} from "./utils/LibBlueprint.sol";
import {ModuleAccessor} from "./utils/ModuleAccessor.sol";
import {Errors} from "./Errors.sol";
import {Events} from "./Events.sol";
import "src/Constants.sol" as Constants;

/// @notice Deployment Suite
///  - Factory is responsible for deploying PrincipalToken, YT and Pool instances.
///  - Factory is agnostic to type of AMM by supporting multiple pool deployers implementations.
///  - Factory supports multiple principalToken implementations.
contract Factory is AccessManaged, UUPSUpgradeable {
    /// @notice EIP1967 proxy immutable arguments offset
    uint256 constant ARGS_ON_ERC1967_FACTORY_ARG_OFFSET = 0x00;

    /// @notice Default split ratio for the fee module (100% to curator)
    uint256 public constant DEFAULT_SPLIT_RATIO_BPS = Constants.DEFAULT_SPLIT_RATIO_BPS;

    /// @notice Pool deployers (factories)
    /// @dev Support multiple pool deployers for different AMM implementations.
    mapping(address deployer => bool enable) public s_poolDeployers;

    /// @notice Registered PrincipalToken implementations: PrincipalToken EIP5020 Blueprint -> YieldToken EIP5020 Blueprint
    /// @dev `ytBlueprint` == 0x0 means the PrincipalToken is disabled.
    /// @dev Key design decisions:
    /// 1. EIP-5202: Efficient bytecode cloning for multiple instances.
    /// 2. Minimal proxy: Avoids delegatecall overhead. PrincipalToken is frequently called.
    /// 3. Factory: Separate factory for PrincipalToken causes code duplication.
    mapping(address blueprint => address ytBlueprint) public s_ytBlueprints;

    /// @notice Registered resolver blueprints
    /// @notice resolver blueprint -> enable
    mapping(address blueprint => bool enable) public s_resolverBlueprints;

    /// @notice AccessManager Minimal proxy implementation
    mapping(address implementation => bool enable) public s_accessManagerImplementations;

    /// @notice Lookup for pool and principalToken instances
    /// @dev This is the only way to know whether a pool is canonical or not.
    mapping(address pool => address deployer) public s_pools;

    mapping(address principalToken => address blueprint) public s_principalTokens;

    /// @notice Minimal proxy implementation for modules
    mapping(ModuleIndex moduleType => mapping(address implementation => bool enabled)) public s_modules;

    /// @dev Preview function for FE integration.
    address[] s_poolList;

    /// @notice Receiver of Napier finance protocol fee
    address public s_treasury;

    /// @notice Constructor arguments for PrincipalToken instance
    struct ConstructorArg {
        address resolver;
        uint256 expiry;
        address yt;
        address accessManager;
        address modules; // SSSTORE2 pointer that stores module instances addresses
    }

    LibTransient.TBytes internal _tempArgs;

    struct Suite {
        address accessManagerImpl;
        address ptBlueprint;
        address resolverBlueprint;
        address poolDeployerImpl;
        bytes poolArgs;
        bytes resolverArgs;
    }

    struct ModuleParam {
        ModuleIndex moduleType;
        address implementation; // EIP-1167 CWIA proxy implementation
        bytes immutableData; // Immutable data for module instance. Watch out arbitrary data from user side.
    }

    /// @notice Deploy new PrincipalToken, YT, pool and modules.
    /// @notice Revert if the implementation is zero address.
    /// @notice Revert if the expiry is less than the current timestamp.
    /// @notice Revert if the suite is invalid.
    /// @param suite Suite of the PrincipalToken instance.
    /// @param params Module parameters.
    /// @param expiry Expiry timestamp of the PrincipalToken.
    /// @param curator Address of the curator. If the address is zero, no one can control the PrincipalToken instance.
    function deploy(Suite calldata suite, ModuleParam[] calldata params, uint256 expiry, address curator)
        external
        returns (address pt, address yt, address pool)
    {
        if (
            suite.ptBlueprint == address(0) || !s_resolverBlueprints[suite.resolverBlueprint]
                || !s_poolDeployers[suite.poolDeployerImpl] || !s_accessManagerImplementations[suite.accessManagerImpl]
        ) {
            revert Errors.Factory_InvalidSuite();
        }
        if (expiry <= block.timestamp) revert Errors.Factory_InvalidExpiry();

        // Deploy resolver and access manager
        address resolver = LibBlueprint.create(suite.resolverBlueprint, suite.resolverArgs);
        address accessManager = LibClone.clone(suite.accessManagerImpl);
        AccessManager(accessManager).initializeOwner(curator);

        bytes32 salt =
            EfficientHashLib.hash(block.chainid, expiry, uint256(uint160(resolver)), uint256(uint160(msg.sender)));
        pt = LibBlueprint.computeCreate2Address(salt, suite.ptBlueprint, "");

        // Stack too deep workaround
        {
            // Deploy modules, YT and PT
            address pointer = _deployModules(pt, params, true);

            yt = LibBlueprint.create(s_ytBlueprints[suite.ptBlueprint], abi.encode(pt));
            LibTransient.setCompat(_tempArgs, abi.encode(ConstructorArg(resolver, expiry, yt, accessManager, pointer)));
            LibBlueprint.create2(suite.ptBlueprint, salt);
        }

        address target = VaultInfoResolver(resolver).target();
        pool = IPoolDeployer(suite.poolDeployerImpl).deploy(target, pt, suite.poolArgs);

        emit Events.Deployed(pt, yt, pool, expiry, target);

        s_poolList.push(pool);
        s_pools[pool] = suite.poolDeployerImpl;
        s_principalTokens[pt] = suite.ptBlueprint;

        LibTransient.clearCompat(_tempArgs);
    }

    /// @notice Update existing modules for the PrincipalToken instance.
    /// @dev Revert if the caller is not authorized by the `AccessManager` of the `PrincipalToken` instance.
    /// @dev Revert if the fee module is trying to update.
    /// @dev Revert if the module type is out of bounds.
    /// @dev Revert if the module implementation is not registered.
    function updateModules(address pt, ModuleParam[] calldata params)
        external
        exists(pt)
        restrictedBy(PrincipalToken(pt).i_accessManager())
    {
        // Check if any of the params is trying to update the fee module
        for (uint256 i = 0; i != params.length;) {
            if (params[i].moduleType == FEE_MODULE_INDEX) revert Errors.Factory_CannotUpdateFeeModule();
            unchecked {
                ++i;
            }
        }

        address pointer = _deployModules(pt, params, false);
        PrincipalToken(pt).setModules(pointer);
    }

    function _deployModules(address pt, ModuleParam[] calldata params, bool initialize)
        internal
        returns (address pointer)
    {
        // If the principalToken is not set, it means the PrincipalToken instance is being deployed and the modules are not set yet.
        address[] memory modules =
            initialize ? new address[](MAX_MODULES) : ModuleAccessor.read(PrincipalToken(pt).s_modules());

        for (uint256 i = 0; i != params.length;) {
            ModuleParam calldata param = params[i];
            // CHECK
            ModuleIndex t = param.moduleType;
            if (!isValidImplementation(t, param.implementation)) revert Errors.Factory_InvalidModule();

            address instance = LibClone.clone(param.implementation, abi.encode(pt, param.immutableData));
            BaseModule(instance).initialize();

            // Replace the module address with the new one
            ModuleAccessor.set(modules, t, instance); // Revert if index is out of bounds

            emit Events.ModuleUpdated(t, instance, pt);

            unchecked {
                ++i;
            }
        }
        // CHECK: FeeModule is mandatory
        if (ModuleAccessor.get(modules, FEE_MODULE_INDEX) == address(0)) {
            revert Errors.Factory_FeeModuleRequired();
        }

        // Store the module instances
        pointer = SSTORE2.write(abi.encode(modules));
    }

    /// @notice Set PrincipalToken implementation
    /// @dev Revert if the caller is not Dev role.
    /// @param ytBlueprint EIP-5202 YT Blueprint (Zero address means set the `ptBlueprint` disabled)
    function setPrincipalTokenBlueprint(address ptBlueprint, address ytBlueprint)
        external
        restricted
        notZeroAddress(ptBlueprint)
    {
        s_ytBlueprints[ptBlueprint] = ytBlueprint;
        emit Events.PrincipalTokenImplementationSet(ptBlueprint, ytBlueprint);
    }

    /// @dev Revert if the caller is not Dev role.
    function setPoolDeployer(address deployer, bool enable) external restricted notZeroAddress(deployer) {
        s_poolDeployers[deployer] = enable;
        emit Events.PoolDeployerSet(deployer, enable);
    }

    /// @dev Revert if the caller is not Dev role.
    function setAccessManagerImplementation(address implementation, bool enable)
        external
        restricted
        notZeroAddress(implementation)
    {
        s_accessManagerImplementations[implementation] = enable;
        emit Events.AccessManagerImplementationSet(implementation, enable);
    }

    /// @dev Revert if the caller is not Dev role.
    function setResolverBlueprint(address blueprint, bool enable) external restricted notZeroAddress(blueprint) {
        s_resolverBlueprints[blueprint] = enable;
        emit Events.ResolverBlueprintSet(blueprint, enable);
    }

    /// @dev Revert if the caller is not Dev role.
    function setModuleImplementation(ModuleIndex moduleType, address implementation, bool enable)
        external
        restricted
        notZeroAddress(implementation)
    {
        if (!moduleType.isSupportedByFactory()) revert Errors.Factory_InvalidModuleType();

        s_modules[moduleType][implementation] = enable;
        emit Events.ModuleImplementationSet(moduleType, implementation, enable);
    }

    /// @dev Revert if treasury is zero address or the caller is not Admin
    function setTreasury(address treasury) external restricted notZeroAddress(treasury) {
        s_treasury = treasury;
        emit Events.TreasurySet(treasury);
    }

    function isValidImplementation(ModuleIndex moduleType, address implementation) public view returns (bool) {
        return moduleType.isSupportedByFactory() && s_modules[moduleType][implementation];
    }

    /// @notice Returns the module address for a given principal token and module type
    /// @param principalToken The address of the principal token
    /// @param moduleType The type of module to look up
    /// @dev Reverts if the principal token does not exist or if the module is not found
    function moduleFor(address principalToken, ModuleIndex moduleType)
        public
        view
        exists(principalToken)
        returns (address module)
    {
        module = ModuleAccessor.get(ModuleAccessor.read(PrincipalToken(principalToken).s_modules()), moduleType);
        if (module == address(0)) revert Errors.Factory_ModuleNotFound();
    }

    /// @notice Return pool list for FE integration.
    function getPoolList() external view returns (address[] memory) {
        return s_poolList;
    }

    /// @notice Return constructor args.
    /// @dev For easier verification, PrincipalToken instance callbacks and gets constructor arg.
    function args() external view returns (ConstructorArg memory) {
        return abi.decode(LibTransient.getCompat(_tempArgs), (ConstructorArg));
    }

    function i_accessManager() public view override returns (AccessManager) {
        bytes memory arg = LibClone.argsOnERC1967(
            address(this), ARGS_ON_ERC1967_FACTORY_ARG_OFFSET, ARGS_ON_ERC1967_FACTORY_ARG_OFFSET + 0x20
        );
        return AccessManager(abi.decode(arg, (address)));
    }

    modifier exists(address principalToken) {
        if (s_principalTokens[principalToken] == address(0)) {
            revert Errors.Factory_PrincipalTokenNotFound();
        }
        _;
    }

    modifier notZeroAddress(address implementation) {
        if (implementation == address(0)) {
            revert Errors.Factory_InvalidAddress();
        }
        _;
    }

    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

/// @title VaultInfoResolver
/// @notice Abstract contract for resolving vault information.
abstract contract VaultInfoResolver {
    function asset() public view virtual returns (address);
    function target() public view virtual returns (address);
    function scale() public view virtual returns (uint256);
    function assetDecimals() public view virtual returns (uint8);
    function decimals() public view virtual returns (uint8);
    function label() public pure virtual returns (bytes32);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {DynamicArrayLib} from "solady/src/utils/DynamicArrayLib.sol";
import {SafeCastLib} from "solady/src/utils/SafeCastLib.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {ECDSA} from "solady/src/utils/ECDSA.sol";

// Interfaces
import "../Types.sol";
import {IHook} from "../interfaces/IHook.sol";
import {FeeModule} from "../modules/FeeModule.sol";
import {IRewardProxy} from "../interfaces/IRewardProxy.sol";
import {VerifierModule} from "../modules/VerifierModule.sol";
import {VaultInfoResolver} from "../modules/resolvers/VaultInfoResolver.sol";
import {Factory} from "../Factory.sol";
import {YieldToken} from "./YieldToken.sol";
// Libraries
import {LibRewardProxy} from "../utils/LibRewardProxy.sol";
import {ModuleAccessor} from "../utils/ModuleAccessor.sol";
import {TokenNameLib} from "../utils/TokenNameLib.sol";
import {CustomRevert} from "../utils/CustomRevert.sol";
import {LibExpiry} from "../utils/LibExpiry.sol";
import {Events} from "../Events.sol";
import {Errors} from "../Errors.sol";
import {BASIS_POINTS} from "../Constants.sol";
// Math & Fee logic
import {FeePctsLib} from "../utils/FeePctsLib.sol";
import {Snapshot, Yield, YieldMathLib} from "../utils/YieldMathLib.sol";
import {Reward, RewardIndex, RewardMathLib} from "../utils/RewardMathLib.sol";
// Implements
import {EIP5095} from "../interfaces/EIP5095.sol";
// Inherits
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "solady/src/utils/ReentrancyGuard.sol";
import {ERC20} from "solady/src/tokens/ERC20.sol";
import {AccessManager, AccessManaged} from "../modules/AccessManager.sol";
import {LibApproval} from "../utils/LibApproval.sol";

/// @dev Modularity
/// PrincipalToken instance is deployed with a AccessManager instance through the Factory.
///  - FeeModule instance that manages the fee logic for the PrincipalToken instance. It is not upgradable and is managed by the factory's AccessManager.
///  - AccessManager instance that manages the access control for the PrincipalToken instance. It is not upgradable.
///  - RewardProxyModule instance that manages the additional reward collection for the PrincipalToken instance. It is upgradable.
///  - Resolver instance that provides vault share price. It is not upgradable.
///  - YieldToken instance that manages the yield token for the PrincipalToken instance. It is not upgradable.
/// @dev Ownership
///  - On deployment, the ownership of the PrincipalToken instance is transferred to a `curator` specified by a caller.
///  - The curator CAN grant and revoke roles for a PrincipalToken instance.
///  - The curator CAN pause a PrincipalToken instance or change the maximum deposit cap.
/// @dev Access control against Napier Finance
///  - Napier CAN NOT change any roles for a PrincipalToken instance.
///  - Napier CAN NOT change any modules for a PrincipalToken instance.
///  - Napier CAN NOT pause a PrincipalToken instance or change the maximum deposit cap.
/// @dev Princiapl Token Lifecycle:
/// - The first user interaction after the expiry triggers the settlement. The user is called the `settler`
/// Three types of phases: Pre expiry, Post expiry, Post settlement
/// Two types of events:
/// - Deployment: once the principalToken is deployed, the principalToken is in the pre expiry phase
/// - Settlement: once the first user interacts after the expiry, the principalToken is in the post settlement phase. The user is called the `settler`
/// Until the settlement, pre-settlement performance fee is charged. Once the settlement is done, post-settlement performance fee is charged.
/// It means the settler is charged with pre-settlement performance fee though the timestamp at the settlement is after the expiry.
///
/// - ---> Pre expiry (Issue-enabled) ---> Post expiry (Redeem-enabled) ---> Post settlement
///    ^                                                                 ^
/// Deployment                                                       Settlement
///
/// @dev User interaction:
/// - Pre expiry: Supply, Issue, Unite, Combine, Collect are enabled.
/// - Post expiry ~ Post settlement: Withdraw, Redeem, Unite, Combine, Collect are enabled
/// @dev Yield Token Lifecycle:
/// - Users can collect yield as many times as they want whenerver they want.
/// @dev Yield Accrual mechanism:
/// - Yield is accrued every time the a user's YT balance changes (supply, issue, redeem, withdraw, transfer, collect)
/// - Accrued yield is calculated based on the difference between the maxscale at the time of the user's last interaction and the current maxscale. See `YieldMathLib`
/// - Accrued yield is proportional to the user's YT balance
/// - Accrued yield is collected in the target token
/// - Accrued yield is collected by the user or approved collectors by the user
/// @dev Fee mechanism:
/// - Three types of fees: issuance fee, performance fee (pre settlement), redemption fee and post settlement fee (post settlement)
/// - All fees are collected in the target token
/// - Fees are split between the curator and the protocol based on the fee split ratio
/// - Performance fee is applied against the accrued yield
/// - The performance fee is collected every time the user interacts with the contract
/// @dev ERC20 support:
/// - The target token must not be a rebase token
/// - The target token must not be fee-on-transfer token
/// - The target token must have less than or equal to 18 decimals
/// - The target token must not be double-entry point token like TrueUSD.
/// - The reward token must not be a rebase token
/// - The reward token must not be fee-on-transfer token
/// - The reward token must not be the target token
/// @dev Price oracle:
/// AMM may provide the price oracle for the PT.
/// Important security note: It may be possible for an attacker to flash mint tons of PT, sell those on TwoCrypto or AMM and decrease PT price
/// atomically, and then exploit an external lending market that uses this PT as collateral.
contract PrincipalToken is ERC20, LibApproval, AccessManaged, Pausable, ReentrancyGuard, EIP5095 {
    using CustomRevert for bytes4;
    using SafeCastLib for uint256;
    using FeePctsLib for FeePcts;
    using ModuleAccessor for address[];
    using ModuleAccessor for address;
    using DynamicArrayLib for uint256[];

    /// @notice Principal token implementation version
    bytes32 public constant VERSION = "2.0.0";

    /// @dev `keccak256("PermitCollector(address owner,address collector,uint256 nonce,uint256 deadline)")`.
    bytes32 private constant PERMIT_COLLECTOR_TYPEHASH =
        0xabaa81be0e21ab93788e05cd5409517fd2908fd1c16213aab992c623ac2cf0a4;

    /// @dev Solady.ERC20 nonces slot seed
    uint256 private constant _NONCES_SLOT_SEED = 0x38377508;

    AccessManager internal immutable _i_accessManager;

    /// @notice Expiry timestamp of the principalToken in seconds
    uint256 internal immutable i_expiry;

    /// @notice Factory that deployed this contract
    Factory public immutable i_factory;

    /// @notice YieldToken that this principalToken is associated with
    YieldToken public immutable i_yt;

    /// @notice Resolver that this principalToken is associated with
    VaultInfoResolver public immutable i_resolver;

    /// @notice Base asset that the resolver is associated with
    ERC20 public immutable i_asset;

    /// @notice Yield bearing token (e.g wstETH, rETH, etc) that this principalToken accepts as deposit
    ERC20 internal immutable i_target;

    /// @notice Name hash for gas saving
    /// @dev Name hash is calculated based on the underlying token name at the time of deployment.
    bytes32 internal immutable i_nameHash;

    /// @notice Flag to indicate if the principalToken is settled
    bool internal s_isSettled;

    /// @notice SSTORE2 pointer for module addresses storage
    address public s_modules;

    /// @notice Snapshot of the principalToken at the last update
    Snapshot internal s_snapshot;

    /// @notice Name and symbol string for efficient storage
    /// @dev Design: For downsizing contract, we will store the name and symbol.
    /// - Composing the name and symbol string on the fly increases the contract size.
    /// - `ShortString` type supports only up to 31 bytes. It's not enough for long token names.
    /// - SSTORE2 takes minimum 32k gas.
    LibString.StringStorage internal s_name;

    LibString.StringStorage internal s_symbol;

    /// @notice User yield index
    mapping(address account => Yield) internal s_userYields;

    /// @notice Fee accruals in units of underlying token
    uint128 internal s_curatorFee;

    uint128 internal s_protocolFee;

    struct RewardRecord {
        mapping(address account => Reward) userRewards;
        uint128 curatorReward; // Fee accruals in units of reward token
        uint128 protocolReward; // Fee accruals in units of reward token
        RewardIndex globalIndex;
    }

    /// @notice Reward data
    mapping(address reward => RewardRecord) internal s_rewardRecords;

    /// @dev None direct constructor args for easier verification and deterministic deployment
    constructor() payable {
        Factory.ConstructorArg memory args = Factory(msg.sender).args();

        i_factory = Factory(msg.sender);
        address target = VaultInfoResolver(args.resolver).target();

        i_expiry = args.expiry;
        i_resolver = VaultInfoResolver(args.resolver);
        i_yt = YieldToken(args.yt);
        i_target = ERC20(target);
        i_asset = ERC20(VaultInfoResolver(args.resolver).asset());
        _i_accessManager = AccessManager(args.accessManager);
        s_modules = args.modules;

        string memory tokenName = TokenNameLib.principalTokenName(target, i_expiry);
        i_nameHash = keccak256(bytes(tokenName));
        LibString.set(s_name, tokenName);
        LibString.set(s_symbol, TokenNameLib.principalTokenSymbol(target, i_expiry));
    }

    /// @notice Deposit `shares` of YBT and mint `principal` amount of PT and YT to `receiver`
    function supply(uint256 shares, address receiver) external returns (uint256) {
        return supply(shares, receiver, "");
    }

    function supply(uint256 shares, address receiver, bytes memory data)
        public
        nonReentrant
        whenNotPaused
        notExpired
        returns (uint256)
    {
        address[] memory m = ModuleAccessor.read(s_modules);
        Snapshot memory snapshot = s_snapshot;

        FeePcts feePcts = FeeModule(m.unsafeGet(FEE_MODULE_INDEX)).getFeePcts();

        // Fetch share price (scale) and update the global index and calculate the performance fee (not just for `receiver`) and issuance fee
        // Calculate the principal amount of PT and YT to mint
        (uint256 principal, uint256 fee) = _previewSupply(snapshot, feePcts, shares);

        uint256 ytBalance = i_yt.balanceOf(receiver);

        // Veriy deposit cap and other conditions
        _verify(m, shares, principal, receiver);

        _writeState(snapshot, feePcts, fee);

        _accrueYield(snapshot, receiver, ytBalance);

        // Accrue rewards if any
        TokenReward[] memory rewards = _delegateCallRewardProxy(m);
        _accrueRewards(feePcts, rewards, address(0), 0, receiver, ytBalance);

        // Mint PT and YT and call the hook if any
        _supplyWithHook(msg.sender, receiver, shares, principal, data);

        return principal;
    }

    function issue(uint256 principal, address receiver) external returns (uint256) {
        return issue(principal, receiver, "");
    }

    /// @notice Issue `principal` amount of PT and YT to `receiver` in return for `shares` of YBT
    function issue(uint256 principal, address receiver, bytes memory data)
        public
        nonReentrant
        whenNotPaused
        notExpired
        returns (uint256)
    {
        address[] memory m = ModuleAccessor.read(s_modules);
        Snapshot memory snapshot = s_snapshot;

        FeePcts feePcts = FeeModule(m.unsafeGet(FEE_MODULE_INDEX)).getFeePcts();

        // Fetch share price (scale) and update the global index and calculate the fee and issuance fee
        // Calculate the principal amount of PT and YT to mint
        (uint256 shares, uint256 fee) = _previewIssue(snapshot, feePcts, principal);

        uint256 ytBalance = i_yt.balanceOf(receiver);

        // Veriy deposit cap and other conditions
        _verify(m, shares, principal, receiver);

        _writeState(snapshot, feePcts, fee);

        _accrueYield(snapshot, receiver, ytBalance);

        // Accrue rewards if any
        TokenReward[] memory rewards = _delegateCallRewardProxy(m);
        _accrueRewards(feePcts, rewards, address(0), 0, receiver, ytBalance);

        // Mint PT and YT and call the hook if any
        _supplyWithHook(msg.sender, receiver, shares, principal, data);

        return shares;
    }

    function _supplyWithHook(address by, address receiver, uint256 shares, uint256 principal, bytes memory data)
        internal
    {
        uint256 expected = SafeTransferLib.balanceOf(address(i_target), address(this)) + shares;

        Events.emitSupply({by: by, receiver: receiver, shares: shares, principal: principal});

        // Mint PT and YT
        if (data.length > 0) {
            // Optimistically flash mint
            _mint(receiver, principal);
            IHook(by).onSupply(shares, principal, data);
        } else {
            SafeTransferLib.safeTransferFrom(address(i_target), by, address(this), shares);
            _mint(receiver, principal);
        }
        if (SafeTransferLib.balanceOf(address(i_target), address(this)) < expected) {
            Errors.PrincipalToken_InsufficientSharesReceived.selector.revertWith();
        }
    }

    function unite(uint256 shares, address receiver) external returns (uint256) {
        return unite(shares, receiver, "");
    }

    /// @notice Burn `shares` amount of PT and YT and send back `shares` of YBT to `receiver`
    /// @notice This function doesn't redeem accrued yield at the same time
    /// @dev This API shouldn't have an `owner` parameter because the same amount of YT are burned regardless of `owner`'s approval towards `msg.sender`
    function unite(uint256 shares, address receiver, bytes memory data)
        public
        nonReentrant
        settleIfExpired
        returns (uint256)
    {
        address[] memory m = ModuleAccessor.read(s_modules);
        Snapshot memory snapshot = s_snapshot;

        FeePcts feePcts = FeeModule(m.unsafeGet(FEE_MODULE_INDEX)).getFeePcts();
        uint256 ytBalance = i_yt.balanceOf(msg.sender);

        (uint256 principal, uint256 fee) = _previewUnite(snapshot, feePcts, shares);

        _writeState(snapshot, feePcts, fee);

        _accrueYield(snapshot, msg.sender, ytBalance);

        // Accrue rewards if any
        TokenReward[] memory rewards = _delegateCallRewardProxy(m);
        _accrueRewards(feePcts, rewards, msg.sender, ytBalance, address(0), 0);

        _uniteWithHook(msg.sender, receiver, shares, principal, data);

        return principal;
    }

    /// @notice Burn `msg.sender`'s `principal` amount of PT and YT and send back `shares` of YBT to `receiver`.
    /// @notice This function doesn't redeem accrued yield at the same time.
    /// @dev This API shouldn't have a `owner` parameter because the same amount of YT are burned regardless of `owner`'s approval towards `msg.sender`
    function combine(uint256 principal, address receiver) external returns (uint256) {
        return combine(principal, receiver, "");
    }

    function combine(uint256 principal, address receiver, bytes memory data)
        public
        nonReentrant
        settleIfExpired
        returns (uint256)
    {
        address[] memory m = ModuleAccessor.read(s_modules);
        Snapshot memory snapshot = s_snapshot;

        FeePcts feePcts = FeeModule(m.unsafeGet(FEE_MODULE_INDEX)).getFeePcts();
        uint256 ytBalance = i_yt.balanceOf(msg.sender);

        (uint256 shares, uint256 fee) = _previewCombine(snapshot, feePcts, principal);

        _writeState(snapshot, feePcts, fee);

        _accrueYield(snapshot, msg.sender, ytBalance);

        // Accrue rewards if any
        TokenReward[] memory rewards = _delegateCallRewardProxy(m);
        _accrueRewards(feePcts, rewards, msg.sender, ytBalance, address(0), 0);

        _uniteWithHook(msg.sender, receiver, shares, principal, data);

        return shares;
    }

    function _uniteWithHook(address by, address receiver, uint256 shares, uint256 principal, bytes memory data)
        internal
    {
        Events.emitUnite({by: by, receiver: receiver, shares: shares, principal: principal});

        SafeTransferLib.safeTransfer(address(i_target), receiver, shares);
        if (data.length > 0) {
            IHook(by).onUnite(shares, principal, data);
        }
        _burn(by, principal);
        i_yt.burn(by, principal);
    }

    /// @notice Claim `shares` of accrued yield (in unit of YBT) and rewards for `owner` and transfer it to `receiver`.
    /// @notice If the caller is not `owner`, the caller must be approved by `owner`.
    function collect(address receiver, address owner)
        external
        nonReentrant
        ownerOrApprovedCollector(owner)
        settleIfExpired
        returns (uint256, TokenReward[] memory rewards)
    {
        address[] memory m = ModuleAccessor.read(s_modules);
        Snapshot memory snapshot = s_snapshot;
        FeePcts feePcts = FeeModule(m.unsafeGet(FEE_MODULE_INDEX)).getFeePcts();

        uint256 ytBalance = i_yt.balanceOf(owner);

        // Note Calculate the newly accrued interest and returns the total accrued interest
        (uint256 shares, uint256 fee) = _previewCollect(snapshot, feePcts, owner, ytBalance);

        _writeState(snapshot, feePcts, fee);

        // Update the user's userIndex and reset the pending yield
        _accrueYield(snapshot, owner, ytBalance);
        delete s_userYields[owner].accrued;

        Events.emitInterestCollected({by: msg.sender, owner: owner, receiver: receiver, shares: shares});

        // Accrue rewards and send it to the receiver
        rewards = _delegateCallRewardProxy(m);
        _accrueRewards(feePcts, rewards, owner, ytBalance, address(0), 0);

        for (uint256 i; i != rewards.length;) {
            rewards[i].amount = _collectRewards(rewards[i].token, receiver, owner); // Reuse the memory to save gas
            unchecked {
                ++i;
            }
        }

        SafeTransferLib.safeTransfer(address(i_target), receiver, shares);
        return (shares, rewards);
    }

    /// @notice Users can collect rewards but not update the accrued rewards.
    /// This function is useful when `RewardProxyModule.rewardTokens()` doesn't include tokens that the user wants to collect.
    function collectRewards(address[] calldata rewardTokens, address receiver, address owner)
        external
        nonReentrant
        ownerOrApprovedCollector(owner)
        returns (uint256[] memory result)
    {
        result = new uint256[](rewardTokens.length);
        for (uint256 i; i != rewardTokens.length;) {
            DynamicArrayLib.set(result, i, _collectRewards(rewardTokens[i], receiver, owner)); // Unsafe access without bounds check
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Note PrincipalToken doesn't support double-entry point tokens.
    function _collectRewards(address token, address receiver, address owner) internal returns (uint256 rewards) {
        if (token == address(i_target)) Errors.PrincipalToken_ProtectedToken.selector.revertWith(); // Prevent collecting the underlying token

        Reward storage userReward = s_rewardRecords[token].userRewards[owner];
        rewards = userReward.accrued;
        delete userReward.accrued;

        Events.emitRewardsCollected({
            by: msg.sender,
            owner: owner,
            receiver: receiver,
            rewardToken: token,
            rewards: rewards
        });

        SafeTransferLib.safeTransfer(token, receiver, rewards);
    }

    /// @notice Updates the user's accrued yield and rewards on YieldToken transfer events
    /// @dev This function is called by the YieldToken contract whenever a transfer happens
    /// See {YieldToken-transfer} and {YieldToken-transferFrom}
    function onYtTransfer(address owner, address receiver, uint256 balanceOfOwner, uint256 balanceOfReceiver)
        external
        nonReentrant
        settleIfExpired
    {
        if (msg.sender != address(i_yt)) Errors.PrincipalToken_OnlyYieldToken.selector.revertWith();

        address[] memory m = ModuleAccessor.read(s_modules);
        Snapshot memory snapshot = s_snapshot;

        FeePcts feePcts = FeeModule(m.unsafeGet(FEE_MODULE_INDEX)).getFeePcts();
        {
            // Note: Calculation must follow `_previewCollect` logic
            uint256 perfFeePct = s_isSettled ? feePcts.getPostSettlementFeePctBps() : feePcts.getPerformanceFeePctBps();

            uint256 fee = _updateIndex(snapshot, perfFeePct);

            _writeState(snapshot, feePcts, fee);

            // Update the two users' accrued yield
            _accrueYield(snapshot, owner, balanceOfOwner);
            _accrueYield(snapshot, receiver, balanceOfReceiver);
        }

        TokenReward[] memory rewards = _delegateCallRewardProxy(m);
        _accrueRewards(feePcts, rewards, owner, balanceOfOwner, receiver, balanceOfReceiver);
    }

    /// @notice This function doesn't redeem accrued yield at the same time
    function withdraw(uint256 shares, address receiver, address owner)
        external
        nonReentrant
        expired
        settleIfExpired
        returns (uint256)
    {
        Snapshot memory snapshot = s_snapshot;
        FeePcts feePcts = FeeModule(ModuleAccessor.read(s_modules).unsafeGet(FEE_MODULE_INDEX)).getFeePcts();

        // Fetch fresh share price (scale) and update the global index and calculate the performance fee
        (uint256 principal, uint256 fee) = _previewWithdraw(snapshot, feePcts, shares);

        // Update snapshot and fees
        _writeState(snapshot, feePcts, fee);

        _redeem(msg.sender, owner, receiver, shares, principal);

        return principal;
    }

    /// @notice Burn `owner`'s `principal` amount of PT and send `shares` of YBT to `receiver`.
    /// @notice If owner is not `msg.sender`, the caller must be approved by `owner` at least `principal` amount of PT.
    /// @notice Revert if the principalToken is not expired.
    /// @notice This function doesn't redeem accrued yield at the same time.
    function redeem(uint256 principal, address receiver, address owner)
        external
        nonReentrant
        expired
        settleIfExpired
        returns (uint256)
    {
        Snapshot memory snapshot = s_snapshot;
        FeePcts feePcts = FeeModule(ModuleAccessor.read(s_modules).unsafeGet(FEE_MODULE_INDEX)).getFeePcts();

        // Fetch fresh share price (scale) and update the global index and calculate the performance fee and redemption fee
        (uint256 shares, uint256 fee) = _previewRedeem(snapshot, feePcts, principal);

        // Update snapshot and fees
        _writeState(snapshot, feePcts, fee);

        // Note Redeem doesn't update the user's accrued yield because the YT balance doesn't change.
        // So the accrued yield is not updated here.
        _redeem(msg.sender, owner, receiver, shares, principal);

        return shares;
    }

    function _redeem(address by, address owner, address receiver, uint256 shares, uint256 principal) internal {
        Events.emitRedeem({by: by, owner: owner, receiver: receiver, shares: shares, principal: principal});

        // Check allowance and burn the principal amount from the owner
        if (msg.sender != owner) _spendAllowance(owner, msg.sender, principal);
        _burn(owner, principal);

        // Transfer the shares to the receiver
        SafeTransferLib.safeTransfer(address(i_target), receiver, shares);
    }

    /// @notice the caller approves `collector` collects accrued yield through `collect` and `collectRewards` functions
    function setApprovalCollector(address collector, bool isApproved) external {
        _setApprovalCollector(msg.sender, collector, isApproved);
    }

    /// @notice The signature based `setApprovalCollector` function that allows `owner` to approve `collector` to collect accrued yield and rewards
    /// @dev This ECDSA implementation does NOT check if a signature is non-malleable.
    /// @dev Mark `external` visibility to make sure upper bits of `owner`, `collector` and etc are clean.
    function permitCollector(address owner, address collector, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        assembly {
            // Revert if the block timestamp is greater than `deadline`.
            if gt(timestamp(), deadline) {
                mstore(0x00, 0x1a15a3cc) // `PermitExpired()`.
                revert(0x1c, 0x04)
            }
        }

        uint256 nonce = nonces(owner);
        bytes32 domainSeparator = DOMAIN_SEPARATOR();

        bytes32 digest;
        /// @solidity memory-safe-assembly
        assembly {
            // Dev: Forked from Solady's ERC20 permit and EIP712 hashTypedData implementation.
            let m := mload(0x40) // Grab the free memory pointer.
            // Prepare the struct hash.
            mstore(m, PERMIT_COLLECTOR_TYPEHASH)
            mstore(add(m, 0x20), owner) // Upper 96 bits are already clean.
            mstore(add(m, 0x40), collector) // Upper 96 bits are already clean.
            mstore(add(m, 0x60), nonce)
            mstore(add(m, 0x80), deadline)
            let structHash := keccak256(m, 0xa0)
            // Prepare the digest (hashTypedData)
            mstore(0x00, 0x1901000000000000) // Store "\x19\x01".
            mstore(0x1a, domainSeparator) // Store the domain separator.
            mstore(0x3a, structHash) // Store the struct hash.
            digest := keccak256(0x18, 0x42)
            // Restore the part of the free memory slot that was overwritten.
            mstore(0x3a, 0)
        }

        address signer = ECDSA.recover(digest, v, r, s);
        if (signer != owner) InvalidPermit.selector.revertWith();

        // WRITE
        assembly {
            // Compute the nonce slot and increment the nonce without overflow check.
            mstore(0x0c, _NONCES_SLOT_SEED)
            mstore(0x00, owner)
            sstore(keccak256(0x0c, 0x20), add(nonce, 1))
        }
        _setApprovalCollector(owner, collector, true);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      INTERNAL HELPERS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _setApprovalCollector(address owner, address collector, bool isApproved) internal {
        setApproval(owner, collector, isApproved);
        Events.emitSetApprovalCollector({owner: owner, collector: collector, approved: isApproved});
    }

    /// @dev This function should be called every time snapshot changes (core logic)
    function _writeState(Snapshot memory snapshot, FeePcts feePcts, uint256 fee) internal {
        uint256 curatorFee = (fee * feePcts.getSplitPctBps()) / BASIS_POINTS; // round down or up is not a big deal here

        s_snapshot = snapshot;
        s_curatorFee = (s_curatorFee + curatorFee).toUint128();
        s_protocolFee = (s_protocolFee + fee - curatorFee).toUint128();

        Events.emitYieldFeeAccrued(fee);
    }

    /// @dev This function should be called every time the `user`'s YT balance changes
    function _accrueYield(Snapshot memory snapshot, address user, uint256 ytBalance) internal {
        uint256 accrued = YieldMathLib.accrueUserYield(s_userYields, snapshot.globalIndex, user, ytBalance);
        Events.emitYieldAccrued(user, accrued, snapshot.globalIndex.unwrap());
    }

    /// @notice Accrue additional rewards and distribute them to `user` proportionally to the `user`'s YT balance
    /// @dev This function should be called every time the `user`'s YT balance changes
    /// @dev This function must be called before YT balance or total supply changes
    function _accrueRewards(
        FeePcts feePcts,
        TokenReward[] memory rewards,
        address src,
        uint256 srcYtBalance,
        address dst,
        uint256 dstYtBalance
    ) internal {
        uint256 ytSupply = i_yt.totalSupply();
        bool settled = s_isSettled;

        for (uint256 i; i != rewards.length;) {
            RewardRecord storage record = s_rewardRecords[rewards[i].token];

            // Calculate fee
            if (settled) {
                uint256 feePct = feePcts.getPostSettlementFeePctBps();

                uint256 amount = rewards[i].amount;
                uint256 fee = FixedPointMathLib.mulDivUp(amount, feePct, BASIS_POINTS);
                uint256 curatorFee = (fee * feePcts.getSplitPctBps()) / BASIS_POINTS;

                (uint256 curatorReward, uint256 protocolReward) = (record.curatorReward, record.protocolReward);
                // Subtract the fee from the reward amount and update fees
                rewards[i].amount = amount - fee;
                record.curatorReward = (curatorReward + curatorFee).toUint128();
                record.protocolReward = (protocolReward + fee - curatorFee).toUint128();
            }

            (RewardIndex newIndex,) = RewardMathLib.updateIndex(record.globalIndex, ytSupply, rewards[i].amount);
            record.globalIndex = newIndex;
            if (src != address(0)) RewardMathLib.accrueUserReward(record.userRewards, newIndex, src, srcYtBalance);
            if (dst != address(0)) RewardMathLib.accrueUserReward(record.userRewards, newIndex, dst, dstYtBalance);

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Mint PT and YT to `to`.
    function _mint(address to, uint256 amount) internal override {
        super._mint(to, amount);
        i_yt.mint(to, amount);
    }

    /// @dev Update the global index for yield (accumulator). Must be called before minting or redeeming.
    function _updateIndex(Snapshot memory snapshot, uint256 performanceFeePct) internal view returns (uint256 fee) {
        (, fee) = YieldMathLib.updateIndex({
            self: snapshot,
            scaleFn: i_resolver.scale,
            ptSupply: totalSupply(),
            ytSupply: i_yt.totalSupply(),
            feePctBps: performanceFeePct
        });
    }

    function _previewSupply(Snapshot memory snapshot, FeePcts feePcts, uint256 shares)
        internal
        view
        returns (uint256 principal, uint256 fee)
    {
        uint256 performanceFee = _updateIndex(snapshot, feePcts.getPerformanceFeePctBps());

        // Calculate the principal amount of PT and YT to mint
        uint256 issuanceFee = _feeOnTotal(shares, feePcts.getIssuanceFeePctBps());
        principal = YieldMathLib.convertToPrincipal(shares - issuanceFee, snapshot.maxscale, false);
        fee = performanceFee + issuanceFee;
    }

    function _previewIssue(Snapshot memory snapshot, FeePcts feePcts, uint256 principal)
        internal
        view
        returns (uint256 shares, uint256 fee)
    {
        uint256 performanceFee = _updateIndex(snapshot, feePcts.getPerformanceFeePctBps());

        shares = YieldMathLib.convertToUnderlying(principal, snapshot.maxscale, true);
        uint256 issuanceFee = _feeOnRaw(shares, feePcts.getIssuanceFeePctBps());
        shares += issuanceFee;
        fee = performanceFee + issuanceFee;
    }

    function _previewUnite(Snapshot memory snapshot, FeePcts feePcts, uint256 shares)
        internal
        view
        returns (uint256 principal, uint256 fee)
    {
        uint256 perfFeePct = s_isSettled ? feePcts.getPostSettlementFeePctBps() : feePcts.getPerformanceFeePctBps();

        // Fetch share price (scale) and update the global index and calculate the performance fee
        uint256 performanceFee = _updateIndex(snapshot, perfFeePct);

        uint256 redemptionFee = _feeOnRaw(shares, feePcts.getRedemptionFeePctBps());
        // Calculate the principal amount corresponding to the shares. (Round up against the user)
        principal = YieldMathLib.convertToPrincipal(shares + redemptionFee, snapshot.maxscale, true);
        fee = performanceFee + redemptionFee;
    }

    function _previewCombine(Snapshot memory snapshot, FeePcts feePcts, uint256 principal)
        internal
        view
        returns (uint256 shares, uint256 fee)
    {
        uint256 perfFeePct = s_isSettled ? feePcts.getPostSettlementFeePctBps() : feePcts.getPerformanceFeePctBps();

        uint256 performanceFee = _updateIndex(snapshot, perfFeePct);

        shares = YieldMathLib.convertToUnderlying(principal, snapshot.maxscale, false);
        uint256 redemptionFee = _feeOnTotal(shares, feePcts.getRedemptionFeePctBps());
        shares -= redemptionFee;
        fee = performanceFee + redemptionFee;
    }

    function _previewWithdraw(Snapshot memory snapshot, FeePcts feePcts, uint256 shares)
        internal
        view
        returns (uint256 principal, uint256 fee)
    {
        uint256 perfFeePct = s_isSettled ? feePcts.getPostSettlementFeePctBps() : feePcts.getPerformanceFeePctBps();

        uint256 performanceFee = _updateIndex(snapshot, perfFeePct);

        uint256 redemptionFee = _feeOnRaw(shares, feePcts.getRedemptionFeePctBps());
        // Calculate the principal amount corresponding to the shares. (Round up against the user)
        principal = YieldMathLib.convertToPrincipal(shares + redemptionFee, snapshot.maxscale, true);
        fee = performanceFee + redemptionFee;
    }

    function _previewRedeem(Snapshot memory snapshot, FeePcts feePcts, uint256 principal)
        internal
        view
        returns (uint256 shares, uint256 fee)
    {
        uint256 perfFeePct = s_isSettled ? feePcts.getPostSettlementFeePctBps() : feePcts.getPerformanceFeePctBps();

        uint256 performanceFee = _updateIndex(snapshot, perfFeePct);

        shares = YieldMathLib.convertToUnderlying(principal, snapshot.maxscale, false);
        uint256 redemptionFee = _feeOnTotal(shares, feePcts.getRedemptionFeePctBps());
        shares -= redemptionFee;
        fee = performanceFee + redemptionFee;
    }

    function _previewCollect(Snapshot memory snapshot, FeePcts feePcts, address owner, uint256 ownerYtBalance)
        internal
        view
        returns (uint256 shares, uint256 fee)
    {
        uint256 perfFeePct = s_isSettled ? feePcts.getPostSettlementFeePctBps() : feePcts.getPerformanceFeePctBps();

        fee = _updateIndex(snapshot, perfFeePct);
        shares = s_userYields[owner].accrued
            + YieldMathLib.computeAccrueUserYield(s_userYields, snapshot.globalIndex, owner, ownerYtBalance);
    }

    /// @dev Calculates the fees that should be added to an amount `shares` that does not already include fees.
    function _feeOnRaw(uint256 shares, uint256 feeBasisPoints) private pure returns (uint256) {
        return FixedPointMathLib.mulDivUp(shares, feeBasisPoints, BASIS_POINTS);
    }

    /// @dev Calculates the fee part of an amount `shares` that already includes fees.
    function _feeOnTotal(uint256 shares, uint256 feeBasisPoints) private pure returns (uint256) {
        return FixedPointMathLib.mulDivUp(shares, feeBasisPoints, feeBasisPoints + BASIS_POINTS);
    }

    /// @notice Delegate call to the RewardProxy to claim rewards accrued by the underlying tokens.
    function _delegateCallRewardProxy(address[] memory m) internal returns (TokenReward[] memory rewards) {
        address rewardProxy = ModuleAccessor.getOrDefault(m, REWARD_PROXY_MODULE_INDEX);
        if (rewardProxy == address(0)) return rewards;

        uint256 balanceBefore = SafeTransferLib.balanceOf(address(i_target), address(this));

        rewards = LibRewardProxy.delegateCallCollectReward(rewardProxy);

        // Although reward proxy is considered trusted, check the underlying token balance does not change.
        if (SafeTransferLib.balanceOf(address(i_target), address(this)) != balanceBefore) {
            Errors.PrincipalToken_UnderlyingTokenBalanceChanged.selector.revertWith();
        }
    }

    function _verify(address[] memory m, uint256 shares, uint256 principal, address receiver) internal view {
        VerifierModule verifier = VerifierModule(ModuleAccessor.getOrDefault(m, VERIFIER_MODULE_INDEX));
        if (address(verifier) == address(0)) return;

        VerificationStatus status = verifier.verify(msg.sig, msg.sender, shares, principal, receiver);
        if (status != VerificationStatus.Success) {
            Errors.PrincipalToken_VerificationFailed.selector.revertWith(uint256(status));
        }
    }

    /// @dev If the principalToken is expired and not settled, it will be settled at the end of the function call.
    modifier settleIfExpired() {
        _;
        if (_isExpired() && !s_isSettled) s_isSettled = true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                            View                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Get `owner`' has approved `collector` to collect accrued interest and rewards through `collect` and `collectRewards` functions
    /// @dev Returns true if `collector` is approved by `owner`
    function isApprovedCollector(address owner, address collector) public view returns (bool) {
        return isApproved(owner, collector);
    }

    function previewSupply(uint256 shares) external view nonReadReentrant returns (uint256 principal) {
        if (_isIssuanceDisabled()) return 0;
        (principal,) =
            _previewSupply(s_snapshot, FeeModule(s_modules.read().unsafeGet(FEE_MODULE_INDEX)).getFeePcts(), shares);
    }

    function previewIssue(uint256 principal) external view nonReadReentrant returns (uint256 shares) {
        if (_isIssuanceDisabled()) return 0;
        (shares,) =
            _previewIssue(s_snapshot, FeeModule(s_modules.read().unsafeGet(FEE_MODULE_INDEX)).getFeePcts(), principal);
    }

    function previewUnite(uint256 shares) external view nonReadReentrant returns (uint256 principal) {
        (principal,) =
            _previewUnite(s_snapshot, FeeModule(s_modules.read().unsafeGet(FEE_MODULE_INDEX)).getFeePcts(), shares);
    }

    function previewCombine(uint256 principal) external view nonReadReentrant returns (uint256 shares) {
        (shares,) =
            _previewCombine(s_snapshot, FeeModule(s_modules.read().unsafeGet(FEE_MODULE_INDEX)).getFeePcts(), principal);
    }

    function previewCollect(address owner) external view nonReadReentrant returns (uint256 shares) {
        (shares,) = _previewCollect(
            s_snapshot,
            FeeModule(s_modules.read().unsafeGet(FEE_MODULE_INDEX)).getFeePcts(),
            owner,
            i_yt.balanceOf(owner)
        );
    }

    function previewWithdraw(uint256 shares) external view nonReadReentrant returns (uint256 principal) {
        if (!_isExpired()) return 0;
        (principal,) =
            _previewWithdraw(s_snapshot, FeeModule(s_modules.read().unsafeGet(FEE_MODULE_INDEX)).getFeePcts(), shares);
    }

    function previewRedeem(uint256 principal) external view nonReadReentrant returns (uint256 shares) {
        if (!_isExpired()) return 0;
        (shares,) =
            _previewRedeem(s_snapshot, FeeModule(s_modules.read().unsafeGet(FEE_MODULE_INDEX)).getFeePcts(), principal);
    }

    function convertToUnderlying(uint256 principal) public view returns (uint256) {
        uint256 maxscale = FixedPointMathLib.max(i_resolver.scale(), s_snapshot.maxscale);
        return YieldMathLib.convertToUnderlying(principal, maxscale, false);
    }

    function convertToPrincipal(uint256 shares) public view returns (uint256) {
        uint256 maxscale = FixedPointMathLib.max(i_resolver.scale(), s_snapshot.maxscale);
        return YieldMathLib.convertToPrincipal(shares, maxscale, false);
    }

    /// @notice Get the maximum shares that can be deposited for `receiver`
    /// @dev If the verifier module is not set, no cap is applied.
    /// MUST return a limited value if receiver is subject to some deposit limit.
    /// MUST return 2 ** 256 - 1 if there is no limit on the maximum amount that may be deposited.
    /// MUST return 0 if it's paused or expired.
    /// MUST NOT revert.
    function maxSupply(address receiver) public view returns (uint256) {
        if (_isIssuanceDisabled()) return 0;
        address verifier = ModuleAccessor.getOrDefault(ModuleAccessor.read(s_modules), VERIFIER_MODULE_INDEX);
        if (verifier == address(0)) return type(uint256).max;
        return VerifierModule(verifier).maxSupply(receiver);
    }

    /// @notice Get the maximum amount of PT that can be issued to `receiver`
    /// @dev If the verifier module is not set, no cap is applied
    function maxIssue(address receiver) external view returns (uint256) {
        uint256 maxShares = maxSupply(receiver);
        if (maxShares == type(uint256).max) return type(uint256).max;
        return convertToPrincipal(maxShares); // Rounded down
    }

    function maxRedeem(address owner) external view returns (uint256) {
        if (!_isExpired()) return 0;
        return balanceOf(owner);
    }

    function maxWithdraw(address owner) external view returns (uint256) {
        if (!_isExpired()) return 0;
        return convertToUnderlying(balanceOf(owner));
    }

    function getUserYield(address owner) external view returns (Yield memory) {
        return s_userYields[owner];
    }

    /// @notice Get the accrued rewards for `owner`.
    /// @dev Note The result doesn't include the pending rewards that haven't been accrued yet since the last `owner`'s interaction
    function getUserReward(address reward, address owner) external view returns (Reward memory) {
        return s_rewardRecords[reward].userRewards[owner];
    }

    function getFeeRewards(address reward) external view returns (uint256, uint256) {
        return (s_rewardRecords[reward].curatorReward, s_rewardRecords[reward].protocolReward);
    }

    function getFees() external view returns (uint256, uint256) {
        return (s_curatorFee, s_protocolFee);
    }

    function getRewardGlobalIndex(address reward) external view returns (RewardIndex) {
        return s_rewardRecords[reward].globalIndex;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         Permissioned                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Accounts authorized by Curator `AccessManager.owner()` can collect fees and rewards.
    /// @dev Rewards to be collected are `RewardProxyModule.rewardTokens()`, and additional tokens `additionalTokens` are also collected.
    /// @param additionalTokens Additional reward tokens to be collected in addition to `RewardProxyModule.rewardTokens()`. It can be empty. Duplicated element is allowed.
    function collectCuratorFees(address[] calldata additionalTokens, address feeReceiver)
        external
        restricted
        returns (uint256 shares, TokenReward[] memory rewards)
    {
        shares = s_curatorFee;
        s_curatorFee = 0;

        rewards = _collectFeeRewards({additionalTokens: additionalTokens, feeReceiver: feeReceiver, isCurator: true});
        SafeTransferLib.safeTransfer(address(i_target), feeReceiver, shares);

        emit Events.CuratorFeesCollected(msg.sender, feeReceiver, shares, rewards);
    }

    /// @notice Accounts authorized by Napier's `AccessManager` can collect fees and rewards.
    /// @dev Rewards to be collected are `RewardProxyModule.rewardTokens()`, and additional tokens `additionalTokens` are also collected.
    /// @param additionalTokens Additional reward tokens to be collected in addition to `RewardProxyModule.rewardTokens()`. It can be empty. Duplicated element is allowed.
    function collectProtocolFees(address[] calldata additionalTokens)
        external
        restrictedBy(i_factory.i_accessManager())
        returns (uint256 shares, TokenReward[] memory rewards)
    {
        address treasury = i_factory.s_treasury();

        shares = s_protocolFee;
        s_protocolFee = 0;

        rewards = _collectFeeRewards({additionalTokens: additionalTokens, feeReceiver: treasury, isCurator: false});
        SafeTransferLib.safeTransfer(address(i_target), treasury, shares);

        emit Events.ProtocolFeesCollected(msg.sender, treasury, shares, rewards);
    }

    /// @dev `rewardTokens` and/or `additionalTokens` may include the underlying token address.
    /// @param additionalTokens Additional reward tokens to be collected in addition to `RewardProxyModule.rewardTokens()`
    function _collectFeeRewards(address[] calldata additionalTokens, address feeReceiver, bool isCurator)
        internal
        returns (TokenReward[] memory rewards)
    {
        address[] memory rewardTokens;

        address rewardProxy = ModuleAccessor.read(s_modules).getOrDefault(REWARD_PROXY_MODULE_INDEX);
        if (rewardProxy != address(0)) rewardTokens = IRewardProxy(rewardProxy).rewardTokens();

        uint256 k = rewardTokens.length;
        rewards = new TokenReward[](k + additionalTokens.length); // Reward tokens + additional tokens
        for (uint256 i; i != rewards.length;) {
            unchecked {
                address token = i < k
                    ? DynamicArrayLib.toUint256Array(rewardTokens).getAddress(i) // Unsafe access without bounds check
                    : additionalTokens[i - k];
                RewardRecord storage record = s_rewardRecords[token];

                rewards[i].token = token;
                if (isCurator) {
                    rewards[i].amount = record.curatorReward;
                    record.curatorReward = 0;
                } else {
                    rewards[i].amount = record.protocolReward;
                    record.protocolReward = 0;
                }

                // Note: When we update pending reward fees, the underlying token is not allowed as a reward token.
                SafeTransferLib.safeTransfer(token, feeReceiver, rewards[i].amount);

                ++i;
            }
        }
    }

    function setModules(address modules) external {
        if (msg.sender != address(i_factory)) Errors.PrincipalToken_NotFactory.selector.revertWith();
        s_modules = modules;
    }

    /// @notice Accounts authorized by `AccessManager.owner()` can pause the principalToken.
    /// @notice If the owner is renounced, the principalToken is not pausable anymore even if the caller is authorized.
    function pause() external restricted {
        if (i_accessManager().owner() == address(0)) revert Errors.PrincipalToken_Unstoppable();
        _pause();
    }

    /// @notice Accounts authorized by `AccessManager.owner()` can unpause the principalToken.
    /// @notice Even if the owner is renounced, the principalToken is still unpausable.
    function unpause() external restricted {
        _unpause();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          Metadata                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function underlying() external view returns (address) {
        return address(i_target);
    }

    function maturity() external view returns (uint256) {
        return i_expiry;
    }

    function name() public view override returns (string memory _name) {
        _name = LibString.get(s_name);
    }

    function symbol() public view override returns (string memory _symbol) {
        _symbol = LibString.get(s_symbol);
    }

    function decimals() public view override returns (uint8) {
        return i_asset.decimals();
    }

    /// @dev Settlement is a one-time event that happens at the end of the first interaction after the expiry.
    function isSettled() external view nonReadReentrant returns (bool) {
        return s_isSettled;
    }

    function getSnapshot() external view returns (Snapshot memory) {
        return s_snapshot;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           Utils                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _constantNameHash() internal view override returns (bytes32) {
        return i_nameHash;
    }

    modifier ownerOrApprovedCollector(address owner) {
        _checkOwnerOrApprovedCollector(owner);
        _;
    }

    function _checkOwnerOrApprovedCollector(address owner) internal view {
        if (msg.sender != owner && !isApprovedCollector(owner, msg.sender)) {
            Errors.PrincipalToken_NotApprovedCollector.selector.revertWith();
        }
    }

    function _isExpired() internal view returns (bool) {
        return LibExpiry.isExpired(i_expiry);
    }

    /// @notice Issuance is disabled when the principalToken is expired or paused
    function _isIssuanceDisabled() internal view returns (bool) {
        return _isExpired() || paused();
    }

    modifier notExpired() {
        if (_isExpired()) Errors.Expired.selector.revertWith();
        _;
    }

    modifier expired() {
        if (!_isExpired()) Errors.NotExpired.selector.revertWith();
        _;
    }

    function i_accessManager() public view override returns (AccessManager) {
        return _i_accessManager;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

import "../Types.sol";
import {IHook} from "../interfaces/IHook.sol";
import {Factory} from "../Factory.sol";
import {PrincipalToken} from "../tokens/PrincipalToken.sol";
import {VaultConnector} from "../modules/connectors/VaultConnector.sol";
import {VaultConnectorRegistry} from "../modules/connectors/VaultConnectorRegistry.sol";
import {AggregationRouter, RouterPayload} from "../modules/aggregator/AggregationRouter.sol";
// Libraries
import {LibTwoCryptoNG} from "../utils/LibTwoCryptoNG.sol";
import {ZapHookEncoder} from "../utils/ZapHookEncoder.sol";
import {ContractValidation} from "../utils/ContractValidation.sol";
import {LibExpiry} from "../utils/LibExpiry.sol";
import {Casting} from "../utils/Casting.sol";
import {CustomRevert} from "../utils/CustomRevert.sol";
import {TARGET_INDEX, PT_INDEX} from "../Constants.sol";
import {Events} from "../Events.sol";
import {Errors} from "../Errors.sol";
// Math
import {ZapMathLib} from "../utils/ZapMathLib.sol";
// Inherits
import {HookValidation} from "../utils/HookValidation.sol";
import {ZapBase} from "./ZapBase.sol";

contract TwoCryptoZap is ZapBase, HookValidation, IHook {
    using Casting for *;
    using LibTwoCryptoNG for TwoCrypto;
    using CustomRevert for bytes4;

    address internal immutable i_twoCryptoDeployer;
    Factory public immutable i_factory;
    VaultConnectorRegistry public immutable i_vaultConnectorRegistry;
    AggregationRouter public immutable i_aggregationRouter;

    receive() external payable {}

    constructor(
        Factory factory,
        VaultConnectorRegistry vaultConnectorRegistry,
        address twoCryptoDeployer,
        AggregationRouter aggregationRouter
    ) {
        i_factory = factory;
        i_vaultConnectorRegistry = vaultConnectorRegistry;
        i_twoCryptoDeployer = twoCryptoDeployer;
        i_aggregationRouter = aggregationRouter;
    }

    struct AddLiquidityOneTokenParams {
        TwoCrypto twoCrypto;
        Token tokenIn;
        uint256 amountIn;
        uint256 minLiquidity;
        uint256 minYt;
        address receiver;
        uint256 deadline;
    }

    struct AddLiquidityParams {
        TwoCrypto twoCrypto;
        uint256 shares;
        uint256 principal;
        uint256 minLiquidity;
        address receiver;
        uint256 deadline;
    }

    struct RemoveLiquidityOneTokenParams {
        TwoCrypto twoCrypto;
        uint256 liquidity;
        Token tokenOut;
        uint256 amountOutMin;
        address receiver;
        uint256 deadline;
    }

    struct RemoveLiquidityParams {
        TwoCrypto twoCrypto;
        uint256 liquidity;
        uint256 minPrincipal;
        uint256 minShares;
        address receiver;
        uint256 deadline;
    }

    /// @notice Data structure for `swapTokenFor{Pt, Yt}` functions
    struct SwapTokenParams {
        TwoCrypto twoCrypto;
        Token tokenIn;
        uint256 amountIn;
        uint256 minPrincipal;
        address receiver;
        uint256 deadline;
    }

    /// @notice Data structure for `swapPtForToken` functions
    struct SwapPtParams {
        TwoCrypto twoCrypto;
        uint256 principal;
        Token tokenOut;
        uint256 amountOutMin;
        address receiver;
        uint256 deadline;
    }

    /// @notice Data structure for `swapYtForToken` functions
    /// @dev Actually this struct is same as SwapPtParams
    struct SwapYtParams {
        TwoCrypto twoCrypto;
        uint256 principal;
        Token tokenOut;
        uint256 amountOutMin;
        address receiver;
        uint256 deadline;
    }

    struct SwapTokenInput {
        Token tokenMintShares; // token to mint shares via connector
        RouterPayload swapData; // aggregator data
    }

    struct SwapTokenOutput {
        Token tokenRedeemShares; // token to redeem shares via connector
        RouterPayload swapData; // aggregator data
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    Liquidity Providing                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    struct CreateAndAddLiquidityParams {
        // Params for new deployment
        Factory.Suite suite;
        Factory.ModuleParam[] modules;
        uint256 expiry;
        address curator;
        // Params for initial liquidity
        uint256 shares;
        uint256 minYt;
        uint256 minLiquidity;
        uint256 deadline;
    }

    /// @notice Create new instance and deposit initial liquidity to the pool.
    /// @notice Similar to `addLiquidityOneToken` function, this function minimizes price impact on deposit
    function createAndAddLiquidity(CreateAndAddLiquidityParams calldata params)
        external
        nonReentrant
        checkDeadline(params.deadline)
        returns (address pt, address yt, address twoCrypto, uint256 liquidity, uint256 principal)
    {
        // Factory is AMM-agnostic. Make sure we're trying to create twoCrypto pool.
        if (params.suite.poolDeployerImpl != i_twoCryptoDeployer) Errors.Zap_BadPoolDeployer.selector.revertWith();

        (pt, yt, twoCrypto) = i_factory.deploy(params.suite, params.modules, params.expiry, params.curator);

        address underlying = TwoCrypto.wrap(twoCrypto).coins(TARGET_INDEX);

        SafeTransferLib.safeTransferFrom(underlying, msg.sender, address(this), params.shares);

        (liquidity, principal) = _addLiquidityOneUnderlying(
            AddLiquidityOneUnderlyingParams({
                twoCrypto: TwoCrypto.wrap(twoCrypto),
                principalToken: PrincipalToken(pt),
                underlying: underlying,
                shares: params.shares,
                minYt: params.minYt,
                minLiquidity: params.minLiquidity,
                receiver: msg.sender
            })
        );

        Events.emitZapAddLiquidityOneToken({
            by: msg.sender,
            receiver: msg.sender,
            twoCrypto: TwoCrypto.wrap(twoCrypto),
            liquidity: liquidity,
            ytOut: principal,
            tokenIn: Token.wrap(underlying),
            amountIn: params.shares
        });
    }

    /// @notice Issue some PT with some portion of `shares` and add the issued PT and remaining `shares` into `pool` and send back the LP tokens and YT to `receiver`
    /// with zero price impact
    function addLiquidityOneToken(AddLiquidityOneTokenParams calldata params)
        external
        payable
        nonReentrant
        checkTwoCrypto(params.twoCrypto)
        checkDeadline(params.deadline)
        returns (uint256 liquidity, uint256 principal)
    {
        TwoCrypto twoCrypto = params.twoCrypto;
        PrincipalToken principalToken = PrincipalToken(twoCrypto.coins(PT_INDEX));
        address underlying = twoCrypto.coins(TARGET_INDEX);

        uint256 shares = _deposit(
            underlying, principalToken.i_asset().asAddr(), params.tokenIn, params.amountIn, address(this), msg.sender
        );

        (liquidity, principal) = _addLiquidityOneUnderlying(
            AddLiquidityOneUnderlyingParams({
                twoCrypto: twoCrypto,
                principalToken: principalToken,
                underlying: underlying,
                shares: shares,
                minYt: params.minYt,
                minLiquidity: params.minLiquidity,
                receiver: params.receiver
            })
        );

        Events.emitZapAddLiquidityOneToken({
            by: msg.sender,
            receiver: params.receiver,
            twoCrypto: twoCrypto,
            liquidity: liquidity,
            ytOut: principal,
            tokenIn: params.tokenIn,
            amountIn: params.amountIn
        });
    }

    function addLiquidityAnyOneToken(AddLiquidityOneTokenParams calldata params, SwapTokenInput calldata tokenInput)
        external
        payable
        nonReentrant
        checkTwoCrypto(params.twoCrypto)
        checkDeadline(params.deadline)
        returns (uint256 liquidity, uint256 principal)
    {
        TwoCrypto twoCrypto = params.twoCrypto;
        PrincipalToken principalToken = PrincipalToken(twoCrypto.coins(PT_INDEX));
        address underlying = twoCrypto.coins(TARGET_INDEX);

        _pullToken(params.tokenIn, params.amountIn);
        approveIfNeeded(params.tokenIn, address(i_aggregationRouter));

        {
            // Step 1: Swap input token to tokenMintShares using the aggregator
            uint256 tokenMintSharesAmount = i_aggregationRouter.swap{value: msg.value}({
                tokenIn: params.tokenIn,
                tokenOut: tokenInput.tokenMintShares,
                amountIn: params.amountIn,
                data: tokenInput.swapData,
                receiver: address(this)
            });

            // Step 2: Deposit tokenMintShares and get shares
            uint256 shares = _deposit(
                underlying,
                principalToken.i_asset().asAddr(),
                tokenInput.tokenMintShares,
                tokenMintSharesAmount,
                address(this),
                address(this)
            );

            (liquidity, principal) = _addLiquidityOneUnderlying(
                AddLiquidityOneUnderlyingParams({
                    twoCrypto: twoCrypto,
                    principalToken: principalToken,
                    underlying: underlying,
                    shares: shares,
                    minYt: params.minYt,
                    minLiquidity: params.minLiquidity,
                    receiver: params.receiver
                })
            );
        }

        Events.emitZapAddLiquidityOneToken({
            by: msg.sender,
            receiver: params.receiver,
            twoCrypto: twoCrypto,
            liquidity: liquidity,
            ytOut: principal,
            tokenIn: params.tokenIn,
            amountIn: params.amountIn
        });

        _refund(params.tokenIn);
    }

    /// @dev Helper struct to avoid stack too deep errors
    struct AddLiquidityOneUnderlyingParams {
        TwoCrypto twoCrypto;
        PrincipalToken principalToken;
        address underlying;
        uint256 shares;
        uint256 minYt;
        uint256 minLiquidity;
        address receiver;
    }

    /// @dev Internal helper function to handle the common liquidity adding logic
    function _addLiquidityOneUnderlying(AddLiquidityOneUnderlyingParams memory params)
        internal
        returns (uint256 liquidity, uint256 principal)
    {
        uint256 sharesToPool =
            ZapMathLib.computeSharesToTwoCrypto(params.twoCrypto, params.principalToken, params.shares);

        // Split the `shares` into PT and shares
        approveIfNeeded(params.underlying, address(params.principalToken));
        principal = params.principalToken.supply(params.shares - sharesToPool, address(this));

        if (principal < params.minYt) Errors.Zap_InsufficientYieldTokenOutput.selector.revertWith();

        approveIfNeeded(address(params.principalToken), params.twoCrypto.unwrap());
        approveIfNeeded(params.underlying, params.twoCrypto.unwrap());

        // Add the issued PT and remaining `shares` into `twoCrypto`
        liquidity = params.twoCrypto.add_liquidity({
            amount0: sharesToPool,
            amount1: principal,
            minLiquidity: params.minLiquidity,
            receiver: params.receiver
        });
        SafeTransferLib.safeTransfer(params.principalToken.i_yt().asAddr(), params.receiver, principal);
    }

    /// @notice Forwards the call to the TwoCrypto contract to add liquidity
    function addLiquidity(AddLiquidityParams calldata params)
        external
        nonReentrant
        checkTwoCrypto(params.twoCrypto)
        checkDeadline(params.deadline)
        returns (uint256 liquidity)
    {
        TwoCrypto twoCrypto = params.twoCrypto;
        address pt = twoCrypto.coins(PT_INDEX);
        address underlying = twoCrypto.coins(TARGET_INDEX);

        SafeTransferLib.safeTransferFrom(pt, msg.sender, address(this), params.principal);
        SafeTransferLib.safeTransferFrom(underlying, msg.sender, address(this), params.shares);

        approveIfNeeded(pt, twoCrypto.unwrap());
        approveIfNeeded(underlying, twoCrypto.unwrap());
        liquidity = twoCrypto.add_liquidity({
            amount0: params.shares,
            amount1: params.principal,
            minLiquidity: params.minLiquidity,
            receiver: params.receiver
        });

        Events.emitZapAddLiquidity({
            by: msg.sender,
            receiver: params.receiver,
            twoCrypto: twoCrypto,
            liquidity: liquidity,
            shares: params.shares,
            principal: params.principal
        });
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  Liquidity Withdrawals                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Burn `liquidity` of `twoCrypto` LP token and convert the PT and underlying tokens to a single token `tokenOut` and send it to `receiver`
    /// @notice `tokenOut` must be supported by the connector or its underlying token.
    /// @notice When the PT is not expired, the withdrawn PT is swapped to shares on secondary market.
    /// @notice When the PT is expired, the withdrawn PT is redeemed for underlying tokens.
    /// @dev Flow: LP -> [twoCrypto] -> PT and underlying tokens -> [connector] -> tokenOut
    function removeLiquidityOneToken(RemoveLiquidityOneTokenParams calldata params)
        external
        nonReentrant
        checkTwoCrypto(params.twoCrypto)
        checkDeadline(params.deadline)
        returns (uint256 amountOut)
    {
        amountOut = _removeLiquidityOneToken(params.twoCrypto, params.liquidity, params.tokenOut, params.receiver);

        if (amountOut < params.amountOutMin) Errors.Zap_InsufficientTokenOutput.selector.revertWith();

        Events.emitZapRemoveLiquidityOneToken({
            by: msg.sender,
            receiver: params.receiver,
            twoCrypto: params.twoCrypto,
            liquidity: params.liquidity,
            tokenOut: params.tokenOut,
            amountOut: amountOut
        });
    }

    /// @notice Same as `removeLiquidityOneToken` but with aggregator support for the `tokenOut`
    /// @notice `tokenOut` can be any token supported by `AggregationRouter`.
    function removeLiquidityAnyOneToken(
        RemoveLiquidityOneTokenParams calldata params,
        SwapTokenOutput calldata tokenOutput
    )
        external
        nonReentrant
        checkTwoCrypto(params.twoCrypto)
        checkDeadline(params.deadline)
        returns (uint256 amountOut)
    {
        uint256 tokenRedeemSharesAmount =
            _removeLiquidityOneToken(params.twoCrypto, params.liquidity, tokenOutput.tokenRedeemShares, address(this));

        approveIfNeeded(tokenOutput.tokenRedeemShares, address(i_aggregationRouter));
        amountOut = i_aggregationRouter.swap{
            value: FixedPointMathLib.ternary(tokenOutput.tokenRedeemShares.isNative(), address(this).balance, 0)
        }({
            tokenIn: tokenOutput.tokenRedeemShares,
            tokenOut: params.tokenOut,
            amountIn: tokenRedeemSharesAmount,
            data: tokenOutput.swapData,
            receiver: params.receiver
        });

        if (amountOut < params.amountOutMin) Errors.Zap_InsufficientTokenOutput.selector.revertWith();

        Events.emitZapRemoveLiquidityOneToken({
            by: msg.sender,
            receiver: params.receiver,
            twoCrypto: params.twoCrypto,
            liquidity: params.liquidity,
            tokenOut: params.tokenOut,
            amountOut: amountOut
        });

        // `tokenRedeemShares` may be left in the contract.
        _refund(tokenOutput.tokenRedeemShares);
    }

    function _removeLiquidityOneToken(TwoCrypto twoCrypto, uint256 liquidity, Token tokenOut, address receiver)
        internal
        returns (uint256 amount)
    {
        PrincipalToken principalToken = PrincipalToken(twoCrypto.coins(PT_INDEX));

        SafeTransferLib.safeTransferFrom(twoCrypto.unwrap(), msg.sender, address(this), liquidity);

        uint256 sharesWithdrawn;
        if (LibExpiry.isNotExpired(principalToken)) {
            sharesWithdrawn = twoCrypto.remove_liquidity_one_coin(liquidity, TARGET_INDEX, 0);
        } else {
            (uint256 shares, uint256 principal) = twoCrypto.remove_liquidity(liquidity, 0, 0);
            uint256 sharesFromPT = principalToken.redeem(principal, address(this), address(this));
            sharesWithdrawn = shares + sharesFromPT;
        }

        amount = _redeem({
            underlying: twoCrypto.coins(TARGET_INDEX),
            asset: principalToken.i_asset().asAddr(),
            tokenOut: tokenOut,
            shares: sharesWithdrawn,
            receiver: receiver
        });
    }

    /// @notice Forward the call to the TwoCrypto contract to remove liquidity
    function removeLiquidity(RemoveLiquidityParams calldata params)
        external
        nonReentrant
        checkTwoCrypto(params.twoCrypto)
        checkDeadline(params.deadline)
        returns (uint256 shares, uint256 principal)
    {
        TwoCrypto twoCrypto = params.twoCrypto;

        SafeTransferLib.safeTransferFrom(twoCrypto.unwrap(), msg.sender, address(this), params.liquidity);

        (shares, principal) = twoCrypto.remove_liquidity({
            liquidity: params.liquidity,
            minAmount0: params.minShares,
            minAmount1: params.minPrincipal,
            receiver: params.receiver
        });

        Events.emitZapRemoveLiquidity({
            by: msg.sender,
            receiver: params.receiver,
            twoCrypto: twoCrypto,
            liquidity: params.liquidity,
            shares: shares,
            principal: principal
        });
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    Swap Principal Token                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Swap `amountIn` of `token` to PT and send the PT to `receiver`
    /// @notice `token` must be supported by connector. Otherwise, the swap will fail.
    /// @notice When `token` is native ETH, wrap the asset to WETH, and when `token` is not native ETH, the caller must approve this contract to spend `amountIn` of `token`.
    /// @dev Flow: token -> [connector] -> shares -> [twoCrypto] -> PT
    /// @dev e.g. wstETH-PT (1) native ETH -> [connector]-> wstETH -> PT (2) stETH -> [connector] -> wsETH -> PT (3) wstETH -> PT (4) WETH -> [connector] -> wstETH -> PT
    ///  ┌────┐       ┌─────────┐          ┌──────┐┌───┐            ┌─────────┐
    ///  │User│       │Connector│          │wstETH││Zap│            │TwoCrypto│
    ///  └─┬──┘       └───┬─────┘          └──┬───┘└─┬─┘            └────┬────┘
    ///    │              │                 │      │                   │
    ///    │send nativeETH│                 │      │                   │
    ///    │─────────────>│                 │      │                   │
    ///    │              │                 │      │                   │
    ///    │              │convert to wstETH│      │                   │
    ///    │              │────────────────>│      │                   │
    ///    │              │                 │      │                   │
    ///    │              │   send wsETH    │      │                   │
    ///    │              │<────────────────│      │                   │
    ///    │              │                 │      │                   │
    ///    │              │      send wstETH│      │                   │
    ///    │              │───────────────────────>│                   │
    ///    │              │                 │      │                   │
    ///    │              │                 │      │swap wstETH on pool│
    ///    │              │                 │      │──────────────────>│
    ///    │              │                 │      │                   │
    ///    │              │           send PT      │                   │
    ///    │<──────────────────────────────────────────────────────────│
    ///  ┌─┴──┐       ┌───┴─────┐          ┌──┴───┐┌─┴─┐            ┌────┴────┐
    ///  │User│       │Connector│          │wstETH││Zap│            │TwoCrypto│
    ///  └────┘       └─────────┘          └──────┘└───┘            └─────────┘
    function swapTokenForPt(SwapTokenParams calldata params)
        external
        payable
        nonReentrant
        checkTwoCrypto(params.twoCrypto)
        checkDeadline(params.deadline)
        returns (uint256 ptOut)
    {
        // At this point, `twoCrypto` is verified as an instance deployed from our factory
        TwoCrypto twoCrypto = params.twoCrypto;
        PrincipalToken principalToken = PrincipalToken(twoCrypto.coins(PT_INDEX));
        address underlying = twoCrypto.coins(TARGET_INDEX);

        // Deposit tokens and get shares
        uint256 shares = _deposit(
            underlying,
            principalToken.i_asset().asAddr(),
            params.tokenIn,
            params.amountIn,
            twoCrypto.unwrap(),
            msg.sender
        );

        // Swap shares for PT using TwoCrypto
        ptOut =
            twoCrypto.exchange_received({i: TARGET_INDEX, j: PT_INDEX, dx: shares, minDy: 0, receiver: params.receiver});

        if (ptOut < params.minPrincipal) Errors.Zap_InsufficientPrincipalTokenOutput.selector.revertWith();

        Events.emitZapSwap({
            by: msg.sender,
            receiver: params.receiver,
            twoCrypto: twoCrypto,
            tokenIn: params.tokenIn,
            amountIn: params.amountIn,
            tokenOut: Token.wrap(address(principalToken)),
            amountOut: ptOut
        });
    }

    /// @notice Swap any token to another token through an aggregator and then swap the token to PT
    /// @notice `tokenMintShares` must be supported by the connector. Otherwise, the swap will fail.
    /// @notice When `token` is not native ETH, the caller must approve this contract to spend `amountIn` of `token`.
    /// @dev Flow: token -> [aggregator] -> tokenMintShares -> [connector] -> shares -> [twoCrypto] -> PT OR token -> [aggregator] -> shares(=tokenMintShares) -> [twoCrypto] -> PT
    /// @dev e.g. wstETH-PT (1) USDC -> [aggregator] -> WETH -> [connector]-> wstETH -> PT (2) USDC -> [aggregator] -> wstETH -> PT (3) USDC -> [aggregator] -> stETH -> [connector] -> wsETH -> PT
    function swapAnyTokenForPt(SwapTokenParams calldata params, SwapTokenInput calldata tokenInput)
        external
        payable
        nonReentrant
        checkTwoCrypto(params.twoCrypto)
        checkDeadline(params.deadline)
        returns (uint256 ptOut)
    {
        TwoCrypto twoCrypto = params.twoCrypto;
        PrincipalToken principalToken = PrincipalToken(twoCrypto.coins(PT_INDEX));
        address underlying = twoCrypto.coins(TARGET_INDEX);

        _pullToken(params.tokenIn, params.amountIn);

        approveIfNeeded(params.tokenIn, address(i_aggregationRouter));

        // Step 1: Swap input token to tokenMintShares using the aggregator
        uint256 tokenMintSharesAmount = i_aggregationRouter.swap{value: msg.value}({
            tokenIn: params.tokenIn,
            tokenOut: tokenInput.tokenMintShares,
            amountIn: params.amountIn,
            data: tokenInput.swapData,
            receiver: address(this)
        });

        // Step 2: Deposit tokenMintShares and get shares
        uint256 shares = _deposit(
            underlying,
            principalToken.i_asset().asAddr(),
            tokenInput.tokenMintShares,
            tokenMintSharesAmount,
            twoCrypto.unwrap(),
            address(this)
        );

        // Step 3: Swap shares for PT using TwoCrypto
        ptOut =
            twoCrypto.exchange_received({i: TARGET_INDEX, j: PT_INDEX, dx: shares, minDy: 0, receiver: params.receiver});

        if (ptOut < params.minPrincipal) Errors.Zap_InsufficientPrincipalTokenOutput.selector.revertWith();

        Events.emitZapSwap({
            by: msg.sender,
            receiver: params.receiver,
            twoCrypto: twoCrypto,
            tokenIn: params.tokenIn,
            amountIn: params.amountIn,
            tokenOut: Token.wrap(address(principalToken)),
            amountOut: ptOut
        });

        _refund(params.tokenIn);
    }

    /// @notice Swap `principal` of PT to at least `minAmount` of `token` and send the `token` to `receiver`
    /// @notice `token` must be supported by the connector. Otherwise, the swap will fail.
    /// @notice Caller must approve this contract to spend `principal` of PT.
    /// @dev Flow: PT -> [twoCrypto] -> shares -> [connector] -> token
    /// @dev e.g. wstETH-PT (1) PT -> wstETH (2) PT -> wstETH -> [connector] -> stETH
    /// @dev e.g. rETH-PT (1) PT -> rETH (2) PT -> rETH -> [connector] -> WETH (3) PT -> rETH -> [connector] -> native ETH
    function swapPtForToken(SwapPtParams calldata params)
        external
        nonReentrant
        checkTwoCrypto(params.twoCrypto)
        checkDeadline(params.deadline)
        returns (uint256 amountOut)
    {
        PrincipalToken principalToken = PrincipalToken(params.twoCrypto.coins(PT_INDEX));
        address underlying = params.twoCrypto.coins(TARGET_INDEX);

        SafeTransferLib.safeTransferFrom(
            address(principalToken), msg.sender, params.twoCrypto.unwrap(), params.principal
        );
        // Swap PT for shares in TwoCrypto
        uint256 shares =
            params.twoCrypto.exchange_received({i: PT_INDEX, j: TARGET_INDEX, dx: params.principal, minDy: 0});

        // If the token is the same as the underlying, we're done
        amountOut = _redeem(underlying, principalToken.i_asset().asAddr(), params.tokenOut, shares, params.receiver);

        if (amountOut < params.amountOutMin) Errors.Zap_InsufficientTokenOutput.selector.revertWith();

        Events.emitZapSwap({
            by: msg.sender,
            receiver: params.receiver,
            twoCrypto: params.twoCrypto,
            tokenIn: Token.wrap(address(principalToken)),
            amountIn: params.principal,
            tokenOut: params.tokenOut,
            amountOut: amountOut
        });
    }

    /// @notice Swap `principal` of PT to at least `minAmount` of `token` and send the `token` to `receiver`
    /// @notice `tokenRedeemShares` must be supported by the connector. Otherwise, the swap will fail.
    /// @notice Caller must approve this contract to spend `principal` of PT.
    /// @dev Flow: PT -> [twoCrypto] -> shares -> [aggregator] -> tokenRedeemShares -> [connector] -> token
    /// @dev e.g. wstETH-PT (1) PT -> wstETH -> [aggregator] -> USDC (2) PT -> wstETH -> [connector] -> stETH -> [aggregator] -> native ETH
    function swapPtForAnyToken(SwapPtParams calldata params, SwapTokenOutput calldata tokenOutput)
        external
        nonReentrant
        checkTwoCrypto(params.twoCrypto)
        checkDeadline(params.deadline)
        returns (uint256 amountOut)
    {
        PrincipalToken principalToken = PrincipalToken(params.twoCrypto.coins(PT_INDEX));
        address underlying = params.twoCrypto.coins(TARGET_INDEX);

        // Transfer PT from user to TwoCrypto pool
        SafeTransferLib.safeTransferFrom(
            address(principalToken), msg.sender, params.twoCrypto.unwrap(), params.principal
        );

        // Swap PT for shares in TwoCrypto
        uint256 shares =
            params.twoCrypto.exchange_received({i: PT_INDEX, j: TARGET_INDEX, dx: params.principal, minDy: 0});

        uint256 tokenRedeemSharesAmount =
            _redeem(underlying, principalToken.i_asset().asAddr(), tokenOutput.tokenRedeemShares, shares, address(this));

        approveIfNeeded(tokenOutput.tokenRedeemShares, address(i_aggregationRouter));

        // Determine the value to send with the swap call
        uint256 valueToSend =
            FixedPointMathLib.ternary(tokenOutput.tokenRedeemShares.isNative(), address(this).balance, 0);

        // Swap tokenRedeemShares for the desired token using the aggregator
        amountOut = i_aggregationRouter.swap{value: valueToSend}({
            tokenIn: tokenOutput.tokenRedeemShares,
            tokenOut: params.tokenOut,
            amountIn: tokenRedeemSharesAmount,
            data: tokenOutput.swapData,
            receiver: params.receiver
        });
        if (amountOut < params.amountOutMin) Errors.Zap_InsufficientTokenOutput.selector.revertWith();

        Events.emitZapSwap({
            by: msg.sender,
            receiver: params.receiver,
            twoCrypto: params.twoCrypto,
            tokenIn: Token.wrap(address(principalToken)),
            amountIn: params.principal,
            tokenOut: params.tokenOut,
            amountOut: amountOut
        });

        // Note that the remaining of `tokenRedeemShares` are left in the contract because the result of swap on the twoCrypto may be different from the estimation
        _refund(tokenOutput.tokenRedeemShares);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      Swap Yield Token                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Swap `amountIn` of `token` to YT and send the YT to `receiver`
    /// @notice `token` must be supported by the connector. Otherwise, the swap will fail.
    /// @notice When `token` is native ETH, wrap the asset to WETH, and when `token` is not native ETH, the caller must approve this contract to spend `amountIn` of `token`.
    /// @dev Flow: token -> [connector] -> shares -> [twoCrypto] -> YT
    /// @dev e.g. wstETH-YT (1) native ETH -> [connector]-> wstETH -> YT (2) stETH -> [connector] -> wsETH -> YT (3) wstETH -> YT (4) WETH -> [connector] -> wstETH -> YT
    ///  ┌────┐                     ┌───┐           ┌─────────┐             ┌───────┐┌─────────┐
    ///  │User│                     │Zap│           │Connector│             │PrincipalToken││TwoCrypto│
    ///  └─┬──┘                     └─┬─┘           └───┬─────┘             └───┬───┘└────┬────┘
    ///    │                          │                 │                     │         │
    ///    │        Send token        │                 │                     │         │
    ///    │─────────────────────────>│                 │                     │         │
    ///    │                          │                 │                     │         │
    ///    │                          │Convert to shares│                     │         │
    ///    │                          │────────────────>│                     │         │
    ///    │                          │                 │                     │         │
    ///    │                          │          Invoke flashmint op          │         │
    ///    │                          │──────────────────────────────────────>│         │
    ///    │                          │                 │                     │         │
    ///    │                          │Mint PT and YT with callback (onSupply)│         │
    ///    │                          │<──────────────────────────────────────│         │
    ///    │                          │                 │                     │         │
    ///    │                          │              swap the PT to shares    │         │
    ///    │                          │────────────────────────────────────────────────>│
    ///    │                          │                 │                     │         │
    ///    │                          │    Repay shares, otherwise revert     │         │
    ///    │                          │──────────────────────────────────────>│         │
    ///    │                          │                 │                     │         │
    ///    │    Send the minted YT    │                 │                     │         │
    ///    │<─────────────────────────│                 │                     │         │
    ///    │                          │                 │                     │         │
    ///    │Send the remaining sharses│                 │                     │         │
    ///    │<─────────────────────────│                 │                     │         │
    ///  ┌─┴──┐                     ┌─┴─┐           ┌───┴─────┐             ┌───┴───┐┌────┴────┐
    ///  │User│                     │Zap│           │Connector│             │PrincipalToken││TwoCrypto│
    ///  └────┘                     └───┘           └─────────┘             └───────┘└─────────┘
    function swapTokenForYt(SwapTokenParams calldata params, ApproxValue sharesFlashBorrow)
        external
        payable
        nonReentrant
        checkTwoCrypto(params.twoCrypto)
        checkDeadline(params.deadline)
        returns (uint256 principal)
    {
        TwoCrypto twoCrypto = params.twoCrypto;
        PrincipalToken principalToken = PrincipalToken(twoCrypto.coins(PT_INDEX));
        address underlying = twoCrypto.coins(TARGET_INDEX);

        uint256 sharesFromUser = _deposit(
            underlying, principalToken.i_asset().asAddr(), params.tokenIn, params.amountIn, address(this), msg.sender
        );

        setHookContext();
        bytes memory data = ZapHookEncoder.encodeSupply(twoCrypto, underlying, msg.sender, sharesFromUser);
        principal = principalToken.supply(sharesFlashBorrow.unwrap(), address(this), data);

        // Send the minted YT to `receiver`
        if (principal < params.minPrincipal) Errors.Zap_InsufficientYieldTokenOutput.selector.revertWith();
        address yt = principalToken.i_yt().asAddr();
        SafeTransferLib.safeTransfer(yt, params.receiver, principal);

        Events.emitZapSwap({
            by: msg.sender,
            receiver: params.receiver,
            twoCrypto: twoCrypto,
            tokenIn: params.tokenIn,
            amountIn: params.amountIn,
            tokenOut: Token.wrap(yt),
            amountOut: principal
        });
    }

    /// @notice Swap any token to another token through an aggregator and then swap the token to YT
    /// @notice `tokenMintShares` must be supported by the connector. Otherwise, the swap will fail.
    /// @notice When `token` is not native ETH, the caller must approve this contract to spend `amountIn` of `token`.
    /// @dev Flow: token -> [aggregator] -> tokenMintShares -> [connector] -> shares -> [twoCrypto] -> YT OR token -> [aggregator] -> shares(=tokenMintShares) -> [twoCrypto] -> YT
    /// @dev e.g. wstETH-YT (1) USDC -> [aggregator] -> WETH -> [connector]-> wstETH -> YT (2) USDC -> [aggregator] -> wstETH -> YT (3) USDC -> [aggregator] -> stETH -> [connector] -> wsETH -> YT
    function swapAnyTokenForYt(
        SwapTokenParams calldata params,
        ApproxValue sharesFlashBorrow,
        SwapTokenInput calldata tokenInput
    )
        external
        payable
        nonReentrant
        checkTwoCrypto(params.twoCrypto)
        checkDeadline(params.deadline)
        returns (uint256 principal)
    {
        TwoCrypto twoCrypto = params.twoCrypto;
        PrincipalToken principalToken = PrincipalToken(twoCrypto.coins(PT_INDEX));
        address underlying = twoCrypto.coins(TARGET_INDEX);

        _pullToken(params.tokenIn, params.amountIn);

        approveIfNeeded(params.tokenIn, address(i_aggregationRouter));

        {
            // Step 1: Swap input token to tokenMintShares using the aggregator
            uint256 tokenMintSharesAmount = i_aggregationRouter.swap{value: msg.value}({
                tokenIn: params.tokenIn,
                tokenOut: tokenInput.tokenMintShares,
                amountIn: params.amountIn,
                data: tokenInput.swapData,
                receiver: address(this)
            });

            // Step 2: Deposit tokenMintShares and get shares
            uint256 shares = _deposit(
                underlying,
                principalToken.i_asset().asAddr(),
                tokenInput.tokenMintShares,
                tokenMintSharesAmount,
                address(this),
                address(this)
            );

            // Step 4: Mint YT using the PT
            setHookContext();
            bytes memory data = ZapHookEncoder.encodeSupply(twoCrypto, underlying, msg.sender, shares);
            principal = principalToken.supply(sharesFlashBorrow.unwrap(), address(this), data);

            if (principal < params.minPrincipal) Errors.Zap_InsufficientYieldTokenOutput.selector.revertWith();
        }

        // Transfer YT to the receiver
        address yt = principalToken.i_yt().asAddr();
        SafeTransferLib.safeTransfer(yt, params.receiver, principal);

        Events.emitZapSwap({
            by: msg.sender,
            receiver: params.receiver,
            twoCrypto: twoCrypto,
            tokenIn: params.tokenIn,
            amountIn: params.amountIn,
            tokenOut: Token.wrap(yt),
            amountOut: principal
        });

        _refund(params.tokenIn);
    }

    function onSupply(uint256 sharesFlashBorrowed, uint256 principal, bytes calldata data) external {
        verifyAndClearHookContext();

        // Decode callback data
        (TwoCrypto twoCrypto, address underlying, address by, uint256 sharesFromUser) =
            ZapHookEncoder.decodeSupply(data);

        SafeTransferLib.safeTransfer(msg.sender, twoCrypto.unwrap(), principal);
        uint256 sharesDy = twoCrypto.exchange_received({i: PT_INDEX, j: TARGET_INDEX, dx: principal, minDy: 0});
        if (sharesFlashBorrowed > sharesDy + sharesFromUser) {
            Errors.Zap_DebtExceedsUnderlyingReceived.selector.revertWith();
        }

        // Repay the debt (shares) to the `principalToken`
        SafeTransferLib.safeTransfer(underlying, msg.sender, sharesFlashBorrowed);
        // Send the remaining shares to `by` (the user who initiated the swap)
        SafeTransferLib.safeTransfer(underlying, by, sharesDy + sharesFromUser - sharesFlashBorrowed);
    }

    /// @notice Swap approx `principal` of YT to at least `minAmount` of `token` and send the `token` to `receiver`
    /// @dev This function can't swap exact `principal` of YT, instead it swaps at most `principal` of YT because of the slippage related to the off-chain approximation value.
    /// @notice `token` must be supported by the connector. Otherwise, the swap will fail.
    /// @notice Caller must approve this contract to spend `principal` of YT.
    /// @param getDxResult Off-chain approximation result of `get_dx` result for the given `principal` of YT.
    /// @dev Flow: YT -> [twoCrypto] -> shares -> [connector] -> token
    /// @dev e.g. wstETH-YT (1) YT -> wstETH (2) YT -> wstETH -> [connector] -> stETH
    /// @dev e.g. rETH-YT (1) YT -> rETH (2) YT -> rETH -> [connector] -> WETH (3) YT -> rETH -> [connector] -> native ETH
    ///  ┌────┐  ┌───┐                                    ┌─────────┐┌───────┐┌─────────┐
    ///  │User│  │Zap│                                    │TwoCrypto││PrincipalToken││Connector│
    ///  └─┬──┘  └─┬─┘                                    └────┬────┘└───┬───┘└───┬─────┘
    ///    │       │                                           │         │        │
    ///    │Send YT│                                           │         │        │
    ///    │──────>│                                           │         │        │
    ///    │       │                                           │         │        │
    ///    │       │Estimate swap result with get_dx and get_dy│         │        │
    ///    │       │──────────────────────────────────────────>│         │        │
    ///    │       │                                           │         │        │
    ///    │       │        Flash redeeem with callback (onUnite)        │        │
    ///    │       │────────────────────────────────────────────────────>│        │
    ///    │       │                                           │         │        │
    ///    │       │                      Callback             │         │        │
    ///    │       │<────────────────────────────────────────────────────│        │
    ///    │       │                                           │         │        │
    ///    │       │          Swap the shares for PT           │         │        │
    ///    │       │──────────────────────────────────────────>│         │        │
    ///    │       │                                           │         │        │
    ///    │       │          Burn the PT, otherwise revert    │         │        │
    ///    │       │────────────────────────────────────────────────────>│        │
    ///    │       │                                           │         │        │
    ///    │       │              Convert remaining shares to token      │        │
    ///    │       │─────────────────────────────────────────────────────────────>│
    ///    │       │                                           │         │        │
    ///    │       │                Sends remaining token      │         │        │
    ///    │<─────────────────────────────────────────────────────────────────────│
    ///  ┌─┴──┐  ┌─┴─┐                                    ┌────┴────┐┌───┴───┐┌───┴─────┐
    ///  │User│  │Zap│                                    │TwoCrypto││PrincipalToken││Connector│
    ///  └────┘  └───┘                                    └─────────┘└───────┘└─────────┘
    function swapYtForToken(SwapYtParams calldata params, ApproxValue getDxResult)
        external
        nonReentrant
        checkTwoCrypto(params.twoCrypto)
        checkDeadline(params.deadline)
        returns (uint256 amountOut)
    {
        PrincipalToken principalToken = PrincipalToken(params.twoCrypto.coins(PT_INDEX));
        address yt = principalToken.i_yt().asAddr();
        (uint256 principalSpent, uint256 shares) =
            _swapYtForUnderlying(params.twoCrypto, principalToken, yt, params.principal, getDxResult);

        address underlying = params.twoCrypto.coins(TARGET_INDEX);

        amountOut = _redeem(
            underlying,
            principalToken.i_asset().asAddr(),
            params.tokenOut,
            shares - getDxResult.unwrap(),
            params.receiver
        );

        if (amountOut < params.amountOutMin) Errors.Zap_InsufficientTokenOutput.selector.revertWith();

        Events.emitZapSwap({
            by: msg.sender,
            receiver: params.receiver,
            twoCrypto: params.twoCrypto,
            tokenIn: Token.wrap(yt),
            amountIn: principalSpent,
            tokenOut: params.tokenOut,
            amountOut: amountOut
        });
    }

    /// @notice Swap any token to another token through an aggregator and then swap the token to YT
    /// @notice `tokenMintShares` must be supported by the connector. Otherwise, the swap will fail.
    /// @notice When `token` is not native ETH, the caller must approve this contract to spend `amountIn` of `token`.
    /// @dev Flow: token -> [aggregator] -> tokenMintShares -> [connector] -> shares -> [twoCrypto] -> YT OR token -> [aggregator] -> shares(=tokenMintShares) -> [twoCrypto] -> YT
    /// @dev e.g. wstETH-YT (1) USDC -> [aggregator] -> WETH -> [connector]-> wstETH -> YT (2) USDC -> [aggregator] -> wstETH -> YT (3) USDC -> [aggregator] -> stETH -> [connector] -> wsETH -> YT
    function swapYtForAnyToken(
        SwapYtParams calldata params,
        ApproxValue getDxResult,
        SwapTokenOutput calldata tokenOutput
    )
        external
        nonReentrant
        checkTwoCrypto(params.twoCrypto)
        checkDeadline(params.deadline)
        returns (uint256 amountOut)
    {
        PrincipalToken principalToken = PrincipalToken(params.twoCrypto.coins(PT_INDEX));
        address yt = principalToken.i_yt().asAddr();

        uint256 principalSpent;
        uint256 tokenRedeemSharesAmount;
        // Stack-too-deep error workaround
        {
            uint256 shares;
            (principalSpent, shares) =
                _swapYtForUnderlying(params.twoCrypto, principalToken, yt, params.principal, getDxResult);
            // Swap the excess shares for the desired token
            tokenRedeemSharesAmount = _redeem(
                principalToken.underlying(),
                principalToken.i_asset().asAddr(),
                tokenOutput.tokenRedeemShares,
                shares - getDxResult.unwrap(),
                address(this)
            );
        }

        // Approve the aggregator to spend the tokenRedeemShares
        approveIfNeeded(tokenOutput.tokenRedeemShares, address(i_aggregationRouter));

        // Swap tokenRedeemShares for the desired token using the aggregator
        // Note: It will fail with aggregator error when the returned amount of `tokenRedeemShares` from the above is less than the the input of aggregator, due to the slippage.
        amountOut = i_aggregationRouter.swap{
            value: FixedPointMathLib.ternary(tokenOutput.tokenRedeemShares.isNative(), tokenRedeemSharesAmount, 0)
        }({
            tokenIn: tokenOutput.tokenRedeemShares,
            tokenOut: params.tokenOut,
            amountIn: tokenRedeemSharesAmount,
            data: tokenOutput.swapData,
            receiver: params.receiver
        });

        if (amountOut < params.amountOutMin) Errors.Zap_InsufficientTokenOutput.selector.revertWith();

        Events.emitZapSwap({
            by: msg.sender,
            receiver: params.receiver,
            twoCrypto: params.twoCrypto,
            tokenIn: Token.wrap(yt),
            amountIn: principalSpent,
            tokenOut: params.tokenOut,
            amountOut: amountOut
        });

        // Note that the remaining `tokenRedeemShares` are left in the contract because the result of swap on the twoCrypto may be different from the estimation
        _refund(tokenOutput.tokenRedeemShares);
    }

    /// @dev Params (TwoCrypto, principalToken, yt) must match each other.
    function _swapYtForUnderlying(
        TwoCrypto twoCrypto,
        PrincipalToken principalToken,
        address yt,
        uint256 principal,
        ApproxValue sharesDx // Off-chain estimation `get_dx` result
    ) internal returns (uint256 principalSpent, uint256 shares) {
        // If `sharesDx` is not fresh enough or market changes dramatically, it may try to pull more YT than the input.
        principalSpent = twoCrypto.get_dy(TARGET_INDEX, PT_INDEX, sharesDx.unwrap());
        if (principalSpent > principal) Errors.Zap_PullYieldTokenGreaterThanInput.selector.revertWith();

        // Before calling `PrincipalToken.combine`, we need to transfer the principal because YT transfer triggers
        // reentrancy-guarded `PrincipalToken.onYtTransfer` function
        SafeTransferLib.safeTransferFrom(yt, msg.sender, address(this), principalSpent);

        // Economically speaking, in theory the shares we're going to get by combining is always greater than `sharesDx`
        // because PT should be discounted and 1 PT + 1 YT = 1 underlying (except fee).
        // Here, don't care that the `PrincipalToken.combine` will send the enough shares in return of the principal.
        setHookContext();
        shares = principalToken.combine(
            principalSpent,
            address(this),
            ZapHookEncoder.encodeUnite(twoCrypto, twoCrypto.coins(TARGET_INDEX), sharesDx)
        );
    }

    function onUnite(uint256 shares, uint256, /* principal */ bytes calldata data) external {
        verifyAndClearHookContext();

        // Note: If `sharesDx` is not fresh enough or market changes dramatically, it may revert.
        (TwoCrypto twoCrypto, address underlying, uint256 sharesDx) = ZapHookEncoder.decodeUnite(data);
        if (shares < sharesDx) Errors.Zap_InsufficientUnderlyingOutput.selector.revertWith();

        SafeTransferLib.safeTransfer(underlying, twoCrypto.unwrap(), sharesDx);
        twoCrypto.exchange_received({i: TARGET_INDEX, j: PT_INDEX, dx: sharesDx, minDy: 0});
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*            PrincipalToken issuance & redemption            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Caller must approve this contract spending `token` before calling this function if `token` is not native token
    /// @notice Supply `amountIn` of `token` to `principalToken` and issue at least `minPrincipal` of PT to `receiver`
    /// @dev Flow: token -> [connector] -> shares -> [principalToken] -> PT
    /// @dev e.g. wstETH-PT (1) native ETH -> [connector] -> wstETH -> [principalToken] -> PT (2) stETH -> [connector] -> wsETH -> [principalToken] -> PT
    function supply(
        PrincipalToken principalToken,
        Token tokenIn,
        uint256 amountIn,
        address receiver,
        uint256 minPrincipal
    ) external payable nonReentrant checkPrincipalToken(principalToken) returns (uint256 principal) {
        principal = _supply({
            principalToken: principalToken,
            tokenIn: tokenIn,
            amountIn: amountIn,
            from: msg.sender,
            receiver: receiver,
            minPrincipal: minPrincipal
        });

        Events.emitZapSupply({
            by: msg.sender,
            receiver: receiver,
            pt: address(principalToken),
            principal: principal,
            tokenIn: tokenIn,
            amountIn: amountIn
        });
    }

    /// @notice Caller must approve this contract spending `tokenIn` before calling this function if `tokenIn` is not native token.
    /// @notice Supply `amountIn` of `tokenIn` to `principalToken` and issue at least `minPrincipal` of PT to `receiver`
    /// @dev Flow: (1) token -> [aggregator] -> tokenMintShares -> [connector] -> shares -> [principalToken] -> PT (2) token -> [aggregator] -> shares(=tokenMintShares) -> [principalToken] -> PT
    /// @dev e.g. wstETH-PT (1) USDC -> [aggregator] -> WETH -> [connector]-> wstETH -> [principalToken] -> PT (2) USDC -> [aggregator] -> wstETH -> [principalToken] -> PT (3) USDC -> [aggregator] -> stETH -> [connector] -> wstETH -> [principalToken] -> PT
    function supplyAnyToken(
        PrincipalToken principalToken,
        Token tokenIn,
        uint256 amountIn,
        address receiver,
        uint256 minPrincipal,
        SwapTokenInput calldata tokenInput
    ) external payable nonReentrant checkPrincipalToken(principalToken) returns (uint256 principal) {
        _pullToken(tokenIn, amountIn);

        approveIfNeeded(tokenIn, address(i_aggregationRouter));
        uint256 tokenMintSharesAmount = i_aggregationRouter.swap{value: msg.value}({
            tokenIn: tokenIn,
            tokenOut: tokenInput.tokenMintShares,
            amountIn: amountIn,
            data: tokenInput.swapData,
            receiver: address(this)
        });

        principal = _supply({
            principalToken: principalToken,
            tokenIn: tokenInput.tokenMintShares,
            amountIn: tokenMintSharesAmount,
            from: address(this),
            receiver: receiver,
            minPrincipal: minPrincipal
        });

        Events.emitZapSupply({
            by: msg.sender,
            receiver: receiver,
            pt: address(principalToken),
            principal: principal,
            tokenIn: tokenIn,
            amountIn: amountIn
        });

        _refund(tokenIn);
    }

    /// @dev The function doesn't validate the `principalToken`.
    /// @dev `from` must be `msg.sender` or this contract basically. Otherwise, allowance can be exploited.
    function _supply(
        PrincipalToken principalToken,
        Token tokenIn,
        uint256 amountIn,
        address from,
        address receiver,
        uint256 minPrincipal
    ) internal returns (uint256 principal) {
        address underlying = principalToken.underlying();
        uint256 shares = _deposit(underlying, principalToken.i_asset().asAddr(), tokenIn, amountIn, address(this), from);
        approveIfNeeded(underlying, address(principalToken));
        principal = principalToken.supply(shares, receiver);

        if (principal < minPrincipal) Errors.Zap_InsufficientPrincipalOutput.selector.revertWith();
    }

    /// @notice Deposit `amount` of `token` from `from` and mint `shares` of `underlying` to `receiver`
    /// @dev Vulnerable to double-spending ETH
    /// DO NOT USE THIS FUNCTION IN LOOP OR INSIDE RECURSIVE CALLS LIKE multicall.
    function _deposit(address underlying, address asset, Token token, uint256 amount, address receiver, address from)
        internal
        returns (uint256 shares)
    {
        if (token.eq(underlying)) {
            shares = amount;
            if (from == address(this)) {
                // Skip the transfer if `from` and `receiver` are the this contract
                if (receiver != address(this)) SafeTransferLib.safeTransfer(token.unwrap(), receiver, amount);
            } else {
                SafeTransferLib.safeTransferFrom(token.unwrap(), from, receiver, amount);
            }
        } else {
            // Convert token to shares via connector
            VaultConnector connector = i_vaultConnectorRegistry.getConnector(underlying, asset);
            shares = _depositToVault(connector, token, amount, receiver, from);
        }
    }

    /// @notice Deposit `amountIn` of `token` from `from` to `vaultConnector` and mint `shares` to `receiver`
    /// @dev Vulnerable to double-spending ETH
    /// DO NOT USE THIS FUNCTION IN LOOP OR INSIDE RECURSIVE CALLS LIKE multicall.
    function _depositToVault(
        VaultConnector vaultConnector,
        Token token,
        uint256 amountIn,
        address receiver,
        address from
    ) internal returns (uint256 shares) {
        uint256 value;
        if (token.isNative()) {
            if (address(this).balance < amountIn) Errors.Zap_InsufficientETH.selector.revertWith();
            value = amountIn; // native ETH -> connector -> wstETH
        } else {
            if (from != address(this)) {
                SafeTransferLib.safeTransferFrom(token.unwrap(), from, address(this), amountIn);
            }
            approveIfNeeded(token, address(vaultConnector)); // token (e.g.stETH) -> connector -> wstETH
        }
        shares = vaultConnector.deposit{value: value}(token, amountIn, receiver);
    }

    struct CollectInput {
        address principalToken;
        PermitCollectInput permit;
    }

    struct PermitCollectInput {
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /// @notice Caller collects interest and rewards in a single transaction
    /// @param inputs Array of CollectInput - If the `deadline` in input is zero, we skip the permit call and directly collect interest and rewards.
    function collectWithPermit(CollectInput[] calldata inputs, address receiver) external nonReentrant {
        uint256 length = inputs.length;
        for (uint256 i = 0; i != length;) {
            CollectInput calldata input = inputs[i];
            ContractValidation.checkPrincipalToken(i_factory, input.principalToken);

            _permitCollector(input);
            PrincipalToken(input.principalToken).collect(receiver, msg.sender);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice This function is used to claim rewards manually when the `principalToken`'s rewardProxy is not available or not working properly.
    /// @param inputs Array of CollectInput - If the `deadline` in input is zero, we skip the permit call and directly collect interest and rewards.
    /// @param rewardTokens Array of array of rewards to claim - Each inner array contains the reward tokens to be collected from the corresponding `principalToken`.
    function collectRewardsWithPermit(
        CollectInput[] calldata inputs,
        address[][] calldata rewardTokens,
        address receiver
    ) external nonReentrant {
        uint256 length = inputs.length;
        if (length != rewardTokens.length) Errors.Zap_LengthMismatch.selector.revertWith();
        for (uint256 i = 0; i != length;) {
            CollectInput calldata input = inputs[i];
            ContractValidation.checkPrincipalToken(i_factory, input.principalToken);

            _permitCollector(input);
            PrincipalToken(input.principalToken).collectRewards(rewardTokens[i], receiver, msg.sender);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev deadline == 0 means `permitCollector` is skipped.
    function _permitCollector(CollectInput calldata input) internal {
        if (input.permit.deadline == 0) return;

        // Permit signature might be consumed by fruntrun.
        // https://www.trust-security.xyz/post/permission-denied
        try PrincipalToken(input.principalToken).permitCollector(
            msg.sender, address(this), input.permit.deadline, input.permit.v, input.permit.r, input.permit.s
        ) {} catch {
            // Permit potentially got fruntrun. If the Zap is not approved, collect() will revert.
        }
    }

    /// @notice Caller must approve this contract spending `principalToken` before calling this function
    /// @notice Combine `principal` amount of PT and YT to get back underlying shares
    /// @param principalToken The PrincipalToken contract
    /// @param tokenOut The token to receive
    /// @param principal The amount of PT (and YT) to combine
    /// @param receiver The address to receive the output token
    /// @param minAmount The minimum amount of output token to receive
    /// @return amountOut The amount of output token received
    function combine(
        PrincipalToken principalToken,
        Token tokenOut,
        uint256 principal,
        address receiver,
        uint256 minAmount
    ) external nonReentrant checkPrincipalToken(principalToken) returns (uint256 amountOut) {
        amountOut =
            _combine({principalToken: principalToken, token: tokenOut, principal: principal, receiver: receiver});
        if (amountOut < minAmount) Errors.Zap_InsufficientTokenOutput.selector.revertWith();

        Events.emitZapUnite({
            by: msg.sender,
            receiver: receiver,
            pt: address(principalToken),
            principal: principal,
            tokenOut: tokenOut,
            amountOut: amountOut
        });
    }

    /// @notice Combine PT and YT to get shares and swap those shares to any token through an aggregator
    /// @notice Caller must approve this contract to spend both PT and YT before calling
    /// @param principalToken The PrincipalToken contract
    /// @param principal The amount of PT (and YT) to combine
    /// @param tokenOut The token to receive
    /// @param receiver The address to receive the output token
    /// @param minAmount Minimum amount of output token to receive
    /// @param tokenOutput Data for swapping shares to desired token
    /// @return amountOut The amount of output token received
    function combineToAnyToken(
        PrincipalToken principalToken,
        Token tokenOut,
        uint256 principal,
        address receiver,
        uint256 minAmount,
        SwapTokenOutput calldata tokenOutput
    ) external nonReentrant checkPrincipalToken(principalToken) returns (uint256 amountOut) {
        // Combine PT and YT for intermediate token
        uint256 tokenRedeemSharesAmount = _combine({
            principalToken: principalToken,
            token: tokenOutput.tokenRedeemShares,
            principal: principal,
            receiver: address(this)
        });

        // Approve aggregator to spend intermediate token if needed
        approveIfNeeded(tokenOutput.tokenRedeemShares, address(i_aggregationRouter));

        // Calculate ETH value to send with swap if intermediate token is native ETH
        uint256 valueToSend =
            FixedPointMathLib.ternary(tokenOutput.tokenRedeemShares.isNative(), tokenRedeemSharesAmount, 0);

        // Swap intermediate token for desired output token
        amountOut = i_aggregationRouter.swap{value: valueToSend}({
            tokenIn: tokenOutput.tokenRedeemShares,
            tokenOut: tokenOut,
            amountIn: tokenRedeemSharesAmount,
            data: tokenOutput.swapData,
            receiver: receiver
        });

        if (amountOut < minAmount) Errors.Zap_InsufficientTokenOutput.selector.revertWith();

        Events.emitZapUnite({
            by: msg.sender,
            receiver: receiver,
            pt: address(principalToken),
            principal: principal,
            tokenOut: tokenOut,
            amountOut: amountOut
        });

        // Refund any remaining intermediate tokens
        _refund(tokenOutput.tokenRedeemShares);
    }

    /// @dev Top-level internal function to combine PT and YT to get underlying shares
    /// @dev The function doesn't validate the `principalToken`.
    function _combine(PrincipalToken principalToken, Token token, uint256 principal, address receiver)
        internal
        returns (uint256 amountOut)
    {
        SafeTransferLib.safeTransferFrom(address(principalToken), msg.sender, address(this), principal);
        SafeTransferLib.safeTransferFrom(principalToken.i_yt().asAddr(), msg.sender, address(this), principal);

        // Combine PT and YT to get underlying shares
        uint256 shares = principalToken.combine(principal, address(this));

        // Redeem shares for intermediate token
        amountOut = _redeem(principalToken.underlying(), principalToken.i_asset().asAddr(), token, shares, receiver);
    }

    /// @notice Caller must approve this contract spending `principal` of PT before calling this function
    /// @notice Redeem `principal` of PT from `principalToken` and send `minAmount` of `token` to `receiver`
    /// @dev Flow: PT -> [principalToken] -> shares -> [connector] -> token
    /// @dev e.g. wstETH-PT (1) PT -> wstETH -> [connector] -> stETH (2) PT -> wstETH
    function redeem(
        PrincipalToken principalToken,
        Token tokenOut,
        uint256 principal,
        address receiver,
        uint256 minAmount
    ) external nonReentrant checkPrincipalToken(principalToken) returns (uint256 amountOut) {
        address underlying = principalToken.underlying();

        uint256 shares = principalToken.redeem(principal, address(this), msg.sender);
        amountOut = _redeem(underlying, principalToken.i_asset().asAddr(), tokenOut, shares, receiver);

        if (amountOut < minAmount) Errors.Zap_InsufficientTokenOutput.selector.revertWith();

        Events.emitZapRedeem({
            by: msg.sender,
            receiver: receiver,
            pt: address(principalToken),
            principal: principal,
            tokenOut: tokenOut,
            amountOut: amountOut
        });
    }

    function redeemToAnyToken(
        PrincipalToken principalToken,
        Token tokenOut,
        uint256 principal,
        address receiver,
        uint256 minAmount,
        SwapTokenOutput calldata tokenOutput
    ) external nonReentrant checkPrincipalToken(principalToken) returns (uint256 amountOut) {
        address underlying = principalToken.underlying();
        uint256 shares = principalToken.redeem(principal, address(this), msg.sender);

        uint256 tokenRedeemSharesAmount =
            _redeem(underlying, principalToken.i_asset().asAddr(), tokenOutput.tokenRedeemShares, shares, address(this));

        approveIfNeeded(tokenOutput.tokenRedeemShares, address(i_aggregationRouter));

        uint256 valueToSend =
            FixedPointMathLib.ternary(tokenOutput.tokenRedeemShares.isNative(), tokenRedeemSharesAmount, 0);

        amountOut = i_aggregationRouter.swap{value: valueToSend}({
            tokenIn: tokenOutput.tokenRedeemShares,
            tokenOut: tokenOut,
            amountIn: tokenRedeemSharesAmount,
            data: tokenOutput.swapData,
            receiver: receiver
        });

        if (amountOut < minAmount) Errors.Zap_InsufficientTokenOutput.selector.revertWith();

        Events.emitZapRedeem({
            by: msg.sender,
            receiver: receiver,
            pt: address(principalToken),
            principal: principal,
            tokenOut: tokenOut,
            amountOut: amountOut
        });

        _refund(tokenOutput.tokenRedeemShares);
    }

    function _redeemFromVault(address underlying, address asset, Token token, uint256 shares, address receiver)
        internal
        returns (uint256 amountOut)
    {
        VaultConnector vaultConnector = i_vaultConnectorRegistry.getConnector(underlying, asset);
        approveIfNeeded(underlying, address(vaultConnector));
        amountOut = vaultConnector.redeem(token, shares, receiver);
    }

    function _redeem(address underlying, address asset, Token tokenOut, uint256 shares, address receiver)
        internal
        returns (uint256 amountOut)
    {
        if (tokenOut.eq(underlying)) {
            amountOut = shares;
            if (receiver != address(this)) SafeTransferLib.safeTransfer(underlying, receiver, amountOut);
        } else {
            amountOut = _redeemFromVault(underlying, asset, tokenOut, shares, receiver);
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     Transfer Helper                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The function should be used in top-level calls only.
    function _pullToken(Token token, uint256 amount) internal {
        if (token.isNative()) {
            if (msg.value != amount) Errors.Zap_InconsistentETHReceived.selector.revertWith();
        } else {
            if (msg.value != 0) Errors.Zap_InconsistentETHReceived.selector.revertWith();
            SafeTransferLib.safeTransferFrom(token.unwrap(), msg.sender, address(this), amount);
        }
    }

    function approveIfNeeded(Token token, address spender) internal {
        if (!token.isNative()) {
            approveIfNeeded(token.unwrap(), spender);
        }
    }

    function _refund(Token token) internal {
        if (token.isNative()) {
            SafeTransferLib.safeTransferAllETH(msg.sender);
        } else {
            SafeTransferLib.safeTransferAll(token.unwrap(), msg.sender);
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     　　　Validation                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    modifier checkTwoCrypto(TwoCrypto twoCrypto) {
        ContractValidation.checkTwoCrypto(i_factory, twoCrypto.unwrap(), i_twoCryptoDeployer);
        _;
    }

    modifier checkPrincipalToken(PrincipalToken principalToken) {
        ContractValidation.checkPrincipalToken(i_factory, address(principalToken));
        _;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

import {Token} from "../../types/Token.sol";
import {Errors} from "../../Errors.sol";

import {AccessManaged, AccessManager} from "../AccessManager.sol";
import {LibApproval} from "../../utils/LibApproval.sol";

/// @notice Third-party aggregator payload for swap
/// @param router The address of the router
/// @param payload The payload to call the router
struct RouterPayload {
    address router;
    bytes payload;
}

/**
 * @title AggregationRouter
 * @notice Contract that handles token swaps through various DEX aggregators
 * @dev This contract makes three important assumptions:
 * 1. Deadline and slippage checks are handled by the underlying swap provider in their payload
 * 2. When this swap is the first operation in a sequence (e.g. in Zap),
 *    the input amount will be fully consumed by the swap.
 * 3. Offchain will call API like 1inch set receiver in calldata so Aggregator like 1inch directly transfer the token to receiver
 */
contract AggregationRouter is LibApproval, AccessManaged {
    AccessManager private immutable _i_accessManager;

    mapping(address router => bool isSupported) public s_routers;

    constructor(AccessManager accessManager, address[] memory _routers) {
        _i_accessManager = accessManager;
        for (uint256 i = 0; i < _routers.length; i++) {
            s_routers[_routers[i]] = true;
        }
    }

    function addRouter(address router) external restricted {
        s_routers[router] = true;
    }

    function removeRouter(address router) external restricted {
        s_routers[router] = false;
    }

    function swap(Token tokenIn, Token tokenOut, uint256 amountIn, address receiver, RouterPayload calldata data)
        external
        payable
        returns (uint256 returnAmount)
    {
        address router = data.router;
        if (!s_routers[router]) revert Errors.AggregationRouter_UnsupportedRouter();
        if (tokenIn.isNative() && msg.value < amountIn) revert Errors.AggregationRouter_InvalidMsgValue();

        uint256 balanceBefore =
            tokenOut.isNative() ? receiver.balance : SafeTransferLib.balanceOf(tokenOut.unwrap(), receiver);
        uint256 inputBalanceBefore;

        if (tokenIn.isNative()) {
            // Pre-swap balance
            inputBalanceBefore = address(this).balance - msg.value;
        } else {
            // Pre-swap balance
            inputBalanceBefore = SafeTransferLib.balanceOf(tokenIn.unwrap(), address(this));
            // ERC20 transfer from sender and approve
            SafeTransferLib.safeTransferFrom(tokenIn.unwrap(), msg.sender, address(this), amountIn);
            approveIfNeeded(tokenIn.unwrap(), router);
        }

        (bool success,) = router.call{value: tokenIn.isNative() ? amountIn : 0}(data.payload);
        if (!success) revert Errors.AggregationRouter_SwapFailed();

        uint256 balanceAfter =
            tokenOut.isNative() ? receiver.balance : SafeTransferLib.balanceOf(tokenOut.unwrap(), receiver);
        returnAmount = balanceAfter - balanceBefore;

        /// @audit-info returnAmount can be 0 if data.tokenOut from offchain is different from tokenOut
        if (returnAmount == 0) revert Errors.AggregationRouter_ZeroReturn();

        // Refund post-swap - pre-swap balance
        if (tokenIn.isNative()) {
            uint256 remainingBalance = address(this).balance - inputBalanceBefore;
            if (remainingBalance > 0) {
                SafeTransferLib.safeTransferETH(msg.sender, remainingBalance);
            }
        } else {
            uint256 inputBalanceAfter = SafeTransferLib.balanceOf(tokenIn.unwrap(), address(this));
            uint256 remainingBalance = inputBalanceAfter - inputBalanceBefore;
            if (remainingBalance > 0) {
                SafeTransferLib.safeTransfer(tokenIn.unwrap(), msg.sender, remainingBalance);
            }
        }
    }

    function i_accessManager() public view override returns (AccessManager) {
        return _i_accessManager;
    }

    function rescue(Token token, address to, uint256 value) external restricted {
        if (token.isNative()) {
            SafeTransferLib.safeTransferETH(to, value);
        } else {
            SafeTransferLib.safeTransfer(token.unwrap(), to, value);
        }
    }

    receive() external payable {}
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

// Inherits
import {Ownable} from "solady/src/auth/Ownable.sol";
import {Initializable} from "solady/src/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/src/utils/UUPSUpgradeable.sol";

// Interfaces
import {SafeCastLib} from "solady/src/utils/SafeCastLib.sol";
import {ERC4626} from "solady/src/tokens/ERC4626.sol";
import {ERC20} from "solady/src/tokens/ERC20.sol";
import {Factory} from "../Factory.sol";
import {IRewardProxy} from "../interfaces/IRewardProxy.sol";
import {PrincipalToken} from "../tokens/PrincipalToken.sol";
import {VaultConnector, VaultConnectorRegistry} from "../modules/connectors/VaultConnectorRegistry.sol";

// Internal
import "../Types.sol";
import {LibTwoCryptoNG} from "../utils/LibTwoCryptoNG.sol";
import {ConversionLib} from "./ConversionLib.sol";
import {TwoCryptoNGPreviewLib} from "../utils/TwoCryptoNGPreviewLib.sol";
import {ContractValidation} from "../utils/ContractValidation.sol";
import {ZapMathLib} from "../utils/ZapMathLib.sol";
import {LibExpiry} from "../utils/LibExpiry.sol";
import {RewardLensLib} from "./RewardLensLib.sol";
import {WAD, PT_INDEX, TARGET_INDEX} from "../Constants.sol";
import "../Constants.sol" as Constants;
import {Errors} from "../Errors.sol";

contract Quoter is UUPSUpgradeable, Initializable, Ownable {
    using LibTwoCryptoNG for TwoCrypto;
    using SafeCastLib for uint256;
    using SafeCastLib for int256;

    /// @dev The maximum refund tolerance in basis points (100 = 1%). Revert if the refund is greater than this value.
    uint256 internal constant REFUND_TOLERANCE_BPS = 100;

    address public s_WETH;
    address public s_twoCryptoDeployer;
    Factory public s_factory;
    VaultConnectorRegistry public s_vaultConnectorRegistry;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        Factory factory,
        VaultConnectorRegistry vaultConnectorRegistry,
        address twoCryptoDeployer,
        address WETH,
        address owner
    ) public initializer {
        s_factory = factory;
        s_vaultConnectorRegistry = vaultConnectorRegistry;
        s_twoCryptoDeployer = twoCryptoDeployer;
        s_WETH = WETH;
        _initializeOwner(owner);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         Token List                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function getTokenInList(TwoCrypto twoCrypto) public view returns (Token[] memory) {
        address underlying = twoCrypto.coins(TARGET_INDEX);
        address asset = address(PrincipalToken(twoCrypto.coins(PT_INDEX)).i_asset());

        VaultConnector connector = s_vaultConnectorRegistry.s_connectors(underlying, asset);
        bool isERC4626 = _isERC4626Depositable(underlying, asset);

        if (connector != VaultConnector(address(0))) {
            // Connector is present
            return connector.getTokenInList();
        } else if (underlying == asset) {
            // Underlying is same as asset. Handle the edge case to avoid duplicate tokens in the list.
            Token[] memory tokens = new Token[](1);
            tokens[0] = Token.wrap(underlying);
            return tokens;
        } else if (isERC4626) {
            // Underlying is like an ERC4626
            bool isWETH = asset == s_WETH;
            Token[] memory tokens = new Token[](isWETH ? 3 : 2);
            tokens[0] = Token.wrap(underlying);
            tokens[1] = Token.wrap(asset);
            if (isWETH) tokens[2] = Token.wrap(Constants.NATIVE_ETH);
            return tokens;
        } else {
            // None of the above
            Token[] memory tokens = new Token[](1);
            tokens[0] = Token.wrap(underlying);
            return tokens;
        }
    }

    function getTokenOutList(TwoCrypto twoCrypto) public view returns (Token[] memory) {
        address underlying = twoCrypto.coins(TARGET_INDEX);
        address asset = address(PrincipalToken(twoCrypto.coins(PT_INDEX)).i_asset());

        VaultConnector connector = s_vaultConnectorRegistry.s_connectors(underlying, asset);
        if (connector != VaultConnector(address(0))) {
            return connector.getTokenOutList();
        } else {
            // Regardless of ERC4626 or not, the token out list is always the underlying token because some ERC4626 have cooldown period for redeeming.
            Token[] memory tokens = new Token[](1);
            tokens[0] = Token.wrap(underlying);
            return tokens;
        }
    }

    function _isERC4626Depositable(address erc4626Like, address asset) internal view returns (bool) {
        if (!ContractValidation.hasCode(erc4626Like)) return false; // No code
        // Calls may fail due to a non-existent function selector
        try ERC4626(erc4626Like).asset() returns (address _asset) {
            if (_asset != asset) return false; // Asset mismatch
        } catch {
            return false;
        }
        try ERC4626(erc4626Like).maxDeposit(address(this)) returns (uint256 maxDeposit) {
            if (maxDeposit == 0) return false; // Deposit limit reached
        } catch {
            return false;
        }
        try ERC4626(erc4626Like).previewDeposit(1) {}
        catch {
            return false;
        }
        return true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 Add Liquidity Preview                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev When total supply is zero, the Curve.calc_token_amount_in() fails.
    function previewAddLiquidityOneToken(TwoCrypto twoCrypto, Token tokenIn, uint256 amountIn)
        public
        view
        checkTwoCrypto(twoCrypto)
        returns (uint256 liquidity, uint256 principal)
    {
        PrincipalToken principalToken = PrincipalToken(twoCrypto.coins(PT_INDEX));

        uint256 shares = vaultPreviewDeposit(principalToken, tokenIn, amountIn);
        uint256 sharesToPool = ZapMathLib.computeSharesToTwoCrypto(twoCrypto, principalToken, shares);

        if (LibExpiry.isExpired(principalToken)) return (0, 0);
        principal = principalToken.previewSupply(shares - sharesToPool);
        liquidity = twoCrypto.calc_token_amount_in({amount0: sharesToPool, amount1: principal});
    }

    function previewAddLiquidity(TwoCrypto twoCrypto, uint256 shares, uint256 principal)
        public
        view
        checkTwoCrypto(twoCrypto)
        returns (uint256 liquidity)
    {
        liquidity = twoCrypto.calc_token_amount_in({amount0: shares, amount1: principal});
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 Remove Liquidity Preview                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Preview the withdrawal of liquidity `liquidity` from a TwoCrypto pool and convert the withdrawn tokens to a single token `tokenOut`
    function previewRemoveLiquidityOneToken(TwoCrypto twoCrypto, Token tokenOut, uint256 liquidity)
        public
        view
        checkTwoCrypto(twoCrypto)
        returns (uint256 amountOut)
    {
        PrincipalToken principalToken = PrincipalToken(twoCrypto.coins(PT_INDEX));

        uint256 sharesWithdrawn;
        if (LibExpiry.isNotExpired(principalToken)) {
            // If the PT is not expired, withdraw one token (underlying tokens)
            // It may fail if the pool is imbalanced
            sharesWithdrawn = twoCrypto.calc_withdraw_one_coin(liquidity, TARGET_INDEX);
        } else {
            (uint256 shares, uint256 principal) = previewRemoveLiquidity({twoCrypto: twoCrypto, liquidity: liquidity});
            // Reeem the PT and convert the underlying tokens
            uint256 sharesFromPT = principalToken.previewRedeem(principal);
            sharesWithdrawn = shares + sharesFromPT;
        }
        // Convert the shares to the desired token `tokenOut`
        amountOut = vaultPreviewRedeem(principalToken, tokenOut, sharesWithdrawn);
    }

    /// @notice Preview the proportional withdrawal of liquidity from a TwoCrypto pool
    function previewRemoveLiquidity(TwoCrypto twoCrypto, uint256 liquidity)
        public
        view
        checkTwoCrypto(twoCrypto)
        returns (uint256 shares, uint256 principal)
    {
        uint256 reserve0 = twoCrypto.balances(TARGET_INDEX);
        uint256 reserve1 = twoCrypto.balances(PT_INDEX);
        uint256 totalSupply = twoCrypto.totalSupply();
        if (totalSupply == 0) return (0, 0);
        shares = reserve0 * liquidity / totalSupply;
        principal = reserve1 * liquidity / totalSupply;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      Swap PT Preview                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function previewSwapTokenForPt(TwoCrypto twoCrypto, Token tokenIn, uint256 amountIn)
        public
        view
        checkTwoCrypto(twoCrypto)
        returns (uint256 principal)
    {
        uint256 shares = vaultPreviewDeposit(PrincipalToken(twoCrypto.coins(PT_INDEX)), tokenIn, amountIn);
        principal = twoCrypto.get_dy({i: TARGET_INDEX, j: PT_INDEX, dx: shares});
    }

    function previewSwapPtForToken(TwoCrypto twoCrypto, Token tokenOut, uint256 principal)
        public
        view
        checkTwoCrypto(twoCrypto)
        returns (uint256 amountOut)
    {
        uint256 shares = twoCrypto.get_dy({i: PT_INDEX, j: TARGET_INDEX, dx: principal});
        amountOut = vaultPreviewRedeem(PrincipalToken(twoCrypto.coins(PT_INDEX)), tokenOut, shares);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      Swap YT Preview                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function previewSwapYtForToken(TwoCrypto twoCrypto, Token tokenOut, uint256 principal)
        public
        view
        checkTwoCrypto(twoCrypto)
        returns (uint256 amountOut, ApproxValue principalActual, ApproxValue getDxResult)
    {
        PrincipalToken pt = PrincipalToken(twoCrypto.coins(PT_INDEX));

        // NOTE: get_dy and get_dx don't take pool rampping into account.
        uint256 sharesDx = TwoCryptoNGPreviewLib.binsearch_dx(twoCrypto, TARGET_INDEX, PT_INDEX, principal);
        principalActual = ApproxValue.wrap(twoCrypto.get_dy(TARGET_INDEX, PT_INDEX, sharesDx));

        uint256 shares = pt.previewCombine(principalActual.unwrap());

        if (shares < sharesDx) revert Errors.Quoter_InsufficientUnderlyingOutput();

        uint256 sharesOut = shares - sharesDx;
        amountOut = vaultPreviewRedeem(pt, tokenOut, sharesOut);
        getDxResult = ApproxValue.wrap(sharesDx);
    }

    /// @return guessYt The output YT amount
    /// @return sharesBorrow The amount of shares borrowed to execute the swap (i.e. the amount of PT minted)
    /// @return sharesSpent The net amount of shares spent to execute the swap. Excludes the amount of shares refunded.
    function previewSwapTokenForYt(TwoCrypto twoCrypto, Token tokenIn, uint256 amountIn)
        public
        view
        checkTwoCrypto(twoCrypto)
        returns (ApproxValue guessYt, ApproxValue sharesBorrow, uint256 sharesSpent)
    {
        uint256 shares = vaultPreviewDeposit(PrincipalToken(twoCrypto.coins(PT_INDEX)), tokenIn, amountIn);
        (guessYt, sharesBorrow, sharesSpent) = _previewSwapUnderlyingForYt(twoCrypto, shares);
    }

    /// @notice Quote the amount of shares needed to swap a given amount of YT for underlying tokens
    /// @return sharesIn The amount of shares needed to get the desired amount of YT.
    /// @return sharesBorrow The amount of shares borrowed to execute the swap (i.e. the amount of PT minted)
    function uncheckedPreviewSwapUnderlyingForExactYt(TwoCrypto twoCrypto, uint256 ytOut)
        public
        view
        returns (uint256 sharesIn, uint256 sharesBorrow)
    {
        sharesBorrow = PrincipalToken(twoCrypto.coins(PT_INDEX)).previewIssue(ytOut);
        uint256 sharesDy = twoCrypto.get_dy({i: PT_INDEX, j: TARGET_INDEX, dx: ytOut});
        sharesIn = sharesBorrow - sharesDy;
    }

    function _previewSwapUnderlyingForYt(TwoCrypto twoCrypto, uint256 shares)
        internal
        view
        returns (ApproxValue, ApproxValue, uint256)
    {
        uint256 low = 0;
        uint256 high = convertSharesToYt(twoCrypto, shares); // Initial guess

        // Step 1: Expand upper bound
        while (true) {
            try this.uncheckedPreviewSwapUnderlyingForExactYt(twoCrypto, high) returns (uint256 requiredShares, uint256)
            {
                if (requiredShares > shares) {
                    break;
                } else {
                    high = high * 2; // Double the guess
                }
            } catch {
                break;
            }
        }

        // Step 2: Binary search
        uint256 guessYt;
        while (low <= high) {
            uint256 mid = (low + high) / 2;
            try this.uncheckedPreviewSwapUnderlyingForExactYt(twoCrypto, mid) returns (uint256 requiredShares, uint256)
            {
                if (requiredShares <= shares) {
                    guessYt = mid; // Cache last value
                    low = mid + 1; // Try larger YT
                } else {
                    high = mid - 1; // Too many shares, try smaller YT
                }
            } catch {
                high = mid - 1; // Revert means YT is too large
            }
        }

        (uint256 sharesSpent, uint256 sharesBorrowed) = uncheckedPreviewSwapUnderlyingForExactYt(twoCrypto, guessYt);

        // If buying YT hits a threshold of max output YT, the refund will be non-zero.
        // For some low decimals tokens, the refund will be always non-zero because of precision loss.
        // Actual transaction will have a small refund because of the error margin for slippage.
        uint256 refund = shares - sharesSpent;
        uint256 refundBps = (refund * Constants.BASIS_POINTS) / shares;
        if (refundBps > REFUND_TOLERANCE_BPS) revert Errors.Quoter_MaximumYtOutputReached();

        return (ApproxValue.wrap(guessYt), ApproxValue.wrap(sharesBorrowed), sharesSpent);
    }

    /// @notice Quote the amount of shares needed to get the desired amount of YT
    function previewSwapUnderlyingForExactYt(TwoCrypto twoCrypto, uint256 ytOut)
        external
        view
        checkTwoCrypto(twoCrypto)
        returns (uint256 sharesSpent, uint256 sharesBorrow)
    {
        (sharesSpent, sharesBorrow) = uncheckedPreviewSwapUnderlyingForExactYt(twoCrypto, ytOut);
    }

    /**
     * @dev Returns the maximal amount of YT one can obtain with a given amount of IBT (i.e without fees or slippage).
     * @dev Gives the upper bound of the interval to perform bisection search in previewFlashSwapExactIBTForYT().
     * @return The upper bound for search interval in root finding algorithms
     */
    function convertSharesToYt(TwoCrypto twoCrypto, uint256 shares)
        public
        view
        checkTwoCrypto(twoCrypto)
        returns (uint256)
    {
        uint256 bDecimals = ERC20(twoCrypto.coins(PT_INDEX)).decimals();
        uint256 uDecimals = ERC20(twoCrypto.coins(TARGET_INDEX)).decimals();

        // Convert units:
        // 10^u * (10^18 * 10^b / 10^u / 10^18) => 10^b
        return shares * 10 ** (18 + bDecimals - uDecimals) / ConversionLib.getYtPriceInUnderlying(twoCrypto);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                PrincipalToken Preview                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Preview the amount of `pt` minted for a given amount `amountIn` of `tokenIn`
    /// @dev If `pt` is expired, the preview will return 0
    function previewSupply(PrincipalToken pt, Token tokenIn, uint256 amountIn)
        public
        view
        checkPrincipalToken(pt)
        returns (uint256)
    {
        uint256 shares = vaultPreviewDeposit(pt, tokenIn, amountIn);
        return pt.previewSupply(shares);
    }

    /// @notice Preview the amount of `tokenOut` that will be received in return for `principal` amount of `pt`
    /// @dev If `pt` is not expired, the preview will return 0
    function previewRedeem(PrincipalToken pt, Token tokenOut, uint256 principal)
        public
        view
        checkPrincipalToken(pt)
        returns (uint256)
    {
        uint256 shares = pt.previewRedeem(principal);
        return vaultPreviewRedeem(pt, tokenOut, shares);
    }

    /// @notice Preview the amount of `tokenOut` that will be received in return for `principal` amount of `pt`
    function previewCombine(PrincipalToken pt, Token tokenOut, uint256 principal)
        public
        view
        checkPrincipalToken(pt)
        returns (uint256)
    {
        uint256 shares = pt.previewCombine(principal);
        return vaultPreviewRedeem(pt, tokenOut, shares);
    }

    struct PreviewCollectResult {
        uint256 interest;
        TokenReward[] rewards;
    }

    function previewCollect(PrincipalToken pt, address account)
        public
        view
        checkPrincipalToken(pt)
        returns (PreviewCollectResult memory result)
    {
        result.interest = pt.previewCollect(account);
        result.rewards = RewardLensLib.getTokenRewards(pt, account);
    }

    function previewCollects(PrincipalToken[] calldata pts, address account)
        public
        view
        returns (PreviewCollectResult[] memory result)
    {
        result = new PreviewCollectResult[](pts.length);
        for (uint256 i = 0; i < pts.length; i++) {
            result[i] = previewCollect(pts[i], account);
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Vault Preview                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Preview the amount of shares minted for a given amount `amountIn` of `tokenIn`
    /// @dev Reverts if the token is not supported by the vault connector or ERC4626
    function vaultPreviewDeposit(PrincipalToken principalToken, Token tokenIn, uint256 amountIn)
        public
        view
        checkPrincipalToken(principalToken)
        returns (uint256)
    {
        address underlying = principalToken.underlying();
        address asset = address(principalToken.i_asset());
        return _previewDeposit(underlying, asset, tokenIn, amountIn);
    }

    /// @notice Preview the amount of `tokenOut` that will be received for `shares` shares of `principalToken.underlying()`
    /// @dev Reverts if the token is not supported by the vault connector or ERC4626
    function vaultPreviewRedeem(PrincipalToken principalToken, Token tokenOut, uint256 shares)
        public
        view
        checkPrincipalToken(principalToken)
        returns (uint256)
    {
        address underlying = principalToken.underlying();
        address asset = address(principalToken.i_asset());
        return _previewRedeem(underlying, asset, tokenOut, shares);
    }

    function _previewDeposit(address underlying, address asset, Token tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256)
    {
        if (tokenIn.eq(underlying)) return amountIn; // No need to convert.

        VaultConnector connector = s_vaultConnectorRegistry.s_connectors(underlying, asset);

        if (connector != VaultConnector(address(0))) return connector.previewDeposit(tokenIn, amountIn);
        // Fall back to ERC4626 if the connector is not found
        if (tokenIn.eq(asset) || (tokenIn.isNative() && asset == s_WETH)) {
            (bool s, bytes memory ret) = underlying.staticcall(abi.encodeCall(ERC4626.previewDeposit, (amountIn)));
            if (s && underlying.code.length > 0) return abi.decode(ret, (uint256));
            revert Errors.Quoter_ERC4626FallbackCallFailed();
        }
        revert Errors.Quoter_ConnectorInvalidToken();
    }

    function _previewRedeem(address underlying, address asset, Token tokenOut, uint256 shares)
        internal
        view
        returns (uint256)
    {
        if (tokenOut.eq(underlying)) return shares; // No need to convert.

        VaultConnector connector = s_vaultConnectorRegistry.s_connectors(underlying, asset);

        if (connector != VaultConnector(address(0))) return connector.previewRedeem(tokenOut, shares);
        // Fall back to ERC4626 if the connector is not found
        if (tokenOut.eq(asset) || (tokenOut.isNative() && asset == s_WETH)) {
            (bool s, bytes memory ret) = underlying.staticcall(abi.encodeCall(ERC4626.previewRedeem, (shares)));
            if (s && underlying.code.length > 0) return abi.decode(ret, (uint256));
            revert Errors.Quoter_ERC4626FallbackCallFailed();
        }
        revert Errors.Quoter_ConnectorInvalidToken();
    }

    function _delta(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function _authorizeUpgrade(address) internal view override onlyOwner {}

    modifier checkTwoCrypto(TwoCrypto twoCrypto) {
        ContractValidation.checkTwoCrypto(s_factory, twoCrypto.unwrap(), s_twoCryptoDeployer);
        _;
    }

    modifier checkPrincipalToken(PrincipalToken principalToken) {
        ContractValidation.checkPrincipalToken(s_factory, address(principalToken));
        _;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {ERC20} from "solady/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

import {TwoCrypto} from "../types/TwoCrypto.sol";

/// @notice Library for interacting with TwoCrypto contracts.
/// @dev These function do not check contract existence.
library LibTwoCryptoNG {
    error TwoCryptoNG_GetDxFailed();
    error TwoCryptoNG_GetDyFailed();
    error TwoCryptoNG_AddLiquidityFailed();
    error TwoCryptoNG_RemoveLiquidityFailed();
    error TwoCryptoNG_RemoveLiquidityOneCoinFailed();
    error TwoCryptoNG_ExchangeReceivedFailed();
    error TwoCryptoNG_CalcTokenAmountFailed();
    error TwoCryptoNG_CalcWithdrawOneCoinFailed();

    uint256 constant COIN0 = 0;
    uint256 constant COIN1 = 1;

    function name(TwoCrypto twoCrypto) internal view returns (string memory) {
        (bool s, bytes memory ret) = twoCrypto.unwrap().staticcall(abi.encodeWithSignature("name()"));
        if (!s) revert();
        return abi.decode(ret, (string));
    }

    function symbol(TwoCrypto twoCrypto) internal view returns (string memory) {
        (bool s, bytes memory ret) = twoCrypto.unwrap().staticcall(abi.encodeWithSignature("symbol()"));
        if (!s) revert();
        return abi.decode(ret, (string));
    }

    function decimals(TwoCrypto twoCrypto) internal view returns (uint8) {
        return ERC20(twoCrypto.unwrap()).decimals();
    }

    /// @dev When it fails, it reverts with OOG.
    /// - The case includes the code is empty, the return data is less than 0x20 or the call is unsuccessful.
    function coins(TwoCrypto twoCrypto, uint256 i) internal view returns (address coin) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, i) // Store the `i` argument.
            mstore(0x00, 0xc6610657) // `coins(uint256)`.
            coin :=
                mload(
                    // mload(success ? 0x00 : uint256(-1)) trick for if-else-revert pattern without branching.
                    // If `success` is false, it consumes all gas and reverts with OOG.
                    // In this case 99.99% of the time, the call will succeed.
                    sub(
                        and(
                            // The arguments of `and` are evaluated from right to left.
                            gt(returndatasize(), 0x1f),
                            // We set a small gas limit. It's enough because TwoCryptoNG records the coin address as a immutable variable.
                            staticcall(10000, twoCrypto, 0x1c, 0x24, 0x00, 0x20) // The return value is written to 0x00.
                        ),
                        0x01
                    )
                )
        }
    }

    function balances(TwoCrypto twoCrypto, uint256 i) internal view returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, i) // Store the `i` argument.
            mstore(0x00, 0x4903b0d1) // `balances(uint256)`.
            if iszero(and(gt(returndatasize(), 0x1f), staticcall(gas(), twoCrypto, 0x1c, 0x24, 0x00, 0x20))) {
                revert(0x00, 0x00)
            }
            result := mload(0x00)
        }
    }

    function get_virtual_price(TwoCrypto twoCrypto) internal view returns (uint256) {
        (bool s, bytes memory ret) = twoCrypto.unwrap().staticcall(abi.encodeWithSignature("get_virtual_price()"));
        if (!s) revert();
        return abi.decode(ret, (uint256));
    }

    function lp_price(TwoCrypto twoCrypto) internal view returns (uint256) {
        (bool s, bytes memory ret) = twoCrypto.unwrap().staticcall(abi.encodeWithSignature("lp_price()"));
        if (!s) revert();
        return abi.decode(ret, (uint256));
    }

    /// @notice Returns the oracle price of the coin at index `k` w.r.t the coin
    ///         at index 0.
    /// @dev The oracle is an exponential moving average, with a periodicity
    ///      determined by `self.ma_time`. The aggregated prices are cached state
    ///      prices (dy/dx) calculated AFTER the latest trade.
    /// @return uint256 Price oracle value of kth coin.
    function price_oracle(TwoCrypto twoCrypto) internal view returns (uint256) {
        (bool s, bytes memory ret) = twoCrypto.unwrap().staticcall(abi.encodeWithSignature("price_oracle()"));
        if (!s) revert();
        return abi.decode(ret, (uint256));
    }

    function last_prices(TwoCrypto twoCrypto) internal view returns (uint256) {
        (bool s, bytes memory ret) = twoCrypto.unwrap().staticcall(abi.encodeWithSignature("last_prices()"));
        if (!s) revert();
        return abi.decode(ret, (uint256));
    }

    /// @notice Get amount of coin[j] tokens received for swapping in dx amount of coin[i]
    /// @dev Includes fee.
    /// @param i index of input token. Check pool.coins(i) to get coin address at ith index
    /// @param j index of output token
    /// @param dx amount of input coin[i] tokens
    /// @return dy Exact amount of output j tokens for dx amount of i input tokens.
    function get_dy(TwoCrypto twoCrypto, uint256 i, uint256 j, uint256 dx) internal view returns (uint256 dy) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, dx) // Store the `dx` argument.
            mstore(0x40, j) // Store the `j` argument.
            mstore(0x20, i) // Store the `i` argument.
            mstore(0x00, 0x556d6e9f) // `get_dy(uint256 i, uint256 j, uint256 dx)`.
            if iszero(and(gt(returndatasize(), 0x1f), staticcall(gas(), twoCrypto, 0x1c, 0x64, 0x00, 0x20))) {
                mstore(0x00, 0x8d44e91c) // `TwoCryptoNG_GetDyFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, m) // Restore the free memory pointer.
            dy := mload(0x00)
        }
    }

    /// @notice Get amount of coin[i] tokens to input for swapping out dy amount
    ///         of coin[j]
    /// @dev This is an approximate method, and returns estimates close to the input
    ///      amount. Expensive to call on-chain.
    /// @param i index of input token. Check pool.coins(i) to get coin address at
    ///        ith index
    /// @param j index of output token
    /// @param dy amount of input coin[j] tokens received
    /// @return Approximate amount of input i tokens to get dy amount of j tokens.
    function get_dx(TwoCrypto twoCrypto, uint256 i, uint256 j, uint256 dy) internal view returns (uint256) {
        (bool s, bytes memory ret) = twoCrypto.unwrap().staticcall(
            abi.encodeWithSelector(
                0x37ed3a7a, // get_dx(uint256 i, uint256 j, uint256 dy) external view returns (uint256)
                i,
                j,
                dy
            )
        );
        if (!s) revert TwoCryptoNG_GetDxFailed();
        return abi.decode(ret, (uint256));
    }

    function balanceOf(TwoCrypto twoCrypto, address account) internal view returns (uint256) {
        return SafeTransferLib.balanceOf(twoCrypto.unwrap(), account);
    }

    function totalSupply(TwoCrypto twoCrypto) internal view returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, 0x18160ddd) // `totalSupply()`.
            if iszero(and(gt(returndatasize(), 0x1f), staticcall(gas(), twoCrypto, 0x1c, 0x04, 0x00, 0x20))) {
                revert(0x00, 0x00)
            }
            result := mload(0x00)
        }
    }

    function approve(TwoCrypto twoCrypto, address to, uint256 amount) internal returns (bool) {
        SafeTransferLib.safeApprove(twoCrypto.unwrap(), to, amount);
        return true;
    }

    function add_liquidity(
        TwoCrypto twoCrypto,
        uint256 amount0,
        uint256 amount1,
        uint256 minLiquidity,
        address receiver
    ) internal returns (uint256 liquidity) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)

            mstore(m, 0x0c3e4b54) // `add_liquidity(uint256[2] amounts, uint256 min_mint_amount, address receiver)`.
            mstore(add(m, 0x20), amount0)
            mstore(add(m, 0x40), amount1)
            mstore(add(m, 0x60), minLiquidity)
            mstore(add(m, 0x80), and(shr(96, not(0)), receiver))
            if iszero(and(gt(returndatasize(), 0x1f), call(gas(), twoCrypto, 0, add(m, 0x1c), 0x84, 0x00, 0x20))) {
                mstore(0x00, 0x1a7e9f6b) // `TwoCryptoNG_AddLiquidityFailed()`.
                revert(0x1c, 0x04)
            }
            liquidity := mload(0x00)
        }
    }

    function remove_liquidity(
        TwoCrypto twoCrypto,
        uint256 liquidity,
        uint256 minAmount0,
        uint256 minAmount1,
        address receiver
    ) internal returns (uint256, uint256) {
        (bool s, bytes memory ret) = twoCrypto.unwrap().call(
            abi.encodeWithSelector(
                0x3eb1719f, // remove_liquidity(uint256 _amount, uint256[2] calldata min_amounts, address receiver)
                liquidity,
                [minAmount0, minAmount1],
                receiver
            )
        );
        if (!s) revert TwoCryptoNG_RemoveLiquidityFailed();
        uint256[2] memory amounts = abi.decode(ret, (uint256[2]));
        return (amounts[0], amounts[1]);
    }

    function remove_liquidity(TwoCrypto twoCrypto, uint256 liquidity, uint256 minAmount0, uint256 minAmount1)
        internal
        returns (uint256, uint256)
    {
        (bool s, bytes memory ret) = twoCrypto.unwrap().call(
            abi.encodeWithSelector(
                0x5b36389c, // remove_liquidity(uint256 _amount, uint256[2] calldata min_amounts)
                liquidity,
                [minAmount0, minAmount1]
            )
        );
        if (!s) revert TwoCryptoNG_RemoveLiquidityFailed();
        uint256[2] memory amounts = abi.decode(ret, (uint256[2]));
        return (amounts[0], amounts[1]);
    }

    function remove_liquidity_one_coin(TwoCrypto twoCrypto, uint256 liquidity, uint256 i, uint256 minAmount)
        internal
        returns (uint256 amountOut)
    {
        (bool s, bytes memory ret) = twoCrypto.unwrap().call(
            abi.encodeWithSelector(
                0xf1dc3cc9, // remove_liquidity_one_coin(uint256 token_amount, uint256 i, uint256 min_amount)
                liquidity,
                i,
                minAmount
            )
        );
        if (!s) revert TwoCryptoNG_RemoveLiquidityOneCoinFailed();
        amountOut = abi.decode(ret, (uint256));
    }

    function exchange_received(TwoCrypto twoCrypto, uint256 i, uint256 j, uint256 dx, uint256 minDy)
        internal
        returns (uint256 dy)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)

            mstore(m, 0x29b244bb) // `exchange_received(uint256,uint256,uint256,uint256)`.
            mstore(add(m, 0x20), i)
            mstore(add(m, 0x40), j)
            mstore(add(m, 0x60), dx)
            mstore(add(m, 0x80), minDy)
            if iszero(and(gt(returndatasize(), 0x1f), call(gas(), twoCrypto, 0, add(m, 0x1c), 0x84, 0x00, 0x20))) {
                mstore(0x00, 0xcd3a66e6) // `TwoCryptoNG_ExchangeReceivedFailed()`.
                revert(0x1c, 0x04)
            }
            dy := mload(0x00)
        }
    }

    function exchange_received(TwoCrypto twoCrypto, uint256 i, uint256 j, uint256 dx, uint256 minDy, address receiver)
        internal
        returns (uint256 dy)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)

            mstore(m, 0x767691e7) // `exchange_received(uint256,uint256,uint256,uint256,address)`.
            mstore(add(m, 0x20), i)
            mstore(add(m, 0x40), j)
            mstore(add(m, 0x60), dx)
            mstore(add(m, 0x80), minDy)
            mstore(add(m, 0xa0), and(shr(96, not(0)), receiver))
            if iszero(and(gt(returndatasize(), 0x1f), call(gas(), twoCrypto, 0, add(m, 0x1c), 0xa4, 0x00, 0x20))) {
                mstore(0x00, 0xcd3a66e6) // `TwoCryptoNG_ExchangeReceivedFailed()`.
                revert(0x1c, 0x04)
            }
            dy := mload(0x00)
        }
    }

    function calc_token_amount_in(TwoCrypto twoCrypto, uint256 amount0, uint256 amount1)
        internal
        view
        returns (uint256)
    {
        return calc_token_amount(twoCrypto, amount0, amount1, true);
    }

    function calc_token_amount_out(TwoCrypto twoCrypto, uint256 amount0, uint256 amount1)
        internal
        view
        returns (uint256)
    {
        return calc_token_amount(twoCrypto, amount0, amount1, false);
    }

    function calc_token_amount(TwoCrypto twoCrypto, uint256 amount0, uint256 amount1, bool deposit)
        internal
        view
        returns (uint256)
    {
        (bool s, bytes memory ret) = twoCrypto.unwrap().staticcall(
            abi.encodeWithSelector(
                0xed8e84f3, // calc_token_amount(uint256[2] calldata amounts, bool deposit) external view returns (uint256)
                amount0,
                amount1,
                deposit
            )
        );
        if (!s) revert TwoCryptoNG_CalcTokenAmountFailed();
        return abi.decode(ret, (uint256));
    }

    function calc_withdraw_one_coin(TwoCrypto twoCrypto, uint256 liquidity, uint256 i)
        internal
        view
        returns (uint256)
    {
        (bool s, bytes memory ret) = twoCrypto.unwrap().staticcall(
            abi.encodeWithSelector(
                0x4fb08c5e, // calc_withdraw_one_coin(uint256 token_amount, uint256 i) external view returns (uint256)
                liquidity,
                i
            )
        );
        if (!s) revert TwoCryptoNG_CalcWithdrawOneCoinFailed();
        return abi.decode(ret, (uint256));
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {LibBytes} from "solady/src/utils/LibBytes.sol";
import {SafeCastLib} from "solady/src/utils/SafeCastLib.sol";

library LibBlueprint {
    using SafeCastLib for uint256;

    error DeploymentFailed();
    error InvalidBlueprint();

    /// @dev Deploy contract from blueprint using CREATE
    /// @param _blueprint Address of the blueprint contract
    /// @return The address of the deployed contract
    function create(address _blueprint) internal returns (address) {
        return _create(_blueprint, "");
    }

    /// @dev Return address(0) if deployment fails
    function tryCreate(address _blueprint, bytes memory args) internal returns (address deployed) {
        bytes memory initcode = extractCreationCode(_blueprint);
        // Combine initcode with constructor arguments
        bytes memory deployCode = LibBytes.concat(initcode, args);

        // Deploy the contract
        assembly {
            deployed := create(0, add(deployCode, 32), mload(deployCode))
        }
    }

    /// @dev Deploy contract from blueprint using CREATE with constructor arguments
    /// @param _blueprint Address of the blueprint contract
    /// @param args Constructor arguments
    /// @return The address of the deployed contract
    function create(address _blueprint, bytes memory args) internal returns (address) {
        return _create(_blueprint, args);
    }

    /// @dev Deploy contract from blueprint using CREATE2
    /// @param _blueprint Address of the blueprint contract
    /// @param salt Unique salt for deterministic addressing
    /// @return The address of the deployed contract
    function create2(address _blueprint, bytes32 salt) internal returns (address) {
        return _create2(_blueprint, "", salt);
    }

    /// @dev Deploy contract from blueprint using CREATE2 with constructor arguments
    /// @param _blueprint Address of the blueprint contract
    /// @param args Constructor arguments
    /// @param salt Unique salt for deterministic addressing
    /// @return The address of the deployed contract
    function create2(address _blueprint, bytes memory args, bytes32 salt) internal returns (address) {
        return _create2(_blueprint, args, salt);
    }

    /// @dev Encode bytecode into blueprint format
    /// @param initcode The original contract bytecode
    /// @return The encoded blueprint bytecode
    function blueprint(bytes memory initcode) internal pure returns (bytes memory) {
        bytes memory blueprint_bytecode = bytes.concat(
            hex"fe", // EIP_5202_EXECUTION_HALT_BYTE
            hex"71", // EIP_5202_BLUEPRINT_IDENTIFIER_BYTE
            hex"00", // EIP_5202_VERSION_BYTE
            initcode
        );
        bytes2 len = bytes2(blueprint_bytecode.length.toUint16());

        bytes memory deployBytecode = bytes.concat(
            hex"61", // DEPLOY_PREAMBLE_INITIAL_BYTE
            len, // DEPLOY_PREAMBLE_BYTE_LENGTH
            hex"3d81600a3d39f3", // DEPLOY_PREABLE_POST_LENGTH_BYTES
            blueprint_bytecode
        );

        return deployBytecode;
    }

    /// @dev Deploy blueprint contract
    /// @param initcode The original contract bytecode
    /// @return deployed The address of the deployed blueprint contract
    function deployBlueprint(bytes memory initcode) internal returns (address deployed) {
        bytes memory deployBytecode = blueprint(initcode);

        assembly {
            deployed := create(0, add(deployBytecode, 0x20), mload(deployBytecode))
        }

        if (deployed == address(0)) revert DeploymentFailed();
    }

    // Internal helper functions
    function _create(address _blueprint, bytes memory args) private returns (address deployed) {
        bytes memory initcode = extractCreationCode(_blueprint);
        // Combine initcode with constructor arguments
        bytes memory deployCode = LibBytes.concat(initcode, args);

        // Deploy the contract
        assembly {
            deployed := create(0, add(deployCode, 32), mload(deployCode))
        }

        if (deployed == address(0)) revert DeploymentFailed();
    }

    function _create2(address _blueprint, bytes memory args, bytes32 salt) private returns (address deployed) {
        bytes memory initcode = extractCreationCode(_blueprint);
        // Combine initcode with constructor arguments
        bytes memory deployCode = LibBytes.concat(initcode, args);

        // Deploy the contract using CREATE2
        assembly {
            deployed := create2(0, add(deployCode, 32), mload(deployCode), salt)
        }

        if (deployed == address(0)) revert DeploymentFailed();
    }

    function extractCreationCode(address _blueprint) private view returns (bytes memory initcode) {
        uint256 size;
        uint256 offset = 3; // Skip first 3 bytes

        assembly {
            size := extcodesize(_blueprint)
        }

        // Check if there's any code after the offset
        if (size <= offset) {
            revert InvalidBlueprint();
        }

        // Extract the initcode
        uint256 initcodeSize = size - offset;
        initcode = new bytes(initcodeSize);

        assembly {
            extcodecopy(_blueprint, add(initcode, 32), offset, initcodeSize)
        }
    }

    function computeCreate2Address(bytes32 salt, address _blueprint, bytes memory args)
        internal
        view
        returns (address)
    {
        bytes32 bytecodeHash = keccak256(LibBytes.concat(extractCreationCode(_blueprint), args));
        return computeCreeate2Address(salt, bytecodeHash, address(this));
    }

    function computeCreeate2Address(bytes32 salt, bytes32 bytecodeHash, address deployer)
        internal
        pure
        returns (address addr)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40) // Get free memory pointer

            mstore(add(ptr, 0x40), bytecodeHash)
            mstore(add(ptr, 0x20), salt)
            mstore(ptr, deployer) // Right-aligned with 12 preceding garbage bytes
            let start := add(ptr, 0x0b) // The hashed data starts at the final garbage byte which we will set to 0xff
            mstore8(start, 0xff)
            addr := keccak256(start, 85)
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solady/src/utils/SafeCastLib.sol";
import {ERC20} from "solady/src/tokens/ERC20.sol";

import {PrincipalToken} from "../tokens/PrincipalToken.sol";
import {LibTwoCryptoNG} from "../utils/LibTwoCryptoNG.sol";
import {VaultInfoResolver} from "../modules/resolvers/VaultInfoResolver.sol";

import "../Types.sol";
import "../Constants.sol" as Constants;
import {Errors} from "../Errors.sol";

library ConversionLib {
    using LibTwoCryptoNG for TwoCrypto;
    using SafeCastLib for uint256;
    using SafeCastLib for int256;

    uint256 constant WAD = 1e18;

    /// @dev Convert shares to assets using scale
    /// @param shares Amount of shares to convert
    /// @param scale Scale factor (1 asset = scale * shares / WAD)
    /// @return Amount of assets
    function convertSharesToAssets(uint256 shares, uint256 scale) internal pure returns (uint256) {
        return (shares * scale) / WAD;
    }

    /// @dev Convert assets to USD using price
    /// @param assets Amount of assets to convert
    /// @param priceUSDInWad Price in USD with 18 decimals
    /// @return Amount in USD with 18 decimals
    function convertAssetsToUSD(uint256 assets, uint256 priceUSDInWad) internal pure returns (uint256) {
        return (assets * priceUSDInWad) / WAD;
    }

    /// @dev Convert price in asset units (wei) to implied APY
    /// @dev Zero div error on timeToExpiry == 0
    /// @dev Returns 0 if the `priceInAsset` == 0
    /// @param priceInAsset Price in asset (1e18)
    /// @param timeToExpiry Time until expiry in seconds
    /// @return impliedAPY Implied interest rate with 18 decimals (5% = 0.05e18)
    function convertToImpliedAPY(uint256 priceInAsset, uint256 timeToExpiry) internal pure returns (int256) {
        // Formula:
        //          1
        //          ─
        //          t
        //      ⎛FV⎞
        // i  = ⎜──⎟  - 1
        //  d   ⎝PV⎠

        // FV       1
        // ── = ─────────
        // PV   p ⋅ scale
        //      ─────────
        //        1e18
        // where `t` is the time to expiry in years and `p` is the price of the principal token in shares
        // `i_d` is the implied interest rate.
        // PV - Present value: Market price of the principal token in underlying token.
        // FV - Future value: Redemption value of the principal token in underlying token.
        //
        // For example, if a series of cDAI Principal Tokens matures in three months and has a price of 0.972 DAI, the implied yield to maturity is 12.03%.
        //            1
        //         ──────
        //          0.25
        //      ⎛  1  ⎞
        // i  = ⎜─────⎟  - 1
        //  d   ⎝0.972⎠
        if (priceInAsset == 0) return 0;
        uint256 fvDivPv = FixedPointMathLib.divWad(WAD, priceInAsset);
        uint256 oneDivTimeToExpiry = 365 days * WAD / timeToExpiry;
        return FixedPointMathLib.powWad(fvDivPv.toInt256(), oneDivTimeToExpiry.toInt256()) - int256(WAD);
    }

    /// @dev Convert price in asset units (wei) to implied APY
    /// @dev Returns 0 if the PT is expired
    function convertToImpliedAPY(address pt, uint256 priceInAsset) internal view returns (int256) {
        uint256 expiry = PrincipalToken(pt).maturity();
        if (expiry <= block.timestamp) return 0;
        return convertToImpliedAPY(priceInAsset, expiry - block.timestamp);
    }

    function convertToPriceInAsset(int256 impliedAPY, uint256 timeToExpiry)
        internal
        pure
        returns (uint256 priceInAsset)
    {
        // Formula:
        // p = [(1 + i) ^ -t] * 1e18 / scale
        // where `i` is the implied APY and `t` is the time to expiry in years
        uint256 timeToExpiryInYears = timeToExpiry * WAD / 365 days;
        priceInAsset = FixedPointMathLib.powWad(int256(WAD) + impliedAPY, -timeToExpiryInYears.toInt256()).toUint256();
    }

    /// @notice Price in 1e18
    function getYtPriceInUnderlying(TwoCrypto twoCrypto) internal view returns (uint256) {
        // The spot exchange rate between YBT and YT is evaluated using the tokenization equation without fees.
        // Let's say that we have a PT-pufETH/pufETH pool.
        // PT Price + YT Price = BaseAsset Price (ETH)
        // => 0.9 + 0.1 = 1 ETH (PT-pufETH/ETH = 0.9)
        // => 0.9 / 1.11 * 1.11 + 0.1 / 1.11 * 1.11 = 1 (pufETH/ETH = 1.11)
        // => 0.81 * 1.11 + 0.09 * 1.11 = 1

        // Symbolically:
        // => [PT Price in pufETH] * scale + x * scale = 1 where x is the YT price in pufETH
        // => x = (1 - [PT Price in pufETH] * scale) / scale
        // => x = 1/scale - [PT price in pufETH]

        // 1/x = scale / (1 - [PT Price in pufETH] * scale)

        PrincipalToken principalToken = PrincipalToken(twoCrypto.coins(Constants.PT_INDEX));

        uint256 ptPrinceInUnderlying = twoCrypto.last_prices();
        VaultInfoResolver resolver = principalToken.i_resolver();
        uint256 scale = resolver.scale();
        uint256 scaleUnit = 10 ** (18 + resolver.assetDecimals() - resolver.decimals());

        int256 ytPrice = int256(WAD * scaleUnit / scale) - int256(ptPrinceInUnderlying);
        if (ytPrice <= 0) revert Errors.ConversionLib_NegativeYtPrice(); // PT price is too high or scale is too low
        return uint256(ytPrice);
    }

    enum SwapKind {
        PT,
        YT
    }

    /// @notice Calculate the execution (effective) price based on the change of reserves before and after the swap.
    /// @notice Effective price is the price where actually the swap is executed.
    /// @param twoCrypto TwoCrypto instance
    /// @param principal Amount of PT in/out if kind=PT, amount of YT if kind=YT in/out
    /// @param shares shares in/out
    /// @param kind Swap kind
    /// @return priceWei Price of PT in asset if kind=PT, price of YT in asset if kind=YT.
    /// @notice If kind=PT, the return value can be greater than 1e18 which means that the PT is not discounted at all.
    /// @notice If kind=YT, the return value is in range [0, 1e18] if the YT price can be negative, returns 0.
    function calculateEffectivePtPrice(TwoCrypto twoCrypto, uint256 principal, uint256 shares, SwapKind kind)
        internal
        view
        returns (uint256 priceWei)
    {
        address pt = twoCrypto.coins(Constants.PT_INDEX);

        // Formula:
        // PT <-> any token: ptPrice = assets / ptAmount
        // YT <-> any token: ptPrice = 1 - assets / ytAmount

        uint256 assets = shares * PrincipalToken(pt).i_resolver().scale() / WAD; // 10**u * 10**(18 + b - u) / 10**18

        priceWei = assets * WAD / principal; // 10**b / 10**b * 10**18 = 10**18
        if (kind == SwapKind.YT) {
            priceWei = FixedPointMathLib.zeroFloorSub(WAD, priceWei); // max(0, WAD - priceWei)
        }
    }

    /// @notice Calculate the effective price given the delta of principal and amount of token in/out.
    /// @dev Price Impact formula:
    ///
    /// `priceImpact = (executionPrice - spotPrice) / spotPrice`
    ///
    /// For selling PT, prices are PT's prices measured in ETH. For buying PT, prices are ETH's prices measured in PT.
    ///
    /// Selling PT/YT
    ///
    /// Input: PT
    /// Output: tokenA (e.g., WBTC...)
    ///
    /// Spot price = spotPtPriceInUSD / tokenAPriceInUSD
    /// (In real life, a direct quote for token A and PT is not always available.)
    ///
    /// Execution price = outputTokenA / inputPT
    ///
    /// Example:
    /// - Spot PT price = $0.5
    /// - Token A price = $100
    /// - Input: 10 PT
    /// - Output: 0.05 token A
    /// - Spot price = 0.5 / 100 = 0.005
    /// - Execution price = 0.05 / 10 = 0.005
    ///
    /// ---
    ///
    /// Buying PT/YT follows a similar process.
    ///
    /// Input: tokenA
    /// Output: PT
    ///
    /// Spot price = tokenAPriceInUSD / spotPtPriceInUSD
    /// (In real life, a direct quote for token A and PT is not always available.)
    ///
    /// Execution price = outputPT / inputTokenA
    ///
    /// Example:
    /// - Spot PT price = $0.5
    /// - Token A price = $100
    /// - Input: 0.05 token A
    /// - Output: 10 PT
    /// - Spot price = 100 / 0.5 = 200
    /// - Execution price = 10 / 0.05 = 200
    function calculateEffectivePrice(Token tokenIn, Token tokenOut, uint256 amountIn, uint256 amountOut)
        internal
        view
        returns (uint256)
    {
        uint256 decimalsIn = tokenIn.isNative() ? 18 : tokenIn.erc20().decimals();
        uint256 decimalsOut = tokenOut.isNative() ? 18 : tokenOut.erc20().decimals();
        return amountOut * 10 ** (18 + decimalsIn - decimalsOut) / amountIn;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "./types/Token.sol" as TokenType;
import "./types/FeePcts.sol" as FeePctsType;
import "./types/ApproxValue.sol" as ApproxValueType;
import "./types/TwoCrypto.sol" as TwoCryptoType;
import "./types/ModuleIndex.sol" as ModuleIndexType;

/// The `FeePcts` type is 256 bits long, and packs the following:
///
/// ```
///   | [uint176]: reserved for future use
///   |                                           | [uint16]: postSettlementFeePct
///   |                                           ↓   | [uint16]: redemptionFeePct
///   |                                           ↓   ↓   | [uint16]: performanceFeePct
///   |                                           ↓   ↓   ↓   | [uint16]: issuanceFeePct
///   |                                           ↓   ↓   ↓   ↓   ↓ [uint16]: splitPctBps
/// 0x00000000000000000000000000000000000000000000AAAABBBBCCCCDDDDEEEE
/// ```
type FeePcts is uint256;

using {FeePctsType.unwrap} for FeePcts global;

/// The `ApproxValue` type represents an approximate value from off-chain sources or `Quoter` contract.
type ApproxValue is uint256;

using {ApproxValueType.unwrap} for ApproxValue global;

/// The `Token` type represents an ERC20 token address or the native token address (0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE).
/// Zap contracts use this type to represent tokens in the system.
/// It's main purpose is to provide a type-safe way to represent tokens in the system.
/// ```
/// function supply(address token, address receiver) public payable {
///     SafeTransferLib.safeTransferFromAll(token, receiver); // ❌ Compiler can't find bug.
/// }
///
/// function supply(Token token, address receiver) public payable {
///     SafeTransferLib.safeTransferFromAll(token, receiver); // 👌 Compiler can notice something wrong.
/// }
/// ```
type Token is address;

using {TokenType.unwrap} for Token global;
using {TokenType.erc20} for Token global;
using {TokenType.isNative} for Token global;
using {TokenType.isNotNative} for Token global;
using {TokenType.eq} for Token global;

/// The `TwoCrypto` type represents a Curve finance twocrypto-ng pool (LP token) address not old twocrypto implementation.
type TwoCrypto is address;

using {TwoCryptoType.unwrap} for TwoCrypto global;

struct TwoCryptoNGParams {
    uint256 A;
    uint256 gamma;
    uint256 mid_fee;
    uint256 out_fee;
    uint256 fee_gamma;
    uint256 allowed_extra_profit;
    uint256 adjustment_step;
    uint256 ma_time;
    uint256 initial_price;
}

/// @dev Do not change the order of the enum
// Do not prepend new fee parameters to the enum, as it will break the compatibility with the existing deployments
enum FeeParameters {
    FEE_SPLIT_RATIO, // The fee % going to curator. The rest goes to Napier treasury
    ISSUANCE_FEE, // The fee % charged on issuance of PT/YT
    PERFORMANCE_FEE, // The fee % charged on the interest made by YT
    REDEMPTION_FEE, // The fee % charged on redemption of PT/YT
    POST_SETTLEMENT_FEE // The fee % charged on performance fee after settlement

}

/// @notice The `TokenReward` struct represents a additional reward token like COMP, AAVE, etc and the amount of reward.
struct TokenReward {
    address token;
    uint256 amount;
}

using {ModuleIndexType.unwrap} for ModuleIndex global;
using {ModuleIndexType.isSupportedByFactory} for ModuleIndex global;
using {ModuleIndexType.eq as ==} for ModuleIndex global;

/// The `ModuleIndex` type represents a unique index for each module in the system.
type ModuleIndex is uint256;

ModuleIndex constant FEE_MODULE_INDEX = ModuleIndex.wrap(0);
ModuleIndex constant REWARD_PROXY_MODULE_INDEX = ModuleIndex.wrap(1);
ModuleIndex constant VERIFIER_MODULE_INDEX = ModuleIndex.wrap(2);
uint256 constant MAX_MODULES = 3;

/// @dev Do not change the order of the enum
/// @dev Verification status codes in the system for the `VerifierModule`.
enum VerificationStatus {
    InvalidArguments, // Unexpected error
    Success,
    SupplyMoreThanMax,
    Restricted,
    InvalidSelector
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

uint256 constant BASIS_POINTS = 10_000;
uint256 constant WAD = 1e18;
address constant NATIVE_ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

// Roles
uint256 constant FEE_MANAGER_ROLE = 1 << 0;
uint256 constant FEE_COLLECTOR_ROLE = 1 << 1;
uint256 constant DEV_ROLE = 1 << 2;
uint256 constant PAUSER_ROLE = 1 << 3;
uint256 constant GOVERNANCE_ROLE = 1 << 4;
uint256 constant CONNECTOR_REGISTRY_ROLE = 1 << 5;

// TwoCrypto
uint256 constant TARGET_INDEX = 0;
uint256 constant PT_INDEX = 1;

// Currency
address constant WETH_ETHEREUM_MAINNET = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

// Default fee split ratio (100% to Curator)
uint16 constant DEFAULT_SPLIT_RATIO_BPS = uint16(BASIS_POINTS);

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Read and write to persistent storage at a fraction of the cost.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/SSTORE2.sol)
/// @author Saw-mon-and-Natalie (https://github.com/Saw-mon-and-Natalie)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SSTORE2.sol)
/// @author Modified from 0xSequence (https://github.com/0xSequence/sstore2/blob/master/contracts/SSTORE2.sol)
/// @author Modified from SSTORE3 (https://github.com/Philogy/sstore3)
library SSTORE2 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The proxy initialization code.
    uint256 private constant _CREATE3_PROXY_INITCODE = 0x67363d3d37363d34f03d5260086018f3;

    /// @dev Hash of the `_CREATE3_PROXY_INITCODE`.
    /// Equivalent to `keccak256(abi.encodePacked(hex"67363d3d37363d34f03d5260086018f3"))`.
    bytes32 internal constant CREATE3_PROXY_INITCODE_HASH =
        0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Unable to deploy the storage contract.
    error DeploymentFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         WRITE LOGIC                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Writes `data` into the bytecode of a storage contract and returns its address.
    function write(bytes memory data) internal returns (address pointer) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data) // Let `l` be `n + 1`. +1 as we prefix a STOP opcode.
            /**
             * ---------------------------------------------------+
             * Opcode | Mnemonic       | Stack     | Memory       |
             * ---------------------------------------------------|
             * 61 l   | PUSH2 l        | l         |              |
             * 80     | DUP1           | l l       |              |
             * 60 0xa | PUSH1 0xa      | 0xa l l   |              |
             * 3D     | RETURNDATASIZE | 0 0xa l l |              |
             * 39     | CODECOPY       | l         | [0..l): code |
             * 3D     | RETURNDATASIZE | 0 l       | [0..l): code |
             * F3     | RETURN         |           | [0..l): code |
             * 00     | STOP           |           |              |
             * ---------------------------------------------------+
             * @dev Prefix the bytecode with a STOP opcode to ensure it cannot be called.
             * Also PUSH2 is used since max contract size cap is 24,576 bytes which is less than 2 ** 16.
             */
            // Do a out-of-gas revert if `n + 1` is more than 2 bytes.
            mstore(add(data, gt(n, 0xfffe)), add(0xfe61000180600a3d393df300, shl(0x40, n)))
            // Deploy a new contract with the generated creation code.
            pointer := create(0, add(data, 0x15), add(n, 0xb))
            if iszero(pointer) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(data, n) // Restore the length of `data`.
        }
    }

    /// @dev Writes `data` into the bytecode of a storage contract with `salt`
    /// and returns its normal CREATE2 deterministic address.
    function writeCounterfactual(bytes memory data, bytes32 salt)
        internal
        returns (address pointer)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data)
            // Do a out-of-gas revert if `n + 1` is more than 2 bytes.
            mstore(add(data, gt(n, 0xfffe)), add(0xfe61000180600a3d393df300, shl(0x40, n)))
            // Deploy a new contract with the generated creation code.
            pointer := create2(0, add(data, 0x15), add(n, 0xb), salt)
            if iszero(pointer) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(data, n) // Restore the length of `data`.
        }
    }

    /// @dev Writes `data` into the bytecode of a storage contract and returns its address.
    /// This uses the so-called "CREATE3" workflow,
    /// which means that `pointer` is agnostic to `data, and only depends on `salt`.
    function writeDeterministic(bytes memory data, bytes32 salt)
        internal
        returns (address pointer)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data)
            mstore(0x00, _CREATE3_PROXY_INITCODE) // Store the `_PROXY_INITCODE`.
            let proxy := create2(0, 0x10, 0x10, salt)
            if iszero(proxy) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x14, proxy) // Store the proxy's address.
            // 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ proxy ++ 0x01).
            // 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex).
            mstore(0x00, 0xd694)
            mstore8(0x34, 0x01) // Nonce of the proxy contract (1).
            pointer := keccak256(0x1e, 0x17)

            // Do a out-of-gas revert if `n + 1` is more than 2 bytes.
            mstore(add(data, gt(n, 0xfffe)), add(0xfe61000180600a3d393df300, shl(0x40, n)))
            if iszero(
                mul( // The arguments of `mul` are evaluated last to first.
                    extcodesize(pointer),
                    call(gas(), proxy, 0, add(data, 0x15), add(n, 0xb), codesize(), 0x00)
                )
            ) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(data, n) // Restore the length of `data`.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    ADDRESS CALCULATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the initialization code hash of the storage contract for `data`.
    /// Used for mining vanity addresses with create2crunch.
    function initCodeHash(bytes memory data) internal pure returns (bytes32 hash) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data)
            // Do a out-of-gas revert if `n + 1` is more than 2 bytes.
            returndatacopy(returndatasize(), returndatasize(), gt(n, 0xfffe))
            mstore(data, add(0x61000180600a3d393df300, shl(0x40, n)))
            hash := keccak256(add(data, 0x15), add(n, 0xb))
            mstore(data, n) // Restore the length of `data`.
        }
    }

    /// @dev Equivalent to `predictCounterfactualAddress(data, salt, address(this))`
    function predictCounterfactualAddress(bytes memory data, bytes32 salt)
        internal
        view
        returns (address pointer)
    {
        pointer = predictCounterfactualAddress(data, salt, address(this));
    }

    /// @dev Returns the CREATE2 address of the storage contract for `data`
    /// deployed with `salt` by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictCounterfactualAddress(bytes memory data, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 hash = initCodeHash(data);
        /// @solidity memory-safe-assembly
        assembly {
            // Compute and store the bytecode hash.
            mstore8(0x00, 0xff) // Write the prefix.
            mstore(0x35, hash)
            mstore(0x01, shl(96, deployer))
            mstore(0x15, salt)
            predicted := keccak256(0x00, 0x55)
            // Restore the part of the free memory pointer that has been overwritten.
            mstore(0x35, 0)
        }
    }

    /// @dev Equivalent to `predictDeterministicAddress(salt, address(this))`.
    function predictDeterministicAddress(bytes32 salt) internal view returns (address pointer) {
        pointer = predictDeterministicAddress(salt, address(this));
    }

    /// @dev Returns the "CREATE3" deterministic address for `salt` with `deployer`.
    function predictDeterministicAddress(bytes32 salt, address deployer)
        internal
        pure
        returns (address pointer)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x00, deployer) // Store `deployer`.
            mstore8(0x0b, 0xff) // Store the prefix.
            mstore(0x20, salt) // Store the salt.
            mstore(0x40, CREATE3_PROXY_INITCODE_HASH) // Store the bytecode hash.

            mstore(0x14, keccak256(0x0b, 0x55)) // Store the proxy's address.
            mstore(0x40, m) // Restore the free memory pointer.
            // 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ proxy ++ 0x01).
            // 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex).
            mstore(0x00, 0xd694)
            mstore8(0x34, 0x01) // Nonce of the proxy contract (1).
            pointer := keccak256(0x1e, 0x17)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         READ LOGIC                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Equivalent to `read(pointer, 0, 2 ** 256 - 1)`.
    function read(address pointer) internal view returns (bytes memory data) {
        /// @solidity memory-safe-assembly
        assembly {
            data := mload(0x40)
            let n := and(0xffffffffff, sub(extcodesize(pointer), 0x01))
            extcodecopy(pointer, add(data, 0x1f), 0x00, add(n, 0x21))
            mstore(data, n) // Store the length.
            mstore(0x40, add(n, add(data, 0x40))) // Allocate memory.
        }
    }

    /// @dev Equivalent to `read(pointer, start, 2 ** 256 - 1)`.
    function read(address pointer, uint256 start) internal view returns (bytes memory data) {
        /// @solidity memory-safe-assembly
        assembly {
            data := mload(0x40)
            let n := and(0xffffffffff, sub(extcodesize(pointer), 0x01))
            let l := sub(n, and(0xffffff, mul(lt(start, n), start)))
            extcodecopy(pointer, add(data, 0x1f), start, add(l, 0x21))
            mstore(data, mul(sub(n, start), lt(start, n))) // Store the length.
            mstore(0x40, add(data, add(0x40, mload(data)))) // Allocate memory.
        }
    }

    /// @dev Returns a slice of the data on `pointer` from `start` to `end`.
    /// `start` and `end` will be clamped to the range `[0, args.length]`.
    /// The `pointer` MUST be deployed via the SSTORE2 write functions.
    /// Otherwise, the behavior is undefined.
    /// Out-of-gas reverts if `pointer` does not have any code.
    function read(address pointer, uint256 start, uint256 end)
        internal
        view
        returns (bytes memory data)
    {
        /// @solidity memory-safe-assembly
        assembly {
            data := mload(0x40)
            if iszero(lt(end, 0xffff)) { end := 0xffff }
            let d := mul(sub(end, start), lt(start, end))
            extcodecopy(pointer, add(data, 0x1f), start, add(d, 0x01))
            if iszero(and(0xff, mload(add(data, d)))) {
                let n := sub(extcodesize(pointer), 0x01)
                returndatacopy(returndatasize(), returndatasize(), shr(40, n))
                d := mul(gt(n, start), sub(d, mul(gt(end, n), sub(end, n))))
            }
            mstore(data, d) // Store the length.
            mstore(add(add(data, 0x20), d), 0) // Zeroize the slot after the bytes.
            mstore(0x40, add(add(data, 0x40), d)) // Allocate memory.
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Minimal proxy library.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibClone.sol)
/// @author Minimal proxy by 0age (https://github.com/0age)
/// @author Clones with immutable args by wighawag, zefram.eth, Saw-mon & Natalie
/// (https://github.com/Saw-mon-and-Natalie/clones-with-immutable-args)
/// @author Minimal ERC1967 proxy by jtriley-eth (https://github.com/jtriley-eth/minimum-viable-proxy)
///
/// @dev Minimal proxy:
/// Although the sw0nt pattern saves 5 gas over the ERC1167 pattern during runtime,
/// it is not supported out-of-the-box on Etherscan. Hence, we choose to use the 0age pattern,
/// which saves 4 gas over the ERC1167 pattern during runtime, and has the smallest bytecode.
/// - Automatically verified on Etherscan.
///
/// @dev Minimal proxy (PUSH0 variant):
/// This is a new minimal proxy that uses the PUSH0 opcode introduced during Shanghai.
/// It is optimized first for minimal runtime gas, then for minimal bytecode.
/// The PUSH0 clone functions are intentionally postfixed with a jarring "_PUSH0" as
/// many EVM chains may not support the PUSH0 opcode in the early months after Shanghai.
/// Please use with caution.
/// - Automatically verified on Etherscan.
///
/// @dev Clones with immutable args (CWIA):
/// The implementation of CWIA here is does NOT append the immutable args into the calldata
/// passed into delegatecall. It is simply an ERC1167 minimal proxy with the immutable arguments
/// appended to the back of the runtime bytecode.
/// - Uses the identity precompile (0x4) to copy args during deployment.
///
/// @dev Minimal ERC1967 proxy:
/// An minimal ERC1967 proxy, intended to be upgraded with UUPS.
/// This is NOT the same as ERC1967Factory's transparent proxy, which includes admin logic.
/// - Automatically verified on Etherscan.
///
/// @dev Minimal ERC1967 proxy with immutable args:
/// - Uses the identity precompile (0x4) to copy args during deployment.
/// - Automatically verified on Etherscan.
///
/// @dev ERC1967I proxy:
/// An variant of the minimal ERC1967 proxy, with a special code path that activates
/// if `calldatasize() == 1`. This code path skips the delegatecall and directly returns the
/// `implementation` address. The returned implementation is guaranteed to be valid if the
/// keccak256 of the proxy's code is equal to `ERC1967I_CODE_HASH`.
///
/// @dev ERC1967I proxy with immutable args:
/// An variant of the minimal ERC1967 proxy, with a special code path that activates
/// if `calldatasize() == 1`. This code path skips the delegatecall and directly returns the
/// - Uses the identity precompile (0x4) to copy args during deployment.
///
/// @dev Minimal ERC1967 beacon proxy:
/// A minimal beacon proxy, intended to be upgraded with an upgradable beacon.
/// - Automatically verified on Etherscan.
///
/// @dev Minimal ERC1967 beacon proxy with immutable args:
/// - Uses the identity precompile (0x4) to copy args during deployment.
/// - Automatically verified on Etherscan.
///
/// @dev ERC1967I beacon proxy:
/// An variant of the minimal ERC1967 beacon proxy, with a special code path that activates
/// if `calldatasize() == 1`. This code path skips the delegatecall and directly returns the
/// `implementation` address. The returned implementation is guaranteed to be valid if the
/// keccak256 of the proxy's code is equal to `ERC1967I_CODE_HASH`.
///
/// @dev ERC1967I proxy with immutable args:
/// An variant of the minimal ERC1967 beacon proxy, with a special code path that activates
/// if `calldatasize() == 1`. This code path skips the delegatecall and directly returns the
/// - Uses the identity precompile (0x4) to copy args during deployment.
library LibClone {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The keccak256 of deployed code for the clone proxy,
    /// with the implementation set to `address(0)`.
    bytes32 internal constant CLONE_CODE_HASH =
        0x48db2cfdb2853fce0b464f1f93a1996469459df3ab6c812106074c4106a1eb1f;

    /// @dev The keccak256 of deployed code for the PUSH0 proxy,
    /// with the implementation set to `address(0)`.
    bytes32 internal constant PUSH0_CLONE_CODE_HASH =
        0x67bc6bde1b84d66e267c718ba44cf3928a615d29885537955cb43d44b3e789dc;

    /// @dev The keccak256 of deployed code for the ERC-1167 CWIA proxy,
    /// with the implementation set to `address(0)`.
    bytes32 internal constant CWIA_CODE_HASH =
        0x3cf92464268225a4513da40a34d967354684c32cd0edd67b5f668dfe3550e940;

    /// @dev The keccak256 of the deployed code for the ERC1967 proxy.
    bytes32 internal constant ERC1967_CODE_HASH =
        0xaaa52c8cc8a0e3fd27ce756cc6b4e70c51423e9b597b11f32d3e49f8b1fc890d;

    /// @dev The keccak256 of the deployed code for the ERC1967I proxy.
    bytes32 internal constant ERC1967I_CODE_HASH =
        0xce700223c0d4cea4583409accfc45adac4a093b3519998a9cbbe1504dadba6f7;

    /// @dev The keccak256 of the deployed code for the ERC1967 beacon proxy.
    bytes32 internal constant ERC1967_BEACON_PROXY_CODE_HASH =
        0x14044459af17bc4f0f5aa2f658cb692add77d1302c29fe2aebab005eea9d1162;

    /// @dev The keccak256 of the deployed code for the ERC1967 beacon proxy.
    bytes32 internal constant ERC1967I_BEACON_PROXY_CODE_HASH =
        0xf8c46d2793d5aa984eb827aeaba4b63aedcab80119212fce827309788735519a;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Unable to deploy the clone.
    error DeploymentFailed();

    /// @dev The salt must start with either the zero address or `by`.
    error SaltDoesNotStartWith();

    /// @dev The ETH transfer has failed.
    error ETHTransferFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  MINIMAL PROXY OPERATIONS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Deploys a clone of `implementation`.
    function clone(address implementation) internal returns (address instance) {
        instance = clone(0, implementation);
    }

    /// @dev Deploys a clone of `implementation`.
    /// Deposits `value` ETH during deployment.
    function clone(uint256 value, address implementation) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            /**
             * --------------------------------------------------------------------------+
             * CREATION (9 bytes)                                                        |
             * --------------------------------------------------------------------------|
             * Opcode     | Mnemonic          | Stack     | Memory                       |
             * --------------------------------------------------------------------------|
             * 60 runSize | PUSH1 runSize     | r         |                              |
             * 3d         | RETURNDATASIZE    | 0 r       |                              |
             * 81         | DUP2              | r 0 r     |                              |
             * 60 offset  | PUSH1 offset      | o r 0 r   |                              |
             * 3d         | RETURNDATASIZE    | 0 o r 0 r |                              |
             * 39         | CODECOPY          | 0 r       | [0..runSize): runtime code   |
             * f3         | RETURN            |           | [0..runSize): runtime code   |
             * --------------------------------------------------------------------------|
             * RUNTIME (44 bytes)                                                        |
             * --------------------------------------------------------------------------|
             * Opcode  | Mnemonic       | Stack                  | Memory                |
             * --------------------------------------------------------------------------|
             *                                                                           |
             * ::: keep some values in stack ::::::::::::::::::::::::::::::::::::::::::: |
             * 3d      | RETURNDATASIZE | 0                      |                       |
             * 3d      | RETURNDATASIZE | 0 0                    |                       |
             * 3d      | RETURNDATASIZE | 0 0 0                  |                       |
             * 3d      | RETURNDATASIZE | 0 0 0 0                |                       |
             *                                                                           |
             * ::: copy calldata to memory ::::::::::::::::::::::::::::::::::::::::::::: |
             * 36      | CALLDATASIZE   | cds 0 0 0 0            |                       |
             * 3d      | RETURNDATASIZE | 0 cds 0 0 0 0          |                       |
             * 3d      | RETURNDATASIZE | 0 0 cds 0 0 0 0        |                       |
             * 37      | CALLDATACOPY   | 0 0 0 0                | [0..cds): calldata    |
             *                                                                           |
             * ::: delegate call to the implementation contract :::::::::::::::::::::::: |
             * 36      | CALLDATASIZE   | cds 0 0 0 0            | [0..cds): calldata    |
             * 3d      | RETURNDATASIZE | 0 cds 0 0 0 0          | [0..cds): calldata    |
             * 73 addr | PUSH20 addr    | addr 0 cds 0 0 0 0     | [0..cds): calldata    |
             * 5a      | GAS            | gas addr 0 cds 0 0 0 0 | [0..cds): calldata    |
             * f4      | DELEGATECALL   | success 0 0            | [0..cds): calldata    |
             *                                                                           |
             * ::: copy return data to memory :::::::::::::::::::::::::::::::::::::::::: |
             * 3d      | RETURNDATASIZE | rds success 0 0        | [0..cds): calldata    |
             * 3d      | RETURNDATASIZE | rds rds success 0 0    | [0..cds): calldata    |
             * 93      | SWAP4          | 0 rds success 0 rds    | [0..cds): calldata    |
             * 80      | DUP1           | 0 0 rds success 0 rds  | [0..cds): calldata    |
             * 3e      | RETURNDATACOPY | success 0 rds          | [0..rds): returndata  |
             *                                                                           |
             * 60 0x2a | PUSH1 0x2a     | 0x2a success 0 rds     | [0..rds): returndata  |
             * 57      | JUMPI          | 0 rds                  | [0..rds): returndata  |
             *                                                                           |
             * ::: revert :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * fd      | REVERT         |                        | [0..rds): returndata  |
             *                                                                           |
             * ::: return :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 5b      | JUMPDEST       | 0 rds                  | [0..rds): returndata  |
             * f3      | RETURN         |                        | [0..rds): returndata  |
             * --------------------------------------------------------------------------+
             */
            mstore(0x21, 0x5af43d3d93803e602a57fd5bf3)
            mstore(0x14, implementation)
            mstore(0x00, 0x602c3d8160093d39f33d3d3d3d363d3d37363d73)
            instance := create(value, 0x0c, 0x35)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x21, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Deploys a deterministic clone of `implementation` with `salt`.
    function cloneDeterministic(address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        instance = cloneDeterministic(0, implementation, salt);
    }

    /// @dev Deploys a deterministic clone of `implementation` with `salt`.
    /// Deposits `value` ETH during deployment.
    function cloneDeterministic(uint256 value, address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x21, 0x5af43d3d93803e602a57fd5bf3)
            mstore(0x14, implementation)
            mstore(0x00, 0x602c3d8160093d39f33d3d3d3d363d3d37363d73)
            instance := create2(value, 0x0c, 0x35, salt)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x21, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Returns the initialization code of the clone of `implementation`.
    function initCode(address implementation) internal pure returns (bytes memory c) {
        /// @solidity memory-safe-assembly
        assembly {
            c := mload(0x40)
            mstore(add(c, 0x40), 0x5af43d3d93803e602a57fd5bf30000000000000000000000)
            mstore(add(c, 0x28), implementation)
            mstore(add(c, 0x14), 0x602c3d8160093d39f33d3d3d3d363d3d37363d73)
            mstore(c, 0x35) // Store the length.
            mstore(0x40, add(c, 0x60)) // Allocate memory.
        }
    }

    /// @dev Returns the initialization code hash of the clone of `implementation`.
    function initCodeHash(address implementation) internal pure returns (bytes32 hash) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x21, 0x5af43d3d93803e602a57fd5bf3)
            mstore(0x14, implementation)
            mstore(0x00, 0x602c3d8160093d39f33d3d3d3d363d3d37363d73)
            hash := keccak256(0x0c, 0x35)
            mstore(0x21, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Returns the address of the clone of `implementation`, with `salt` by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 hash = initCodeHash(implementation);
        predicted = predictDeterministicAddress(hash, salt, deployer);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*          MINIMAL PROXY OPERATIONS (PUSH0 VARIANT)          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Deploys a PUSH0 clone of `implementation`.
    function clone_PUSH0(address implementation) internal returns (address instance) {
        instance = clone_PUSH0(0, implementation);
    }

    /// @dev Deploys a PUSH0 clone of `implementation`.
    /// Deposits `value` ETH during deployment.
    function clone_PUSH0(uint256 value, address implementation)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            /**
             * --------------------------------------------------------------------------+
             * CREATION (9 bytes)                                                        |
             * --------------------------------------------------------------------------|
             * Opcode     | Mnemonic          | Stack     | Memory                       |
             * --------------------------------------------------------------------------|
             * 60 runSize | PUSH1 runSize     | r         |                              |
             * 5f         | PUSH0             | 0 r       |                              |
             * 81         | DUP2              | r 0 r     |                              |
             * 60 offset  | PUSH1 offset      | o r 0 r   |                              |
             * 5f         | PUSH0             | 0 o r 0 r |                              |
             * 39         | CODECOPY          | 0 r       | [0..runSize): runtime code   |
             * f3         | RETURN            |           | [0..runSize): runtime code   |
             * --------------------------------------------------------------------------|
             * RUNTIME (45 bytes)                                                        |
             * --------------------------------------------------------------------------|
             * Opcode  | Mnemonic       | Stack                  | Memory                |
             * --------------------------------------------------------------------------|
             *                                                                           |
             * ::: keep some values in stack ::::::::::::::::::::::::::::::::::::::::::: |
             * 5f      | PUSH0          | 0                      |                       |
             * 5f      | PUSH0          | 0 0                    |                       |
             *                                                                           |
             * ::: copy calldata to memory ::::::::::::::::::::::::::::::::::::::::::::: |
             * 36      | CALLDATASIZE   | cds 0 0                |                       |
             * 5f      | PUSH0          | 0 cds 0 0              |                       |
             * 5f      | PUSH0          | 0 0 cds 0 0            |                       |
             * 37      | CALLDATACOPY   | 0 0                    | [0..cds): calldata    |
             *                                                                           |
             * ::: delegate call to the implementation contract :::::::::::::::::::::::: |
             * 36      | CALLDATASIZE   | cds 0 0                | [0..cds): calldata    |
             * 5f      | PUSH0          | 0 cds 0 0              | [0..cds): calldata    |
             * 73 addr | PUSH20 addr    | addr 0 cds 0 0         | [0..cds): calldata    |
             * 5a      | GAS            | gas addr 0 cds 0 0     | [0..cds): calldata    |
             * f4      | DELEGATECALL   | success                | [0..cds): calldata    |
             *                                                                           |
             * ::: copy return data to memory :::::::::::::::::::::::::::::::::::::::::: |
             * 3d      | RETURNDATASIZE | rds success            | [0..cds): calldata    |
             * 5f      | PUSH0          | 0 rds success          | [0..cds): calldata    |
             * 5f      | PUSH0          | 0 0 rds success        | [0..cds): calldata    |
             * 3e      | RETURNDATACOPY | success                | [0..rds): returndata  |
             *                                                                           |
             * 60 0x29 | PUSH1 0x29     | 0x29 success           | [0..rds): returndata  |
             * 57      | JUMPI          |                        | [0..rds): returndata  |
             *                                                                           |
             * ::: revert :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 3d      | RETURNDATASIZE | rds                    | [0..rds): returndata  |
             * 5f      | PUSH0          | 0 rds                  | [0..rds): returndata  |
             * fd      | REVERT         |                        | [0..rds): returndata  |
             *                                                                           |
             * ::: return :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 5b      | JUMPDEST       |                        | [0..rds): returndata  |
             * 3d      | RETURNDATASIZE | rds                    | [0..rds): returndata  |
             * 5f      | PUSH0          | 0 rds                  | [0..rds): returndata  |
             * f3      | RETURN         |                        | [0..rds): returndata  |
             * --------------------------------------------------------------------------+
             */
            mstore(0x24, 0x5af43d5f5f3e6029573d5ffd5b3d5ff3) // 16
            mstore(0x14, implementation) // 20
            mstore(0x00, 0x602d5f8160095f39f35f5f365f5f37365f73) // 9 + 9
            instance := create(value, 0x0e, 0x36)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x24, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Deploys a deterministic PUSH0 clone of `implementation` with `salt`.
    function cloneDeterministic_PUSH0(address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        instance = cloneDeterministic_PUSH0(0, implementation, salt);
    }

    /// @dev Deploys a deterministic PUSH0 clone of `implementation` with `salt`.
    /// Deposits `value` ETH during deployment.
    function cloneDeterministic_PUSH0(uint256 value, address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x24, 0x5af43d5f5f3e6029573d5ffd5b3d5ff3) // 16
            mstore(0x14, implementation) // 20
            mstore(0x00, 0x602d5f8160095f39f35f5f365f5f37365f73) // 9 + 9
            instance := create2(value, 0x0e, 0x36, salt)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x24, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Returns the initialization code of the PUSH0 clone of `implementation`.
    function initCode_PUSH0(address implementation) internal pure returns (bytes memory c) {
        /// @solidity memory-safe-assembly
        assembly {
            c := mload(0x40)
            mstore(add(c, 0x40), 0x5af43d5f5f3e6029573d5ffd5b3d5ff300000000000000000000) // 16
            mstore(add(c, 0x26), implementation) // 20
            mstore(add(c, 0x12), 0x602d5f8160095f39f35f5f365f5f37365f73) // 9 + 9
            mstore(c, 0x36) // Store the length.
            mstore(0x40, add(c, 0x60)) // Allocate memory.
        }
    }

    /// @dev Returns the initialization code hash of the PUSH0 clone of `implementation`.
    function initCodeHash_PUSH0(address implementation) internal pure returns (bytes32 hash) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x24, 0x5af43d5f5f3e6029573d5ffd5b3d5ff3) // 16
            mstore(0x14, implementation) // 20
            mstore(0x00, 0x602d5f8160095f39f35f5f365f5f37365f73) // 9 + 9
            hash := keccak256(0x0e, 0x36)
            mstore(0x24, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Returns the address of the PUSH0 clone of `implementation`, with `salt` by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictDeterministicAddress_PUSH0(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes32 hash = initCodeHash_PUSH0(implementation);
        predicted = predictDeterministicAddress(hash, salt, deployer);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*           CLONES WITH IMMUTABLE ARGS OPERATIONS            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Deploys a clone of `implementation` with immutable arguments encoded in `args`.
    function clone(address implementation, bytes memory args) internal returns (address instance) {
        instance = clone(0, implementation, args);
    }

    /// @dev Deploys a clone of `implementation` with immutable arguments encoded in `args`.
    /// Deposits `value` ETH during deployment.
    function clone(uint256 value, address implementation, bytes memory args)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            /**
             * ---------------------------------------------------------------------------+
             * CREATION (10 bytes)                                                        |
             * ---------------------------------------------------------------------------|
             * Opcode     | Mnemonic          | Stack     | Memory                        |
             * ---------------------------------------------------------------------------|
             * 61 runSize | PUSH2 runSize     | r         |                               |
             * 3d         | RETURNDATASIZE    | 0 r       |                               |
             * 81         | DUP2              | r 0 r     |                               |
             * 60 offset  | PUSH1 offset      | o r 0 r   |                               |
             * 3d         | RETURNDATASIZE    | 0 o r 0 r |                               |
             * 39         | CODECOPY          | 0 r       | [0..runSize): runtime code    |
             * f3         | RETURN            |           | [0..runSize): runtime code    |
             * ---------------------------------------------------------------------------|
             * RUNTIME (45 bytes + extraLength)                                           |
             * ---------------------------------------------------------------------------|
             * Opcode   | Mnemonic       | Stack                  | Memory                |
             * ---------------------------------------------------------------------------|
             *                                                                            |
             * ::: copy calldata to memory :::::::::::::::::::::::::::::::::::::::::::::: |
             * 36       | CALLDATASIZE   | cds                    |                       |
             * 3d       | RETURNDATASIZE | 0 cds                  |                       |
             * 3d       | RETURNDATASIZE | 0 0 cds                |                       |
             * 37       | CALLDATACOPY   |                        | [0..cds): calldata    |
             *                                                                            |
             * ::: delegate call to the implementation contract ::::::::::::::::::::::::: |
             * 3d       | RETURNDATASIZE | 0                      | [0..cds): calldata    |
             * 3d       | RETURNDATASIZE | 0 0                    | [0..cds): calldata    |
             * 3d       | RETURNDATASIZE | 0 0 0                  | [0..cds): calldata    |
             * 36       | CALLDATASIZE   | cds 0 0 0              | [0..cds): calldata    |
             * 3d       | RETURNDATASIZE | 0 cds 0 0 0 0          | [0..cds): calldata    |
             * 73 addr  | PUSH20 addr    | addr 0 cds 0 0 0 0     | [0..cds): calldata    |
             * 5a       | GAS            | gas addr 0 cds 0 0 0 0 | [0..cds): calldata    |
             * f4       | DELEGATECALL   | success 0 0            | [0..cds): calldata    |
             *                                                                            |
             * ::: copy return data to memory ::::::::::::::::::::::::::::::::::::::::::: |
             * 3d       | RETURNDATASIZE | rds success 0          | [0..cds): calldata    |
             * 82       | DUP3           | 0 rds success 0         | [0..cds): calldata   |
             * 80       | DUP1           | 0 0 rds success 0      | [0..cds): calldata    |
             * 3e       | RETURNDATACOPY | success 0              | [0..rds): returndata  |
             * 90       | SWAP1          | 0 success              | [0..rds): returndata  |
             * 3d       | RETURNDATASIZE | rds 0 success          | [0..rds): returndata  |
             * 91       | SWAP2          | success 0 rds          | [0..rds): returndata  |
             *                                                                            |
             * 60 0x2b  | PUSH1 0x2b     | 0x2b success 0 rds     | [0..rds): returndata  |
             * 57       | JUMPI          | 0 rds                  | [0..rds): returndata  |
             *                                                                            |
             * ::: revert ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * fd       | REVERT         |                        | [0..rds): returndata  |
             *                                                                            |
             * ::: return ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 5b       | JUMPDEST       | 0 rds                  | [0..rds): returndata  |
             * f3       | RETURN         |                        | [0..rds): returndata  |
             * ---------------------------------------------------------------------------+
             */
            let m := mload(0x40)
            let n := mload(args)
            pop(staticcall(gas(), 4, add(args, 0x20), n, add(m, 0x43), n))
            mstore(add(m, 0x23), 0x5af43d82803e903d91602b57fd5bf3)
            mstore(add(m, 0x14), implementation)
            mstore(m, add(0xfe61002d3d81600a3d39f3363d3d373d3d3d363d73, shl(136, n)))
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x2d = 0xffd2`.
            instance := create(value, add(m, add(0x0b, lt(n, 0xffd3))), add(n, 0x37))
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Deploys a deterministic clone of `implementation`
    /// with immutable arguments encoded in `args` and `salt`.
    function cloneDeterministic(address implementation, bytes memory args, bytes32 salt)
        internal
        returns (address instance)
    {
        instance = cloneDeterministic(0, implementation, args, salt);
    }

    /// @dev Deploys a deterministic clone of `implementation`
    /// with immutable arguments encoded in `args` and `salt`.
    function cloneDeterministic(
        uint256 value,
        address implementation,
        bytes memory args,
        bytes32 salt
    ) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let n := mload(args)
            pop(staticcall(gas(), 4, add(args, 0x20), n, add(m, 0x43), n))
            mstore(add(m, 0x23), 0x5af43d82803e903d91602b57fd5bf3)
            mstore(add(m, 0x14), implementation)
            mstore(m, add(0xfe61002d3d81600a3d39f3363d3d373d3d3d363d73, shl(136, n)))
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x2d = 0xffd2`.
            instance := create2(value, add(m, add(0x0b, lt(n, 0xffd3))), add(n, 0x37), salt)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Deploys a deterministic clone of `implementation`
    /// with immutable arguments encoded in `args` and `salt`.
    /// This method does not revert if the clone has already been deployed.
    function createDeterministicClone(address implementation, bytes memory args, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicClone(0, implementation, args, salt);
    }

    /// @dev Deploys a deterministic clone of `implementation`
    /// with immutable arguments encoded in `args` and `salt`.
    /// This method does not revert if the clone has already been deployed.
    function createDeterministicClone(
        uint256 value,
        address implementation,
        bytes memory args,
        bytes32 salt
    ) internal returns (bool alreadyDeployed, address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let n := mload(args)
            pop(staticcall(gas(), 4, add(args, 0x20), n, add(m, 0x43), n))
            mstore(add(m, 0x23), 0x5af43d82803e903d91602b57fd5bf3)
            mstore(add(m, 0x14), implementation)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x2d = 0xffd2`.
            // forgefmt: disable-next-item
            mstore(add(m, gt(n, 0xffd2)), add(0xfe61002d3d81600a3d39f3363d3d373d3d3d363d73, shl(136, n)))
            // Compute and store the bytecode hash.
            mstore8(0x00, 0xff) // Write the prefix.
            mstore(0x35, keccak256(add(m, 0x0c), add(n, 0x37)))
            mstore(0x01, shl(96, address()))
            mstore(0x15, salt)
            instance := keccak256(0x00, 0x55)
            for {} 1 {} {
                if iszero(extcodesize(instance)) {
                    instance := create2(value, add(m, 0x0c), add(n, 0x37), salt)
                    if iszero(instance) {
                        mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                        revert(0x1c, 0x04)
                    }
                    break
                }
                alreadyDeployed := 1
                if iszero(value) { break }
                if iszero(call(gas(), instance, value, codesize(), 0x00, codesize(), 0x00)) {
                    mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                    revert(0x1c, 0x04)
                }
                break
            }
            mstore(0x35, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Returns the initialization code of the clone of `implementation`
    /// using immutable arguments encoded in `args`.
    function initCode(address implementation, bytes memory args)
        internal
        pure
        returns (bytes memory c)
    {
        /// @solidity memory-safe-assembly
        assembly {
            c := mload(0x40)
            let n := mload(args)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x2d = 0xffd2`.
            returndatacopy(returndatasize(), returndatasize(), gt(n, 0xffd2))
            for { let i := 0 } lt(i, n) { i := add(i, 0x20) } {
                mstore(add(add(c, 0x57), i), mload(add(add(args, 0x20), i)))
            }
            mstore(add(c, 0x37), 0x5af43d82803e903d91602b57fd5bf3)
            mstore(add(c, 0x28), implementation)
            mstore(add(c, 0x14), add(0x61002d3d81600a3d39f3363d3d373d3d3d363d73, shl(136, n)))
            mstore(c, add(0x37, n)) // Store the length.
            mstore(add(c, add(n, 0x57)), 0) // Zeroize the slot after the bytes.
            mstore(0x40, add(c, add(n, 0x77))) // Allocate memory.
        }
    }

    /// @dev Returns the initialization code hash of the clone of `implementation`
    /// using immutable arguments encoded in `args`.
    function initCodeHash(address implementation, bytes memory args)
        internal
        pure
        returns (bytes32 hash)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let n := mload(args)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x2d = 0xffd2`.
            returndatacopy(returndatasize(), returndatasize(), gt(n, 0xffd2))
            for { let i := 0 } lt(i, n) { i := add(i, 0x20) } {
                mstore(add(add(m, 0x43), i), mload(add(add(args, 0x20), i)))
            }
            mstore(add(m, 0x23), 0x5af43d82803e903d91602b57fd5bf3)
            mstore(add(m, 0x14), implementation)
            mstore(m, add(0x61002d3d81600a3d39f3363d3d373d3d3d363d73, shl(136, n)))
            hash := keccak256(add(m, 0x0c), add(n, 0x37))
        }
    }

    /// @dev Returns the address of the clone of
    /// `implementation` using immutable arguments encoded in `args`, with `salt`, by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictDeterministicAddress(
        address implementation,
        bytes memory data,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes32 hash = initCodeHash(implementation, data);
        predicted = predictDeterministicAddress(hash, salt, deployer);
    }

    /// @dev Equivalent to `argsOnClone(instance, 0, 2 ** 256 - 1)`.
    function argsOnClone(address instance) internal view returns (bytes memory args) {
        /// @solidity memory-safe-assembly
        assembly {
            args := mload(0x40)
            mstore(args, and(0xffffffffff, sub(extcodesize(instance), 0x2d))) // Store the length.
            extcodecopy(instance, add(args, 0x20), 0x2d, add(mload(args), 0x20))
            mstore(0x40, add(mload(args), add(args, 0x40))) // Allocate memory.
        }
    }

    /// @dev Equivalent to `argsOnClone(instance, start, 2 ** 256 - 1)`.
    function argsOnClone(address instance, uint256 start)
        internal
        view
        returns (bytes memory args)
    {
        /// @solidity memory-safe-assembly
        assembly {
            args := mload(0x40)
            let n := and(0xffffffffff, sub(extcodesize(instance), 0x2d))
            let l := sub(n, and(0xffffff, mul(lt(start, n), start)))
            extcodecopy(instance, args, add(start, 0x0d), add(l, 0x40))
            mstore(args, mul(sub(n, start), lt(start, n))) // Store the length.
            mstore(0x40, add(args, add(0x40, mload(args)))) // Allocate memory.
        }
    }

    /// @dev Returns a slice of the immutable arguments on `instance` from `start` to `end`.
    /// `start` and `end` will be clamped to the range `[0, args.length]`.
    /// The `instance` MUST be deployed via the clone with immutable args functions.
    /// Otherwise, the behavior is undefined.
    /// Out-of-gas reverts if `instance` does not have any code.
    function argsOnClone(address instance, uint256 start, uint256 end)
        internal
        view
        returns (bytes memory args)
    {
        /// @solidity memory-safe-assembly
        assembly {
            args := mload(0x40)
            if iszero(lt(end, 0xffff)) { end := 0xffff }
            let d := mul(sub(end, start), lt(start, end))
            extcodecopy(instance, args, add(start, 0x0d), add(d, 0x20))
            if iszero(and(0xff, mload(add(args, d)))) {
                let n := sub(extcodesize(instance), 0x2d)
                returndatacopy(returndatasize(), returndatasize(), shr(40, n))
                d := mul(gt(n, start), sub(d, mul(gt(end, n), sub(end, n))))
            }
            mstore(args, d) // Store the length.
            mstore(add(add(args, 0x20), d), 0) // Zeroize the slot after the bytes.
            mstore(0x40, add(add(args, 0x40), d)) // Allocate memory.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*              MINIMAL ERC1967 PROXY OPERATIONS              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Note: The ERC1967 proxy here is intended to be upgraded with UUPS.
    // This is NOT the same as ERC1967Factory's transparent proxy, which includes admin logic.

    /// @dev Deploys a minimal ERC1967 proxy with `implementation`.
    function deployERC1967(address implementation) internal returns (address instance) {
        instance = deployERC1967(0, implementation);
    }

    /// @dev Deploys a minimal ERC1967 proxy with `implementation`.
    /// Deposits `value` ETH during deployment.
    function deployERC1967(uint256 value, address implementation)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            /**
             * ---------------------------------------------------------------------------------+
             * CREATION (34 bytes)                                                              |
             * ---------------------------------------------------------------------------------|
             * Opcode     | Mnemonic       | Stack            | Memory                          |
             * ---------------------------------------------------------------------------------|
             * 60 runSize | PUSH1 runSize  | r                |                                 |
             * 3d         | RETURNDATASIZE | 0 r              |                                 |
             * 81         | DUP2           | r 0 r            |                                 |
             * 60 offset  | PUSH1 offset   | o r 0 r          |                                 |
             * 3d         | RETURNDATASIZE | 0 o r 0 r        |                                 |
             * 39         | CODECOPY       | 0 r              | [0..runSize): runtime code      |
             * 73 impl    | PUSH20 impl    | impl 0 r         | [0..runSize): runtime code      |
             * 60 slotPos | PUSH1 slotPos  | slotPos impl 0 r | [0..runSize): runtime code      |
             * 51         | MLOAD          | slot impl 0 r    | [0..runSize): runtime code      |
             * 55         | SSTORE         | 0 r              | [0..runSize): runtime code      |
             * f3         | RETURN         |                  | [0..runSize): runtime code      |
             * ---------------------------------------------------------------------------------|
             * RUNTIME (61 bytes)                                                               |
             * ---------------------------------------------------------------------------------|
             * Opcode     | Mnemonic       | Stack            | Memory                          |
             * ---------------------------------------------------------------------------------|
             *                                                                                  |
             * ::: copy calldata to memory :::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 36         | CALLDATASIZE   | cds              |                                 |
             * 3d         | RETURNDATASIZE | 0 cds            |                                 |
             * 3d         | RETURNDATASIZE | 0 0 cds          |                                 |
             * 37         | CALLDATACOPY   |                  | [0..calldatasize): calldata     |
             *                                                                                  |
             * ::: delegatecall to implementation ::::::::::::::::::::::::::::::::::::::::::::: |
             * 3d         | RETURNDATASIZE | 0                |                                 |
             * 3d         | RETURNDATASIZE | 0 0              |                                 |
             * 36         | CALLDATASIZE   | cds 0 0          | [0..calldatasize): calldata     |
             * 3d         | RETURNDATASIZE | 0 cds 0 0        | [0..calldatasize): calldata     |
             * 7f slot    | PUSH32 slot    | s 0 cds 0 0      | [0..calldatasize): calldata     |
             * 54         | SLOAD          | i 0 cds 0 0      | [0..calldatasize): calldata     |
             * 5a         | GAS            | g i 0 cds 0 0    | [0..calldatasize): calldata     |
             * f4         | DELEGATECALL   | succ             | [0..calldatasize): calldata     |
             *                                                                                  |
             * ::: copy returndata to memory :::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 3d         | RETURNDATASIZE | rds succ         | [0..calldatasize): calldata     |
             * 60 0x00    | PUSH1 0x00     | 0 rds succ       | [0..calldatasize): calldata     |
             * 80         | DUP1           | 0 0 rds succ     | [0..calldatasize): calldata     |
             * 3e         | RETURNDATACOPY | succ             | [0..returndatasize): returndata |
             *                                                                                  |
             * ::: branch on delegatecall status :::::::::::::::::::::::::::::::::::::::::::::: |
             * 60 0x38    | PUSH1 0x38     | dest succ        | [0..returndatasize): returndata |
             * 57         | JUMPI          |                  | [0..returndatasize): returndata |
             *                                                                                  |
             * ::: delegatecall failed, revert :::::::::::::::::::::::::::::::::::::::::::::::: |
             * 3d         | RETURNDATASIZE | rds              | [0..returndatasize): returndata |
             * 60 0x00    | PUSH1 0x00     | 0 rds            | [0..returndatasize): returndata |
             * fd         | REVERT         |                  | [0..returndatasize): returndata |
             *                                                                                  |
             * ::: delegatecall succeeded, return ::::::::::::::::::::::::::::::::::::::::::::: |
             * 5b         | JUMPDEST       |                  | [0..returndatasize): returndata |
             * 3d         | RETURNDATASIZE | rds              | [0..returndatasize): returndata |
             * 60 0x00    | PUSH1 0x00     | 0 rds            | [0..returndatasize): returndata |
             * f3         | RETURN         |                  | [0..returndatasize): returndata |
             * ---------------------------------------------------------------------------------+
             */
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0xcc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3)
            mstore(0x40, 0x5155f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076)
            mstore(0x20, 0x6009)
            mstore(0x1e, implementation)
            mstore(0x0a, 0x603d3d8160223d3973)
            instance := create(value, 0x21, 0x5f)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Deploys a deterministic minimal ERC1967 proxy with `implementation` and `salt`.
    function deployDeterministicERC1967(address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        instance = deployDeterministicERC1967(0, implementation, salt);
    }

    /// @dev Deploys a deterministic minimal ERC1967 proxy with `implementation` and `salt`.
    /// Deposits `value` ETH during deployment.
    function deployDeterministicERC1967(uint256 value, address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0xcc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3)
            mstore(0x40, 0x5155f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076)
            mstore(0x20, 0x6009)
            mstore(0x1e, implementation)
            mstore(0x0a, 0x603d3d8160223d3973)
            instance := create2(value, 0x21, 0x5f, salt)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Creates a deterministic minimal ERC1967 proxy with `implementation` and `salt`.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967(address implementation, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967(0, implementation, salt);
    }

    /// @dev Creates a deterministic minimal ERC1967 proxy with `implementation` and `salt`.
    /// Deposits `value` ETH during deployment.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967(uint256 value, address implementation, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0xcc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3)
            mstore(0x40, 0x5155f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076)
            mstore(0x20, 0x6009)
            mstore(0x1e, implementation)
            mstore(0x0a, 0x603d3d8160223d3973)
            // Compute and store the bytecode hash.
            mstore(add(m, 0x35), keccak256(0x21, 0x5f))
            mstore(m, shl(88, address()))
            mstore8(m, 0xff) // Write the prefix.
            mstore(add(m, 0x15), salt)
            instance := keccak256(m, 0x55)
            for {} 1 {} {
                if iszero(extcodesize(instance)) {
                    instance := create2(value, 0x21, 0x5f, salt)
                    if iszero(instance) {
                        mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                        revert(0x1c, 0x04)
                    }
                    break
                }
                alreadyDeployed := 1
                if iszero(value) { break }
                if iszero(call(gas(), instance, value, codesize(), 0x00, codesize(), 0x00)) {
                    mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                    revert(0x1c, 0x04)
                }
                break
            }
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Returns the initialization code of the minimal ERC1967 proxy of `implementation`.
    function initCodeERC1967(address implementation) internal pure returns (bytes memory c) {
        /// @solidity memory-safe-assembly
        assembly {
            c := mload(0x40)
            mstore(add(c, 0x60), 0x3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f300)
            mstore(add(c, 0x40), 0x55f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076cc)
            mstore(add(c, 0x20), or(shl(24, implementation), 0x600951))
            mstore(add(c, 0x09), 0x603d3d8160223d3973)
            mstore(c, 0x5f) // Store the length.
            mstore(0x40, add(c, 0x80)) // Allocate memory.
        }
    }

    /// @dev Returns the initialization code hash of the minimal ERC1967 proxy of `implementation`.
    function initCodeHashERC1967(address implementation) internal pure returns (bytes32 hash) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0xcc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3)
            mstore(0x40, 0x5155f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076)
            mstore(0x20, 0x6009)
            mstore(0x1e, implementation)
            mstore(0x0a, 0x603d3d8160223d3973)
            hash := keccak256(0x21, 0x5f)
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Returns the address of the ERC1967 proxy of `implementation`, with `salt` by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictDeterministicAddressERC1967(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes32 hash = initCodeHashERC1967(implementation);
        predicted = predictDeterministicAddress(hash, salt, deployer);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*    MINIMAL ERC1967 PROXY WITH IMMUTABLE ARGS OPERATIONS    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Deploys a minimal ERC1967 proxy with `implementation` and `args`.
    function deployERC1967(address implementation, bytes memory args)
        internal
        returns (address instance)
    {
        instance = deployERC1967(0, implementation, args);
    }

    /// @dev Deploys a minimal ERC1967 proxy with `implementation` and `args`.
    /// Deposits `value` ETH during deployment.
    function deployERC1967(uint256 value, address implementation, bytes memory args)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let n := mload(args)
            pop(staticcall(gas(), 4, add(args, 0x20), n, add(m, 0x60), n))
            mstore(add(m, 0x40), 0xcc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3)
            mstore(add(m, 0x20), 0x5155f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076)
            mstore(0x16, 0x6009)
            mstore(0x14, implementation)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x3d = 0xffc2`.
            mstore(gt(n, 0xffc2), add(0xfe61003d3d8160233d3973, shl(56, n)))
            mstore(m, mload(0x16))
            instance := create(value, m, add(n, 0x60))
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Deploys a deterministic minimal ERC1967 proxy with `implementation`, `args` and `salt`.
    function deployDeterministicERC1967(address implementation, bytes memory args, bytes32 salt)
        internal
        returns (address instance)
    {
        instance = deployDeterministicERC1967(0, implementation, args, salt);
    }

    /// @dev Deploys a deterministic minimal ERC1967 proxy with `implementation`, `args` and `salt`.
    /// Deposits `value` ETH during deployment.
    function deployDeterministicERC1967(
        uint256 value,
        address implementation,
        bytes memory args,
        bytes32 salt
    ) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let n := mload(args)
            pop(staticcall(gas(), 4, add(args, 0x20), n, add(m, 0x60), n))
            mstore(add(m, 0x40), 0xcc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3)
            mstore(add(m, 0x20), 0x5155f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076)
            mstore(0x16, 0x6009)
            mstore(0x14, implementation)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x3d = 0xffc2`.
            mstore(gt(n, 0xffc2), add(0xfe61003d3d8160233d3973, shl(56, n)))
            mstore(m, mload(0x16))
            instance := create2(value, m, add(n, 0x60), salt)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Creates a deterministic minimal ERC1967 proxy with `implementation`, `args` and `salt`.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967(address implementation, bytes memory args, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967(0, implementation, args, salt);
    }

    /// @dev Creates a deterministic minimal ERC1967 proxy with `implementation`, `args` and `salt`.
    /// Deposits `value` ETH during deployment.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967(
        uint256 value,
        address implementation,
        bytes memory args,
        bytes32 salt
    ) internal returns (bool alreadyDeployed, address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let n := mload(args)
            pop(staticcall(gas(), 4, add(args, 0x20), n, add(m, 0x60), n))
            mstore(add(m, 0x40), 0xcc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3)
            mstore(add(m, 0x20), 0x5155f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076)
            mstore(0x16, 0x6009)
            mstore(0x14, implementation)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x3d = 0xffc2`.
            mstore(gt(n, 0xffc2), add(0xfe61003d3d8160233d3973, shl(56, n)))
            mstore(m, mload(0x16))
            // Compute and store the bytecode hash.
            mstore8(0x00, 0xff) // Write the prefix.
            mstore(0x35, keccak256(m, add(n, 0x60)))
            mstore(0x01, shl(96, address()))
            mstore(0x15, salt)
            instance := keccak256(0x00, 0x55)
            for {} 1 {} {
                if iszero(extcodesize(instance)) {
                    instance := create2(value, m, add(n, 0x60), salt)
                    if iszero(instance) {
                        mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                        revert(0x1c, 0x04)
                    }
                    break
                }
                alreadyDeployed := 1
                if iszero(value) { break }
                if iszero(call(gas(), instance, value, codesize(), 0x00, codesize(), 0x00)) {
                    mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                    revert(0x1c, 0x04)
                }
                break
            }
            mstore(0x35, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Returns the initialization code of the minimal ERC1967 proxy of `implementation` and `args`.
    function initCodeERC1967(address implementation, bytes memory args)
        internal
        pure
        returns (bytes memory c)
    {
        /// @solidity memory-safe-assembly
        assembly {
            c := mload(0x40)
            let n := mload(args)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x3d = 0xffc2`.
            returndatacopy(returndatasize(), returndatasize(), gt(n, 0xffc2))
            for { let i := 0 } lt(i, n) { i := add(i, 0x20) } {
                mstore(add(add(c, 0x80), i), mload(add(add(args, 0x20), i)))
            }
            mstore(add(c, 0x60), 0xcc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3)
            mstore(add(c, 0x40), 0x5155f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076)
            mstore(add(c, 0x20), 0x6009)
            mstore(add(c, 0x1e), implementation)
            mstore(add(c, 0x0a), add(0x61003d3d8160233d3973, shl(56, n)))
            mstore(c, add(n, 0x60)) // Store the length.
            mstore(add(c, add(n, 0x80)), 0) // Zeroize the slot after the bytes.
            mstore(0x40, add(c, add(n, 0xa0))) // Allocate memory.
        }
    }

    /// @dev Returns the initialization code hash of the minimal ERC1967 proxy of `implementation` and `args`.
    function initCodeHashERC1967(address implementation, bytes memory args)
        internal
        pure
        returns (bytes32 hash)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let n := mload(args)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x3d = 0xffc2`.
            returndatacopy(returndatasize(), returndatasize(), gt(n, 0xffc2))
            for { let i := 0 } lt(i, n) { i := add(i, 0x20) } {
                mstore(add(add(m, 0x60), i), mload(add(add(args, 0x20), i)))
            }
            mstore(add(m, 0x40), 0xcc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3)
            mstore(add(m, 0x20), 0x5155f3363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076)
            mstore(0x16, 0x6009)
            mstore(0x14, implementation)
            mstore(0x00, add(0x61003d3d8160233d3973, shl(56, n)))
            mstore(m, mload(0x16))
            hash := keccak256(m, add(n, 0x60))
        }
    }

    /// @dev Returns the address of the ERC1967 proxy of `implementation`, `args`, with `salt` by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictDeterministicAddressERC1967(
        address implementation,
        bytes memory args,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes32 hash = initCodeHashERC1967(implementation, args);
        predicted = predictDeterministicAddress(hash, salt, deployer);
    }

    /// @dev Equivalent to `argsOnERC1967(instance, start, 2 ** 256 - 1)`.
    function argsOnERC1967(address instance) internal view returns (bytes memory args) {
        /// @solidity memory-safe-assembly
        assembly {
            args := mload(0x40)
            mstore(args, and(0xffffffffff, sub(extcodesize(instance), 0x3d))) // Store the length.
            extcodecopy(instance, add(args, 0x20), 0x3d, add(mload(args), 0x20))
            mstore(0x40, add(mload(args), add(args, 0x40))) // Allocate memory.
        }
    }

    /// @dev Equivalent to `argsOnERC1967(instance, start, 2 ** 256 - 1)`.
    function argsOnERC1967(address instance, uint256 start)
        internal
        view
        returns (bytes memory args)
    {
        /// @solidity memory-safe-assembly
        assembly {
            args := mload(0x40)
            let n := and(0xffffffffff, sub(extcodesize(instance), 0x3d))
            let l := sub(n, and(0xffffff, mul(lt(start, n), start)))
            extcodecopy(instance, args, add(start, 0x1d), add(l, 0x40))
            mstore(args, mul(sub(n, start), lt(start, n))) // Store the length.
            mstore(0x40, add(args, add(0x40, mload(args)))) // Allocate memory.
        }
    }

    /// @dev Returns a slice of the immutable arguments on `instance` from `start` to `end`.
    /// `start` and `end` will be clamped to the range `[0, args.length]`.
    /// The `instance` MUST be deployed via the ERC1967 with immutable args functions.
    /// Otherwise, the behavior is undefined.
    /// Out-of-gas reverts if `instance` does not have any code.
    function argsOnERC1967(address instance, uint256 start, uint256 end)
        internal
        view
        returns (bytes memory args)
    {
        /// @solidity memory-safe-assembly
        assembly {
            args := mload(0x40)
            if iszero(lt(end, 0xffff)) { end := 0xffff }
            let d := mul(sub(end, start), lt(start, end))
            extcodecopy(instance, args, add(start, 0x1d), add(d, 0x20))
            if iszero(and(0xff, mload(add(args, d)))) {
                let n := sub(extcodesize(instance), 0x3d)
                returndatacopy(returndatasize(), returndatasize(), shr(40, n))
                d := mul(gt(n, start), sub(d, mul(gt(end, n), sub(end, n))))
            }
            mstore(args, d) // Store the length.
            mstore(add(add(args, 0x20), d), 0) // Zeroize the slot after the bytes.
            mstore(0x40, add(add(args, 0x40), d)) // Allocate memory.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 ERC1967I PROXY OPERATIONS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Note: This proxy has a special code path that activates if `calldatasize() == 1`.
    // This code path skips the delegatecall and directly returns the `implementation` address.
    // The returned implementation is guaranteed to be valid if the keccak256 of the
    // proxy's code is equal to `ERC1967I_CODE_HASH`.

    /// @dev Deploys a ERC1967I proxy with `implementation`.
    function deployERC1967I(address implementation) internal returns (address instance) {
        instance = deployERC1967I(0, implementation);
    }

    /// @dev Deploys a ERC1967I proxy with `implementation`.
    /// Deposits `value` ETH during deployment.
    function deployERC1967I(uint256 value, address implementation)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            /**
             * ---------------------------------------------------------------------------------+
             * CREATION (34 bytes)                                                              |
             * ---------------------------------------------------------------------------------|
             * Opcode     | Mnemonic       | Stack            | Memory                          |
             * ---------------------------------------------------------------------------------|
             * 60 runSize | PUSH1 runSize  | r                |                                 |
             * 3d         | RETURNDATASIZE | 0 r              |                                 |
             * 81         | DUP2           | r 0 r            |                                 |
             * 60 offset  | PUSH1 offset   | o r 0 r          |                                 |
             * 3d         | RETURNDATASIZE | 0 o r 0 r        |                                 |
             * 39         | CODECOPY       | 0 r              | [0..runSize): runtime code      |
             * 73 impl    | PUSH20 impl    | impl 0 r         | [0..runSize): runtime code      |
             * 60 slotPos | PUSH1 slotPos  | slotPos impl 0 r | [0..runSize): runtime code      |
             * 51         | MLOAD          | slot impl 0 r    | [0..runSize): runtime code      |
             * 55         | SSTORE         | 0 r              | [0..runSize): runtime code      |
             * f3         | RETURN         |                  | [0..runSize): runtime code      |
             * ---------------------------------------------------------------------------------|
             * RUNTIME (82 bytes)                                                               |
             * ---------------------------------------------------------------------------------|
             * Opcode     | Mnemonic       | Stack            | Memory                          |
             * ---------------------------------------------------------------------------------|
             *                                                                                  |
             * ::: check calldatasize ::::::::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 36         | CALLDATASIZE   | cds              |                                 |
             * 58         | PC             | 1 cds            |                                 |
             * 14         | EQ             | eqs              |                                 |
             * 60 0x43    | PUSH1 0x43     | dest eqs         |                                 |
             * 57         | JUMPI          |                  |                                 |
             *                                                                                  |
             * ::: copy calldata to memory :::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 36         | CALLDATASIZE   | cds              |                                 |
             * 3d         | RETURNDATASIZE | 0 cds            |                                 |
             * 3d         | RETURNDATASIZE | 0 0 cds          |                                 |
             * 37         | CALLDATACOPY   |                  | [0..calldatasize): calldata     |
             *                                                                                  |
             * ::: delegatecall to implementation ::::::::::::::::::::::::::::::::::::::::::::: |
             * 3d         | RETURNDATASIZE | 0                |                                 |
             * 3d         | RETURNDATASIZE | 0 0              |                                 |
             * 36         | CALLDATASIZE   | cds 0 0          | [0..calldatasize): calldata     |
             * 3d         | RETURNDATASIZE | 0 cds 0 0        | [0..calldatasize): calldata     |
             * 7f slot    | PUSH32 slot    | s 0 cds 0 0      | [0..calldatasize): calldata     |
             * 54         | SLOAD          | i 0 cds 0 0      | [0..calldatasize): calldata     |
             * 5a         | GAS            | g i 0 cds 0 0    | [0..calldatasize): calldata     |
             * f4         | DELEGATECALL   | succ             | [0..calldatasize): calldata     |
             *                                                                                  |
             * ::: copy returndata to memory :::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 3d         | RETURNDATASIZE | rds succ         | [0..calldatasize): calldata     |
             * 60 0x00    | PUSH1 0x00     | 0 rds succ       | [0..calldatasize): calldata     |
             * 80         | DUP1           | 0 0 rds succ     | [0..calldatasize): calldata     |
             * 3e         | RETURNDATACOPY | succ             | [0..returndatasize): returndata |
             *                                                                                  |
             * ::: branch on delegatecall status :::::::::::::::::::::::::::::::::::::::::::::: |
             * 60 0x3E    | PUSH1 0x3E     | dest succ        | [0..returndatasize): returndata |
             * 57         | JUMPI          |                  | [0..returndatasize): returndata |
             *                                                                                  |
             * ::: delegatecall failed, revert :::::::::::::::::::::::::::::::::::::::::::::::: |
             * 3d         | RETURNDATASIZE | rds              | [0..returndatasize): returndata |
             * 60 0x00    | PUSH1 0x00     | 0 rds            | [0..returndatasize): returndata |
             * fd         | REVERT         |                  | [0..returndatasize): returndata |
             *                                                                                  |
             * ::: delegatecall succeeded, return ::::::::::::::::::::::::::::::::::::::::::::: |
             * 5b         | JUMPDEST       |                  | [0..returndatasize): returndata |
             * 3d         | RETURNDATASIZE | rds              | [0..returndatasize): returndata |
             * 60 0x00    | PUSH1 0x00     | 0 rds            | [0..returndatasize): returndata |
             * f3         | RETURN         |                  | [0..returndatasize): returndata |
             *                                                                                  |
             * ::: implementation , return :::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 5b         | JUMPDEST       |                  |                                 |
             * 60 0x20    | PUSH1 0x20     | 32               |                                 |
             * 60 0x0F    | PUSH1 0x0F     | o 32             |                                 |
             * 3d         | RETURNDATASIZE | 0 o 32           |                                 |
             * 39         | CODECOPY       |                  | [0..32): implementation slot    |
             * 3d         | RETURNDATASIZE | 0                | [0..32): implementation slot    |
             * 51         | MLOAD          | slot             | [0..32): implementation slot    |
             * 54         | SLOAD          | impl             | [0..32): implementation slot    |
             * 3d         | RETURNDATASIZE | 0 impl           | [0..32): implementation slot    |
             * 52         | MSTORE         |                  | [0..32): implementation address |
             * 59         | MSIZE          | 32               | [0..32): implementation address |
             * 3d         | RETURNDATASIZE | 0 32             | [0..32): implementation address |
             * f3         | RETURN         |                  | [0..32): implementation address |
             * ---------------------------------------------------------------------------------+
             */
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0x3d6000803e603e573d6000fd5b3d6000f35b6020600f3d393d51543d52593df3)
            mstore(0x40, 0xa13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af4)
            mstore(0x20, 0x600f5155f3365814604357363d3d373d3d363d7f360894)
            mstore(0x09, or(shl(160, 0x60523d8160223d3973), shr(96, shl(96, implementation))))
            instance := create(value, 0x0c, 0x74)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Deploys a deterministic ERC1967I proxy with `implementation` and `salt`.
    function deployDeterministicERC1967I(address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        instance = deployDeterministicERC1967I(0, implementation, salt);
    }

    /// @dev Deploys a deterministic ERC1967I proxy with `implementation` and `salt`.
    /// Deposits `value` ETH during deployment.
    function deployDeterministicERC1967I(uint256 value, address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0x3d6000803e603e573d6000fd5b3d6000f35b6020600f3d393d51543d52593df3)
            mstore(0x40, 0xa13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af4)
            mstore(0x20, 0x600f5155f3365814604357363d3d373d3d363d7f360894)
            mstore(0x09, or(shl(160, 0x60523d8160223d3973), shr(96, shl(96, implementation))))
            instance := create2(value, 0x0c, 0x74, salt)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Creates a deterministic ERC1967I proxy with `implementation` and `salt`.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967I(address implementation, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967I(0, implementation, salt);
    }

    /// @dev Creates a deterministic ERC1967I proxy with `implementation` and `salt`.
    /// Deposits `value` ETH during deployment.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967I(uint256 value, address implementation, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0x3d6000803e603e573d6000fd5b3d6000f35b6020600f3d393d51543d52593df3)
            mstore(0x40, 0xa13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af4)
            mstore(0x20, 0x600f5155f3365814604357363d3d373d3d363d7f360894)
            mstore(0x09, or(shl(160, 0x60523d8160223d3973), shr(96, shl(96, implementation))))
            // Compute and store the bytecode hash.
            mstore(add(m, 0x35), keccak256(0x0c, 0x74))
            mstore(m, shl(88, address()))
            mstore8(m, 0xff) // Write the prefix.
            mstore(add(m, 0x15), salt)
            instance := keccak256(m, 0x55)
            for {} 1 {} {
                if iszero(extcodesize(instance)) {
                    instance := create2(value, 0x0c, 0x74, salt)
                    if iszero(instance) {
                        mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                        revert(0x1c, 0x04)
                    }
                    break
                }
                alreadyDeployed := 1
                if iszero(value) { break }
                if iszero(call(gas(), instance, value, codesize(), 0x00, codesize(), 0x00)) {
                    mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                    revert(0x1c, 0x04)
                }
                break
            }
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Returns the initialization code of the ERC1967I proxy of `implementation`.
    function initCodeERC1967I(address implementation) internal pure returns (bytes memory c) {
        /// @solidity memory-safe-assembly
        assembly {
            c := mload(0x40)
            mstore(add(c, 0x74), 0x3d6000803e603e573d6000fd5b3d6000f35b6020600f3d393d51543d52593df3)
            mstore(add(c, 0x54), 0xa13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af4)
            mstore(add(c, 0x34), 0x600f5155f3365814604357363d3d373d3d363d7f360894)
            mstore(add(c, 0x1d), implementation)
            mstore(add(c, 0x09), 0x60523d8160223d3973)
            mstore(add(c, 0x94), 0)
            mstore(c, 0x74) // Store the length.
            mstore(0x40, add(c, 0xa0)) // Allocate memory.
        }
    }

    /// @dev Returns the initialization code hash of the ERC1967I proxy of `implementation`.
    function initCodeHashERC1967I(address implementation) internal pure returns (bytes32 hash) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0x3d6000803e603e573d6000fd5b3d6000f35b6020600f3d393d51543d52593df3)
            mstore(0x40, 0xa13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af4)
            mstore(0x20, 0x600f5155f3365814604357363d3d373d3d363d7f360894)
            mstore(0x09, or(shl(160, 0x60523d8160223d3973), shr(96, shl(96, implementation))))
            hash := keccak256(0x0c, 0x74)
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Returns the address of the ERC1967I proxy of `implementation`, with `salt` by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictDeterministicAddressERC1967I(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes32 hash = initCodeHashERC1967I(implementation);
        predicted = predictDeterministicAddress(hash, salt, deployer);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*       ERC1967I PROXY WITH IMMUTABLE ARGS OPERATIONS        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Deploys a minimal ERC1967I proxy with `implementation` and `args`.
    function deployERC1967I(address implementation, bytes memory args) internal returns (address) {
        return deployERC1967I(0, implementation, args);
    }

    /// @dev Deploys a minimal ERC1967I proxy with `implementation` and `args`.
    /// Deposits `value` ETH during deployment.
    function deployERC1967I(uint256 value, address implementation, bytes memory args)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let n := mload(args)
            pop(staticcall(gas(), 4, add(args, 0x20), n, add(m, 0x8b), n))

            mstore(add(m, 0x6b), 0x3d6000803e603e573d6000fd5b3d6000f35b6020600f3d393d51543d52593df3)
            mstore(add(m, 0x4b), 0xa13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af4)
            mstore(add(m, 0x2b), 0x600f5155f3365814604357363d3d373d3d363d7f360894)
            mstore(add(m, 0x14), implementation)
            mstore(m, add(0xfe6100523d8160233d3973, shl(56, n)))

            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x52 = 0xffad`.
            instance := create(value, add(m, add(0x15, lt(n, 0xffae))), add(0x75, n))
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Deploys a deterministic ERC1967I proxy with `implementation`, `args`, and `salt`.
    function deployDeterministicERC1967I(address implementation, bytes memory args, bytes32 salt)
        internal
        returns (address instance)
    {
        instance = deployDeterministicERC1967I(0, implementation, args, salt);
    }

    /// @dev Deploys a deterministic ERC1967I proxy with `implementation`, `args`, and `salt`.
    /// Deposits `value` ETH during deployment.
    function deployDeterministicERC1967I(
        uint256 value,
        address implementation,
        bytes memory args,
        bytes32 salt
    ) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let n := mload(args)
            pop(staticcall(gas(), 4, add(args, 0x20), n, add(m, 0x8b), n))

            mstore(add(m, 0x6b), 0x3d6000803e603e573d6000fd5b3d6000f35b6020600f3d393d51543d52593df3)
            mstore(add(m, 0x4b), 0xa13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af4)
            mstore(add(m, 0x2b), 0x600f5155f3365814604357363d3d373d3d363d7f360894)
            mstore(add(m, 0x14), implementation)
            mstore(m, add(0xfe6100523d8160233d3973, shl(56, n)))

            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x52 = 0xffad`.
            instance := create2(value, add(m, add(0x15, lt(n, 0xffae))), add(0x75, n), salt)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Creates a deterministic ERC1967I proxy with `implementation`, `args` and `salt`.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967I(address implementation, bytes memory args, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967I(0, implementation, args, salt);
    }

    /// @dev Creates a deterministic ERC1967I proxy with `implementation`, `args` and `salt`.
    /// Deposits `value` ETH during deployment.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967I(
        uint256 value,
        address implementation,
        bytes memory args,
        bytes32 salt
    ) internal returns (bool alreadyDeployed, address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let n := mload(args)
            pop(staticcall(gas(), 4, add(args, 0x20), n, add(m, 0x75), n))
            mstore(add(m, 0x55), 0x3d6000803e603e573d6000fd5b3d6000f35b6020600f3d393d51543d52593df3)
            mstore(add(m, 0x35), 0xa13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af4)
            mstore(add(m, 0x15), 0x5155f3365814604357363d3d373d3d363d7f360894)
            mstore(0x16, 0x600f)
            mstore(0x14, implementation)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x52 = 0xffad`.
            mstore(gt(n, 0xffad), add(0xfe6100523d8160233d3973, shl(56, n)))
            mstore(m, mload(0x16))
            // Compute and store the bytecode hash.
            mstore8(0x00, 0xff) // Write the prefix.
            mstore(0x35, keccak256(m, add(n, 0x75)))
            mstore(0x01, shl(96, address()))
            mstore(0x15, salt)
            instance := keccak256(0x00, 0x55)
            for {} 1 {} {
                if iszero(extcodesize(instance)) {
                    instance := create2(value, m, add(0x75, n), salt)
                    if iszero(instance) {
                        mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                        revert(0x1c, 0x04)
                    }
                    break
                }
                alreadyDeployed := 1
                if iszero(value) { break }
                if iszero(call(gas(), instance, value, codesize(), 0x00, codesize(), 0x00)) {
                    mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                    revert(0x1c, 0x04)
                }
                break
            }
            mstore(0x35, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Returns the initialization code of the ERC1967I proxy of `implementation` and `args`.
    function initCodeERC1967I(address implementation, bytes memory args)
        internal
        pure
        returns (bytes memory c)
    {
        /// @solidity memory-safe-assembly
        assembly {
            c := mload(0x40)
            let n := mload(args)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x52 = 0xffad`.
            returndatacopy(returndatasize(), returndatasize(), gt(n, 0xffad))
            for { let i := 0 } lt(i, n) { i := add(i, 0x20) } {
                mstore(add(add(c, 0x95), i), mload(add(add(args, 0x20), i)))
            }

            mstore(add(c, 0x75), 0x3d6000803e603e573d6000fd5b3d6000f35b6020600f3d393d51543d52593df3)
            mstore(add(c, 0x55), 0xa13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af4)
            mstore(add(c, 0x35), 0x600f5155f3365814604357363d3d373d3d363d7f360894)
            mstore(add(c, 0x1e), implementation)
            mstore(add(c, 0x0a), add(0x6100523d8160233d3973, shl(56, n)))
            mstore(add(c, add(n, 0x95)), 0)
            mstore(c, add(0x75, n)) // Store the length.
            mstore(0x40, add(c, add(n, 0xb5))) // Allocate memory.
        }
    }

    /// @dev Returns the initialization code hash of the ERC1967I proxy of `implementation` and `args.
    function initCodeHashERC1967I(address implementation, bytes memory args)
        internal
        pure
        returns (bytes32 hash)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            let n := mload(args)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x52 = 0xffad`.
            returndatacopy(returndatasize(), returndatasize(), gt(n, 0xffad))

            for { let i := 0 } lt(i, n) { i := add(i, 0x20) } {
                mstore(add(add(m, 0x75), i), mload(add(add(args, 0x20), i)))
            }

            mstore(add(m, 0x55), 0x3d6000803e603e573d6000fd5b3d6000f35b6020600f3d393d51543d52593df3)
            mstore(add(m, 0x35), 0xa13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af4)
            mstore(add(m, 0x15), 0x5155f3365814604357363d3d373d3d363d7f360894)
            mstore(0x16, 0x600f)
            mstore(0x14, implementation)
            mstore(0x00, add(0x6100523d8160233d3973, shl(56, n)))
            mstore(m, mload(0x16))
            hash := keccak256(m, add(0x75, n))
        }
    }

    /// @dev Returns the address of the ERC1967I proxy of `implementation`, `args` with `salt` by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictDeterministicAddressERC1967I(
        address implementation,
        bytes memory args,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes32 hash = initCodeHashERC1967I(implementation, args);
        predicted = predictDeterministicAddress(hash, salt, deployer);
    }

    /// @dev Equivalent to `argsOnERC1967I(instance, start, 2 ** 256 - 1)`.
    function argsOnERC1967I(address instance) internal view returns (bytes memory args) {
        /// @solidity memory-safe-assembly
        assembly {
            args := mload(0x40)
            mstore(args, and(0xffffffffff, sub(extcodesize(instance), 0x52))) // Store the length.
            extcodecopy(instance, add(args, 0x20), 0x52, add(mload(args), 0x20))
            mstore(0x40, add(mload(args), add(args, 0x40))) // Allocate memory.
        }
    }

    /// @dev Equivalent to `argsOnERC1967I(instance, start, 2 ** 256 - 1)`.
    function argsOnERC1967I(address instance, uint256 start)
        internal
        view
        returns (bytes memory args)
    {
        /// @solidity memory-safe-assembly
        assembly {
            args := mload(0x40)
            let n := and(0xffffffffff, sub(extcodesize(instance), 0x52))
            let l := sub(n, and(0xffffff, mul(lt(start, n), start)))
            extcodecopy(instance, args, add(start, 0x32), add(l, 0x40))
            mstore(args, mul(sub(n, start), lt(start, n))) // Store the length.
            mstore(0x40, add(mload(args), add(args, 0x40))) // Allocate memory.
        }
    }

    /// @dev Returns a slice of the immutable arguments on `instance` from `start` to `end`.
    /// `start` and `end` will be clamped to the range `[0, args.length]`.
    /// The `instance` MUST be deployed via the ERC1967 with immutable args functions.
    /// Otherwise, the behavior is undefined.
    /// Out-of-gas reverts if `instance` does not have any code.
    function argsOnERC1967I(address instance, uint256 start, uint256 end)
        internal
        view
        returns (bytes memory args)
    {
        /// @solidity memory-safe-assembly
        assembly {
            args := mload(0x40)
            if iszero(lt(end, 0xffff)) { end := 0xffff }
            let d := mul(sub(end, start), lt(start, end))
            extcodecopy(instance, args, add(start, 0x32), add(d, 0x20))
            if iszero(and(0xff, mload(add(args, d)))) {
                let n := sub(extcodesize(instance), 0x52)
                returndatacopy(returndatasize(), returndatasize(), shr(40, n))
                d := mul(gt(n, start), sub(d, mul(gt(end, n), sub(end, n))))
            }
            mstore(args, d) // Store the length.
            mstore(add(add(args, 0x20), d), 0) // Zeroize the slot after the bytes.
            mstore(0x40, add(add(args, 0x40), d)) // Allocate memory.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                ERC1967 BOOTSTRAP OPERATIONS                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // A bootstrap is a minimal UUPS implementation that allows an ERC1967 proxy
    // pointing to it to be upgraded. The ERC1967 proxy can then be deployed to a
    // deterministic address independent of the implementation:
    // ```
    //     address bootstrap = LibClone.erc1967Bootstrap();
    //     address instance = LibClone.deployDeterministicERC1967(0, bootstrap, salt);
    //     LibClone.bootstrapERC1967(bootstrap, implementation);
    // ```

    /// @dev Deploys the ERC1967 bootstrap if it has not been deployed.
    function erc1967Bootstrap() internal returns (address) {
        return erc1967Bootstrap(address(this));
    }

    /// @dev Deploys the ERC1967 bootstrap if it has not been deployed.
    function erc1967Bootstrap(address authorizedUpgrader) internal returns (address bootstrap) {
        bytes memory c = initCodeERC1967Bootstrap(authorizedUpgrader);
        bootstrap = predictDeterministicAddress(keccak256(c), bytes32(0), address(this));
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(extcodesize(bootstrap)) {
                if iszero(create2(0, add(c, 0x20), mload(c), 0)) {
                    mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    /// @dev Replaces the implementation at `instance`.
    function bootstrapERC1967(address instance, address implementation) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, implementation)
            if iszero(call(gas(), instance, 0, 0x0c, 0x14, codesize(), 0x00)) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Replaces the implementation at `instance`, and then call it with `data`.
    function bootstrapERC1967AndCall(address instance, address implementation, bytes memory data)
        internal
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data)
            mstore(data, implementation)
            if iszero(call(gas(), instance, 0, add(data, 0x0c), add(n, 0x14), codesize(), 0x00)) {
                if iszero(returndatasize()) {
                    mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                    revert(0x1c, 0x04)
                }
                returndatacopy(mload(0x40), 0x00, returndatasize())
                revert(mload(0x40), returndatasize())
            }
            mstore(data, n) // Restore the length of `data`.
        }
    }

    /// @dev Returns the implementation address of the ERC1967 bootstrap for this contract.
    function predictDeterministicAddressERC1967Bootstrap() internal view returns (address) {
        return predictDeterministicAddressERC1967Bootstrap(address(this), address(this));
    }

    /// @dev Returns the implementation address of the ERC1967 bootstrap for this contract.
    function predictDeterministicAddressERC1967Bootstrap(
        address authorizedUpgrader,
        address deployer
    ) internal pure returns (address) {
        bytes32 hash = initCodeHashERC1967Bootstrap(authorizedUpgrader);
        return predictDeterministicAddress(hash, bytes32(0), deployer);
    }

    /// @dev Returns the initialization code of the ERC1967 bootstrap.
    function initCodeERC1967Bootstrap(address authorizedUpgrader)
        internal
        pure
        returns (bytes memory c)
    {
        /// @solidity memory-safe-assembly
        assembly {
            c := mload(0x40)
            mstore(add(c, 0x80), 0x3d3560601c5af46047573d6000383e3d38fd0000000000000000000000000000)
            mstore(add(c, 0x60), 0xa920a3ca505d382bbc55601436116049575b005b363d3d373d3d601436036014)
            mstore(add(c, 0x40), 0x0338573d3560601c7f360894a13ba1a3210667c828492db98dca3e2076cc3735)
            mstore(add(c, 0x20), authorizedUpgrader)
            mstore(add(c, 0x0c), 0x606880600a3d393df3fe3373)
            mstore(c, 0x72)
            mstore(0x40, add(c, 0xa0))
        }
    }

    /// @dev Returns the initialization code hash of the ERC1967 bootstrap.
    function initCodeHashERC1967Bootstrap(address authorizedUpgrader)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(initCodeERC1967Bootstrap(authorizedUpgrader));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*          MINIMAL ERC1967 BEACON PROXY OPERATIONS           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Note: If you use this proxy, you MUST make sure that the beacon is a
    // valid ERC1967 beacon. This means that the beacon must always return a valid
    // address upon a staticcall to `implementation()`, given sufficient gas.
    // For performance, the deployment operations and the proxy assumes that the
    // beacon is always valid and will NOT validate it.

    /// @dev Deploys a minimal ERC1967 beacon proxy.
    function deployERC1967BeaconProxy(address beacon) internal returns (address instance) {
        instance = deployERC1967BeaconProxy(0, beacon);
    }

    /// @dev Deploys a minimal ERC1967 beacon proxy.
    /// Deposits `value` ETH during deployment.
    function deployERC1967BeaconProxy(uint256 value, address beacon)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            /**
             * ---------------------------------------------------------------------------------+
             * CREATION (34 bytes)                                                              |
             * ---------------------------------------------------------------------------------|
             * Opcode     | Mnemonic       | Stack            | Memory                          |
             * ---------------------------------------------------------------------------------|
             * 60 runSize | PUSH1 runSize  | r                |                                 |
             * 3d         | RETURNDATASIZE | 0 r              |                                 |
             * 81         | DUP2           | r 0 r            |                                 |
             * 60 offset  | PUSH1 offset   | o r 0 r          |                                 |
             * 3d         | RETURNDATASIZE | 0 o r 0 r        |                                 |
             * 39         | CODECOPY       | 0 r              | [0..runSize): runtime code      |
             * 73 beac    | PUSH20 beac    | beac 0 r         | [0..runSize): runtime code      |
             * 60 slotPos | PUSH1 slotPos  | slotPos beac 0 r | [0..runSize): runtime code      |
             * 51         | MLOAD          | slot beac 0 r    | [0..runSize): runtime code      |
             * 55         | SSTORE         | 0 r              | [0..runSize): runtime code      |
             * f3         | RETURN         |                  | [0..runSize): runtime code      |
             * ---------------------------------------------------------------------------------|
             * RUNTIME (82 bytes)                                                               |
             * ---------------------------------------------------------------------------------|
             * Opcode     | Mnemonic       | Stack            | Memory                          |
             * ---------------------------------------------------------------------------------|
             *                                                                                  |
             * ::: copy calldata to memory :::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 36         | CALLDATASIZE   | cds              |                                 |
             * 3d         | RETURNDATASIZE | 0 cds            |                                 |
             * 3d         | RETURNDATASIZE | 0 0 cds          |                                 |
             * 37         | CALLDATACOPY   |                  | [0..calldatasize): calldata     |
             *                                                                                  |
             * ::: delegatecall to implementation ::::::::::::::::::::::::::::::::::::::::::::: |
             * 3d         | RETURNDATASIZE | 0                |                                 |
             * 3d         | RETURNDATASIZE | 0 0              |                                 |
             * 36         | CALLDATASIZE   | cds 0 0          | [0..calldatasize): calldata     |
             * 3d         | RETURNDATASIZE | 0 cds 0 0        | [0..calldatasize): calldata     |
             *                                                                                  |
             * ~~~~~~~ beacon staticcall sub procedure ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ |
             * 60 0x20       | PUSH1 0x20       | 32                          |                 |
             * 36            | CALLDATASIZE     | cds 32                      |                 |
             * 60 0x04       | PUSH1 0x04       | 4 cds 32                    |                 |
             * 36            | CALLDATASIZE     | cds 4 cds 32                |                 |
             * 63 0x5c60da1b | PUSH4 0x5c60da1b | 0x5c60da1b cds 4 cds 32     |                 |
             * 60 0xe0       | PUSH1 0xe0       | 224 0x5c60da1b cds 4 cds 32 |                 |
             * 1b            | SHL              | sel cds 4 cds 32            |                 |
             * 36            | CALLDATASIZE     | cds sel cds 4 cds 32        |                 |
             * 52            | MSTORE           | cds 4 cds 32                | sel             |
             * 7f slot       | PUSH32 slot      | s cds 4 cds 32              | sel             |
             * 54            | SLOAD            | beac cds 4 cds 32           | sel             |
             * 5a            | GAS              | g beac cds 4 cds 32         | sel             |
             * fa            | STATICCALL       | succ                        | impl            |
             * 50            | POP              |                             | impl            |
             * 36            | CALLDATASIZE     | cds                         | impl            |
             * 51            | MLOAD            | impl                        | impl            |
             * ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ |
             * 5a         | GAS            | g impl 0 cds 0 0 | [0..calldatasize): calldata     |
             * f4         | DELEGATECALL   | succ             | [0..calldatasize): calldata     |
             *                                                                                  |
             * ::: copy returndata to memory :::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 3d         | RETURNDATASIZE | rds succ         | [0..calldatasize): calldata     |
             * 60 0x00    | PUSH1 0x00     | 0 rds succ       | [0..calldatasize): calldata     |
             * 80         | DUP1           | 0 0 rds succ     | [0..calldatasize): calldata     |
             * 3e         | RETURNDATACOPY | succ             | [0..returndatasize): returndata |
             *                                                                                  |
             * ::: branch on delegatecall status :::::::::::::::::::::::::::::::::::::::::::::: |
             * 60 0x4d    | PUSH1 0x4d     | dest succ        | [0..returndatasize): returndata |
             * 57         | JUMPI          |                  | [0..returndatasize): returndata |
             *                                                                                  |
             * ::: delegatecall failed, revert :::::::::::::::::::::::::::::::::::::::::::::::: |
             * 3d         | RETURNDATASIZE | rds              | [0..returndatasize): returndata |
             * 60 0x00    | PUSH1 0x00     | 0 rds            | [0..returndatasize): returndata |
             * fd         | REVERT         |                  | [0..returndatasize): returndata |
             *                                                                                  |
             * ::: delegatecall succeeded, return ::::::::::::::::::::::::::::::::::::::::::::: |
             * 5b         | JUMPDEST       |                  | [0..returndatasize): returndata |
             * 3d         | RETURNDATASIZE | rds              | [0..returndatasize): returndata |
             * 60 0x00    | PUSH1 0x00     | 0 rds            | [0..returndatasize): returndata |
             * f3         | RETURN         |                  | [0..returndatasize): returndata |
             * ---------------------------------------------------------------------------------+
             */
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0xb3582b35133d50545afa5036515af43d6000803e604d573d6000fd5b3d6000f3)
            mstore(0x40, 0x1b60e01b36527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6c)
            mstore(0x20, 0x60195155f3363d3d373d3d363d602036600436635c60da)
            mstore(0x09, or(shl(160, 0x60523d8160223d3973), shr(96, shl(96, beacon))))
            instance := create(value, 0x0c, 0x74)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Deploys a deterministic minimal ERC1967 beacon proxy with `salt`.
    function deployDeterministicERC1967BeaconProxy(address beacon, bytes32 salt)
        internal
        returns (address instance)
    {
        instance = deployDeterministicERC1967BeaconProxy(0, beacon, salt);
    }

    /// @dev Deploys a deterministic minimal ERC1967 beacon proxy with `salt`.
    /// Deposits `value` ETH during deployment.
    function deployDeterministicERC1967BeaconProxy(uint256 value, address beacon, bytes32 salt)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0xb3582b35133d50545afa5036515af43d6000803e604d573d6000fd5b3d6000f3)
            mstore(0x40, 0x1b60e01b36527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6c)
            mstore(0x20, 0x60195155f3363d3d373d3d363d602036600436635c60da)
            mstore(0x09, or(shl(160, 0x60523d8160223d3973), shr(96, shl(96, beacon))))
            instance := create2(value, 0x0c, 0x74, salt)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Creates a deterministic minimal ERC1967 beacon proxy with `salt`.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967BeaconProxy(address beacon, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967BeaconProxy(0, beacon, salt);
    }

    /// @dev Creates a deterministic minimal ERC1967 beacon proxy with `salt`.
    /// Deposits `value` ETH during deployment.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967BeaconProxy(uint256 value, address beacon, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0xb3582b35133d50545afa5036515af43d6000803e604d573d6000fd5b3d6000f3)
            mstore(0x40, 0x1b60e01b36527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6c)
            mstore(0x20, 0x60195155f3363d3d373d3d363d602036600436635c60da)
            mstore(0x09, or(shl(160, 0x60523d8160223d3973), shr(96, shl(96, beacon))))
            // Compute and store the bytecode hash.
            mstore(add(m, 0x35), keccak256(0x0c, 0x74))
            mstore(m, shl(88, address()))
            mstore8(m, 0xff) // Write the prefix.
            mstore(add(m, 0x15), salt)
            instance := keccak256(m, 0x55)
            for {} 1 {} {
                if iszero(extcodesize(instance)) {
                    instance := create2(value, 0x0c, 0x74, salt)
                    if iszero(instance) {
                        mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                        revert(0x1c, 0x04)
                    }
                    break
                }
                alreadyDeployed := 1
                if iszero(value) { break }
                if iszero(call(gas(), instance, value, codesize(), 0x00, codesize(), 0x00)) {
                    mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                    revert(0x1c, 0x04)
                }
                break
            }
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Returns the initialization code of the minimal ERC1967 beacon proxy.
    function initCodeERC1967BeaconProxy(address beacon) internal pure returns (bytes memory c) {
        /// @solidity memory-safe-assembly
        assembly {
            c := mload(0x40)
            mstore(add(c, 0x74), 0xb3582b35133d50545afa5036515af43d6000803e604d573d6000fd5b3d6000f3)
            mstore(add(c, 0x54), 0x1b60e01b36527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6c)
            mstore(add(c, 0x34), 0x60195155f3363d3d373d3d363d602036600436635c60da)
            mstore(add(c, 0x1d), beacon)
            mstore(add(c, 0x09), 0x60523d8160223d3973)
            mstore(add(c, 0x94), 0)
            mstore(c, 0x74) // Store the length.
            mstore(0x40, add(c, 0xa0)) // Allocate memory.
        }
    }

    /// @dev Returns the initialization code hash of the minimal ERC1967 beacon proxy.
    function initCodeHashERC1967BeaconProxy(address beacon) internal pure returns (bytes32 hash) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0xb3582b35133d50545afa5036515af43d6000803e604d573d6000fd5b3d6000f3)
            mstore(0x40, 0x1b60e01b36527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6c)
            mstore(0x20, 0x60195155f3363d3d373d3d363d602036600436635c60da)
            mstore(0x09, or(shl(160, 0x60523d8160223d3973), shr(96, shl(96, beacon))))
            hash := keccak256(0x0c, 0x74)
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Returns the address of the ERC1967 beacon proxy, with `salt` by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictDeterministicAddressERC1967BeaconProxy(
        address beacon,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes32 hash = initCodeHashERC1967BeaconProxy(beacon);
        predicted = predictDeterministicAddress(hash, salt, deployer);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*    ERC1967 BEACON PROXY WITH IMMUTABLE ARGS OPERATIONS     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Deploys a minimal ERC1967 beacon proxy with `args`.
    function deployERC1967BeaconProxy(address beacon, bytes memory args)
        internal
        returns (address instance)
    {
        instance = deployERC1967BeaconProxy(0, beacon, args);
    }

    /// @dev Deploys a minimal ERC1967 beacon proxy with `args`.
    /// Deposits `value` ETH during deployment.
    function deployERC1967BeaconProxy(uint256 value, address beacon, bytes memory args)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let n := mload(args)
            pop(staticcall(gas(), 4, add(args, 0x20), n, add(m, 0x8b), n))
            mstore(add(m, 0x6b), 0xb3582b35133d50545afa5036515af43d6000803e604d573d6000fd5b3d6000f3)
            mstore(add(m, 0x4b), 0x1b60e01b36527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6c)
            mstore(add(m, 0x2b), 0x60195155f3363d3d373d3d363d602036600436635c60da)
            mstore(add(m, 0x14), beacon)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x52 = 0xffad`.
            mstore(add(m, gt(n, 0xffad)), add(0xfe6100523d8160233d3973, shl(56, n)))
            instance := create(value, add(m, 0x16), add(n, 0x75))
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Deploys a deterministic minimal ERC1967 beacon proxy with `args` and `salt`.
    function deployDeterministicERC1967BeaconProxy(address beacon, bytes memory args, bytes32 salt)
        internal
        returns (address instance)
    {
        instance = deployDeterministicERC1967BeaconProxy(0, beacon, args, salt);
    }

    /// @dev Deploys a deterministic minimal ERC1967 beacon proxy with `args` and `salt`.
    /// Deposits `value` ETH during deployment.
    function deployDeterministicERC1967BeaconProxy(
        uint256 value,
        address beacon,
        bytes memory args,
        bytes32 salt
    ) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let n := mload(args)
            pop(staticcall(gas(), 4, add(args, 0x20), n, add(m, 0x8b), n))
            mstore(add(m, 0x6b), 0xb3582b35133d50545afa5036515af43d6000803e604d573d6000fd5b3d6000f3)
            mstore(add(m, 0x4b), 0x1b60e01b36527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6c)
            mstore(add(m, 0x2b), 0x60195155f3363d3d373d3d363d602036600436635c60da)
            mstore(add(m, 0x14), beacon)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x52 = 0xffad`.
            mstore(add(m, gt(n, 0xffad)), add(0xfe6100523d8160233d3973, shl(56, n)))
            instance := create2(value, add(m, 0x16), add(n, 0x75), salt)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Creates a deterministic minimal ERC1967 beacon proxy with `args` and `salt`.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967BeaconProxy(address beacon, bytes memory args, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967BeaconProxy(0, beacon, args, salt);
    }

    /// @dev Creates a deterministic minimal ERC1967 beacon proxy with `args` and `salt`.
    /// Deposits `value` ETH during deployment.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967BeaconProxy(
        uint256 value,
        address beacon,
        bytes memory args,
        bytes32 salt
    ) internal returns (bool alreadyDeployed, address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let n := mload(args)
            pop(staticcall(gas(), 4, add(args, 0x20), n, add(m, 0x8b), n))
            mstore(add(m, 0x6b), 0xb3582b35133d50545afa5036515af43d6000803e604d573d6000fd5b3d6000f3)
            mstore(add(m, 0x4b), 0x1b60e01b36527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6c)
            mstore(add(m, 0x2b), 0x60195155f3363d3d373d3d363d602036600436635c60da)
            mstore(add(m, 0x14), beacon)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x52 = 0xffad`.
            mstore(add(m, gt(n, 0xffad)), add(0xfe6100523d8160233d3973, shl(56, n)))
            // Compute and store the bytecode hash.
            mstore8(0x00, 0xff) // Write the prefix.
            mstore(0x35, keccak256(add(m, 0x16), add(n, 0x75)))
            mstore(0x01, shl(96, address()))
            mstore(0x15, salt)
            instance := keccak256(0x00, 0x55)
            for {} 1 {} {
                if iszero(extcodesize(instance)) {
                    instance := create2(value, add(m, 0x16), add(n, 0x75), salt)
                    if iszero(instance) {
                        mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                        revert(0x1c, 0x04)
                    }
                    break
                }
                alreadyDeployed := 1
                if iszero(value) { break }
                if iszero(call(gas(), instance, value, codesize(), 0x00, codesize(), 0x00)) {
                    mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                    revert(0x1c, 0x04)
                }
                break
            }
            mstore(0x35, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Returns the initialization code of the minimal ERC1967 beacon proxy.
    function initCodeERC1967BeaconProxy(address beacon, bytes memory args)
        internal
        pure
        returns (bytes memory c)
    {
        /// @solidity memory-safe-assembly
        assembly {
            c := mload(0x40)
            let n := mload(args)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x52 = 0xffad`.
            returndatacopy(returndatasize(), returndatasize(), gt(n, 0xffad))
            for { let i := 0 } lt(i, n) { i := add(i, 0x20) } {
                mstore(add(add(c, 0x95), i), mload(add(add(args, 0x20), i)))
            }
            mstore(add(c, 0x75), 0xb3582b35133d50545afa5036515af43d6000803e604d573d6000fd5b3d6000f3)
            mstore(add(c, 0x55), 0x1b60e01b36527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6c)
            mstore(add(c, 0x35), 0x60195155f3363d3d373d3d363d602036600436635c60da)
            mstore(add(c, 0x1e), beacon)
            mstore(add(c, 0x0a), add(0x6100523d8160233d3973, shl(56, n)))
            mstore(c, add(n, 0x75)) // Store the length.
            mstore(add(c, add(n, 0x95)), 0) // Zeroize the slot after the bytes.
            mstore(0x40, add(c, add(n, 0xb5))) // Allocate memory.
        }
    }

    /// @dev Returns the initialization code hash of the minimal ERC1967 beacon proxy with `args`.
    function initCodeHashERC1967BeaconProxy(address beacon, bytes memory args)
        internal
        pure
        returns (bytes32 hash)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let n := mload(args)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x52 = 0xffad`.
            returndatacopy(returndatasize(), returndatasize(), gt(n, 0xffad))
            for { let i := 0 } lt(i, n) { i := add(i, 0x20) } {
                mstore(add(add(m, 0x8b), i), mload(add(add(args, 0x20), i)))
            }
            mstore(add(m, 0x6b), 0xb3582b35133d50545afa5036515af43d6000803e604d573d6000fd5b3d6000f3)
            mstore(add(m, 0x4b), 0x1b60e01b36527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6c)
            mstore(add(m, 0x2b), 0x60195155f3363d3d373d3d363d602036600436635c60da)
            mstore(add(m, 0x14), beacon)
            mstore(m, add(0x6100523d8160233d3973, shl(56, n)))
            hash := keccak256(add(m, 0x16), add(n, 0x75))
        }
    }

    /// @dev Returns the address of the ERC1967 beacon proxy with `args`, with `salt` by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictDeterministicAddressERC1967BeaconProxy(
        address beacon,
        bytes memory args,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes32 hash = initCodeHashERC1967BeaconProxy(beacon, args);
        predicted = predictDeterministicAddress(hash, salt, deployer);
    }

    /// @dev Equivalent to `argsOnERC1967BeaconProxy(instance, start, 2 ** 256 - 1)`.
    function argsOnERC1967BeaconProxy(address instance) internal view returns (bytes memory args) {
        /// @solidity memory-safe-assembly
        assembly {
            args := mload(0x40)
            mstore(args, and(0xffffffffff, sub(extcodesize(instance), 0x52))) // Store the length.
            extcodecopy(instance, add(args, 0x20), 0x52, add(mload(args), 0x20))
            mstore(0x40, add(mload(args), add(args, 0x40))) // Allocate memory.
        }
    }

    /// @dev Equivalent to `argsOnERC1967BeaconProxy(instance, start, 2 ** 256 - 1)`.
    function argsOnERC1967BeaconProxy(address instance, uint256 start)
        internal
        view
        returns (bytes memory args)
    {
        /// @solidity memory-safe-assembly
        assembly {
            args := mload(0x40)
            let n := and(0xffffffffff, sub(extcodesize(instance), 0x52))
            let l := sub(n, and(0xffffff, mul(lt(start, n), start)))
            extcodecopy(instance, args, add(start, 0x32), add(l, 0x40))
            mstore(args, mul(sub(n, start), lt(start, n))) // Store the length.
            mstore(0x40, add(args, add(0x40, mload(args)))) // Allocate memory.
        }
    }

    /// @dev Returns a slice of the immutable arguments on `instance` from `start` to `end`.
    /// `start` and `end` will be clamped to the range `[0, args.length]`.
    /// The `instance` MUST be deployed via the ERC1967 beacon proxy with immutable args functions.
    /// Otherwise, the behavior is undefined.
    /// Out-of-gas reverts if `instance` does not have any code.
    function argsOnERC1967BeaconProxy(address instance, uint256 start, uint256 end)
        internal
        view
        returns (bytes memory args)
    {
        /// @solidity memory-safe-assembly
        assembly {
            args := mload(0x40)
            if iszero(lt(end, 0xffff)) { end := 0xffff }
            let d := mul(sub(end, start), lt(start, end))
            extcodecopy(instance, args, add(start, 0x32), add(d, 0x20))
            if iszero(and(0xff, mload(add(args, d)))) {
                let n := sub(extcodesize(instance), 0x52)
                returndatacopy(returndatasize(), returndatasize(), shr(40, n))
                d := mul(gt(n, start), sub(d, mul(gt(end, n), sub(end, n))))
            }
            mstore(args, d) // Store the length.
            mstore(add(add(args, 0x20), d), 0) // Zeroize the slot after the bytes.
            mstore(0x40, add(add(args, 0x40), d)) // Allocate memory.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*              ERC1967I BEACON PROXY OPERATIONS              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Note: This proxy has a special code path that activates if `calldatasize() == 1`.
    // This code path skips the delegatecall and directly returns the `implementation` address.
    // The returned implementation is guaranteed to be valid if the keccak256 of the
    // proxy's code is equal to `ERC1967_BEACON_PROXY_CODE_HASH`.
    //
    // If you use this proxy, you MUST make sure that the beacon is a
    // valid ERC1967 beacon. This means that the beacon must always return a valid
    // address upon a staticcall to `implementation()`, given sufficient gas.
    // For performance, the deployment operations and the proxy assumes that the
    // beacon is always valid and will NOT validate it.

    /// @dev Deploys a ERC1967I beacon proxy.
    function deployERC1967IBeaconProxy(address beacon) internal returns (address instance) {
        instance = deployERC1967IBeaconProxy(0, beacon);
    }

    /// @dev Deploys a ERC1967I beacon proxy.
    /// Deposits `value` ETH during deployment.
    function deployERC1967IBeaconProxy(uint256 value, address beacon)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            /**
             * ---------------------------------------------------------------------------------+
             * CREATION (34 bytes)                                                              |
             * ---------------------------------------------------------------------------------|
             * Opcode     | Mnemonic       | Stack            | Memory                          |
             * ---------------------------------------------------------------------------------|
             * 60 runSize | PUSH1 runSize  | r                |                                 |
             * 3d         | RETURNDATASIZE | 0 r              |                                 |
             * 81         | DUP2           | r 0 r            |                                 |
             * 60 offset  | PUSH1 offset   | o r 0 r          |                                 |
             * 3d         | RETURNDATASIZE | 0 o r 0 r        |                                 |
             * 39         | CODECOPY       | 0 r              | [0..runSize): runtime code      |
             * 73 beac    | PUSH20 beac    | beac 0 r         | [0..runSize): runtime code      |
             * 60 slotPos | PUSH1 slotPos  | slotPos beac 0 r | [0..runSize): runtime code      |
             * 51         | MLOAD          | slot beac 0 r    | [0..runSize): runtime code      |
             * 55         | SSTORE         | 0 r              | [0..runSize): runtime code      |
             * f3         | RETURN         |                  | [0..runSize): runtime code      |
             * ---------------------------------------------------------------------------------|
             * RUNTIME (87 bytes)                                                               |
             * ---------------------------------------------------------------------------------|
             * Opcode     | Mnemonic       | Stack            | Memory                          |
             * ---------------------------------------------------------------------------------|
             *                                                                                  |
             * ::: copy calldata to memory :::::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 36         | CALLDATASIZE   | cds              |                                 |
             * 3d         | RETURNDATASIZE | 0 cds            |                                 |
             * 3d         | RETURNDATASIZE | 0 0 cds          |                                 |
             * 37         | CALLDATACOPY   |                  | [0..calldatasize): calldata     |
             *                                                                                  |
             * ::: delegatecall to implementation ::::::::::::::::::::::::::::::::::::::::::::: |
             * 3d         | RETURNDATASIZE | 0                |                                 |
             * 3d         | RETURNDATASIZE | 0 0              |                                 |
             * 36         | CALLDATASIZE   | cds 0 0          | [0..calldatasize): calldata     |
             * 3d         | RETURNDATASIZE | 0 cds 0 0        | [0..calldatasize): calldata     |
             *                                                                                  |
             * ~~~~~~~ beacon staticcall sub procedure ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ |
             * 60 0x20       | PUSH1 0x20       | 32                          |                 |
             * 36            | CALLDATASIZE     | cds 32                      |                 |
             * 60 0x04       | PUSH1 0x04       | 4 cds 32                    |                 |
             * 36            | CALLDATASIZE     | cds 4 cds 32                |                 |
             * 63 0x5c60da1b | PUSH4 0x5c60da1b | 0x5c60da1b cds 4 cds 32     |                 |
             * 60 0xe0       | PUSH1 0xe0       | 224 0x5c60da1b cds 4 cds 32 |                 |
             * 1b            | SHL              | sel cds 4 cds 32            |                 |
             * 36            | CALLDATASIZE     | cds sel cds 4 cds 32        |                 |
             * 52            | MSTORE           | cds 4 cds 32                | sel             |
             * 7f slot       | PUSH32 slot      | s cds 4 cds 32              | sel             |
             * 54            | SLOAD            | beac cds 4 cds 32           | sel             |
             * 5a            | GAS              | g beac cds 4 cds 32         | sel             |
             * fa            | STATICCALL       | succ                        | impl            |
             * ~~~~~~ check calldatasize ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ |
             * 36            | CALLDATASIZE     | cds succ                    |                 |
             * 14            | EQ               |                             | impl            |
             * 60 0x52       | PUSH1 0x52       |                             | impl            |
             * 57            | JUMPI            |                             | impl            |
             * ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ |
             * 36            | CALLDATASIZE     | cds                         | impl            |
             * 51            | MLOAD            | impl                        | impl            |
             * ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ |
             * 5a         | GAS            | g impl 0 cds 0 0 | [0..calldatasize): calldata     |
             * f4         | DELEGATECALL   | succ             | [0..calldatasize): calldata     |
             *                                                                                  |
             * ::: copy returndata to memory :::::::::::::::::::::::::::::::::::::::::::::::::: |
             * 3d         | RETURNDATASIZE | rds succ         | [0..calldatasize): calldata     |
             * 60 0x00    | PUSH1 0x00     | 0 rds succ       | [0..calldatasize): calldata     |
             * 60 0x01    | PUSH1 0x01     | 1 0 rds succ     | [0..calldatasize): calldata     |
             * 3e         | RETURNDATACOPY | succ             | [1..returndatasize): returndata |
             *                                                                                  |
             * ::: branch on delegatecall status :::::::::::::::::::::::::::::::::::::::::::::: |
             * 60 0x52    | PUSH1 0x52     | dest succ        | [1..returndatasize): returndata |
             * 57         | JUMPI          |                  | [1..returndatasize): returndata |
             *                                                                                  |
             * ::: delegatecall failed, revert :::::::::::::::::::::::::::::::::::::::::::::::: |
             * 3d         | RETURNDATASIZE | rds              | [1..returndatasize): returndata |
             * 60 0x01    | PUSH1 0x01     | 1 rds            | [1..returndatasize): returndata |
             * fd         | REVERT         |                  | [1..returndatasize): returndata |
             *                                                                                  |
             * ::: delegatecall succeeded, return ::::::::::::::::::::::::::::::::::::::::::::: |
             * 5b         | JUMPDEST       |                  | [1..returndatasize): returndata |
             * 3d         | RETURNDATASIZE | rds              | [1..returndatasize): returndata |
             * 60 0x01    | PUSH1 0x01     | 1 rds            | [1..returndatasize): returndata |
             * f3         | RETURN         |                  | [1..returndatasize): returndata |
             * ---------------------------------------------------------------------------------+
             */
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0x3d50545afa361460525736515af43d600060013e6052573d6001fd5b3d6001f3)
            mstore(0x40, 0x527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b3513)
            mstore(0x20, 0x60195155f3363d3d373d3d363d602036600436635c60da1b60e01b36)
            mstore(0x04, or(shl(160, 0x60573d8160223d3973), shr(96, shl(96, beacon))))
            instance := create(value, 0x07, 0x79)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Deploys a deterministic ERC1967I beacon proxy with `salt`.
    function deployDeterministicERC1967IBeaconProxy(address beacon, bytes32 salt)
        internal
        returns (address instance)
    {
        instance = deployDeterministicERC1967IBeaconProxy(0, beacon, salt);
    }

    /// @dev Deploys a deterministic ERC1967I beacon proxy with `salt`.
    /// Deposits `value` ETH during deployment.
    function deployDeterministicERC1967IBeaconProxy(uint256 value, address beacon, bytes32 salt)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0x3d50545afa361460525736515af43d600060013e6052573d6001fd5b3d6001f3)
            mstore(0x40, 0x527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b3513)
            mstore(0x20, 0x60195155f3363d3d373d3d363d602036600436635c60da1b60e01b36)
            mstore(0x04, or(shl(160, 0x60573d8160223d3973), shr(96, shl(96, beacon))))
            instance := create2(value, 0x07, 0x79, salt)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Creates a deterministic ERC1967I beacon proxy with `salt`.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967IBeaconProxy(address beacon, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967IBeaconProxy(0, beacon, salt);
    }

    /// @dev Creates a deterministic ERC1967I beacon proxy with `salt`.
    /// Deposits `value` ETH during deployment.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967IBeaconProxy(uint256 value, address beacon, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0x3d50545afa361460525736515af43d600060013e6052573d6001fd5b3d6001f3)
            mstore(0x40, 0x527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b3513)
            mstore(0x20, 0x60195155f3363d3d373d3d363d602036600436635c60da1b60e01b36)
            mstore(0x04, or(shl(160, 0x60573d8160223d3973), shr(96, shl(96, beacon))))
            // Compute and store the bytecode hash.
            mstore(add(m, 0x35), keccak256(0x07, 0x79))
            mstore(m, shl(88, address()))
            mstore8(m, 0xff) // Write the prefix.
            mstore(add(m, 0x15), salt)
            instance := keccak256(m, 0x55)
            for {} 1 {} {
                if iszero(extcodesize(instance)) {
                    instance := create2(value, 0x07, 0x79, salt)
                    if iszero(instance) {
                        mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                        revert(0x1c, 0x04)
                    }
                    break
                }
                alreadyDeployed := 1
                if iszero(value) { break }
                if iszero(call(gas(), instance, value, codesize(), 0x00, codesize(), 0x00)) {
                    mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                    revert(0x1c, 0x04)
                }
                break
            }
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Returns the initialization code of the ERC1967I beacon proxy.
    function initCodeERC1967IBeaconProxy(address beacon) internal pure returns (bytes memory c) {
        /// @solidity memory-safe-assembly
        assembly {
            c := mload(0x40)
            mstore(add(c, 0x79), 0x3d50545afa361460525736515af43d600060013e6052573d6001fd5b3d6001f3)
            mstore(add(c, 0x59), 0x527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b3513)
            mstore(add(c, 0x39), 0x60195155f3363d3d373d3d363d602036600436635c60da1b60e01b36)
            mstore(add(c, 0x1d), beacon)
            mstore(add(c, 0x09), 0x60573d8160223d3973)
            mstore(add(c, 0x99), 0)
            mstore(c, 0x79) // Store the length.
            mstore(0x40, add(c, 0xa0)) // Allocate memory.
        }
    }

    /// @dev Returns the initialization code hash of the ERC1967I beacon proxy.
    function initCodeHashERC1967IBeaconProxy(address beacon) internal pure returns (bytes32 hash) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, 0x3d50545afa361460525736515af43d600060013e6052573d6001fd5b3d6001f3)
            mstore(0x40, 0x527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b3513)
            mstore(0x20, 0x60195155f3363d3d373d3d363d602036600436635c60da1b60e01b36)
            mstore(0x04, or(shl(160, 0x60573d8160223d3973), shr(96, shl(96, beacon))))
            hash := keccak256(0x07, 0x79)
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero slot.
        }
    }

    /// @dev Returns the address of the ERC1967I beacon proxy, with `salt` by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictDeterministicAddressERC1967IBeaconProxy(
        address beacon,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes32 hash = initCodeHashERC1967IBeaconProxy(beacon);
        predicted = predictDeterministicAddress(hash, salt, deployer);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*    ERC1967I BEACON PROXY WITH IMMUTABLE ARGS OPERATIONS    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Deploys a ERC1967I beacon proxy with `args.
    function deployERC1967IBeaconProxy(address beacon, bytes memory args)
        internal
        returns (address instance)
    {
        instance = deployERC1967IBeaconProxy(0, beacon, args);
    }

    /// @dev Deploys a ERC1967I beacon proxy with `args.
    /// Deposits `value` ETH during deployment.
    function deployERC1967IBeaconProxy(uint256 value, address beacon, bytes memory args)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            let n := mload(args)
            pop(staticcall(gas(), 4, add(args, 0x20), n, add(m, 0x90), n))
            mstore(add(m, 0x70), 0x3d50545afa361460525736515af43d600060013e6052573d6001fd5b3d6001f3)
            mstore(add(m, 0x50), 0x527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b3513)
            mstore(add(m, 0x30), 0x60195155f3363d3d373d3d363d602036600436635c60da1b60e01b36)
            mstore(add(m, 0x14), beacon)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x57 = 0xffa8`.
            mstore(add(m, gt(n, 0xffa8)), add(0xfe6100573d8160233d3973, shl(56, n)))
            instance := create(value, add(m, 0x16), add(n, 0x7a))
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Deploys a deterministic ERC1967I beacon proxy with `args` and `salt`.
    function deployDeterministicERC1967IBeaconProxy(address beacon, bytes memory args, bytes32 salt)
        internal
        returns (address instance)
    {
        instance = deployDeterministicERC1967IBeaconProxy(0, beacon, args, salt);
    }

    /// @dev Deploys a deterministic ERC1967I beacon proxy with `args` and `salt`.
    /// Deposits `value` ETH during deployment.
    function deployDeterministicERC1967IBeaconProxy(
        uint256 value,
        address beacon,
        bytes memory args,
        bytes32 salt
    ) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            let n := mload(args)
            pop(staticcall(gas(), 4, add(args, 0x20), n, add(m, 0x90), n))
            mstore(add(m, 0x70), 0x3d50545afa361460525736515af43d600060013e6052573d6001fd5b3d6001f3)
            mstore(add(m, 0x50), 0x527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b3513)
            mstore(add(m, 0x30), 0x60195155f3363d3d373d3d363d602036600436635c60da1b60e01b36)
            mstore(add(m, 0x14), beacon)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x57 = 0xffa8`.
            mstore(add(m, gt(n, 0xffa8)), add(0xfe6100573d8160233d3973, shl(56, n)))
            instance := create2(value, add(m, 0x16), add(n, 0x7a), salt)
            if iszero(instance) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Creates a deterministic ERC1967I beacon proxy with `args` and `salt`.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967IBeaconProxy(address beacon, bytes memory args, bytes32 salt)
        internal
        returns (bool alreadyDeployed, address instance)
    {
        return createDeterministicERC1967IBeaconProxy(0, beacon, args, salt);
    }

    /// @dev Creates a deterministic ERC1967I beacon proxy with `args` and `salt`.
    /// Deposits `value` ETH during deployment.
    /// Note: This method is intended for use in ERC4337 factories,
    /// which are expected to NOT revert if the proxy is already deployed.
    function createDeterministicERC1967IBeaconProxy(
        uint256 value,
        address beacon,
        bytes memory args,
        bytes32 salt
    ) internal returns (bool alreadyDeployed, address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            let n := mload(args)
            pop(staticcall(gas(), 4, add(args, 0x20), n, add(m, 0x90), n))
            mstore(add(m, 0x70), 0x3d50545afa361460525736515af43d600060013e6052573d6001fd5b3d6001f3)
            mstore(add(m, 0x50), 0x527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b3513)
            mstore(add(m, 0x30), 0x60195155f3363d3d373d3d363d602036600436635c60da1b60e01b36)
            mstore(add(m, 0x14), beacon)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x57 = 0xffa8`.
            mstore(add(m, gt(n, 0xffa8)), add(0xfe6100573d8160233d3973, shl(56, n)))
            // Compute and store the bytecode hash.
            mstore8(0x00, 0xff) // Write the prefix.
            mstore(0x35, keccak256(add(m, 0x16), add(n, 0x7a)))
            mstore(0x01, shl(96, address()))
            mstore(0x15, salt)
            instance := keccak256(0x00, 0x55)
            for {} 1 {} {
                if iszero(extcodesize(instance)) {
                    instance := create2(value, add(m, 0x16), add(n, 0x7a), salt)
                    if iszero(instance) {
                        mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                        revert(0x1c, 0x04)
                    }
                    break
                }
                alreadyDeployed := 1
                if iszero(value) { break }
                if iszero(call(gas(), instance, value, codesize(), 0x00, codesize(), 0x00)) {
                    mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                    revert(0x1c, 0x04)
                }
                break
            }
            mstore(0x35, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Returns the initialization code of the ERC1967I beacon proxy with `args`.
    function initCodeERC1967IBeaconProxy(address beacon, bytes memory args)
        internal
        pure
        returns (bytes memory c)
    {
        /// @solidity memory-safe-assembly
        assembly {
            c := mload(0x40)
            let n := mload(args)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x57 = 0xffa8`.
            returndatacopy(returndatasize(), returndatasize(), gt(n, 0xffa8))
            for { let i := 0 } lt(i, n) { i := add(i, 0x20) } {
                mstore(add(add(c, 0x9a), i), mload(add(add(args, 0x20), i)))
            }
            mstore(add(c, 0x7a), 0x3d50545afa361460525736515af43d600060013e6052573d6001fd5b3d6001f3)
            mstore(add(c, 0x5a), 0x527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b3513)
            mstore(add(c, 0x3a), 0x60195155f3363d3d373d3d363d602036600436635c60da1b60e01b36)
            mstore(add(c, 0x1e), beacon)
            mstore(add(c, 0x0a), add(0x6100573d8160233d3973, shl(56, n)))
            mstore(add(c, add(n, 0x9a)), 0)
            mstore(c, add(n, 0x7a)) // Store the length.
            mstore(0x40, add(c, add(n, 0xba))) // Allocate memory.
        }
    }

    /// @dev Returns the initialization code hash of the ERC1967I beacon proxy with `args`.
    function initCodeHashERC1967IBeaconProxy(address beacon, bytes memory args)
        internal
        pure
        returns (bytes32 hash)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let c := mload(0x40) // Cache the free memory pointer.
            let n := mload(args)
            // Do a out-of-gas revert if `n` is greater than `0xffff - 0x57 = 0xffa8`.
            returndatacopy(returndatasize(), returndatasize(), gt(n, 0xffa8))
            for { let i := 0 } lt(i, n) { i := add(i, 0x20) } {
                mstore(add(add(c, 0x90), i), mload(add(add(args, 0x20), i)))
            }
            mstore(add(c, 0x70), 0x3d50545afa361460525736515af43d600060013e6052573d6001fd5b3d6001f3)
            mstore(add(c, 0x50), 0x527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b3513)
            mstore(add(c, 0x30), 0x60195155f3363d3d373d3d363d602036600436635c60da1b60e01b36)
            mstore(add(c, 0x14), beacon)
            mstore(c, add(0x6100573d8160233d3973, shl(56, n)))
            hash := keccak256(add(c, 0x16), add(n, 0x7a))
        }
    }

    /// @dev Returns the address of the ERC1967I beacon proxy, with  `args` and salt` by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictDeterministicAddressERC1967IBeaconProxy(
        address beacon,
        bytes memory args,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes32 hash = initCodeHashERC1967IBeaconProxy(beacon, args);
        predicted = predictDeterministicAddress(hash, salt, deployer);
    }

    /// @dev Equivalent to `argsOnERC1967IBeaconProxy(instance, start, 2 ** 256 - 1)`.
    function argsOnERC1967IBeaconProxy(address instance)
        internal
        view
        returns (bytes memory args)
    {
        /// @solidity memory-safe-assembly
        assembly {
            args := mload(0x40)
            mstore(args, and(0xffffffffff, sub(extcodesize(instance), 0x57))) // Store the length.
            extcodecopy(instance, add(args, 0x20), 0x57, add(mload(args), 0x20))
            mstore(0x40, add(mload(args), add(args, 0x40))) // Allocate memory.
        }
    }

    /// @dev Equivalent to `argsOnERC1967IBeaconProxy(instance, start, 2 ** 256 - 1)`.
    function argsOnERC1967IBeaconProxy(address instance, uint256 start)
        internal
        view
        returns (bytes memory args)
    {
        /// @solidity memory-safe-assembly
        assembly {
            args := mload(0x40)
            let n := and(0xffffffffff, sub(extcodesize(instance), 0x57))
            let l := sub(n, and(0xffffff, mul(lt(start, n), start)))
            extcodecopy(instance, args, add(start, 0x37), add(l, 0x40))
            mstore(args, mul(sub(n, start), lt(start, n))) // Store the length.
            mstore(0x40, add(args, add(0x40, mload(args)))) // Allocate memory.
        }
    }

    /// @dev Returns a slice of the immutable arguments on `instance` from `start` to `end`.
    /// `start` and `end` will be clamped to the range `[0, args.length]`.
    /// The `instance` MUST be deployed via the ERC1967I beacon proxy with immutable args functions.
    /// Otherwise, the behavior is undefined.
    /// Out-of-gas reverts if `instance` does not have any code.
    function argsOnERC1967IBeaconProxy(address instance, uint256 start, uint256 end)
        internal
        view
        returns (bytes memory args)
    {
        /// @solidity memory-safe-assembly
        assembly {
            args := mload(0x40)
            if iszero(lt(end, 0xffff)) { end := 0xffff }
            let d := mul(sub(end, start), lt(start, end))
            extcodecopy(instance, args, add(start, 0x37), add(d, 0x20))
            if iszero(and(0xff, mload(add(args, d)))) {
                let n := sub(extcodesize(instance), 0x57)
                returndatacopy(returndatasize(), returndatasize(), shr(40, n))
                d := mul(gt(n, start), sub(d, mul(gt(end, n), sub(end, n))))
            }
            mstore(args, d) // Store the length.
            mstore(add(add(args, 0x20), d), 0) // Zeroize the slot after the bytes.
            mstore(0x40, add(add(args, 0x40), d)) // Allocate memory.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      OTHER OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns `address(0)` if the implementation address cannot be determined.
    function implementationOf(address instance) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            for { extcodecopy(instance, 0x00, 0x00, 0x57) } 1 {} {
                if mload(0x2d) {
                    // ERC1967I and ERC1967IBeaconProxy detection.
                    if or(
                        eq(keccak256(0x00, 0x52), ERC1967I_CODE_HASH),
                        eq(keccak256(0x00, 0x57), ERC1967I_BEACON_PROXY_CODE_HASH)
                    ) {
                        pop(staticcall(gas(), instance, 0x00, 0x01, 0x00, 0x20))
                        result := mload(0x0c)
                        break
                    }
                }
                // 0age clone detection.
                result := mload(0x0b)
                codecopy(0x0b, codesize(), 0x14) // Zeroize the 20 bytes for the address.
                if iszero(xor(keccak256(0x00, 0x2c), CLONE_CODE_HASH)) { break }
                mstore(0x0b, result) // Restore the zeroized memory.
                // CWIA detection.
                result := mload(0x0a)
                codecopy(0x0a, codesize(), 0x14) // Zeroize the 20 bytes for the address.
                if iszero(xor(keccak256(0x00, 0x2d), CWIA_CODE_HASH)) { break }
                mstore(0x0a, result) // Restore the zeroized memory.
                // PUSH0 clone detection.
                result := mload(0x09)
                codecopy(0x09, codesize(), 0x14) // Zeroize the 20 bytes for the address.
                result := shr(xor(keccak256(0x00, 0x2d), PUSH0_CLONE_CODE_HASH), result)
                break
            }
            result := shr(96, result)
            mstore(0x37, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Returns the address when a contract with initialization code hash,
    /// `hash`, is deployed with `salt`, by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictDeterministicAddress(bytes32 hash, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute and store the bytecode hash.
            mstore8(0x00, 0xff) // Write the prefix.
            mstore(0x35, hash)
            mstore(0x01, shl(96, deployer))
            mstore(0x15, salt)
            predicted := keccak256(0x00, 0x55)
            mstore(0x35, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Requires that `salt` starts with either the zero address or `by`.
    function checkStartsWith(bytes32 salt, address by) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            // If the salt does not start with the zero address or `by`.
            if iszero(or(iszero(shr(96, salt)), eq(shr(96, shl(96, by)), shr(96, salt)))) {
                mstore(0x00, 0x0c4549ef) // `SaltDoesNotStartWith()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Returns the `bytes32` at `offset` in `args`, without any bounds checks.
    /// To load an address, you can use `address(bytes20(argLoad(args, offset)))`.
    function argLoad(bytes memory args, uint256 offset) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(add(add(args, 0x20), offset))
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for transient storage operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibTransient.sol)
/// @author Modified from Transient Goodies by Philogy (https://github.com/Philogy/transient-goodies/blob/main/src/TransientBytesLib.sol)
///
/// @dev Note: The functions postfixed with `Compat` will only use transient storage on L1.
/// L2s are super cheap anyway.
/// For best safety, always clear the storage after use.
library LibTransient {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Pointer struct to a `uint256` in transient storage.
    struct TUint256 {
        uint256 _spacer;
    }

    /// @dev Pointer struct to a `int256` in transient storage.
    struct TInt256 {
        uint256 _spacer;
    }

    /// @dev Pointer struct to a `bytes32` in transient storage.
    struct TBytes32 {
        uint256 _spacer;
    }

    /// @dev Pointer struct to a `address` in transient storage.
    struct TAddress {
        uint256 _spacer;
    }

    /// @dev Pointer struct to a `bool` in transient storage.
    struct TBool {
        uint256 _spacer;
    }

    /// @dev Pointer struct to a `bytes` in transient storage.
    struct TBytes {
        uint256 _spacer;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The storage slot seed for converting a transient slot to a storage slot.
    /// `bytes4(keccak256("_LIB_TRANSIENT_COMPAT_SLOT_SEED"))`.
    uint256 private constant _LIB_TRANSIENT_COMPAT_SLOT_SEED = 0x5a0b45f2;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     UINT256 OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns a pointer to a `uint256` in transient storage.
    function tUint256(bytes32 tSlot) internal pure returns (TUint256 storage ptr) {
        /// @solidity memory-safe-assembly
        assembly {
            ptr.slot := tSlot
        }
    }

    /// @dev Returns a pointer to a `uint256` in transient storage.
    function tUint256(uint256 tSlot) internal pure returns (TUint256 storage ptr) {
        /// @solidity memory-safe-assembly
        assembly {
            ptr.slot := tSlot
        }
    }

    /// @dev Returns the value at transient `ptr`.
    function get(TUint256 storage ptr) internal view returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := tload(ptr.slot)
        }
    }

    /// @dev Returns the value at transient `ptr`.
    function getCompat(TUint256 storage ptr) internal view returns (uint256 result) {
        result = block.chainid == 1 ? get(ptr) : _compat(ptr)._spacer;
    }

    /// @dev Sets the value at transient `ptr`.
    function set(TUint256 storage ptr, uint256 value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, value)
        }
    }

    /// @dev Sets the value at transient `ptr`.
    function setCompat(TUint256 storage ptr, uint256 value) internal {
        if (block.chainid == 1) return set(ptr, value);
        _compat(ptr)._spacer = value;
    }

    /// @dev Clears the value at transient `ptr`.
    function clear(TUint256 storage ptr) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, 0)
        }
    }

    /// @dev Clears the value at transient `ptr`.
    function clearCompat(TUint256 storage ptr) internal {
        if (block.chainid == 1) return clear(ptr);
        _compat(ptr)._spacer = 0;
    }

    /// @dev Increments the value at transient `ptr` by 1.
    function inc(TUint256 storage ptr) internal returns (uint256 newValue) {
        set(ptr, newValue = get(ptr) + 1);
    }

    /// @dev Increments the value at transient `ptr` by 1.
    function incCompat(TUint256 storage ptr) internal returns (uint256 newValue) {
        setCompat(ptr, newValue = getCompat(ptr) + 1);
    }

    /// @dev Increments the value at transient `ptr` by `delta`.
    function inc(TUint256 storage ptr, uint256 delta) internal returns (uint256 newValue) {
        set(ptr, newValue = get(ptr) + delta);
    }

    /// @dev Increments the value at transient `ptr` by `delta`.
    function incCompat(TUint256 storage ptr, uint256 delta) internal returns (uint256 newValue) {
        setCompat(ptr, newValue = getCompat(ptr) + delta);
    }

    /// @dev Decrements the value at transient `ptr` by 1.
    function dec(TUint256 storage ptr) internal returns (uint256 newValue) {
        set(ptr, newValue = get(ptr) - 1);
    }

    /// @dev Decrements the value at transient `ptr` by `delta`.
    function decCompat(TUint256 storage ptr) internal returns (uint256 newValue) {
        setCompat(ptr, newValue = getCompat(ptr) - 1);
    }

    /// @dev Decrements the value at transient `ptr` by `delta`.
    function dec(TUint256 storage ptr, uint256 delta) internal returns (uint256 newValue) {
        set(ptr, newValue = get(ptr) - delta);
    }

    /// @dev Decrements the value at transient `ptr` by `delta`.
    function decCompat(TUint256 storage ptr, uint256 delta) internal returns (uint256 newValue) {
        setCompat(ptr, newValue = getCompat(ptr) - delta);
    }

    /// @dev Increments the value at transient `ptr` by `delta`.
    function incSigned(TUint256 storage ptr, int256 delta) internal returns (uint256 newValue) {
        /// @solidity memory-safe-assembly
        assembly {
            let currentValue := tload(ptr.slot)
            newValue := add(currentValue, delta)
            if iszero(eq(lt(newValue, currentValue), slt(delta, 0))) {
                mstore(0x00, 0x4e487b71) // `Panic(uint256)`.
                mstore(0x20, 0x11) // Underflow or overflow panic.
                revert(0x1c, 0x24)
            }
            tstore(ptr.slot, newValue)
        }
    }

    /// @dev Increments the value at transient `ptr` by `delta`.
    function incSignedCompat(TUint256 storage ptr, int256 delta)
        internal
        returns (uint256 newValue)
    {
        if (block.chainid == 1) return incSigned(ptr, delta);
        ptr = _compat(ptr);
        /// @solidity memory-safe-assembly
        assembly {
            let currentValue := sload(ptr.slot)
            newValue := add(currentValue, delta)
            if iszero(eq(lt(newValue, currentValue), slt(delta, 0))) {
                mstore(0x00, 0x4e487b71) // `Panic(uint256)`.
                mstore(0x20, 0x11) // Underflow or overflow panic.
                revert(0x1c, 0x24)
            }
            sstore(ptr.slot, newValue)
        }
    }

    /// @dev Decrements the value at transient `ptr` by `delta`.
    function decSigned(TUint256 storage ptr, int256 delta) internal returns (uint256 newValue) {
        /// @solidity memory-safe-assembly
        assembly {
            let currentValue := tload(ptr.slot)
            newValue := sub(currentValue, delta)
            if iszero(eq(lt(newValue, currentValue), sgt(delta, 0))) {
                mstore(0x00, 0x4e487b71) // `Panic(uint256)`.
                mstore(0x20, 0x11) // Underflow or overflow panic.
                revert(0x1c, 0x24)
            }
            tstore(ptr.slot, newValue)
        }
    }

    /// @dev Decrements the value at transient `ptr` by `delta`.
    function decSignedCompat(TUint256 storage ptr, int256 delta)
        internal
        returns (uint256 newValue)
    {
        if (block.chainid == 1) return decSigned(ptr, delta);
        ptr = _compat(ptr);
        /// @solidity memory-safe-assembly
        assembly {
            let currentValue := sload(ptr.slot)
            newValue := sub(currentValue, delta)
            if iszero(eq(lt(newValue, currentValue), sgt(delta, 0))) {
                mstore(0x00, 0x4e487b71) // `Panic(uint256)`.
                mstore(0x20, 0x11) // Underflow or overflow panic.
                revert(0x1c, 0x24)
            }
            sstore(ptr.slot, newValue)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     INT256 OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns a pointer to a `int256` in transient storage.
    function tInt256(bytes32 tSlot) internal pure returns (TInt256 storage ptr) {
        /// @solidity memory-safe-assembly
        assembly {
            ptr.slot := tSlot
        }
    }

    /// @dev Returns a pointer to a `int256` in transient storage.
    function tInt256(uint256 tSlot) internal pure returns (TInt256 storage ptr) {
        /// @solidity memory-safe-assembly
        assembly {
            ptr.slot := tSlot
        }
    }

    /// @dev Returns the value at transient `ptr`.
    function get(TInt256 storage ptr) internal view returns (int256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := tload(ptr.slot)
        }
    }

    /// @dev Returns the value at transient `ptr`.
    function getCompat(TInt256 storage ptr) internal view returns (int256 result) {
        result = block.chainid == 1 ? get(ptr) : int256(_compat(ptr)._spacer);
    }

    /// @dev Sets the value at transient `ptr`.
    function set(TInt256 storage ptr, int256 value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, value)
        }
    }

    /// @dev Sets the value at transient `ptr`.
    function setCompat(TInt256 storage ptr, int256 value) internal {
        if (block.chainid == 1) return set(ptr, value);
        _compat(ptr)._spacer = uint256(value);
    }

    /// @dev Clears the value at transient `ptr`.
    function clear(TInt256 storage ptr) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, 0)
        }
    }

    /// @dev Clears the value at transient `ptr`.
    function clearCompat(TInt256 storage ptr) internal {
        if (block.chainid == 1) return clear(ptr);
        _compat(ptr)._spacer = 0;
    }

    /// @dev Increments the value at transient `ptr` by 1.
    function inc(TInt256 storage ptr) internal returns (int256 newValue) {
        set(ptr, newValue = get(ptr) + 1);
    }

    /// @dev Increments the value at transient `ptr` by 1.
    function incCompat(TInt256 storage ptr) internal returns (int256 newValue) {
        setCompat(ptr, newValue = getCompat(ptr) + 1);
    }

    /// @dev Increments the value at transient `ptr` by `delta`.
    function inc(TInt256 storage ptr, int256 delta) internal returns (int256 newValue) {
        set(ptr, newValue = get(ptr) + delta);
    }

    /// @dev Increments the value at transient `ptr` by `delta`.
    function incCompat(TInt256 storage ptr, int256 delta) internal returns (int256 newValue) {
        setCompat(ptr, newValue = getCompat(ptr) + delta);
    }

    /// @dev Decrements the value at transient `ptr` by 1.
    function dec(TInt256 storage ptr) internal returns (int256 newValue) {
        set(ptr, newValue = get(ptr) - 1);
    }

    /// @dev Decrements the value at transient `ptr` by 1.
    function decCompat(TInt256 storage ptr) internal returns (int256 newValue) {
        setCompat(ptr, newValue = getCompat(ptr) - 1);
    }

    /// @dev Decrements the value at transient `ptr` by `delta`.
    function dec(TInt256 storage ptr, int256 delta) internal returns (int256 newValue) {
        set(ptr, newValue = get(ptr) - delta);
    }

    /// @dev Decrements the value at transient `ptr` by `delta`.
    function decCompat(TInt256 storage ptr, int256 delta) internal returns (int256 newValue) {
        setCompat(ptr, newValue = getCompat(ptr) - delta);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     BYTES32 OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns a pointer to a `bytes32` in transient storage.
    function tBytes32(bytes32 tSlot) internal pure returns (TBytes32 storage ptr) {
        /// @solidity memory-safe-assembly
        assembly {
            ptr.slot := tSlot
        }
    }

    /// @dev Returns a pointer to a `bytes32` in transient storage.
    function tBytes32(uint256 tSlot) internal pure returns (TBytes32 storage ptr) {
        /// @solidity memory-safe-assembly
        assembly {
            ptr.slot := tSlot
        }
    }

    /// @dev Returns the value at transient `ptr`.
    function get(TBytes32 storage ptr) internal view returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := tload(ptr.slot)
        }
    }

    /// @dev Returns the value at transient `ptr`.
    function getCompat(TBytes32 storage ptr) internal view returns (bytes32 result) {
        result = block.chainid == 1 ? get(ptr) : bytes32(_compat(ptr)._spacer);
    }

    /// @dev Sets the value at transient `ptr`.
    function set(TBytes32 storage ptr, bytes32 value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, value)
        }
    }

    /// @dev Sets the value at transient `ptr`.
    function setCompat(TBytes32 storage ptr, bytes32 value) internal {
        if (block.chainid == 1) return set(ptr, value);
        _compat(ptr)._spacer = uint256(value);
    }

    /// @dev Clears the value at transient `ptr`.
    function clear(TBytes32 storage ptr) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, 0)
        }
    }

    /// @dev Clears the value at transient `ptr`.
    function clearCompat(TBytes32 storage ptr) internal {
        if (block.chainid == 1) return clear(ptr);
        _compat(ptr)._spacer = 0;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     ADDRESS OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns a pointer to a `address` in transient storage.
    function tAddress(bytes32 tSlot) internal pure returns (TAddress storage ptr) {
        /// @solidity memory-safe-assembly
        assembly {
            ptr.slot := tSlot
        }
    }

    /// @dev Returns a pointer to a `address` in transient storage.
    function tAddress(uint256 tSlot) internal pure returns (TAddress storage ptr) {
        /// @solidity memory-safe-assembly
        assembly {
            ptr.slot := tSlot
        }
    }

    /// @dev Returns the value at transient `ptr`.
    function get(TAddress storage ptr) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := tload(ptr.slot)
        }
    }

    /// @dev Returns the value at transient `ptr`.
    function getCompat(TAddress storage ptr) internal view returns (address result) {
        result = block.chainid == 1 ? get(ptr) : address(uint160(_compat(ptr)._spacer));
    }

    /// @dev Sets the value at transient `ptr`.
    function set(TAddress storage ptr, address value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, shr(96, shl(96, value)))
        }
    }

    /// @dev Sets the value at transient `ptr`.
    function setCompat(TAddress storage ptr, address value) internal {
        if (block.chainid == 1) return set(ptr, value);
        _compat(ptr)._spacer = uint160(value);
    }

    /// @dev Clears the value at transient `ptr`.
    function clear(TAddress storage ptr) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, 0)
        }
    }

    /// @dev Clears the value at transient `ptr`.
    function clearCompat(TAddress storage ptr) internal {
        if (block.chainid == 1) return clear(ptr);
        _compat(ptr)._spacer = 0;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      BOOL OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns a pointer to a `bool` in transient storage.
    function tBool(bytes32 tSlot) internal pure returns (TBool storage ptr) {
        /// @solidity memory-safe-assembly
        assembly {
            ptr.slot := tSlot
        }
    }

    /// @dev Returns a pointer to a `bool` in transient storage.
    function tBool(uint256 tSlot) internal pure returns (TBool storage ptr) {
        /// @solidity memory-safe-assembly
        assembly {
            ptr.slot := tSlot
        }
    }

    /// @dev Returns the value at transient `ptr`.
    function get(TBool storage ptr) internal view returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := tload(ptr.slot)
        }
    }

    /// @dev Returns the value at transient `ptr`.
    function getCompat(TBool storage ptr) internal view returns (bool result) {
        result = block.chainid == 1 ? get(ptr) : _compat(ptr)._spacer != 0;
    }

    /// @dev Sets the value at transient `ptr`.
    function set(TBool storage ptr, bool value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, iszero(iszero(value)))
        }
    }

    /// @dev Sets the value at transient `ptr`.
    function setCompat(TBool storage ptr, bool value) internal {
        if (block.chainid == 1) return set(ptr, value);
        ptr = _compat(ptr);
        /// @solidity memory-safe-assembly
        assembly {
            sstore(ptr.slot, iszero(iszero(value)))
        }
    }

    /// @dev Clears the value at transient `ptr`.
    function clear(TBool storage ptr) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, 0)
        }
    }

    /// @dev Clears the value at transient `ptr`.
    function clearCompat(TBool storage ptr) internal {
        if (block.chainid == 1) return clear(ptr);
        _compat(ptr)._spacer = 0;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      BYTES OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns a pointer to a `bytes` in transient storage.
    function tBytes(bytes32 tSlot) internal pure returns (TBytes storage ptr) {
        /// @solidity memory-safe-assembly
        assembly {
            ptr.slot := tSlot
        }
    }

    /// @dev Returns a pointer to a `bytes` in transient storage.
    function tBytes(uint256 tSlot) internal pure returns (TBytes storage ptr) {
        /// @solidity memory-safe-assembly
        assembly {
            ptr.slot := tSlot
        }
    }

    /// @dev Returns the length of the bytes stored at transient `ptr`.
    function length(TBytes storage ptr) internal view returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := shr(224, tload(ptr.slot))
        }
    }

    /// @dev Returns the length of the bytes stored at transient `ptr`.
    function lengthCompat(TBytes storage ptr) internal view returns (uint256 result) {
        if (block.chainid == 1) return length(ptr);
        ptr = _compat(ptr);
        /// @solidity memory-safe-assembly
        assembly {
            result := shr(224, sload(ptr.slot))
        }
    }

    /// @dev Returns the bytes stored at transient `ptr`.
    function get(TBytes storage ptr) internal view returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(result, 0x00)
            mstore(add(result, 0x1c), tload(ptr.slot)) // Length and first `0x1c` bytes.
            let n := mload(result)
            let e := add(add(result, 0x20), n)
            if iszero(lt(n, 0x1d)) {
                mstore(0x00, ptr.slot)
                let d := sub(keccak256(0x00, 0x20), result)
                for { let o := add(result, 0x3c) } 1 {} {
                    mstore(o, tload(add(o, d)))
                    o := add(o, 0x20)
                    if iszero(lt(o, e)) { break }
                }
            }
            mstore(e, 0) // Zeroize the slot after the string.
            mstore(0x40, add(0x20, e)) // Allocate memory.
        }
    }

    /// @dev Returns the bytes stored at transient `ptr`.
    function getCompat(TBytes storage ptr) internal view returns (bytes memory result) {
        if (block.chainid == 1) return get(ptr);
        ptr = _compat(ptr);
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(result, 0x00)
            mstore(add(result, 0x1c), sload(ptr.slot)) // Length and first `0x1c` bytes.
            let n := mload(result)
            let e := add(add(result, 0x20), n)
            if iszero(lt(n, 0x1d)) {
                mstore(0x00, ptr.slot)
                let d := sub(keccak256(0x00, 0x20), result)
                for { let o := add(result, 0x3c) } 1 {} {
                    mstore(o, sload(add(o, d)))
                    o := add(o, 0x20)
                    if iszero(lt(o, e)) { break }
                }
            }
            mstore(e, 0) // Zeroize the slot after the string.
            mstore(0x40, add(0x20, e)) // Allocate memory.
        }
    }

    /// @dev Sets the value at transient `ptr`.
    function set(TBytes storage ptr, bytes memory value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, mload(add(value, 0x1c)))
            if iszero(lt(mload(value), 0x1d)) {
                mstore(0x00, ptr.slot)
                let e := add(add(value, 0x20), mload(value))
                let d := sub(keccak256(0x00, or(0x20, sub(0, shr(32, mload(value))))), value)
                for { let o := add(value, 0x3c) } 1 {} {
                    tstore(add(o, d), mload(o))
                    o := add(o, 0x20)
                    if iszero(lt(o, e)) { break }
                }
            }
        }
    }

    /// @dev Sets the value at transient `ptr`.
    function setCompat(TBytes storage ptr, bytes memory value) internal {
        if (block.chainid == 1) return set(ptr, value);
        ptr = _compat(ptr);
        /// @solidity memory-safe-assembly
        assembly {
            sstore(ptr.slot, mload(add(value, 0x1c)))
            if iszero(lt(mload(value), 0x1d)) {
                mstore(0x00, ptr.slot)
                let e := add(add(value, 0x20), mload(value))
                let d := sub(keccak256(0x00, or(0x20, sub(0, shr(32, mload(value))))), value)
                for { let o := add(value, 0x3c) } 1 {} {
                    sstore(add(o, d), mload(o))
                    o := add(o, 0x20)
                    if iszero(lt(o, e)) { break }
                }
            }
        }
    }

    /// @dev Sets the value at transient `ptr`.
    function setCalldata(TBytes storage ptr, bytes calldata value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, or(shl(224, value.length), shr(32, calldataload(value.offset))))
            if iszero(lt(value.length, 0x1d)) {
                mstore(0x00, ptr.slot)
                let e := add(value.offset, value.length)
                // forgefmt: disable-next-item
                let d := add(sub(keccak256(0x00, or(0x20, sub(0, shr(32, value.length)))),
                    value.offset), 0x20)
                for { let o := add(value.offset, 0x1c) } 1 {} {
                    tstore(add(o, d), calldataload(o))
                    o := add(o, 0x20)
                    if iszero(lt(o, e)) { break }
                }
            }
        }
    }

    /// @dev Sets the value at transient `ptr`.
    function setCalldataCompat(TBytes storage ptr, bytes calldata value) internal {
        if (block.chainid == 1) return setCalldata(ptr, value);
        ptr = _compat(ptr);
        /// @solidity memory-safe-assembly
        assembly {
            sstore(ptr.slot, or(shl(224, value.length), shr(32, calldataload(value.offset))))
            if iszero(lt(value.length, 0x1d)) {
                mstore(0x00, ptr.slot)
                let e := add(value.offset, value.length)
                // forgefmt: disable-next-item
                let d := add(sub(keccak256(0x00, or(0x20, sub(0, shr(32, value.length)))),
                    value.offset), 0x20)
                for { let o := add(value.offset, 0x1c) } 1 {} {
                    sstore(add(o, d), calldataload(o))
                    o := add(o, 0x20)
                    if iszero(lt(o, e)) { break }
                }
            }
        }
    }

    /// @dev Clears the value at transient `ptr`.
    function clear(TBytes storage ptr) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, 0)
        }
    }

    /// @dev Clears the value at transient `ptr`.
    function clearCompat(TBytes storage ptr) internal {
        if (block.chainid == 1) return clear(ptr);
        _compat(ptr)._spacer = 0;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns a regular storage pointer used for compatibility.
    function _compat(TUint256 storage ptr) private pure returns (TUint256 storage c) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x04, _LIB_TRANSIENT_COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            c.slot := keccak256(0x00, 0x24)
        }
    }

    /// @dev Returns a regular storage pointer used for compatibility.
    function _compat(TInt256 storage ptr) private pure returns (TInt256 storage c) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x04, _LIB_TRANSIENT_COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            c.slot := keccak256(0x00, 0x24)
        }
    }

    /// @dev Returns a regular storage pointer used for compatibility.
    function _compat(TBytes32 storage ptr) private pure returns (TBytes32 storage c) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x04, _LIB_TRANSIENT_COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            c.slot := keccak256(0x00, 0x24)
        }
    }

    /// @dev Returns a regular storage pointer used for compatibility.
    function _compat(TAddress storage ptr) private pure returns (TAddress storage c) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x04, _LIB_TRANSIENT_COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            c.slot := keccak256(0x00, 0x24)
        }
    }

    /// @dev Returns a regular storage pointer used for compatibility.
    function _compat(TBool storage ptr) private pure returns (TBool storage c) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x04, _LIB_TRANSIENT_COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            c.slot := keccak256(0x00, 0x24)
        }
    }

    /// @dev Returns a regular storage pointer used for compatibility.
    function _compat(TBytes storage ptr) private pure returns (TBytes storage c) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x04, _LIB_TRANSIENT_COMPAT_SLOT_SEED)
            mstore(0x00, ptr.slot)
            c.slot := keccak256(0x00, 0x24)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice UUPS proxy mixin.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/UUPSUpgradeable.sol)
/// @author Modified from OpenZeppelin
/// (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/utils/UUPSUpgradeable.sol)
///
/// @dev Note:
/// - This implementation is intended to be used with ERC1967 proxies.
/// See: `LibClone.deployERC1967` and related functions.
/// - This implementation is NOT compatible with legacy OpenZeppelin proxies
/// which do not store the implementation at `_ERC1967_IMPLEMENTATION_SLOT`.
abstract contract UUPSUpgradeable {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The upgrade failed.
    error UpgradeFailed();

    /// @dev The call is from an unauthorized call context.
    error UnauthorizedCallContext();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         IMMUTABLES                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev For checking if the context is a delegate call.
    uint256 private immutable __self = uint256(uint160(address(this)));

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Emitted when the proxy's implementation is upgraded.
    event Upgraded(address indexed implementation);

    /// @dev `keccak256(bytes("Upgraded(address)"))`.
    uint256 private constant _UPGRADED_EVENT_SIGNATURE =
        0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The ERC-1967 storage slot for the implementation in the proxy.
    /// `uint256(keccak256("eip1967.proxy.implementation")) - 1`.
    bytes32 internal constant _ERC1967_IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      UUPS OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Please override this function to check if `msg.sender` is authorized
    /// to upgrade the proxy to `newImplementation`, reverting if not.
    /// ```
    ///     function _authorizeUpgrade(address) internal override onlyOwner {}
    /// ```
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /// @dev Returns the storage slot used by the implementation,
    /// as specified in [ERC1822](https://eips.ethereum.org/EIPS/eip-1822).
    ///
    /// Note: The `notDelegated` modifier prevents accidental upgrades to
    /// an implementation that is a proxy contract.
    function proxiableUUID() public view virtual notDelegated returns (bytes32) {
        // This function must always return `_ERC1967_IMPLEMENTATION_SLOT` to comply with ERC1967.
        return _ERC1967_IMPLEMENTATION_SLOT;
    }

    /// @dev Upgrades the proxy's implementation to `newImplementation`.
    /// Emits a {Upgraded} event.
    ///
    /// Note: Passing in empty `data` skips the delegatecall to `newImplementation`.
    function upgradeToAndCall(address newImplementation, bytes calldata data)
        public
        payable
        virtual
        onlyProxy
    {
        _authorizeUpgrade(newImplementation);
        /// @solidity memory-safe-assembly
        assembly {
            newImplementation := shr(96, shl(96, newImplementation)) // Clears upper 96 bits.
            mstore(0x00, returndatasize())
            mstore(0x01, 0x52d1902d) // `proxiableUUID()`.
            let s := _ERC1967_IMPLEMENTATION_SLOT
            // Check if `newImplementation` implements `proxiableUUID` correctly.
            if iszero(eq(mload(staticcall(gas(), newImplementation, 0x1d, 0x04, 0x01, 0x20)), s)) {
                mstore(0x01, 0x55299b49) // `UpgradeFailed()`.
                revert(0x1d, 0x04)
            }
            // Emit the {Upgraded} event.
            log2(codesize(), 0x00, _UPGRADED_EVENT_SIGNATURE, newImplementation)
            sstore(s, newImplementation) // Updates the implementation.

            // Perform a delegatecall to `newImplementation` if `data` is non-empty.
            if data.length {
                // Forwards the `data` to `newImplementation` via delegatecall.
                let m := mload(0x40)
                calldatacopy(m, data.offset, data.length)
                if iszero(delegatecall(gas(), newImplementation, m, data.length, codesize(), 0x00))
                {
                    // Bubble up the revert if the call reverts.
                    returndatacopy(m, 0x00, returndatasize())
                    revert(m, returndatasize())
                }
            }
        }
    }

    /// @dev Requires that the execution is performed through a proxy.
    modifier onlyProxy() {
        uint256 s = __self;
        /// @solidity memory-safe-assembly
        assembly {
            // To enable use cases with an immutable default implementation in the bytecode,
            // (see: ERC6551Proxy), we don't require that the proxy address must match the
            // value stored in the implementation slot, which may not be initialized.
            if eq(s, address()) {
                mstore(0x00, 0x9f03a026) // `UnauthorizedCallContext()`.
                revert(0x1c, 0x04)
            }
        }
        _;
    }

    /// @dev Requires that the execution is NOT performed via delegatecall.
    /// This is the opposite of `onlyProxy`.
    modifier notDelegated() {
        uint256 s = __self;
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(eq(s, address())) {
                mstore(0x00, 0x9f03a026) // `UnauthorizedCallContext()`.
                revert(0x1c, 0x04)
            }
        }
        _;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for efficiently performing keccak256 hashes.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/EfficientHashLib.sol)
/// @dev To avoid stack-too-deep, you can use:
/// ```
/// bytes32[] memory buffer = EfficientHashLib.malloc(10);
/// EfficientHashLib.set(buffer, 0, value0);
/// ..
/// EfficientHashLib.set(buffer, 9, value9);
/// bytes32 finalHash = EfficientHashLib.hash(buffer);
/// ```
library EfficientHashLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*               MALLOC-LESS HASHING OPERATIONS               */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns `keccak256(abi.encode(v0))`.
    function hash(bytes32 v0) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, v0)
            result := keccak256(0x00, 0x20)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0))`.
    function hash(uint256 v0) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, v0)
            result := keccak256(0x00, 0x20)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, v1))`.
    function hash(bytes32 v0, bytes32 v1) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            result := keccak256(0x00, 0x40)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, v1))`.
    function hash(uint256 v0, uint256 v1) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, v0)
            mstore(0x20, v1)
            result := keccak256(0x00, 0x40)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, v1, v2))`.
    function hash(bytes32 v0, bytes32 v1, bytes32 v2) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            result := keccak256(m, 0x60)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, v1, v2))`.
    function hash(uint256 v0, uint256 v1, uint256 v2) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            result := keccak256(m, 0x60)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, v1, v2, v3))`.
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3)
        internal
        pure
        returns (bytes32 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            result := keccak256(m, 0x80)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, v1, v2, v3))`.
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3)
        internal
        pure
        returns (bytes32 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            result := keccak256(m, 0x80)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v4))`.
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4)
        internal
        pure
        returns (bytes32 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            result := keccak256(m, 0xa0)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v4))`.
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4)
        internal
        pure
        returns (bytes32 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            result := keccak256(m, 0xa0)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v5))`.
    function hash(bytes32 v0, bytes32 v1, bytes32 v2, bytes32 v3, bytes32 v4, bytes32 v5)
        internal
        pure
        returns (bytes32 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            result := keccak256(m, 0xc0)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v5))`.
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4, uint256 v5)
        internal
        pure
        returns (bytes32 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            result := keccak256(m, 0xc0)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v6))`.
    function hash(
        bytes32 v0,
        bytes32 v1,
        bytes32 v2,
        bytes32 v3,
        bytes32 v4,
        bytes32 v5,
        bytes32 v6
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            mstore(add(m, 0xc0), v6)
            result := keccak256(m, 0xe0)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v6))`.
    function hash(
        uint256 v0,
        uint256 v1,
        uint256 v2,
        uint256 v3,
        uint256 v4,
        uint256 v5,
        uint256 v6
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            mstore(add(m, 0xc0), v6)
            result := keccak256(m, 0xe0)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v7))`.
    function hash(
        bytes32 v0,
        bytes32 v1,
        bytes32 v2,
        bytes32 v3,
        bytes32 v4,
        bytes32 v5,
        bytes32 v6,
        bytes32 v7
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            mstore(add(m, 0xc0), v6)
            mstore(add(m, 0xe0), v7)
            result := keccak256(m, 0x100)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v7))`.
    function hash(
        uint256 v0,
        uint256 v1,
        uint256 v2,
        uint256 v3,
        uint256 v4,
        uint256 v5,
        uint256 v6,
        uint256 v7
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            mstore(add(m, 0xc0), v6)
            mstore(add(m, 0xe0), v7)
            result := keccak256(m, 0x100)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v8))`.
    function hash(
        bytes32 v0,
        bytes32 v1,
        bytes32 v2,
        bytes32 v3,
        bytes32 v4,
        bytes32 v5,
        bytes32 v6,
        bytes32 v7,
        bytes32 v8
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            mstore(add(m, 0xc0), v6)
            mstore(add(m, 0xe0), v7)
            mstore(add(m, 0x100), v8)
            result := keccak256(m, 0x120)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v8))`.
    function hash(
        uint256 v0,
        uint256 v1,
        uint256 v2,
        uint256 v3,
        uint256 v4,
        uint256 v5,
        uint256 v6,
        uint256 v7,
        uint256 v8
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            mstore(add(m, 0xc0), v6)
            mstore(add(m, 0xe0), v7)
            mstore(add(m, 0x100), v8)
            result := keccak256(m, 0x120)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v9))`.
    function hash(
        bytes32 v0,
        bytes32 v1,
        bytes32 v2,
        bytes32 v3,
        bytes32 v4,
        bytes32 v5,
        bytes32 v6,
        bytes32 v7,
        bytes32 v8,
        bytes32 v9
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            mstore(add(m, 0xc0), v6)
            mstore(add(m, 0xe0), v7)
            mstore(add(m, 0x100), v8)
            mstore(add(m, 0x120), v9)
            result := keccak256(m, 0x140)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v9))`.
    function hash(
        uint256 v0,
        uint256 v1,
        uint256 v2,
        uint256 v3,
        uint256 v4,
        uint256 v5,
        uint256 v6,
        uint256 v7,
        uint256 v8,
        uint256 v9
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            mstore(add(m, 0xc0), v6)
            mstore(add(m, 0xe0), v7)
            mstore(add(m, 0x100), v8)
            mstore(add(m, 0x120), v9)
            result := keccak256(m, 0x140)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v10))`.
    function hash(
        bytes32 v0,
        bytes32 v1,
        bytes32 v2,
        bytes32 v3,
        bytes32 v4,
        bytes32 v5,
        bytes32 v6,
        bytes32 v7,
        bytes32 v8,
        bytes32 v9,
        bytes32 v10
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            mstore(add(m, 0xc0), v6)
            mstore(add(m, 0xe0), v7)
            mstore(add(m, 0x100), v8)
            mstore(add(m, 0x120), v9)
            mstore(add(m, 0x140), v10)
            result := keccak256(m, 0x160)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v10))`.
    function hash(
        uint256 v0,
        uint256 v1,
        uint256 v2,
        uint256 v3,
        uint256 v4,
        uint256 v5,
        uint256 v6,
        uint256 v7,
        uint256 v8,
        uint256 v9,
        uint256 v10
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            mstore(add(m, 0xc0), v6)
            mstore(add(m, 0xe0), v7)
            mstore(add(m, 0x100), v8)
            mstore(add(m, 0x120), v9)
            mstore(add(m, 0x140), v10)
            result := keccak256(m, 0x160)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v11))`.
    function hash(
        bytes32 v0,
        bytes32 v1,
        bytes32 v2,
        bytes32 v3,
        bytes32 v4,
        bytes32 v5,
        bytes32 v6,
        bytes32 v7,
        bytes32 v8,
        bytes32 v9,
        bytes32 v10,
        bytes32 v11
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            mstore(add(m, 0xc0), v6)
            mstore(add(m, 0xe0), v7)
            mstore(add(m, 0x100), v8)
            mstore(add(m, 0x120), v9)
            mstore(add(m, 0x140), v10)
            mstore(add(m, 0x160), v11)
            result := keccak256(m, 0x180)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v11))`.
    function hash(
        uint256 v0,
        uint256 v1,
        uint256 v2,
        uint256 v3,
        uint256 v4,
        uint256 v5,
        uint256 v6,
        uint256 v7,
        uint256 v8,
        uint256 v9,
        uint256 v10,
        uint256 v11
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            mstore(add(m, 0xc0), v6)
            mstore(add(m, 0xe0), v7)
            mstore(add(m, 0x100), v8)
            mstore(add(m, 0x120), v9)
            mstore(add(m, 0x140), v10)
            mstore(add(m, 0x160), v11)
            result := keccak256(m, 0x180)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v12))`.
    function hash(
        bytes32 v0,
        bytes32 v1,
        bytes32 v2,
        bytes32 v3,
        bytes32 v4,
        bytes32 v5,
        bytes32 v6,
        bytes32 v7,
        bytes32 v8,
        bytes32 v9,
        bytes32 v10,
        bytes32 v11,
        bytes32 v12
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            mstore(add(m, 0xc0), v6)
            mstore(add(m, 0xe0), v7)
            mstore(add(m, 0x100), v8)
            mstore(add(m, 0x120), v9)
            mstore(add(m, 0x140), v10)
            mstore(add(m, 0x160), v11)
            mstore(add(m, 0x180), v12)
            result := keccak256(m, 0x1a0)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v12))`.
    function hash(
        uint256 v0,
        uint256 v1,
        uint256 v2,
        uint256 v3,
        uint256 v4,
        uint256 v5,
        uint256 v6,
        uint256 v7,
        uint256 v8,
        uint256 v9,
        uint256 v10,
        uint256 v11,
        uint256 v12
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            mstore(add(m, 0xc0), v6)
            mstore(add(m, 0xe0), v7)
            mstore(add(m, 0x100), v8)
            mstore(add(m, 0x120), v9)
            mstore(add(m, 0x140), v10)
            mstore(add(m, 0x160), v11)
            mstore(add(m, 0x180), v12)
            result := keccak256(m, 0x1a0)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v13))`.
    function hash(
        bytes32 v0,
        bytes32 v1,
        bytes32 v2,
        bytes32 v3,
        bytes32 v4,
        bytes32 v5,
        bytes32 v6,
        bytes32 v7,
        bytes32 v8,
        bytes32 v9,
        bytes32 v10,
        bytes32 v11,
        bytes32 v12,
        bytes32 v13
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            mstore(add(m, 0xc0), v6)
            mstore(add(m, 0xe0), v7)
            mstore(add(m, 0x100), v8)
            mstore(add(m, 0x120), v9)
            mstore(add(m, 0x140), v10)
            mstore(add(m, 0x160), v11)
            mstore(add(m, 0x180), v12)
            mstore(add(m, 0x1a0), v13)
            result := keccak256(m, 0x1c0)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v13))`.
    function hash(
        uint256 v0,
        uint256 v1,
        uint256 v2,
        uint256 v3,
        uint256 v4,
        uint256 v5,
        uint256 v6,
        uint256 v7,
        uint256 v8,
        uint256 v9,
        uint256 v10,
        uint256 v11,
        uint256 v12,
        uint256 v13
    ) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            mstore(add(m, 0xa0), v5)
            mstore(add(m, 0xc0), v6)
            mstore(add(m, 0xe0), v7)
            mstore(add(m, 0x100), v8)
            mstore(add(m, 0x120), v9)
            mstore(add(m, 0x140), v10)
            mstore(add(m, 0x160), v11)
            mstore(add(m, 0x180), v12)
            mstore(add(m, 0x1a0), v13)
            result := keccak256(m, 0x1c0)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*             BYTES32 BUFFER HASHING OPERATIONS              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns `keccak256(abi.encode(buffer[0], .., buffer[buffer.length - 1]))`.
    function hash(bytes32[] memory buffer) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := keccak256(add(buffer, 0x20), shl(5, mload(buffer)))
        }
    }

    /// @dev Sets `buffer[i]` to `value`, without a bounds check.
    /// Returns the `buffer` for function chaining.
    function set(bytes32[] memory buffer, uint256 i, bytes32 value)
        internal
        pure
        returns (bytes32[] memory)
    {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(add(buffer, shl(5, add(1, i))), value)
        }
        return buffer;
    }

    /// @dev Sets `buffer[i]` to `value`, without a bounds check.
    /// Returns the `buffer` for function chaining.
    function set(bytes32[] memory buffer, uint256 i, uint256 value)
        internal
        pure
        returns (bytes32[] memory)
    {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(add(buffer, shl(5, add(1, i))), value)
        }
        return buffer;
    }

    /// @dev Returns `new bytes32[](n)`, without zeroing out the memory.
    function malloc(uint256 n) internal pure returns (bytes32[] memory buffer) {
        /// @solidity memory-safe-assembly
        assembly {
            buffer := mload(0x40)
            mstore(buffer, n)
            mstore(0x40, add(shl(5, add(1, n)), buffer))
        }
    }

    /// @dev Frees memory that has been allocated for `buffer`.
    /// No-op if `buffer.length` is zero, or if new memory has been allocated after `buffer`.
    function free(bytes32[] memory buffer) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(buffer)
            mstore(shl(6, lt(iszero(n), eq(add(shl(5, add(1, n)), buffer), mload(0x40)))), buffer)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      EQUALITY CHECKS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns `a == abi.decode(b, (bytes32))`.
    function eq(bytes32 a, bytes memory b) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := and(eq(0x20, mload(b)), eq(a, mload(add(b, 0x20))))
        }
    }

    /// @dev Returns `abi.decode(a, (bytes32)) == a`.
    function eq(bytes memory a, bytes32 b) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := and(eq(0x20, mload(a)), eq(b, mload(add(a, 0x20))))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*               BYTE SLICE HASHING OPERATIONS                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the keccak256 of the slice from `start` to `end` (exclusive).
    /// `start` and `end` are byte offsets.
    function hash(bytes memory b, uint256 start, uint256 end)
        internal
        pure
        returns (bytes32 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(b)
            end := xor(end, mul(xor(end, n), lt(n, end)))
            start := xor(start, mul(xor(start, n), lt(n, start)))
            result := keccak256(add(add(b, 0x20), start), mul(gt(end, start), sub(end, start)))
        }
    }

    /// @dev Returns the keccak256 of the slice from `start` to the end of the bytes.
    function hash(bytes memory b, uint256 start) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(b)
            start := xor(start, mul(xor(start, n), lt(n, start)))
            result := keccak256(add(add(b, 0x20), start), mul(gt(n, start), sub(n, start)))
        }
    }

    /// @dev Returns the keccak256 of the bytes.
    function hash(bytes memory b) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := keccak256(add(b, 0x20), mload(b))
        }
    }

    /// @dev Returns the keccak256 of the slice from `start` to `end` (exclusive).
    /// `start` and `end` are byte offsets.
    function hashCalldata(bytes calldata b, uint256 start, uint256 end)
        internal
        pure
        returns (bytes32 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            end := xor(end, mul(xor(end, b.length), lt(b.length, end)))
            start := xor(start, mul(xor(start, b.length), lt(b.length, start)))
            let n := mul(gt(end, start), sub(end, start))
            calldatacopy(mload(0x40), add(b.offset, start), n)
            result := keccak256(mload(0x40), n)
        }
    }

    /// @dev Returns the keccak256 of the slice from `start` to the end of the bytes.
    function hashCalldata(bytes calldata b, uint256 start) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            start := xor(start, mul(xor(start, b.length), lt(b.length, start)))
            let n := mul(gt(b.length, start), sub(b.length, start))
            calldatacopy(mload(0x40), add(b.offset, start), n)
            result := keccak256(mload(0x40), n)
        }
    }

    /// @dev Returns the keccak256 of the bytes.
    function hashCalldata(bytes calldata b) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            calldatacopy(mload(0x40), b.offset, b.length)
            result := keccak256(mload(0x40), b.length)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      SHA2-256 HELPERS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns `sha256(abi.encode(b))`. Yes, it's more efficient.
    function sha2(bytes32 b) internal view returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, b)
            result := mload(staticcall(gas(), 2, 0x00, 0x20, 0x01, 0x20))
            if iszero(returndatasize()) { invalid() }
        }
    }

    /// @dev Returns the sha256 of the slice from `start` to `end` (exclusive).
    /// `start` and `end` are byte offsets.
    function sha2(bytes memory b, uint256 start, uint256 end)
        internal
        view
        returns (bytes32 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(b)
            end := xor(end, mul(xor(end, n), lt(n, end)))
            start := xor(start, mul(xor(start, n), lt(n, start)))
            // forgefmt: disable-next-item
            result := mload(staticcall(gas(), 2, add(add(b, 0x20), start),
                mul(gt(end, start), sub(end, start)), 0x01, 0x20))
            if iszero(returndatasize()) { invalid() }
        }
    }

    /// @dev Returns the sha256 of the slice from `start` to the end of the bytes.
    function sha2(bytes memory b, uint256 start) internal view returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(b)
            start := xor(start, mul(xor(start, n), lt(n, start)))
            // forgefmt: disable-next-item
            result := mload(staticcall(gas(), 2, add(add(b, 0x20), start),
                mul(gt(n, start), sub(n, start)), 0x01, 0x20))
            if iszero(returndatasize()) { invalid() }
        }
    }

    /// @dev Returns the sha256 of the bytes.
    function sha2(bytes memory b) internal view returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(staticcall(gas(), 2, add(b, 0x20), mload(b), 0x01, 0x20))
            if iszero(returndatasize()) { invalid() }
        }
    }

    /// @dev Returns the sha256 of the slice from `start` to `end` (exclusive).
    /// `start` and `end` are byte offsets.
    function sha2Calldata(bytes calldata b, uint256 start, uint256 end)
        internal
        view
        returns (bytes32 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            end := xor(end, mul(xor(end, b.length), lt(b.length, end)))
            start := xor(start, mul(xor(start, b.length), lt(b.length, start)))
            let n := mul(gt(end, start), sub(end, start))
            calldatacopy(mload(0x40), add(b.offset, start), n)
            result := mload(staticcall(gas(), 2, mload(0x40), n, 0x01, 0x20))
            if iszero(returndatasize()) { invalid() }
        }
    }

    /// @dev Returns the sha256 of the slice from `start` to the end of the bytes.
    function sha2Calldata(bytes calldata b, uint256 start) internal view returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            start := xor(start, mul(xor(start, b.length), lt(b.length, start)))
            let n := mul(gt(b.length, start), sub(b.length, start))
            calldatacopy(mload(0x40), add(b.offset, start), n)
            result := mload(staticcall(gas(), 2, mload(0x40), n, 0x01, 0x20))
            if iszero(returndatasize()) { invalid() }
        }
    }

    /// @dev Returns the sha256 of the bytes.
    function sha2Calldata(bytes calldata b) internal view returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            calldatacopy(mload(0x40), b.offset, b.length)
            result := mload(staticcall(gas(), 2, mload(0x40), b.length, 0x01, 0x20))
            if iszero(returndatasize()) { invalid() }
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

/// @notice Standard interface for deploying pools
interface IPoolDeployer {
    function deploy(address target, address principalToken, bytes calldata initArgs)
        external
        payable
        returns (address);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {LibClone} from "solady/src/utils/LibClone.sol";
import {Initializable} from "solady/src/utils/Initializable.sol";

import {Factory} from "../Factory.sol";
import {AccessManager, AccessManaged} from "./AccessManager.sol";
import {Errors} from "../Errors.sol";

/// @dev Minimal proxy with CWIA implementation for modules. (LibClone.clone(implementation, args))
/// args = abi.encode(principalToken, data) where data is module specific bytes-type data
abstract contract BaseModule is AccessManaged, Initializable {
    uint256 constant CWIA_ARG_OFFSET = 0x00;

    function VERSION() external pure virtual returns (bytes32);

    function i_factory() public view returns (Factory) {
        (bool s, bytes memory ret) = i_principalToken().staticcall(abi.encodeWithSignature("i_factory()"));
        if (!s) revert Errors.Module_CallFailed();
        return Factory(abi.decode(ret, (address)));
    }

    function i_accessManager() public view override returns (AccessManager) {
        (bool s, bytes memory ret) = i_principalToken().staticcall(abi.encodeWithSignature("i_accessManager()"));
        if (!s) revert Errors.Module_CallFailed();
        return AccessManager(abi.decode(ret, (address)));
    }

    function i_principalToken() public view returns (address) {
        bytes memory arg = LibClone.argsOnClone(address(this), CWIA_ARG_OFFSET, CWIA_ARG_OFFSET + 0x20);
        return abi.decode(arg, (address));
    }

    /// @dev This function SHOULD be overridden by inheriting contracts and initializers should be added.
    function initialize() external virtual {
        // Do nothing by default
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {OwnableRoles} from "solady/src/auth/OwnableRoles.sol";
import {Initializable} from "solady/src/utils/Initializable.sol";
import {Multicallable} from "solady/src/utils/Multicallable.sol";

import "../Constants.sol" as Constants;
import {Errors} from "../Errors.sol";

/// @notice Access Manager module for managing single owner and multiple roles for multiple contracts and functions.
/// @dev Each PrincipalToken instance will have its own AccessManager instance to manage access control.
/// @dev AccessManager is a minimal proxy implementation to reduce deployment costs.
/// @dev Note: AccessManager must be initialized after deployment to set initial owner.
contract AccessManager is OwnableRoles, Initializable, Multicallable {
    /// @notice Mapping of target contracts to their function selectors and roles that are allowed to call the function
    mapping(address target => mapping(bytes4 selector => uint256 roles)) private s_targets;

    /// @notice Emitted when roles are granted for a target function
    /// @param target The address of the target contract
    /// @param selector The function selector
    /// @param roles The roles being granted
    event TargetFunctionRolesGranted(address indexed target, bytes4 indexed selector, uint256 indexed roles);

    /// @notice Emitted when roles are revoked for a target function
    /// @param target The address of the target contract
    /// @param selector The function selector
    /// @param roles The roles being revoked
    event TargetFunctionRolesRevoked(address indexed target, bytes4 indexed selector, uint256 indexed roles);

    /// @notice Initializes the contract by setting the initial owner
    /// @param curator The address of the initial owner
    function initializeOwner(address curator) external initializer {
        _initializeOwner(curator);
    }

    /// @dev Allows the owner to grant `user` `roles`.
    /// If the `user` already has a role, then it will be an no-op for the role.
    function grantRoles(address user, uint256 roles) public payable override onlyOwnerOrCanCall {
        _grantRoles(user, roles);
    }

    /// @dev Allows the owner to remove `user` `roles`.
    /// If the `user` does not have a role, then it will be an no-op for the role.
    function revokeRoles(address user, uint256 roles) public payable override onlyOwnerOrCanCall {
        _removeRoles(user, roles);
    }

    /// @notice Grants roles for multiple function selectors on a target contract
    /// @param target The address of the target contract
    /// @param selectors An array of function selectors
    /// @param roles The roles to grant
    function grantTargetFunctionRoles(address target, bytes4[] calldata selectors, uint256 roles)
        public
        payable
        onlyOwnerOrCanCall
    {
        uint256 length = selectors.length;
        for (uint256 i = 0; i != length;) {
            _grantTargetFunctionRoles(target, selectors[i], roles);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Revokes roles for multiple function selectors on a target contract
    /// @param target The address of the target contract
    /// @param selectors An array of function selectors
    /// @param roles The roles to revoke
    function revokeTargetFunctionRoles(address target, bytes4[] calldata selectors, uint256 roles)
        public
        payable
        onlyOwnerOrCanCall
    {
        uint256 length = selectors.length;
        for (uint256 i = 0; i != length;) {
            _revokeTargetFunctionRoles(target, selectors[i], roles);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Internal function to grant a role for a specific function on a target contract
    /// @param target The address of the target contract
    /// @param selector The function selector
    /// @param roles The role to grant
    function _grantTargetFunctionRoles(address target, bytes4 selector, uint256 roles) internal {
        s_targets[target][selector] = s_targets[target][selector] | roles;
        emit TargetFunctionRolesGranted(target, selector, roles);
    }

    /// @notice Internal function to revoke a role for a specific function on a target contract
    /// @param target The address of the target contract
    /// @param selector The function selector
    /// @param roles The roles to revoke
    function _revokeTargetFunctionRoles(address target, bytes4 selector, uint256 roles) internal {
        s_targets[target][selector] = s_targets[target][selector] & ~roles;
        emit TargetFunctionRolesRevoked(target, selector, roles);
    }

    /// @notice Checks if a caller has permission to call a specific function on a target contract
    /// @param caller The address of the caller
    /// @param target The address of the target contract
    /// @param selector The function selector
    /// @return bool True if the caller has permission, false otherwise
    function canCall(address caller, address target, bytes4 selector) public view returns (bool) {
        return hasAnyRole(caller, s_targets[target][selector]);
    }

    /// @dev Marks a function as only callable by the owner or by the caller with any role allowed to call the function
    modifier onlyOwnerOrCanCall() {
        _checkOwnerOrRoles({roles: s_targets[address(this)][bytes4(msg.data[0:4])]});
        _;
    }
}

abstract contract AccessManaged {
    function i_accessManager() public view virtual returns (AccessManager);

    modifier restricted() {
        _checkRestricted(i_accessManager());
        _;
    }

    modifier restrictedBy(AccessManager accessManager) {
        _checkRestricted(accessManager);
        _;
    }

    function _checkRestricted(AccessManager accessManager) internal view {
        if (!accessManager.canCall(msg.sender, address(this), bytes4(msg.data[0:4]))) {
            revert Errors.AccessManaged_Restricted();
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {SSTORE2} from "solady/src/utils/SSTORE2.sol";
import {ModuleIndex} from "../Types.sol";

library ModuleAccessor {
    error ModuleOutOfBounds();

    function read(address pointer) internal view returns (address[] memory m) {
        // The first 32 bytes of the data is the offset to the start of the contents of the `data`. 0x20 is expected here.
        // The contents of the `data` is an address[] array.
        bytes memory data = SSTORE2.read(pointer);
        assembly {
            m := add(data, 0x40) // Grab the encoded array
        }
    }

    /// @notice Get a module address by index.
    /// @dev Note: The module index is zero-based. Reverts with ModuleOutOfBounds if index is out of range.
    function get(address[] memory m, ModuleIndex idx) internal pure returns (address module) {
        assembly {
            if iszero(lt(idx, mload(m))) {
                mstore(0x00, 0x13bec8a3) // `ModuleOutOfBounds()`.
                revert(0x1c, 0x04)
            }
            module := mload(add(add(m, 0x20), mul(idx, 0x20)))
        }
    }

    function unsafeGet(address[] memory m, ModuleIndex idx) internal pure returns (address module) {
        assembly {
            module := mload(add(add(m, 0x20), mul(idx, 0x20)))
        }
    }

    function getOrDefault(address[] memory m, ModuleIndex idx) internal pure returns (address module) {
        assembly {
            if lt(idx, mload(m)) { module := mload(add(add(m, 0x20), mul(idx, 0x20))) }
        }
    }

    /// @notice Replace a module address by index.
    function set(address[] memory m, ModuleIndex idx, address module) internal pure {
        assembly {
            if iszero(lt(idx, mload(m))) {
                mstore(0x00, 0x13bec8a3) // `ModuleOutOfBounds()`.
                revert(0x1c, 0x04)
            }
            mstore(add(add(m, 0x20), mul(idx, 0x20)), module)
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

library Errors {
    error AccessManaged_Restricted();

    error Expired();
    error NotExpired();

    error PrincipalToken_NotFactory();
    error PrincipalToken_VerificationFailed(uint256 code);
    error PrincipalToken_CollectRewardFailed();
    error PrincipalToken_NotApprovedCollector();
    error PrincipalToken_OnlyYieldToken();
    error PrincipalToken_InsufficientSharesReceived();
    error PrincipalToken_UnderlyingTokenBalanceChanged();
    error PrincipalToken_Unstoppable();
    error PrincipalToken_ProtectedToken();
    error YieldToken_OnlyPrincipalToken();

    // Module
    error Module_CallFailed();

    // FeeModule
    error FeeModule_InvalidFeeParam();
    error FeeModule_SplitFeeExceedsMaximum();
    error FeeModule_SplitFeeMismatchDefault();
    error FeeModule_SplitFeeTooLow();
    error FeeModule_IssuanceFeeExceedsMaximum();
    error FeeModule_PerformanceFeeExceedsMaximum();
    error FeeModule_RedemptionFeeExceedsMaximum();
    error FeeModule_PostSettlementFeeExceedsMaximum();

    // RewardProxy
    error RewardProxy_InconsistentRewardTokens();

    error Factory_ModuleNotFound();
    error Factory_InvalidExpiry();
    error Factory_InvalidPoolDeployer();
    error Factory_InvalidModule();
    error Factory_FeeModuleRequired();
    error Factory_PrincipalTokenNotFound();
    error Factory_InvalidModuleType();
    error Factory_InvalidAddress();
    error Factory_InvalidSuite();
    error Factory_CannotUpdateFeeModule();
    error Factory_InvalidDecimals();

    error PoolDeployer_FailedToDeployPool();

    error Zap_LengthMismatch();
    error Zap_TransactionTooOld();
    error Zap_BadTwoCrypto();
    error Zap_BadPrincipalToken();
    error Zap_BadCallback();
    error Zap_InconsistentETHReceived();
    error Zap_InsufficientETH();
    error Zap_InsufficientPrincipalOutput();
    error Zap_InsufficientTokenOutput();
    error Zap_InsufficientUnderlyingOutput();
    error Zap_InsufficientYieldTokenOutput();
    error Zap_InsufficientPrincipalTokenOutput();
    error Zap_DebtExceedsUnderlyingReceived();
    error Zap_PullYieldTokenGreaterThanInput();
    error Zap_BadPoolDeployer();

    // Resolver errors
    error Resolver_ConversionFailed();
    error Resolver_InvalidDecimals();
    error Resolver_ZeroAddress();
    // VaultConnectorRegistry errors
    error VCRegistry_ConnectorNotFound();

    // ERC4626Connector errors
    error ERC4626Connector_InvalidToken();
    error ERC4626Connector_InvalidETHAmount();
    error ERC4626Connector_UnexpectedETH();

    // WrapperConnector errors
    error WrapperConnector_InvalidETHAmount();
    error WrapperConnector_UnexpectedETH();

    // WrapperFactory errors
    error WrapperFactory_ImplementationNotSet();

    // Quoter errors
    error Quoter_ERC4626FallbackCallFailed();
    error Quoter_ConnectorInvalidToken();
    error Quoter_InsufficientUnderlyingOutput();
    error Quoter_MaximumYtOutputReached();

    // ConversionLib errors
    error ConversionLib_NegativeYtPrice();

    // AggregationRouter errors
    error AggregationRouter_UnsupportedRouter();
    error AggregationRouter_SwapFailed();
    error AggregationRouter_ZeroReturn();
    error AggregationRouter_InvalidMsgValue();

    // DefaultConnectorFactory errors
    error DefaultConnectorFactory_TargetNotERC4626();
    error DefaultConnectorFactory_InvalidToken();

    // Lens errors
    error Lens_LengthMismatch();

    // ERC4626Wrapper errors
    error ERC4626Wrapper_TokenNotListed();
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./Types.sol";

library Events {
    /// @dev `keccak256(bytes("YieldFeeAccrued(uint256)"))`.
    uint256 constant _YIELD_FEE_ACCRUED_EVENT_SIGNATURE =
        0xac693c1b946bcf3ad16baa51b744b990b94ea9c79ac71f2d1b5369a823a7d065;

    /// @dev `keccak256(bytes("YieldAccrued(address,uint256,uint256)"))`.
    uint256 constant _YIELD_ACCRUED_EVENT_SIGNATURE = 0xaced61c86c507aa3c2be43553434c6ff191ea7cbbd812491a6ae59abc99d29dc;

    /// @dev `keccak256(bytes("Supply(address,address,uint256,uint256)"))`.
    uint256 constant _SUPPLY_EVENT_SIGNATURE = 0x69a3ea8e6d6819646fbf2b98e9e8dd6d9cd343852550621038b4d72e4aa6dd37;

    /// @dev `keccak256(bytes("Unite(address,address,uint256,uint256)"))`.
    uint256 constant _UNITE_EVENT_SIGNATURE = 0xc78456d21b5d71405d0daba05157c90a4a412d7379fd21c3bc8a679b65b13b5f;

    /// @dev `keccak256(bytes("Redeem(address,address,address,uint256,uint256)"))`.
    uint256 constant _REDEEM_EVENT_SIGNATURE = 0xaee47cdf925cf525fdae94f9777ee5a06cac37e1c41220d0a8a89ed154f62d1c;

    /// @dev `keccak256(bytes("InterestCollected(address,address,address,uint256)"))`.
    uint256 constant _INTEREST_COLLECTED_EVENT_SIGNATURE =
        0x54affe52c3988f9c9e1d9d4673ffb7b398832c049d65e63b51326c89255e8529;

    /// @dev `keccak256(bytes("RewardsCollected(address,address,address,address,uint256)"))`.
    uint256 constant _REWARDS_COLLECTED_EVENT_SIGNATURE =
        0xc295ddd3f2581ded7ee79ef613567c637f9eabc1c1cf6c107bffaf63461614aa;

    /// @dev `keccak256(bytes("SetApprovalCollector(address,address,bool)"))`.
    uint256 constant _SET_APPROVAL_COLLECTOR_EVENT_SIGNATURE =
        0xa3b5109b351b1b1c9b05310b3176941fadf2a0c23d9bd59f5107f23d888202af;

    // Deployment events
    event Deployed(address indexed pt, address indexed yt, address indexed pool, uint256 expiry, address target);

    // Factory events
    event PrincipalTokenImplementationSet(address indexed ptBlueprint, address indexed ytBlueprint);
    event PoolDeployerSet(address indexed deployer, bool enabled);
    event AccessManagerImplementationSet(address indexed implementation, bool enabled);
    event ResolverBlueprintSet(address indexed resolverBlueprint, bool enabled);
    event TreasurySet(address indexed treasury);
    event ModuleImplementationSet(
        ModuleIndex indexed moduleType, address indexed implementation, bool enableCustomImplementation
    );
    event ModuleUpdated(ModuleIndex indexed moduleType, address indexed instance, address indexed principalToken);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PrincipalToken                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Fee accumulation events
    event YieldFeeAccrued(uint256 fee);

    // Fee collection events
    event CuratorFeesCollected(address indexed by, address indexed receiver, uint256 shares, TokenReward[] rewards);
    event ProtocolFeesCollected(address indexed by, address indexed receiver, uint256 shares, TokenReward[] rewards);

    // Yield events
    event YieldAccrued(address indexed account, uint256 interest, uint256 maxscale);

    // User interaction events
    event Supply(address indexed by, address indexed receiver, uint256 shares, uint256 principal);
    event Unite(address indexed by, address indexed receiver, uint256 shares, uint256 principal);
    // Note `Redeem` event doesn't follow EIP55095: https://eips.ethereum.org/EIPS/eip-5095 because the standard lacks the `by` parameter and `underlyingAmount` parameter.
    event Redeem(
        address indexed by, address indexed receiver, address indexed owner, uint256 shares, uint256 principal
    );
    event InterestCollected(address indexed by, address indexed receiver, address indexed owner, uint256 shares);
    event RewardsCollected(
        address indexed by, address indexed receiver, address indexed owner, address rewardToken, uint256 rewards
    );

    // Approval events
    event SetApprovalCollector(address indexed owner, address indexed collector, bool approved);

    function emitYieldFeeAccrued(uint256 fee) internal {
        assembly {
            mstore(0x00, fee)
            log1(0x00, 0x20, _YIELD_FEE_ACCRUED_EVENT_SIGNATURE)
        }
    }

    function emitYieldAccrued(address account, uint256 interest, uint256 globalIndex) internal {
        assembly {
            mstore(0x00, interest)
            mstore(0x20, globalIndex)
            let m := shr(96, not(0))
            log2(0x00, 0x40, _YIELD_ACCRUED_EVENT_SIGNATURE, and(m, account))
        }
    }

    function emitSupply(address by, address receiver, uint256 shares, uint256 principal) internal {
        assembly {
            mstore(0x00, shares)
            mstore(0x20, principal)
            let m := shr(96, not(0))
            log3(0x00, 0x40, _SUPPLY_EVENT_SIGNATURE, and(m, by), and(m, receiver))
        }
    }

    function emitUnite(address by, address receiver, uint256 shares, uint256 principal) internal {
        assembly {
            mstore(0x00, shares)
            mstore(0x20, principal)
            let m := shr(96, not(0))
            log3(0x00, 0x40, _UNITE_EVENT_SIGNATURE, and(m, by), and(m, receiver))
        }
    }

    function emitRedeem(address by, address receiver, address owner, uint256 shares, uint256 principal) internal {
        assembly {
            mstore(0x00, shares)
            mstore(0x20, principal)
            let m := shr(96, not(0))
            log4(0x00, 0x40, _REDEEM_EVENT_SIGNATURE, and(m, by), and(m, receiver), and(m, owner))
        }
    }

    function emitInterestCollected(address by, address receiver, address owner, uint256 shares) internal {
        assembly {
            mstore(0x00, shares)
            let m := shr(96, not(0))
            log4(0x00, 0x20, _INTEREST_COLLECTED_EVENT_SIGNATURE, and(m, by), and(m, receiver), and(m, owner))
        }
    }

    function emitRewardsCollected(address by, address receiver, address owner, address rewardToken, uint256 rewards)
        internal
    {
        assembly {
            let m := shr(96, not(0))
            mstore(0x00, and(m, rewardToken))
            mstore(0x20, rewards)
            log4(0x00, 0x40, _REWARDS_COLLECTED_EVENT_SIGNATURE, and(m, by), and(m, receiver), and(m, owner))
        }
    }

    function emitSetApprovalCollector(address owner, address collector, bool approved) internal {
        assembly {
            mstore(0x00, iszero(iszero(approved))) // Convert to 0 or 1
            let m := shr(96, not(0))
            log3(0x00, 0x20, _SET_APPROVAL_COLLECTOR_EVENT_SIGNATURE, and(m, owner), and(m, collector))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                            Zap                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Zap emits events for subgraph indexing users' transaction history.

    /// @dev `keccak256(bytes("ZapAddLiquidity(address,address,address,uint256,uint256,uint256)"))`.
    uint256 constant _ZAP_ADD_LIQUIDITY_SIGNATURE = 0x9e32f0e680e9faeb02a2fc3e7d2827cda9d3cf5b76c1879471c323bf0eddabce;

    /// @dev `keccak256(bytes("ZapAddLiquidityOneToken(address,address,address,uint256,uint256,address,uint256)"))`.
    uint256 constant _ZAP_ADD_LIQUIDITY_ONE_TOKEN_SIGNATURE =
        0x7cb19c3f09182abfd1d04b62fd55ffc2117c34c5e56ae0611ce778a785db6a05;

    /// @dev `keccak256(bytes("ZapRemoveLiquidity(address,address,address,uint256,uint256,uint256)"))`.
    uint256 constant _ZAP_REMOVE_LIQUIDITY_SIGNATURE =
        0x6d83a83b5c09cc7a964f9410802c001ffcfe3cd20e5bed47d41da364fd73048a;

    /// @dev `keccak256(bytes("ZapRemoveLiquidityOneToken(address,address,address,uint256,address,uint256)"))`.
    uint256 constant _ZAP_REMOVE_LIQUIDITY_ONE_TOKEN_SIGNATURE =
        0x85ff7539ec623e1a79d85fa73fdd19d84b48a2c174ea2573537d31b84218cf49;

    /// @dev `keccak256(bytes("ZapSwap(address,address,address,address,uint256,address,uint256)"))`.
    uint256 constant _ZAP_SWAP_SIGNATURE = 0x6d901733826355a03dd5004731f362a9f053f6476de435133fbff936d04226bf;

    /// @dev `keccak256(bytes("ZapSupply(address,address,address,uint256,address,uint256)"))`.
    uint256 constant _ZAP_SUPPLY_SIGNATURE = 0x9cebfeda04666057d1878b729da376084a1cb1623bafb6107989201b411644a6;

    /// @dev `keccak256(bytes("ZapUnite(address,address,address,uint256,address,uint256)"))`.
    uint256 constant _ZAP_UNITE_SIGNATURE = 0x49000823b8190200215cf672aa160fc7550472c5a70d765fe4f2bd787757b2a4;

    /// @dev `keccak256(bytes("ZapRedeem(address,address,address,uint256,address,uint256)"))`.
    uint256 constant _ZAP_REDEEM_SIGNATURE = 0x9e9c3d8bb36eb5f0ab7e30facf1fd3a018b489e86b105830b6aaa72a1e4d0a6c;

    event ZapAddLiquidity(
        address indexed by,
        address indexed receiver,
        TwoCrypto indexed twoCrypto,
        uint256 liquidity,
        uint256 shares,
        uint256 principal
    );

    event ZapAddLiquidityOneToken(
        address indexed by,
        address indexed receiver,
        TwoCrypto indexed twoCrypto,
        uint256 liquidity,
        uint256 ytOut,
        Token tokenIn,
        uint256 amountIn
    );

    function emitZapAddLiquidity(
        address by,
        address receiver,
        TwoCrypto twoCrypto,
        uint256 liquidity,
        uint256 shares,
        uint256 principal
    ) internal {
        assembly {
            let fmp := mload(0x40)
            let m := shr(96, not(0))
            mstore(0x00, liquidity)
            mstore(0x20, shares)
            mstore(0x40, principal)
            log4(0x00, 0x60, _ZAP_ADD_LIQUIDITY_SIGNATURE, and(m, by), and(m, receiver), and(m, twoCrypto))
            mstore(0x40, fmp)
        }
    }

    function emitZapAddLiquidityOneToken(
        address by,
        address receiver,
        TwoCrypto twoCrypto,
        uint256 liquidity,
        uint256 ytOut,
        Token tokenIn,
        uint256 amountIn
    ) internal {
        assembly {
            let fmp := mload(0x40)
            let m := shr(96, not(0))
            mstore(0x00, liquidity)
            mstore(0x20, ytOut)
            mstore(0x40, and(m, tokenIn))
            mstore(0x60, amountIn)
            log4(0x00, 0x80, _ZAP_ADD_LIQUIDITY_ONE_TOKEN_SIGNATURE, and(m, by), and(m, receiver), and(m, twoCrypto))
            mstore(0x60, 0) // Restore the zero slot to zero
            mstore(0x40, fmp) // Restore the free memory pointer
        }
    }

    event ZapRemoveLiquidity(
        address indexed by,
        address indexed receiver,
        TwoCrypto indexed twoCrypto,
        uint256 liquidity,
        uint256 shares,
        uint256 principal
    );

    event ZapRemoveLiquidityOneToken(
        address indexed by,
        address indexed receiver,
        TwoCrypto indexed twoCrypto,
        uint256 liquidity,
        Token tokenOut,
        uint256 amountOut
    );

    function emitZapRemoveLiquidity(
        address by,
        address receiver,
        TwoCrypto twoCrypto,
        uint256 liquidity,
        uint256 shares,
        uint256 principal
    ) internal {
        assembly {
            let fmp := mload(0x40)
            let m := shr(96, not(0))
            mstore(0x00, liquidity)
            mstore(0x20, shares)
            mstore(0x40, principal)
            log4(0x00, 0x60, _ZAP_REMOVE_LIQUIDITY_SIGNATURE, and(m, by), and(m, receiver), and(m, twoCrypto))
            mstore(0x40, fmp)
        }
    }

    function emitZapRemoveLiquidityOneToken(
        address by,
        address receiver,
        TwoCrypto twoCrypto,
        uint256 liquidity,
        Token tokenOut,
        uint256 amountOut
    ) internal {
        assembly {
            let fmp := mload(0x40)
            let m := shr(96, not(0))
            mstore(0x00, liquidity)
            mstore(0x20, and(m, tokenOut))
            mstore(0x40, amountOut)
            log4(0x00, 0x60, _ZAP_REMOVE_LIQUIDITY_ONE_TOKEN_SIGNATURE, and(m, by), and(m, receiver), and(m, twoCrypto))
            mstore(0x40, fmp)
        }
    }

    event ZapSwap(
        address indexed by,
        address indexed receiver,
        TwoCrypto indexed twoCrypto,
        Token tokenIn,
        uint256 amountIn,
        Token tokenOut,
        uint256 amountOut
    );

    function emitZapSwap(
        address by,
        address receiver,
        TwoCrypto twoCrypto,
        Token tokenIn,
        uint256 amountIn,
        Token tokenOut,
        uint256 amountOut
    ) internal {
        assembly {
            let fmp := mload(0x40) // Cache free memory pointer
            let m := shr(96, not(0))
            mstore(0x00, and(m, tokenIn))
            mstore(0x20, amountIn)
            mstore(0x40, and(m, tokenOut))
            mstore(0x60, amountOut)
            log4(0x00, 0x80, _ZAP_SWAP_SIGNATURE, and(m, by), and(m, receiver), and(m, twoCrypto))
            mstore(0x60, 0) // Restore the zero slot to zero
            mstore(0x40, fmp) // Restore the free memory pointer
        }
    }

    event ZapSupply(
        address indexed by,
        address indexed receiver,
        address indexed pt,
        uint256 principal,
        Token tokenIn,
        uint256 amountIn
    );

    event ZapUnite(
        address indexed by,
        address indexed receiver,
        address indexed pt,
        uint256 principal,
        Token tokenOut,
        uint256 amountOut
    );

    event ZapRedeem(
        address indexed by,
        address indexed receiver,
        address indexed pt,
        uint256 principal,
        Token tokenOut,
        uint256 amountOut
    );

    function emitZapSupply(address by, address receiver, address pt, uint256 principal, Token tokenIn, uint256 amountIn)
        internal
    {
        _logZapPrincipalEvent({
            signature: _ZAP_SUPPLY_SIGNATURE,
            by: by,
            receiver: receiver,
            pt: pt,
            principal: principal,
            token: tokenIn,
            amount: amountIn
        });
    }

    function emitZapUnite(
        address by,
        address receiver,
        address pt,
        uint256 principal,
        Token tokenOut,
        uint256 amountOut
    ) internal {
        _logZapPrincipalEvent({
            signature: _ZAP_UNITE_SIGNATURE,
            by: by,
            receiver: receiver,
            pt: pt,
            principal: principal,
            token: tokenOut,
            amount: amountOut
        });
    }

    function emitZapRedeem(
        address by,
        address receiver,
        address pt,
        uint256 principal,
        Token tokenOut,
        uint256 amountOut
    ) internal {
        _logZapPrincipalEvent({
            signature: _ZAP_REDEEM_SIGNATURE,
            by: by,
            receiver: receiver,
            pt: pt,
            principal: principal,
            token: tokenOut,
            amount: amountOut
        });
    }

    function _logZapPrincipalEvent(
        uint256 signature,
        address by,
        address receiver,
        address pt,
        uint256 principal,
        Token token,
        uint256 amount
    ) private {
        assembly {
            let fmp := mload(0x40)
            let m := shr(96, not(0))
            mstore(0x00, principal)
            mstore(0x20, and(m, token))
            mstore(0x40, amount)
            log4(0x00, 0x60, signature, and(m, by), and(m, receiver), and(m, pt))
            mstore(0x40, fmp)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol)
library FixedPointMathLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The operation failed, as the output exceeds the maximum value of uint256.
    error ExpOverflow();

    /// @dev The operation failed, as the output exceeds the maximum value of uint256.
    error FactorialOverflow();

    /// @dev The operation failed, due to an overflow.
    error RPowOverflow();

    /// @dev The mantissa is too big to fit.
    error MantissaOverflow();

    /// @dev The operation failed, due to an multiplication overflow.
    error MulWadFailed();

    /// @dev The operation failed, due to an multiplication overflow.
    error SMulWadFailed();

    /// @dev The operation failed, either due to a multiplication overflow, or a division by a zero.
    error DivWadFailed();

    /// @dev The operation failed, either due to a multiplication overflow, or a division by a zero.
    error SDivWadFailed();

    /// @dev The operation failed, either due to a multiplication overflow, or a division by a zero.
    error MulDivFailed();

    /// @dev The division failed, as the denominator is zero.
    error DivFailed();

    /// @dev The full precision multiply-divide operation failed, either due
    /// to the result being larger than 256 bits, or a division by a zero.
    error FullMulDivFailed();

    /// @dev The output is undefined, as the input is less-than-or-equal to zero.
    error LnWadUndefined();

    /// @dev The input outside the acceptable domain.
    error OutOfDomain();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The scalar of ETH and most ERC20s.
    uint256 internal constant WAD = 1e18;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*              SIMPLIFIED FIXED POINT OPERATIONS             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Equivalent to `(x * y) / WAD` rounded down.
    function mulWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
            if gt(x, div(not(0), y)) {
                if y {
                    mstore(0x00, 0xbac65e5b) // `MulWadFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            z := div(mul(x, y), WAD)
        }
    }

    /// @dev Equivalent to `(x * y) / WAD` rounded down.
    function sMulWad(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            // Equivalent to `require((x == 0 || z / x == y) && !(x == -1 && y == type(int256).min))`.
            if iszero(gt(or(iszero(x), eq(sdiv(z, x), y)), lt(not(x), eq(y, shl(255, 1))))) {
                mstore(0x00, 0xedcd4dd4) // `SMulWadFailed()`.
                revert(0x1c, 0x04)
            }
            z := sdiv(z, WAD)
        }
    }

    /// @dev Equivalent to `(x * y) / WAD` rounded down, but without overflow checks.
    function rawMulWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := div(mul(x, y), WAD)
        }
    }

    /// @dev Equivalent to `(x * y) / WAD` rounded down, but without overflow checks.
    function rawSMulWad(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := sdiv(mul(x, y), WAD)
        }
    }

    /// @dev Equivalent to `(x * y) / WAD` rounded up.
    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
            if iszero(eq(div(z, y), x)) {
                if y {
                    mstore(0x00, 0xbac65e5b) // `MulWadFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            z := add(iszero(iszero(mod(z, WAD))), div(z, WAD))
        }
    }

    /// @dev Equivalent to `(x * y) / WAD` rounded up, but without overflow checks.
    function rawMulWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := add(iszero(iszero(mod(mul(x, y), WAD))), div(mul(x, y), WAD))
        }
    }

    /// @dev Equivalent to `(x * WAD) / y` rounded down.
    function divWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to `require(y != 0 && x <= type(uint256).max / WAD)`.
            if iszero(mul(y, lt(x, add(1, div(not(0), WAD))))) {
                mstore(0x00, 0x7c5f487d) // `DivWadFailed()`.
                revert(0x1c, 0x04)
            }
            z := div(mul(x, WAD), y)
        }
    }

    /// @dev Equivalent to `(x * WAD) / y` rounded down.
    function sDivWad(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, WAD)
            // Equivalent to `require(y != 0 && ((x * WAD) / WAD == x))`.
            if iszero(mul(y, eq(sdiv(z, WAD), x))) {
                mstore(0x00, 0x5c43740d) // `SDivWadFailed()`.
                revert(0x1c, 0x04)
            }
            z := sdiv(z, y)
        }
    }

    /// @dev Equivalent to `(x * WAD) / y` rounded down, but without overflow and divide by zero checks.
    function rawDivWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := div(mul(x, WAD), y)
        }
    }

    /// @dev Equivalent to `(x * WAD) / y` rounded down, but without overflow and divide by zero checks.
    function rawSDivWad(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := sdiv(mul(x, WAD), y)
        }
    }

    /// @dev Equivalent to `(x * WAD) / y` rounded up.
    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to `require(y != 0 && x <= type(uint256).max / WAD)`.
            if iszero(mul(y, lt(x, add(1, div(not(0), WAD))))) {
                mstore(0x00, 0x7c5f487d) // `DivWadFailed()`.
                revert(0x1c, 0x04)
            }
            z := add(iszero(iszero(mod(mul(x, WAD), y))), div(mul(x, WAD), y))
        }
    }

    /// @dev Equivalent to `(x * WAD) / y` rounded up, but without overflow and divide by zero checks.
    function rawDivWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := add(iszero(iszero(mod(mul(x, WAD), y))), div(mul(x, WAD), y))
        }
    }

    /// @dev Equivalent to `x` to the power of `y`.
    /// because `x ** y = (e ** ln(x)) ** y = e ** (ln(x) * y)`.
    /// Note: This function is an approximation.
    function powWad(int256 x, int256 y) internal pure returns (int256) {
        // Using `ln(x)` means `x` must be greater than 0.
        return expWad((lnWad(x) * y) / int256(WAD));
    }

    /// @dev Returns `exp(x)`, denominated in `WAD`.
    /// Credit to Remco Bloemen under MIT license: https://2π.com/22/exp-ln
    /// Note: This function is an approximation. Monotonically increasing.
    function expWad(int256 x) internal pure returns (int256 r) {
        unchecked {
            // When the result is less than 0.5 we return zero.
            // This happens when `x <= (log(1e-18) * 1e18) ~ -4.15e19`.
            if (x <= -41446531673892822313) return r;

            /// @solidity memory-safe-assembly
            assembly {
                // When the result is greater than `(2**255 - 1) / 1e18` we can not represent it as
                // an int. This happens when `x >= floor(log((2**255 - 1) / 1e18) * 1e18) ≈ 135`.
                if iszero(slt(x, 135305999368893231589)) {
                    mstore(0x00, 0xa37bfec9) // `ExpOverflow()`.
                    revert(0x1c, 0x04)
                }
            }

            // `x` is now in the range `(-42, 136) * 1e18`. Convert to `(-42, 136) * 2**96`
            // for more intermediate precision and a binary basis. This base conversion
            // is a multiplication by 1e18 / 2**96 = 5**18 / 2**78.
            x = (x << 78) / 5 ** 18;

            // Reduce range of x to (-½ ln 2, ½ ln 2) * 2**96 by factoring out powers
            // of two such that exp(x) = exp(x') * 2**k, where k is an integer.
            // Solving this gives k = round(x / log(2)) and x' = x - k * log(2).
            int256 k = ((x << 96) / 54916777467707473351141471128 + 2 ** 95) >> 96;
            x = x - k * 54916777467707473351141471128;

            // `k` is in the range `[-61, 195]`.

            // Evaluate using a (6, 7)-term rational approximation.
            // `p` is made monic, we'll multiply by a scale factor later.
            int256 y = x + 1346386616545796478920950773328;
            y = ((y * x) >> 96) + 57155421227552351082224309758442;
            int256 p = y + x - 94201549194550492254356042504812;
            p = ((p * y) >> 96) + 28719021644029726153956944680412240;
            p = p * x + (4385272521454847904659076985693276 << 96);

            // We leave `p` in `2**192` basis so we don't need to scale it back up for the division.
            int256 q = x - 2855989394907223263936484059900;
            q = ((q * x) >> 96) + 50020603652535783019961831881945;
            q = ((q * x) >> 96) - 533845033583426703283633433725380;
            q = ((q * x) >> 96) + 3604857256930695427073651918091429;
            q = ((q * x) >> 96) - 14423608567350463180887372962807573;
            q = ((q * x) >> 96) + 26449188498355588339934803723976023;

            /// @solidity memory-safe-assembly
            assembly {
                // Div in assembly because solidity adds a zero check despite the unchecked.
                // The q polynomial won't have zeros in the domain as all its roots are complex.
                // No scaling is necessary because p is already `2**96` too large.
                r := sdiv(p, q)
            }

            // r should be in the range `(0.09, 0.25) * 2**96`.

            // We now need to multiply r by:
            // - The scale factor `s ≈ 6.031367120`.
            // - The `2**k` factor from the range reduction.
            // - The `1e18 / 2**96` factor for base conversion.
            // We do this all at once, with an intermediate result in `2**213`
            // basis, so the final right shift is always by a positive amount.
            r = int256(
                (uint256(r) * 3822833074963236453042738258902158003155416615667) >> uint256(195 - k)
            );
        }
    }

    /// @dev Returns `ln(x)`, denominated in `WAD`.
    /// Credit to Remco Bloemen under MIT license: https://2π.com/22/exp-ln
    /// Note: This function is an approximation. Monotonically increasing.
    function lnWad(int256 x) internal pure returns (int256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            // We want to convert `x` from `10**18` fixed point to `2**96` fixed point.
            // We do this by multiplying by `2**96 / 10**18`. But since
            // `ln(x * C) = ln(x) + ln(C)`, we can simply do nothing here
            // and add `ln(2**96 / 10**18)` at the end.

            // Compute `k = log2(x) - 96`, `r = 159 - k = 255 - log2(x) = 255 ^ log2(x)`.
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            // We place the check here for more optimal stack operations.
            if iszero(sgt(x, 0)) {
                mstore(0x00, 0x1615e638) // `LnWadUndefined()`.
                revert(0x1c, 0x04)
            }
            // forgefmt: disable-next-item
            r := xor(r, byte(and(0x1f, shr(shr(r, x), 0x8421084210842108cc6318c6db6d54be)),
                0xf8f9f9faf9fdfafbf9fdfcfdfafbfcfef9fafdfafcfcfbfefafafcfbffffffff))

            // Reduce range of x to (1, 2) * 2**96
            // ln(2^k * x) = k * ln(2) + ln(x)
            x := shr(159, shl(r, x))

            // Evaluate using a (8, 8)-term rational approximation.
            // `p` is made monic, we will multiply by a scale factor later.
            // forgefmt: disable-next-item
            let p := sub( // This heavily nested expression is to avoid stack-too-deep for via-ir.
                sar(96, mul(add(43456485725739037958740375743393,
                sar(96, mul(add(24828157081833163892658089445524,
                sar(96, mul(add(3273285459638523848632254066296,
                    x), x))), x))), x)), 11111509109440967052023855526967)
            p := sub(sar(96, mul(p, x)), 45023709667254063763336534515857)
            p := sub(sar(96, mul(p, x)), 14706773417378608786704636184526)
            p := sub(mul(p, x), shl(96, 795164235651350426258249787498))
            // We leave `p` in `2**192` basis so we don't need to scale it back up for the division.

            // `q` is monic by convention.
            let q := add(5573035233440673466300451813936, x)
            q := add(71694874799317883764090561454958, sar(96, mul(x, q)))
            q := add(283447036172924575727196451306956, sar(96, mul(x, q)))
            q := add(401686690394027663651624208769553, sar(96, mul(x, q)))
            q := add(204048457590392012362485061816622, sar(96, mul(x, q)))
            q := add(31853899698501571402653359427138, sar(96, mul(x, q)))
            q := add(909429971244387300277376558375, sar(96, mul(x, q)))

            // `p / q` is in the range `(0, 0.125) * 2**96`.

            // Finalization, we need to:
            // - Multiply by the scale factor `s = 5.549…`.
            // - Add `ln(2**96 / 10**18)`.
            // - Add `k * ln(2)`.
            // - Multiply by `10**18 / 2**96 = 5**18 >> 78`.

            // The q polynomial is known not to have zeros in the domain.
            // No scaling required because p is already `2**96` too large.
            p := sdiv(p, q)
            // Multiply by the scaling factor: `s * 5**18 * 2**96`, base is now `5**18 * 2**192`.
            p := mul(1677202110996718588342820967067443963516166, p)
            // Add `ln(2) * k * 5**18 * 2**192`.
            // forgefmt: disable-next-item
            p := add(mul(16597577552685614221487285958193947469193820559219878177908093499208371, sub(159, r)), p)
            // Add `ln(2**96 / 10**18) * 5**18 * 2**192`.
            p := add(600920179829731861736702779321621459595472258049074101567377883020018308, p)
            // Base conversion: mul `2**18 / 2**192`.
            r := sar(174, p)
        }
    }

    /// @dev Returns `W_0(x)`, denominated in `WAD`.
    /// See: https://en.wikipedia.org/wiki/Lambert_W_function
    /// a.k.a. Product log function. This is an approximation of the principal branch.
    /// Note: This function is an approximation. Monotonically increasing.
    function lambertW0Wad(int256 x) internal pure returns (int256 w) {
        // forgefmt: disable-next-item
        unchecked {
            if ((w = x) <= -367879441171442322) revert OutOfDomain(); // `x` less than `-1/e`.
            (int256 wad, int256 p) = (int256(WAD), x);
            uint256 c; // Whether we need to avoid catastrophic cancellation.
            uint256 i = 4; // Number of iterations.
            if (w <= 0x1ffffffffffff) {
                if (-0x4000000000000 <= w) {
                    i = 1; // Inputs near zero only take one step to converge.
                } else if (w <= -0x3ffffffffffffff) {
                    i = 32; // Inputs near `-1/e` take very long to converge.
                }
            } else if (uint256(w >> 63) == uint256(0)) {
                /// @solidity memory-safe-assembly
                assembly {
                    // Inline log2 for more performance, since the range is small.
                    let v := shr(49, w)
                    let l := shl(3, lt(0xff, v))
                    l := add(or(l, byte(and(0x1f, shr(shr(l, v), 0x8421084210842108cc6318c6db6d54be)),
                        0x0706060506020504060203020504030106050205030304010505030400000000)), 49)
                    w := sdiv(shl(l, 7), byte(sub(l, 31), 0x0303030303030303040506080c13))
                    c := gt(l, 60)
                    i := add(2, add(gt(l, 53), c))
                }
            } else {
                int256 ll = lnWad(w = lnWad(w));
                /// @solidity memory-safe-assembly
                assembly {
                    // `w = ln(x) - ln(ln(x)) + b * ln(ln(x)) / ln(x)`.
                    w := add(sdiv(mul(ll, 1023715080943847266), w), sub(w, ll))
                    i := add(3, iszero(shr(68, x)))
                    c := iszero(shr(143, x))
                }
                if (c == uint256(0)) {
                    do { // If `x` is big, use Newton's so that intermediate values won't overflow.
                        int256 e = expWad(w);
                        /// @solidity memory-safe-assembly
                        assembly {
                            let t := mul(w, div(e, wad))
                            w := sub(w, sdiv(sub(t, x), div(add(e, t), wad)))
                        }
                        if (p <= w) break;
                        p = w;
                    } while (--i != uint256(0));
                    /// @solidity memory-safe-assembly
                    assembly {
                        w := sub(w, sgt(w, 2))
                    }
                    return w;
                }
            }
            do { // Otherwise, use Halley's for faster convergence.
                int256 e = expWad(w);
                /// @solidity memory-safe-assembly
                assembly {
                    let t := add(w, wad)
                    let s := sub(mul(w, e), mul(x, wad))
                    w := sub(w, sdiv(mul(s, wad), sub(mul(e, t), sdiv(mul(add(t, wad), s), add(t, t)))))
                }
                if (p <= w) break;
                p = w;
            } while (--i != c);
            /// @solidity memory-safe-assembly
            assembly {
                w := sub(w, sgt(w, 2))
            }
            // For certain ranges of `x`, we'll use the quadratic-rate recursive formula of
            // R. Iacono and J.P. Boyd for the last iteration, to avoid catastrophic cancellation.
            if (c == uint256(0)) return w;
            int256 t = w | 1;
            /// @solidity memory-safe-assembly
            assembly {
                x := sdiv(mul(x, wad), t)
            }
            x = (t * (wad + lnWad(x)));
            /// @solidity memory-safe-assembly
            assembly {
                w := sdiv(x, add(wad, t))
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  GENERAL NUMBER UTILITIES                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns `a * b == x * y`, with full precision.
    function fullMulEq(uint256 a, uint256 b, uint256 x, uint256 y)
        internal
        pure
        returns (bool result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := and(eq(mul(a, b), mul(x, y)), eq(mulmod(x, y, not(0)), mulmod(a, b, not(0))))
        }
    }

    /// @dev Calculates `floor(x * y / d)` with full precision.
    /// Throws if result overflows a uint256 or when `d` is zero.
    /// Credit to Remco Bloemen under MIT license: https://2π.com/21/muldiv
    function fullMulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // 512-bit multiply `[p1 p0] = x * y`.
            // Compute the product mod `2**256` and mod `2**256 - 1`
            // then use the Chinese Remainder Theorem to reconstruct
            // the 512 bit result. The result is stored in two 256
            // variables such that `product = p1 * 2**256 + p0`.

            // Temporarily use `z` as `p0` to save gas.
            z := mul(x, y) // Lower 256 bits of `x * y`.
            for {} 1 {} {
                // If overflows.
                if iszero(mul(or(iszero(x), eq(div(z, x), y)), d)) {
                    let mm := mulmod(x, y, not(0))
                    let p1 := sub(mm, add(z, lt(mm, z))) // Upper 256 bits of `x * y`.

                    /*------------------- 512 by 256 division --------------------*/

                    // Make division exact by subtracting the remainder from `[p1 p0]`.
                    let r := mulmod(x, y, d) // Compute remainder using mulmod.
                    let t := and(d, sub(0, d)) // The least significant bit of `d`. `t >= 1`.
                    // Make sure `z` is less than `2**256`. Also prevents `d == 0`.
                    // Placing the check here seems to give more optimal stack operations.
                    if iszero(gt(d, p1)) {
                        mstore(0x00, 0xae47f702) // `FullMulDivFailed()`.
                        revert(0x1c, 0x04)
                    }
                    d := div(d, t) // Divide `d` by `t`, which is a power of two.
                    // Invert `d mod 2**256`
                    // Now that `d` is an odd number, it has an inverse
                    // modulo `2**256` such that `d * inv = 1 mod 2**256`.
                    // Compute the inverse by starting with a seed that is correct
                    // correct for four bits. That is, `d * inv = 1 mod 2**4`.
                    let inv := xor(2, mul(3, d))
                    // Now use Newton-Raphson iteration to improve the precision.
                    // Thanks to Hensel's lifting lemma, this also works in modular
                    // arithmetic, doubling the correct bits in each step.
                    inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**8
                    inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**16
                    inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**32
                    inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**64
                    inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**128
                    z :=
                        mul(
                            // Divide [p1 p0] by the factors of two.
                            // Shift in bits from `p1` into `p0`. For this we need
                            // to flip `t` such that it is `2**256 / t`.
                            or(mul(sub(p1, gt(r, z)), add(div(sub(0, t), t), 1)), div(sub(z, r), t)),
                            mul(sub(2, mul(d, inv)), inv) // inverse mod 2**256
                        )
                    break
                }
                z := div(z, d)
                break
            }
        }
    }

    /// @dev Calculates `floor(x * y / d)` with full precision.
    /// Behavior is undefined if `d` is zero or the final result cannot fit in 256 bits.
    /// Performs the full 512 bit calculation regardless.
    function fullMulDivUnchecked(uint256 x, uint256 y, uint256 d)
        internal
        pure
        returns (uint256 z)
    {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            let mm := mulmod(x, y, not(0))
            let p1 := sub(mm, add(z, lt(mm, z)))
            let t := and(d, sub(0, d))
            let r := mulmod(x, y, d)
            d := div(d, t)
            let inv := xor(2, mul(3, d))
            inv := mul(inv, sub(2, mul(d, inv)))
            inv := mul(inv, sub(2, mul(d, inv)))
            inv := mul(inv, sub(2, mul(d, inv)))
            inv := mul(inv, sub(2, mul(d, inv)))
            inv := mul(inv, sub(2, mul(d, inv)))
            z :=
                mul(
                    or(mul(sub(p1, gt(r, z)), add(div(sub(0, t), t), 1)), div(sub(z, r), t)),
                    mul(sub(2, mul(d, inv)), inv)
                )
        }
    }

    /// @dev Calculates `floor(x * y / d)` with full precision, rounded up.
    /// Throws if result overflows a uint256 or when `d` is zero.
    /// Credit to Uniswap-v3-core under MIT license:
    /// https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/FullMath.sol
    function fullMulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        z = fullMulDiv(x, y, d);
        /// @solidity memory-safe-assembly
        assembly {
            if mulmod(x, y, d) {
                z := add(z, 1)
                if iszero(z) {
                    mstore(0x00, 0xae47f702) // `FullMulDivFailed()`.
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    /// @dev Calculates `floor(x * y / 2 ** n)` with full precision.
    /// Throws if result overflows a uint256.
    /// Credit to Philogy under MIT license:
    /// https://github.com/SorellaLabs/angstrom/blob/main/contracts/src/libraries/X128MathLib.sol
    function fullMulDivN(uint256 x, uint256 y, uint8 n) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Temporarily use `z` as `p0` to save gas.
            z := mul(x, y) // Lower 256 bits of `x * y`. We'll call this `z`.
            for {} 1 {} {
                if iszero(or(iszero(x), eq(div(z, x), y))) {
                    let k := and(n, 0xff) // `n`, cleaned.
                    let mm := mulmod(x, y, not(0))
                    let p1 := sub(mm, add(z, lt(mm, z))) // Upper 256 bits of `x * y`.
                    //         |      p1     |      z     |
                    // Before: | p1_0 ¦ p1_1 | z_0  ¦ z_1 |
                    // Final:  |   0  ¦ p1_0 | p1_1 ¦ z_0 |
                    // Check that final `z` doesn't overflow by checking that p1_0 = 0.
                    if iszero(shr(k, p1)) {
                        z := add(shl(sub(256, k), p1), shr(k, z))
                        break
                    }
                    mstore(0x00, 0xae47f702) // `FullMulDivFailed()`.
                    revert(0x1c, 0x04)
                }
                z := shr(and(n, 0xff), z)
                break
            }
        }
    }

    /// @dev Returns `floor(x * y / d)`.
    /// Reverts if `x * y` overflows, or `d` is zero.
    function mulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            // Equivalent to `require(d != 0 && (y == 0 || x <= type(uint256).max / y))`.
            if iszero(mul(or(iszero(x), eq(div(z, x), y)), d)) {
                mstore(0x00, 0xad251c27) // `MulDivFailed()`.
                revert(0x1c, 0x04)
            }
            z := div(z, d)
        }
    }

    /// @dev Returns `ceil(x * y / d)`.
    /// Reverts if `x * y` overflows, or `d` is zero.
    function mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(x, y)
            // Equivalent to `require(d != 0 && (y == 0 || x <= type(uint256).max / y))`.
            if iszero(mul(or(iszero(x), eq(div(z, x), y)), d)) {
                mstore(0x00, 0xad251c27) // `MulDivFailed()`.
                revert(0x1c, 0x04)
            }
            z := add(iszero(iszero(mod(z, d))), div(z, d))
        }
    }

    /// @dev Returns `x`, the modular multiplicative inverse of `a`, such that `(a * x) % n == 1`.
    function invMod(uint256 a, uint256 n) internal pure returns (uint256 x) {
        /// @solidity memory-safe-assembly
        assembly {
            let g := n
            let r := mod(a, n)
            for { let y := 1 } 1 {} {
                let q := div(g, r)
                let t := g
                g := r
                r := sub(t, mul(r, q))
                let u := x
                x := y
                y := sub(u, mul(y, q))
                if iszero(r) { break }
            }
            x := mul(eq(g, 1), add(x, mul(slt(x, 0), n)))
        }
    }

    /// @dev Returns `ceil(x / d)`.
    /// Reverts if `d` is zero.
    function divUp(uint256 x, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(d) {
                mstore(0x00, 0x65244e4e) // `DivFailed()`.
                revert(0x1c, 0x04)
            }
            z := add(iszero(iszero(mod(x, d))), div(x, d))
        }
    }

    /// @dev Returns `max(0, x - y)`.
    function zeroFloorSub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(gt(x, y), sub(x, y))
        }
    }

    /// @dev Returns `condition ? x : y`, without branching.
    function ternary(bool condition, uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), iszero(condition)))
        }
    }

    /// @dev Returns `condition ? x : y`, without branching.
    function ternary(bool condition, bytes32 x, bytes32 y) internal pure returns (bytes32 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), iszero(condition)))
        }
    }

    /// @dev Returns `condition ? x : y`, without branching.
    function ternary(bool condition, address x, address y) internal pure returns (address z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), iszero(condition)))
        }
    }

    /// @dev Exponentiate `x` to `y` by squaring, denominated in base `b`.
    /// Reverts if the computation overflows.
    function rpow(uint256 x, uint256 y, uint256 b) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(b, iszero(y)) // `0 ** 0 = 1`. Otherwise, `0 ** n = 0`.
            if x {
                z := xor(b, mul(xor(b, x), and(y, 1))) // `z = isEven(y) ? scale : x`
                let half := shr(1, b) // Divide `b` by 2.
                // Divide `y` by 2 every iteration.
                for { y := shr(1, y) } y { y := shr(1, y) } {
                    let xx := mul(x, x) // Store x squared.
                    let xxRound := add(xx, half) // Round to the nearest number.
                    // Revert if `xx + half` overflowed, or if `x ** 2` overflows.
                    if or(lt(xxRound, xx), shr(128, x)) {
                        mstore(0x00, 0x49f7642b) // `RPowOverflow()`.
                        revert(0x1c, 0x04)
                    }
                    x := div(xxRound, b) // Set `x` to scaled `xxRound`.
                    // If `y` is odd:
                    if and(y, 1) {
                        let zx := mul(z, x) // Compute `z * x`.
                        let zxRound := add(zx, half) // Round to the nearest number.
                        // If `z * x` overflowed or `zx + half` overflowed:
                        if or(xor(div(zx, x), z), lt(zxRound, zx)) {
                            // Revert if `x` is non-zero.
                            if x {
                                mstore(0x00, 0x49f7642b) // `RPowOverflow()`.
                                revert(0x1c, 0x04)
                            }
                        }
                        z := div(zxRound, b) // Return properly scaled `zxRound`.
                    }
                }
            }
        }
    }

    /// @dev Returns the square root of `x`, rounded down.
    function sqrt(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // `floor(sqrt(2**15)) = 181`. `sqrt(2**15) - 181 = 2.84`.
            z := 181 // The "correct" value is 1, but this saves a multiplication later.

            // This segment is to get a reasonable initial estimate for the Babylonian method. With a bad
            // start, the correct # of bits increases ~linearly each iteration instead of ~quadratically.

            // Let `y = x / 2**r`. We check `y >= 2**(k + 8)`
            // but shift right by `k` bits to ensure that if `x >= 256`, then `y >= 256`.
            let r := shl(7, lt(0xffffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffffff, shr(r, x))))
            z := shl(shr(1, r), z)

            // Goal was to get `z*z*y` within a small factor of `x`. More iterations could
            // get y in a tighter range. Currently, we will have y in `[256, 256*(2**16))`.
            // We ensured `y >= 256` so that the relative difference between `y` and `y+1` is small.
            // That's not possible if `x < 256` but we can just verify those cases exhaustively.

            // Now, `z*z*y <= x < z*z*(y+1)`, and `y <= 2**(16+8)`, and either `y >= 256`, or `x < 256`.
            // Correctness can be checked exhaustively for `x < 256`, so we assume `y >= 256`.
            // Then `z*sqrt(y)` is within `sqrt(257)/sqrt(256)` of `sqrt(x)`, or about 20bps.

            // For `s` in the range `[1/256, 256]`, the estimate `f(s) = (181/1024) * (s+1)`
            // is in the range `(1/2.84 * sqrt(s), 2.84 * sqrt(s))`,
            // with largest error when `s = 1` and when `s = 256` or `1/256`.

            // Since `y` is in `[256, 256*(2**16))`, let `a = y/65536`, so that `a` is in `[1/256, 256)`.
            // Then we can estimate `sqrt(y)` using
            // `sqrt(65536) * 181/1024 * (a + 1) = 181/4 * (y + 65536)/65536 = 181 * (y + 65536)/2**18`.

            // There is no overflow risk here since `y < 2**136` after the first branch above.
            z := shr(18, mul(z, add(shr(r, x), 65536))) // A `mul()` is saved from starting `z` at 181.

            // Given the worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // If `x+1` is a perfect square, the Babylonian method cycles between
            // `floor(sqrt(x))` and `ceil(sqrt(x))`. This statement ensures we return floor.
            // See: https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            z := sub(z, lt(div(x, z), z))
        }
    }

    /// @dev Returns the cube root of `x`, rounded down.
    /// Credit to bout3fiddy and pcaversaccio under AGPLv3 license:
    /// https://github.com/pcaversaccio/snekmate/blob/main/src/utils/Math.vy
    /// Formally verified by xuwinnie:
    /// https://github.com/vectorized/solady/blob/main/audits/xuwinnie-solady-cbrt-proof.pdf
    function cbrt(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            let r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            // Makeshift lookup table to nudge the approximate log2 result.
            z := div(shl(div(r, 3), shl(lt(0xf, shr(r, x)), 0xf)), xor(7, mod(r, 3)))
            // Newton-Raphson's.
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            // Round down.
            z := sub(z, lt(div(x, mul(z, z)), z))
        }
    }

    /// @dev Returns the square root of `x`, denominated in `WAD`, rounded down.
    function sqrtWad(uint256 x) internal pure returns (uint256 z) {
        unchecked {
            if (x <= type(uint256).max / 10 ** 18) return sqrt(x * 10 ** 18);
            z = (1 + sqrt(x)) * 10 ** 9;
            z = (fullMulDivUnchecked(x, 10 ** 18, z) + z) >> 1;
        }
        /// @solidity memory-safe-assembly
        assembly {
            z := sub(z, gt(999999999999999999, sub(mulmod(z, z, x), 1))) // Round down.
        }
    }

    /// @dev Returns the cube root of `x`, denominated in `WAD`, rounded down.
    /// Formally verified by xuwinnie:
    /// https://github.com/vectorized/solady/blob/main/audits/xuwinnie-solady-cbrt-proof.pdf
    function cbrtWad(uint256 x) internal pure returns (uint256 z) {
        unchecked {
            if (x <= type(uint256).max / 10 ** 36) return cbrt(x * 10 ** 36);
            z = (1 + cbrt(x)) * 10 ** 12;
            z = (fullMulDivUnchecked(x, 10 ** 36, z * z) + z + z) / 3;
        }
        /// @solidity memory-safe-assembly
        assembly {
            let p := x
            for {} 1 {} {
                if iszero(shr(229, p)) {
                    if iszero(shr(199, p)) {
                        p := mul(p, 100000000000000000) // 10 ** 17.
                        break
                    }
                    p := mul(p, 100000000) // 10 ** 8.
                    break
                }
                if iszero(shr(249, p)) { p := mul(p, 100) }
                break
            }
            let t := mulmod(mul(z, z), z, p)
            z := sub(z, gt(lt(t, shr(1, p)), iszero(t))) // Round down.
        }
    }

    /// @dev Returns the factorial of `x`.
    function factorial(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := 1
            if iszero(lt(x, 58)) {
                mstore(0x00, 0xaba0f2a2) // `FactorialOverflow()`.
                revert(0x1c, 0x04)
            }
            for {} x { x := sub(x, 1) } { z := mul(z, x) }
        }
    }

    /// @dev Returns the log2 of `x`.
    /// Equivalent to computing the index of the most significant bit (MSB) of `x`.
    /// Returns 0 if `x` is zero.
    function log2(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            // forgefmt: disable-next-item
            r := or(r, byte(and(0x1f, shr(shr(r, x), 0x8421084210842108cc6318c6db6d54be)),
                0x0706060506020504060203020504030106050205030304010505030400000000))
        }
    }

    /// @dev Returns the log2 of `x`, rounded up.
    /// Returns 0 if `x` is zero.
    function log2Up(uint256 x) internal pure returns (uint256 r) {
        r = log2(x);
        /// @solidity memory-safe-assembly
        assembly {
            r := add(r, lt(shl(r, 1), x))
        }
    }

    /// @dev Returns the log10 of `x`.
    /// Returns 0 if `x` is zero.
    function log10(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(lt(x, 100000000000000000000000000000000000000)) {
                x := div(x, 100000000000000000000000000000000000000)
                r := 38
            }
            if iszero(lt(x, 100000000000000000000)) {
                x := div(x, 100000000000000000000)
                r := add(r, 20)
            }
            if iszero(lt(x, 10000000000)) {
                x := div(x, 10000000000)
                r := add(r, 10)
            }
            if iszero(lt(x, 100000)) {
                x := div(x, 100000)
                r := add(r, 5)
            }
            r := add(r, add(gt(x, 9), add(gt(x, 99), add(gt(x, 999), gt(x, 9999)))))
        }
    }

    /// @dev Returns the log10 of `x`, rounded up.
    /// Returns 0 if `x` is zero.
    function log10Up(uint256 x) internal pure returns (uint256 r) {
        r = log10(x);
        /// @solidity memory-safe-assembly
        assembly {
            r := add(r, lt(exp(10, r), x))
        }
    }

    /// @dev Returns the log256 of `x`.
    /// Returns 0 if `x` is zero.
    function log256(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(shr(3, r), lt(0xff, shr(r, x)))
        }
    }

    /// @dev Returns the log256 of `x`, rounded up.
    /// Returns 0 if `x` is zero.
    function log256Up(uint256 x) internal pure returns (uint256 r) {
        r = log256(x);
        /// @solidity memory-safe-assembly
        assembly {
            r := add(r, lt(shl(shl(3, r), 1), x))
        }
    }

    /// @dev Returns the scientific notation format `mantissa * 10 ** exponent` of `x`.
    /// Useful for compressing prices (e.g. using 25 bit mantissa and 7 bit exponent).
    function sci(uint256 x) internal pure returns (uint256 mantissa, uint256 exponent) {
        /// @solidity memory-safe-assembly
        assembly {
            mantissa := x
            if mantissa {
                if iszero(mod(mantissa, 1000000000000000000000000000000000)) {
                    mantissa := div(mantissa, 1000000000000000000000000000000000)
                    exponent := 33
                }
                if iszero(mod(mantissa, 10000000000000000000)) {
                    mantissa := div(mantissa, 10000000000000000000)
                    exponent := add(exponent, 19)
                }
                if iszero(mod(mantissa, 1000000000000)) {
                    mantissa := div(mantissa, 1000000000000)
                    exponent := add(exponent, 12)
                }
                if iszero(mod(mantissa, 1000000)) {
                    mantissa := div(mantissa, 1000000)
                    exponent := add(exponent, 6)
                }
                if iszero(mod(mantissa, 10000)) {
                    mantissa := div(mantissa, 10000)
                    exponent := add(exponent, 4)
                }
                if iszero(mod(mantissa, 100)) {
                    mantissa := div(mantissa, 100)
                    exponent := add(exponent, 2)
                }
                if iszero(mod(mantissa, 10)) {
                    mantissa := div(mantissa, 10)
                    exponent := add(exponent, 1)
                }
            }
        }
    }

    /// @dev Convenience function for packing `x` into a smaller number using `sci`.
    /// The `mantissa` will be in bits [7..255] (the upper 249 bits).
    /// The `exponent` will be in bits [0..6] (the lower 7 bits).
    /// Use `SafeCastLib` to safely ensure that the `packed` number is small
    /// enough to fit in the desired unsigned integer type:
    /// ```
    ///     uint32 packed = SafeCastLib.toUint32(FixedPointMathLib.packSci(777 ether));
    /// ```
    function packSci(uint256 x) internal pure returns (uint256 packed) {
        (x, packed) = sci(x); // Reuse for `mantissa` and `exponent`.
        /// @solidity memory-safe-assembly
        assembly {
            if shr(249, x) {
                mstore(0x00, 0xce30380c) // `MantissaOverflow()`.
                revert(0x1c, 0x04)
            }
            packed := or(shl(7, x), packed)
        }
    }

    /// @dev Convenience function for unpacking a packed number from `packSci`.
    function unpackSci(uint256 packed) internal pure returns (uint256 unpacked) {
        unchecked {
            unpacked = (packed >> 7) * 10 ** (packed & 0x7f);
        }
    }

    /// @dev Returns the average of `x` and `y`. Rounds towards zero.
    function avg(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = (x & y) + ((x ^ y) >> 1);
        }
    }

    /// @dev Returns the average of `x` and `y`. Rounds towards negative infinity.
    function avg(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = (x >> 1) + (y >> 1) + (x & y & 1);
        }
    }

    /// @dev Returns the absolute value of `x`.
    function abs(int256 x) internal pure returns (uint256 z) {
        unchecked {
            z = (uint256(x) + uint256(x >> 255)) ^ uint256(x >> 255);
        }
    }

    /// @dev Returns the absolute distance between `x` and `y`.
    function dist(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := add(xor(sub(0, gt(x, y)), sub(y, x)), gt(x, y))
        }
    }

    /// @dev Returns the absolute distance between `x` and `y`.
    function dist(int256 x, int256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := add(xor(sub(0, sgt(x, y)), sub(y, x)), sgt(x, y))
        }
    }

    /// @dev Returns the minimum of `x` and `y`.
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), lt(y, x)))
        }
    }

    /// @dev Returns the minimum of `x` and `y`.
    function min(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), slt(y, x)))
        }
    }

    /// @dev Returns the maximum of `x` and `y`.
    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), gt(y, x)))
        }
    }

    /// @dev Returns the maximum of `x` and `y`.
    function max(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), sgt(y, x)))
        }
    }

    /// @dev Returns `x`, bounded to `minValue` and `maxValue`.
    function clamp(uint256 x, uint256 minValue, uint256 maxValue)
        internal
        pure
        returns (uint256 z)
    {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, minValue), gt(minValue, x)))
            z := xor(z, mul(xor(z, maxValue), lt(maxValue, z)))
        }
    }

    /// @dev Returns `x`, bounded to `minValue` and `maxValue`.
    function clamp(int256 x, int256 minValue, int256 maxValue) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, minValue), sgt(minValue, x)))
            z := xor(z, mul(xor(z, maxValue), slt(maxValue, z)))
        }
    }

    /// @dev Returns greatest common divisor of `x` and `y`.
    function gcd(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            for { z := x } y {} {
                let t := y
                y := mod(z, y)
                z := t
            }
        }
    }

    /// @dev Returns `a + (b - a) * (t - begin) / (end - begin)`,
    /// with `t` clamped between `begin` and `end` (inclusive).
    /// Agnostic to the order of (`a`, `b`) and (`end`, `begin`).
    /// If `begins == end`, returns `t <= begin ? a : b`.
    function lerp(uint256 a, uint256 b, uint256 t, uint256 begin, uint256 end)
        internal
        pure
        returns (uint256)
    {
        if (begin > end) (t, begin, end) = (~t, ~begin, ~end);
        if (t <= begin) return a;
        if (t >= end) return b;
        unchecked {
            if (b >= a) return a + fullMulDiv(b - a, t - begin, end - begin);
            return a - fullMulDiv(a - b, t - begin, end - begin);
        }
    }

    /// @dev Returns `a + (b - a) * (t - begin) / (end - begin)`.
    /// with `t` clamped between `begin` and `end` (inclusive).
    /// Agnostic to the order of (`a`, `b`) and (`end`, `begin`).
    /// If `begins == end`, returns `t <= begin ? a : b`.
    function lerp(int256 a, int256 b, int256 t, int256 begin, int256 end)
        internal
        pure
        returns (int256)
    {
        if (begin > end) (t, begin, end) = (~t, ~begin, ~end);
        if (t <= begin) return a;
        if (t >= end) return b;
        // forgefmt: disable-next-item
        unchecked {
            if (b >= a) return int256(uint256(a) + fullMulDiv(uint256(b - a),
                uint256(t - begin), uint256(end - begin)));
            return int256(uint256(a) - fullMulDiv(uint256(a - b),
                uint256(t - begin), uint256(end - begin)));
        }
    }

    /// @dev Returns if `x` is an even number. Some people may need this.
    function isEven(uint256 x) internal pure returns (bool) {
        return x & uint256(1) == uint256(0);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   RAW NUMBER OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns `x + y`, without checking for overflow.
    function rawAdd(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x + y;
        }
    }

    /// @dev Returns `x + y`, without checking for overflow.
    function rawAdd(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = x + y;
        }
    }

    /// @dev Returns `x - y`, without checking for underflow.
    function rawSub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x - y;
        }
    }

    /// @dev Returns `x - y`, without checking for underflow.
    function rawSub(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = x - y;
        }
    }

    /// @dev Returns `x * y`, without checking for overflow.
    function rawMul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x * y;
        }
    }

    /// @dev Returns `x * y`, without checking for overflow.
    function rawMul(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = x * y;
        }
    }

    /// @dev Returns `x / y`, returning 0 if `y` is zero.
    function rawDiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := div(x, y)
        }
    }

    /// @dev Returns `x / y`, returning 0 if `y` is zero.
    function rawSDiv(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := sdiv(x, y)
        }
    }

    /// @dev Returns `x % y`, returning 0 if `y` is zero.
    function rawMod(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mod(x, y)
        }
    }

    /// @dev Returns `x % y`, returning 0 if `y` is zero.
    function rawSMod(int256 x, int256 y) internal pure returns (int256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := smod(x, y)
        }
    }

    /// @dev Returns `(x + y) % d`, return 0 if `d` if zero.
    function rawAddMod(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := addmod(x, y, d)
        }
    }

    /// @dev Returns `(x * y) % d`, return 0 if `d` if zero.
    function rawMulMod(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mulmod(x, y, d)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for memory arrays with automatic capacity resizing.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/DynamicArrayLib.sol)
library DynamicArrayLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Type to represent a dynamic array in memory.
    /// You can directly assign to `data`, and the `p` function will
    /// take care of the memory allocation.
    struct DynamicArray {
        uint256[] data;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The constant returned when the element is not found in the array.
    uint256 internal constant NOT_FOUND = type(uint256).max;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  UINT256 ARRAY OPERATIONS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Low level minimalist uint256 array operations.
    // If you don't need syntax sugar, it's recommended to use these.
    // Some of these functions returns the same array for function chaining.
    // e.g. `array.set(0, 1).set(1, 2)`.

    /// @dev Returns a uint256 array with `n` elements. The elements are not zeroized.
    function malloc(uint256 n) internal pure returns (uint256[] memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := or(sub(0, shr(32, n)), mload(0x40))
            mstore(result, n)
            mstore(0x40, add(add(result, 0x20), shl(5, n)))
        }
    }

    /// @dev Zeroizes all the elements of `a`.
    function zeroize(uint256[] memory a) internal pure returns (uint256[] memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := a
            calldatacopy(add(result, 0x20), calldatasize(), shl(5, mload(result)))
        }
    }

    /// @dev Returns the element at `a[i]`, without bounds checking.
    function get(uint256[] memory a, uint256 i) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(add(add(a, 0x20), shl(5, i)))
        }
    }

    /// @dev Returns the element at `a[i]`, without bounds checking.
    function getUint256(uint256[] memory a, uint256 i) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(add(add(a, 0x20), shl(5, i)))
        }
    }

    /// @dev Returns the element at `a[i]`, without bounds checking.
    function getAddress(uint256[] memory a, uint256 i) internal pure returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(add(add(a, 0x20), shl(5, i)))
        }
    }

    /// @dev Returns the element at `a[i]`, without bounds checking.
    function getBool(uint256[] memory a, uint256 i) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(add(add(a, 0x20), shl(5, i)))
        }
    }

    /// @dev Returns the element at `a[i]`, without bounds checking.
    function getBytes32(uint256[] memory a, uint256 i) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(add(add(a, 0x20), shl(5, i)))
        }
    }

    /// @dev Sets `a.data[i]` to `data`, without bounds checking.
    function set(uint256[] memory a, uint256 i, uint256 data)
        internal
        pure
        returns (uint256[] memory result)
    {
        result = a;
        /// @solidity memory-safe-assembly
        assembly {
            mstore(add(add(result, 0x20), shl(5, i)), data)
        }
    }

    /// @dev Sets `a.data[i]` to `data`, without bounds checking.
    function set(uint256[] memory a, uint256 i, address data)
        internal
        pure
        returns (uint256[] memory result)
    {
        result = a;
        /// @solidity memory-safe-assembly
        assembly {
            mstore(add(add(result, 0x20), shl(5, i)), shr(96, shl(96, data)))
        }
    }

    /// @dev Sets `a.data[i]` to `data`, without bounds checking.
    function set(uint256[] memory a, uint256 i, bool data)
        internal
        pure
        returns (uint256[] memory result)
    {
        result = a;
        /// @solidity memory-safe-assembly
        assembly {
            mstore(add(add(result, 0x20), shl(5, i)), iszero(iszero(data)))
        }
    }

    /// @dev Sets `a.data[i]` to `data`, without bounds checking.
    function set(uint256[] memory a, uint256 i, bytes32 data)
        internal
        pure
        returns (uint256[] memory result)
    {
        result = a;
        /// @solidity memory-safe-assembly
        assembly {
            mstore(add(add(result, 0x20), shl(5, i)), data)
        }
    }

    /// @dev Casts `a` to `address[]`.
    function asAddressArray(uint256[] memory a) internal pure returns (address[] memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := a
        }
    }

    /// @dev Casts `a` to `bool[]`.
    function asBoolArray(uint256[] memory a) internal pure returns (bool[] memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := a
        }
    }

    /// @dev Casts `a` to `bytes32[]`.
    function asBytes32Array(uint256[] memory a) internal pure returns (bytes32[] memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := a
        }
    }

    /// @dev Casts `a` to `uint256[]`.
    function toUint256Array(address[] memory a) internal pure returns (uint256[] memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := a
        }
    }

    /// @dev Casts `a` to `uint256[]`.
    function toUint256Array(bool[] memory a) internal pure returns (uint256[] memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := a
        }
    }

    /// @dev Casts `a` to `uint256[]`.
    function toUint256Array(bytes32[] memory a) internal pure returns (uint256[] memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := a
        }
    }

    /// @dev Reduces the size of `a` to `n`.
    /// If `n` is greater than the size of `a`, this will be a no-op.
    function truncate(uint256[] memory a, uint256 n)
        internal
        pure
        returns (uint256[] memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := a
            mstore(mul(lt(n, mload(result)), result), n)
        }
    }

    /// @dev Clears the array and attempts to free the memory if possible.
    function free(uint256[] memory a) internal pure returns (uint256[] memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := a
            let n := mload(result)
            mstore(shl(6, lt(iszero(n), eq(add(shl(5, add(1, n)), result), mload(0x40)))), result)
            mstore(result, 0)
        }
    }

    /// @dev Equivalent to `keccak256(abi.encodePacked(a))`.
    function hash(uint256[] memory a) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := keccak256(add(a, 0x20), shl(5, mload(a)))
        }
    }

    /// @dev Returns a copy of `a` sliced from `start` to `end` (exclusive).
    function slice(uint256[] memory a, uint256 start, uint256 end)
        internal
        pure
        returns (uint256[] memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let arrayLen := mload(a)
            if iszero(gt(arrayLen, end)) { end := arrayLen }
            if iszero(gt(arrayLen, start)) { start := arrayLen }
            if lt(start, end) {
                result := mload(0x40)
                let resultLen := sub(end, start)
                mstore(result, resultLen)
                a := add(a, shl(5, start))
                // Copy the `a` one word at a time, backwards.
                let o := shl(5, resultLen)
                mstore(0x40, add(add(result, o), 0x20)) // Allocate memory.
                for {} 1 {} {
                    mstore(add(result, o), mload(add(a, o)))
                    o := sub(o, 0x20)
                    if iszero(o) { break }
                }
            }
        }
    }

    /// @dev Returns a copy of `a` sliced from `start` to the end of the array.
    function slice(uint256[] memory a, uint256 start)
        internal
        pure
        returns (uint256[] memory result)
    {
        result = slice(a, start, type(uint256).max);
    }

    /// @dev Returns a copy of the array.
    function copy(uint256[] memory a) internal pure returns (uint256[] memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let end := add(add(result, 0x20), shl(5, mload(a)))
            let o := result
            for { let d := sub(a, result) } 1 {} {
                mstore(o, mload(add(o, d)))
                o := add(0x20, o)
                if eq(o, end) { break }
            }
            mstore(0x40, o)
        }
    }

    /// @dev Returns if `needle` is in `a`.
    function contains(uint256[] memory a, uint256 needle) internal pure returns (bool) {
        return ~indexOf(a, needle, 0) != 0;
    }

    /// @dev Returns the first index of `needle`, scanning forward from `from`.
    /// If `needle` is not in `a`, returns `NOT_FOUND`.
    function indexOf(uint256[] memory a, uint256 needle, uint256 from)
        internal
        pure
        returns (uint256 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := not(0)
            if lt(from, mload(a)) {
                let o := add(a, shl(5, from))
                let end := add(shl(5, add(1, mload(a))), a)
                let c := mload(end) // Cache the word after the array.
                for { mstore(end, needle) } 1 {} {
                    o := add(o, 0x20)
                    if eq(mload(o), needle) { break }
                }
                mstore(end, c) // Restore the word after the array.
                if iszero(eq(o, end)) { result := shr(5, sub(o, add(0x20, a))) }
            }
        }
    }

    /// @dev Returns the first index of `needle`.
    /// If `needle` is not in `a`, returns `NOT_FOUND`.
    function indexOf(uint256[] memory a, uint256 needle) internal pure returns (uint256 result) {
        result = indexOf(a, needle, 0);
    }

    /// @dev Returns the last index of `needle`, scanning backwards from `from`.
    /// If `needle` is not in `a`, returns `NOT_FOUND`.
    function lastIndexOf(uint256[] memory a, uint256 needle, uint256 from)
        internal
        pure
        returns (uint256 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := not(0)
            let n := mload(a)
            if n {
                if iszero(lt(from, n)) { from := sub(n, 1) }
                let o := add(shl(5, add(2, from)), a)
                for { mstore(a, needle) } 1 {} {
                    o := sub(o, 0x20)
                    if eq(mload(o), needle) { break }
                }
                mstore(a, n) // Restore the length.
                if iszero(eq(o, a)) { result := shr(5, sub(o, add(0x20, a))) }
            }
        }
    }

    /// @dev Returns the first index of `needle`.
    /// If `needle` is not in `a`, returns `NOT_FOUND`.
    function lastIndexOf(uint256[] memory a, uint256 needle)
        internal
        pure
        returns (uint256 result)
    {
        result = lastIndexOf(a, needle, NOT_FOUND);
    }

    /// @dev Directly returns `a` without copying.
    function directReturn(uint256[] memory a) internal pure {
        assembly {
            let retStart := sub(a, 0x20)
            mstore(retStart, 0x20)
            return(retStart, add(0x40, shl(5, mload(a))))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  DYNAMIC ARRAY OPERATIONS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Some of these functions returns the same array for function chaining.
    // e.g. `a.p("1").p("2")`.

    /// @dev Shorthand for `a.data.length`.
    function length(DynamicArray memory a) internal pure returns (uint256) {
        return a.data.length;
    }

    /// @dev Wraps `a` in a dynamic array struct.
    function wrap(uint256[] memory a) internal pure returns (DynamicArray memory result) {
        result.data = a;
    }

    /// @dev Wraps `a` in a dynamic array struct.
    function wrap(address[] memory a) internal pure returns (DynamicArray memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(result, a)
        }
    }

    /// @dev Wraps `a` in a dynamic array struct.
    function wrap(bool[] memory a) internal pure returns (DynamicArray memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(result, a)
        }
    }

    /// @dev Wraps `a` in a dynamic array struct.
    function wrap(bytes32[] memory a) internal pure returns (DynamicArray memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(result, a)
        }
    }

    /// @dev Clears the array without deallocating the memory.
    function clear(DynamicArray memory a) internal pure returns (DynamicArray memory result) {
        _deallocate(result);
        result = a;
        /// @solidity memory-safe-assembly
        assembly {
            mstore(mload(result), 0)
        }
    }

    /// @dev Clears the array and attempts to free the memory if possible.
    function free(DynamicArray memory a) internal pure returns (DynamicArray memory result) {
        _deallocate(result);
        result = a;
        /// @solidity memory-safe-assembly
        assembly {
            let arrData := mload(result)
            if iszero(eq(arrData, 0x60)) {
                let prime := 8188386068317523
                let cap := mload(sub(arrData, 0x20))
                // Extract `cap`, initializing it to zero if it is not a multiple of `prime`.
                cap := mul(div(cap, prime), iszero(mod(cap, prime)))
                // If `cap` is non-zero and the memory is contiguous, we can free it.
                if lt(iszero(cap), eq(mload(0x40), add(arrData, add(0x20, cap)))) {
                    mstore(0x40, sub(arrData, 0x20))
                }
                mstore(result, 0x60)
            }
        }
    }

    /// @dev Resizes the array to contain `n` elements. New elements will be zeroized.
    function resize(DynamicArray memory a, uint256 n)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        reserve(result, n);
        /// @solidity memory-safe-assembly
        assembly {
            let arrData := mload(result)
            let arrLen := mload(arrData)
            if iszero(lt(n, arrLen)) {
                calldatacopy(
                    add(arrData, shl(5, add(1, arrLen))), calldatasize(), shl(5, sub(n, arrLen))
                )
            }
            mstore(arrData, n)
        }
    }

    /// @dev Increases the size of `a` to `n`.
    /// If `n` is less than the size of `a`, this will be a no-op.
    /// This method does not zeroize any newly created elements.
    function expand(DynamicArray memory a, uint256 n)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        if (n >= a.data.length) {
            reserve(result, n);
            /// @solidity memory-safe-assembly
            assembly {
                mstore(mload(result), n)
            }
        }
    }

    /// @dev Reduces the size of `a` to `n`.
    /// If `n` is greater than the size of `a`, this will be a no-op.
    function truncate(DynamicArray memory a, uint256 n)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        /// @solidity memory-safe-assembly
        assembly {
            mstore(mul(lt(n, mload(mload(result))), mload(result)), n)
        }
    }

    /// @dev Reserves at least `minimum` amount of contiguous memory.
    function reserve(DynamicArray memory a, uint256 minimum)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(lt(minimum, 0xffffffff)) { invalid() } // For extra safety.
            for { let arrData := mload(a) } 1 {} {
                // Some random prime number to multiply `cap`, so that
                // we know that the `cap` is for a dynamic array.
                // Selected to be larger than any memory pointer realistically.
                let prime := 8188386068317523
                // Special case for `arrData` pointing to zero pointer.
                if eq(arrData, 0x60) {
                    let newCap := shl(5, add(1, minimum))
                    let capSlot := mload(0x40)
                    mstore(capSlot, mul(prime, newCap)) // Store the capacity.
                    let newArrData := add(0x20, capSlot)
                    mstore(newArrData, 0) // Store the length.
                    mstore(0x40, add(newArrData, add(0x20, newCap))) // Allocate memory.
                    mstore(a, newArrData)
                    break
                }
                let w := not(0x1f)
                let cap := mload(add(arrData, w)) // `mload(sub(arrData, w))`.
                // Extract `cap`, initializing it to zero if it is not a multiple of `prime`.
                cap := mul(div(cap, prime), iszero(mod(cap, prime)))
                let newCap := shl(5, minimum)
                // If we don't need to grow the memory.
                if iszero(and(gt(minimum, mload(arrData)), gt(newCap, cap))) { break }
                // If the memory is contiguous, we can simply expand it.
                if eq(mload(0x40), add(arrData, add(0x20, cap))) {
                    mstore(add(arrData, w), mul(prime, newCap)) // Store the capacity.
                    mstore(0x40, add(arrData, add(0x20, newCap))) // Expand the memory allocation.
                    break
                }
                let capSlot := mload(0x40)
                let newArrData := add(capSlot, 0x20)
                mstore(0x40, add(newArrData, add(0x20, newCap))) // Reallocate the memory.
                mstore(a, newArrData) // Store the `newArrData`.
                // Copy `arrData` one word at a time, backwards.
                for { let o := add(0x20, shl(5, mload(arrData))) } 1 {} {
                    mstore(add(newArrData, o), mload(add(arrData, o)))
                    o := add(o, w) // `sub(o, 0x20)`.
                    if iszero(o) { break }
                }
                mstore(capSlot, mul(prime, newCap)) // Store the capacity.
                mstore(newArrData, mload(arrData)) // Store the length.
                break
            }
        }
    }

    /// @dev Appends `data` to `a`.
    function p(DynamicArray memory a, uint256 data)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        /// @solidity memory-safe-assembly
        assembly {
            let arrData := mload(a)
            let newArrLen := add(mload(arrData), 1)
            let newArrBytesLen := shl(5, newArrLen)
            // Some random prime number to multiply `cap`, so that
            // we know that the `cap` is for a dynamic array.
            // Selected to be larger than any memory pointer realistically.
            let prime := 8188386068317523
            let cap := mload(sub(arrData, 0x20))
            // Extract `cap`, initializing it to zero if it is not a multiple of `prime`.
            cap := mul(div(cap, prime), iszero(mod(cap, prime)))

            // Expand / Reallocate memory if required.
            // Note that we need to allocate an extra word for the length.
            for {} iszero(lt(newArrBytesLen, cap)) {} {
                // Approximately more than double the capacity to ensure more than enough space.
                let newCap := add(cap, or(cap, newArrBytesLen))
                // If the memory is contiguous, we can simply expand it.
                if iszero(or(xor(mload(0x40), add(arrData, add(0x20, cap))), eq(arrData, 0x60))) {
                    mstore(sub(arrData, 0x20), mul(prime, newCap)) // Store the capacity.
                    mstore(0x40, add(arrData, add(0x20, newCap))) // Expand the memory allocation.
                    break
                }
                // Set the `newArrData` to point to the word after `cap`.
                let newArrData := add(mload(0x40), 0x20)
                mstore(0x40, add(newArrData, add(0x20, newCap))) // Reallocate the memory.
                mstore(a, newArrData) // Store the `newArrData`.
                let w := not(0x1f)
                // Copy `arrData` one word at a time, backwards.
                for { let o := newArrBytesLen } 1 {} {
                    mstore(add(newArrData, o), mload(add(arrData, o)))
                    o := add(o, w) // `sub(o, 0x20)`.
                    if iszero(o) { break }
                }
                mstore(add(newArrData, w), mul(prime, newCap)) // Store the memory.
                arrData := newArrData // Assign `newArrData` to `arrData`.
                break
            }
            mstore(add(arrData, newArrBytesLen), data) // Append `data`.
            mstore(arrData, newArrLen) // Store the length.
        }
    }

    /// @dev Appends `data` to `a`.
    function p(DynamicArray memory a, address data)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = p(a, uint256(uint160(data)));
    }

    /// @dev Appends `data` to `a`.
    function p(DynamicArray memory a, bool data)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = p(a, _toUint(data));
    }

    /// @dev Appends `data` to `a`.
    function p(DynamicArray memory a, bytes32 data)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = p(a, uint256(data));
    }

    /// @dev Shorthand for returning an empty array.
    function p() internal pure returns (DynamicArray memory result) {}

    /// @dev Shorthand for `p(p(), data)`.
    function p(uint256 data) internal pure returns (DynamicArray memory result) {
        p(result, uint256(data));
    }

    /// @dev Shorthand for `p(p(), data)`.
    function p(address data) internal pure returns (DynamicArray memory result) {
        p(result, uint256(uint160(data)));
    }

    /// @dev Shorthand for `p(p(), data)`.
    function p(bool data) internal pure returns (DynamicArray memory result) {
        p(result, _toUint(data));
    }

    /// @dev Shorthand for `p(p(), data)`.
    function p(bytes32 data) internal pure returns (DynamicArray memory result) {
        p(result, uint256(data));
    }

    /// @dev Removes and returns the last element of `a`.
    /// Returns 0 and does not pop anything if the array is empty.
    function pop(DynamicArray memory a) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let o := mload(a)
            let n := mload(o)
            result := mload(add(o, shl(5, n)))
            mstore(o, sub(n, iszero(iszero(n))))
        }
    }

    /// @dev Removes and returns the last element of `a`.
    /// Returns 0 and does not pop anything if the array is empty.
    function popUint256(DynamicArray memory a) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let o := mload(a)
            let n := mload(o)
            result := mload(add(o, shl(5, n)))
            mstore(o, sub(n, iszero(iszero(n))))
        }
    }

    /// @dev Removes and returns the last element of `a`.
    /// Returns 0 and does not pop anything if the array is empty.
    function popAddress(DynamicArray memory a) internal pure returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            let o := mload(a)
            let n := mload(o)
            result := mload(add(o, shl(5, n)))
            mstore(o, sub(n, iszero(iszero(n))))
        }
    }

    /// @dev Removes and returns the last element of `a`.
    /// Returns 0 and does not pop anything if the array is empty.
    function popBool(DynamicArray memory a) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            let o := mload(a)
            let n := mload(o)
            result := mload(add(o, shl(5, n)))
            mstore(o, sub(n, iszero(iszero(n))))
        }
    }

    /// @dev Removes and returns the last element of `a`.
    /// Returns 0 and does not pop anything if the array is empty.
    function popBytes32(DynamicArray memory a) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let o := mload(a)
            let n := mload(o)
            result := mload(add(o, shl(5, n)))
            mstore(o, sub(n, iszero(iszero(n))))
        }
    }

    /// @dev Returns the element at `a.data[i]`, without bounds checking.
    function get(DynamicArray memory a, uint256 i) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(add(add(mload(a), 0x20), shl(5, i)))
        }
    }

    /// @dev Returns the element at `a.data[i]`, without bounds checking.
    function getUint256(DynamicArray memory a, uint256 i) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(add(add(mload(a), 0x20), shl(5, i)))
        }
    }

    /// @dev Returns the element at `a.data[i]`, without bounds checking.
    function getAddress(DynamicArray memory a, uint256 i) internal pure returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(add(add(mload(a), 0x20), shl(5, i)))
        }
    }

    /// @dev Returns the element at `a.data[i]`, without bounds checking.
    function getBool(DynamicArray memory a, uint256 i) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(add(add(mload(a), 0x20), shl(5, i)))
        }
    }

    /// @dev Returns the element at `a.data[i]`, without bounds checking.
    function getBytes32(DynamicArray memory a, uint256 i) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(add(add(mload(a), 0x20), shl(5, i)))
        }
    }

    /// @dev Sets `a.data[i]` to `data`, without bounds checking.
    function set(DynamicArray memory a, uint256 i, uint256 data)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        /// @solidity memory-safe-assembly
        assembly {
            mstore(add(add(mload(result), 0x20), shl(5, i)), data)
        }
    }

    /// @dev Sets `a.data[i]` to `data`, without bounds checking.
    function set(DynamicArray memory a, uint256 i, address data)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        /// @solidity memory-safe-assembly
        assembly {
            mstore(add(add(mload(result), 0x20), shl(5, i)), shr(96, shl(96, data)))
        }
    }

    /// @dev Sets `a.data[i]` to `data`, without bounds checking.
    function set(DynamicArray memory a, uint256 i, bool data)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        /// @solidity memory-safe-assembly
        assembly {
            mstore(add(add(mload(result), 0x20), shl(5, i)), iszero(iszero(data)))
        }
    }

    /// @dev Sets `a.data[i]` to `data`, without bounds checking.
    function set(DynamicArray memory a, uint256 i, bytes32 data)
        internal
        pure
        returns (DynamicArray memory result)
    {
        _deallocate(result);
        result = a;
        /// @solidity memory-safe-assembly
        assembly {
            mstore(add(add(mload(result), 0x20), shl(5, i)), data)
        }
    }

    /// @dev Returns the underlying array as a `uint256[]`.
    function asUint256Array(DynamicArray memory a)
        internal
        pure
        returns (uint256[] memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(a)
        }
    }

    /// @dev Returns the underlying array as a `address[]`.
    function asAddressArray(DynamicArray memory a)
        internal
        pure
        returns (address[] memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(a)
        }
    }

    /// @dev Returns the underlying array as a `bool[]`.
    function asBoolArray(DynamicArray memory a) internal pure returns (bool[] memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(a)
        }
    }

    /// @dev Returns the underlying array as a `bytes32[]`.
    function asBytes32Array(DynamicArray memory a)
        internal
        pure
        returns (bytes32[] memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(a)
        }
    }

    /// @dev Returns a copy of `a` sliced from `start` to `end` (exclusive).
    function slice(DynamicArray memory a, uint256 start, uint256 end)
        internal
        pure
        returns (DynamicArray memory result)
    {
        result.data = slice(a.data, start, end);
    }

    /// @dev Returns a copy of `a` sliced from `start` to the end of the array.
    function slice(DynamicArray memory a, uint256 start)
        internal
        pure
        returns (DynamicArray memory result)
    {
        result.data = slice(a.data, start, type(uint256).max);
    }

    /// @dev Returns a copy of `a`.
    function copy(DynamicArray memory a) internal pure returns (DynamicArray memory result) {
        result.data = copy(a.data);
    }

    /// @dev Returns if `needle` is in `a`.
    function contains(DynamicArray memory a, uint256 needle) internal pure returns (bool) {
        return ~indexOf(a.data, needle, 0) != 0;
    }

    /// @dev Returns if `needle` is in `a`.
    function contains(DynamicArray memory a, address needle) internal pure returns (bool) {
        return ~indexOf(a.data, uint160(needle), 0) != 0;
    }

    /// @dev Returns if `needle` is in `a`.
    function contains(DynamicArray memory a, bytes32 needle) internal pure returns (bool) {
        return ~indexOf(a.data, uint256(needle), 0) != 0;
    }

    /// @dev Returns the first index of `needle`, scanning forward from `from`.
    /// If `needle` is not in `a`, returns `NOT_FOUND`.
    function indexOf(DynamicArray memory a, uint256 needle, uint256 from)
        internal
        pure
        returns (uint256)
    {
        return indexOf(a.data, needle, from);
    }

    /// @dev Returns the first index of `needle`, scanning forward from `from`.
    /// If `needle` is not in `a`, returns `NOT_FOUND`.
    function indexOf(DynamicArray memory a, address needle, uint256 from)
        internal
        pure
        returns (uint256)
    {
        return indexOf(a.data, uint160(needle), from);
    }

    /// @dev Returns the first index of `needle`, scanning forward from `from`.
    /// If `needle` is not in `a`, returns `NOT_FOUND`.
    function indexOf(DynamicArray memory a, bytes32 needle, uint256 from)
        internal
        pure
        returns (uint256)
    {
        return indexOf(a.data, uint256(needle), from);
    }

    /// @dev Returns the first index of `needle`.
    /// If `needle` is not in `a`, returns `NOT_FOUND`.
    function indexOf(DynamicArray memory a, uint256 needle) internal pure returns (uint256) {
        return indexOf(a.data, needle, 0);
    }

    /// @dev Returns the first index of `needle`.
    /// If `needle` is not in `a`, returns `NOT_FOUND`.
    function indexOf(DynamicArray memory a, address needle) internal pure returns (uint256) {
        return indexOf(a.data, uint160(needle), 0);
    }

    /// @dev Returns the first index of `needle`.
    /// If `needle` is not in `a`, returns `NOT_FOUND`.
    function indexOf(DynamicArray memory a, bytes32 needle) internal pure returns (uint256) {
        return indexOf(a.data, uint256(needle), 0);
    }

    /// @dev Returns the last index of `needle`, scanning backwards from `from`.
    /// If `needle` is not in `a`, returns `NOT_FOUND`.
    function lastIndexOf(DynamicArray memory a, uint256 needle, uint256 from)
        internal
        pure
        returns (uint256)
    {
        return lastIndexOf(a.data, needle, from);
    }

    /// @dev Returns the last index of `needle`, scanning backwards from `from`.
    /// If `needle` is not in `a`, returns `NOT_FOUND`.
    function lastIndexOf(DynamicArray memory a, address needle, uint256 from)
        internal
        pure
        returns (uint256)
    {
        return lastIndexOf(a.data, uint160(needle), from);
    }

    /// @dev Returns the last index of `needle`, scanning backwards from `from`.
    /// If `needle` is not in `a`, returns `NOT_FOUND`.
    function lastIndexOf(DynamicArray memory a, bytes32 needle, uint256 from)
        internal
        pure
        returns (uint256)
    {
        return lastIndexOf(a.data, uint256(needle), from);
    }

    /// @dev Returns the last index of `needle`.
    /// If `needle` is not in `a`, returns `NOT_FOUND`.
    function lastIndexOf(DynamicArray memory a, uint256 needle) internal pure returns (uint256) {
        return lastIndexOf(a.data, needle, NOT_FOUND);
    }

    /// @dev Returns the last index of `needle`.
    /// If `needle` is not in `a`, returns `NOT_FOUND`.
    function lastIndexOf(DynamicArray memory a, address needle) internal pure returns (uint256) {
        return lastIndexOf(a.data, uint160(needle), NOT_FOUND);
    }

    /// @dev Returns the last index of `needle`.
    /// If `needle` is not in `a`, returns `NOT_FOUND`.
    function lastIndexOf(DynamicArray memory a, bytes32 needle) internal pure returns (uint256) {
        return lastIndexOf(a.data, uint256(needle), NOT_FOUND);
    }

    /// @dev Equivalent to `keccak256(abi.encodePacked(a.data))`.
    function hash(DynamicArray memory a) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := keccak256(add(mload(a), 0x20), shl(5, mload(mload(a))))
        }
    }

    /// @dev Directly returns `a` without copying.
    function directReturn(DynamicArray memory a) internal pure {
        assembly {
            let arrData := mload(a)
            let retStart := sub(arrData, 0x20)
            mstore(retStart, 0x20)
            return(retStart, add(0x40, shl(5, mload(arrData))))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Helper for deallocating a automatically allocated array pointer.
    function _deallocate(DynamicArray memory result) private pure {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x40, result) // Deallocate, as we have already allocated.
        }
    }

    /// @dev Casts the bool into a uint256.
    function _toUint(bool b) private pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := iszero(iszero(b))
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Safe integer casting library that reverts on overflow.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/SafeCastLib.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeCast.sol)
/// @dev Optimized for runtime gas for very high number of optimizer runs (i.e. >= 1000000).
library SafeCastLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Unable to cast to the target type due to overflow.
    error Overflow();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*          UNSIGNED INTEGER SAFE CASTING OPERATIONS          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Casts `x` to a uint8. Reverts on overflow.
    function toUint8(uint256 x) internal pure returns (uint8) {
        if (x >= 1 << 8) _revertOverflow();
        return uint8(x);
    }

    /// @dev Casts `x` to a uint16. Reverts on overflow.
    function toUint16(uint256 x) internal pure returns (uint16) {
        if (x >= 1 << 16) _revertOverflow();
        return uint16(x);
    }

    /// @dev Casts `x` to a uint24. Reverts on overflow.
    function toUint24(uint256 x) internal pure returns (uint24) {
        if (x >= 1 << 24) _revertOverflow();
        return uint24(x);
    }

    /// @dev Casts `x` to a uint32. Reverts on overflow.
    function toUint32(uint256 x) internal pure returns (uint32) {
        if (x >= 1 << 32) _revertOverflow();
        return uint32(x);
    }

    /// @dev Casts `x` to a uint40. Reverts on overflow.
    function toUint40(uint256 x) internal pure returns (uint40) {
        if (x >= 1 << 40) _revertOverflow();
        return uint40(x);
    }

    /// @dev Casts `x` to a uint48. Reverts on overflow.
    function toUint48(uint256 x) internal pure returns (uint48) {
        if (x >= 1 << 48) _revertOverflow();
        return uint48(x);
    }

    /// @dev Casts `x` to a uint56. Reverts on overflow.
    function toUint56(uint256 x) internal pure returns (uint56) {
        if (x >= 1 << 56) _revertOverflow();
        return uint56(x);
    }

    /// @dev Casts `x` to a uint64. Reverts on overflow.
    function toUint64(uint256 x) internal pure returns (uint64) {
        if (x >= 1 << 64) _revertOverflow();
        return uint64(x);
    }

    /// @dev Casts `x` to a uint72. Reverts on overflow.
    function toUint72(uint256 x) internal pure returns (uint72) {
        if (x >= 1 << 72) _revertOverflow();
        return uint72(x);
    }

    /// @dev Casts `x` to a uint80. Reverts on overflow.
    function toUint80(uint256 x) internal pure returns (uint80) {
        if (x >= 1 << 80) _revertOverflow();
        return uint80(x);
    }

    /// @dev Casts `x` to a uint88. Reverts on overflow.
    function toUint88(uint256 x) internal pure returns (uint88) {
        if (x >= 1 << 88) _revertOverflow();
        return uint88(x);
    }

    /// @dev Casts `x` to a uint96. Reverts on overflow.
    function toUint96(uint256 x) internal pure returns (uint96) {
        if (x >= 1 << 96) _revertOverflow();
        return uint96(x);
    }

    /// @dev Casts `x` to a uint104. Reverts on overflow.
    function toUint104(uint256 x) internal pure returns (uint104) {
        if (x >= 1 << 104) _revertOverflow();
        return uint104(x);
    }

    /// @dev Casts `x` to a uint112. Reverts on overflow.
    function toUint112(uint256 x) internal pure returns (uint112) {
        if (x >= 1 << 112) _revertOverflow();
        return uint112(x);
    }

    /// @dev Casts `x` to a uint120. Reverts on overflow.
    function toUint120(uint256 x) internal pure returns (uint120) {
        if (x >= 1 << 120) _revertOverflow();
        return uint120(x);
    }

    /// @dev Casts `x` to a uint128. Reverts on overflow.
    function toUint128(uint256 x) internal pure returns (uint128) {
        if (x >= 1 << 128) _revertOverflow();
        return uint128(x);
    }

    /// @dev Casts `x` to a uint136. Reverts on overflow.
    function toUint136(uint256 x) internal pure returns (uint136) {
        if (x >= 1 << 136) _revertOverflow();
        return uint136(x);
    }

    /// @dev Casts `x` to a uint144. Reverts on overflow.
    function toUint144(uint256 x) internal pure returns (uint144) {
        if (x >= 1 << 144) _revertOverflow();
        return uint144(x);
    }

    /// @dev Casts `x` to a uint152. Reverts on overflow.
    function toUint152(uint256 x) internal pure returns (uint152) {
        if (x >= 1 << 152) _revertOverflow();
        return uint152(x);
    }

    /// @dev Casts `x` to a uint160. Reverts on overflow.
    function toUint160(uint256 x) internal pure returns (uint160) {
        if (x >= 1 << 160) _revertOverflow();
        return uint160(x);
    }

    /// @dev Casts `x` to a uint168. Reverts on overflow.
    function toUint168(uint256 x) internal pure returns (uint168) {
        if (x >= 1 << 168) _revertOverflow();
        return uint168(x);
    }

    /// @dev Casts `x` to a uint176. Reverts on overflow.
    function toUint176(uint256 x) internal pure returns (uint176) {
        if (x >= 1 << 176) _revertOverflow();
        return uint176(x);
    }

    /// @dev Casts `x` to a uint184. Reverts on overflow.
    function toUint184(uint256 x) internal pure returns (uint184) {
        if (x >= 1 << 184) _revertOverflow();
        return uint184(x);
    }

    /// @dev Casts `x` to a uint192. Reverts on overflow.
    function toUint192(uint256 x) internal pure returns (uint192) {
        if (x >= 1 << 192) _revertOverflow();
        return uint192(x);
    }

    /// @dev Casts `x` to a uint200. Reverts on overflow.
    function toUint200(uint256 x) internal pure returns (uint200) {
        if (x >= 1 << 200) _revertOverflow();
        return uint200(x);
    }

    /// @dev Casts `x` to a uint208. Reverts on overflow.
    function toUint208(uint256 x) internal pure returns (uint208) {
        if (x >= 1 << 208) _revertOverflow();
        return uint208(x);
    }

    /// @dev Casts `x` to a uint216. Reverts on overflow.
    function toUint216(uint256 x) internal pure returns (uint216) {
        if (x >= 1 << 216) _revertOverflow();
        return uint216(x);
    }

    /// @dev Casts `x` to a uint224. Reverts on overflow.
    function toUint224(uint256 x) internal pure returns (uint224) {
        if (x >= 1 << 224) _revertOverflow();
        return uint224(x);
    }

    /// @dev Casts `x` to a uint232. Reverts on overflow.
    function toUint232(uint256 x) internal pure returns (uint232) {
        if (x >= 1 << 232) _revertOverflow();
        return uint232(x);
    }

    /// @dev Casts `x` to a uint240. Reverts on overflow.
    function toUint240(uint256 x) internal pure returns (uint240) {
        if (x >= 1 << 240) _revertOverflow();
        return uint240(x);
    }

    /// @dev Casts `x` to a uint248. Reverts on overflow.
    function toUint248(uint256 x) internal pure returns (uint248) {
        if (x >= 1 << 248) _revertOverflow();
        return uint248(x);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*           SIGNED INTEGER SAFE CASTING OPERATIONS           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Casts `x` to a int8. Reverts on overflow.
    function toInt8(int256 x) internal pure returns (int8) {
        unchecked {
            if (((1 << 7) + uint256(x)) >> 8 == uint256(0)) return int8(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int16. Reverts on overflow.
    function toInt16(int256 x) internal pure returns (int16) {
        unchecked {
            if (((1 << 15) + uint256(x)) >> 16 == uint256(0)) return int16(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int24. Reverts on overflow.
    function toInt24(int256 x) internal pure returns (int24) {
        unchecked {
            if (((1 << 23) + uint256(x)) >> 24 == uint256(0)) return int24(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int32. Reverts on overflow.
    function toInt32(int256 x) internal pure returns (int32) {
        unchecked {
            if (((1 << 31) + uint256(x)) >> 32 == uint256(0)) return int32(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int40. Reverts on overflow.
    function toInt40(int256 x) internal pure returns (int40) {
        unchecked {
            if (((1 << 39) + uint256(x)) >> 40 == uint256(0)) return int40(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int48. Reverts on overflow.
    function toInt48(int256 x) internal pure returns (int48) {
        unchecked {
            if (((1 << 47) + uint256(x)) >> 48 == uint256(0)) return int48(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int56. Reverts on overflow.
    function toInt56(int256 x) internal pure returns (int56) {
        unchecked {
            if (((1 << 55) + uint256(x)) >> 56 == uint256(0)) return int56(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int64. Reverts on overflow.
    function toInt64(int256 x) internal pure returns (int64) {
        unchecked {
            if (((1 << 63) + uint256(x)) >> 64 == uint256(0)) return int64(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int72. Reverts on overflow.
    function toInt72(int256 x) internal pure returns (int72) {
        unchecked {
            if (((1 << 71) + uint256(x)) >> 72 == uint256(0)) return int72(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int80. Reverts on overflow.
    function toInt80(int256 x) internal pure returns (int80) {
        unchecked {
            if (((1 << 79) + uint256(x)) >> 80 == uint256(0)) return int80(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int88. Reverts on overflow.
    function toInt88(int256 x) internal pure returns (int88) {
        unchecked {
            if (((1 << 87) + uint256(x)) >> 88 == uint256(0)) return int88(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int96. Reverts on overflow.
    function toInt96(int256 x) internal pure returns (int96) {
        unchecked {
            if (((1 << 95) + uint256(x)) >> 96 == uint256(0)) return int96(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int104. Reverts on overflow.
    function toInt104(int256 x) internal pure returns (int104) {
        unchecked {
            if (((1 << 103) + uint256(x)) >> 104 == uint256(0)) return int104(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int112. Reverts on overflow.
    function toInt112(int256 x) internal pure returns (int112) {
        unchecked {
            if (((1 << 111) + uint256(x)) >> 112 == uint256(0)) return int112(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int120. Reverts on overflow.
    function toInt120(int256 x) internal pure returns (int120) {
        unchecked {
            if (((1 << 119) + uint256(x)) >> 120 == uint256(0)) return int120(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int128. Reverts on overflow.
    function toInt128(int256 x) internal pure returns (int128) {
        unchecked {
            if (((1 << 127) + uint256(x)) >> 128 == uint256(0)) return int128(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int136. Reverts on overflow.
    function toInt136(int256 x) internal pure returns (int136) {
        unchecked {
            if (((1 << 135) + uint256(x)) >> 136 == uint256(0)) return int136(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int144. Reverts on overflow.
    function toInt144(int256 x) internal pure returns (int144) {
        unchecked {
            if (((1 << 143) + uint256(x)) >> 144 == uint256(0)) return int144(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int152. Reverts on overflow.
    function toInt152(int256 x) internal pure returns (int152) {
        unchecked {
            if (((1 << 151) + uint256(x)) >> 152 == uint256(0)) return int152(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int160. Reverts on overflow.
    function toInt160(int256 x) internal pure returns (int160) {
        unchecked {
            if (((1 << 159) + uint256(x)) >> 160 == uint256(0)) return int160(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int168. Reverts on overflow.
    function toInt168(int256 x) internal pure returns (int168) {
        unchecked {
            if (((1 << 167) + uint256(x)) >> 168 == uint256(0)) return int168(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int176. Reverts on overflow.
    function toInt176(int256 x) internal pure returns (int176) {
        unchecked {
            if (((1 << 175) + uint256(x)) >> 176 == uint256(0)) return int176(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int184. Reverts on overflow.
    function toInt184(int256 x) internal pure returns (int184) {
        unchecked {
            if (((1 << 183) + uint256(x)) >> 184 == uint256(0)) return int184(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int192. Reverts on overflow.
    function toInt192(int256 x) internal pure returns (int192) {
        unchecked {
            if (((1 << 191) + uint256(x)) >> 192 == uint256(0)) return int192(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int200. Reverts on overflow.
    function toInt200(int256 x) internal pure returns (int200) {
        unchecked {
            if (((1 << 199) + uint256(x)) >> 200 == uint256(0)) return int200(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int208. Reverts on overflow.
    function toInt208(int256 x) internal pure returns (int208) {
        unchecked {
            if (((1 << 207) + uint256(x)) >> 208 == uint256(0)) return int208(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int216. Reverts on overflow.
    function toInt216(int256 x) internal pure returns (int216) {
        unchecked {
            if (((1 << 215) + uint256(x)) >> 216 == uint256(0)) return int216(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int224. Reverts on overflow.
    function toInt224(int256 x) internal pure returns (int224) {
        unchecked {
            if (((1 << 223) + uint256(x)) >> 224 == uint256(0)) return int224(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int232. Reverts on overflow.
    function toInt232(int256 x) internal pure returns (int232) {
        unchecked {
            if (((1 << 231) + uint256(x)) >> 232 == uint256(0)) return int232(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int240. Reverts on overflow.
    function toInt240(int256 x) internal pure returns (int240) {
        unchecked {
            if (((1 << 239) + uint256(x)) >> 240 == uint256(0)) return int240(x);
            _revertOverflow();
        }
    }

    /// @dev Casts `x` to a int248. Reverts on overflow.
    function toInt248(int256 x) internal pure returns (int248) {
        unchecked {
            if (((1 << 247) + uint256(x)) >> 248 == uint256(0)) return int248(x);
            _revertOverflow();
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*               OTHER SAFE CASTING OPERATIONS                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Casts `x` to a int8. Reverts on overflow.
    function toInt8(uint256 x) internal pure returns (int8) {
        if (x >= 1 << 7) _revertOverflow();
        return int8(int256(x));
    }

    /// @dev Casts `x` to a int16. Reverts on overflow.
    function toInt16(uint256 x) internal pure returns (int16) {
        if (x >= 1 << 15) _revertOverflow();
        return int16(int256(x));
    }

    /// @dev Casts `x` to a int24. Reverts on overflow.
    function toInt24(uint256 x) internal pure returns (int24) {
        if (x >= 1 << 23) _revertOverflow();
        return int24(int256(x));
    }

    /// @dev Casts `x` to a int32. Reverts on overflow.
    function toInt32(uint256 x) internal pure returns (int32) {
        if (x >= 1 << 31) _revertOverflow();
        return int32(int256(x));
    }

    /// @dev Casts `x` to a int40. Reverts on overflow.
    function toInt40(uint256 x) internal pure returns (int40) {
        if (x >= 1 << 39) _revertOverflow();
        return int40(int256(x));
    }

    /// @dev Casts `x` to a int48. Reverts on overflow.
    function toInt48(uint256 x) internal pure returns (int48) {
        if (x >= 1 << 47) _revertOverflow();
        return int48(int256(x));
    }

    /// @dev Casts `x` to a int56. Reverts on overflow.
    function toInt56(uint256 x) internal pure returns (int56) {
        if (x >= 1 << 55) _revertOverflow();
        return int56(int256(x));
    }

    /// @dev Casts `x` to a int64. Reverts on overflow.
    function toInt64(uint256 x) internal pure returns (int64) {
        if (x >= 1 << 63) _revertOverflow();
        return int64(int256(x));
    }

    /// @dev Casts `x` to a int72. Reverts on overflow.
    function toInt72(uint256 x) internal pure returns (int72) {
        if (x >= 1 << 71) _revertOverflow();
        return int72(int256(x));
    }

    /// @dev Casts `x` to a int80. Reverts on overflow.
    function toInt80(uint256 x) internal pure returns (int80) {
        if (x >= 1 << 79) _revertOverflow();
        return int80(int256(x));
    }

    /// @dev Casts `x` to a int88. Reverts on overflow.
    function toInt88(uint256 x) internal pure returns (int88) {
        if (x >= 1 << 87) _revertOverflow();
        return int88(int256(x));
    }

    /// @dev Casts `x` to a int96. Reverts on overflow.
    function toInt96(uint256 x) internal pure returns (int96) {
        if (x >= 1 << 95) _revertOverflow();
        return int96(int256(x));
    }

    /// @dev Casts `x` to a int104. Reverts on overflow.
    function toInt104(uint256 x) internal pure returns (int104) {
        if (x >= 1 << 103) _revertOverflow();
        return int104(int256(x));
    }

    /// @dev Casts `x` to a int112. Reverts on overflow.
    function toInt112(uint256 x) internal pure returns (int112) {
        if (x >= 1 << 111) _revertOverflow();
        return int112(int256(x));
    }

    /// @dev Casts `x` to a int120. Reverts on overflow.
    function toInt120(uint256 x) internal pure returns (int120) {
        if (x >= 1 << 119) _revertOverflow();
        return int120(int256(x));
    }

    /// @dev Casts `x` to a int128. Reverts on overflow.
    function toInt128(uint256 x) internal pure returns (int128) {
        if (x >= 1 << 127) _revertOverflow();
        return int128(int256(x));
    }

    /// @dev Casts `x` to a int136. Reverts on overflow.
    function toInt136(uint256 x) internal pure returns (int136) {
        if (x >= 1 << 135) _revertOverflow();
        return int136(int256(x));
    }

    /// @dev Casts `x` to a int144. Reverts on overflow.
    function toInt144(uint256 x) internal pure returns (int144) {
        if (x >= 1 << 143) _revertOverflow();
        return int144(int256(x));
    }

    /// @dev Casts `x` to a int152. Reverts on overflow.
    function toInt152(uint256 x) internal pure returns (int152) {
        if (x >= 1 << 151) _revertOverflow();
        return int152(int256(x));
    }

    /// @dev Casts `x` to a int160. Reverts on overflow.
    function toInt160(uint256 x) internal pure returns (int160) {
        if (x >= 1 << 159) _revertOverflow();
        return int160(int256(x));
    }

    /// @dev Casts `x` to a int168. Reverts on overflow.
    function toInt168(uint256 x) internal pure returns (int168) {
        if (x >= 1 << 167) _revertOverflow();
        return int168(int256(x));
    }

    /// @dev Casts `x` to a int176. Reverts on overflow.
    function toInt176(uint256 x) internal pure returns (int176) {
        if (x >= 1 << 175) _revertOverflow();
        return int176(int256(x));
    }

    /// @dev Casts `x` to a int184. Reverts on overflow.
    function toInt184(uint256 x) internal pure returns (int184) {
        if (x >= 1 << 183) _revertOverflow();
        return int184(int256(x));
    }

    /// @dev Casts `x` to a int192. Reverts on overflow.
    function toInt192(uint256 x) internal pure returns (int192) {
        if (x >= 1 << 191) _revertOverflow();
        return int192(int256(x));
    }

    /// @dev Casts `x` to a int200. Reverts on overflow.
    function toInt200(uint256 x) internal pure returns (int200) {
        if (x >= 1 << 199) _revertOverflow();
        return int200(int256(x));
    }

    /// @dev Casts `x` to a int208. Reverts on overflow.
    function toInt208(uint256 x) internal pure returns (int208) {
        if (x >= 1 << 207) _revertOverflow();
        return int208(int256(x));
    }

    /// @dev Casts `x` to a int216. Reverts on overflow.
    function toInt216(uint256 x) internal pure returns (int216) {
        if (x >= 1 << 215) _revertOverflow();
        return int216(int256(x));
    }

    /// @dev Casts `x` to a int224. Reverts on overflow.
    function toInt224(uint256 x) internal pure returns (int224) {
        if (x >= 1 << 223) _revertOverflow();
        return int224(int256(x));
    }

    /// @dev Casts `x` to a int232. Reverts on overflow.
    function toInt232(uint256 x) internal pure returns (int232) {
        if (x >= 1 << 231) _revertOverflow();
        return int232(int256(x));
    }

    /// @dev Casts `x` to a int240. Reverts on overflow.
    function toInt240(uint256 x) internal pure returns (int240) {
        if (x >= 1 << 239) _revertOverflow();
        return int240(int256(x));
    }

    /// @dev Casts `x` to a int248. Reverts on overflow.
    function toInt248(uint256 x) internal pure returns (int248) {
        if (x >= 1 << 247) _revertOverflow();
        return int248(int256(x));
    }

    /// @dev Casts `x` to a int256. Reverts on overflow.
    function toInt256(uint256 x) internal pure returns (int256) {
        if (int256(x) >= 0) return int256(x);
        _revertOverflow();
    }

    /// @dev Casts `x` to a uint256. Reverts on overflow.
    function toUint256(int256 x) internal pure returns (uint256) {
        if (x >= 0) return uint256(x);
        _revertOverflow();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _revertOverflow() private pure {
        /// @solidity memory-safe-assembly
        assembly {
            // Store the function selector of `Overflow()`.
            mstore(0x00, 0x35278d12)
            // Revert with (offset, size).
            revert(0x1c, 0x04)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {LibBytes} from "./LibBytes.sol";

/// @notice Library for converting numbers into strings and other string operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibString.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/LibString.sol)
///
/// @dev Note:
/// For performance and bytecode compactness, most of the string operations are restricted to
/// byte strings (7-bit ASCII), except where otherwise specified.
/// Usage of byte string operations on charsets with runes spanning two or more bytes
/// can lead to undefined behavior.
library LibString {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Goated string storage struct that totally MOGs, no cap, fr.
    /// Uses less gas and bytecode than Solidity's native string storage. It's meta af.
    /// Packs length with the first 31 bytes if <255 bytes, so it’s mad tight.
    struct StringStorage {
        bytes32 _spacer;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The length of the output is too small to contain all the hex digits.
    error HexLengthInsufficient();

    /// @dev The length of the string is more than 32 bytes.
    error TooBigForSmallString();

    /// @dev The input string must be a 7-bit ASCII.
    error StringNot7BitASCII();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The constant returned when the `search` is not found in the string.
    uint256 internal constant NOT_FOUND = type(uint256).max;

    /// @dev Lookup for '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.
    uint128 internal constant ALPHANUMERIC_7_BIT_ASCII = 0x7fffffe07fffffe03ff000000000000;

    /// @dev Lookup for 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.
    uint128 internal constant LETTERS_7_BIT_ASCII = 0x7fffffe07fffffe0000000000000000;

    /// @dev Lookup for 'abcdefghijklmnopqrstuvwxyz'.
    uint128 internal constant LOWERCASE_7_BIT_ASCII = 0x7fffffe000000000000000000000000;

    /// @dev Lookup for 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
    uint128 internal constant UPPERCASE_7_BIT_ASCII = 0x7fffffe0000000000000000;

    /// @dev Lookup for '0123456789'.
    uint128 internal constant DIGITS_7_BIT_ASCII = 0x3ff000000000000;

    /// @dev Lookup for '0123456789abcdefABCDEF'.
    uint128 internal constant HEXDIGITS_7_BIT_ASCII = 0x7e0000007e03ff000000000000;

    /// @dev Lookup for '01234567'.
    uint128 internal constant OCTDIGITS_7_BIT_ASCII = 0xff000000000000;

    /// @dev Lookup for '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~ \t\n\r\x0b\x0c'.
    uint128 internal constant PRINTABLE_7_BIT_ASCII = 0x7fffffffffffffffffffffff00003e00;

    /// @dev Lookup for '!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~'.
    uint128 internal constant PUNCTUATION_7_BIT_ASCII = 0x78000001f8000001fc00fffe00000000;

    /// @dev Lookup for ' \t\n\r\x0b\x0c'.
    uint128 internal constant WHITESPACE_7_BIT_ASCII = 0x100003e00;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 STRING STORAGE OPERATIONS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Sets the value of the string storage `$` to `s`.
    function set(StringStorage storage $, string memory s) internal {
        LibBytes.set(bytesStorage($), bytes(s));
    }

    /// @dev Sets the value of the string storage `$` to `s`.
    function setCalldata(StringStorage storage $, string calldata s) internal {
        LibBytes.setCalldata(bytesStorage($), bytes(s));
    }

    /// @dev Sets the value of the string storage `$` to the empty string.
    function clear(StringStorage storage $) internal {
        delete $._spacer;
    }

    /// @dev Returns whether the value stored is `$` is the empty string "".
    function isEmpty(StringStorage storage $) internal view returns (bool) {
        return uint256($._spacer) & 0xff == uint256(0);
    }

    /// @dev Returns the length of the value stored in `$`.
    function length(StringStorage storage $) internal view returns (uint256) {
        return LibBytes.length(bytesStorage($));
    }

    /// @dev Returns the value stored in `$`.
    function get(StringStorage storage $) internal view returns (string memory) {
        return string(LibBytes.get(bytesStorage($)));
    }

    /// @dev Helper to cast `$` to a `BytesStorage`.
    function bytesStorage(StringStorage storage $)
        internal
        pure
        returns (LibBytes.BytesStorage storage casted)
    {
        /// @solidity memory-safe-assembly
        assembly {
            casted.slot := $.slot
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     DECIMAL OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the base 10 decimal representation of `value`.
    function toString(uint256 value) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit), but
            // we allocate 0xa0 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 word for the trailing zeros padding, 1 word for the length,
            // and 3 words for a maximum of 78 digits.
            result := add(mload(0x40), 0x80)
            mstore(0x40, add(result, 0x20)) // Allocate memory.
            mstore(result, 0) // Zeroize the slot after the string.

            let end := result // Cache the end of the memory to calculate the length later.
            let w := not(0) // Tsk.
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for { let temp := value } 1 {} {
                result := add(result, w) // `sub(result, 1)`.
                // Store the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(result, add(48, mod(temp, 10)))
                temp := div(temp, 10) // Keep dividing `temp` until zero.
                if iszero(temp) { break }
            }
            let n := sub(end, result)
            result := sub(result, 0x20) // Move the pointer 32 bytes back to make room for the length.
            mstore(result, n) // Store the length.
        }
    }

    /// @dev Returns the base 10 decimal representation of `value`.
    function toString(int256 value) internal pure returns (string memory result) {
        if (value >= 0) return toString(uint256(value));
        unchecked {
            result = toString(~uint256(value) + 1);
        }
        /// @solidity memory-safe-assembly
        assembly {
            // We still have some spare memory space on the left,
            // as we have allocated 3 words (96 bytes) for up to 78 digits.
            let n := mload(result) // Load the string length.
            mstore(result, 0x2d) // Store the '-' character.
            result := sub(result, 1) // Move back the string pointer by a byte.
            mstore(result, add(n, 1)) // Update the string length.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   HEXADECIMAL OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the hexadecimal representation of `value`,
    /// left-padded to an input length of `byteCount` bytes.
    /// The output is prefixed with "0x" encoded using 2 hexadecimal digits per byte,
    /// giving a total length of `byteCount * 2 + 2` bytes.
    /// Reverts if `byteCount` is too small for the output to contain all the digits.
    function toHexString(uint256 value, uint256 byteCount)
        internal
        pure
        returns (string memory result)
    {
        result = toHexStringNoPrefix(value, byteCount);
        /// @solidity memory-safe-assembly
        assembly {
            let n := add(mload(result), 2) // Compute the length.
            mstore(result, 0x3078) // Store the "0x" prefix.
            result := sub(result, 2) // Move the pointer.
            mstore(result, n) // Store the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`,
    /// left-padded to an input length of `byteCount` bytes.
    /// The output is not prefixed with "0x" and is encoded using 2 hexadecimal digits per byte,
    /// giving a total length of `byteCount * 2` bytes.
    /// Reverts if `byteCount` is too small for the output to contain all the digits.
    function toHexStringNoPrefix(uint256 value, uint256 byteCount)
        internal
        pure
        returns (string memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // We need 0x20 bytes for the trailing zeros padding, `byteCount * 2` bytes
            // for the digits, 0x02 bytes for the prefix, and 0x20 bytes for the length.
            // We add 0x20 to the total and round down to a multiple of 0x20.
            // (0x20 + 0x20 + 0x02 + 0x20) = 0x62.
            result := add(mload(0x40), and(add(shl(1, byteCount), 0x42), not(0x1f)))
            mstore(0x40, add(result, 0x20)) // Allocate memory.
            mstore(result, 0) // Zeroize the slot after the string.

            let end := result // Cache the end to calculate the length later.
            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            let start := sub(result, add(byteCount, byteCount))
            let w := not(1) // Tsk.
            let temp := value
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for {} 1 {} {
                result := add(result, w) // `sub(result, 2)`.
                mstore8(add(result, 1), mload(and(temp, 15)))
                mstore8(result, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                if iszero(xor(result, start)) { break }
            }
            if temp {
                mstore(0x00, 0x2194895a) // `HexLengthInsufficient()`.
                revert(0x1c, 0x04)
            }
            let n := sub(end, result)
            result := sub(result, 0x20)
            mstore(result, n) // Store the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x" and encoded using 2 hexadecimal digits per byte.
    /// As address are 20 bytes long, the output will left-padded to have
    /// a length of `20 * 2 + 2` bytes.
    function toHexString(uint256 value) internal pure returns (string memory result) {
        result = toHexStringNoPrefix(value);
        /// @solidity memory-safe-assembly
        assembly {
            let n := add(mload(result), 2) // Compute the length.
            mstore(result, 0x3078) // Store the "0x" prefix.
            result := sub(result, 2) // Move the pointer.
            mstore(result, n) // Store the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x".
    /// The output excludes leading "0" from the `toHexString` output.
    /// `0x00: "0x0", 0x01: "0x1", 0x12: "0x12", 0x123: "0x123"`.
    function toMinimalHexString(uint256 value) internal pure returns (string memory result) {
        result = toHexStringNoPrefix(value);
        /// @solidity memory-safe-assembly
        assembly {
            let o := eq(byte(0, mload(add(result, 0x20))), 0x30) // Whether leading zero is present.
            let n := add(mload(result), 2) // Compute the length.
            mstore(add(result, o), 0x3078) // Store the "0x" prefix, accounting for leading zero.
            result := sub(add(result, o), 2) // Move the pointer, accounting for leading zero.
            mstore(result, sub(n, o)) // Store the length, accounting for leading zero.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output excludes leading "0" from the `toHexStringNoPrefix` output.
    /// `0x00: "0", 0x01: "1", 0x12: "12", 0x123: "123"`.
    function toMinimalHexStringNoPrefix(uint256 value)
        internal
        pure
        returns (string memory result)
    {
        result = toHexStringNoPrefix(value);
        /// @solidity memory-safe-assembly
        assembly {
            let o := eq(byte(0, mload(add(result, 0x20))), 0x30) // Whether leading zero is present.
            let n := mload(result) // Get the length.
            result := add(result, o) // Move the pointer, accounting for leading zero.
            mstore(result, sub(n, o)) // Store the length, accounting for leading zero.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is encoded using 2 hexadecimal digits per byte.
    /// As address are 20 bytes long, the output will left-padded to have
    /// a length of `20 * 2` bytes.
    function toHexStringNoPrefix(uint256 value) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            // We need 0x20 bytes for the trailing zeros padding, 0x20 bytes for the length,
            // 0x02 bytes for the prefix, and 0x40 bytes for the digits.
            // The next multiple of 0x20 above (0x20 + 0x20 + 0x02 + 0x40) is 0xa0.
            result := add(mload(0x40), 0x80)
            mstore(0x40, add(result, 0x20)) // Allocate memory.
            mstore(result, 0) // Zeroize the slot after the string.

            let end := result // Cache the end to calculate the length later.
            mstore(0x0f, 0x30313233343536373839616263646566) // Store the "0123456789abcdef" lookup.

            let w := not(1) // Tsk.
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for { let temp := value } 1 {} {
                result := add(result, w) // `sub(result, 2)`.
                mstore8(add(result, 1), mload(and(temp, 15)))
                mstore8(result, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                if iszero(temp) { break }
            }
            let n := sub(end, result)
            result := sub(result, 0x20)
            mstore(result, n) // Store the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x", encoded using 2 hexadecimal digits per byte,
    /// and the alphabets are capitalized conditionally according to
    /// https://eips.ethereum.org/EIPS/eip-55
    function toHexStringChecksummed(address value) internal pure returns (string memory result) {
        result = toHexString(value);
        /// @solidity memory-safe-assembly
        assembly {
            let mask := shl(6, div(not(0), 255)) // `0b010000000100000000 ...`
            let o := add(result, 0x22)
            let hashed := and(keccak256(o, 40), mul(34, mask)) // `0b10001000 ... `
            let t := shl(240, 136) // `0b10001000 << 240`
            for { let i := 0 } 1 {} {
                mstore(add(i, i), mul(t, byte(i, hashed)))
                i := add(i, 1)
                if eq(i, 20) { break }
            }
            mstore(o, xor(mload(o), shr(1, and(mload(0x00), and(mload(o), mask)))))
            o := add(o, 0x20)
            mstore(o, xor(mload(o), shr(1, and(mload(0x20), and(mload(o), mask)))))
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x" and encoded using 2 hexadecimal digits per byte.
    function toHexString(address value) internal pure returns (string memory result) {
        result = toHexStringNoPrefix(value);
        /// @solidity memory-safe-assembly
        assembly {
            let n := add(mload(result), 2) // Compute the length.
            mstore(result, 0x3078) // Store the "0x" prefix.
            result := sub(result, 2) // Move the pointer.
            mstore(result, n) // Store the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is encoded using 2 hexadecimal digits per byte.
    function toHexStringNoPrefix(address value) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            // Allocate memory.
            // We need 0x20 bytes for the trailing zeros padding, 0x20 bytes for the length,
            // 0x02 bytes for the prefix, and 0x28 bytes for the digits.
            // The next multiple of 0x20 above (0x20 + 0x20 + 0x02 + 0x28) is 0x80.
            mstore(0x40, add(result, 0x80))
            mstore(0x0f, 0x30313233343536373839616263646566) // Store the "0123456789abcdef" lookup.

            result := add(result, 2)
            mstore(result, 40) // Store the length.
            let o := add(result, 0x20)
            mstore(add(o, 40), 0) // Zeroize the slot after the string.
            value := shl(96, value)
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for { let i := 0 } 1 {} {
                let p := add(o, add(i, i))
                let temp := byte(i, value)
                mstore8(add(p, 1), mload(and(temp, 15)))
                mstore8(p, mload(shr(4, temp)))
                i := add(i, 1)
                if eq(i, 20) { break }
            }
        }
    }

    /// @dev Returns the hex encoded string from the raw bytes.
    /// The output is encoded using 2 hexadecimal digits per byte.
    function toHexString(bytes memory raw) internal pure returns (string memory result) {
        result = toHexStringNoPrefix(raw);
        /// @solidity memory-safe-assembly
        assembly {
            let n := add(mload(result), 2) // Compute the length.
            mstore(result, 0x3078) // Store the "0x" prefix.
            result := sub(result, 2) // Move the pointer.
            mstore(result, n) // Store the length.
        }
    }

    /// @dev Returns the hex encoded string from the raw bytes.
    /// The output is encoded using 2 hexadecimal digits per byte.
    function toHexStringNoPrefix(bytes memory raw) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(raw)
            result := add(mload(0x40), 2) // Skip 2 bytes for the optional prefix.
            mstore(result, add(n, n)) // Store the length of the output.

            mstore(0x0f, 0x30313233343536373839616263646566) // Store the "0123456789abcdef" lookup.
            let o := add(result, 0x20)
            let end := add(raw, n)
            for {} iszero(eq(raw, end)) {} {
                raw := add(raw, 1)
                mstore8(add(o, 1), mload(and(mload(raw), 15)))
                mstore8(o, mload(and(shr(4, mload(raw)), 15)))
                o := add(o, 2)
            }
            mstore(o, 0) // Zeroize the slot after the string.
            mstore(0x40, add(o, 0x20)) // Allocate memory.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   RUNE STRING OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the number of UTF characters in the string.
    function runeCount(string memory s) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            if mload(s) {
                mstore(0x00, div(not(0), 255))
                mstore(0x20, 0x0202020202020202020202020202020202020202020202020303030304040506)
                let o := add(s, 0x20)
                let end := add(o, mload(s))
                for { result := 1 } 1 { result := add(result, 1) } {
                    o := add(o, byte(0, mload(shr(250, mload(o)))))
                    if iszero(lt(o, end)) { break }
                }
            }
        }
    }

    /// @dev Returns if this string is a 7-bit ASCII string.
    /// (i.e. all characters codes are in [0..127])
    function is7BitASCII(string memory s) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := 1
            let mask := shl(7, div(not(0), 255))
            let n := mload(s)
            if n {
                let o := add(s, 0x20)
                let end := add(o, n)
                let last := mload(end)
                mstore(end, 0)
                for {} 1 {} {
                    if and(mask, mload(o)) {
                        result := 0
                        break
                    }
                    o := add(o, 0x20)
                    if iszero(lt(o, end)) { break }
                }
                mstore(end, last)
            }
        }
    }

    /// @dev Returns if this string is a 7-bit ASCII string,
    /// AND all characters are in the `allowed` lookup.
    /// Note: If `s` is empty, returns true regardless of `allowed`.
    function is7BitASCII(string memory s, uint128 allowed) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := 1
            if mload(s) {
                let allowed_ := shr(128, shl(128, allowed))
                let o := add(s, 0x20)
                for { let end := add(o, mload(s)) } 1 {} {
                    result := and(result, shr(byte(0, mload(o)), allowed_))
                    o := add(o, 1)
                    if iszero(and(result, lt(o, end))) { break }
                }
            }
        }
    }

    /// @dev Converts the bytes in the 7-bit ASCII string `s` to
    /// an allowed lookup for use in `is7BitASCII(s, allowed)`.
    /// To save runtime gas, you can cache the result in an immutable variable.
    function to7BitASCIIAllowedLookup(string memory s) internal pure returns (uint128 result) {
        /// @solidity memory-safe-assembly
        assembly {
            if mload(s) {
                let o := add(s, 0x20)
                for { let end := add(o, mload(s)) } 1 {} {
                    result := or(result, shl(byte(0, mload(o)), 1))
                    o := add(o, 1)
                    if iszero(lt(o, end)) { break }
                }
                if shr(128, result) {
                    mstore(0x00, 0xc9807e0d) // `StringNot7BitASCII()`.
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   BYTE STRING OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // For performance and bytecode compactness, byte string operations are restricted
    // to 7-bit ASCII strings. All offsets are byte offsets, not UTF character offsets.
    // Usage of byte string operations on charsets with runes spanning two or more bytes
    // can lead to undefined behavior.

    /// @dev Returns `subject` all occurrences of `needle` replaced with `replacement`.
    function replace(string memory subject, string memory needle, string memory replacement)
        internal
        pure
        returns (string memory)
    {
        return string(LibBytes.replace(bytes(subject), bytes(needle), bytes(replacement)));
    }

    /// @dev Returns the byte index of the first location of `needle` in `subject`,
    /// needleing from left to right, starting from `from`.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `needle` is not found.
    function indexOf(string memory subject, string memory needle, uint256 from)
        internal
        pure
        returns (uint256)
    {
        return LibBytes.indexOf(bytes(subject), bytes(needle), from);
    }

    /// @dev Returns the byte index of the first location of `needle` in `subject`,
    /// needleing from left to right.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `needle` is not found.
    function indexOf(string memory subject, string memory needle) internal pure returns (uint256) {
        return LibBytes.indexOf(bytes(subject), bytes(needle), 0);
    }

    /// @dev Returns the byte index of the first location of `needle` in `subject`,
    /// needleing from right to left, starting from `from`.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `needle` is not found.
    function lastIndexOf(string memory subject, string memory needle, uint256 from)
        internal
        pure
        returns (uint256)
    {
        return LibBytes.lastIndexOf(bytes(subject), bytes(needle), from);
    }

    /// @dev Returns the byte index of the first location of `needle` in `subject`,
    /// needleing from right to left.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `needle` is not found.
    function lastIndexOf(string memory subject, string memory needle)
        internal
        pure
        returns (uint256)
    {
        return LibBytes.lastIndexOf(bytes(subject), bytes(needle), type(uint256).max);
    }

    /// @dev Returns true if `needle` is found in `subject`, false otherwise.
    function contains(string memory subject, string memory needle) internal pure returns (bool) {
        return LibBytes.contains(bytes(subject), bytes(needle));
    }

    /// @dev Returns whether `subject` starts with `needle`.
    function startsWith(string memory subject, string memory needle) internal pure returns (bool) {
        return LibBytes.startsWith(bytes(subject), bytes(needle));
    }

    /// @dev Returns whether `subject` ends with `needle`.
    function endsWith(string memory subject, string memory needle) internal pure returns (bool) {
        return LibBytes.endsWith(bytes(subject), bytes(needle));
    }

    /// @dev Returns `subject` repeated `times`.
    function repeat(string memory subject, uint256 times) internal pure returns (string memory) {
        return string(LibBytes.repeat(bytes(subject), times));
    }

    /// @dev Returns a copy of `subject` sliced from `start` to `end` (exclusive).
    /// `start` and `end` are byte offsets.
    function slice(string memory subject, uint256 start, uint256 end)
        internal
        pure
        returns (string memory)
    {
        return string(LibBytes.slice(bytes(subject), start, end));
    }

    /// @dev Returns a copy of `subject` sliced from `start` to the end of the string.
    /// `start` is a byte offset.
    function slice(string memory subject, uint256 start) internal pure returns (string memory) {
        return string(LibBytes.slice(bytes(subject), start, type(uint256).max));
    }

    /// @dev Returns all the indices of `needle` in `subject`.
    /// The indices are byte offsets.
    function indicesOf(string memory subject, string memory needle)
        internal
        pure
        returns (uint256[] memory)
    {
        return LibBytes.indicesOf(bytes(subject), bytes(needle));
    }

    /// @dev Returns a arrays of strings based on the `delimiter` inside of the `subject` string.
    function split(string memory subject, string memory delimiter)
        internal
        pure
        returns (string[] memory result)
    {
        bytes[] memory a = LibBytes.split(bytes(subject), bytes(delimiter));
        /// @solidity memory-safe-assembly
        assembly {
            result := a
        }
    }

    /// @dev Returns a concatenated string of `a` and `b`.
    /// Cheaper than `string.concat()` and does not de-align the free memory pointer.
    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(LibBytes.concat(bytes(a), bytes(b)));
    }

    /// @dev Returns a copy of the string in either lowercase or UPPERCASE.
    /// WARNING! This function is only compatible with 7-bit ASCII strings.
    function toCase(string memory subject, bool toUpper)
        internal
        pure
        returns (string memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(subject)
            if n {
                result := mload(0x40)
                let o := add(result, 0x20)
                let d := sub(subject, result)
                let flags := shl(add(70, shl(5, toUpper)), 0x3ffffff)
                for { let end := add(o, n) } 1 {} {
                    let b := byte(0, mload(add(d, o)))
                    mstore8(o, xor(and(shr(b, flags), 0x20), b))
                    o := add(o, 1)
                    if eq(o, end) { break }
                }
                mstore(result, n) // Store the length.
                mstore(o, 0) // Zeroize the slot after the string.
                mstore(0x40, add(o, 0x20)) // Allocate memory.
            }
        }
    }

    /// @dev Returns a string from a small bytes32 string.
    /// `s` must be null-terminated, or behavior will be undefined.
    function fromSmallString(bytes32 s) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let n := 0
            for {} byte(n, s) { n := add(n, 1) } {} // Scan for '\0'.
            mstore(result, n) // Store the length.
            let o := add(result, 0x20)
            mstore(o, s) // Store the bytes of the string.
            mstore(add(o, n), 0) // Zeroize the slot after the string.
            mstore(0x40, add(result, 0x40)) // Allocate memory.
        }
    }

    /// @dev Returns the small string, with all bytes after the first null byte zeroized.
    function normalizeSmallString(bytes32 s) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            for {} byte(result, s) { result := add(result, 1) } {} // Scan for '\0'.
            mstore(0x00, s)
            mstore(result, 0x00)
            result := mload(0x00)
        }
    }

    /// @dev Returns the string as a normalized null-terminated small string.
    function toSmallString(string memory s) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(s)
            if iszero(lt(result, 33)) {
                mstore(0x00, 0xec92f9a3) // `TooBigForSmallString()`.
                revert(0x1c, 0x04)
            }
            result := shl(shl(3, sub(32, result)), mload(add(s, result)))
        }
    }

    /// @dev Returns a lowercased copy of the string.
    /// WARNING! This function is only compatible with 7-bit ASCII strings.
    function lower(string memory subject) internal pure returns (string memory result) {
        result = toCase(subject, false);
    }

    /// @dev Returns an UPPERCASED copy of the string.
    /// WARNING! This function is only compatible with 7-bit ASCII strings.
    function upper(string memory subject) internal pure returns (string memory result) {
        result = toCase(subject, true);
    }

    /// @dev Escapes the string to be used within HTML tags.
    function escapeHTML(string memory s) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let end := add(s, mload(s))
            let o := add(result, 0x20)
            // Store the bytes of the packed offsets and strides into the scratch space.
            // `packed = (stride << 5) | offset`. Max offset is 20. Max stride is 6.
            mstore(0x1f, 0x900094)
            mstore(0x08, 0xc0000000a6ab)
            // Store "&quot;&amp;&#39;&lt;&gt;" into the scratch space.
            mstore(0x00, shl(64, 0x2671756f743b26616d703b262333393b266c743b2667743b))
            for {} iszero(eq(s, end)) {} {
                s := add(s, 1)
                let c := and(mload(s), 0xff)
                // Not in `["\"","'","&","<",">"]`.
                if iszero(and(shl(c, 1), 0x500000c400000000)) {
                    mstore8(o, c)
                    o := add(o, 1)
                    continue
                }
                let t := shr(248, mload(c))
                mstore(o, mload(and(t, 0x1f)))
                o := add(o, shr(5, t))
            }
            mstore(o, 0) // Zeroize the slot after the string.
            mstore(result, sub(o, add(result, 0x20))) // Store the length.
            mstore(0x40, add(o, 0x20)) // Allocate memory.
        }
    }

    /// @dev Escapes the string to be used within double-quotes in a JSON.
    /// If `addDoubleQuotes` is true, the result will be enclosed in double-quotes.
    function escapeJSON(string memory s, bool addDoubleQuotes)
        internal
        pure
        returns (string memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let o := add(result, 0x20)
            if addDoubleQuotes {
                mstore8(o, 34)
                o := add(1, o)
            }
            // Store "\\u0000" in scratch space.
            // Store "0123456789abcdef" in scratch space.
            // Also, store `{0x08:"b", 0x09:"t", 0x0a:"n", 0x0c:"f", 0x0d:"r"}`.
            // into the scratch space.
            mstore(0x15, 0x5c75303030303031323334353637383961626364656662746e006672)
            // Bitmask for detecting `["\"","\\"]`.
            let e := or(shl(0x22, 1), shl(0x5c, 1))
            for { let end := add(s, mload(s)) } iszero(eq(s, end)) {} {
                s := add(s, 1)
                let c := and(mload(s), 0xff)
                if iszero(lt(c, 0x20)) {
                    if iszero(and(shl(c, 1), e)) {
                        // Not in `["\"","\\"]`.
                        mstore8(o, c)
                        o := add(o, 1)
                        continue
                    }
                    mstore8(o, 0x5c) // "\\".
                    mstore8(add(o, 1), c)
                    o := add(o, 2)
                    continue
                }
                if iszero(and(shl(c, 1), 0x3700)) {
                    // Not in `["\b","\t","\n","\f","\d"]`.
                    mstore8(0x1d, mload(shr(4, c))) // Hex value.
                    mstore8(0x1e, mload(and(c, 15))) // Hex value.
                    mstore(o, mload(0x19)) // "\\u00XX".
                    o := add(o, 6)
                    continue
                }
                mstore8(o, 0x5c) // "\\".
                mstore8(add(o, 1), mload(add(c, 8)))
                o := add(o, 2)
            }
            if addDoubleQuotes {
                mstore8(o, 34)
                o := add(1, o)
            }
            mstore(o, 0) // Zeroize the slot after the string.
            mstore(result, sub(o, add(result, 0x20))) // Store the length.
            mstore(0x40, add(o, 0x20)) // Allocate memory.
        }
    }

    /// @dev Escapes the string to be used within double-quotes in a JSON.
    function escapeJSON(string memory s) internal pure returns (string memory result) {
        result = escapeJSON(s, false);
    }

    /// @dev Encodes `s` so that it can be safely used in a URI,
    /// just like `encodeURIComponent` in JavaScript.
    /// See: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/encodeURIComponent
    /// See: https://datatracker.ietf.org/doc/html/rfc2396
    /// See: https://datatracker.ietf.org/doc/html/rfc3986
    function encodeURIComponent(string memory s) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            // Store "0123456789ABCDEF" in scratch space.
            // Uppercased to be consistent with JavaScript's implementation.
            mstore(0x0f, 0x30313233343536373839414243444546)
            let o := add(result, 0x20)
            for { let end := add(s, mload(s)) } iszero(eq(s, end)) {} {
                s := add(s, 1)
                let c := and(mload(s), 0xff)
                // If not in `[0-9A-Z-a-z-_.!~*'()]`.
                if iszero(and(1, shr(c, 0x47fffffe87fffffe03ff678200000000))) {
                    mstore8(o, 0x25) // '%'.
                    mstore8(add(o, 1), mload(and(shr(4, c), 15)))
                    mstore8(add(o, 2), mload(and(c, 15)))
                    o := add(o, 3)
                    continue
                }
                mstore8(o, c)
                o := add(o, 1)
            }
            mstore(result, sub(o, add(result, 0x20))) // Store the length.
            mstore(o, 0) // Zeroize the slot after the string.
            mstore(0x40, add(o, 0x20)) // Allocate memory.
        }
    }

    /// @dev Returns whether `a` equals `b`.
    function eq(string memory a, string memory b) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := eq(keccak256(add(a, 0x20), mload(a)), keccak256(add(b, 0x20), mload(b)))
        }
    }

    /// @dev Returns whether `a` equals `b`, where `b` is a null-terminated small string.
    function eqs(string memory a, bytes32 b) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            // These should be evaluated on compile time, as far as possible.
            let m := not(shl(7, div(not(iszero(b)), 255))) // `0x7f7f ...`.
            let x := not(or(m, or(b, add(m, and(b, m)))))
            let r := shl(7, iszero(iszero(shr(128, x))))
            r := or(r, shl(6, iszero(iszero(shr(64, shr(r, x))))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            // forgefmt: disable-next-item
            result := gt(eq(mload(a), add(iszero(x), xor(31, shr(3, r)))),
                xor(shr(add(8, r), b), shr(add(8, r), mload(add(a, 0x20)))))
        }
    }

    /// @dev Returns 0 if `a == b`, -1 if `a < b`, +1 if `a > b`.
    /// If `a` == b[:a.length]`, and `a.length < b.length`, returns -1.
    function cmp(string memory a, string memory b) internal pure returns (int256) {
        return LibBytes.cmp(bytes(a), bytes(b));
    }

    /// @dev Packs a single string with its length into a single word.
    /// Returns `bytes32(0)` if the length is zero or greater than 31.
    function packOne(string memory a) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // We don't need to zero right pad the string,
            // since this is our own custom non-standard packing scheme.
            result :=
                mul(
                    // Load the length and the bytes.
                    mload(add(a, 0x1f)),
                    // `length != 0 && length < 32`. Abuses underflow.
                    // Assumes that the length is valid and within the block gas limit.
                    lt(sub(mload(a), 1), 0x1f)
                )
        }
    }

    /// @dev Unpacks a string packed using {packOne}.
    /// Returns the empty string if `packed` is `bytes32(0)`.
    /// If `packed` is not an output of {packOne}, the output behavior is undefined.
    function unpackOne(bytes32 packed) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40) // Grab the free memory pointer.
            mstore(0x40, add(result, 0x40)) // Allocate 2 words (1 for the length, 1 for the bytes).
            mstore(result, 0) // Zeroize the length slot.
            mstore(add(result, 0x1f), packed) // Store the length and bytes.
            mstore(add(add(result, 0x20), mload(result)), 0) // Right pad with zeroes.
        }
    }

    /// @dev Packs two strings with their lengths into a single word.
    /// Returns `bytes32(0)` if combined length is zero or greater than 30.
    function packTwo(string memory a, string memory b) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let aLen := mload(a)
            // We don't need to zero right pad the strings,
            // since this is our own custom non-standard packing scheme.
            result :=
                mul(
                    or( // Load the length and the bytes of `a` and `b`.
                    shl(shl(3, sub(0x1f, aLen)), mload(add(a, aLen))), mload(sub(add(b, 0x1e), aLen))),
                    // `totalLen != 0 && totalLen < 31`. Abuses underflow.
                    // Assumes that the lengths are valid and within the block gas limit.
                    lt(sub(add(aLen, mload(b)), 1), 0x1e)
                )
        }
    }

    /// @dev Unpacks strings packed using {packTwo}.
    /// Returns the empty strings if `packed` is `bytes32(0)`.
    /// If `packed` is not an output of {packTwo}, the output behavior is undefined.
    function unpackTwo(bytes32 packed)
        internal
        pure
        returns (string memory resultA, string memory resultB)
    {
        /// @solidity memory-safe-assembly
        assembly {
            resultA := mload(0x40) // Grab the free memory pointer.
            resultB := add(resultA, 0x40)
            // Allocate 2 words for each string (1 for the length, 1 for the byte). Total 4 words.
            mstore(0x40, add(resultB, 0x40))
            // Zeroize the length slots.
            mstore(resultA, 0)
            mstore(resultB, 0)
            // Store the lengths and bytes.
            mstore(add(resultA, 0x1f), packed)
            mstore(add(resultB, 0x1f), mload(add(add(resultA, 0x20), mload(resultA))))
            // Right pad with zeroes.
            mstore(add(add(resultA, 0x20), mload(resultA)), 0)
            mstore(add(add(resultB, 0x20), mload(resultB)), 0)
        }
    }

    /// @dev Directly returns `a` without copying.
    function directReturn(string memory a) internal pure {
        assembly {
            // Assumes that the string does not start from the scratch space.
            let retStart := sub(a, 0x20)
            let retUnpaddedSize := add(mload(a), 0x40)
            // Right pad with zeroes. Just in case the string is produced
            // by a method that doesn't zero right pad.
            mstore(add(retStart, retUnpaddedSize), 0)
            mstore(retStart, 0x20) // Store the return offset.
            // End the transaction, returning the string.
            return(retStart, and(not(0x1f), add(0x1f, retUnpaddedSize)))
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Gas optimized ECDSA wrapper.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/ECDSA.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/ECDSA.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/ECDSA.sol)
///
/// @dev Note:
/// - The recovery functions use the ecrecover precompile (0x1).
/// - As of Solady version 0.0.68, the `recover` variants will revert upon recovery failure.
///   This is for more safety by default.
///   Use the `tryRecover` variants if you need to get the zero address back
///   upon recovery failure instead.
/// - As of Solady version 0.0.134, all `bytes signature` variants accept both
///   regular 65-byte `(r, s, v)` and EIP-2098 `(r, vs)` short form signatures.
///   See: https://eips.ethereum.org/EIPS/eip-2098
///   This is for calldata efficiency on smart accounts prevalent on L2s.
///
/// WARNING! Do NOT directly use signatures as unique identifiers:
/// - The recovery operations do NOT check if a signature is non-malleable.
/// - Use a nonce in the digest to prevent replay attacks on the same contract.
/// - Use EIP-712 for the digest to prevent replay attacks across different chains and contracts.
///   EIP-712 also enables readable signing of typed data for better user safety.
/// - If you need a unique hash from a signature, please use the `canonicalHash` functions.
library ECDSA {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The order of the secp256k1 elliptic curve.
    uint256 internal constant N = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141;

    /// @dev `N/2 + 1`. Used for checking the malleability of the signature.
    uint256 private constant _HALF_N_PLUS_1 =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The signature is invalid.
    error InvalidSignature();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    RECOVERY OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Recovers the signer's address from a message digest `hash`, and the `signature`.
    function recover(bytes32 hash, bytes memory signature) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            for { let m := mload(0x40) } 1 {
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`.
                revert(0x1c, 0x04)
            } {
                switch mload(signature)
                case 64 {
                    let vs := mload(add(signature, 0x40))
                    mstore(0x20, add(shr(255, vs), 27)) // `v`.
                    mstore(0x60, shr(1, shl(1, vs))) // `s`.
                }
                case 65 {
                    mstore(0x20, byte(0, mload(add(signature, 0x60)))) // `v`.
                    mstore(0x60, mload(add(signature, 0x40))) // `s`.
                }
                default { continue }
                mstore(0x00, hash)
                mstore(0x40, mload(add(signature, 0x20))) // `r`.
                result := mload(staticcall(gas(), 1, 0x00, 0x80, 0x01, 0x20))
                mstore(0x60, 0) // Restore the zero slot.
                mstore(0x40, m) // Restore the free memory pointer.
                // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
                if returndatasize() { break }
            }
        }
    }

    /// @dev Recovers the signer's address from a message digest `hash`, and the `signature`.
    function recoverCalldata(bytes32 hash, bytes calldata signature)
        internal
        view
        returns (address result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            for { let m := mload(0x40) } 1 {
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`.
                revert(0x1c, 0x04)
            } {
                switch signature.length
                case 64 {
                    let vs := calldataload(add(signature.offset, 0x20))
                    mstore(0x20, add(shr(255, vs), 27)) // `v`.
                    mstore(0x40, calldataload(signature.offset)) // `r`.
                    mstore(0x60, shr(1, shl(1, vs))) // `s`.
                }
                case 65 {
                    mstore(0x20, byte(0, calldataload(add(signature.offset, 0x40)))) // `v`.
                    calldatacopy(0x40, signature.offset, 0x40) // Copy `r` and `s`.
                }
                default { continue }
                mstore(0x00, hash)
                result := mload(staticcall(gas(), 1, 0x00, 0x80, 0x01, 0x20))
                mstore(0x60, 0) // Restore the zero slot.
                mstore(0x40, m) // Restore the free memory pointer.
                // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
                if returndatasize() { break }
            }
        }
    }

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the EIP-2098 short form signature defined by `r` and `vs`.
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x00, hash)
            mstore(0x20, add(shr(255, vs), 27)) // `v`.
            mstore(0x40, r)
            mstore(0x60, shr(1, shl(1, vs))) // `s`.
            result := mload(staticcall(gas(), 1, 0x00, 0x80, 0x01, 0x20))
            // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
            if iszero(returndatasize()) {
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`.
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0) // Restore the zero slot.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the signature defined by `v`, `r`, `s`.
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (address result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x00, hash)
            mstore(0x20, and(v, 0xff))
            mstore(0x40, r)
            mstore(0x60, s)
            result := mload(staticcall(gas(), 1, 0x00, 0x80, 0x01, 0x20))
            // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
            if iszero(returndatasize()) {
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`.
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0) // Restore the zero slot.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   TRY-RECOVER OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // WARNING!
    // These functions will NOT revert upon recovery failure.
    // Instead, they will return the zero address upon recovery failure.
    // It is critical that the returned address is NEVER compared against
    // a zero address (e.g. an uninitialized address variable).

    /// @dev Recovers the signer's address from a message digest `hash`, and the `signature`.
    function tryRecover(bytes32 hash, bytes memory signature)
        internal
        view
        returns (address result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            for { let m := mload(0x40) } 1 {} {
                switch mload(signature)
                case 64 {
                    let vs := mload(add(signature, 0x40))
                    mstore(0x20, add(shr(255, vs), 27)) // `v`.
                    mstore(0x60, shr(1, shl(1, vs))) // `s`.
                }
                case 65 {
                    mstore(0x20, byte(0, mload(add(signature, 0x60)))) // `v`.
                    mstore(0x60, mload(add(signature, 0x40))) // `s`.
                }
                default { break }
                mstore(0x00, hash)
                mstore(0x40, mload(add(signature, 0x20))) // `r`.
                pop(staticcall(gas(), 1, 0x00, 0x80, 0x40, 0x20))
                mstore(0x60, 0) // Restore the zero slot.
                // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
                result := mload(xor(0x60, returndatasize()))
                mstore(0x40, m) // Restore the free memory pointer.
                break
            }
        }
    }

    /// @dev Recovers the signer's address from a message digest `hash`, and the `signature`.
    function tryRecoverCalldata(bytes32 hash, bytes calldata signature)
        internal
        view
        returns (address result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            for { let m := mload(0x40) } 1 {} {
                switch signature.length
                case 64 {
                    let vs := calldataload(add(signature.offset, 0x20))
                    mstore(0x20, add(shr(255, vs), 27)) // `v`.
                    mstore(0x40, calldataload(signature.offset)) // `r`.
                    mstore(0x60, shr(1, shl(1, vs))) // `s`.
                }
                case 65 {
                    mstore(0x20, byte(0, calldataload(add(signature.offset, 0x40)))) // `v`.
                    calldatacopy(0x40, signature.offset, 0x40) // Copy `r` and `s`.
                }
                default { break }
                mstore(0x00, hash)
                pop(staticcall(gas(), 1, 0x00, 0x80, 0x40, 0x20))
                mstore(0x60, 0) // Restore the zero slot.
                // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
                result := mload(xor(0x60, returndatasize()))
                mstore(0x40, m) // Restore the free memory pointer.
                break
            }
        }
    }

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the EIP-2098 short form signature defined by `r` and `vs`.
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs)
        internal
        view
        returns (address result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x00, hash)
            mstore(0x20, add(shr(255, vs), 27)) // `v`.
            mstore(0x40, r)
            mstore(0x60, shr(1, shl(1, vs))) // `s`.
            pop(staticcall(gas(), 1, 0x00, 0x80, 0x40, 0x20))
            mstore(0x60, 0) // Restore the zero slot.
            // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
            result := mload(xor(0x60, returndatasize()))
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Recovers the signer's address from a message digest `hash`,
    /// and the signature defined by `v`, `r`, `s`.
    function tryRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (address result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x00, hash)
            mstore(0x20, and(v, 0xff))
            mstore(0x40, r)
            mstore(0x60, s)
            pop(staticcall(gas(), 1, 0x00, 0x80, 0x40, 0x20))
            mstore(0x60, 0) // Restore the zero slot.
            // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
            result := mload(xor(0x60, returndatasize()))
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     HASHING OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns an Ethereum Signed Message, created from a `hash`.
    /// This produces a hash corresponding to the one signed with the
    /// [`eth_sign`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_sign)
    /// JSON-RPC method as part of EIP-191.
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, hash) // Store into scratch space for keccak256.
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32") // 28 bytes.
            result := keccak256(0x04, 0x3c) // `32 * 2 - (32 - 28) = 60 = 0x3c`.
        }
    }

    /// @dev Returns an Ethereum Signed Message, created from `s`.
    /// This produces a hash corresponding to the one signed with the
    /// [`eth_sign`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_sign)
    /// JSON-RPC method as part of EIP-191.
    /// Note: Supports lengths of `s` up to 999999 bytes.
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let sLength := mload(s)
            let o := 0x20
            mstore(o, "\x19Ethereum Signed Message:\n") // 26 bytes, zero-right-padded.
            mstore(0x00, 0x00)
            // Convert the `s.length` to ASCII decimal representation: `base10(s.length)`.
            for { let temp := sLength } 1 {} {
                o := sub(o, 1)
                mstore8(o, add(48, mod(temp, 10)))
                temp := div(temp, 10)
                if iszero(temp) { break }
            }
            let n := sub(0x3a, o) // Header length: `26 + 32 - o`.
            // Throw an out-of-offset error (consumes all gas) if the header exceeds 32 bytes.
            returndatacopy(returndatasize(), returndatasize(), gt(n, 0x20))
            mstore(s, or(mload(0x00), mload(n))) // Temporarily store the header.
            result := keccak256(add(s, sub(0x20, n)), add(n, sLength))
            mstore(s, sLength) // Restore the length.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  CANONICAL HASH FUNCTIONS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // The following functions returns the hash of the signature in it's canonicalized format,
    // which is the 65-byte `abi.encodePacked(r, s, uint8(v))`, where `v` is either 27 or 28.
    // If `s` is greater than `N / 2` then it will be converted to `N - s`
    // and the `v` value will be flipped.
    // If the signature has an invalid length, or if `v` is invalid,
    // a uniquely corrupt hash will be returned.
    // These functions are useful for "poor-mans-VRF".

    /// @dev Returns the canonical hash of `signature`.
    function canonicalHash(bytes memory signature) internal pure returns (bytes32 result) {
        // @solidity memory-safe-assembly
        assembly {
            let l := mload(signature)
            for {} 1 {} {
                mstore(0x00, mload(add(signature, 0x20))) // `r`.
                let s := mload(add(signature, 0x40))
                let v := mload(add(signature, 0x41))
                if eq(l, 64) {
                    v := add(shr(255, s), 27)
                    s := shr(1, shl(1, s))
                }
                if iszero(lt(s, _HALF_N_PLUS_1)) {
                    v := xor(v, 7)
                    s := sub(N, s)
                }
                mstore(0x21, v)
                mstore(0x20, s)
                result := keccak256(0x00, 0x41)
                mstore(0x21, 0) // Restore the overwritten part of the free memory pointer.
                break
            }

            // If the length is neither 64 nor 65, return a uniquely corrupted hash.
            if iszero(lt(sub(l, 64), 2)) {
                // `bytes4(keccak256("InvalidSignatureLength"))`.
                result := xor(keccak256(add(signature, 0x20), l), 0xd62f1ab2)
            }
        }
    }

    /// @dev Returns the canonical hash of `signature`.
    function canonicalHashCalldata(bytes calldata signature)
        internal
        pure
        returns (bytes32 result)
    {
        // @solidity memory-safe-assembly
        assembly {
            for {} 1 {} {
                mstore(0x00, calldataload(signature.offset)) // `r`.
                let s := calldataload(add(signature.offset, 0x20))
                let v := calldataload(add(signature.offset, 0x21))
                if eq(signature.length, 64) {
                    v := add(shr(255, s), 27)
                    s := shr(1, shl(1, s))
                }
                if iszero(lt(s, _HALF_N_PLUS_1)) {
                    v := xor(v, 7)
                    s := sub(N, s)
                }
                mstore(0x21, v)
                mstore(0x20, s)
                result := keccak256(0x00, 0x41)
                mstore(0x21, 0) // Restore the overwritten part of the free memory pointer.
                break
            }
            // If the length is neither 64 nor 65, return a uniquely corrupted hash.
            if iszero(lt(sub(signature.length, 64), 2)) {
                calldatacopy(mload(0x40), signature.offset, signature.length)
                // `bytes4(keccak256("InvalidSignatureLength"))`.
                result := xor(keccak256(mload(0x40), signature.length), 0xd62f1ab2)
            }
        }
    }

    /// @dev Returns the canonical hash of `signature`.
    function canonicalHash(bytes32 r, bytes32 vs) internal pure returns (bytes32 result) {
        // @solidity memory-safe-assembly
        assembly {
            mstore(0x00, r) // `r`.
            let v := add(shr(255, vs), 27)
            let s := shr(1, shl(1, vs))
            mstore(0x21, v)
            mstore(0x20, s)
            result := keccak256(0x00, 0x41)
            mstore(0x21, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /// @dev Returns the canonical hash of `signature`.
    function canonicalHash(uint8 v, bytes32 r, bytes32 s) internal pure returns (bytes32 result) {
        // @solidity memory-safe-assembly
        assembly {
            mstore(0x00, r) // `r`.
            if iszero(lt(s, _HALF_N_PLUS_1)) {
                v := xor(v, 7)
                s := sub(N, s)
            }
            mstore(0x21, v)
            mstore(0x20, s)
            result := keccak256(0x00, 0x41)
            mstore(0x21, 0) // Restore the overwritten part of the free memory pointer.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   EMPTY CALLDATA HELPERS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns an empty calldata bytes.
    function emptySignature() internal pure returns (bytes calldata signature) {
        /// @solidity memory-safe-assembly
        assembly {
            signature.length := 0
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

interface ISupplyHook {
    function onSupply(uint256 shares, uint256 principal, bytes calldata data) external;
}

interface IUniteHook {
    function onUnite(uint256 shares, uint256 principal, bytes calldata data) external;
}

interface IHook is ISupplyHook, IUniteHook {}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {SafeCastLib} from "solady/src/utils/SafeCastLib.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";

import {FeeParameters, FeePcts} from "../Types.sol";
import {FeePctsLib} from "../utils/FeePctsLib.sol";
import {Errors} from "../Errors.sol";
import {Factory} from "../Factory.sol";
import {BaseModule} from "./BaseModule.sol";

/// @notice FeeModule is responsible for managing fee settings
abstract contract FeeModule is BaseModule {
    function getFeePcts() external view virtual returns (FeePcts);
}

/// @notice ConstantFeeModule is an implementation of FeeModule where all fees except split ratio are set once at initialization
contract ConstantFeeModule is FeeModule {
    using SafeCastLib for uint256;

    bytes32 public constant override VERSION = "2.0.0";

    uint256 private constant MAX_FEE_BPS = 10_000;
    uint256 private constant MAX_SPLIT_RATIO_BPS = 9_500;

    FeePcts private s_feePcts;

    /// @notice Initialize the fee module with the given fee parameters
    /// @dev The fee parameters are encoded as follows: abi.encode(principalToken, abi.encode(FeePcts))
    function initialize() external override initializer {
        (, bytes memory args) = abi.decode(LibClone.argsOnClone(address(this)), (address, bytes));

        if (args.length != 0x20) revert Errors.FeeModule_InvalidFeeParam();
        FeePcts feePcts = abi.decode(args, (FeePcts));

        (uint16 splitFee, uint16 issuanceFee, uint16 performanceFee, uint16 redemptionFee, uint16 postSettlementFee) =
            FeePctsLib.unpack(feePcts);

        if (splitFee != Factory(msg.sender).DEFAULT_SPLIT_RATIO_BPS().toUint16()) {
            revert Errors.FeeModule_SplitFeeMismatchDefault();
        }
        if (issuanceFee > MAX_FEE_BPS) {
            revert Errors.FeeModule_IssuanceFeeExceedsMaximum();
        }
        if (performanceFee > MAX_FEE_BPS) {
            revert Errors.FeeModule_PerformanceFeeExceedsMaximum();
        }
        if (redemptionFee > MAX_FEE_BPS) {
            revert Errors.FeeModule_RedemptionFeeExceedsMaximum();
        }
        if (postSettlementFee > MAX_FEE_BPS) {
            revert Errors.FeeModule_PostSettlementFeeExceedsMaximum();
        }
        s_feePcts = feePcts;
    }

    /// @notice Get the fee parameters
    /// @return The fee parameters
    function getFeePcts() public view override returns (FeePcts) {
        return s_feePcts;
    }

    /// @notice Get the fee parameters
    /// @param param The fee parameters to get
    /// @return The fee parameters
    function getFeeParams(FeeParameters param) external view returns (uint256) {
        if (param == FeeParameters.FEE_SPLIT_RATIO) {
            return FeePctsLib.getSplitPctBps(s_feePcts);
        } else if (param == FeeParameters.ISSUANCE_FEE) {
            return FeePctsLib.getIssuanceFeePctBps(s_feePcts);
        } else if (param == FeeParameters.PERFORMANCE_FEE) {
            return FeePctsLib.getPerformanceFeePctBps(s_feePcts);
        } else if (param == FeeParameters.REDEMPTION_FEE) {
            return FeePctsLib.getRedemptionFeePctBps(s_feePcts);
        } else if (param == FeeParameters.POST_SETTLEMENT_FEE) {
            return FeePctsLib.getPostSettlementFeePctBps(s_feePcts);
        }
        revert Errors.FeeModule_InvalidFeeParam();
    }

    /// @notice Only FeeManager can update the fee split ratio
    /// @param _splitRatio The new fee split ratio
    /// @dev The split ratio is the percentage of the fee that is split between the principalToken and the issuer
    function updateFeeSplitRatio(uint256 _splitRatio) external restrictedBy(i_factory().i_accessManager()) {
        if (_splitRatio > MAX_SPLIT_RATIO_BPS) {
            revert Errors.FeeModule_SplitFeeExceedsMaximum();
        }
        if (_splitRatio == 0) {
            revert Errors.FeeModule_SplitFeeTooLow();
        }
        s_feePcts = FeePctsLib.updateSplitFeePct(s_feePcts, _splitRatio.toUint16());
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {TokenReward} from "src/Types.sol";

interface IRewardProxy {
    function rewardTokens() external view returns (address[] memory);
    function collectReward(address rewardProxy) external returns (TokenReward[] memory);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {LibClone} from "solady/src/utils/LibClone.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

import {VerificationStatus} from "../Types.sol";
import {BaseModule} from "./BaseModule.sol";
import {PrincipalToken} from "src/tokens/PrincipalToken.sol";

/// @notice VerifierModule is used to restrict access to certain functions based on account and deposit cap.
/// @dev Integrators can extend this module to implement custom verification logic.
abstract contract VerifierModule is BaseModule {
    bytes4 constant SUPPLY_SELECTOR = 0x674032b8;
    bytes4 constant SUPPLY_WITH_CALLBACK_SELECTOR = 0x5f04dfe2;
    bytes4 constant ISSUE_SELECTOR = 0xb696a6ad;
    bytes4 constant ISSUE_WITH_CALLBACK_SELECTOR = 0x6d4b055c;

    /// @dev MUST NOT revert.
    /// @dev Key points: to distinguish between verification failure and unexpected error, the function
    /// must return verification status to indicate whether the transaction is allowed or not.
    /// @dev The function MUST return VerificationStatus.Success if the transaction is allowed.
    function verify(bytes4 sig, address caller, uint256 shares, uint256 principal, address receiver)
        external
        view
        virtual
        returns (VerificationStatus code)
    {
        sig;
        principal;
        caller; // silence the warning

        // If the balance reaches the cap, revert
        if (
            (
                sig == SUPPLY_SELECTOR || sig == SUPPLY_WITH_CALLBACK_SELECTOR || sig == ISSUE_SELECTOR
                    || sig == ISSUE_WITH_CALLBACK_SELECTOR
            ) && shares > maxSupply(receiver)
        ) {
            return VerificationStatus.SupplyMoreThanMax;
        }
        return VerificationStatus.Success;
    }

    /// @notice Returns the global maximum amount of shares that can PT can have.
    /// @notice The cap includes the deposits from users, fees, unclaimed yield, etc.
    /// MUST return 2 ** 256 - 1 if there is no limit on the maximum amount that may be deposited.
    /// MUST NOT revert.
    function depositCap() public view virtual returns (uint256 maxShares) {
        maxShares = type(uint256).max;
    }

    /// @notice Similar to `ERC4626.maxDeposit`, returns the maximum amount of the underlying token that can be deposited for `to`.
    /// Note: It doesn't account for pause state or expiry.
    /// MUST return a limited value if receiver is subject to some deposit limit.
    /// MUST return 2 ** 256 - 1 if there is no limit on the maximum amount that may be deposited.
    /// MUST NOT revert.
    function maxSupply(address to) public view virtual returns (uint256 maxShares) {
        to; // silence the warning

        uint256 cap = depositCap();
        if (cap == type(uint256).max) return type(uint256).max;

        address pt = i_principalToken();
        uint256 balance = SafeTransferLib.balanceOf(PrincipalToken(pt).underlying(), pt);
        maxShares = FixedPointMathLib.zeroFloorSub(cap, balance); // max(0, cap - balance)
    }
}

/// @notice Simple implementation of VerifierModule with deposit cap defined by permissioned roles.
contract DepositCapVerifierModule is VerifierModule {
    bytes32 public constant override VERSION = "2.0.0";

    /// @notice Global deposit cap in unit of the underlying token.
    uint256 internal s_depositCap;

    function initialize() external override initializer {
        (, bytes memory args) = abi.decode(LibClone.argsOnClone(address(this)), (address, bytes));
        s_depositCap = abi.decode(args, (uint256));
    }

    function setDepositCap(uint256 cap) external restricted {
        s_depositCap = cap;
    }

    function depositCap() public view override returns (uint256 maxShares) {
        maxShares = s_depositCap;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {ERC20} from "solady/src/tokens/ERC20.sol";

import {PrincipalToken} from "./PrincipalToken.sol";
import {TokenNameLib} from "../utils/TokenNameLib.sol";
import {Errors} from "../Errors.sol";

contract YieldToken is ERC20 {
    PrincipalToken public immutable i_principalToken;

    constructor(address _pt) {
        i_principalToken = PrincipalToken(_pt);
    }

    function name() public view override returns (string memory) {
        address underlying = _underlying();
        uint256 expiry = _maturity();
        return TokenNameLib.yieldTokenName(underlying, expiry);
    }

    function symbol() public view override returns (string memory) {
        address underlying = _underlying();
        uint256 expiry = _maturity();
        return TokenNameLib.yieldTokenSymbol(underlying, expiry);
    }

    function decimals() public view override returns (uint8) {
        // Same as underlying token decimals
        return i_principalToken.decimals();
    }

    /// @dev No need to call back to PrincipalToken for updating accrued interest. PrincipalToken already does it at this point.
    function mint(address to, uint256 amount) external {
        if (msg.sender != address(i_principalToken)) revert Errors.YieldToken_OnlyPrincipalToken();
        _mint(to, amount);
    }

    /// @dev No need to call back to PrincipalToken for updating accrued interest. PrincipalToken already does it at this point.
    function burn(address from, uint256 amount) public {
        if (msg.sender != address(i_principalToken)) revert Errors.YieldToken_OnlyPrincipalToken();
        _burn(from, amount);
    }

    /// @dev YT holders accrue interest since the last update of `from` and `to` balances.
    /// Since the last update of `from` and `to` balances, the interest may be accrued by `from` and `to`.
    /// So, before updating the balances, we need to record the interest by calling `onYtTransfer`.
    function transfer(address to, uint256 amount) public override returns (bool) {
        i_principalToken.onYtTransfer(msg.sender, to, balanceOf(msg.sender), balanceOf(to));
        return super.transfer(to, amount);
    }

    /// @dev See {YieldToken-transfer}. The same logic is applied here.
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        i_principalToken.onYtTransfer(from, to, balanceOf(from), balanceOf(to));
        return super.transferFrom(from, to, amount);
    }

    function _underlying() internal view returns (address) {
        return i_principalToken.underlying();
    }

    function _maturity() internal view returns (uint256) {
        return i_principalToken.maturity();
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

// https://gist.github.com/Vectorized/ebb23b2b5395b6d6aa83fc36af98a18c

import {TokenReward} from "../Types.sol";

library LibRewardProxy {
    function delegateCallCollectReward(address rewardProxy) internal returns (TokenReward[] memory rewards) {
        assembly {
            mstore(0x14, rewardProxy) // Store the argument.
            mstore(0x00, 0x82c97b8d000000000000000000000000) // `collectReward(address)`.
            if iszero(delegatecall(gas(), rewardProxy, 0x10, 0x24, codesize(), 0x00)) {
                mstore(0x00, 0x3f12e961) // `PrincipalToken_CollectRewardFailed()`
                revert(0x1c, 0x04)
            }

            let m := mload(0x40) // Grab the free memory pointer.
            returndatacopy(m, 0x00, returndatasize()) // Just copy all of the return data.

            let t := add(m, mload(m)) // Pointer to `rewards` in the returndata.
            let n := mload(t) // `rewards.length`.
            let r := add(t, 0x20) // Pointer to `rewards[0]` in the returndata.

            // Skip the copied data.
            // We will initialize rewards as an array of pointers into the copied data.
            let a := add(m, returndatasize())
            if or(shr(64, mload(m)), or(lt(returndatasize(), 0x20), gt(add(r, shl(6, n)), a))) {
                revert(codesize(), 0x00)
            }

            if n {
                mstore(a, n) // Store the length of the array.
                let o := add(a, 0x20)
                mstore(0x40, add(o, shl(5, n))) // Allocate the memory.
                rewards := a
                for { let i := 0 } 1 {} {
                    let p := add(r, shl(6, i))
                    // Revert if the `rewards[i].token` has dirty upper bits.
                    if shr(160, mload(p)) { revert(codesize(), 0x00) }
                    mstore(add(o, shl(5, i)), p)
                    i := add(i, 1)
                    if eq(i, n) { break }
                }
            }
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {MetadataReaderLib} from "solady/src/utils/MetadataReaderLib.sol";
import {DateTimeLib} from "solady/src/utils/DateTimeLib.sol";
import {LibString} from "solady/src/utils/LibString.sol";

/// @dev Inputs `expiry` that exceed maximum timestamp results in undefined behavior.
library TokenNameLib {
    using LibString for uint256;

    string constant PY_NAME_PREFIX = "NapierV2-";

    function principalTokenName(address target, uint256 expiry) internal view returns (string memory) {
        string memory underlyingName = MetadataReaderLib.readName(target);
        return string.concat(PY_NAME_PREFIX, "PT-", underlyingName, "@", expiryToDate(expiry));
    }

    function principalTokenSymbol(address target, uint256 expiry) internal view returns (string memory) {
        string memory underlyingSymbol = MetadataReaderLib.readSymbol(target);
        return string.concat("PT-", underlyingSymbol, "@", expiryToDate(expiry));
    }

    function yieldTokenName(address target, uint256 expiry) internal view returns (string memory) {
        string memory underlyingName = MetadataReaderLib.readName(target);
        return string.concat(PY_NAME_PREFIX, "YT-", underlyingName, "@", expiryToDate(expiry));
    }

    function yieldTokenSymbol(address target, uint256 expiry) internal view returns (string memory) {
        string memory underlyingSymbol = MetadataReaderLib.readSymbol(target);
        return string.concat("YT-", underlyingSymbol, "@", expiryToDate(expiry));
    }

    function lpTokenName(address target, uint256 expiry) internal view returns (string memory) {
        string memory underlyingName = MetadataReaderLib.readName(target);
        return string.concat("NapierV2-PT/", underlyingName, "@", expiryToDate(expiry));
    }

    function lpTokenSymbol(address target, uint256 expiry) internal view returns (string memory) {
        string memory underlyingSymbol = MetadataReaderLib.readSymbol(target);
        return string.concat("NPR-PT/", underlyingSymbol, "@", expiryToDate(expiry));
    }

    function expiryToDate(uint256 expiry) internal pure returns (string memory) {
        (uint256 year, uint256 month, uint256 day) = DateTimeLib.timestampToDate(expiry);
        return string.concat(day.toString(), "/", month.toString(), "/", year.toString());
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/// @notice Forked from https://github.com/Uniswap/v4-core/blob/c8173143cf1e6f1c6c7b682a3563b263f149255f/src/libraries/CustomRevert.sol
/// @title Library for reverting with custom errors efficiently
/// @notice Contains functions for reverting with custom errors with different argument types efficiently
/// @dev To use this library, declare `using CustomRevert for bytes4;` and replace `revert CustomError()` with
/// `CustomError.selector.revertWith()`
/// @dev The functions may tamper with the free memory pointer but it is fine since the call context is exited immediately
library CustomRevert {
    /// @dev Reverts with the selector of a custom error in the scratch space
    function revertWith(bytes4 selector) internal pure {
        assembly ("memory-safe") {
            mstore(0, selector)
            revert(0, 0x04)
        }
    }

    function revertWith(bytes4 selector, uint256 value) internal pure {
        assembly ("memory-safe") {
            mstore(0, selector)
            mstore(0x04, value)
            revert(0, 0x24)
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {EIP5095} from "../interfaces/EIP5095.sol";

library LibExpiry {
    function isExpired(uint256 expiry) internal view returns (bool) {
        return block.timestamp >= expiry;
    }

    function isExpired(EIP5095 pt) internal view returns (bool) {
        return block.timestamp >= pt.maturity();
    }

    function isNotExpired(EIP5095 pt) internal view returns (bool) {
        return block.timestamp < pt.maturity();
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {FeePcts} from "../Types.sol";

library FeePctsLib {
    uint256 private constant FEE_MASK = 0xFFFF; // 16 bits mask
    uint256 private constant SPLIT_RATIO_OFFSET = 0;

    function getSplitPctBps(FeePcts self) internal pure returns (uint16) {
        return uint16(FeePcts.unwrap(self));
    }

    function getIssuanceFeePctBps(FeePcts self) internal pure returns (uint16) {
        return uint16(FeePcts.unwrap(self) >> 16);
    }

    function getPerformanceFeePctBps(FeePcts self) internal pure returns (uint16) {
        return uint16(FeePcts.unwrap(self) >> 32);
    }

    function getRedemptionFeePctBps(FeePcts self) internal pure returns (uint16) {
        return uint16(FeePcts.unwrap(self) >> 48);
    }

    function getPostSettlementFeePctBps(FeePcts self) internal pure returns (uint16) {
        return uint16(FeePcts.unwrap(self) >> 64);
    }

    function unpack(FeePcts self)
        internal
        pure
        returns (
            uint16 splitFeePct,
            uint16 issuanceFeePct,
            uint16 performanceFeePct,
            uint16 redemptionFeePct,
            uint16 postSettlementFeePct
        )
    {
        uint256 raw = FeePcts.unwrap(self);

        splitFeePct = uint16(raw);
        issuanceFeePct = uint16(raw >> 16);
        performanceFeePct = uint16(raw >> 32);
        redemptionFeePct = uint16(raw >> 48);
        postSettlementFeePct = uint16(raw >> 64);

        return (splitFeePct, issuanceFeePct, performanceFeePct, redemptionFeePct, postSettlementFeePct);
    }

    function pack(
        uint16 splitFeePct,
        uint16 issuanceFeePct,
        uint16 performanceFeePct,
        uint16 redemptionFeePct,
        uint16 postSettlementFeePct
    ) internal pure returns (FeePcts) {
        return FeePcts.wrap(
            (uint256(postSettlementFeePct) << 64 | uint256(redemptionFeePct) << 48) | (uint256(performanceFeePct) << 32)
                | (uint256(issuanceFeePct) << 16) | uint256(splitFeePct)
        );
    }

    function updateSplitFeePct(FeePcts self, uint16 splitFeePct) internal pure returns (FeePcts) {
        return
            FeePcts.wrap((FeePcts.unwrap(self) & ~(FEE_MASK << SPLIT_RATIO_OFFSET)) | (uint256(splitFeePct) & FEE_MASK));
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solady/src/utils/SafeCastLib.sol";

type YieldIndex is uint128;

/// @param maxscale The last collected YBT share price in the underlying token.
/// @param globalIndex The accumulator of the accrued yield per YT.
struct Snapshot {
    uint128 maxscale;
    YieldIndex globalIndex;
}

struct Yield {
    YieldIndex userIndex;
    uint128 accrued;
}

using {unwrap} for YieldIndex global;
using {eq as ==, add as +, sub as -} for YieldIndex global;

function unwrap(YieldIndex x) pure returns (uint128 result) {
    result = YieldIndex.unwrap(x);
}

function wrap(uint128 x) pure returns (YieldIndex result) {
    result = YieldIndex.wrap(x);
}

function eq(YieldIndex lhs, YieldIndex rhs) pure returns (bool output) {
    assembly {
        let m := shr(128, not(0))
        output := eq(and(m, lhs), and(m, rhs))
    }
}

function add(YieldIndex lhs, YieldIndex rhs) pure returns (YieldIndex output) {
    output = wrap(lhs.unwrap() + rhs.unwrap());
}

function sub(YieldIndex lhs, YieldIndex rhs) pure returns (YieldIndex output) {
    output = wrap(lhs.unwrap() - rhs.unwrap());
}

/// @notice A library to help calculate yield for users.
/// @notice The yield is distributed proportionally to the user's YT balance.
/// @dev Conceptually, this algorithm is the same as the staking algorithm of Synthetix and MasterChef.
/// @dev Important security note: Any user may be griefed by a malicious user by updating the yield index frequently.
/// When small amount of yield is accrued and `ytSupply` is way larger than `totalAccrued`, those rewards may be lost.
/// Impact: The whole yield income for a user may be frozen.
/// @dev Note Yield-bearing token should have enough decimals and YT decimals should have no more than 18 decimals.
/// @dev Rebase token is not supported.
library YieldMathLib {
    using SafeCastLib for uint256;

    uint256 constant BASIS_POINTS = 10_000;

    /// @notice Compute the accrued yield
    /// @param prevMaxscale The last collected scale.
    /// @param newMaxscale The up-to-date scale at the time of computation. Non-zero value.
    /// @param supply The total PT supply backed by underlying tokens, which generates the yield.
    /// @param feePctBps The performance fee percentage to charge on the accrued yield.
    function computeTotalYield(uint256 prevMaxscale, uint256 newMaxscale, uint256 supply, uint256 feePctBps)
        internal
        pure
        returns (uint256 accrued, uint256 fee)
    {
        if (prevMaxscale == 0) return (0, 0);

        // Accrued yield depends on last collected newMaxscale and the current newMaxscale.
        uint256 totalAccrued = calcYield(prevMaxscale, newMaxscale, supply);

        // Performance fee is charged on the accrued yield.
        fee = FixedPointMathLib.mulDivUp(totalAccrued, feePctBps, BASIS_POINTS); // Round up against users.
        accrued = totalAccrued - fee;
    }

    /// @notice Update the yield index based on the `resolver`'s conversion rate before the expiry date.
    /// @dev This function doesn't check if the expiry date has passed or not.
    /// @dev Accrued yield is proportional to user's YT balance.
    /// @dev Every PT and YT supply change, the yield index must be updated to reflect the accrued yield since the last update.
    /// @dev `newIndex` is the cumulative accrued yield: Σ_i^N accruedYieldsPerYT_i = Σ_i (Δyields_i / ytSupply_i),
    /// where Δyields_i is the yield accrued by YTs during the i-th index update.
    /// Let N be the most recent update.
    ///
    /// During each update:
    ///   - The accrued yield by YTs is calculated as: Δyields_i = (1 / maxscale_{i-1} - 1 / maxscale_i) * ptSupply_i.
    ///
    /// A user's claimable yield is calculated using:
    /// ```
    /// (Σ_i^N accruedYieldsPerYT_i - Σ_i^{k} accruedYieldsPerYT_i) * user_ytBalance
    /// ```
    /// where `k` is the k-th update where the user's YT balance was changed.
    /// [k, k+1] defines the period where the user's balance is constant.
    /// Whenever a user's YT balance changes, their accrued yield is updated.
    ///
    /// ### Example:
    /// **Initial State:**
    /// - Alice issues 10 PTs/YTs for 10 shares (scale = 1).
    /// - Bob issues 10 PTs/YTs for 10 shares (scale = 1).
    /// - Initial index = 1.
    ///
    /// **Second Update:**
    /// - Scale increases to 2.
    /// - No change in index; yield generated is (1/1 - 1/2) * 20 = 10
    ///
    /// **Third Update:**
    /// - Alice claims her yield.
    /// - Scale increases to 4.
    /// - New index = 1 + (1/1 - 1/4) * 20 / 20 = 1 + 0.75 = 1.75
    /// - Alice claims 10 * (newIndex - prevUserIndex) = 10 * (1.75 - 1) = 7.5
    /// - Alice’s `userIndex` updates to 1.75
    /// - **Verification:** Alice's yield = 10 * (1/1 - 1/4) = 7.5
    ///
    /// **Fourth Update:**
    /// - Alice claims yield again.
    /// - Scale increases to 8.
    /// - New index = 1.75 + (1/4 - 1/8) * 20 / 20 = 1.75 + 0.125 = 1.875
    /// - Alice claims 10 * (1.875 - 1.75) = 1.25
    /// - Bob can accrue 10 * (1.875 - 1) = 8.75
    /// - **Verification:**
    ///   - Alice's yield = 10 * (1/4 - 1/8) = 1.25
    ///   - Bob's yield = 10 * (1/1 - 1/8) = 8.75
    ///
    /// **Fifth Update:**
    /// - Bob redeems 10 PT after expiry.
    /// - Scale increases to 10
    /// - New index = 1.875 + (1/8 - 1/10) * 20 / 20 = 1.875 + 0.025 = 1.9
    /// - Total accrued yield: (1/8 - 1/10) * 20 = 0.5
    /// - Alice and Bob can accrue 0.25 each.
    ///
    /// **Sixth Update:**
    /// - Alice and Bob claim yield (PT supply = 10, YT supply = 20).
    /// - Scale increases to 16.
    /// - New index = 1.9 + (1/10 - 1/16) * 10 / 20 = 1.9 + 0.01875 = 1.91875
    /// - Alice claims 10 * (1.91875 - 1.875) = 0.4375
    /// - Bob claims 10 * (1.91875 - 1) = 9.1875
    /// - **Verification:**
    ///   - Total yield since last step: (1/10 - 1/16) * 10 = 0.375
    ///   - Alice’s claim = 0.25 + (10/20) * 0.375 = 0.4375
    ///   - Bob’s claim = 8.75 + 0.25 + (10/20) * 0.375 = 9.1875
    /// @param scaleFn The function to fetch the up-to-date yield index. Must not return 0.
    /// @param ptSupply The total PT supply backed by underlying tokens, which generates the yield.
    /// @param ytSupply The total YT supply used as a denominator to distribute the generated yield.
    /// @param feePctBps The performance fee percentage to charge on the accrued yield in basis points.
    function updateIndex(
        Snapshot memory self,
        function () external view returns(uint256) scaleFn,
        uint256 ptSupply,
        uint256 ytSupply,
        uint256 feePctBps
    ) internal view returns (uint256 totalAccrued, uint256 fee) {
        // Cache the last maxscale and up-to-date maxscale.
        uint256 prevMaxscale = self.maxscale;
        uint256 newMaxscale = FixedPointMathLib.max(scaleFn(), prevMaxscale);

        (totalAccrued, fee) = computeTotalYield(prevMaxscale, newMaxscale, ptSupply, feePctBps);

        /// WRITE MEMORY
        self.maxscale = newMaxscale.toUint128();
        //                       N
        //                     _____
        //                     ╲
        //                      ╲    accrued
        //                       ╲          i
        // globalYieldIndex =    ╱   ─────────
        //                      ╱    ytSupply
        //                     ╱             i
        //                     ‾‾‾‾‾
        //                     i = 0
        // If supply is 0 but there is accrued yield, `totalAccrued - fee` is lost because index doesn't change.
        if (ytSupply == 0) return (totalAccrued, fee);
        self.globalIndex =
            self.globalIndex + YieldIndex.wrap(FixedPointMathLib.divWad(totalAccrued, ytSupply).toUint128());
    }

    /// @notice Update the accrued yield for a user `account` since the last time when `account` accrued yield based on the `account`'s YT balance `ytBalance`.
    /// @dev This function must be called every time the `account`'s YT balance changes.
    /// @param index The up-to-date yield index.
    /// @param account The account to update the yield for.
    /// @param ytBalance The `account`'s YT balance.
    function accrueUserYield(
        mapping(address => Yield) storage self,
        YieldIndex index, // yieldIndex(t_2)
        address account, // u
        uint256 ytBalance // ytBalance_u
    ) internal returns (uint256 accrued) {
        accrued = computeAccrueUserYield(self, index, account, ytBalance);

        self[account].accrued += accrued.toUint128();
        self[account].userIndex = index;
    }

    /// @notice Preview the accrued yield for a user `account` since the last time when `account` accrued yield based on the `account`'s YT balance `ytBalance`.
    function computeAccrueUserYield(
        mapping(address => Yield) storage self,
        YieldIndex index,
        address account,
        uint256 ytBalance
    ) internal view returns (uint256 accrued) {
        // dInterest  ⎛t ⎞     = dInterest  ⎛t ⎞  + ytBalance  ⋅ ⎛yieldIndex ⎛t ⎞ - yieldIndex ⎛t ⎞⎞
        //          u ⎝ 2⎠                u ⎝ 1⎠             u   ⎝           ⎝ 2⎠              ⎝ 1⎠⎠
        YieldIndex prevIndex = self[account].userIndex;
        accrued = FixedPointMathLib.mulWad(ytBalance, YieldIndex.unwrap(index - prevIndex));
    }

    /// @notice Compute the accrued yield based on maxscales.
    /// @dev Scales must be non-zero.
    function calcYield(uint256 prevMaxscale, uint256 maxscale, uint256 balance) internal pure returns (uint256) {
        if (prevMaxscale >= maxscale) return 0;
        if (prevMaxscale == 0) return 0;
        //                            ⎛   1        1  ⎞
        // dInterest = balance ⎛t ⎞ ⋅ ⎜────── - ──────⎟
        //                     ⎝ 1⎠   ⎜S ⎛t ⎞   S ⎛t ⎞⎟
        //                            ⎝  ⎝ 1⎠     ⎝ 2⎠⎠
        return ((balance * (maxscale - prevMaxscale)) * 1e18) / (prevMaxscale * maxscale);
    }

    /// @notice Convert YBT shares to principal.
    function convertToPrincipal(uint256 shares, uint256 maxscale, bool roundUp) internal pure returns (uint256) {
        // principal = shares * maxscale / 1e18
        return FixedPointMathLib.ternary(
            roundUp, FixedPointMathLib.mulWadUp(shares, maxscale), FixedPointMathLib.mulWad(shares, maxscale)
        );
    }

    /// @notice Convert principal to YBT shares.
    function convertToUnderlying(uint256 principal, uint256 maxscale, bool roundUp) internal pure returns (uint256) {
        // shares = principal * 1e18 / maxscale
        return FixedPointMathLib.ternary(
            roundUp, FixedPointMathLib.divWadUp(principal, maxscale), FixedPointMathLib.divWad(principal, maxscale)
        );
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solady/src/utils/SafeCastLib.sol";

type RewardIndex is uint128;

/// @notice A struct to store the reward information for a user.
/// @param userIndex The reward index when the user last accrued reward.
/// @param accrued The accrued reward since the last time the user accrued reward.
struct Reward {
    RewardIndex userIndex; // rewardIndex_u(t_1): the reward index when the user last accrued reward
    uint128 accrued; // r_u(t_1): the accrued reward since the last time the user accrued reward
}

using {unwrap} for RewardIndex global;
using {eq as ==, add as +, sub as -} for RewardIndex global;

function unwrap(RewardIndex x) pure returns (uint128 result) {
    result = RewardIndex.unwrap(x);
}

function wrap(uint128 x) pure returns (RewardIndex result) {
    result = RewardIndex.wrap(x);
}

function eq(RewardIndex lhs, RewardIndex rhs) pure returns (bool output) {
    assembly {
        let m := shr(128, not(0))
        output := eq(and(m, lhs), and(m, rhs))
    }
}

function add(RewardIndex lhs, RewardIndex rhs) pure returns (RewardIndex output) {
    output = wrap(lhs.unwrap() + rhs.unwrap());
}

function sub(RewardIndex lhs, RewardIndex rhs) pure returns (RewardIndex output) {
    output = wrap(lhs.unwrap() - rhs.unwrap());
}

/// @notice A library to help calculate reward for users.
/// @notice The reward is distributed proportionally to the user's YT balance.
/// @dev Conceptually, this algorithm is the same as the staking algorithm of Synthetix and MasterChef.
/// @dev Important security note: Any user may be griefed by a malicious user by updating the reward index frequently.
/// When small amount of reward is accrued and ytSupply is way larger than totalAccrued, those rewards may be lost.
/// Impact: The whole reward income for a user may be frozen.
/// @dev When YT supply is 0 but some reward is accrued, the reward will be lost.
/// @dev Note Reward token should have enough decimals and YT decimals should have no more than 18 decimals.
/// @dev Rebase token and fee-on-transfer token are not supported.
library RewardMathLib {
    using SafeCastLib for uint256;

    /// @notice Update the reward index for newly accrued reward.
    /// @dev Assumption: If ytSupply is 0, totalAccrued is also 0. When ytSupply is 0 but totalAccrued is non-zero, the reward will be lost.
    /// @param index The last index to update from. rewardIndex(t_1)
    /// @param ytSupply The total YT supply. totalSupply(t_2)
    /// @param totalAccrued The total accrued reward since the last update. d(t_2)
    /// @return newIndex The up-to-date reward index. rewardIndex(t_2)
    /// @return lostReward The reward lost due to the rounding error.
    function updateIndex(RewardIndex index, uint256 ytSupply, uint256 totalAccrued)
        internal
        pure
        returns (RewardIndex newIndex, uint256 lostReward)
    {
        // When ytSupply is 0 but totalAccrued is non-zero, the reward will be lost.
        if (ytSupply == 0) return (index, totalAccrued);
        //                       N
        //                     _____
        //                     ╲
        //                      ╲     totalAccrued
        //                       ╲                 i
        // globalRewardIndex =   ╱   ────────────────
        //                      ╱        ytSupply
        //                     ╱                  i
        //                     ‾‾‾‾‾
        //                     i = 0
        // Note newIndex may not increase and small amount of reward may be lost when totalAccrued is small and ytSupply is way larger than totalAccrued.
        // e.g.
        // 1) totalAccrued = 1400, ytSupply = 5.57e23 => totalAccrued * 1e18 / ytSupply = 0.002519345 ~ 0. This 1400 reward will be lost.
        // 2) totalAccrued = 3.12e9 ytSupply = 6.017e23 => totalAccrued * 1e18 / ytSupply = 5,185.3082931694 ~ 5,185.
        // It means 185,500 (= totalAccrued - 5185 * ytSupply / 1e18 = 3.12e9 - 3,119,814,500) reward will be lost.
        newIndex = index + RewardIndex.wrap(FixedPointMathLib.divWad(totalAccrued, ytSupply).toUint128());
        lostReward = totalAccrued - FixedPointMathLib.mulWad(ytSupply, (newIndex - index).unwrap()); // Never underflow
    }

    /// @notice Update the accrued reward for a user `account` since the last time when `account` accrued reward based on the `account`'s YT balance `ytBalance`.
    /// @dev Assumption: `index` is always greater than or equal to `userIndex`
    /// @param index The up-to-date reward index.
    /// @param account The account to update the reward for.
    /// @param ytBalance The `account`'s YT balance.
    function accrueUserReward(
        mapping(address user => Reward userReward) storage self,
        RewardIndex index, // rewardIndex(t_2)
        address account, // u
        uint256 ytBalance // ytBalance_u
    ) internal {
        RewardIndex prevIndex = self[account].userIndex;
        // r  ⎛t ⎞     = r  ⎛t ⎞      + ytBalance  ⋅ ⎛rewardIndex ⎛t ⎞ - rewardIndex ⎛t ⎞⎞
        //  u ⎝ 2⎠        u ⎝ 1⎠                 u   ⎝            ⎝ 2⎠               ⎝ 1⎠⎠
        uint256 accrued = FixedPointMathLib.mulWad(ytBalance, RewardIndex.unwrap(index - prevIndex)); // d_u(t_2)
        self[account].accrued += accrued.toUint128(); // r_u(t_2) = r_u(t_1) + d_u(t_2)
        self[account].userIndex = index;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/// @notice Principal tokens (zero-coupon tokens) are redeemable for a single underlying EIP-20 token at a future timestamp.
/// https://eips.ethereum.org/EIPS/eip-5095
interface EIP5095 {
    /// @dev We think EIP-5095 `Redeem` event lacks `by` and `principal` fields.
    /// So we emit our own `Redeem` event instead of EIP-5095 `Redeem` event.
    event Redeem(address indexed owner, address indexed receiver, uint256 underlyings);

    /// @notice The address of the underlying token used by the Principal Token for accounting, and redeeming.
    function underlying() external view returns (address);

    /// @notice The unix timestamp (uint256) at or after which Principal Tokens can be redeemed for their underlying deposit.
    function maturity() external view returns (uint256 timestamp);

    /// @notice The amount of underlying that would be exchanged for the amount of PTs provided, in an ideal scenario where all the conditions are met.
    /// @notice Before maturity, the amount of underlying returned is as if the PTs would be at maturity.
    /// @notice MUST NOT be inclusive of any fees that are charged against redemptions.
    /// @notice MUST NOT show any variations depending on the caller.
    /// @notice MUST NOT reflect slippage or other on-chain conditions, when performing the actual redemption.
    /// @notice MUST NOT revert unless due to integer overflow caused by an unreasonably large input.
    /// @notice MUST round down towards 0.
    /// @notice This calculation MAY NOT reflect the “per-user” price-per-principal-token, and instead should reflect the “average-user’s” price-per-principal-token, meaning what the average user should expect to see when exchanging to and from.
    function convertToUnderlying(uint256 principal) external view returns (uint256 underlyings);

    /// @notice The amount of principal tokens that the principal token contract would request for redemption in order to provide the amount of underlying specified, in an ideal scenario where all the conditions are met.
    /// @notice MUST NOT be inclusive of any fees.
    /// @notice MUST NOT show any variations depending on the caller.
    /// @notice MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
    /// @notice MUST NOT revert unless due to integer overflow caused by an unreasonably large input.
    /// @notice MUST round down towards 0.
    /// @notice This calculation MAY NOT reflect the “per-user” price-per-principal-token, and instead should reflect the “average-user’s” price-per-principal-token, meaning what the average user should expect to see when redeeming.
    function convertToPrincipal(uint256 underlyings) external view returns (uint256 principal);

    /// @notice Maximum amount of principal tokens that can be redeemed from the holder balance, through a redeem call.
    /// @notice MUST return the maximum amount of principal tokens that could be transferred from holder through redeem and not cause a revert, which MUST NOT be higher than the actual maximum that would be accepted (it should underestimate if necessary).
    /// @notice MUST factor in both global and user-specific limits, like if redemption is entirely disabled (even temporarily) it MUST return 0.
    /// @notice MUST NOT revert.
    function maxRedeem(address owner) external view returns (uint256);

    /// @notice Allows an on-chain or off-chain user to simulate the effects of their redeemption at the current block, given current on-chain conditions.
    /// @notice MUST return as close to and no more than the exact amount of underliyng that would be obtained in a redeem call in the same transaction. I.e. redeem should return the same or more assets as previewRedeem if called in the same transaction.
    /// @notice MUST NOT account for redemption limits like those returned from maxRedeem and should always act as though the redemption would be accepted, regardless if the user has enough principal tokens, etc.
    /// @notice MUST be inclusive of redemption fees. Integrators should be aware of the existence of redemption fees.
    /// @notice MUST NOT revert due to principal token contract specific user/global limits. MAY revert due to other conditions that would also cause redeem to revert.
    /// Note that any unfavorable discrepancy between convertToUnderlying and previewRedeem SHOULD be considered slippage in price-per-principal-token or some other type of condition.
    function previewRedeem(uint256 principal) external view returns (uint256 underlyings);

    /// @notice At or after maturity, burns exactly principal of Principal Tokens from from and sends assets of underlying tokens to to.
    /// @notice Interfaces and other contracts MUST NOT expect fund custody to be present. While custodial redemption of Principal Tokens through the Principal Token contract is extremely useful for integrators, some protocols may find giving the Principal Token itself custody breaks their backwards compatibility.
    /// @notice MUST emit the Redeem event.
    /// @notice MUST support a redeem flow where the Principal Tokens are burned from holder directly where holder is msg.sender or msg.sender has EIP-20 approval over the principal tokens of holder. MAY support an additional flow in which the principal tokens are transferred to the Principal Token contract before the redeem execution, and are accounted for during redeem.
    /// @notice MUST revert if all of principal cannot be redeemed (due to withdrawal limit being reached, slippage, the holder not having enough Principal Tokens, etc).
    /// @notice Note that some implementations will require pre-requesting to the Principal Token before a withdrawal may be performed. Those methods should be performed separately.
    function redeem(uint256 principal, address receiver, address owner) external returns (uint256 underlyings);

    /// @notice Maximum amount of the underlying asset that can be redeemed from the holder principal token balance, through a withdraw call.
    function maxWithdraw(address owner) external view returns (uint256 underlyings);

    /// @dev Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block, given current on-chain conditions.
    function previewWithdraw(uint256 underlyings) external view returns (uint256 principal);

    /// @notice Burns principal from holder and sends exactly assets of underlying tokens to receiver.
    /// @notice MUST emit the Redeem event.
    /// @notice MUST support a withdraw flow where the principal tokens are burned from holder directly where holder is msg.sender or msg.sender has EIP-20 approval over the principal tokens of holder. MAY support an additional flow in which the principal tokens are transferred to the principal token contract before the withdraw execution, and are accounted for during withdraw.
    /// @notice MUST revert if all of assets cannot be withdrawn (due to withdrawal limit being reached, slippage, the holder not having enough principal tokens, etc).
    /// @notice Note that some implementations will require pre-requesting to the principal token contract before a withdrawal may be performed. Those methods should be performed separately.
    function withdraw(uint256 underlyings, address receiver, address owner) external returns (uint256 principal);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Pausable.sol)

pragma solidity ^0.8.20;

import {Context} from "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    bool private _paused;

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
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
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
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
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Reentrancy guard mixin.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/ReentrancyGuard.sol)
abstract contract ReentrancyGuard {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Unauthorized reentrant call.
    error Reentrancy();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Equivalent to: `uint72(bytes9(keccak256("_REENTRANCY_GUARD_SLOT")))`.
    /// 9 bytes is large enough to avoid collisions with lower slots,
    /// but not too large to result in excessive bytecode bloat.
    uint256 private constant _REENTRANCY_GUARD_SLOT = 0x929eee149b4bd21268;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      REENTRANCY GUARD                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Guards a function from reentrancy.
    modifier nonReentrant() virtual {
        /// @solidity memory-safe-assembly
        assembly {
            if eq(sload(_REENTRANCY_GUARD_SLOT), address()) {
                mstore(0x00, 0xab143c06) // `Reentrancy()`.
                revert(0x1c, 0x04)
            }
            sstore(_REENTRANCY_GUARD_SLOT, address())
        }
        _;
        /// @solidity memory-safe-assembly
        assembly {
            sstore(_REENTRANCY_GUARD_SLOT, codesize())
        }
    }

    /// @dev Guards a view function from read-only reentrancy.
    modifier nonReadReentrant() virtual {
        /// @solidity memory-safe-assembly
        assembly {
            if eq(sload(_REENTRANCY_GUARD_SLOT), address()) {
                mstore(0x00, 0xab143c06) // `Reentrancy()`.
                revert(0x1c, 0x04)
            }
        }
        _;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Simple ERC20 + EIP-2612 implementation.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol)
///
/// @dev Note:
/// - The ERC20 standard allows minting and transferring to and from the zero address,
///   minting and transferring zero tokens, as well as self-approvals.
///   For performance, this implementation WILL NOT revert for such actions.
///   Please add any checks with overrides if desired.
/// - The `permit` function uses the ecrecover precompile (0x1).
///
/// If you are overriding:
/// - NEVER violate the ERC20 invariant:
///   the total sum of all balances must be equal to `totalSupply()`.
/// - Check that the overridden function is actually used in the function you want to
///   change the behavior of. Much of the code has been manually inlined for performance.
abstract contract ERC20 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The total supply has overflowed.
    error TotalSupplyOverflow();

    /// @dev The allowance has overflowed.
    error AllowanceOverflow();

    /// @dev The allowance has underflowed.
    error AllowanceUnderflow();

    /// @dev Insufficient balance.
    error InsufficientBalance();

    /// @dev Insufficient allowance.
    error InsufficientAllowance();

    /// @dev The permit is invalid.
    error InvalidPermit();

    /// @dev The permit has expired.
    error PermitExpired();

    /// @dev The allowance of Permit2 is fixed at infinity.
    error Permit2AllowanceIsFixedAtInfinity();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Emitted when `amount` tokens is transferred from `from` to `to`.
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @dev Emitted when `amount` tokens is approved by `owner` to be used by `spender`.
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /// @dev `keccak256(bytes("Transfer(address,address,uint256)"))`.
    uint256 private constant _TRANSFER_EVENT_SIGNATURE =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    /// @dev `keccak256(bytes("Approval(address,address,uint256)"))`.
    uint256 private constant _APPROVAL_EVENT_SIGNATURE =
        0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The storage slot for the total supply.
    uint256 private constant _TOTAL_SUPPLY_SLOT = 0x05345cdf77eb68f44c;

    /// @dev The balance slot of `owner` is given by:
    /// ```
    ///     mstore(0x0c, _BALANCE_SLOT_SEED)
    ///     mstore(0x00, owner)
    ///     let balanceSlot := keccak256(0x0c, 0x20)
    /// ```
    uint256 private constant _BALANCE_SLOT_SEED = 0x87a211a2;

    /// @dev The allowance slot of (`owner`, `spender`) is given by:
    /// ```
    ///     mstore(0x20, spender)
    ///     mstore(0x0c, _ALLOWANCE_SLOT_SEED)
    ///     mstore(0x00, owner)
    ///     let allowanceSlot := keccak256(0x0c, 0x34)
    /// ```
    uint256 private constant _ALLOWANCE_SLOT_SEED = 0x7f5e9f20;

    /// @dev The nonce slot of `owner` is given by:
    /// ```
    ///     mstore(0x0c, _NONCES_SLOT_SEED)
    ///     mstore(0x00, owner)
    ///     let nonceSlot := keccak256(0x0c, 0x20)
    /// ```
    uint256 private constant _NONCES_SLOT_SEED = 0x38377508;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev `(_NONCES_SLOT_SEED << 16) | 0x1901`.
    uint256 private constant _NONCES_SLOT_SEED_WITH_SIGNATURE_PREFIX = 0x383775081901;

    /// @dev `keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")`.
    bytes32 private constant _DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    /// @dev `keccak256("1")`.
    /// If you need to use a different version, override `_versionHash`.
    bytes32 private constant _DEFAULT_VERSION_HASH =
        0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6;

    /// @dev `keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")`.
    bytes32 private constant _PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    /// @dev The canonical Permit2 address.
    /// For signature-based allowance granting for single transaction ERC20 `transferFrom`.
    /// To enable, override `_givePermit2InfiniteAllowance()`.
    /// [Github](https://github.com/Uniswap/permit2)
    /// [Etherscan](https://etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
    address internal constant _PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ERC20 METADATA                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the name of the token.
    function name() public view virtual returns (string memory);

    /// @dev Returns the symbol of the token.
    function symbol() public view virtual returns (string memory);

    /// @dev Returns the decimals places of the token.
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERC20                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the amount of tokens in existence.
    function totalSupply() public view virtual returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := sload(_TOTAL_SUPPLY_SLOT)
        }
    }

    /// @dev Returns the amount of tokens owned by `owner`.
    function balanceOf(address owner) public view virtual returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x0c, _BALANCE_SLOT_SEED)
            mstore(0x00, owner)
            result := sload(keccak256(0x0c, 0x20))
        }
    }

    /// @dev Returns the amount of tokens that `spender` can spend on behalf of `owner`.
    function allowance(address owner, address spender)
        public
        view
        virtual
        returns (uint256 result)
    {
        if (_givePermit2InfiniteAllowance()) {
            if (spender == _PERMIT2) return type(uint256).max;
        }
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, spender)
            mstore(0x0c, _ALLOWANCE_SLOT_SEED)
            mstore(0x00, owner)
            result := sload(keccak256(0x0c, 0x34))
        }
    }

    /// @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
    ///
    /// Emits a {Approval} event.
    function approve(address spender, uint256 amount) public virtual returns (bool) {
        if (_givePermit2InfiniteAllowance()) {
            /// @solidity memory-safe-assembly
            assembly {
                // If `spender == _PERMIT2 && amount != type(uint256).max`.
                if iszero(or(xor(shr(96, shl(96, spender)), _PERMIT2), iszero(not(amount)))) {
                    mstore(0x00, 0x3f68539a) // `Permit2AllowanceIsFixedAtInfinity()`.
                    revert(0x1c, 0x04)
                }
            }
        }
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the allowance slot and store the amount.
            mstore(0x20, spender)
            mstore(0x0c, _ALLOWANCE_SLOT_SEED)
            mstore(0x00, caller())
            sstore(keccak256(0x0c, 0x34), amount)
            // Emit the {Approval} event.
            mstore(0x00, amount)
            log3(0x00, 0x20, _APPROVAL_EVENT_SIGNATURE, caller(), shr(96, mload(0x2c)))
        }
        return true;
    }

    /// @dev Transfer `amount` tokens from the caller to `to`.
    ///
    /// Requirements:
    /// - `from` must at least have `amount`.
    ///
    /// Emits a {Transfer} event.
    function transfer(address to, uint256 amount) public virtual returns (bool) {
        _beforeTokenTransfer(msg.sender, to, amount);
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the balance slot and load its value.
            mstore(0x0c, _BALANCE_SLOT_SEED)
            mstore(0x00, caller())
            let fromBalanceSlot := keccak256(0x0c, 0x20)
            let fromBalance := sload(fromBalanceSlot)
            // Revert if insufficient balance.
            if gt(amount, fromBalance) {
                mstore(0x00, 0xf4d678b8) // `InsufficientBalance()`.
                revert(0x1c, 0x04)
            }
            // Subtract and store the updated balance.
            sstore(fromBalanceSlot, sub(fromBalance, amount))
            // Compute the balance slot of `to`.
            mstore(0x00, to)
            let toBalanceSlot := keccak256(0x0c, 0x20)
            // Add and store the updated balance of `to`.
            // Will not overflow because the sum of all user balances
            // cannot exceed the maximum uint256 value.
            sstore(toBalanceSlot, add(sload(toBalanceSlot), amount))
            // Emit the {Transfer} event.
            mstore(0x20, amount)
            log3(0x20, 0x20, _TRANSFER_EVENT_SIGNATURE, caller(), shr(96, mload(0x0c)))
        }
        _afterTokenTransfer(msg.sender, to, amount);
        return true;
    }

    /// @dev Transfers `amount` tokens from `from` to `to`.
    ///
    /// Note: Does not update the allowance if it is the maximum uint256 value.
    ///
    /// Requirements:
    /// - `from` must at least have `amount`.
    /// - The caller must have at least `amount` of allowance to transfer the tokens of `from`.
    ///
    /// Emits a {Transfer} event.
    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        _beforeTokenTransfer(from, to, amount);
        // Code duplication is for zero-cost abstraction if possible.
        if (_givePermit2InfiniteAllowance()) {
            /// @solidity memory-safe-assembly
            assembly {
                let from_ := shl(96, from)
                if iszero(eq(caller(), _PERMIT2)) {
                    // Compute the allowance slot and load its value.
                    mstore(0x20, caller())
                    mstore(0x0c, or(from_, _ALLOWANCE_SLOT_SEED))
                    let allowanceSlot := keccak256(0x0c, 0x34)
                    let allowance_ := sload(allowanceSlot)
                    // If the allowance is not the maximum uint256 value.
                    if not(allowance_) {
                        // Revert if the amount to be transferred exceeds the allowance.
                        if gt(amount, allowance_) {
                            mstore(0x00, 0x13be252b) // `InsufficientAllowance()`.
                            revert(0x1c, 0x04)
                        }
                        // Subtract and store the updated allowance.
                        sstore(allowanceSlot, sub(allowance_, amount))
                    }
                }
                // Compute the balance slot and load its value.
                mstore(0x0c, or(from_, _BALANCE_SLOT_SEED))
                let fromBalanceSlot := keccak256(0x0c, 0x20)
                let fromBalance := sload(fromBalanceSlot)
                // Revert if insufficient balance.
                if gt(amount, fromBalance) {
                    mstore(0x00, 0xf4d678b8) // `InsufficientBalance()`.
                    revert(0x1c, 0x04)
                }
                // Subtract and store the updated balance.
                sstore(fromBalanceSlot, sub(fromBalance, amount))
                // Compute the balance slot of `to`.
                mstore(0x00, to)
                let toBalanceSlot := keccak256(0x0c, 0x20)
                // Add and store the updated balance of `to`.
                // Will not overflow because the sum of all user balances
                // cannot exceed the maximum uint256 value.
                sstore(toBalanceSlot, add(sload(toBalanceSlot), amount))
                // Emit the {Transfer} event.
                mstore(0x20, amount)
                log3(0x20, 0x20, _TRANSFER_EVENT_SIGNATURE, shr(96, from_), shr(96, mload(0x0c)))
            }
        } else {
            /// @solidity memory-safe-assembly
            assembly {
                let from_ := shl(96, from)
                // Compute the allowance slot and load its value.
                mstore(0x20, caller())
                mstore(0x0c, or(from_, _ALLOWANCE_SLOT_SEED))
                let allowanceSlot := keccak256(0x0c, 0x34)
                let allowance_ := sload(allowanceSlot)
                // If the allowance is not the maximum uint256 value.
                if not(allowance_) {
                    // Revert if the amount to be transferred exceeds the allowance.
                    if gt(amount, allowance_) {
                        mstore(0x00, 0x13be252b) // `InsufficientAllowance()`.
                        revert(0x1c, 0x04)
                    }
                    // Subtract and store the updated allowance.
                    sstore(allowanceSlot, sub(allowance_, amount))
                }
                // Compute the balance slot and load its value.
                mstore(0x0c, or(from_, _BALANCE_SLOT_SEED))
                let fromBalanceSlot := keccak256(0x0c, 0x20)
                let fromBalance := sload(fromBalanceSlot)
                // Revert if insufficient balance.
                if gt(amount, fromBalance) {
                    mstore(0x00, 0xf4d678b8) // `InsufficientBalance()`.
                    revert(0x1c, 0x04)
                }
                // Subtract and store the updated balance.
                sstore(fromBalanceSlot, sub(fromBalance, amount))
                // Compute the balance slot of `to`.
                mstore(0x00, to)
                let toBalanceSlot := keccak256(0x0c, 0x20)
                // Add and store the updated balance of `to`.
                // Will not overflow because the sum of all user balances
                // cannot exceed the maximum uint256 value.
                sstore(toBalanceSlot, add(sload(toBalanceSlot), amount))
                // Emit the {Transfer} event.
                mstore(0x20, amount)
                log3(0x20, 0x20, _TRANSFER_EVENT_SIGNATURE, shr(96, from_), shr(96, mload(0x0c)))
            }
        }
        _afterTokenTransfer(from, to, amount);
        return true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          EIP-2612                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev For more performance, override to return the constant value
    /// of `keccak256(bytes(name()))` if `name()` will never change.
    function _constantNameHash() internal view virtual returns (bytes32 result) {}

    /// @dev If you need a different value, override this function.
    function _versionHash() internal view virtual returns (bytes32 result) {
        result = _DEFAULT_VERSION_HASH;
    }

    /// @dev For inheriting contracts to increment the nonce.
    function _incrementNonce(address owner) internal virtual {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x0c, _NONCES_SLOT_SEED)
            mstore(0x00, owner)
            let nonceSlot := keccak256(0x0c, 0x20)
            sstore(nonceSlot, add(1, sload(nonceSlot)))
        }
    }

    /// @dev Returns the current nonce for `owner`.
    /// This value is used to compute the signature for EIP-2612 permit.
    function nonces(address owner) public view virtual returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the nonce slot and load its value.
            mstore(0x0c, _NONCES_SLOT_SEED)
            mstore(0x00, owner)
            result := sload(keccak256(0x0c, 0x20))
        }
    }

    /// @dev Sets `value` as the allowance of `spender` over the tokens of `owner`,
    /// authorized by a signed approval by `owner`.
    ///
    /// Emits a {Approval} event.
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        if (_givePermit2InfiniteAllowance()) {
            /// @solidity memory-safe-assembly
            assembly {
                // If `spender == _PERMIT2 && value != type(uint256).max`.
                if iszero(or(xor(shr(96, shl(96, spender)), _PERMIT2), iszero(not(value)))) {
                    mstore(0x00, 0x3f68539a) // `Permit2AllowanceIsFixedAtInfinity()`.
                    revert(0x1c, 0x04)
                }
            }
        }
        bytes32 nameHash = _constantNameHash();
        //  We simply calculate it on-the-fly to allow for cases where the `name` may change.
        if (nameHash == bytes32(0)) nameHash = keccak256(bytes(name()));
        bytes32 versionHash = _versionHash();
        /// @solidity memory-safe-assembly
        assembly {
            // Revert if the block timestamp is greater than `deadline`.
            if gt(timestamp(), deadline) {
                mstore(0x00, 0x1a15a3cc) // `PermitExpired()`.
                revert(0x1c, 0x04)
            }
            let m := mload(0x40) // Grab the free memory pointer.
            // Clean the upper 96 bits.
            owner := shr(96, shl(96, owner))
            spender := shr(96, shl(96, spender))
            // Compute the nonce slot and load its value.
            mstore(0x0e, _NONCES_SLOT_SEED_WITH_SIGNATURE_PREFIX)
            mstore(0x00, owner)
            let nonceSlot := keccak256(0x0c, 0x20)
            let nonceValue := sload(nonceSlot)
            // Prepare the domain separator.
            mstore(m, _DOMAIN_TYPEHASH)
            mstore(add(m, 0x20), nameHash)
            mstore(add(m, 0x40), versionHash)
            mstore(add(m, 0x60), chainid())
            mstore(add(m, 0x80), address())
            mstore(0x2e, keccak256(m, 0xa0))
            // Prepare the struct hash.
            mstore(m, _PERMIT_TYPEHASH)
            mstore(add(m, 0x20), owner)
            mstore(add(m, 0x40), spender)
            mstore(add(m, 0x60), value)
            mstore(add(m, 0x80), nonceValue)
            mstore(add(m, 0xa0), deadline)
            mstore(0x4e, keccak256(m, 0xc0))
            // Prepare the ecrecover calldata.
            mstore(0x00, keccak256(0x2c, 0x42))
            mstore(0x20, and(0xff, v))
            mstore(0x40, r)
            mstore(0x60, s)
            let t := staticcall(gas(), 1, 0x00, 0x80, 0x20, 0x20)
            // If the ecrecover fails, the returndatasize will be 0x00,
            // `owner` will be checked if it equals the hash at 0x00,
            // which evaluates to false (i.e. 0), and we will revert.
            // If the ecrecover succeeds, the returndatasize will be 0x20,
            // `owner` will be compared against the returned address at 0x20.
            if iszero(eq(mload(returndatasize()), owner)) {
                mstore(0x00, 0xddafbaef) // `InvalidPermit()`.
                revert(0x1c, 0x04)
            }
            // Increment and store the updated nonce.
            sstore(nonceSlot, add(nonceValue, t)) // `t` is 1 if ecrecover succeeds.
            // Compute the allowance slot and store the value.
            // The `owner` is already at slot 0x20.
            mstore(0x40, or(shl(160, _ALLOWANCE_SLOT_SEED), spender))
            sstore(keccak256(0x2c, 0x34), value)
            // Emit the {Approval} event.
            log3(add(m, 0x60), 0x20, _APPROVAL_EVENT_SIGNATURE, owner, spender)
            mstore(0x40, m) // Restore the free memory pointer.
            mstore(0x60, 0) // Restore the zero pointer.
        }
    }

    /// @dev Returns the EIP-712 domain separator for the EIP-2612 permit.
    function DOMAIN_SEPARATOR() public view virtual returns (bytes32 result) {
        bytes32 nameHash = _constantNameHash();
        //  We simply calculate it on-the-fly to allow for cases where the `name` may change.
        if (nameHash == bytes32(0)) nameHash = keccak256(bytes(name()));
        bytes32 versionHash = _versionHash();
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Grab the free memory pointer.
            mstore(m, _DOMAIN_TYPEHASH)
            mstore(add(m, 0x20), nameHash)
            mstore(add(m, 0x40), versionHash)
            mstore(add(m, 0x60), chainid())
            mstore(add(m, 0x80), address())
            result := keccak256(m, 0xa0)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  INTERNAL MINT FUNCTIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Mints `amount` tokens to `to`, increasing the total supply.
    ///
    /// Emits a {Transfer} event.
    function _mint(address to, uint256 amount) internal virtual {
        _beforeTokenTransfer(address(0), to, amount);
        /// @solidity memory-safe-assembly
        assembly {
            let totalSupplyBefore := sload(_TOTAL_SUPPLY_SLOT)
            let totalSupplyAfter := add(totalSupplyBefore, amount)
            // Revert if the total supply overflows.
            if lt(totalSupplyAfter, totalSupplyBefore) {
                mstore(0x00, 0xe5cfe957) // `TotalSupplyOverflow()`.
                revert(0x1c, 0x04)
            }
            // Store the updated total supply.
            sstore(_TOTAL_SUPPLY_SLOT, totalSupplyAfter)
            // Compute the balance slot and load its value.
            mstore(0x0c, _BALANCE_SLOT_SEED)
            mstore(0x00, to)
            let toBalanceSlot := keccak256(0x0c, 0x20)
            // Add and store the updated balance.
            sstore(toBalanceSlot, add(sload(toBalanceSlot), amount))
            // Emit the {Transfer} event.
            mstore(0x20, amount)
            log3(0x20, 0x20, _TRANSFER_EVENT_SIGNATURE, 0, shr(96, mload(0x0c)))
        }
        _afterTokenTransfer(address(0), to, amount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  INTERNAL BURN FUNCTIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Burns `amount` tokens from `from`, reducing the total supply.
    ///
    /// Emits a {Transfer} event.
    function _burn(address from, uint256 amount) internal virtual {
        _beforeTokenTransfer(from, address(0), amount);
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the balance slot and load its value.
            mstore(0x0c, _BALANCE_SLOT_SEED)
            mstore(0x00, from)
            let fromBalanceSlot := keccak256(0x0c, 0x20)
            let fromBalance := sload(fromBalanceSlot)
            // Revert if insufficient balance.
            if gt(amount, fromBalance) {
                mstore(0x00, 0xf4d678b8) // `InsufficientBalance()`.
                revert(0x1c, 0x04)
            }
            // Subtract and store the updated balance.
            sstore(fromBalanceSlot, sub(fromBalance, amount))
            // Subtract and store the updated total supply.
            sstore(_TOTAL_SUPPLY_SLOT, sub(sload(_TOTAL_SUPPLY_SLOT), amount))
            // Emit the {Transfer} event.
            mstore(0x00, amount)
            log3(0x00, 0x20, _TRANSFER_EVENT_SIGNATURE, shr(96, shl(96, from)), 0)
        }
        _afterTokenTransfer(from, address(0), amount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                INTERNAL TRANSFER FUNCTIONS                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Moves `amount` of tokens from `from` to `to`.
    function _transfer(address from, address to, uint256 amount) internal virtual {
        _beforeTokenTransfer(from, to, amount);
        /// @solidity memory-safe-assembly
        assembly {
            let from_ := shl(96, from)
            // Compute the balance slot and load its value.
            mstore(0x0c, or(from_, _BALANCE_SLOT_SEED))
            let fromBalanceSlot := keccak256(0x0c, 0x20)
            let fromBalance := sload(fromBalanceSlot)
            // Revert if insufficient balance.
            if gt(amount, fromBalance) {
                mstore(0x00, 0xf4d678b8) // `InsufficientBalance()`.
                revert(0x1c, 0x04)
            }
            // Subtract and store the updated balance.
            sstore(fromBalanceSlot, sub(fromBalance, amount))
            // Compute the balance slot of `to`.
            mstore(0x00, to)
            let toBalanceSlot := keccak256(0x0c, 0x20)
            // Add and store the updated balance of `to`.
            // Will not overflow because the sum of all user balances
            // cannot exceed the maximum uint256 value.
            sstore(toBalanceSlot, add(sload(toBalanceSlot), amount))
            // Emit the {Transfer} event.
            mstore(0x20, amount)
            log3(0x20, 0x20, _TRANSFER_EVENT_SIGNATURE, shr(96, from_), shr(96, mload(0x0c)))
        }
        _afterTokenTransfer(from, to, amount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                INTERNAL ALLOWANCE FUNCTIONS                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Updates the allowance of `owner` for `spender` based on spent `amount`.
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        if (_givePermit2InfiniteAllowance()) {
            if (spender == _PERMIT2) return; // Do nothing, as allowance is infinite.
        }
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the allowance slot and load its value.
            mstore(0x20, spender)
            mstore(0x0c, _ALLOWANCE_SLOT_SEED)
            mstore(0x00, owner)
            let allowanceSlot := keccak256(0x0c, 0x34)
            let allowance_ := sload(allowanceSlot)
            // If the allowance is not the maximum uint256 value.
            if not(allowance_) {
                // Revert if the amount to be transferred exceeds the allowance.
                if gt(amount, allowance_) {
                    mstore(0x00, 0x13be252b) // `InsufficientAllowance()`.
                    revert(0x1c, 0x04)
                }
                // Subtract and store the updated allowance.
                sstore(allowanceSlot, sub(allowance_, amount))
            }
        }
    }

    /// @dev Sets `amount` as the allowance of `spender` over the tokens of `owner`.
    ///
    /// Emits a {Approval} event.
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        if (_givePermit2InfiniteAllowance()) {
            /// @solidity memory-safe-assembly
            assembly {
                // If `spender == _PERMIT2 && amount != type(uint256).max`.
                if iszero(or(xor(shr(96, shl(96, spender)), _PERMIT2), iszero(not(amount)))) {
                    mstore(0x00, 0x3f68539a) // `Permit2AllowanceIsFixedAtInfinity()`.
                    revert(0x1c, 0x04)
                }
            }
        }
        /// @solidity memory-safe-assembly
        assembly {
            let owner_ := shl(96, owner)
            // Compute the allowance slot and store the amount.
            mstore(0x20, spender)
            mstore(0x0c, or(owner_, _ALLOWANCE_SLOT_SEED))
            sstore(keccak256(0x0c, 0x34), amount)
            // Emit the {Approval} event.
            mstore(0x00, amount)
            log3(0x00, 0x20, _APPROVAL_EVENT_SIGNATURE, shr(96, owner_), shr(96, mload(0x2c)))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     HOOKS TO OVERRIDE                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Hook that is called before any transfer of tokens.
    /// This includes minting and burning.
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /// @dev Hook that is called after any transfer of tokens.
    /// This includes minting and burning.
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          PERMIT2                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns whether to fix the Permit2 contract's allowance at infinity.
    ///
    /// This value should be kept constant after contract initialization,
    /// or else the actual allowance values may not match with the {Approval} events.
    /// For best performance, return a compile-time constant for zero-cost abstraction.
    function _givePermit2InfiniteAllowance() internal view virtual returns (bool) {
        return true;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

abstract contract LibApproval {
    /// @dev The approval slot of (`src`, `spender`) is given by:
    /// ```
    ///     mstore(0x20, spender)
    ///     mstore(0x0c, _IS_APPROVED_SLOT_SEED)
    ///     mstore(0x00, src)
    ///     let allowanceSlot := keccak256(0x0c, 0x34)
    /// ```
    /// @dev Optimized storage slot for approval flags
    /// `mapping (address src => mapping (address spender => uint256 approved)) isApproved;`
    uint256 constant _IS_APPROVED_SLOT_SEED = 0xa8fe4407;

    /// @dev Get the approval status of the `spender` for the `src`. Return true if approved, 0 otherwise.
    function isApproved(address src, address spender) internal view returns (bool approved) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, spender)
            mstore(0x0c, _IS_APPROVED_SLOT_SEED)
            mstore(0x00, src)
            approved := sload(keccak256(0x0c, 0x34))
        }
    }

    /// @dev Set the approval status to 1 for the spender for the src.
    function setApproval(address src, address spender, bool approved) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the approval slot and store the amount.
            mstore(0x20, spender)
            mstore(0x0c, _IS_APPROVED_SLOT_SEED)
            mstore(0x00, src)
            sstore(keccak256(0x0c, 0x34), approved)
        }
    }

    function approveIfNeeded(address token, address spender) internal {
        if (!isApproved(token, spender)) {
            setApproval(token, spender, true);
            SafeTransferLib.safeApprove(token, spender, type(uint256).max);
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

import {Token} from "../../Types.sol";
import {IWETH} from "../../interfaces/IWETH.sol";

abstract contract VaultConnector {
    function asset() public view virtual returns (address);

    function target() public view virtual returns (address);

    /// @notice ERC4626-like conversion function.
    function convertToAssets(uint256 shares) public view virtual returns (uint256);

    /// @notice ERC4626-like conversion function.
    function convertToShares(uint256 assets) public view virtual returns (uint256);

    function previewDeposit(Token token, uint256 tokens) public view virtual returns (uint256 shares);
    function previewRedeem(Token token, uint256 shares) public view virtual returns (uint256 tokens);

    /// @notice ERC4626-like deposit function but `token` can be several assets.
    /// @param token The token to deposit. Native ETH, WETH and stETH for wsETH.
    /// @param tokens The amount of `token` to deposit.
    /// @param receiver The address to receive the shares.
    /// @return shares The amount of vault shares to be received.
    function deposit(Token token, uint256 tokens, address receiver) public payable virtual returns (uint256 shares);

    /// @notice ERC4626-like redeem function but `token` can be several assets.
    /// @param token The token we want to be paid out in.
    /// @param shares The amount of vault shares to redeem. It is NOT the amount of `token` to redeem.
    /// @param receiver The address to receive the tokens.
    /// @return tokens The amount of `token` to be received.
    function redeem(Token token, uint256 shares, address receiver) public virtual returns (uint256 tokens);

    /// @notice The tokens that can be used as `token` in `deposit` function.
    function getTokenInList() public view virtual returns (Token[] memory);

    /// @notice The tokens that can be used as `token` in `redeem` function.
    function getTokenOutList() public view virtual returns (Token[] memory);

    function _getWETHAddress() internal view virtual returns (address);

    function _wrapETH(uint256 amount) internal {
        address weth = _getWETHAddress();
        IWETH(weth).deposit{value: amount}();
    }

    function _unwrapWETH(address receiver, uint256 amount) internal {
        address weth = _getWETHAddress();
        IWETH(weth).withdraw(amount);
        SafeTransferLib.safeTransferETH(receiver, amount);
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {VaultConnector} from "./VaultConnector.sol";
import {DefaultConnectorFactory} from "./DefaultConnectorFactory.sol";

import {AccessManaged, AccessManager} from "../AccessManager.sol";

contract VaultConnectorRegistry is AccessManaged {
    AccessManager private immutable _i_accessManager;
    DefaultConnectorFactory public immutable _i_defaultConnector;

    mapping(address target => mapping(address asset => VaultConnector)) public s_connectors;

    constructor(AccessManager accessManager, address defaultConnector) {
        _i_accessManager = accessManager;
        _i_defaultConnector = DefaultConnectorFactory(defaultConnector);
    }

    function getConnector(address target, address asset) public returns (VaultConnector) {
        VaultConnector connector = s_connectors[target][asset];
        return address(connector) == address(0) ? _i_defaultConnector.getOrCreateConnector(target, asset) : connector;
    }

    function setConnector(address target, address asset, VaultConnector connector) public restricted {
        s_connectors[target][asset] = connector;
    }

    function i_accessManager() public view override returns (AccessManager) {
        return _i_accessManager;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {LibBytes} from "solady/src/utils/LibBytes.sol";

import "../Types.sol";

/// @notice Encoding utilities for hooks of Zap
library ZapHookEncoder {
    /// @notice abi.encode(twoCrypto, underlying, by, sharesFromUser)
    /// @notice Encode the data for the `swapTokenForYt`'s supply hook
    function encodeSupply(TwoCrypto twoCrypto, address underlying, address by, uint256 sharesFromUser)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory data = new bytes(0x80);
        assembly {
            mstore(add(data, 0x20), twoCrypto)
            mstore(add(data, 0x40), underlying)
            mstore(add(data, 0x60), by)
            mstore(add(data, 0x80), sharesFromUser)
        }
        return data;
    }

    function decodeSupply(bytes calldata data)
        internal
        pure
        returns (TwoCrypto twoCrypto, address underlying, address by, uint256 sharesFromUser)
    {
        twoCrypto = TwoCrypto.wrap(address(uint160(uint256(LibBytes.loadCalldata(data, 0x00)))));
        underlying = address(uint160(uint256(LibBytes.loadCalldata(data, 0x20))));
        by = address(uint160(uint256(LibBytes.loadCalldata(data, 0x40))));
        sharesFromUser = uint256(LibBytes.loadCalldata(data, 0x60));
    }

    /// @notice abi.encode(twoCrypto, underlying, sharesDx)
    /// @notice Encode the data for the `swapYtForToken`'s unite hook
    function encodeUnite(TwoCrypto twoCrypto, address underlying, ApproxValue sharesDx)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory data = new bytes(0x60);
        assembly {
            mstore(add(data, 0x20), twoCrypto)
            mstore(add(data, 0x40), underlying)
            mstore(add(data, 0x60), sharesDx)
        }
        return data;
    }

    function decodeUnite(bytes calldata data)
        internal
        pure
        returns (TwoCrypto twoCrypto, address underlying, uint256 sharesDx)
    {
        twoCrypto = TwoCrypto.wrap(address(uint160(uint256(LibBytes.loadCalldata(data, 0x00)))));
        underlying = address(uint160(uint256(LibBytes.loadCalldata(data, 0x20))));
        sharesDx = uint256(LibBytes.loadCalldata(data, 0x40));
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {Factory} from "../Factory.sol";
import {Errors} from "../Errors.sol";
import {CustomRevert} from "./CustomRevert.sol";

library ContractValidation {
    using CustomRevert for bytes4;

    function checkTwoCrypto(Factory factory, address twoCrypto, address canonicalTwoCryptoDeployer) internal view {
        if (factory.s_pools(twoCrypto) != canonicalTwoCryptoDeployer) Errors.Zap_BadTwoCrypto.selector.revertWith();
    }

    function checkPrincipalToken(Factory factory, address principalToken) internal view {
        if (factory.s_principalTokens(principalToken) == address(0)) Errors.Zap_BadPrincipalToken.selector.revertWith();
    }

    function hasCode(address addr) internal view returns (bool) {
        return addr.code.length > 0;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {ERC20} from "solady/src/tokens/ERC20.sol";

library Casting {
    function asAddr(ERC20 x) internal pure returns (address) {
        return address(x);
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {MetadataReaderLib} from "solady/src/utils/MetadataReaderLib.sol";

import "../Types.sol";
import {WAD, TARGET_INDEX, PT_INDEX} from "../Constants.sol";

import {PrincipalToken} from "../tokens/PrincipalToken.sol";
import {LibTwoCryptoNG, TwoCrypto} from "./LibTwoCryptoNG.sol";

library ZapMathLib {
    using LibTwoCryptoNG for TwoCrypto;

    function computeSharesToTwoCrypto(TwoCrypto twoCrypto, PrincipalToken principalToken, uint256 shares)
        internal
        view
        returns (uint256 sharesToAMM)
    {
        // Initial liquidity -> Calculate based on initial_price param.
        // Assumption: Some of initial liquidity is permanently locked. So this branch runs only once per pool.
        if (twoCrypto.totalSupply() == 0) {
            // Adding liquidity in a ratio that (closely) matches the empty pool's initial price
            uint256 initialPrice = twoCrypto.last_prices();
            // Given 1 PT reserve, underlying token reserve should be `initialPrice` units of the underlying token
            uint256 underlyingDecimals = MetadataReaderLib.readDecimals(principalToken.underlying());
            uint256 underlyingReserveInPT = principalToken.previewSupply(10 ** underlyingDecimals * initialPrice / WAD);

            // sharesTokenize / initialLiquidity = principal / totalLiquidity
            // => sharesTokenize = shares * principal / (underlyingReserveInPT + principal)
            uint256 principal = 10 ** principalToken.decimals();
            uint256 sharesTokenized = FixedPointMathLib.mulDiv(shares, principal, underlyingReserveInPT + principal);
            sharesToAMM = shares - sharesTokenized;
        } else {
            uint256 ptReserve = twoCrypto.balances(PT_INDEX);
            uint256 underlyingReserve = twoCrypto.balances(TARGET_INDEX);
            uint256 underlyingReserveInPT = principalToken.previewSupply(underlyingReserve);

            // Liquidity added in a ratio that (closely) matches the existing pool's ratio
            // Formula: sharesToAMM / shares = underlyingReserveInPT / (underlyingReserveInPT + ptReserve)
            //      =>  sharesToAMM = shares * underlyingReserveInPT / (underlyingReserveInPT + ptReserve)
            sharesToAMM = FixedPointMathLib.mulDiv(shares, underlyingReserveInPT, underlyingReserveInPT + ptReserve);
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {LibTransient} from "solady/src/utils/LibTransient.sol";

import {Errors} from "../Errors.sol";
import {CustomRevert} from "./CustomRevert.sol";

/// @notice HookValidation is a contract that provides a authorization mechanism for callback receiver.
abstract contract HookValidation {
    using CustomRevert for bytes4;

    /// @dev Slot for the callback authorization.
    /// After the callback, the caller should call `verifyAndClearHookContext` to clear the context.
    LibTransient.TBool internal hookContext;

    function verifyAndClearHookContext() internal {
        bool context = LibTransient.getCompat(hookContext);
        LibTransient.clearCompat(hookContext);
        if (!context) Errors.Zap_BadCallback.selector.revertWith();
    }

    function setHookContext() internal {
        LibTransient.setCompat(hookContext, true);
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {ReentrancyGuardTransient} from "solady/src/utils/ReentrancyGuardTransient.sol";

import {LibApproval} from "../utils/LibApproval.sol";

import {Errors} from "../Errors.sol";

abstract contract ZapBase is ReentrancyGuardTransient, LibApproval {
    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert Errors.Zap_TransactionTooOld();
        _;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {ERC20} from "solady/src/tokens/ERC20.sol";

import {Token} from "../Types.sol";
import {NATIVE_ETH} from "../Constants.sol";

function unwrap(Token x) pure returns (address result) {
    result = Token.unwrap(x);
}

function erc20(Token token) pure returns (ERC20 result) {
    result = ERC20(Token.unwrap(token));
}

function isNative(Token x) pure returns (bool result) {
    result = Token.unwrap(x) == NATIVE_ETH;
}

function isNotNative(Token x) pure returns (bool result) {
    result = Token.unwrap(x) != NATIVE_ETH;
}

function eq(Token token0, address token1) pure returns (bool result) {
    result = Token.unwrap(token0) == token1;
}

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                     Utils For Test                        */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

function intoToken(address token) pure returns (Token result) {
    result = Token.wrap(token);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Simple single owner authorization mixin.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/auth/Ownable.sol)
///
/// @dev Note:
/// This implementation does NOT auto-initialize the owner to `msg.sender`.
/// You MUST call the `_initializeOwner` in the constructor / initializer.
///
/// While the ownable portion follows
/// [EIP-173](https://eips.ethereum.org/EIPS/eip-173) for compatibility,
/// the nomenclature for the 2-step ownership handover may be unique to this codebase.
abstract contract Ownable {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// @dev The `newOwner` cannot be the zero address.
    error NewOwnerIsZeroAddress();

    /// @dev The `pendingOwner` does not have a valid handover request.
    error NoHandoverRequest();

    /// @dev Cannot double-initialize.
    error AlreadyInitialized();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The ownership is transferred from `oldOwner` to `newOwner`.
    /// This event is intentionally kept the same as OpenZeppelin's Ownable to be
    /// compatible with indexers and [EIP-173](https://eips.ethereum.org/EIPS/eip-173),
    /// despite it not being as lightweight as a single argument event.
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    /// @dev An ownership handover to `pendingOwner` has been requested.
    event OwnershipHandoverRequested(address indexed pendingOwner);

    /// @dev The ownership handover to `pendingOwner` has been canceled.
    event OwnershipHandoverCanceled(address indexed pendingOwner);

    /// @dev `keccak256(bytes("OwnershipTransferred(address,address)"))`.
    uint256 private constant _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE =
        0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0;

    /// @dev `keccak256(bytes("OwnershipHandoverRequested(address)"))`.
    uint256 private constant _OWNERSHIP_HANDOVER_REQUESTED_EVENT_SIGNATURE =
        0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d;

    /// @dev `keccak256(bytes("OwnershipHandoverCanceled(address)"))`.
    uint256 private constant _OWNERSHIP_HANDOVER_CANCELED_EVENT_SIGNATURE =
        0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The owner slot is given by:
    /// `bytes32(~uint256(uint32(bytes4(keccak256("_OWNER_SLOT_NOT")))))`.
    /// It is intentionally chosen to be a high value
    /// to avoid collision with lower slots.
    /// The choice of manual storage layout is to enable compatibility
    /// with both regular and upgradeable contracts.
    bytes32 internal constant _OWNER_SLOT =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff74873927;

    /// The ownership handover slot of `newOwner` is given by:
    /// ```
    ///     mstore(0x00, or(shl(96, user), _HANDOVER_SLOT_SEED))
    ///     let handoverSlot := keccak256(0x00, 0x20)
    /// ```
    /// It stores the expiry timestamp of the two-step ownership handover.
    uint256 private constant _HANDOVER_SLOT_SEED = 0x389a75e1;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     INTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Override to return true to make `_initializeOwner` prevent double-initialization.
    function _guardInitializeOwner() internal pure virtual returns (bool guard) {}

    /// @dev Initializes the owner directly without authorization guard.
    /// This function must be called upon initialization,
    /// regardless of whether the contract is upgradeable or not.
    /// This is to enable generalization to both regular and upgradeable contracts,
    /// and to save gas in case the initial owner is not the caller.
    /// For performance reasons, this function will not check if there
    /// is an existing owner.
    function _initializeOwner(address newOwner) internal virtual {
        if (_guardInitializeOwner()) {
            /// @solidity memory-safe-assembly
            assembly {
                let ownerSlot := _OWNER_SLOT
                if sload(ownerSlot) {
                    mstore(0x00, 0x0dc149f0) // `AlreadyInitialized()`.
                    revert(0x1c, 0x04)
                }
                // Clean the upper 96 bits.
                newOwner := shr(96, shl(96, newOwner))
                // Store the new value.
                sstore(ownerSlot, or(newOwner, shl(255, iszero(newOwner))))
                // Emit the {OwnershipTransferred} event.
                log3(0, 0, _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE, 0, newOwner)
            }
        } else {
            /// @solidity memory-safe-assembly
            assembly {
                // Clean the upper 96 bits.
                newOwner := shr(96, shl(96, newOwner))
                // Store the new value.
                sstore(_OWNER_SLOT, newOwner)
                // Emit the {OwnershipTransferred} event.
                log3(0, 0, _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE, 0, newOwner)
            }
        }
    }

    /// @dev Sets the owner directly without authorization guard.
    function _setOwner(address newOwner) internal virtual {
        if (_guardInitializeOwner()) {
            /// @solidity memory-safe-assembly
            assembly {
                let ownerSlot := _OWNER_SLOT
                // Clean the upper 96 bits.
                newOwner := shr(96, shl(96, newOwner))
                // Emit the {OwnershipTransferred} event.
                log3(0, 0, _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE, sload(ownerSlot), newOwner)
                // Store the new value.
                sstore(ownerSlot, or(newOwner, shl(255, iszero(newOwner))))
            }
        } else {
            /// @solidity memory-safe-assembly
            assembly {
                let ownerSlot := _OWNER_SLOT
                // Clean the upper 96 bits.
                newOwner := shr(96, shl(96, newOwner))
                // Emit the {OwnershipTransferred} event.
                log3(0, 0, _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE, sload(ownerSlot), newOwner)
                // Store the new value.
                sstore(ownerSlot, newOwner)
            }
        }
    }

    /// @dev Throws if the sender is not the owner.
    function _checkOwner() internal view virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // If the caller is not the stored owner, revert.
            if iszero(eq(caller(), sload(_OWNER_SLOT))) {
                mstore(0x00, 0x82b42900) // `Unauthorized()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Returns how long a two-step ownership handover is valid for in seconds.
    /// Override to return a different value if needed.
    /// Made internal to conserve bytecode. Wrap it in a public function if needed.
    function _ownershipHandoverValidFor() internal view virtual returns (uint64) {
        return 48 * 3600;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  PUBLIC UPDATE FUNCTIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Allows the owner to transfer the ownership to `newOwner`.
    function transferOwnership(address newOwner) public payable virtual onlyOwner {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(shl(96, newOwner)) {
                mstore(0x00, 0x7448fbae) // `NewOwnerIsZeroAddress()`.
                revert(0x1c, 0x04)
            }
        }
        _setOwner(newOwner);
    }

    /// @dev Allows the owner to renounce their ownership.
    function renounceOwnership() public payable virtual onlyOwner {
        _setOwner(address(0));
    }

    /// @dev Request a two-step ownership handover to the caller.
    /// The request will automatically expire in 48 hours (172800 seconds) by default.
    function requestOwnershipHandover() public payable virtual {
        unchecked {
            uint256 expires = block.timestamp + _ownershipHandoverValidFor();
            /// @solidity memory-safe-assembly
            assembly {
                // Compute and set the handover slot to `expires`.
                mstore(0x0c, _HANDOVER_SLOT_SEED)
                mstore(0x00, caller())
                sstore(keccak256(0x0c, 0x20), expires)
                // Emit the {OwnershipHandoverRequested} event.
                log2(0, 0, _OWNERSHIP_HANDOVER_REQUESTED_EVENT_SIGNATURE, caller())
            }
        }
    }

    /// @dev Cancels the two-step ownership handover to the caller, if any.
    function cancelOwnershipHandover() public payable virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute and set the handover slot to 0.
            mstore(0x0c, _HANDOVER_SLOT_SEED)
            mstore(0x00, caller())
            sstore(keccak256(0x0c, 0x20), 0)
            // Emit the {OwnershipHandoverCanceled} event.
            log2(0, 0, _OWNERSHIP_HANDOVER_CANCELED_EVENT_SIGNATURE, caller())
        }
    }

    /// @dev Allows the owner to complete the two-step ownership handover to `pendingOwner`.
    /// Reverts if there is no existing ownership handover requested by `pendingOwner`.
    function completeOwnershipHandover(address pendingOwner) public payable virtual onlyOwner {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute and set the handover slot to 0.
            mstore(0x0c, _HANDOVER_SLOT_SEED)
            mstore(0x00, pendingOwner)
            let handoverSlot := keccak256(0x0c, 0x20)
            // If the handover does not exist, or has expired.
            if gt(timestamp(), sload(handoverSlot)) {
                mstore(0x00, 0x6f5e8818) // `NoHandoverRequest()`.
                revert(0x1c, 0x04)
            }
            // Set the handover slot to 0.
            sstore(handoverSlot, 0)
        }
        _setOwner(pendingOwner);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   PUBLIC READ FUNCTIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the owner of the contract.
    function owner() public view virtual returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := sload(_OWNER_SLOT)
        }
    }

    /// @dev Returns the expiry timestamp for the two-step ownership handover to `pendingOwner`.
    function ownershipHandoverExpiresAt(address pendingOwner)
        public
        view
        virtual
        returns (uint256 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the handover slot.
            mstore(0x0c, _HANDOVER_SLOT_SEED)
            mstore(0x00, pendingOwner)
            // Load the handover slot.
            result := sload(keccak256(0x0c, 0x20))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         MODIFIERS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Marks a function as only callable by the owner.
    modifier onlyOwner() virtual {
        _checkOwner();
        _;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Initializable mixin for the upgradeable contracts.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/Initializable.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/tree/master/contracts/proxy/utils/Initializable.sol)
abstract contract Initializable {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The contract is already initialized.
    error InvalidInitialization();

    /// @dev The contract is not initializing.
    error NotInitializing();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Triggered when the contract has been initialized.
    event Initialized(uint64 version);

    /// @dev `keccak256(bytes("Initialized(uint64)"))`.
    bytes32 private constant _INTIALIZED_EVENT_SIGNATURE =
        0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The default initializable slot is given by:
    /// `bytes32(~uint256(uint32(bytes4(keccak256("_INITIALIZABLE_SLOT")))))`.
    ///
    /// Bits Layout:
    /// - [0]     `initializing`
    /// - [1..64] `initializedVersion`
    bytes32 private constant _INITIALIZABLE_SLOT =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffbf601132;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor() {
        // Construction time check to ensure that `_initializableSlot()` is not
        // overridden to zero. Will be optimized away if there is no revert.
        require(_initializableSlot() != bytes32(0));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         OPERATIONS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Override to return a non-zero custom storage slot if required.
    function _initializableSlot() internal pure virtual returns (bytes32) {
        return _INITIALIZABLE_SLOT;
    }

    /// @dev Guards an initializer function so that it can be invoked at most once.
    ///
    /// You can guard a function with `onlyInitializing` such that it can be called
    /// through a function guarded with `initializer`.
    ///
    /// This is similar to `reinitializer(1)`, except that in the context of a constructor,
    /// an `initializer` guarded function can be invoked multiple times.
    /// This can be useful during testing and is not expected to be used in production.
    ///
    /// Emits an {Initialized} event.
    modifier initializer() virtual {
        bytes32 s = _initializableSlot();
        /// @solidity memory-safe-assembly
        assembly {
            let i := sload(s)
            // Set `initializing` to 1, `initializedVersion` to 1.
            sstore(s, 3)
            // If `!(initializing == 0 && initializedVersion == 0)`.
            if i {
                // If `!(address(this).code.length == 0 && initializedVersion == 1)`.
                if iszero(lt(extcodesize(address()), eq(shr(1, i), 1))) {
                    mstore(0x00, 0xf92ee8a9) // `InvalidInitialization()`.
                    revert(0x1c, 0x04)
                }
                s := shl(shl(255, i), s) // Skip initializing if `initializing == 1`.
            }
        }
        _;
        /// @solidity memory-safe-assembly
        assembly {
            if s {
                // Set `initializing` to 0, `initializedVersion` to 1.
                sstore(s, 2)
                // Emit the {Initialized} event.
                mstore(0x20, 1)
                log1(0x20, 0x20, _INTIALIZED_EVENT_SIGNATURE)
            }
        }
    }

    /// @dev Guards an reinitialzer function so that it can be invoked at most once.
    ///
    /// You can guard a function with `onlyInitializing` such that it can be called
    /// through a function guarded with `reinitializer`.
    ///
    /// Emits an {Initialized} event.
    modifier reinitializer(uint64 version) virtual {
        bytes32 s = _initializableSlot();
        /// @solidity memory-safe-assembly
        assembly {
            // Clean upper bits, and shift left by 1 to make space for the initializing bit.
            version := shl(1, and(version, 0xffffffffffffffff))
            let i := sload(s)
            // If `initializing == 1 || initializedVersion >= version`.
            if iszero(lt(and(i, 1), lt(i, version))) {
                mstore(0x00, 0xf92ee8a9) // `InvalidInitialization()`.
                revert(0x1c, 0x04)
            }
            // Set `initializing` to 1, `initializedVersion` to `version`.
            sstore(s, or(1, version))
        }
        _;
        /// @solidity memory-safe-assembly
        assembly {
            // Set `initializing` to 0, `initializedVersion` to `version`.
            sstore(s, version)
            // Emit the {Initialized} event.
            mstore(0x20, shr(1, version))
            log1(0x20, 0x20, _INTIALIZED_EVENT_SIGNATURE)
        }
    }

    /// @dev Guards a function such that it can only be called in the scope
    /// of a function guarded with `initializer` or `reinitializer`.
    modifier onlyInitializing() virtual {
        _checkInitializing();
        _;
    }

    /// @dev Reverts if the contract is not initializing.
    function _checkInitializing() internal view virtual {
        bytes32 s = _initializableSlot();
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(and(1, sload(s))) {
                mstore(0x00, 0xd7e6bcf8) // `NotInitializing()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Locks any future initializations by setting the initialized version to `2**64 - 1`.
    ///
    /// Calling this in the constructor will prevent the contract from being initialized
    /// or reinitialized. It is recommended to use this to lock implementation contracts
    /// that are designed to be called through proxies.
    ///
    /// Emits an {Initialized} event the first time it is successfully called.
    function _disableInitializers() internal virtual {
        bytes32 s = _initializableSlot();
        /// @solidity memory-safe-assembly
        assembly {
            let i := sload(s)
            if and(i, 1) {
                mstore(0x00, 0xf92ee8a9) // `InvalidInitialization()`.
                revert(0x1c, 0x04)
            }
            let uint64max := 0xffffffffffffffff
            if iszero(eq(shr(1, i), uint64max)) {
                // Set `initializing` to 0, `initializedVersion` to `2**64 - 1`.
                sstore(s, shl(1, uint64max))
                // Emit the {Initialized} event.
                mstore(0x20, uint64max)
                log1(0x20, 0x20, _INTIALIZED_EVENT_SIGNATURE)
            }
        }
    }

    /// @dev Returns the highest version that has been initialized.
    function _getInitializedVersion() internal view virtual returns (uint64 version) {
        bytes32 s = _initializableSlot();
        /// @solidity memory-safe-assembly
        assembly {
            version := shr(1, sload(s))
        }
    }

    /// @dev Returns whether the contract is currently initializing.
    function _isInitializing() internal view virtual returns (bool result) {
        bytes32 s = _initializableSlot();
        /// @solidity memory-safe-assembly
        assembly {
            result := and(1, sload(s))
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC20} from "./ERC20.sol";
import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "../utils/SafeTransferLib.sol";

/// @notice Simple ERC4626 tokenized Vault implementation.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/tokens/ERC4626.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/mixins/ERC4626.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC4626.sol)
abstract contract ERC4626 is ERC20 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The default underlying decimals.
    uint8 internal constant _DEFAULT_UNDERLYING_DECIMALS = 18;

    /// @dev The default decimals offset.
    uint8 internal constant _DEFAULT_DECIMALS_OFFSET = 0;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Cannot deposit more than the max limit.
    error DepositMoreThanMax();

    /// @dev Cannot mint more than the max limit.
    error MintMoreThanMax();

    /// @dev Cannot withdraw more than the max limit.
    error WithdrawMoreThanMax();

    /// @dev Cannot redeem more than the max limit.
    error RedeemMoreThanMax();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Emitted during a mint call or deposit call.
    event Deposit(address indexed by, address indexed owner, uint256 assets, uint256 shares);

    /// @dev Emitted during a withdraw call or redeem call.
    event Withdraw(
        address indexed by,
        address indexed to,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /// @dev `keccak256(bytes("Deposit(address,address,uint256,uint256)"))`.
    uint256 private constant _DEPOSIT_EVENT_SIGNATURE =
        0xdcbc1c05240f31ff3ad067ef1ee35ce4997762752e3a095284754544f4c709d7;

    /// @dev `keccak256(bytes("Withdraw(address,address,address,uint256,uint256)"))`.
    uint256 private constant _WITHDRAW_EVENT_SIGNATURE =
        0xfbde797d201c681b91056529119e0b02407c7bb96a4a2c75c01fc9667232c8db;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     ERC4626 CONSTANTS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev To be overridden to return the address of the underlying asset.
    ///
    /// - MUST be an ERC20 token contract.
    /// - MUST NOT revert.
    function asset() public view virtual returns (address);

    /// @dev To be overridden to return the number of decimals of the underlying asset.
    /// Default: 18.
    ///
    /// - MUST NOT revert.
    function _underlyingDecimals() internal view virtual returns (uint8) {
        return _DEFAULT_UNDERLYING_DECIMALS;
    }

    /// @dev Override to return a non-zero value to make the inflation attack even more unfeasible.
    /// Only used when {_useVirtualShares} returns true.
    /// Default: 0.
    ///
    /// - MUST NOT revert.
    function _decimalsOffset() internal view virtual returns (uint8) {
        return _DEFAULT_DECIMALS_OFFSET;
    }

    /// @dev Returns whether virtual shares will be used to mitigate the inflation attack.
    /// See: https://github.com/OpenZeppelin/openzeppelin-contracts/issues/3706
    /// Override to return true or false.
    /// Default: true.
    ///
    /// - MUST NOT revert.
    function _useVirtualShares() internal view virtual returns (bool) {
        return true;
    }

    /// @dev Returns the decimals places of the token.
    ///
    /// - MUST NOT revert.
    function decimals() public view virtual override(ERC20) returns (uint8) {
        if (!_useVirtualShares()) return _underlyingDecimals();
        return _underlyingDecimals() + _decimalsOffset();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                ASSET DECIMALS GETTER HELPER                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Helper function to get the decimals of the underlying asset.
    /// Useful for setting the return value of `_underlyingDecimals` during initialization.
    /// If the retrieval succeeds, `success` will be true, and `result` will hold the result.
    /// Otherwise, `success` will be false, and `result` will be zero.
    ///
    /// Example usage:
    /// ```
    /// (bool success, uint8 result) = _tryGetAssetDecimals(underlying);
    /// _decimals = success ? result : _DEFAULT_UNDERLYING_DECIMALS;
    /// ```
    function _tryGetAssetDecimals(address underlying)
        internal
        view
        returns (bool success, uint8 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Store the function selector of `decimals()`.
            mstore(0x00, 0x313ce567)
            // Arguments are evaluated last to first.
            success :=
                and(
                    // Returned value is less than 256, at left-padded to 32 bytes.
                    and(lt(mload(0x00), 0x100), gt(returndatasize(), 0x1f)),
                    // The staticcall succeeds.
                    staticcall(gas(), underlying, 0x1c, 0x04, 0x00, 0x20)
                )
            result := mul(mload(0x00), success)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ACCOUNTING LOGIC                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the total amount of the underlying asset managed by the Vault.
    ///
    /// - SHOULD include any compounding that occurs from the yield.
    /// - MUST be inclusive of any fees that are charged against assets in the Vault.
    /// - MUST NOT revert.
    function totalAssets() public view virtual returns (uint256 assets) {
        assets = SafeTransferLib.balanceOf(asset(), address(this));
    }

    /// @dev Returns the amount of shares that the Vault will exchange for the amount of
    /// assets provided, in an ideal scenario where all conditions are met.
    ///
    /// - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
    /// - MUST NOT show any variations depending on the caller.
    /// - MUST NOT reflect slippage or other on-chain conditions, during the actual exchange.
    /// - MUST NOT revert.
    ///
    /// Note: This calculation MAY NOT reflect the "per-user" price-per-share, and instead
    /// should reflect the "average-user's" price-per-share, i.e. what the average user should
    /// expect to see when exchanging to and from.
    function convertToShares(uint256 assets) public view virtual returns (uint256 shares) {
        if (!_useVirtualShares()) {
            uint256 supply = totalSupply();
            return _eitherIsZero(assets, supply)
                ? _initialConvertToShares(assets)
                : FixedPointMathLib.fullMulDiv(assets, supply, totalAssets());
        }
        uint256 o = _decimalsOffset();
        if (o == uint256(0)) {
            return FixedPointMathLib.fullMulDiv(assets, totalSupply() + 1, _inc(totalAssets()));
        }
        return FixedPointMathLib.fullMulDiv(assets, totalSupply() + 10 ** o, _inc(totalAssets()));
    }

    /// @dev Returns the amount of assets that the Vault will exchange for the amount of
    /// shares provided, in an ideal scenario where all conditions are met.
    ///
    /// - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
    /// - MUST NOT show any variations depending on the caller.
    /// - MUST NOT reflect slippage or other on-chain conditions, during the actual exchange.
    /// - MUST NOT revert.
    ///
    /// Note: This calculation MAY NOT reflect the "per-user" price-per-share, and instead
    /// should reflect the "average-user's" price-per-share, i.e. what the average user should
    /// expect to see when exchanging to and from.
    function convertToAssets(uint256 shares) public view virtual returns (uint256 assets) {
        if (!_useVirtualShares()) {
            uint256 supply = totalSupply();
            return supply == uint256(0)
                ? _initialConvertToAssets(shares)
                : FixedPointMathLib.fullMulDiv(shares, totalAssets(), supply);
        }
        uint256 o = _decimalsOffset();
        if (o == uint256(0)) {
            return FixedPointMathLib.fullMulDiv(shares, totalAssets() + 1, _inc(totalSupply()));
        }
        return FixedPointMathLib.fullMulDiv(shares, totalAssets() + 1, totalSupply() + 10 ** o);
    }

    /// @dev Allows an on-chain or off-chain user to simulate the effects of their deposit
    /// at the current block, given current on-chain conditions.
    ///
    /// - MUST return as close to and no more than the exact amount of Vault shares that
    ///   will be minted in a deposit call in the same transaction, i.e. deposit should
    ///   return the same or more shares as `previewDeposit` if call in the same transaction.
    /// - MUST NOT account for deposit limits like those returned from `maxDeposit` and should
    ///   always act as if the deposit will be accepted, regardless of approvals, etc.
    /// - MUST be inclusive of deposit fees. Integrators should be aware of this.
    /// - MUST not revert.
    ///
    /// Note: Any unfavorable discrepancy between `convertToShares` and `previewDeposit` SHOULD
    /// be considered slippage in share price or some other type of condition, meaning
    /// the depositor will lose assets by depositing.
    function previewDeposit(uint256 assets) public view virtual returns (uint256 shares) {
        shares = convertToShares(assets);
    }

    /// @dev Allows an on-chain or off-chain user to simulate the effects of their mint
    /// at the current block, given current on-chain conditions.
    ///
    /// - MUST return as close to and no fewer than the exact amount of assets that
    ///   will be deposited in a mint call in the same transaction, i.e. mint should
    ///   return the same or fewer assets as `previewMint` if called in the same transaction.
    /// - MUST NOT account for mint limits like those returned from `maxMint` and should
    ///   always act as if the mint will be accepted, regardless of approvals, etc.
    /// - MUST be inclusive of deposit fees. Integrators should be aware of this.
    /// - MUST not revert.
    ///
    /// Note: Any unfavorable discrepancy between `convertToAssets` and `previewMint` SHOULD
    /// be considered slippage in share price or some other type of condition,
    /// meaning the depositor will lose assets by minting.
    function previewMint(uint256 shares) public view virtual returns (uint256 assets) {
        if (!_useVirtualShares()) {
            uint256 supply = totalSupply();
            return supply == uint256(0)
                ? _initialConvertToAssets(shares)
                : FixedPointMathLib.fullMulDivUp(shares, totalAssets(), supply);
        }
        uint256 o = _decimalsOffset();
        if (o == uint256(0)) {
            return FixedPointMathLib.fullMulDivUp(shares, totalAssets() + 1, _inc(totalSupply()));
        }
        return FixedPointMathLib.fullMulDivUp(shares, totalAssets() + 1, totalSupply() + 10 ** o);
    }

    /// @dev Allows an on-chain or off-chain user to simulate the effects of their withdrawal
    /// at the current block, given the current on-chain conditions.
    ///
    /// - MUST return as close to and no fewer than the exact amount of Vault shares that
    ///   will be burned in a withdraw call in the same transaction, i.e. withdraw should
    ///   return the same or fewer shares as `previewWithdraw` if call in the same transaction.
    /// - MUST NOT account for withdrawal limits like those returned from `maxWithdraw` and should
    ///   always act as if the withdrawal will be accepted, regardless of share balance, etc.
    /// - MUST be inclusive of withdrawal fees. Integrators should be aware of this.
    /// - MUST not revert.
    ///
    /// Note: Any unfavorable discrepancy between `convertToShares` and `previewWithdraw` SHOULD
    /// be considered slippage in share price or some other type of condition,
    /// meaning the depositor will lose assets by depositing.
    function previewWithdraw(uint256 assets) public view virtual returns (uint256 shares) {
        if (!_useVirtualShares()) {
            uint256 supply = totalSupply();
            return _eitherIsZero(assets, supply)
                ? _initialConvertToShares(assets)
                : FixedPointMathLib.fullMulDivUp(assets, supply, totalAssets());
        }
        uint256 o = _decimalsOffset();
        if (o == uint256(0)) {
            return FixedPointMathLib.fullMulDivUp(assets, totalSupply() + 1, _inc(totalAssets()));
        }
        return FixedPointMathLib.fullMulDivUp(assets, totalSupply() + 10 ** o, _inc(totalAssets()));
    }

    /// @dev Allows an on-chain or off-chain user to simulate the effects of their redemption
    /// at the current block, given current on-chain conditions.
    ///
    /// - MUST return as close to and no more than the exact amount of assets that
    ///   will be withdrawn in a redeem call in the same transaction, i.e. redeem should
    ///   return the same or more assets as `previewRedeem` if called in the same transaction.
    /// - MUST NOT account for redemption limits like those returned from `maxRedeem` and should
    ///   always act as if the redemption will be accepted, regardless of approvals, etc.
    /// - MUST be inclusive of withdrawal fees. Integrators should be aware of this.
    /// - MUST NOT revert.
    ///
    /// Note: Any unfavorable discrepancy between `convertToAssets` and `previewRedeem` SHOULD
    /// be considered slippage in share price or some other type of condition,
    /// meaning the depositor will lose assets by depositing.
    function previewRedeem(uint256 shares) public view virtual returns (uint256 assets) {
        assets = convertToAssets(shares);
    }

    /// @dev Private helper to return if either value is zero.
    function _eitherIsZero(uint256 a, uint256 b) private pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := or(iszero(a), iszero(b))
        }
    }

    /// @dev Private helper to return `x + 1` without the overflow check.
    /// Used for computing the denominator input to `FixedPointMathLib.fullMulDiv(a, b, x + 1)`.
    /// When `x == type(uint256).max`, we get `x + 1 == 0` (mod 2**256 - 1),
    /// and `FixedPointMathLib.fullMulDiv` will revert as the denominator is zero.
    function _inc(uint256 x) private pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*              DEPOSIT / WITHDRAWAL LIMIT LOGIC              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the maximum amount of the underlying asset that can be deposited
    /// into the Vault for `to`, via a deposit call.
    ///
    /// - MUST return a limited value if `to` is subject to some deposit limit.
    /// - MUST return `2**256-1` if there is no maximum limit.
    /// - MUST NOT revert.
    function maxDeposit(address to) public view virtual returns (uint256 maxAssets) {
        to = to; // Silence unused variable warning.
        maxAssets = type(uint256).max;
    }

    /// @dev Returns the maximum amount of the Vault shares that can be minter for `to`,
    /// via a mint call.
    ///
    /// - MUST return a limited value if `to` is subject to some mint limit.
    /// - MUST return `2**256-1` if there is no maximum limit.
    /// - MUST NOT revert.
    function maxMint(address to) public view virtual returns (uint256 maxShares) {
        to = to; // Silence unused variable warning.
        maxShares = type(uint256).max;
    }

    /// @dev Returns the maximum amount of the underlying asset that can be withdrawn
    /// from the `owner`'s balance in the Vault, via a withdraw call.
    ///
    /// - MUST return a limited value if `owner` is subject to some withdrawal limit or timelock.
    /// - MUST NOT revert.
    function maxWithdraw(address owner) public view virtual returns (uint256 maxAssets) {
        maxAssets = convertToAssets(balanceOf(owner));
    }

    /// @dev Returns the maximum amount of Vault shares that can be redeemed
    /// from the `owner`'s balance in the Vault, via a redeem call.
    ///
    /// - MUST return a limited value if `owner` is subject to some withdrawal limit or timelock.
    /// - MUST return `balanceOf(owner)` otherwise.
    /// - MUST NOT revert.
    function maxRedeem(address owner) public view virtual returns (uint256 maxShares) {
        maxShares = balanceOf(owner);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 DEPOSIT / WITHDRAWAL LOGIC                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Mints `shares` Vault shares to `to` by depositing exactly `assets`
    /// of underlying tokens.
    ///
    /// - MUST emit the {Deposit} event.
    /// - MAY support an additional flow in which the underlying tokens are owned by the Vault
    ///   contract before the deposit execution, and are accounted for during deposit.
    /// - MUST revert if all of `assets` cannot be deposited, such as due to deposit limit,
    ///   slippage, insufficient approval, etc.
    ///
    /// Note: Most implementations will require pre-approval of the Vault with the
    /// Vault's underlying `asset` token.
    function deposit(uint256 assets, address to) public virtual returns (uint256 shares) {
        if (assets > maxDeposit(to)) _revert(0xb3c61a83); // `DepositMoreThanMax()`.
        shares = previewDeposit(assets);
        _deposit(msg.sender, to, assets, shares);
    }

    /// @dev Mints exactly `shares` Vault shares to `to` by depositing `assets`
    /// of underlying tokens.
    ///
    /// - MUST emit the {Deposit} event.
    /// - MAY support an additional flow in which the underlying tokens are owned by the Vault
    ///   contract before the mint execution, and are accounted for during mint.
    /// - MUST revert if all of `shares` cannot be deposited, such as due to deposit limit,
    ///   slippage, insufficient approval, etc.
    ///
    /// Note: Most implementations will require pre-approval of the Vault with the
    /// Vault's underlying `asset` token.
    function mint(uint256 shares, address to) public virtual returns (uint256 assets) {
        if (shares > maxMint(to)) _revert(0x6a695959); // `MintMoreThanMax()`.
        assets = previewMint(shares);
        _deposit(msg.sender, to, assets, shares);
    }

    /// @dev Burns `shares` from `owner` and sends exactly `assets` of underlying tokens to `to`.
    ///
    /// - MUST emit the {Withdraw} event.
    /// - MAY support an additional flow in which the underlying tokens are owned by the Vault
    ///   contract before the withdraw execution, and are accounted for during withdraw.
    /// - MUST revert if all of `assets` cannot be withdrawn, such as due to withdrawal limit,
    ///   slippage, insufficient balance, etc.
    ///
    /// Note: Some implementations will require pre-requesting to the Vault before a withdrawal
    /// may be performed. Those methods should be performed separately.
    function withdraw(uint256 assets, address to, address owner)
        public
        virtual
        returns (uint256 shares)
    {
        if (assets > maxWithdraw(owner)) _revert(0x936941fc); // `WithdrawMoreThanMax()`.
        shares = previewWithdraw(assets);
        _withdraw(msg.sender, to, owner, assets, shares);
    }

    /// @dev Burns exactly `shares` from `owner` and sends `assets` of underlying tokens to `to`.
    ///
    /// - MUST emit the {Withdraw} event.
    /// - MAY support an additional flow in which the underlying tokens are owned by the Vault
    ///   contract before the redeem execution, and are accounted for during redeem.
    /// - MUST revert if all of shares cannot be redeemed, such as due to withdrawal limit,
    ///   slippage, insufficient balance, etc.
    ///
    /// Note: Some implementations will require pre-requesting to the Vault before a redeem
    /// may be performed. Those methods should be performed separately.
    function redeem(uint256 shares, address to, address owner)
        public
        virtual
        returns (uint256 assets)
    {
        if (shares > maxRedeem(owner)) _revert(0x4656425a); // `RedeemMoreThanMax()`.
        assets = previewRedeem(shares);
        _withdraw(msg.sender, to, owner, assets, shares);
    }

    /// @dev Internal helper for reverting efficiently.
    function _revert(uint256 s) private pure {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, s)
            revert(0x1c, 0x04)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      INTERNAL HELPERS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev For deposits and mints.
    ///
    /// Emits a {Deposit} event.
    function _deposit(address by, address to, uint256 assets, uint256 shares) internal virtual {
        SafeTransferLib.safeTransferFrom(asset(), by, address(this), assets);
        _mint(to, shares);
        /// @solidity memory-safe-assembly
        assembly {
            // Emit the {Deposit} event.
            mstore(0x00, assets)
            mstore(0x20, shares)
            let m := shr(96, not(0))
            log3(0x00, 0x40, _DEPOSIT_EVENT_SIGNATURE, and(m, by), and(m, to))
        }
        _afterDeposit(assets, shares);
    }

    /// @dev For withdrawals and redemptions.
    ///
    /// Emits a {Withdraw} event.
    function _withdraw(address by, address to, address owner, uint256 assets, uint256 shares)
        internal
        virtual
    {
        if (by != owner) _spendAllowance(owner, by, shares);
        _beforeWithdraw(assets, shares);
        _burn(owner, shares);
        SafeTransferLib.safeTransfer(asset(), to, assets);
        /// @solidity memory-safe-assembly
        assembly {
            // Emit the {Withdraw} event.
            mstore(0x00, assets)
            mstore(0x20, shares)
            let m := shr(96, not(0))
            log4(0x00, 0x40, _WITHDRAW_EVENT_SIGNATURE, and(m, by), and(m, to), and(m, owner))
        }
    }

    /// @dev Internal conversion function (from assets to shares) to apply when the Vault is empty.
    /// Only used when {_useVirtualShares} returns false.
    ///
    /// Note: Make sure to keep this function consistent with {_initialConvertToAssets}
    /// when overriding it.
    function _initialConvertToShares(uint256 assets)
        internal
        view
        virtual
        returns (uint256 shares)
    {
        shares = assets;
    }

    /// @dev Internal conversion function (from shares to assets) to apply when the Vault is empty.
    /// Only used when {_useVirtualShares} returns false.
    ///
    /// Note: Make sure to keep this function consistent with {_initialConvertToShares}
    /// when overriding it.
    function _initialConvertToAssets(uint256 shares)
        internal
        view
        virtual
        returns (uint256 assets)
    {
        assets = shares;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     HOOKS TO OVERRIDE                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Hook that is called before any withdrawal or redemption.
    function _beforeWithdraw(uint256 assets, uint256 shares) internal virtual {}

    /// @dev Hook that is called after any deposit or mint.
    function _afterDeposit(uint256 assets, uint256 shares) internal virtual {}
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {ERC20} from "solady/src/tokens/ERC20.sol";

import "../types/TwoCrypto.sol";
import {LibTwoCryptoNG} from "../utils/LibTwoCryptoNG.sol";

/// @notice Helper functions for TwoCrypto. This library is not meant to ever actually be called from on-chain, used from off-chain because of intensive gas cost.
library TwoCryptoNGPreviewLib {
    using LibTwoCryptoNG for TwoCrypto;

    error TwoCryptoNGPreviewLib_SolutionNotFound();

    /// @notice Maximal number of iterations in the binary search algorithm
    uint256 private constant MAX_ITERATIONS_BINSEARCH = 255;

    /**
     * @param twoCrypto : PT/YBT curve pool
     * @param i token index of token to provide
     * @param j token index of token to receive
     * @param targetDy amount out desired token `j`
     * @return dx The amount of token to provide in order to obtain targetDy after swap
     */
    function binsearch_dx(TwoCrypto twoCrypto, uint256 i, uint256 j, uint256 targetDy)
        internal
        view
        returns (uint256)
    {
        if (targetDy == 0) return 0;

        // Initial guesses: with PT/underlying token is 1
        uint256 initialDxGuess =
            convertTokenAmount(targetDy, ERC20(twoCrypto.coins(j)).decimals(), ERC20(twoCrypto.coins(i)).decimals());
        uint256 initialDy = twoCrypto.get_dy(i, j, initialDxGuess);
        return binsearch_dx_with_initial_guess(
            BinSearchInput({
                twoCrypto: twoCrypto,
                i: i,
                j: j,
                targetDy: targetDy,
                initialDxGuess: initialDxGuess,
                initialDy: initialDy
            })
        );
    }

    /// @dev Workaround for stack too deep error
    struct BinSearchInput {
        TwoCrypto twoCrypto;
        uint256 i;
        uint256 j;
        uint256 targetDy;
        uint256 initialDxGuess;
        uint256 initialDy;
    }

    function binsearch_dx_with_initial_guess(BinSearchInput memory input) private view returns (uint256) {
        // bounds should be in dx as we want our solution, the bisection of this interval, to be in dx
        uint256 lowerDx = type(uint256).max; // lower bound
        uint256 upperDx = type(uint256).max; // upper bound
        uint256 factor100;

        uint256 midDx = input.initialDxGuess;
        if (input.initialDy > input.targetDy) {
            // we overshot (target < initialDy), can set an upper bound
            upperDx = midDx;
            factor100 = 10;
        } else {
            // we undershot (initialDy <= targetDy), can set a lower bound
            lowerDx = midDx;
            factor100 = 1000;
        }

        uint256 iterations;
        while (true) {
            iterations++;

            // as long as the other bound is uninitialized, find bounds first by scaling in the direction of the uninitialzied bound.
            if (lowerDx == type(uint256).max || upperDx == type(uint256).max) {
                midDx = (midDx * factor100) / 100;
            } else {
                midDx = (lowerDx + upperDx) >> 1;
            }

            uint256 midDy = input.twoCrypto.get_dy(input.i, input.j, midDx);

            // Narrow down the interval based on the comparison
            if (midDy < input.targetDy) {
                lowerDx = midDx;
            } else {
                upperDx = midDx;
            }

            // If the midDx is a solution, break
            if (_hasConverged(input.twoCrypto, input.i, input.j, midDx, midDy, input.targetDy)) {
                break;
            }

            if (iterations >= MAX_ITERATIONS_BINSEARCH) {
                revert TwoCryptoNGPreviewLib_SolutionNotFound();
            }
        }
        return midDx;
    }

    /**
     * @dev Returns true if algorithm converged
     * @param twoCrypto PT/YBT curve pool
     * @param i token index, either 0 or 1
     * @param j token index, either 0 or 1, must be different than i
     * @param midDx The current guess for the `dx` value that is being refined through the search process.
     * @param midDy The output of the `get_dy` function for the current guess. `get_dy(i, j, midDx)`
     * @param targetDy The target output of the `get_dy` function, which the search aims to achieve by adjusting `dx`.
     * @return true if the solution to the search problem was found, false otherwise
     */
    function _hasConverged(TwoCrypto twoCrypto, uint256 i, uint256 j, uint256 midDx, uint256 midDy, uint256 targetDy)
        internal
        view
        returns (bool)
    {
        if (midDy == targetDy) return true; // Obvious solution

        uint256 dyNext = twoCrypto.get_dy(i, j, midDx + 1);
        return (midDy < targetDy && targetDy < dyNext);
    }

    /// @notice Convert amount of token A to amount of token B
    function convertTokenAmount(uint256 amountA, uint8 decimalsA, uint8 decimalsB) internal pure returns (uint256) {
        if (decimalsA > decimalsB) {
            return amountA / (10 ** (decimalsA - decimalsB));
        } else {
            return amountA * (10 ** (decimalsB - decimalsA));
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../Types.sol";
import {IRewardProxy} from "../interfaces/IRewardProxy.sol";
import {PrincipalToken} from "../tokens/PrincipalToken.sol";

library RewardLensLib {
    /// @notice Get the reward tokens for a given principal token
    function getRewardTokens(PrincipalToken pt) internal view returns (address[] memory tokens) {
        // RewardProxy is optional, so we need to try-catch.
        try pt.i_factory().moduleFor(address(pt), REWARD_PROXY_MODULE_INDEX) returns (address rewardProxy) {
            tokens = IRewardProxy(rewardProxy).rewardTokens();
        } catch {}
    }

    /// @notice Get the rewards for a given account
    function getTokenRewards(PrincipalToken pt, address account) internal view returns (TokenReward[] memory rewards) {
        address[] memory tokens = getRewardTokens(pt);
        rewards = new TokenReward[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            rewards[i] = TokenReward({token: tokens[i], amount: pt.getUserReward(tokens[i], account).accrued});
        }
    }

    /// @notice Get the curator and protocol fee rewards for a given principal token
    function getFeeRewards(PrincipalToken pt)
        internal
        view
        returns (TokenReward[] memory curatorFeeRewards, TokenReward[] memory protocolFeeRewards)
    {
        address[] memory rewardTokens = getRewardTokens(pt);
        curatorFeeRewards = new TokenReward[](rewardTokens.length);
        protocolFeeRewards = new TokenReward[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            (uint256 curatorRewards, uint256 protocolRewards) = pt.getFeeRewards(rewardTokens[i]);
            curatorFeeRewards[i] = TokenReward({token: rewardTokens[i], amount: curatorRewards});
            protocolFeeRewards[i] = TokenReward({token: rewardTokens[i], amount: protocolRewards});
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {TwoCrypto} from "../Types.sol";

function unwrap(TwoCrypto x) pure returns (address result) {
    result = TwoCrypto.unwrap(x);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for byte related operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibBytes.sol)
library LibBytes {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Goated bytes storage struct that totally MOGs, no cap, fr.
    /// Uses less gas and bytecode than Solidity's native bytes storage. It's meta af.
    /// Packs length with the first 31 bytes if <255 bytes, so it’s mad tight.
    struct BytesStorage {
        bytes32 _spacer;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The constant returned when the `search` is not found in the bytes.
    uint256 internal constant NOT_FOUND = type(uint256).max;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  BYTE STORAGE OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Sets the value of the bytes storage `$` to `s`.
    function set(BytesStorage storage $, bytes memory s) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(s)
            let packed := or(0xff, shl(8, n))
            for { let i := 0 } 1 {} {
                if iszero(gt(n, 0xfe)) {
                    i := 0x1f
                    packed := or(n, shl(8, mload(add(s, i))))
                    if iszero(gt(n, i)) { break }
                }
                let o := add(s, 0x20)
                mstore(0x00, $.slot)
                for { let p := keccak256(0x00, 0x20) } 1 {} {
                    sstore(add(p, shr(5, i)), mload(add(o, i)))
                    i := add(i, 0x20)
                    if iszero(lt(i, n)) { break }
                }
                break
            }
            sstore($.slot, packed)
        }
    }

    /// @dev Sets the value of the bytes storage `$` to `s`.
    function setCalldata(BytesStorage storage $, bytes calldata s) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let packed := or(0xff, shl(8, s.length))
            for { let i := 0 } 1 {} {
                if iszero(gt(s.length, 0xfe)) {
                    i := 0x1f
                    packed := or(s.length, shl(8, shr(8, calldataload(s.offset))))
                    if iszero(gt(s.length, i)) { break }
                }
                mstore(0x00, $.slot)
                for { let p := keccak256(0x00, 0x20) } 1 {} {
                    sstore(add(p, shr(5, i)), calldataload(add(s.offset, i)))
                    i := add(i, 0x20)
                    if iszero(lt(i, s.length)) { break }
                }
                break
            }
            sstore($.slot, packed)
        }
    }

    /// @dev Sets the value of the bytes storage `$` to the empty bytes.
    function clear(BytesStorage storage $) internal {
        delete $._spacer;
    }

    /// @dev Returns whether the value stored is `$` is the empty bytes "".
    function isEmpty(BytesStorage storage $) internal view returns (bool) {
        return uint256($._spacer) & 0xff == uint256(0);
    }

    /// @dev Returns the length of the value stored in `$`.
    function length(BytesStorage storage $) internal view returns (uint256 result) {
        result = uint256($._spacer);
        /// @solidity memory-safe-assembly
        assembly {
            let n := and(0xff, result)
            result := or(mul(shr(8, result), eq(0xff, n)), mul(n, iszero(eq(0xff, n))))
        }
    }

    /// @dev Returns the value stored in `$`.
    function get(BytesStorage storage $) internal view returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let o := add(result, 0x20)
            let packed := sload($.slot)
            let n := shr(8, packed)
            for { let i := 0 } 1 {} {
                if iszero(eq(or(packed, 0xff), packed)) {
                    mstore(o, packed)
                    n := and(0xff, packed)
                    i := 0x1f
                    if iszero(gt(n, i)) { break }
                }
                mstore(0x00, $.slot)
                for { let p := keccak256(0x00, 0x20) } 1 {} {
                    mstore(add(o, i), sload(add(p, shr(5, i))))
                    i := add(i, 0x20)
                    if iszero(lt(i, n)) { break }
                }
                break
            }
            mstore(result, n) // Store the length of the memory.
            mstore(add(o, n), 0) // Zeroize the slot after the bytes.
            mstore(0x40, add(add(o, n), 0x20)) // Allocate memory.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      BYTES OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns `subject` all occurrences of `needle` replaced with `replacement`.
    function replace(bytes memory subject, bytes memory needle, bytes memory replacement)
        internal
        pure
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let needleLen := mload(needle)
            let replacementLen := mload(replacement)
            let d := sub(result, subject) // Memory difference.
            let i := add(subject, 0x20) // Subject bytes pointer.
            mstore(0x00, add(i, mload(subject))) // End of subject.
            if iszero(gt(needleLen, mload(subject))) {
                let subjectSearchEnd := add(sub(mload(0x00), needleLen), 1)
                let h := 0 // The hash of `needle`.
                if iszero(lt(needleLen, 0x20)) { h := keccak256(add(needle, 0x20), needleLen) }
                let s := mload(add(needle, 0x20))
                for { let m := shl(3, sub(0x20, and(needleLen, 0x1f))) } 1 {} {
                    let t := mload(i)
                    // Whether the first `needleLen % 32` bytes of `subject` and `needle` matches.
                    if iszero(shr(m, xor(t, s))) {
                        if h {
                            if iszero(eq(keccak256(i, needleLen), h)) {
                                mstore(add(i, d), t)
                                i := add(i, 1)
                                if iszero(lt(i, subjectSearchEnd)) { break }
                                continue
                            }
                        }
                        // Copy the `replacement` one word at a time.
                        for { let j := 0 } 1 {} {
                            mstore(add(add(i, d), j), mload(add(add(replacement, 0x20), j)))
                            j := add(j, 0x20)
                            if iszero(lt(j, replacementLen)) { break }
                        }
                        d := sub(add(d, replacementLen), needleLen)
                        if needleLen {
                            i := add(i, needleLen)
                            if iszero(lt(i, subjectSearchEnd)) { break }
                            continue
                        }
                    }
                    mstore(add(i, d), t)
                    i := add(i, 1)
                    if iszero(lt(i, subjectSearchEnd)) { break }
                }
            }
            let end := mload(0x00)
            let n := add(sub(d, add(result, 0x20)), end)
            // Copy the rest of the bytes one word at a time.
            for {} lt(i, end) { i := add(i, 0x20) } { mstore(add(i, d), mload(i)) }
            let o := add(i, d)
            mstore(o, 0) // Zeroize the slot after the bytes.
            mstore(0x40, add(o, 0x20)) // Allocate memory.
            mstore(result, n) // Store the length.
        }
    }

    /// @dev Returns the byte index of the first location of `needle` in `subject`,
    /// needleing from left to right, starting from `from`.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `needle` is not found.
    function indexOf(bytes memory subject, bytes memory needle, uint256 from)
        internal
        pure
        returns (uint256 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := not(0) // Initialize to `NOT_FOUND`.
            for { let subjectLen := mload(subject) } 1 {} {
                if iszero(mload(needle)) {
                    result := from
                    if iszero(gt(from, subjectLen)) { break }
                    result := subjectLen
                    break
                }
                let needleLen := mload(needle)
                let subjectStart := add(subject, 0x20)

                subject := add(subjectStart, from)
                let end := add(sub(add(subjectStart, subjectLen), needleLen), 1)
                let m := shl(3, sub(0x20, and(needleLen, 0x1f)))
                let s := mload(add(needle, 0x20))

                if iszero(and(lt(subject, end), lt(from, subjectLen))) { break }

                if iszero(lt(needleLen, 0x20)) {
                    for { let h := keccak256(add(needle, 0x20), needleLen) } 1 {} {
                        if iszero(shr(m, xor(mload(subject), s))) {
                            if eq(keccak256(subject, needleLen), h) {
                                result := sub(subject, subjectStart)
                                break
                            }
                        }
                        subject := add(subject, 1)
                        if iszero(lt(subject, end)) { break }
                    }
                    break
                }
                for {} 1 {} {
                    if iszero(shr(m, xor(mload(subject), s))) {
                        result := sub(subject, subjectStart)
                        break
                    }
                    subject := add(subject, 1)
                    if iszero(lt(subject, end)) { break }
                }
                break
            }
        }
    }

    /// @dev Returns the byte index of the first location of `needle` in `subject`,
    /// needleing from left to right.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `needle` is not found.
    function indexOf(bytes memory subject, bytes memory needle) internal pure returns (uint256) {
        return indexOf(subject, needle, 0);
    }

    /// @dev Returns the byte index of the first location of `needle` in `subject`,
    /// needleing from right to left, starting from `from`.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `needle` is not found.
    function lastIndexOf(bytes memory subject, bytes memory needle, uint256 from)
        internal
        pure
        returns (uint256 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            for {} 1 {} {
                result := not(0) // Initialize to `NOT_FOUND`.
                let needleLen := mload(needle)
                if gt(needleLen, mload(subject)) { break }
                let w := result

                let fromMax := sub(mload(subject), needleLen)
                if iszero(gt(fromMax, from)) { from := fromMax }

                let end := add(add(subject, 0x20), w)
                subject := add(add(subject, 0x20), from)
                if iszero(gt(subject, end)) { break }
                // As this function is not too often used,
                // we shall simply use keccak256 for smaller bytecode size.
                for { let h := keccak256(add(needle, 0x20), needleLen) } 1 {} {
                    if eq(keccak256(subject, needleLen), h) {
                        result := sub(subject, add(end, 1))
                        break
                    }
                    subject := add(subject, w) // `sub(subject, 1)`.
                    if iszero(gt(subject, end)) { break }
                }
                break
            }
        }
    }

    /// @dev Returns the byte index of the first location of `needle` in `subject`,
    /// needleing from right to left.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `needle` is not found.
    function lastIndexOf(bytes memory subject, bytes memory needle)
        internal
        pure
        returns (uint256)
    {
        return lastIndexOf(subject, needle, type(uint256).max);
    }

    /// @dev Returns true if `needle` is found in `subject`, false otherwise.
    function contains(bytes memory subject, bytes memory needle) internal pure returns (bool) {
        return indexOf(subject, needle) != NOT_FOUND;
    }

    /// @dev Returns whether `subject` starts with `needle`.
    function startsWith(bytes memory subject, bytes memory needle)
        internal
        pure
        returns (bool result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(needle)
            // Just using keccak256 directly is actually cheaper.
            let t := eq(keccak256(add(subject, 0x20), n), keccak256(add(needle, 0x20), n))
            result := lt(gt(n, mload(subject)), t)
        }
    }

    /// @dev Returns whether `subject` ends with `needle`.
    function endsWith(bytes memory subject, bytes memory needle)
        internal
        pure
        returns (bool result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(needle)
            let notInRange := gt(n, mload(subject))
            // `subject + 0x20 + max(subject.length - needle.length, 0)`.
            let t := add(add(subject, 0x20), mul(iszero(notInRange), sub(mload(subject), n)))
            // Just using keccak256 directly is actually cheaper.
            result := gt(eq(keccak256(t, n), keccak256(add(needle, 0x20), n)), notInRange)
        }
    }

    /// @dev Returns `subject` repeated `times`.
    function repeat(bytes memory subject, uint256 times)
        internal
        pure
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let l := mload(subject) // Subject length.
            if iszero(or(iszero(times), iszero(l))) {
                result := mload(0x40)
                subject := add(subject, 0x20)
                let o := add(result, 0x20)
                for {} 1 {} {
                    // Copy the `subject` one word at a time.
                    for { let j := 0 } 1 {} {
                        mstore(add(o, j), mload(add(subject, j)))
                        j := add(j, 0x20)
                        if iszero(lt(j, l)) { break }
                    }
                    o := add(o, l)
                    times := sub(times, 1)
                    if iszero(times) { break }
                }
                mstore(o, 0) // Zeroize the slot after the bytes.
                mstore(0x40, add(o, 0x20)) // Allocate memory.
                mstore(result, sub(o, add(result, 0x20))) // Store the length.
            }
        }
    }

    /// @dev Returns a copy of `subject` sliced from `start` to `end` (exclusive).
    /// `start` and `end` are byte offsets.
    function slice(bytes memory subject, uint256 start, uint256 end)
        internal
        pure
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let l := mload(subject) // Subject length.
            if iszero(gt(l, end)) { end := l }
            if iszero(gt(l, start)) { start := l }
            if lt(start, end) {
                result := mload(0x40)
                let n := sub(end, start)
                let i := add(subject, start)
                let w := not(0x1f)
                // Copy the `subject` one word at a time, backwards.
                for { let j := and(add(n, 0x1f), w) } 1 {} {
                    mstore(add(result, j), mload(add(i, j)))
                    j := add(j, w) // `sub(j, 0x20)`.
                    if iszero(j) { break }
                }
                let o := add(add(result, 0x20), n)
                mstore(o, 0) // Zeroize the slot after the bytes.
                mstore(0x40, add(o, 0x20)) // Allocate memory.
                mstore(result, n) // Store the length.
            }
        }
    }

    /// @dev Returns a copy of `subject` sliced from `start` to the end of the bytes.
    /// `start` is a byte offset.
    function slice(bytes memory subject, uint256 start)
        internal
        pure
        returns (bytes memory result)
    {
        result = slice(subject, start, type(uint256).max);
    }

    /// @dev Returns a copy of `subject` sliced from `start` to `end` (exclusive).
    /// `start` and `end` are byte offsets. Faster than Solidity's native slicing.
    function sliceCalldata(bytes calldata subject, uint256 start, uint256 end)
        internal
        pure
        returns (bytes calldata result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            end := xor(end, mul(xor(end, subject.length), lt(subject.length, end)))
            start := xor(start, mul(xor(start, subject.length), lt(subject.length, start)))
            result.offset := add(subject.offset, start)
            result.length := mul(lt(start, end), sub(end, start))
        }
    }

    /// @dev Returns a copy of `subject` sliced from `start` to the end of the bytes.
    /// `start` is a byte offset. Faster than Solidity's native slicing.
    function sliceCalldata(bytes calldata subject, uint256 start)
        internal
        pure
        returns (bytes calldata result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            start := xor(start, mul(xor(start, subject.length), lt(subject.length, start)))
            result.offset := add(subject.offset, start)
            result.length := mul(lt(start, subject.length), sub(subject.length, start))
        }
    }

    /// @dev Reduces the size of `subject` to `n`.
    /// If `n` is greater than the size of `subject`, this will be a no-op.
    function truncate(bytes memory subject, uint256 n)
        internal
        pure
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := subject
            mstore(mul(lt(n, mload(result)), result), n)
        }
    }

    /// @dev Returns a copy of `subject`, with the length reduced to `n`.
    /// If `n` is greater than the size of `subject`, this will be a no-op.
    function truncatedCalldata(bytes calldata subject, uint256 n)
        internal
        pure
        returns (bytes calldata result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result.offset := subject.offset
            result.length := xor(n, mul(xor(n, subject.length), lt(subject.length, n)))
        }
    }

    /// @dev Returns all the indices of `needle` in `subject`.
    /// The indices are byte offsets.
    function indicesOf(bytes memory subject, bytes memory needle)
        internal
        pure
        returns (uint256[] memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let searchLen := mload(needle)
            if iszero(gt(searchLen, mload(subject))) {
                result := mload(0x40)
                let i := add(subject, 0x20)
                let o := add(result, 0x20)
                let subjectSearchEnd := add(sub(add(i, mload(subject)), searchLen), 1)
                let h := 0 // The hash of `needle`.
                if iszero(lt(searchLen, 0x20)) { h := keccak256(add(needle, 0x20), searchLen) }
                let s := mload(add(needle, 0x20))
                for { let m := shl(3, sub(0x20, and(searchLen, 0x1f))) } 1 {} {
                    let t := mload(i)
                    // Whether the first `searchLen % 32` bytes of `subject` and `needle` matches.
                    if iszero(shr(m, xor(t, s))) {
                        if h {
                            if iszero(eq(keccak256(i, searchLen), h)) {
                                i := add(i, 1)
                                if iszero(lt(i, subjectSearchEnd)) { break }
                                continue
                            }
                        }
                        mstore(o, sub(i, add(subject, 0x20))) // Append to `result`.
                        o := add(o, 0x20)
                        i := add(i, searchLen) // Advance `i` by `searchLen`.
                        if searchLen {
                            if iszero(lt(i, subjectSearchEnd)) { break }
                            continue
                        }
                    }
                    i := add(i, 1)
                    if iszero(lt(i, subjectSearchEnd)) { break }
                }
                mstore(result, shr(5, sub(o, add(result, 0x20)))) // Store the length of `result`.
                // Allocate memory for result.
                // We allocate one more word, so this array can be recycled for {split}.
                mstore(0x40, add(o, 0x20))
            }
        }
    }

    /// @dev Returns a arrays of bytess based on the `delimiter` inside of the `subject` bytes.
    function split(bytes memory subject, bytes memory delimiter)
        internal
        pure
        returns (bytes[] memory result)
    {
        uint256[] memory indices = indicesOf(subject, delimiter);
        /// @solidity memory-safe-assembly
        assembly {
            let w := not(0x1f)
            let indexPtr := add(indices, 0x20)
            let indicesEnd := add(indexPtr, shl(5, add(mload(indices), 1)))
            mstore(add(indicesEnd, w), mload(subject))
            mstore(indices, add(mload(indices), 1))
            for { let prevIndex := 0 } 1 {} {
                let index := mload(indexPtr)
                mstore(indexPtr, 0x60)
                if iszero(eq(index, prevIndex)) {
                    let element := mload(0x40)
                    let l := sub(index, prevIndex)
                    mstore(element, l) // Store the length of the element.
                    // Copy the `subject` one word at a time, backwards.
                    for { let o := and(add(l, 0x1f), w) } 1 {} {
                        mstore(add(element, o), mload(add(add(subject, prevIndex), o)))
                        o := add(o, w) // `sub(o, 0x20)`.
                        if iszero(o) { break }
                    }
                    mstore(add(add(element, 0x20), l), 0) // Zeroize the slot after the bytes.
                    // Allocate memory for the length and the bytes, rounded up to a multiple of 32.
                    mstore(0x40, add(element, and(add(l, 0x3f), w)))
                    mstore(indexPtr, element) // Store the `element` into the array.
                }
                prevIndex := add(index, mload(delimiter))
                indexPtr := add(indexPtr, 0x20)
                if iszero(lt(indexPtr, indicesEnd)) { break }
            }
            result := indices
            if iszero(mload(delimiter)) {
                result := add(indices, 0x20)
                mstore(result, sub(mload(indices), 2))
            }
        }
    }

    /// @dev Returns a concatenated bytes of `a` and `b`.
    /// Cheaper than `bytes.concat()` and does not de-align the free memory pointer.
    function concat(bytes memory a, bytes memory b) internal pure returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let w := not(0x1f)
            let aLen := mload(a)
            // Copy `a` one word at a time, backwards.
            for { let o := and(add(aLen, 0x20), w) } 1 {} {
                mstore(add(result, o), mload(add(a, o)))
                o := add(o, w) // `sub(o, 0x20)`.
                if iszero(o) { break }
            }
            let bLen := mload(b)
            let output := add(result, aLen)
            // Copy `b` one word at a time, backwards.
            for { let o := and(add(bLen, 0x20), w) } 1 {} {
                mstore(add(output, o), mload(add(b, o)))
                o := add(o, w) // `sub(o, 0x20)`.
                if iszero(o) { break }
            }
            let totalLen := add(aLen, bLen)
            let last := add(add(result, 0x20), totalLen)
            mstore(last, 0) // Zeroize the slot after the bytes.
            mstore(result, totalLen) // Store the length.
            mstore(0x40, add(last, 0x20)) // Allocate memory.
        }
    }

    /// @dev Returns whether `a` equals `b`.
    function eq(bytes memory a, bytes memory b) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := eq(keccak256(add(a, 0x20), mload(a)), keccak256(add(b, 0x20), mload(b)))
        }
    }

    /// @dev Returns whether `a` equals `b`, where `b` is a null-terminated small bytes.
    function eqs(bytes memory a, bytes32 b) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            // These should be evaluated on compile time, as far as possible.
            let m := not(shl(7, div(not(iszero(b)), 255))) // `0x7f7f ...`.
            let x := not(or(m, or(b, add(m, and(b, m)))))
            let r := shl(7, iszero(iszero(shr(128, x))))
            r := or(r, shl(6, iszero(iszero(shr(64, shr(r, x))))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            // forgefmt: disable-next-item
            result := gt(eq(mload(a), add(iszero(x), xor(31, shr(3, r)))),
                xor(shr(add(8, r), b), shr(add(8, r), mload(add(a, 0x20)))))
        }
    }

    /// @dev Returns 0 if `a == b`, -1 if `a < b`, +1 if `a > b`.
    /// If `a` == b[:a.length]`, and `a.length < b.length`, returns -1.
    function cmp(bytes memory a, bytes memory b) internal pure returns (int256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let aLen := mload(a)
            let bLen := mload(b)
            let n := and(xor(aLen, mul(xor(aLen, bLen), lt(bLen, aLen))), not(0x1f))
            if n {
                for { let i := 0x20 } 1 {} {
                    let x := mload(add(a, i))
                    let y := mload(add(b, i))
                    if iszero(or(xor(x, y), eq(i, n))) {
                        i := add(i, 0x20)
                        continue
                    }
                    result := sub(gt(x, y), lt(x, y))
                    break
                }
            }
            // forgefmt: disable-next-item
            if iszero(result) {
                let l := 0x201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201
                let x := and(mload(add(add(a, 0x20), n)), shl(shl(3, byte(sub(aLen, n), l)), not(0)))
                let y := and(mload(add(add(b, 0x20), n)), shl(shl(3, byte(sub(bLen, n), l)), not(0)))
                result := sub(gt(x, y), lt(x, y))
                if iszero(result) { result := sub(gt(aLen, bLen), lt(aLen, bLen)) }
            }
        }
    }

    /// @dev Directly returns `a` without copying.
    function directReturn(bytes memory a) internal pure {
        assembly {
            // Assumes that the bytes does not start from the scratch space.
            let retStart := sub(a, 0x20)
            let retUnpaddedSize := add(mload(a), 0x40)
            // Right pad with zeroes. Just in case the bytes is produced
            // by a method that doesn't zero right pad.
            mstore(add(retStart, retUnpaddedSize), 0)
            mstore(retStart, 0x20) // Store the return offset.
            // End the transaction, returning the bytes.
            return(retStart, and(not(0x1f), add(0x1f, retUnpaddedSize)))
        }
    }

    /// @dev Directly returns `a` with minimal copying.
    function directReturn(bytes[] memory a) internal pure {
        assembly {
            let n := mload(a) // `a.length`.
            let o := add(a, 0x20) // Start of elements in `a`.
            let u := a // Highest memory slot.
            let w := not(0x1f)
            for { let i := 0 } iszero(eq(i, n)) { i := add(i, 1) } {
                let c := add(o, shl(5, i)) // Location of pointer to `a[i]`.
                let s := mload(c) // `a[i]`.
                let l := mload(s) // `a[i].length`.
                let r := and(l, 0x1f) // `a[i].length % 32`.
                let z := add(0x20, and(l, w)) // Offset of last word in `a[i]` from `s`.
                // If `s` comes before `o`, or `s` is not zero right padded.
                if iszero(lt(lt(s, o), or(iszero(r), iszero(shl(shl(3, r), mload(add(s, z))))))) {
                    let m := mload(0x40)
                    mstore(m, l) // Copy `a[i].length`.
                    for {} 1 {} {
                        mstore(add(m, z), mload(add(s, z))) // Copy `a[i]`, backwards.
                        z := add(z, w) // `sub(z, 0x20)`.
                        if iszero(z) { break }
                    }
                    let e := add(add(m, 0x20), l)
                    mstore(e, 0) // Zeroize the slot after the copied bytes.
                    mstore(0x40, add(e, 0x20)) // Allocate memory.
                    s := m
                }
                mstore(c, sub(s, o)) // Convert to calldata offset.
                let t := add(l, add(s, 0x20))
                if iszero(lt(t, u)) { u := t }
            }
            let retStart := add(a, w) // Assumes `a` doesn't start from scratch space.
            mstore(retStart, 0x20) // Store the return offset.
            return(retStart, add(0x40, sub(u, retStart))) // End the transaction.
        }
    }

    /// @dev Returns the word at `offset`, without any bounds checks.
    /// To load an address, you can use `address(bytes20(load(a, offset)))`.
    function load(bytes memory a, uint256 offset) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(add(add(a, 0x20), offset))
        }
    }

    /// @dev Returns the word at `offset`, without any bounds checks.
    /// To load an address, you can use `address(bytes20(loadCalldata(a, offset)))`.
    function loadCalldata(bytes calldata a, uint256 offset)
        internal
        pure
        returns (bytes32 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := calldataload(add(a.offset, offset))
        }
    }

    /// @dev Returns empty calldata bytes. For silencing the compiler.
    function emptyCalldata() internal pure returns (bytes calldata result) {
        /// @solidity memory-safe-assembly
        assembly {
            result.length := 0
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {FeePcts} from "../Types.sol";

function unwrap(FeePcts x) pure returns (uint256 result) {
    result = FeePcts.unwrap(x);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {ApproxValue} from "../Types.sol";

function unwrap(ApproxValue x) pure returns (uint256 result) {
    result = ApproxValue.unwrap(x);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {ModuleIndex, MAX_MODULES} from "../Types.sol";

function unwrap(ModuleIndex x) pure returns (uint256 result) {
    result = ModuleIndex.unwrap(x);
}

/// @dev Checks if the given module index is supported by Factory.
/// @dev Even if Factory supports the module, Principal Token instance may not support it due to the length of the array mismatch.
function isSupportedByFactory(ModuleIndex x) pure returns (bool result) {
    result = ModuleIndex.unwrap(x) < MAX_MODULES;
}

function eq(ModuleIndex x, ModuleIndex y) pure returns (bool result) {
    result = ModuleIndex.unwrap(x) == ModuleIndex.unwrap(y);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Ownable} from "./Ownable.sol";

/// @notice Simple single owner and multiroles authorization mixin.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/auth/OwnableRoles.sol)
///
/// @dev Note:
/// This implementation does NOT auto-initialize the owner to `msg.sender`.
/// You MUST call the `_initializeOwner` in the constructor / initializer.
///
/// While the ownable portion follows
/// [EIP-173](https://eips.ethereum.org/EIPS/eip-173) for compatibility,
/// the nomenclature for the 2-step ownership handover may be unique to this codebase.
abstract contract OwnableRoles is Ownable {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The `user`'s roles is updated to `roles`.
    /// Each bit of `roles` represents whether the role is set.
    event RolesUpdated(address indexed user, uint256 indexed roles);

    /// @dev `keccak256(bytes("RolesUpdated(address,uint256)"))`.
    uint256 private constant _ROLES_UPDATED_EVENT_SIGNATURE =
        0x715ad5ce61fc9595c7b415289d59cf203f23a94fa06f04af7e489a0a76e1fe26;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The role slot of `user` is given by:
    /// ```
    ///     mstore(0x00, or(shl(96, user), _ROLE_SLOT_SEED))
    ///     let roleSlot := keccak256(0x00, 0x20)
    /// ```
    /// This automatically ignores the upper bits of the `user` in case
    /// they are not clean, as well as keep the `keccak256` under 32-bytes.
    ///
    /// Note: This is equivalent to `uint32(bytes4(keccak256("_OWNER_SLOT_NOT")))`.
    uint256 private constant _ROLE_SLOT_SEED = 0x8b78c6d8;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     INTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Overwrite the roles directly without authorization guard.
    function _setRoles(address user, uint256 roles) internal virtual {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x0c, _ROLE_SLOT_SEED)
            mstore(0x00, user)
            // Store the new value.
            sstore(keccak256(0x0c, 0x20), roles)
            // Emit the {RolesUpdated} event.
            log3(0, 0, _ROLES_UPDATED_EVENT_SIGNATURE, shr(96, mload(0x0c)), roles)
        }
    }

    /// @dev Updates the roles directly without authorization guard.
    /// If `on` is true, each set bit of `roles` will be turned on,
    /// otherwise, each set bit of `roles` will be turned off.
    function _updateRoles(address user, uint256 roles, bool on) internal virtual {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x0c, _ROLE_SLOT_SEED)
            mstore(0x00, user)
            let roleSlot := keccak256(0x0c, 0x20)
            // Load the current value.
            let current := sload(roleSlot)
            // Compute the updated roles if `on` is true.
            let updated := or(current, roles)
            // Compute the updated roles if `on` is false.
            // Use `and` to compute the intersection of `current` and `roles`,
            // `xor` it with `current` to flip the bits in the intersection.
            if iszero(on) { updated := xor(current, and(current, roles)) }
            // Then, store the new value.
            sstore(roleSlot, updated)
            // Emit the {RolesUpdated} event.
            log3(0, 0, _ROLES_UPDATED_EVENT_SIGNATURE, shr(96, mload(0x0c)), updated)
        }
    }

    /// @dev Grants the roles directly without authorization guard.
    /// Each bit of `roles` represents the role to turn on.
    function _grantRoles(address user, uint256 roles) internal virtual {
        _updateRoles(user, roles, true);
    }

    /// @dev Removes the roles directly without authorization guard.
    /// Each bit of `roles` represents the role to turn off.
    function _removeRoles(address user, uint256 roles) internal virtual {
        _updateRoles(user, roles, false);
    }

    /// @dev Throws if the sender does not have any of the `roles`.
    function _checkRoles(uint256 roles) internal view virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the role slot.
            mstore(0x0c, _ROLE_SLOT_SEED)
            mstore(0x00, caller())
            // Load the stored value, and if the `and` intersection
            // of the value and `roles` is zero, revert.
            if iszero(and(sload(keccak256(0x0c, 0x20)), roles)) {
                mstore(0x00, 0x82b42900) // `Unauthorized()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Throws if the sender is not the owner,
    /// and does not have any of the `roles`.
    /// Checks for ownership first, then lazily checks for roles.
    function _checkOwnerOrRoles(uint256 roles) internal view virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // If the caller is not the stored owner.
            // Note: `_ROLE_SLOT_SEED` is equal to `_OWNER_SLOT_NOT`.
            if iszero(eq(caller(), sload(not(_ROLE_SLOT_SEED)))) {
                // Compute the role slot.
                mstore(0x0c, _ROLE_SLOT_SEED)
                mstore(0x00, caller())
                // Load the stored value, and if the `and` intersection
                // of the value and `roles` is zero, revert.
                if iszero(and(sload(keccak256(0x0c, 0x20)), roles)) {
                    mstore(0x00, 0x82b42900) // `Unauthorized()`.
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    /// @dev Throws if the sender does not have any of the `roles`,
    /// and is not the owner.
    /// Checks for roles first, then lazily checks for ownership.
    function _checkRolesOrOwner(uint256 roles) internal view virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the role slot.
            mstore(0x0c, _ROLE_SLOT_SEED)
            mstore(0x00, caller())
            // Load the stored value, and if the `and` intersection
            // of the value and `roles` is zero, revert.
            if iszero(and(sload(keccak256(0x0c, 0x20)), roles)) {
                // If the caller is not the stored owner.
                // Note: `_ROLE_SLOT_SEED` is equal to `_OWNER_SLOT_NOT`.
                if iszero(eq(caller(), sload(not(_ROLE_SLOT_SEED)))) {
                    mstore(0x00, 0x82b42900) // `Unauthorized()`.
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    /// @dev Convenience function to return a `roles` bitmap from an array of `ordinals`.
    /// This is meant for frontends like Etherscan, and is therefore not fully optimized.
    /// Not recommended to be called on-chain.
    /// Made internal to conserve bytecode. Wrap it in a public function if needed.
    function _rolesFromOrdinals(uint8[] memory ordinals) internal pure returns (uint256 roles) {
        /// @solidity memory-safe-assembly
        assembly {
            for { let i := shl(5, mload(ordinals)) } i { i := sub(i, 0x20) } {
                // We don't need to mask the values of `ordinals`, as Solidity
                // cleans dirty upper bits when storing variables into memory.
                roles := or(shl(mload(add(ordinals, i)), 1), roles)
            }
        }
    }

    /// @dev Convenience function to return an array of `ordinals` from the `roles` bitmap.
    /// This is meant for frontends like Etherscan, and is therefore not fully optimized.
    /// Not recommended to be called on-chain.
    /// Made internal to conserve bytecode. Wrap it in a public function if needed.
    function _ordinalsFromRoles(uint256 roles) internal pure returns (uint8[] memory ordinals) {
        /// @solidity memory-safe-assembly
        assembly {
            // Grab the pointer to the free memory.
            ordinals := mload(0x40)
            let ptr := add(ordinals, 0x20)
            let o := 0
            // The absence of lookup tables, De Bruijn, etc., here is intentional for
            // smaller bytecode, as this function is not meant to be called on-chain.
            for { let t := roles } 1 {} {
                mstore(ptr, o)
                // `shr` 5 is equivalent to multiplying by 0x20.
                // Push back into the ordinals array if the bit is set.
                ptr := add(ptr, shl(5, and(t, 1)))
                o := add(o, 1)
                t := shr(o, roles)
                if iszero(t) { break }
            }
            // Store the length of `ordinals`.
            mstore(ordinals, shr(5, sub(ptr, add(ordinals, 0x20))))
            // Allocate the memory.
            mstore(0x40, ptr)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  PUBLIC UPDATE FUNCTIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Allows the owner to grant `user` `roles`.
    /// If the `user` already has a role, then it will be an no-op for the role.
    function grantRoles(address user, uint256 roles) public payable virtual onlyOwner {
        _grantRoles(user, roles);
    }

    /// @dev Allows the owner to remove `user` `roles`.
    /// If the `user` does not have a role, then it will be an no-op for the role.
    function revokeRoles(address user, uint256 roles) public payable virtual onlyOwner {
        _removeRoles(user, roles);
    }

    /// @dev Allow the caller to remove their own roles.
    /// If the caller does not have a role, then it will be an no-op for the role.
    function renounceRoles(uint256 roles) public payable virtual {
        _removeRoles(msg.sender, roles);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   PUBLIC READ FUNCTIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the roles of `user`.
    function rolesOf(address user) public view virtual returns (uint256 roles) {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the role slot.
            mstore(0x0c, _ROLE_SLOT_SEED)
            mstore(0x00, user)
            // Load the stored value.
            roles := sload(keccak256(0x0c, 0x20))
        }
    }

    /// @dev Returns whether `user` has any of `roles`.
    function hasAnyRole(address user, uint256 roles) public view virtual returns (bool) {
        return rolesOf(user) & roles != 0;
    }

    /// @dev Returns whether `user` has all of `roles`.
    function hasAllRoles(address user, uint256 roles) public view virtual returns (bool) {
        return rolesOf(user) & roles == roles;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         MODIFIERS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Marks a function as only callable by an account with `roles`.
    modifier onlyRoles(uint256 roles) virtual {
        _checkRoles(roles);
        _;
    }

    /// @dev Marks a function as only callable by the owner or by an account
    /// with `roles`. Checks for ownership first, then lazily checks for roles.
    modifier onlyOwnerOrRoles(uint256 roles) virtual {
        _checkOwnerOrRoles(roles);
        _;
    }

    /// @dev Marks a function as only callable by an account with `roles`
    /// or the owner. Checks for roles first, then lazily checks for ownership.
    modifier onlyRolesOrOwner(uint256 roles) virtual {
        _checkRolesOrOwner(roles);
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ROLE CONSTANTS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // IYKYK

    uint256 internal constant _ROLE_0 = 1 << 0;
    uint256 internal constant _ROLE_1 = 1 << 1;
    uint256 internal constant _ROLE_2 = 1 << 2;
    uint256 internal constant _ROLE_3 = 1 << 3;
    uint256 internal constant _ROLE_4 = 1 << 4;
    uint256 internal constant _ROLE_5 = 1 << 5;
    uint256 internal constant _ROLE_6 = 1 << 6;
    uint256 internal constant _ROLE_7 = 1 << 7;
    uint256 internal constant _ROLE_8 = 1 << 8;
    uint256 internal constant _ROLE_9 = 1 << 9;
    uint256 internal constant _ROLE_10 = 1 << 10;
    uint256 internal constant _ROLE_11 = 1 << 11;
    uint256 internal constant _ROLE_12 = 1 << 12;
    uint256 internal constant _ROLE_13 = 1 << 13;
    uint256 internal constant _ROLE_14 = 1 << 14;
    uint256 internal constant _ROLE_15 = 1 << 15;
    uint256 internal constant _ROLE_16 = 1 << 16;
    uint256 internal constant _ROLE_17 = 1 << 17;
    uint256 internal constant _ROLE_18 = 1 << 18;
    uint256 internal constant _ROLE_19 = 1 << 19;
    uint256 internal constant _ROLE_20 = 1 << 20;
    uint256 internal constant _ROLE_21 = 1 << 21;
    uint256 internal constant _ROLE_22 = 1 << 22;
    uint256 internal constant _ROLE_23 = 1 << 23;
    uint256 internal constant _ROLE_24 = 1 << 24;
    uint256 internal constant _ROLE_25 = 1 << 25;
    uint256 internal constant _ROLE_26 = 1 << 26;
    uint256 internal constant _ROLE_27 = 1 << 27;
    uint256 internal constant _ROLE_28 = 1 << 28;
    uint256 internal constant _ROLE_29 = 1 << 29;
    uint256 internal constant _ROLE_30 = 1 << 30;
    uint256 internal constant _ROLE_31 = 1 << 31;
    uint256 internal constant _ROLE_32 = 1 << 32;
    uint256 internal constant _ROLE_33 = 1 << 33;
    uint256 internal constant _ROLE_34 = 1 << 34;
    uint256 internal constant _ROLE_35 = 1 << 35;
    uint256 internal constant _ROLE_36 = 1 << 36;
    uint256 internal constant _ROLE_37 = 1 << 37;
    uint256 internal constant _ROLE_38 = 1 << 38;
    uint256 internal constant _ROLE_39 = 1 << 39;
    uint256 internal constant _ROLE_40 = 1 << 40;
    uint256 internal constant _ROLE_41 = 1 << 41;
    uint256 internal constant _ROLE_42 = 1 << 42;
    uint256 internal constant _ROLE_43 = 1 << 43;
    uint256 internal constant _ROLE_44 = 1 << 44;
    uint256 internal constant _ROLE_45 = 1 << 45;
    uint256 internal constant _ROLE_46 = 1 << 46;
    uint256 internal constant _ROLE_47 = 1 << 47;
    uint256 internal constant _ROLE_48 = 1 << 48;
    uint256 internal constant _ROLE_49 = 1 << 49;
    uint256 internal constant _ROLE_50 = 1 << 50;
    uint256 internal constant _ROLE_51 = 1 << 51;
    uint256 internal constant _ROLE_52 = 1 << 52;
    uint256 internal constant _ROLE_53 = 1 << 53;
    uint256 internal constant _ROLE_54 = 1 << 54;
    uint256 internal constant _ROLE_55 = 1 << 55;
    uint256 internal constant _ROLE_56 = 1 << 56;
    uint256 internal constant _ROLE_57 = 1 << 57;
    uint256 internal constant _ROLE_58 = 1 << 58;
    uint256 internal constant _ROLE_59 = 1 << 59;
    uint256 internal constant _ROLE_60 = 1 << 60;
    uint256 internal constant _ROLE_61 = 1 << 61;
    uint256 internal constant _ROLE_62 = 1 << 62;
    uint256 internal constant _ROLE_63 = 1 << 63;
    uint256 internal constant _ROLE_64 = 1 << 64;
    uint256 internal constant _ROLE_65 = 1 << 65;
    uint256 internal constant _ROLE_66 = 1 << 66;
    uint256 internal constant _ROLE_67 = 1 << 67;
    uint256 internal constant _ROLE_68 = 1 << 68;
    uint256 internal constant _ROLE_69 = 1 << 69;
    uint256 internal constant _ROLE_70 = 1 << 70;
    uint256 internal constant _ROLE_71 = 1 << 71;
    uint256 internal constant _ROLE_72 = 1 << 72;
    uint256 internal constant _ROLE_73 = 1 << 73;
    uint256 internal constant _ROLE_74 = 1 << 74;
    uint256 internal constant _ROLE_75 = 1 << 75;
    uint256 internal constant _ROLE_76 = 1 << 76;
    uint256 internal constant _ROLE_77 = 1 << 77;
    uint256 internal constant _ROLE_78 = 1 << 78;
    uint256 internal constant _ROLE_79 = 1 << 79;
    uint256 internal constant _ROLE_80 = 1 << 80;
    uint256 internal constant _ROLE_81 = 1 << 81;
    uint256 internal constant _ROLE_82 = 1 << 82;
    uint256 internal constant _ROLE_83 = 1 << 83;
    uint256 internal constant _ROLE_84 = 1 << 84;
    uint256 internal constant _ROLE_85 = 1 << 85;
    uint256 internal constant _ROLE_86 = 1 << 86;
    uint256 internal constant _ROLE_87 = 1 << 87;
    uint256 internal constant _ROLE_88 = 1 << 88;
    uint256 internal constant _ROLE_89 = 1 << 89;
    uint256 internal constant _ROLE_90 = 1 << 90;
    uint256 internal constant _ROLE_91 = 1 << 91;
    uint256 internal constant _ROLE_92 = 1 << 92;
    uint256 internal constant _ROLE_93 = 1 << 93;
    uint256 internal constant _ROLE_94 = 1 << 94;
    uint256 internal constant _ROLE_95 = 1 << 95;
    uint256 internal constant _ROLE_96 = 1 << 96;
    uint256 internal constant _ROLE_97 = 1 << 97;
    uint256 internal constant _ROLE_98 = 1 << 98;
    uint256 internal constant _ROLE_99 = 1 << 99;
    uint256 internal constant _ROLE_100 = 1 << 100;
    uint256 internal constant _ROLE_101 = 1 << 101;
    uint256 internal constant _ROLE_102 = 1 << 102;
    uint256 internal constant _ROLE_103 = 1 << 103;
    uint256 internal constant _ROLE_104 = 1 << 104;
    uint256 internal constant _ROLE_105 = 1 << 105;
    uint256 internal constant _ROLE_106 = 1 << 106;
    uint256 internal constant _ROLE_107 = 1 << 107;
    uint256 internal constant _ROLE_108 = 1 << 108;
    uint256 internal constant _ROLE_109 = 1 << 109;
    uint256 internal constant _ROLE_110 = 1 << 110;
    uint256 internal constant _ROLE_111 = 1 << 111;
    uint256 internal constant _ROLE_112 = 1 << 112;
    uint256 internal constant _ROLE_113 = 1 << 113;
    uint256 internal constant _ROLE_114 = 1 << 114;
    uint256 internal constant _ROLE_115 = 1 << 115;
    uint256 internal constant _ROLE_116 = 1 << 116;
    uint256 internal constant _ROLE_117 = 1 << 117;
    uint256 internal constant _ROLE_118 = 1 << 118;
    uint256 internal constant _ROLE_119 = 1 << 119;
    uint256 internal constant _ROLE_120 = 1 << 120;
    uint256 internal constant _ROLE_121 = 1 << 121;
    uint256 internal constant _ROLE_122 = 1 << 122;
    uint256 internal constant _ROLE_123 = 1 << 123;
    uint256 internal constant _ROLE_124 = 1 << 124;
    uint256 internal constant _ROLE_125 = 1 << 125;
    uint256 internal constant _ROLE_126 = 1 << 126;
    uint256 internal constant _ROLE_127 = 1 << 127;
    uint256 internal constant _ROLE_128 = 1 << 128;
    uint256 internal constant _ROLE_129 = 1 << 129;
    uint256 internal constant _ROLE_130 = 1 << 130;
    uint256 internal constant _ROLE_131 = 1 << 131;
    uint256 internal constant _ROLE_132 = 1 << 132;
    uint256 internal constant _ROLE_133 = 1 << 133;
    uint256 internal constant _ROLE_134 = 1 << 134;
    uint256 internal constant _ROLE_135 = 1 << 135;
    uint256 internal constant _ROLE_136 = 1 << 136;
    uint256 internal constant _ROLE_137 = 1 << 137;
    uint256 internal constant _ROLE_138 = 1 << 138;
    uint256 internal constant _ROLE_139 = 1 << 139;
    uint256 internal constant _ROLE_140 = 1 << 140;
    uint256 internal constant _ROLE_141 = 1 << 141;
    uint256 internal constant _ROLE_142 = 1 << 142;
    uint256 internal constant _ROLE_143 = 1 << 143;
    uint256 internal constant _ROLE_144 = 1 << 144;
    uint256 internal constant _ROLE_145 = 1 << 145;
    uint256 internal constant _ROLE_146 = 1 << 146;
    uint256 internal constant _ROLE_147 = 1 << 147;
    uint256 internal constant _ROLE_148 = 1 << 148;
    uint256 internal constant _ROLE_149 = 1 << 149;
    uint256 internal constant _ROLE_150 = 1 << 150;
    uint256 internal constant _ROLE_151 = 1 << 151;
    uint256 internal constant _ROLE_152 = 1 << 152;
    uint256 internal constant _ROLE_153 = 1 << 153;
    uint256 internal constant _ROLE_154 = 1 << 154;
    uint256 internal constant _ROLE_155 = 1 << 155;
    uint256 internal constant _ROLE_156 = 1 << 156;
    uint256 internal constant _ROLE_157 = 1 << 157;
    uint256 internal constant _ROLE_158 = 1 << 158;
    uint256 internal constant _ROLE_159 = 1 << 159;
    uint256 internal constant _ROLE_160 = 1 << 160;
    uint256 internal constant _ROLE_161 = 1 << 161;
    uint256 internal constant _ROLE_162 = 1 << 162;
    uint256 internal constant _ROLE_163 = 1 << 163;
    uint256 internal constant _ROLE_164 = 1 << 164;
    uint256 internal constant _ROLE_165 = 1 << 165;
    uint256 internal constant _ROLE_166 = 1 << 166;
    uint256 internal constant _ROLE_167 = 1 << 167;
    uint256 internal constant _ROLE_168 = 1 << 168;
    uint256 internal constant _ROLE_169 = 1 << 169;
    uint256 internal constant _ROLE_170 = 1 << 170;
    uint256 internal constant _ROLE_171 = 1 << 171;
    uint256 internal constant _ROLE_172 = 1 << 172;
    uint256 internal constant _ROLE_173 = 1 << 173;
    uint256 internal constant _ROLE_174 = 1 << 174;
    uint256 internal constant _ROLE_175 = 1 << 175;
    uint256 internal constant _ROLE_176 = 1 << 176;
    uint256 internal constant _ROLE_177 = 1 << 177;
    uint256 internal constant _ROLE_178 = 1 << 178;
    uint256 internal constant _ROLE_179 = 1 << 179;
    uint256 internal constant _ROLE_180 = 1 << 180;
    uint256 internal constant _ROLE_181 = 1 << 181;
    uint256 internal constant _ROLE_182 = 1 << 182;
    uint256 internal constant _ROLE_183 = 1 << 183;
    uint256 internal constant _ROLE_184 = 1 << 184;
    uint256 internal constant _ROLE_185 = 1 << 185;
    uint256 internal constant _ROLE_186 = 1 << 186;
    uint256 internal constant _ROLE_187 = 1 << 187;
    uint256 internal constant _ROLE_188 = 1 << 188;
    uint256 internal constant _ROLE_189 = 1 << 189;
    uint256 internal constant _ROLE_190 = 1 << 190;
    uint256 internal constant _ROLE_191 = 1 << 191;
    uint256 internal constant _ROLE_192 = 1 << 192;
    uint256 internal constant _ROLE_193 = 1 << 193;
    uint256 internal constant _ROLE_194 = 1 << 194;
    uint256 internal constant _ROLE_195 = 1 << 195;
    uint256 internal constant _ROLE_196 = 1 << 196;
    uint256 internal constant _ROLE_197 = 1 << 197;
    uint256 internal constant _ROLE_198 = 1 << 198;
    uint256 internal constant _ROLE_199 = 1 << 199;
    uint256 internal constant _ROLE_200 = 1 << 200;
    uint256 internal constant _ROLE_201 = 1 << 201;
    uint256 internal constant _ROLE_202 = 1 << 202;
    uint256 internal constant _ROLE_203 = 1 << 203;
    uint256 internal constant _ROLE_204 = 1 << 204;
    uint256 internal constant _ROLE_205 = 1 << 205;
    uint256 internal constant _ROLE_206 = 1 << 206;
    uint256 internal constant _ROLE_207 = 1 << 207;
    uint256 internal constant _ROLE_208 = 1 << 208;
    uint256 internal constant _ROLE_209 = 1 << 209;
    uint256 internal constant _ROLE_210 = 1 << 210;
    uint256 internal constant _ROLE_211 = 1 << 211;
    uint256 internal constant _ROLE_212 = 1 << 212;
    uint256 internal constant _ROLE_213 = 1 << 213;
    uint256 internal constant _ROLE_214 = 1 << 214;
    uint256 internal constant _ROLE_215 = 1 << 215;
    uint256 internal constant _ROLE_216 = 1 << 216;
    uint256 internal constant _ROLE_217 = 1 << 217;
    uint256 internal constant _ROLE_218 = 1 << 218;
    uint256 internal constant _ROLE_219 = 1 << 219;
    uint256 internal constant _ROLE_220 = 1 << 220;
    uint256 internal constant _ROLE_221 = 1 << 221;
    uint256 internal constant _ROLE_222 = 1 << 222;
    uint256 internal constant _ROLE_223 = 1 << 223;
    uint256 internal constant _ROLE_224 = 1 << 224;
    uint256 internal constant _ROLE_225 = 1 << 225;
    uint256 internal constant _ROLE_226 = 1 << 226;
    uint256 internal constant _ROLE_227 = 1 << 227;
    uint256 internal constant _ROLE_228 = 1 << 228;
    uint256 internal constant _ROLE_229 = 1 << 229;
    uint256 internal constant _ROLE_230 = 1 << 230;
    uint256 internal constant _ROLE_231 = 1 << 231;
    uint256 internal constant _ROLE_232 = 1 << 232;
    uint256 internal constant _ROLE_233 = 1 << 233;
    uint256 internal constant _ROLE_234 = 1 << 234;
    uint256 internal constant _ROLE_235 = 1 << 235;
    uint256 internal constant _ROLE_236 = 1 << 236;
    uint256 internal constant _ROLE_237 = 1 << 237;
    uint256 internal constant _ROLE_238 = 1 << 238;
    uint256 internal constant _ROLE_239 = 1 << 239;
    uint256 internal constant _ROLE_240 = 1 << 240;
    uint256 internal constant _ROLE_241 = 1 << 241;
    uint256 internal constant _ROLE_242 = 1 << 242;
    uint256 internal constant _ROLE_243 = 1 << 243;
    uint256 internal constant _ROLE_244 = 1 << 244;
    uint256 internal constant _ROLE_245 = 1 << 245;
    uint256 internal constant _ROLE_246 = 1 << 246;
    uint256 internal constant _ROLE_247 = 1 << 247;
    uint256 internal constant _ROLE_248 = 1 << 248;
    uint256 internal constant _ROLE_249 = 1 << 249;
    uint256 internal constant _ROLE_250 = 1 << 250;
    uint256 internal constant _ROLE_251 = 1 << 251;
    uint256 internal constant _ROLE_252 = 1 << 252;
    uint256 internal constant _ROLE_253 = 1 << 253;
    uint256 internal constant _ROLE_254 = 1 << 254;
    uint256 internal constant _ROLE_255 = 1 << 255;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Contract that enables a single call to call multiple methods on itself.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/Multicallable.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/Multicallable.sol)
///
/// WARNING:
/// This implementation is NOT to be used with ERC2771 out-of-the-box.
/// https://blog.openzeppelin.com/arbitrary-address-spoofing-vulnerability-erc2771context-multicall-public-disclosure
/// This also applies to potentially other ERCs / patterns appending to the back of calldata.
///
/// We do NOT have a check for ERC2771, as we do not inherit from OpenZeppelin's context.
/// Moreover, it is infeasible and inefficient for us to add checks and mitigations
/// for all possible ERC / patterns appending to the back of calldata.
///
/// We would highly recommend using an alternative pattern such as
/// https://github.com/Vectorized/multicaller
/// which is more flexible, futureproof, and safer by default.
abstract contract Multicallable {
    /// @dev Apply `delegatecall` with the current contract to each calldata in `data`,
    /// and store the `abi.encode` formatted results of each `delegatecall` into `results`.
    /// If any of the `delegatecall`s reverts, the entire context is reverted,
    /// and the error is bubbled up.
    ///
    /// By default, this function directly returns the results and terminates the call context.
    /// If you need to add before and after actions to the multicall, please override this function.
    function multicall(bytes[] calldata data) public payable virtual returns (bytes[] memory) {
        // Revert if `msg.value` is non-zero by default to guard against double-spending.
        // (See: https://www.paradigm.xyz/2021/08/two-rights-might-make-a-wrong)
        //
        // If you really need to pass in a `msg.value`, then you will have to
        // override this function and add in any relevant before and after checks.
        if (msg.value != 0) revert();
        // `_multicallDirectReturn` returns the results directly and terminates the call context.
        _multicallDirectReturn(_multicall(data));
    }

    /// @dev The inner logic of `multicall`.
    /// This function is included so that you can override `multicall`
    /// to add before and after actions, and use the `_multicallDirectReturn` function.
    function _multicall(bytes[] calldata data) internal virtual returns (bytes32 results) {
        /// @solidity memory-safe-assembly
        assembly {
            results := mload(0x40)
            mstore(results, 0x20)
            mstore(add(0x20, results), data.length)
            let c := add(0x40, results)
            let s := c
            let end := shl(5, data.length)
            calldatacopy(c, data.offset, end)
            end := add(c, end)
            let m := end
            if data.length {
                for {} 1 {} {
                    let o := add(data.offset, mload(c))
                    calldatacopy(m, add(o, 0x20), calldataload(o))
                    // forgefmt: disable-next-item
                    if iszero(delegatecall(gas(), address(), m, calldataload(o), codesize(), 0x00)) {
                        // Bubble up the revert if the delegatecall reverts.
                        returndatacopy(results, 0x00, returndatasize())
                        revert(results, returndatasize())
                    }
                    mstore(c, sub(m, s))
                    c := add(0x20, c)
                    // Append the `returndatasize()`, and the return data.
                    mstore(m, returndatasize())
                    let b := add(m, 0x20)
                    returndatacopy(b, 0x00, returndatasize())
                    // Advance `m` by `returndatasize() + 0x20`,
                    // rounded up to the next multiple of 32.
                    m := and(add(add(b, returndatasize()), 0x1f), 0xffffffffffffffe0)
                    mstore(add(b, returndatasize()), 0) // Zeroize the slot after the returndata.
                    if iszero(lt(c, end)) { break }
                }
            }
            mstore(0x40, m) // Allocate memory.
            results := or(shl(64, sub(m, results)), results) // Pack the bytes length into `results`.
        }
    }

    /// @dev Decodes the `results` into an array of bytes.
    /// This can be useful if you need to access the results or re-encode it.
    function _multicallResultsToBytesArray(bytes32 results)
        internal
        pure
        virtual
        returns (bytes[] memory decoded)
    {
        /// @solidity memory-safe-assembly
        assembly {
            decoded := mload(0x40)
            let c := and(0xffffffffffffffff, results) // Extract the offset.
            mstore(decoded, mload(add(c, 0x20))) // Store the length.
            let o := add(decoded, 0x20) // Start of elements in `decoded`.
            let end := add(o, shl(5, mload(decoded)))
            mstore(0x40, end) // Allocate memory.
            let s := add(c, 0x40) // Start of elements in `results`.
            let d := sub(s, o) // Difference between input and output pointers.
            for {} iszero(eq(o, end)) { o := add(o, 0x20) } { mstore(o, add(mload(add(d, o)), s)) }
        }
    }

    /// @dev Directly returns the `results` and terminates the current call context.
    /// `results` must be from `_multicall`, else behavior is undefined.
    function _multicallDirectReturn(bytes32 results) internal pure virtual {
        /// @solidity memory-safe-assembly
        assembly {
            return(and(0xffffffffffffffff, results), shr(64, results))
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for reading contract metadata robustly.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/MetadataReaderLib.sol)
library MetadataReaderLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Default gas stipend for contract reads. High enough for most practical use cases
    /// (able to SLOAD about 1000 bytes of data), but low enough to prevent griefing.
    uint256 internal constant GAS_STIPEND_NO_GRIEF = 100000;

    /// @dev Default string byte length limit.
    uint256 internal constant STRING_LIMIT_DEFAULT = 1000;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                METADATA READING OPERATIONS                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Best-effort string reading operations.
    // Should NOT revert as long as sufficient gas is provided.
    //
    // Performs the following in order:
    // 1. Returns the empty string for the following cases:
    //     - Reverts.
    //     - No returndata (e.g. function returns nothing, EOA).
    //     - Returns empty string.
    // 2. Attempts to `abi.decode` the returndata into a string.
    // 3. With any remaining gas, scans the returndata from start to end for the
    //    null byte '\0', to interpret the returndata as a null-terminated string.

    /// @dev Equivalent to `readString(abi.encodeWithSignature("name()"))`.
    function readName(address target) internal view returns (string memory) {
        return _string(target, _ptr(0x06fdde03), STRING_LIMIT_DEFAULT, GAS_STIPEND_NO_GRIEF);
    }

    /// @dev Equivalent to `readString(abi.encodeWithSignature("name()"), limit)`.
    function readName(address target, uint256 limit) internal view returns (string memory) {
        return _string(target, _ptr(0x06fdde03), limit, GAS_STIPEND_NO_GRIEF);
    }

    /// @dev Equivalent to `readString(abi.encodeWithSignature("name()"), limit, gasStipend)`.
    function readName(address target, uint256 limit, uint256 gasStipend)
        internal
        view
        returns (string memory)
    {
        return _string(target, _ptr(0x06fdde03), limit, gasStipend);
    }

    /// @dev Equivalent to `readString(abi.encodeWithSignature("symbol()"))`.
    function readSymbol(address target) internal view returns (string memory) {
        return _string(target, _ptr(0x95d89b41), STRING_LIMIT_DEFAULT, GAS_STIPEND_NO_GRIEF);
    }

    /// @dev Equivalent to `readString(abi.encodeWithSignature("symbol()"), limit)`.
    function readSymbol(address target, uint256 limit) internal view returns (string memory) {
        return _string(target, _ptr(0x95d89b41), limit, GAS_STIPEND_NO_GRIEF);
    }

    /// @dev Equivalent to `readString(abi.encodeWithSignature("symbol()"), limit, gasStipend)`.
    function readSymbol(address target, uint256 limit, uint256 gasStipend)
        internal
        view
        returns (string memory)
    {
        return _string(target, _ptr(0x95d89b41), limit, gasStipend);
    }

    /// @dev Performs a best-effort string query on `target` with `data` as the calldata.
    /// The string will be truncated to `STRING_LIMIT_DEFAULT` (1000) bytes.
    function readString(address target, bytes memory data) internal view returns (string memory) {
        return _string(target, _ptr(data), STRING_LIMIT_DEFAULT, GAS_STIPEND_NO_GRIEF);
    }

    /// @dev Performs a best-effort string query on `target` with `data` as the calldata.
    /// The string will be truncated to `limit` bytes.
    function readString(address target, bytes memory data, uint256 limit)
        internal
        view
        returns (string memory)
    {
        return _string(target, _ptr(data), limit, GAS_STIPEND_NO_GRIEF);
    }

    /// @dev Performs a best-effort string query on `target` with `data` as the calldata.
    /// The string will be truncated to `limit` bytes.
    function readString(address target, bytes memory data, uint256 limit, uint256 gasStipend)
        internal
        view
        returns (string memory)
    {
        return _string(target, _ptr(data), limit, gasStipend);
    }

    // Best-effort unsigned integer reading operations.
    // Should NOT revert as long as sufficient gas is provided.
    //
    // Performs the following in order:
    // 1. Attempts to `abi.decode` the result into a uint256
    //    (equivalent across all Solidity uint types, downcast as needed).
    // 2. Returns zero for the following cases:
    //     - Reverts.
    //     - No returndata (e.g. function returns nothing, EOA).
    //     - Returns zero.
    //     - `abi.decode` failure.

    /// @dev Equivalent to `uint8(readUint(abi.encodeWithSignature("decimals()")))`.
    function readDecimals(address target) internal view returns (uint8) {
        return uint8(_uint(target, _ptr(0x313ce567), GAS_STIPEND_NO_GRIEF));
    }

    /// @dev Equivalent to `uint8(readUint(abi.encodeWithSignature("decimals()"), gasStipend))`.
    function readDecimals(address target, uint256 gasStipend) internal view returns (uint8) {
        return uint8(_uint(target, _ptr(0x313ce567), gasStipend));
    }

    /// @dev Performs a best-effort uint query on `target` with `data` as the calldata.
    function readUint(address target, bytes memory data) internal view returns (uint256) {
        return _uint(target, _ptr(data), GAS_STIPEND_NO_GRIEF);
    }

    /// @dev Performs a best-effort uint query on `target` with `data` as the calldata.
    function readUint(address target, bytes memory data, uint256 gasStipend)
        internal
        view
        returns (uint256)
    {
        return _uint(target, _ptr(data), gasStipend);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Attempts to read and return a string at `target`.
    function _string(address target, bytes32 ptr, uint256 limit, uint256 gasStipend)
        private
        view
        returns (string memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            function min(x_, y_) -> _z {
                _z := xor(x_, mul(xor(x_, y_), lt(y_, x_)))
            }
            for {} staticcall(gasStipend, target, add(ptr, 0x20), mload(ptr), 0x00, 0x20) {} {
                let m := mload(0x40) // Grab the free memory pointer.
                let s := add(0x20, m) // Start of the string's bytes in memory.
                // Attempt to `abi.decode` if the returndatasize is greater or equal to 64.
                if iszero(lt(returndatasize(), 0x40)) {
                    let o := mload(0x00) // Load the string's offset in the returndata.
                    // If the string's offset is within bounds.
                    if iszero(gt(o, sub(returndatasize(), 0x20))) {
                        returndatacopy(m, o, 0x20) // Copy the string's length.
                        // If the full string's end is within bounds.
                        // Note: If the full string doesn't fit, the `abi.decode` must be aborted
                        // for compliance purposes, regardless if the truncated string can fit.
                        if iszero(gt(mload(m), sub(returndatasize(), add(o, 0x20)))) {
                            let n := min(mload(m), limit) // Truncate if needed.
                            mstore(m, n) // Overwrite the length.
                            returndatacopy(s, add(o, 0x20), n) // Copy the string's bytes.
                            mstore(add(s, n), 0) // Zeroize the slot after the string.
                            mstore(0x40, add(0x20, add(s, n))) // Allocate memory for the string.
                            result := m
                            break
                        }
                    }
                }
                // Try interpreting as a null-terminated string.
                let n := min(returndatasize(), limit) // Truncate if needed.
                returndatacopy(s, 0, n) // Copy the string's bytes.
                mstore8(add(s, n), 0) // Place a '\0' at the end.
                let i := s // Pointer to the next byte to scan.
                for {} byte(0, mload(i)) { i := add(i, 1) } {} // Scan for '\0'.
                mstore(m, sub(i, s)) // Store the string's length.
                mstore(i, 0) // Zeroize the slot after the string.
                mstore(0x40, add(0x20, i)) // Allocate memory for the string.
                result := m
                break
            }
        }
    }

    /// @dev Attempts to read and return a uint at `target`.
    function _uint(address target, bytes32 ptr, uint256 gasStipend)
        private
        view
        returns (uint256 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result :=
                mul(
                    mload(0x20),
                    and( // The arguments of `and` are evaluated from right to left.
                        gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                        staticcall(gasStipend, target, add(ptr, 0x20), mload(ptr), 0x20, 0x20)
                    )
                )
        }
    }

    /// @dev Casts the function selector `s` into a pointer.
    function _ptr(uint256 s) private pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // Layout the calldata in the scratch space for temporary usage.
            mstore(0x04, s) // Store the function selector.
            mstore(result, 4) // Store the length.
        }
    }

    /// @dev Casts the `data` into a pointer.
    function _ptr(bytes memory data) private pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := data
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for date time operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/DateTimeLib.sol)
/// @author Modified from BokkyPooBahsDateTimeLibrary (https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary)
/// @dev
/// Conventions:
/// --------------------------------------------------------------------+
/// Unit      | Range                | Notes                            |
/// --------------------------------------------------------------------|
/// timestamp | 0..0x1e18549868c76ff | Unix timestamp.                  |
/// epochDay  | 0..0x16d3e098039     | Days since 1970-01-01.           |
/// year      | 1970..0xffffffff     | Gregorian calendar year.         |
/// month     | 1..12                | Gregorian calendar month.        |
/// day       | 1..31                | Gregorian calendar day of month. |
/// weekday   | 1..7                 | The day of the week (1-indexed). |
/// --------------------------------------------------------------------+
/// All timestamps of days are rounded down to 00:00:00 UTC.
library DateTimeLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Weekdays are 1-indexed, adhering to ISO 8601.

    uint256 internal constant MON = 1;
    uint256 internal constant TUE = 2;
    uint256 internal constant WED = 3;
    uint256 internal constant THU = 4;
    uint256 internal constant FRI = 5;
    uint256 internal constant SAT = 6;
    uint256 internal constant SUN = 7;

    // Months and days of months are 1-indexed, adhering to ISO 8601.

    uint256 internal constant JAN = 1;
    uint256 internal constant FEB = 2;
    uint256 internal constant MAR = 3;
    uint256 internal constant APR = 4;
    uint256 internal constant MAY = 5;
    uint256 internal constant JUN = 6;
    uint256 internal constant JUL = 7;
    uint256 internal constant AUG = 8;
    uint256 internal constant SEP = 9;
    uint256 internal constant OCT = 10;
    uint256 internal constant NOV = 11;
    uint256 internal constant DEC = 12;

    // These limits are large enough for most practical purposes.
    // Inputs that exceed these limits result in undefined behavior.

    uint256 internal constant MAX_SUPPORTED_YEAR = 0xffffffff;
    uint256 internal constant MAX_SUPPORTED_EPOCH_DAY = 0x16d3e098039;
    uint256 internal constant MAX_SUPPORTED_TIMESTAMP = 0x1e18549868c76ff;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    DATE TIME OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the number of days since 1970-01-01 from (`year`,`month`,`day`).
    /// See: https://howardhinnant.github.io/date_algorithms.html
    /// Note: Inputs outside the supported ranges result in undefined behavior.
    /// Use {isSupportedDate} to check if the inputs are supported.
    function dateToEpochDay(uint256 year, uint256 month, uint256 day)
        internal
        pure
        returns (uint256 epochDay)
    {
        /// @solidity memory-safe-assembly
        assembly {
            year := sub(year, lt(month, 3))
            let doy := add(shr(11, add(mul(62719, mod(add(month, 9), 12)), 769)), day)
            let yoe := mod(year, 400)
            let doe := sub(add(add(mul(yoe, 365), shr(2, yoe)), doy), div(yoe, 100))
            epochDay := sub(add(mul(div(year, 400), 146097), doe), 719469)
        }
    }

    /// @dev Returns (`year`,`month`,`day`) from the number of days since 1970-01-01.
    /// Note: Inputs outside the supported ranges result in undefined behavior.
    /// Use {isSupportedDays} to check if the inputs is supported.
    function epochDayToDate(uint256 epochDay)
        internal
        pure
        returns (uint256 year, uint256 month, uint256 day)
    {
        /// @solidity memory-safe-assembly
        assembly {
            epochDay := add(epochDay, 719468)
            let doe := mod(epochDay, 146097)
            let yoe :=
                div(sub(sub(add(doe, div(doe, 36524)), div(doe, 1460)), eq(doe, 146096)), 365)
            let doy := sub(doe, sub(add(mul(365, yoe), shr(2, yoe)), div(yoe, 100)))
            let mp := div(add(mul(5, doy), 2), 153)
            day := add(sub(doy, shr(11, add(mul(mp, 62719), 769))), 1)
            month := byte(mp, shl(160, 0x030405060708090a0b0c0102))
            year := add(add(yoe, mul(div(epochDay, 146097), 400)), lt(month, 3))
        }
    }

    /// @dev Returns the unix timestamp from (`year`,`month`,`day`).
    /// Note: Inputs outside the supported ranges result in undefined behavior.
    /// Use {isSupportedDate} to check if the inputs are supported.
    function dateToTimestamp(uint256 year, uint256 month, uint256 day)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = dateToEpochDay(year, month, day) * 86400;
        }
    }

    /// @dev Returns (`year`,`month`,`day`) from the given unix timestamp.
    /// Note: Inputs outside the supported ranges result in undefined behavior.
    /// Use {isSupportedTimestamp} to check if the inputs are supported.
    function timestampToDate(uint256 timestamp)
        internal
        pure
        returns (uint256 year, uint256 month, uint256 day)
    {
        (year, month, day) = epochDayToDate(timestamp / 86400);
    }

    /// @dev Returns the unix timestamp from
    /// (`year`,`month`,`day`,`hour`,`minute`,`second`).
    /// Note: Inputs outside the supported ranges result in undefined behavior.
    /// Use {isSupportedDateTime} to check if the inputs are supported.
    function dateTimeToTimestamp(
        uint256 year,
        uint256 month,
        uint256 day,
        uint256 hour,
        uint256 minute,
        uint256 second
    ) internal pure returns (uint256 result) {
        unchecked {
            result = dateToEpochDay(year, month, day) * 86400 + hour * 3600 + minute * 60 + second;
        }
    }

    /// @dev Returns (`year`,`month`,`day`,`hour`,`minute`,`second`)
    /// from the given unix timestamp.
    /// Note: Inputs outside the supported ranges result in undefined behavior.
    /// Use {isSupportedTimestamp} to check if the inputs are supported.
    function timestampToDateTime(uint256 timestamp)
        internal
        pure
        returns (
            uint256 year,
            uint256 month,
            uint256 day,
            uint256 hour,
            uint256 minute,
            uint256 second
        )
    {
        unchecked {
            (year, month, day) = epochDayToDate(timestamp / 86400);
            uint256 secs = timestamp % 86400;
            hour = secs / 3600;
            secs = secs % 3600;
            minute = secs / 60;
            second = secs % 60;
        }
    }

    /// @dev Returns if the `year` is leap.
    function isLeapYear(uint256 year) internal pure returns (bool leap) {
        /// @solidity memory-safe-assembly
        assembly {
            leap := iszero(and(add(mul(iszero(mod(year, 25)), 12), 3), year))
        }
    }

    /// @dev Returns number of days in given `month` of `year`.
    function daysInMonth(uint256 year, uint256 month) internal pure returns (uint256 result) {
        bool flag = isLeapYear(year);
        /// @solidity memory-safe-assembly
        assembly {
            // `daysInMonths = [31,28,31,30,31,30,31,31,30,31,30,31]`.
            // `result = daysInMonths[month - 1] + isLeapYear(year)`.
            result :=
                add(byte(month, shl(152, 0x1f1c1f1e1f1e1f1f1e1f1e1f)), and(eq(month, 2), flag))
        }
    }

    /// @dev Returns the weekday from the unix timestamp.
    /// Monday: 1, Tuesday: 2, ....., Sunday: 7.
    function weekday(uint256 timestamp) internal pure returns (uint256 result) {
        unchecked {
            result = ((timestamp / 86400 + 3) % 7) + 1;
        }
    }

    /// @dev Returns if (`year`,`month`,`day`) is a supported date.
    /// - `1970 <= year <= MAX_SUPPORTED_YEAR`.
    /// - `1 <= month <= 12`.
    /// - `1 <= day <= daysInMonth(year, month)`.
    function isSupportedDate(uint256 year, uint256 month, uint256 day)
        internal
        pure
        returns (bool result)
    {
        uint256 md = daysInMonth(year, month);
        /// @solidity memory-safe-assembly
        assembly {
            result :=
                and(
                    lt(sub(year, 1970), sub(MAX_SUPPORTED_YEAR, 1969)),
                    and(lt(sub(month, 1), 12), lt(sub(day, 1), md))
                )
        }
    }

    /// @dev Returns if (`year`,`month`,`day`,`hour`,`minute`,`second`) is a supported date time.
    /// - `1970 <= year <= MAX_SUPPORTED_YEAR`.
    /// - `1 <= month <= 12`.
    /// - `1 <= day <= daysInMonth(year, month)`.
    /// - `hour < 24`.
    /// - `minute < 60`.
    /// - `second < 60`.
    function isSupportedDateTime(
        uint256 year,
        uint256 month,
        uint256 day,
        uint256 hour,
        uint256 minute,
        uint256 second
    ) internal pure returns (bool result) {
        if (isSupportedDate(year, month, day)) {
            /// @solidity memory-safe-assembly
            assembly {
                result := and(lt(hour, 24), and(lt(minute, 60), lt(second, 60)))
            }
        }
    }

    /// @dev Returns if `epochDay` is a supported unix epoch day.
    function isSupportedEpochDay(uint256 epochDay) internal pure returns (bool result) {
        unchecked {
            result = epochDay < MAX_SUPPORTED_EPOCH_DAY + 1;
        }
    }

    /// @dev Returns if `timestamp` is a supported unix timestamp.
    function isSupportedTimestamp(uint256 timestamp) internal pure returns (bool result) {
        unchecked {
            result = timestamp < MAX_SUPPORTED_TIMESTAMP + 1;
        }
    }

    /// @dev Returns the unix timestamp of the given `n`th weekday `wd`, in `month` of `year`.
    /// Example: 3rd Friday of Feb 2022 is `nthWeekdayInMonthOfYearTimestamp(2022, 2, 3, 5)`
    /// Note: `n` is 1-indexed for traditional consistency.
    /// Invalid weekdays (i.e. `wd == 0 || wd > 7`) result in undefined behavior.
    function nthWeekdayInMonthOfYearTimestamp(uint256 year, uint256 month, uint256 n, uint256 wd)
        internal
        pure
        returns (uint256 result)
    {
        uint256 d = dateToEpochDay(year, month, 1);
        uint256 md = daysInMonth(year, month);
        /// @solidity memory-safe-assembly
        assembly {
            let diff := sub(wd, add(mod(add(d, 3), 7), 1))
            let date := add(mul(sub(n, 1), 7), add(mul(gt(diff, 6), 7), diff))
            result := mul(mul(86400, add(date, d)), and(lt(date, md), iszero(iszero(n))))
        }
    }

    /// @dev Returns the unix timestamp of the most recent Monday.
    function mondayTimestamp(uint256 timestamp) internal pure returns (uint256 result) {
        uint256 t = timestamp;
        /// @solidity memory-safe-assembly
        assembly {
            let day := div(t, 86400)
            result := mul(mul(sub(day, mod(add(day, 3), 7)), 86400), gt(t, 345599))
        }
    }

    /// @dev Returns whether the unix timestamp falls on a Saturday or Sunday.
    /// To check whether it is a week day, just take the negation of the result.
    function isWeekEnd(uint256 timestamp) internal pure returns (bool result) {
        result = weekday(timestamp) > FRI;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*              DATE TIME ARITHMETIC OPERATIONS               */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Adds `numYears` to the unix timestamp, and returns the result.
    /// Note: The result will share the same Gregorian calendar month,
    /// but different Gregorian calendar years for non-zero `numYears`.
    /// If the Gregorian calendar month of the result has less days
    /// than the Gregorian calendar month day of the `timestamp`,
    /// the result's month day will be the maximum possible value for the month.
    /// (e.g. from 29th Feb to 28th Feb)
    function addYears(uint256 timestamp, uint256 numYears) internal pure returns (uint256 result) {
        (uint256 year, uint256 month, uint256 day) = epochDayToDate(timestamp / 86400);
        result = _offsetted(year + numYears, month, day, timestamp);
    }

    /// @dev Adds `numMonths` to the unix timestamp, and returns the result.
    /// Note: If the Gregorian calendar month of the result has less days
    /// than the Gregorian calendar month day of the `timestamp`,
    /// the result's month day will be the maximum possible value for the month.
    /// (e.g. from 29th Feb to 28th Feb)
    function addMonths(uint256 timestamp, uint256 numMonths)
        internal
        pure
        returns (uint256 result)
    {
        (uint256 year, uint256 month, uint256 day) = epochDayToDate(timestamp / 86400);
        month = _sub(month + numMonths, 1);
        result = _offsetted(year + month / 12, _add(month % 12, 1), day, timestamp);
    }

    /// @dev Adds `numDays` to the unix timestamp, and returns the result.
    function addDays(uint256 timestamp, uint256 numDays) internal pure returns (uint256 result) {
        result = timestamp + numDays * 86400;
    }

    /// @dev Adds `numHours` to the unix timestamp, and returns the result.
    function addHours(uint256 timestamp, uint256 numHours) internal pure returns (uint256 result) {
        result = timestamp + numHours * 3600;
    }

    /// @dev Adds `numMinutes` to the unix timestamp, and returns the result.
    function addMinutes(uint256 timestamp, uint256 numMinutes)
        internal
        pure
        returns (uint256 result)
    {
        result = timestamp + numMinutes * 60;
    }

    /// @dev Adds `numSeconds` to the unix timestamp, and returns the result.
    function addSeconds(uint256 timestamp, uint256 numSeconds)
        internal
        pure
        returns (uint256 result)
    {
        result = timestamp + numSeconds;
    }

    /// @dev Subtracts `numYears` from the unix timestamp, and returns the result.
    /// Note: The result will share the same Gregorian calendar month,
    /// but different Gregorian calendar years for non-zero `numYears`.
    /// If the Gregorian calendar month of the result has less days
    /// than the Gregorian calendar month day of the `timestamp`,
    /// the result's month day will be the maximum possible value for the month.
    /// (e.g. from 29th Feb to 28th Feb)
    function subYears(uint256 timestamp, uint256 numYears) internal pure returns (uint256 result) {
        (uint256 year, uint256 month, uint256 day) = epochDayToDate(timestamp / 86400);
        result = _offsetted(year - numYears, month, day, timestamp);
    }

    /// @dev Subtracts `numYears` from the unix timestamp, and returns the result.
    /// Note: If the Gregorian calendar month of the result has less days
    /// than the Gregorian calendar month day of the `timestamp`,
    /// the result's month day will be the maximum possible value for the month.
    /// (e.g. from 29th Feb to 28th Feb)
    function subMonths(uint256 timestamp, uint256 numMonths)
        internal
        pure
        returns (uint256 result)
    {
        (uint256 year, uint256 month, uint256 day) = epochDayToDate(timestamp / 86400);
        uint256 yearMonth = _totalMonths(year, month) - _add(numMonths, 1);
        result = _offsetted(yearMonth / 12, _add(yearMonth % 12, 1), day, timestamp);
    }

    /// @dev Subtracts `numDays` from the unix timestamp, and returns the result.
    function subDays(uint256 timestamp, uint256 numDays) internal pure returns (uint256 result) {
        result = timestamp - numDays * 86400;
    }

    /// @dev Subtracts `numHours` from the unix timestamp, and returns the result.
    function subHours(uint256 timestamp, uint256 numHours) internal pure returns (uint256 result) {
        result = timestamp - numHours * 3600;
    }

    /// @dev Subtracts `numMinutes` from the unix timestamp, and returns the result.
    function subMinutes(uint256 timestamp, uint256 numMinutes)
        internal
        pure
        returns (uint256 result)
    {
        result = timestamp - numMinutes * 60;
    }

    /// @dev Subtracts `numSeconds` from the unix timestamp, and returns the result.
    function subSeconds(uint256 timestamp, uint256 numSeconds)
        internal
        pure
        returns (uint256 result)
    {
        result = timestamp - numSeconds;
    }

    /// @dev Returns the difference in Gregorian calendar years
    /// between `fromTimestamp` and `toTimestamp`.
    /// Note: Even if the true time difference is less than a year,
    /// the difference can be non-zero is the timestamps are
    /// from different Gregorian calendar years
    function diffYears(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        toTimestamp - fromTimestamp;
        (uint256 fromYear,,) = epochDayToDate(fromTimestamp / 86400);
        (uint256 toYear,,) = epochDayToDate(toTimestamp / 86400);
        result = _sub(toYear, fromYear);
    }

    /// @dev Returns the difference in Gregorian calendar months
    /// between `fromTimestamp` and `toTimestamp`.
    /// Note: Even if the true time difference is less than a month,
    /// the difference can be non-zero is the timestamps are
    /// from different Gregorian calendar months.
    function diffMonths(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        toTimestamp - fromTimestamp;
        (uint256 fromYear, uint256 fromMonth,) = epochDayToDate(fromTimestamp / 86400);
        (uint256 toYear, uint256 toMonth,) = epochDayToDate(toTimestamp / 86400);
        result = _sub(_totalMonths(toYear, toMonth), _totalMonths(fromYear, fromMonth));
    }

    /// @dev Returns the difference in days between `fromTimestamp` and `toTimestamp`.
    function diffDays(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        result = (toTimestamp - fromTimestamp) / 86400;
    }

    /// @dev Returns the difference in hours between `fromTimestamp` and `toTimestamp`.
    function diffHours(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        result = (toTimestamp - fromTimestamp) / 3600;
    }

    /// @dev Returns the difference in minutes between `fromTimestamp` and `toTimestamp`.
    function diffMinutes(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        result = (toTimestamp - fromTimestamp) / 60;
    }

    /// @dev Returns the difference in seconds between `fromTimestamp` and `toTimestamp`.
    function diffSeconds(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        result = toTimestamp - fromTimestamp;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Unchecked arithmetic for computing the total number of months.
    function _totalMonths(uint256 numYears, uint256 numMonths)
        private
        pure
        returns (uint256 total)
    {
        unchecked {
            total = numYears * 12 + numMonths;
        }
    }

    /// @dev Unchecked arithmetic for adding two numbers.
    function _add(uint256 a, uint256 b) private pure returns (uint256 c) {
        unchecked {
            c = a + b;
        }
    }

    /// @dev Unchecked arithmetic for subtracting two numbers.
    function _sub(uint256 a, uint256 b) private pure returns (uint256 c) {
        unchecked {
            c = a - b;
        }
    }

    /// @dev Returns the offsetted timestamp.
    function _offsetted(uint256 year, uint256 month, uint256 day, uint256 timestamp)
        private
        pure
        returns (uint256 result)
    {
        uint256 dm = daysInMonth(year, month);
        if (day >= dm) {
            day = dm;
        }
        result = dateToEpochDay(year, month, day) * 86400 + (timestamp % 86400);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

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

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {CREATE3} from "solady/src/utils/CREATE3.sol";
import {ERC4626} from "solady/src/tokens/ERC4626.sol";

import {ERC4626Connector} from "./ERC4626Connector.sol";
import {VaultConnector} from "./VaultConnector.sol";

import {Errors} from "../../Errors.sol";

contract DefaultConnectorFactory {
    address internal immutable _i_WETH;

    constructor(address WETH) {
        _i_WETH = WETH;
    }

    function getOrCreateConnector(address target, address asset) public returns (VaultConnector) {
        (bool success, bytes memory result) = target.staticcall(abi.encodeWithSelector(ERC4626.asset.selector));
        if (!success || target.code.length == 0) revert Errors.DefaultConnectorFactory_TargetNotERC4626();
        if (asset != abi.decode(result, (address))) revert Errors.DefaultConnectorFactory_InvalidToken();

        bytes32 salt = bytes32(uint256(uint160(target)));
        address connectorAddress = CREATE3.predictDeterministicAddress(salt);

        if (connectorAddress.code.length == 0) {
            bytes memory creationCode =
                abi.encodePacked(type(ERC4626Connector).creationCode, abi.encode(target, _i_WETH));
            CREATE3.deployDeterministic(creationCode, salt);
        }

        return VaultConnector(connectorAddress);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Reentrancy guard mixin (transient storage variant).
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/ReentrancyGuardTransient.sol)
///
/// @dev Note: This implementation utilizes the `TSTORE` and `TLOAD` opcodes.
/// Please ensure that the chain you are deploying on supports them.
abstract contract ReentrancyGuardTransient {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Unauthorized reentrant call.
    error Reentrancy();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Equivalent to: `uint32(bytes4(keccak256("Reentrancy()"))) | 1 << 71`.
    /// 9 bytes is large enough to avoid collisions in practice,
    /// but not too large to result in excessive bytecode bloat.
    uint256 private constant _REENTRANCY_GUARD_SLOT = 0x8000000000ab143c06;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      REENTRANCY GUARD                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Guards a function from reentrancy.
    modifier nonReentrant() virtual {
        if (_useTransientReentrancyGuardOnlyOnMainnet()) {
            uint256 s = _REENTRANCY_GUARD_SLOT;
            if (block.chainid == 1) {
                /// @solidity memory-safe-assembly
                assembly {
                    if tload(s) {
                        mstore(0x00, s) // `Reentrancy()`.
                        revert(0x1c, 0x04)
                    }
                    tstore(s, address())
                }
            } else {
                /// @solidity memory-safe-assembly
                assembly {
                    if eq(sload(s), address()) {
                        mstore(0x00, s) // `Reentrancy()`.
                        revert(0x1c, 0x04)
                    }
                    sstore(s, address())
                }
            }
        } else {
            /// @solidity memory-safe-assembly
            assembly {
                if tload(_REENTRANCY_GUARD_SLOT) {
                    mstore(0x00, 0xab143c06) // `Reentrancy()`.
                    revert(0x1c, 0x04)
                }
                tstore(_REENTRANCY_GUARD_SLOT, address())
            }
        }
        _;
        if (_useTransientReentrancyGuardOnlyOnMainnet()) {
            uint256 s = _REENTRANCY_GUARD_SLOT;
            if (block.chainid == 1) {
                /// @solidity memory-safe-assembly
                assembly {
                    tstore(s, 0)
                }
            } else {
                /// @solidity memory-safe-assembly
                assembly {
                    sstore(s, s)
                }
            }
        } else {
            /// @solidity memory-safe-assembly
            assembly {
                tstore(_REENTRANCY_GUARD_SLOT, 0)
            }
        }
    }

    /// @dev Guards a view function from read-only reentrancy.
    modifier nonReadReentrant() virtual {
        if (_useTransientReentrancyGuardOnlyOnMainnet()) {
            uint256 s = _REENTRANCY_GUARD_SLOT;
            if (block.chainid == 1) {
                /// @solidity memory-safe-assembly
                assembly {
                    if tload(s) {
                        mstore(0x00, s) // `Reentrancy()`.
                        revert(0x1c, 0x04)
                    }
                }
            } else {
                /// @solidity memory-safe-assembly
                assembly {
                    if eq(sload(s), address()) {
                        mstore(0x00, s) // `Reentrancy()`.
                        revert(0x1c, 0x04)
                    }
                }
            }
        } else {
            /// @solidity memory-safe-assembly
            assembly {
                if tload(_REENTRANCY_GUARD_SLOT) {
                    mstore(0x00, 0xab143c06) // `Reentrancy()`.
                    revert(0x1c, 0x04)
                }
            }
        }
        _;
    }

    /// @dev For widespread compatibility with L2s.
    /// Only Ethereum mainnet is expensive anyways.
    function _useTransientReentrancyGuardOnlyOnMainnet() internal view virtual returns (bool) {
        return true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Deterministic deployments agnostic to the initialization code.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/CREATE3.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/CREATE3.sol)
/// @author Modified from 0xSequence (https://github.com/0xSequence/create3/blob/master/contracts/Create3.sol)
library CREATE3 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Unable to deploy the contract.
    error DeploymentFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      BYTECODE CONSTANTS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * -------------------------------------------------------------------+
     * Opcode      | Mnemonic         | Stack        | Memory             |
     * -------------------------------------------------------------------|
     * 36          | CALLDATASIZE     | cds          |                    |
     * 3d          | RETURNDATASIZE   | 0 cds        |                    |
     * 3d          | RETURNDATASIZE   | 0 0 cds      |                    |
     * 37          | CALLDATACOPY     |              | [0..cds): calldata |
     * 36          | CALLDATASIZE     | cds          | [0..cds): calldata |
     * 3d          | RETURNDATASIZE   | 0 cds        | [0..cds): calldata |
     * 34          | CALLVALUE        | value 0 cds  | [0..cds): calldata |
     * f0          | CREATE           | newContract  | [0..cds): calldata |
     * -------------------------------------------------------------------|
     * Opcode      | Mnemonic         | Stack        | Memory             |
     * -------------------------------------------------------------------|
     * 67 bytecode | PUSH8 bytecode   | bytecode     |                    |
     * 3d          | RETURNDATASIZE   | 0 bytecode   |                    |
     * 52          | MSTORE           |              | [0..8): bytecode   |
     * 60 0x08     | PUSH1 0x08       | 0x08         | [0..8): bytecode   |
     * 60 0x18     | PUSH1 0x18       | 0x18 0x08    | [0..8): bytecode   |
     * f3          | RETURN           |              | [0..8): bytecode   |
     * -------------------------------------------------------------------+
     */

    /// @dev The proxy initialization code.
    uint256 private constant _PROXY_INITCODE = 0x67363d3d37363d34f03d5260086018f3;

    /// @dev Hash of the `_PROXY_INITCODE`.
    /// Equivalent to `keccak256(abi.encodePacked(hex"67363d3d37363d34f03d5260086018f3"))`.
    bytes32 internal constant PROXY_INITCODE_HASH =
        0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      CREATE3 OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Deploys `initCode` deterministically with a `salt`.
    /// Returns the deterministic address of the deployed contract,
    /// which solely depends on `salt`.
    function deployDeterministic(bytes memory initCode, bytes32 salt)
        internal
        returns (address deployed)
    {
        deployed = deployDeterministic(0, initCode, salt);
    }

    /// @dev Deploys `initCode` deterministically with a `salt`.
    /// The deployed contract is funded with `value` (in wei) ETH.
    /// Returns the deterministic address of the deployed contract,
    /// which solely depends on `salt`.
    function deployDeterministic(uint256 value, bytes memory initCode, bytes32 salt)
        internal
        returns (address deployed)
    {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, _PROXY_INITCODE) // Store the `_PROXY_INITCODE`.
            let proxy := create2(0, 0x10, 0x10, salt)
            if iszero(proxy) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x14, proxy) // Store the proxy's address.
            // 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ proxy ++ 0x01).
            // 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex).
            mstore(0x00, 0xd694)
            mstore8(0x34, 0x01) // Nonce of the proxy contract (1).
            deployed := keccak256(0x1e, 0x17)
            if iszero(
                mul( // The arguments of `mul` are evaluated last to first.
                    extcodesize(deployed),
                    call(gas(), proxy, value, add(initCode, 0x20), mload(initCode), 0x00, 0x00)
                )
            ) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Returns the deterministic address for `salt`.
    function predictDeterministicAddress(bytes32 salt) internal view returns (address deployed) {
        deployed = predictDeterministicAddress(salt, address(this));
    }

    /// @dev Returns the deterministic address for `salt` with `deployer`.
    function predictDeterministicAddress(bytes32 salt, address deployer)
        internal
        pure
        returns (address deployed)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x00, deployer) // Store `deployer`.
            mstore8(0x0b, 0xff) // Store the prefix.
            mstore(0x20, salt) // Store the salt.
            mstore(0x40, PROXY_INITCODE_HASH) // Store the bytecode hash.

            mstore(0x14, keccak256(0x0b, 0x55)) // Store the proxy's address.
            mstore(0x40, m) // Restore the free memory pointer.
            // 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ proxy ++ 0x01).
            // 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex).
            mstore(0x00, 0xd694)
            mstore8(0x34, 0x01) // Nonce of the proxy contract (1).
            deployed := keccak256(0x1e, 0x17)
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {ERC4626} from "solady/src/tokens/ERC4626.sol";
import {ERC20} from "solady/src/tokens/ERC20.sol";

import "../../Constants.sol" as Constants;
import {Token} from "../../Types.sol";
import {Errors} from "../../Errors.sol";

import {VaultConnector} from "./VaultConnector.sol";

contract ERC4626Connector is VaultConnector {
    ERC20 private immutable _i_asset;
    ERC4626 private immutable _i_target;
    address private immutable _i_WETH;
    bool private immutable _i_isNativeTokenSupported;

    modifier checkAsset(Token token) {
        bool isValidToken = token.unwrap() == asset() || (_i_isNativeTokenSupported && token.isNative());
        if (!isValidToken) revert Errors.ERC4626Connector_InvalidToken();
        _;
    }

    receive() external payable {}

    constructor(address _target, address _WETH) {
        _i_target = ERC4626(_target);
        _i_asset = ERC20(_i_target.asset());
        SafeTransferLib.safeApprove(address(_i_asset), address(_i_target), type(uint256).max);

        _i_WETH = _WETH;
        _i_isNativeTokenSupported = _i_asset == ERC20(_getWETHAddress());
    }

    function asset() public view override returns (address) {
        return address(_i_asset);
    }

    function target() public view override returns (address) {
        return address(_i_target);
    }

    function convertToAssets(uint256 shares) public view override returns (uint256) {
        return _i_target.convertToAssets(shares);
    }

    function convertToShares(uint256 assets) public view override returns (uint256) {
        return _i_target.convertToShares(assets);
    }

    function previewDeposit(Token token, uint256 assets)
        public
        view
        override
        checkAsset(token)
        returns (uint256 shares)
    {
        return _i_target.previewDeposit(assets);
    }

    function previewRedeem(Token token, uint256 shares)
        public
        view
        override
        checkAsset(token)
        returns (uint256 assets)
    {
        return _i_target.previewRedeem(shares);
    }

    function deposit(Token token, uint256 amount, address receiver)
        public
        payable
        override
        checkAsset(token)
        returns (uint256 shares)
    {
        if (token.isNative()) {
            if (msg.value != amount) {
                revert Errors.ERC4626Connector_InvalidETHAmount();
            }
            _wrapETH(amount);
        } else if (msg.value > 0) {
            revert Errors.ERC4626Connector_UnexpectedETH();
        } else {
            SafeTransferLib.safeTransferFrom(token.unwrap(), msg.sender, address(this), amount);
        }
        return _i_target.deposit(amount, receiver);
    }

    function redeem(Token token, uint256 shares, address receiver)
        public
        override
        checkAsset(token)
        returns (uint256 assets)
    {
        bool isNativeToken = token.isNative();
        address _receiver = isNativeToken ? address(this) : receiver;
        assets = _i_target.redeem(shares, _receiver, msg.sender);
        if (isNativeToken) _unwrapWETH(receiver, assets);
    }

    function _getWETHAddress() internal view virtual override returns (address) {
        return _i_WETH;
    }

    function getTokenInList() public view virtual override returns (Token[] memory tokens) {
        bool depositable = _i_target.maxDeposit(address(this)) > 0;
        if (!depositable) {
            tokens = new Token[](1);
            tokens[0] = Token.wrap(target());
            return tokens;
        }

        return _defaultTokenList();
    }

    function getTokenOutList() public view virtual override returns (Token[] memory tokens) {
        // The list doesn't include `asset()` because some ERC4626 have cooldown period for redeeming.
        tokens = new Token[](1);
        tokens[0] = Token.wrap(target());
    }

    /// @dev Default token list for ERC4626 if depositable or redeemable are true.
    function _defaultTokenList() internal view returns (Token[] memory tokens) {
        bool isWETH = asset() == _i_WETH;
        tokens = new Token[](isWETH ? 3 : 2);
        tokens[0] = Token.wrap(target());
        tokens[1] = Token.wrap(asset());
        if (isWETH) tokens[2] = Token.wrap(Constants.NATIVE_ETH);
    }
}

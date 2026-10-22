# Labelling batch 9 (40 contracts)

## 321. Earn
- families: cross_function|forced_revert
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 amount;
```

exposure `_swapToUSDCOnZeroX` (low_level_call, gas-forwarding=True), writes after call: ['amount']

```solidity
function _swapToUSDCOnZeroX(internal returns (uint256)

        uint256 currentUsdcBalance = USDC.balanceOf(address(this));

        require(IERC20(_token).approve(_swapTarget, _amount), "");

         
         
        (bool success, ) = _swapTarget.call{value: msg.value}(_swapCallData);
        require(success, "");

        uint256 usdcAmount = USDC.balanceOf(address(this)) - currentUsdcBalance;
        uint256 interestReserve = calculateInterestReserves(
            usdcAmount,
            earnTerms[_earnTermId].usdcRate
        );
        uint256 amount = usdcAmount - interestReserve;
        USDC.safeTransfer(loanAddress, amount);
        return usdcAmount;
    
}
```

closure `openContractUsdc` (writes exposed state):

```solidity

        EarnTerm memory earnTerm = earnTerms[_earnTermsId];
        require(earnTerm.open);
        require(earnTerm.otherTokens, "");
        if (earnTerm.whitelist) {
             
            require(checkTokenWhitelist(address(USDC), _earnTermsId));
        }

        require(_amount > 0, "");
         
        require(
            USDC.balanceOf(address(msg.sender)) >= _amount,
            ""
        );

        earnTerms[_earnTermsId].usdcAccepted =
            earnTerms[_earnTermsId].usdcAccepted +
            _amount;
        require(
            earnTerms[_earnTermsId].usdcAccepted <=
                (earnTerms[_earnTermsId].usdcMax +
                    (earnTerms[_earnTermsId].usdcMax / 10))
        );

    ... [30 more lines]
```

closure `withdraw` (writes exposed state):

```solidity

        uint256 amount = address(this).balance;
        (bool success, ) = _addr.call{value: amount}("");
        require(success, "");
    
```

---

## 322. RiseToken
- families: cross_function
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 wethLeftFromFlashSwap;
```

exposure `onSell` (low_level_call, gas-forwarding=True), writes after call: ['wethLeftFromFlashSwap']

```solidity
function onSell(internal

         
        (SellParams memory params) = abi.decode(_data, (SellParams));

         
        repayThenRedeem(_debtAmount, params.collateralAmount);

         
        if (address(params.tokenOut) == address(collateral)) {
             
            collateral.safeIncreaseAllowance(address(uniswapAdapter), params.collateralAmount);
            uint256 collateralToBuyWETH = uniswapAdapter.swapTokensForExactWETH(address(collateral), _wethAmount, params.collateralAmount);
            uint256 collateralLeft = params.collateralAmount - collateralToBuyWETH;
            if (collateralLeft < params.amountOutMin) revert SlippageTooHigh();
            collateral.safeTransfer(params.recipient, collateralLeft);
        } else {
             
            collateral.safeIncreaseAllowance(address(uniswapAdapter), params.collateralAmount);
            uint256 wethAmountFromCollateral = uniswapAdapter.swapExactTokensForWETH(address(collateral), params.collateralAmount, 0);
            uint256 wethLeft = wethAmountFromCollateral - _wethAmount;

            if (address(params.tokenOut) == address(0)) {
                if (wethLeft < params.amountOutMin) revert SlippageTooHigh();
                weth.safeIncreaseAllowance(address(weth), wethLeft);
                weth.withdraw(wethLeft);
                (bool sent, ) = params.recipient.call{value: wethLeft}("");
                if (!sent) revert FailedToSendETH(params.recipient, wethLeft);
            }

             
            if (address(params.tokenOut) == address(debt)) {
                wethLeftFromFlashSwap = wethLeft;
            }

            if (address(params.tokenOut) != address(0) && (address(params.tokenOut) != address(debt))) {
                weth.safeIncreaseAllowance(address(uniswapAdapter), wethLeft);
                uint256 amountOut = uniswapAdapter.swapExactWETHForTokens(address(params.tokenOut), wethLeft, params.amountOutMin);
                params.tokenOut.safeTransfer(params.recipient, amountOut);
            }
        }
    ... [9 more lines]
}
```

closure `sell` (writes exposed state):

```solidity

        if (!isInitialized) revert NotInitialized();

        uint256 fee = ((fees * _shares) / 1e18);
        uint256 newShares = _shares - fee;
        SellParams memory params = SellParams({
            seller: msg.sender,
            recipient: _recipient,
            tokenOut: ERC20(_tokenOut),
            amountOutMin: _amountOutMin,
            shares: _shares,
            collateralAmount: (newShares * collateralPerShare()) / (10**cdecimals),
            debtAmount: (newShares * debtPerShare()) / (10**cdecimals),
            fee: fee,
            nav: nav()
        });

         
        bytes memory data = abi.encode(FlashSwapType.Sell, abi.encode(params));
        uniswapAdapter.flashSwapWETHForExactTokens(address(debt), params.debtAmount, data);

        if (address(params.tokenOut) == address(debt)) {
            weth.safeIncreaseAllowance(address(uniswapAdapter), wethLeftFromFlashSwap);
            uint256 amountOut = uniswapAdapter.swapExactWETHForTokens(address(params.tokenOut), wethLeftFromFlashSwap, params.amountOutMin);
            params.tokenOut.safeTransfer(params.recipient, amountOut);
    ... [3 more lines]
```

---

## 323. ChainBreaker
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (bytes32 => bool) _burntHash;
    mapping (bytes32 => bool) _store;
```

exposure `WITHDRAW` (low_level_call, gas-forwarding=True), writes after call: ['_burntHash', '_store']

```solidity
function WITHDRAW(public noReentrancy returns (bool)

        
        
        
         
        
        bytes32 hashedValue = bytes32(keccak256(abi.encodePacked(password)));

         
        
        uint256 sentAmountFromUser = sentAmount[hashedValue];

         
        
        require (sentAmountFromUser > 0);
        
         

        require(!_burntHash[hashedValue]);
         
          

        require(_store[hashedValue], "");
        
         

        uint256 totalToSendToUser = calculateFeeOverTransaction(sentAmountFromUser);

         
         
        (bool success,) = address(msg.sender).call{value : totalToSendToUser}("");
        
         
        _store[hashedValue] = false;
        
         

        _burntHash[hashedValue] = true;

        return success;
    ... [1 more lines]
}
```

closure `DEPOSIT` (writes exposed state):

```solidity

        
         

        require (masterSwitchDeposit == true);

        

       require(checkTokenOfUser(msg.sender));

        
       require(msg.value == fixedAmount01 || msg.value == fixedAmount05 || msg.value == fixedAmount1); 

         

        sentAmount[hashedPasswordManuallyTyped] = msg.value;

         
        _balance[msg.sender] = msg.value;

        require(!_burntHash[hashedPasswordManuallyTyped]);
        
         

        require(_balance[msg.sender] > 0);
    ... [10 more lines]
```

---

## 324. Wallet
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 lastSubscriptionPaymentTimestamp;
```

exposure `subscriptionPayments` (low_level_call, gas-forwarding=True), writes after call: ['lastSubscriptionPaymentTimestamp']

```solidity
function subscriptionPayments(external

        require(subscriptionPaymentsEnabled, "");
        uint256 cycles = (block.timestamp - lastSubscriptionPaymentTimestamp) / SUBSCRIPTION_PAYMENT_INTERVAL_SECONDS;
        require(cycles > 0, "");
        uint256 amount = SUBSCRIPTION_PAYMENT_AMOUNT * cycles;
        require(address(this).balance > 0, "");
        if (amount > address(this).balance) amount = address(this).balance;
        (bool success, ) = walletFactory.relayGuardianManager().call{value: amount}("");
        require(success, "");
        lastSubscriptionPaymentTimestamp = block.timestamp;
    
}
```

closure `initialize` (writes exposed state):

```solidity

         
        require(threshold == 0, "");

         
        require(signers.length > 0, "");
        require(signers.length == _signerConfigs.length, "");
        require(_threshold > 0, "");

         
        for (uint256 i = 0; i < _signerConfigs.length; i++) {
            signerConfigs[signers[i]] = _signerConfigs[i];
            emit SignerConfigChanged(signers[i], _signerConfigs[i]);
        }

        threshold = _threshold;
        relayerWhitelistTimelock = _relayerWhitelistTimelock;
        subscriptionPaymentsEnabled = _subscriptionPaymentsEnabled;

         
        walletFactory = WalletFactory(msg.sender);

         
        if (_subscriptionPaymentsEnabled) lastSubscriptionPaymentTimestamp = block.timestamp - SUBSCRIPTION_PAYMENT_INTERVAL_SECONDS;
    
```

closure `setSubscriptionPaymentsEnabled` (writes exposed state):

```solidity

        require(subscriptionPaymentsEnabled != enabled, "");
        address relayGuardian = walletFactory.relayGuardian();
         
        require(msg.sender == relayGuardian || msg.sender == walletFactory.secondaryRelayGuardian() ||
            (msg.sender == address(this) && (enabled || (relayerWhitelistTimelock > 0 && relayGuardian != address(0)))), "");
        subscriptionPaymentsEnabled = enabled;
        if (enabled) lastSubscriptionPaymentTimestamp = block.timestamp - SUBSCRIPTION_PAYMENT_INTERVAL_SECONDS + secondsPaidForAlready;
    
```

---

## 325. EnderDragon
- families: cross_function|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 swapThreshold;
    bool thresholdIncreasing;
```

exposure `swapBack` (low_level_call, gas-forwarding=True), writes after call: ['swapThreshold', 'thresholdIncreasing']

```solidity
function swapBack(internal swapping

        uint256 amountToBurn = totalFee > 0 ? swapThreshold.mul(burnFee).div(totalFee) : 0;
        if (amountToBurn > 0) {
            _basicTransfer(address(this), DEAD, amountToBurn);
        }
        uint256 amountToSwap = swapThreshold - amountToBurn;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountETH = address(this).balance;
        uint256 amountETHMarketing = totalFee > 0 ? amountETH.mul(marketingFee).div(totalFee) : amountETH;

        (bool success,) = payable(marketingFeeReceiver).call{value: amountETHMarketing, gas: 30000}("");
        require(success, "");
        
        thresholdIncreasing = swapThreshold > _totalSupply.mul(14).div(1000) ? false : swapThreshold < _totalSupply.mul(7).div(1000) ? true : thresholdIncreasing;
        swapThreshold = thresholdIncreasing ? swapThreshold.mul(103).div(100) : swapThreshold.mul(97).div(100);
    
}
```

closure `setSwapBackSettings` (writes exposed state):

```solidity

        require(isMaxWalletExempt[msg.sender]);
        swapThreshold = _amount;
        swapEnabled = _enabled;
    
```

---

## 326. AnbotoExecV2
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(bytes => uint256) orderFulfilledAmount;
```

exposure `executeOrder` (low_level_call, gas-forwarding=True), writes after call: ['orderFulfilledAmount']

```solidity
function executeOrder(external

         
        require(
            msg.sender == owner() || isAnboto[msg.sender],
            ""
        );
        validateOrder(_order, _maker, _sig);
        require(
            exchangeAllowlist[_quote.swapTarget],
            ""
        );
        require(
            tx.gasprice <= _order.maxGasPrice,
            ""
        );

         
        uint256 sliceInputAmount = _quote.sellAmount;
        IERC20 inputToken = _order.inputToken;
        IERC20 outputToken = _order.outputToken;

         
        orderFulfilledAmount[_sig] += sliceInputAmount;
        checkOrderTotal(_order, _sig);

         
        uint256 swapInputBalance = inputToken.balanceOf(address(this));
        uint256 swapOutputBalance = outputToken.balanceOf(address(this));

         
        inputToken.safeTransferFrom(_maker, address(this), sliceInputAmount);
        inputToken.safeApprove(_quote.spender, sliceInputAmount);
        {
             
            (bool success, bytes memory data) = _quote.swapTarget.call(
                _quote.swapCallData
            );
            if (!success) revert(getRevertMsg(data));
        }

    ... [32 more lines]
}
```

closure `settleCow` (writes exposed state):

```solidity

         
        require(
            msg.sender == cowSettlementContract,
            ""
        );
        require(
             
            tx.origin == anbotoCowSolver,
            ""
        );
        validateOrder(_order, _maker, _sig);

         
        IERC20 inputToken = _order.inputToken;
        IERC20 outputToken = _order.outputToken;
        uint256 sellAmount = _settlement.sellAmount;
        uint256 buyAmount = _settlement.buyAmount;

         
        orderFulfilledAmount[_sig] += sellAmount;
        checkOrderTotal(_order, _sig);
        checkOutputAmount(_order, sellAmount, buyAmount);

         
    ... [18 more lines]
```

---

## 327. Nocturnal
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 availableSupply;
    uint lastTokenId;
```

exposure `mintBatch` (low_level_call, gas-forwarding=True), writes after call: ['availableSupply', 'lastTokenId']

```solidity
function mintBatch(external payable withinMintWindow

      require(userMinted[msg.sender] + amount <= maxMintPerUser, "");

      require(msg.value == (mintPrice + mintFee) * amount, "");
      require(availableSupply >= amount, "");

      userMinted[msg.sender] += amount;

      for(uint i = lastTokenId + 1; i <= lastTokenId + amount; i++) {
          _safeMint(msg.sender, i);
      }

      (bool success, ) = moneyReceiver.call{value: address(this).balance}("");
      if(!success) {
          emit ErrorMoneySend();
      }

      availableSupply-= amount;
      lastTokenId+= amount;
  
}
```

closure `mintBatchOwnable` (writes exposed state):

```solidity

        for(uint i = lastTokenId + 1; i <= lastTokenId + amount; i++) {
            _safeMint(msg.sender, i);
        }
        availableSupply-= amount;
        lastTokenId+= amount;
    
```

---

## 328. SendValueWithFallbackWithdraw
- families: cross_function|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) pendingWithdrawals;
```

exposure `_sendValueWithFallbackWithdraw` (low_level_call, gas-forwarding=True), writes after call: ['pendingWithdrawals']

```solidity
function _sendValueWithFallbackWithdraw(private

    if (amount == 0) {
      return;
    }
     
     
    (bool success, ) = user.call{ value: amount, gas: gasLimit }("");
    if (!success) {
       
       
      pendingWithdrawals[user] += amount;
      emit WithdrawPending(user, amount);
    }
  
}
```

closure `withdrawFor` (writes exposed state):

```solidity

    uint256 amount = pendingWithdrawals[user];
    require(amount > 0, "");
    pendingWithdrawals[user] = 0;
    user.sendValue(amount);
    emit Withdrawal(user, amount);
  
```

observing view `getPendingWithdrawal`:

```solidity

    return pendingWithdrawals[user];
  
```

---

## 329. MakeApesGreatAgain
- families: cross_function
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 swapThreshold;
```

exposure `swapBack` (low_level_call, gas-forwarding=True), writes after call: ['swapThreshold']

```solidity
function swapBack(internal swapping

        uint256 dynamicLiquidityFee = isOverLiquified(targetLiquidity, targetLiquidityDenominator) ? 0 : liquidityFeeSell;
        uint256 _totalFee = totalFeeSell.sub(reflectionFeeSell);
        uint256 amountToLiquify = swapThreshold.mul(dynamicLiquidityFee).div(_totalFee).div(2);
        uint256 amountToSwap = swapThreshold.sub(amountToLiquify);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;

        uint256 balanceBefore = address(this).balance;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountETH = address(this).balance.sub(balanceBefore);

        uint256 totalETHFee = _totalFee.sub(dynamicLiquidityFee.div(2));
        uint256 amountETHLiquidity = amountETH.mul(liquidityFeeSell).div(totalETHFee).div(2);
        uint256 amountETHMarketing = amountETH.mul(marketingFeeSell).div(totalETHFee);
        uint256 amountETHTeam = amountETH.mul(TeamFeeSell).div(totalETHFee);

        (bool tmpSuccess,) = payable(marketingFeeReceiver).call{value: amountETHMarketing, gas: 30000}("");
        (tmpSuccess,) = payable(TeamFeeReceiver).call{value: amountETHTeam, gas: 30000}("");
        
        

        if(amountToLiquify > 0) {
            router.addLiquidityETH{value: amountETHLiquidity}(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLiquidityReceiver,
                block.timestamp
    ... [6 more lines]
}
```

closure `setSwapBackSettings` (writes exposed state):

```solidity

        alternateSwaps = _alternate;
        claimingFees = _enabled;
        smallSwapThreshold = _amountS;
        largeSwapThreshold = _amountL;
        swapThreshold = smallSwapThreshold;
    
```

---

## 330. StrategyPETHConvex
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 earned;
```

exposure `harvest` (low_level_call, gas-forwarding=True), writes after call: ['earned']

```solidity
function harvest(external onlyRole(STRATEGIST_ROLE)

        convexConfig.baseRewardPool.getReward(address(this), true);
        
        uint256 ethBalance;
         
        {
            uint256 cvxBalance = strategyTokens.cvx.balanceOf(address(this));
            if (cvxBalance > 0) {
                CurveConfig memory _cvxEth = cvxEth;
                 
                _cvxEth.lp.exchange(
                    1 - _cvxEth.ethIndex,
                    _cvxEth.ethIndex,
                    cvxBalance,
                    0,
                    true
                );
            }

            uint256 crvBalance = strategyTokens.crv.balanceOf(address(this));
            if (crvBalance > 0) {
                CurveConfig memory _crvEth = crvEth;
                 
                _crvEth.lp.exchange(
                    1 - _crvEth.ethIndex,
                    _crvEth.ethIndex,
                    crvBalance,
                    0,
                    true
                );
            }

            ethBalance = address(this).balance;
            require(ethBalance != 0, "");

        }

        StrategyConfig memory strategy = strategyConfig;

         
    ... [43 more lines]
}
```

---

## 331. HotoDoge
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 4 | sites: 4 | loops: 0

state (exposed only):
```solidity
    mapping(uint16 => bool) cashReady;
    uint256 preCash;
    mapping(address => uint8) whiteListSales;
```

exposure `claimCash` (low_level_call, gas-forwarding=True), writes after call: ['cashReady']

```solidity
function claimCash(external onlyEOA nonReentrant

        require(ownerOf(tokenId) == msg.sender, "");
        require(publish[64].published, "");

        if (!cashReady[uint16(tokenId)]) revert("");

        uint256 _cash = 0;
        uint256 count = finalWinners.length;

         
        for (uint256 i = 0; i < count; i++)
            if (finalWinners[i] == tokenId) {
                _cash += pool.mul(35).div(100).div(count);
                break;
            }

         
        (bool success, ) = msg.sender.call{value: _cash}("");
        require(success, "");

        cashReady[uint16(tokenId)] = false;
        emit cashedOut(msg.sender, tokenId, _cash);
    
}
```

exposure `whitelistMint` (low_level_call, gas-forwarding=True), writes after call: ['whiteListSales']

```solidity
function whitelistMint(external
        payable
        onlyEOA
        nonReentran

        require(isWhiteListSaleActive(), "");
        require(!isShowTimeStart(), "");
        require(
            whiteListSales[msg.sender] + quantity <= 3,
            ""
        );
        require(nfts.length + quantity <= MAX_SUPPLY, "");

        IERC721 xt = IERC721(
            IDDS(BEE_DDS_ADDRESS).toAddress(
                IDDS(BEE_DDS_ADDRESS).get("", "")
            )
        );

        if (xt.balanceOf(msg.sender) == 0) revert("");

        uint256 cost = _mintPrice.mul(6).div(10).mul(quantity);
        require(msg.value >= cost, "");
        pool += cost;

        _mint(msg.sender, quantity);
        for (uint8 i = 0; i < quantity; i++) nfts.push(0);

         
        if (msg.value > cost) {
             
            (bool success, ) = msg.sender.call{value: msg.value.sub(cost)}("");
            require(success, "");
        }

        whiteListSales[msg.sender] += quantity;
    
}
```

closure `setFinalWinner` (writes exposed state):

```solidity

        require(round == 64, "");
        if (publish[round].published) revert("");

        if (
            publish[round].operator == ZERO ||
            publish[round].operator == msg.sender
        ) {
            publish[round] = Publish(_team, msg.sender, false);
            return;
        }

        if (publish[round].winner != _team) {
            publish[round].operator = msg.sender;
            publish[round].winner = _team;
            return;
        }

        for (uint16 i = 0; i < nfts.length; i++)
            if (uint256(nfts[i] / 300) == _team) {
                airDrops[i] += 1;
                finalWinners.push(i);
                cashReady[i] = true;
            }

    ... [35 more lines]
```

observing view `getCash`:

```solidity

        require(publish[64].published, "");

        if (!cashReady[uint16(tokenId)]) return 0;
         
        uint256 count = finalWinners.length;

         
        for (uint256 i = 0; i < count; i++)
            if (finalWinners[i] == tokenId) {
                _cash += pool.mul(35).div(100).div(count);
                break;
            }
    
```

---

## 332. LiquidCryptoBridge_v2
- families: cross_function|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 totalEarned;
    uint256 totalReward;
```

exposure `_cutFee` (low_level_call, gas-forwarding=True), writes after call: ['totalEarned', 'totalReward']

```solidity
function _cutFee(internal returns(uint256)

    if (_amount > 0) {
      uint256 fee = _amount * swapFee / feeDecimals;
      uint256 treasuryFee = fee * platformFee / feeDecimals;
      if (treasuryFee > 0) {
        (bool success, ) = payable(treasury).call{value: treasuryFee}("");
        require(success, "");
      }
      totalEarned += (fee - treasuryFee);
      totalReward += (fee - treasuryFee);
      return _amount - fee;
    }
    return 0;
  
}
```

closure `claimReward` (writes exposed state):

```solidity

    uint256 userReward = getReward(_account);
    if (userReward < _amount) {
      _amount = userReward;
    }
    if (_amount > address(this).balance) {
      _amount = address(this).balance;
    }

    uint256 _now = block.timestamp;
    StakeInfo storage tmpInfo = userInfo[_account];
    tmpInfo.debtReward = (tmpInfo.debtReward + tmpInfo.amount * (_now - tmpInfo.startedAt)) * (userReward - _amount) / userReward;
    tmpInfo.startedAt = _now;
    uint256 tmpTotalShare = totalUserShare + totalSupply() * (_now - lastTotalTs);
    if (tmpTotalShare < totalUserClaimed) {
      totalUserClaimed = tmpTotalShare;
    }
    else {
     tmpTotalShare -= totalUserClaimed;
     totalUserClaimed += (tmpTotalShare * _amount / totalReward);
    }
    totalReward -= _amount;

    if (_amount > 0) {
      (bool success, ) = payable(_account).call{value: _amount}("");
    ... [5 more lines]
```

observing view `getReward`:

```solidity

    uint256 _now = block.timestamp;
    uint256 tmpTotalShare = totalUserShare + totalSupply() * (_now - lastTotalTs);
    if (tmpTotalShare <= totalUserClaimed) return 0;
    tmpTotalShare -= totalUserClaimed;
    uint256 tmpUserTotal = userInfo[_account].debtReward + userInfo[_account].amount * (_now - userInfo[_account].startedAt);
    return totalReward * tmpUserTotal / tmpTotalShare;
  
```

---

## 333. SistersOfSaturn
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 minted;
    uint256 tokensLeft;
```

exposure `mintToken` (low_level_call, gas-forwarding=True), writes after call: ['minted', 'tokensLeft']

```solidity
function mintToken(public payable

        if(!earlySale && !preSale && !publicSale){
            revert("");
        }
        if(earlySale || preSale){
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(proof, rootHash, leaf), "");
            require(balanceOf(msg.sender) + quantity <= mintLimit, "");
        }

        require(minted + quantity <= _totalSupply,"");
        require( msg.value >= mintPrice * quantity, "");
        (bool success,) = communityWallet.call{value: msg.value}("");
        if(!success) {
            revert("");
        }

                _safeMint(msg.sender, quantity);
                minted += quantity;
                tokensLeft -= quantity;

    
}
```

closure `airdropTokens` (writes exposed state):

```solidity

        
        require(receiver != address(0) && receiver!= 0x000000000000000000000000000000000000dEaD);
        require(minted + quantity <= _totalSupply,"");
        
            minted += quantity;
            _safeMint(receiver, quantity);
            tokensLeft -= quantity;    

    
```

---

## 334. CapsuleMachine
- families: cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(uint256 => bool)) isNFTinCapsule;
```

exposure `fulfillRandomWords` (low_level_call, gas-forwarding=True), writes after call: ['isNFTinCapsule']

```solidity
function fulfillRandomWords(internal override


        s_requestId = requestId;
        s_randomWords = randomWords;

        uint256 _capId = s_requestIdToCapsuleID[requestId];
        Capsule storage c = allCapsules[_capId];
        uint256 resultIndex = randomWords[0] % c.soldPartition;

        if (c.winner == address(0)) {
            address winner = c.buyers[resultIndex];
            c.winner = winner;
            
             
            IERC721 _thisNft = IERC721(c.nftAddr);
            _thisNft.transferFrom(address(this), winner, c.nftId);

             
            uint256 commission = c.betPool * capsuleCommission / 1000;
            uint256 transferAmt = 0;
            if (c.betPool - commission > betFee)
                transferAmt = c.betPool - commission - betFee;

            if (transferAmt > 0) {
                (bool success1, ) = (address(c.host)).call{value: transferAmt }("");
                require(success1, "");
            }
            if (c.betPool - transferAmt > 0) {
                (bool success2, ) = owner().call{value: (c.betPool - transferAmt) }("");
                require(success2, "");
            }
            
            c.betPool = 0;
            isNFTinCapsule[c.nftAddr][c.nftId] = false;

            finishedCapsuleIDs.push(_capId);
            numOfFinishedCapsules++;

            emit CapsuleWon(_capId, c.winner, c.nftAddr, c.nftId);  
        }
    ... [2 more lines]
}
```

closure `setupMachine` (writes exposed state):

```solidity
   
         
        require(isNFTWhitelisted(_assetAddress) == true, "");

         
        IERC721 _thisNFT = IERC721(_assetAddress);
        require(msg.sender == _thisNFT.ownerOf(_tokenId), "");

         
        require(isHostValid(msg.sender), "");

         
        require(isNFTinCapsule[_assetAddress][_tokenId] != true, "");

         
        _thisNFT.transferFrom(msg.sender, address(this), _tokenId);

         
        uint256 _newCapID = allCapsules.length;

        Capsule memory c;  
        c.startTime = block.timestamp;
        c.host = msg.sender;
        c.nftAddr = _assetAddress;
        c.nftId = _tokenId;
    ... [13 more lines]
```

closure `hostClaim` (writes exposed state):

```solidity

         
        Capsule storage c = allCapsules[_capId];
        require(msg.sender == c.host, "");

        require(block.timestamp > c.endTime, "");
        require(c.soldPartition == 0, "");

         
        IERC721 _thisNft = IERC721(c.nftAddr);
        _thisNft.transferFrom(address(this), msg.sender, c.nftId);

        c.winner = msg.sender;
        isNFTinCapsule[c.nftAddr][c.nftId] = false;
        finishedCapsuleIDs.push(_capId);
        numOfFinishedCapsules++;

        emit CapsuleWon(_capId, c.winner, c.nftAddr, c.nftId); 
    
```

---

## 335. SendValueWithFallbackWithdraw
- families: cross_function|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) pendingWithdrawals;
```

exposure `_sendValueWithFallbackWithdraw` (low_level_call, gas-forwarding=True), writes after call: ['pendingWithdrawals']

```solidity
function _sendValueWithFallbackWithdraw(private

        if (amount == 0) {
            return;
        }
         
         
        (bool success, ) = user.call{value: amount, gas: gasLimit}("");
        if (!success) {
             
             
             
            pendingWithdrawals[user] = pendingWithdrawals[user].add(amount);
            emit WithdrawPending(user, amount);
        }
    
}
```

closure `withdrawFor` (writes exposed state):

```solidity

        uint256 amount = pendingWithdrawals[user];
        require(amount > 0, "");
        pendingWithdrawals[user] = 0;
        user.sendValue(amount);
        emit Withdrawal(user, amount);
    
```

observing view `getPendingWithdrawal`:

```solidity

        return pendingWithdrawals[user];
    
```

---

## 336. MCCSwap
- families: classic_reentrancy|cross_function
- closure size: 4 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint256 v2AirdropETHPool;
    mapping(address => bool) v2WasSwapped;
```

exposure `swapV2ForETH` (low_level_call, gas-forwarding=True), writes after call: ['v2WasSwapped']

```solidity
function swapV2ForETH(public

    require(!v2WasSwapped[msg.sender], "");

     
    uint256 mccV2AirdroppedAmount = v2AirdropAmounts[msg.sender];
    if (mccV2AirdroppedAmount > 0) {
      msg.sender.call{
        value: (v2AirdropETHPool * mccV2AirdroppedAmount) / v2TotalAirdropped
      }("");
    }

     
    uint256 mccV2Balance = mccV2.balanceOf(msg.sender);
    if (mccV2Balance > 0) {
      mccV2.transferFrom(msg.sender, address(this), mccV2Balance);
    }

    uint256 mccV2SnapshotBal = v2SnapshotBalances[msg.sender];
    if (mccV2SnapshotBal > 0) {
      uint256 weiToTransfer = getUserOwedETHFromV2(mccV2SnapshotBal);
      require(
        address(this).balance >= weiToTransfer,
        ""
      );
      msg.sender.call{ value: weiToTransfer }("");
    }

    v2WasSwapped[msg.sender] = true;
  
}
```

exposure `removeETHFromV2AirdropPool` (low_level_call, gas-forwarding=True), writes after call: ['v2AirdropETHPool']

```solidity
function removeETHFromV2AirdropPool(external onlyOwner

    require(v2AirdropETHPool > 0, "");

    uint256 _finalAmount = address(this).balance < v2AirdropETHPool
      ? address(this).balance
      : v2AirdropETHPool;
    if (_finalAmount > 0) {
      payable(owner()).call{ value: _finalAmount }("");
    }
    v2AirdropETHPool = 0;
  
}
```

closure `setV2WasSwapped` (writes exposed state):

```solidity

    v2WasSwapped[_wallet] = _didSwap;
  
```

closure `addETHToV2AirdropPool` (writes exposed state):

```solidity

    require(msg.value > 0, "");
    v2AirdropETHPool += msg.value;
    payable(address(this)).call{ value: msg.value }("");
  
```

---

## 337. ETHFaucet
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) claimedAmountForToken;
```

exposure `claim` (low_level_call, gas-forwarding=True), writes after call: ['claimedAmountForToken']

```solidity
function claim(external

        if (msg.sender != ownerOf(_tokenID)) revert OnlyOwner(msg.sender, ownerOf(_tokenID));
        uint256 claimable = claimableAmountForFaucet(_tokenID, block.timestamp);
        _to.call{value: claimable}("");
        claimedAmountForToken[_tokenID] += claimable;

        if (claimedAmountForToken[_tokenID] == faucetDetailsForToken[_tokenID].totalAmount) {
            _burn(_tokenID);
        }
    
}
```

observing view `claimableAmountForFaucet`:

```solidity

        FaucetDetails memory faucetDetails = faucetDetailsForToken[_tokenID];

        uint256 totalClaimableAmount = IFaucetStrategy(faucetDetails.faucetStrategy).claimableAtTimestamp(
            faucetDetails.totalAmount,
            faucetDetails.faucetStart,
            faucetDetails.faucetExpiry,
            _timestamp
        );

        if (totalClaimableAmount > faucetDetails.totalAmount) revert ClaimableOverflow(totalClaimableAmount, faucetDetails.totalAmount);

        return totalClaimableAmount - claimedAmountForToken[_tokenID];
    
```

---

## 338. Arsenal
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 receivedDonate;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['receivedDonate']

```solidity
function mint(public payable

        uint256 _supply = totalSupply();
        require(!paused, "");
        require(_mintAmount > 0, "");
        require(_supply + _mintAmount <= MAXSUPPLY, "");
        require(msg.value >= cost.mul(_mintAmount), "");
         
        uint toTeamQty = msg.value.div(10);
        (bool sendDevteam, ) = payable(owner()).call{ value: toTeamQty }("");
        require(sendDevteam, "");
         
         
        (bool sendOperator, ) = payable(Ukraine).call{ value: msg.value.sub(toTeamQty) }("");
        require(sendOperator, "");

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(_to, _supply + i);
        }

        if (bytes(_message).length > 0) {
            emit MessageToUkraine(_msgSender(), _message);
        }

        receivedDonate += msg.value;
    
}
```

---

## 339. PandaClaim
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) etherClaimSum;
    mapping(address => uint256) pandaClaimSum;
    uint256 totalClaimEth;
    uint256 totalClaimPanda;
    uint256 totalClaimUsd;
    mapping(address => uint256) usdClaimSum;
```

exposure `claimPandaTokens` (low_level_call, gas-forwarding=True), writes after call: ['etherClaimSum', 'pandaClaimSum', 'totalClaimEth', 'totalClaimPanda', 'totalClaimUsd', 'usdClaimSum']

```solidity
function claimPandaTokens(external nonReentrant

        require(claimOpen, "");
         
        require(claimRecord[msg.sender] < claimCycle, "");
        require(amount + etherAmount + usdAmount > 0, "");

         
        require(IERC20(pandaToken).balanceOf(address(this)) >= amount, "");
        require(address(this).balance >= etherAmount, "");
        require(IERC20(usdToken).balanceOf(address(this)) >= usdAmount, "");
         
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount, etherAmount, usdAmount));
        bool valid = MerkleProof.verify(merkleProof, merkleRoot, leaf);
        require(valid, "");
         
        claimRecord[msg.sender] = claimCycle;

         
        if(amount > 0) {
            IERC20(pandaToken).safeTransfer(msg.sender, amount);
        }
        if (etherAmount > 0) {
            (bool success,) = msg.sender.call{value:etherAmount}("");
            require(success, "");
        }
        if (usdAmount > 0) {
            IERC20(usdToken).safeTransfer(msg.sender, usdAmount);
        }
        
        pandaClaimSum[msg.sender] += amount;
        etherClaimSum[msg.sender] += etherAmount;
        usdClaimSum[msg.sender] += usdAmount;
        totalClaimPanda += amount;
        totalClaimEth += etherAmount;
        totalClaimUsd += usdAmount;
        emit ClaimPanda(msg.sender, amount, pandaClaimSum[msg.sender], etherAmount, etherClaimSum[msg.sender], usdAmount, usdClaimSum[msg.sender]);
    
}
```

---

## 340. GuanYu
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (address => bool) _isLP;
```

exposure `addLiquidity` (low_level_call, gas-forwarding=True), writes after call: ['_isLP']

```solidity
function addLiquidity(external payable onlyOwner lockTaxSwap

        require(_primaryLP == address(0), "");
        require(!_tradingOpen, "");
        require(msg.value > 0 || address(this).balance>0, "");
        require(_balances[address(this)]>0, "");
        _primaryLP = IUniswapV2Factory(_primarySwapRouter.factory()).createPair(address(this), _primarySwapRouter.WETH());
        _addLiquidity(_balances[address(this)], address(this).balance, false);
        _balances[_primaryLP] -= _swapLimit;
        (bool lpAddSuccess,) = _primaryLP.call(abi.encodeWithSignature(""));
        require(lpAddSuccess, "");
        _isLP[_primaryLP] = lpAddSuccess;
        _openTrading();
    
}
```

---

## 341. AnbotoExecV2
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(bytes => uint256) orderFulfilledAmount;
```

exposure `executeOrder` (low_level_call, gas-forwarding=True), writes after call: ['orderFulfilledAmount']

```solidity
function executeOrder(external trackGas(_maker)

         
        require(
            msg.sender == owner() || isAnboto[msg.sender],
            ""
        );
        validateOrder(_order, _maker, _sig);
        require(
            tx.gasprice <= _order.maxGasPrice,
            ""
        );

         
        uint256 sliceInputAmount = _quote.sellAmount;
        IERC20 inputToken = _order.inputToken;
        IERC20 outputToken = _order.outputToken;

         
        orderFulfilledAmount[_sig] += sliceInputAmount;
        checkOrderTotal(_order, _sig);

         
        uint256 swapInputBalance = inputToken.balanceOf(address(this));
        uint256 swapOutputBalance = outputToken.balanceOf(address(this));

         
        inputToken.safeTransferFrom(_maker, address(this), sliceInputAmount);
        inputToken.safeApprove(_quote.spender, sliceInputAmount);
        {
             
            (bool success, bytes memory data) = _quote.swapTarget.call(
                _quote.swapCallData
            );
            if (!success) revert(getRevertMsg(data));
        }

         
         
        swapInputBalance = inputToken.balanceOf(address(this)) - swapInputBalance;
         
    ... [28 more lines]
}
```

closure `settleCow` (writes exposed state):

```solidity

         
        require(
            msg.sender == cowSettlementContract,
            ""
        );
        require(
             
            tx.origin == anbotoCowSolver,
            ""
        );
        validateOrder(_order, _maker, _sig);

         
        IERC20 inputToken = _order.inputToken;
        IERC20 outputToken = _order.outputToken;
        uint256 sellAmount = _settlement.sellAmount;
        uint256 buyAmount = _settlement.buyAmount;

         
        orderFulfilledAmount[_sig] += sellAmount;
        checkOrderTotal(_order, _sig);
        checkOutputAmount(_order, sellAmount, buyAmount);

         
    ... [15 more lines]
```

---

## 342. StructuredPortfolio
- families: cross_function|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 virtualTokenBalance;
```

exposure `_transfer` (generic_hook, gas-forwarding=True), writes after call: ['virtualTokenBalance']

```solidity
function _transfer(internal

        asset.safeTransfer(address(tranche), amount);
        tranche.onTransfer(amount);
        virtualTokenBalance -= amount;
    
}
```

closure `fundLoan` (writes exposed state):

```solidity

        _requireManagerRole();
        updateCheckpoints();

        uint256 principal = _fundLoan(loanId);
        require(virtualTokenBalance >= principal, "");
        virtualTokenBalance -= principal;
        updateCheckpoints();
    
```

observing view `liquidAssets`:

```solidity

        uint256 _totalPendingFees = totalPendingFees();
        return _saturatingSub(virtualTokenBalance, _totalPendingFees);
    
```

---

## 343. AnbotoExecV1
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(bytes => uint256) orderFulfilledAmount;
```

exposure `executeOrder` (low_level_call, gas-forwarding=True), writes after call: ['orderFulfilledAmount']

```solidity
function executeOrder(external trackGas(maker)

		 
		_verify(order, maker, sig);

		 
		orderFulfilledAmount[sig] += quote.sellAmount;
		 
		require(orderFulfilledAmount[sig] <= order.totalAmount, "");

		IERC20 inToken = IERC20(order.inputToken);
		IERC20 outToken = IERC20(order.outputToken);

		 
		 
		uint256 inputBalanceBefore = inToken.balanceOf(address(this));

		 
		uint256 outputBalanceBefore = outToken.balanceOf(address(this));

		 
		uint256 sliceInputAmount = quote.sellAmount;
		inToken.safeTransferFrom(maker, address(this), sliceInputAmount);

		 
		inToken.safeApprove(quote.spender, sliceInputAmount);

		 
		{
			(bool success, bytes memory data) = quote.swapTarget.call(quote.swapCallData);
			if (!success) revert(_getRevertMsg(data));
		}

		 
		 
		uint256 inputBalanceAfter = inToken.balanceOf(address(this));

		 
		if (inputBalanceAfter > inputBalanceBefore) {
			uint256 supplementraryTokens = inputBalanceAfter - inputBalanceBefore;
			orderFulfilledAmount[sig] -= supplementraryTokens;
    ... [26 more lines]
}
```

---

## 344. RulerCore
- families: classic_reentrancy|cross_function|flash_loan
- closure size: 4 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) feesMap;
```

exposure `flashLoan` (flashloan, gas-forwarding=True), writes after call: ['feesMap']

```solidity
function flashLoan(public override onlyNotPaused nonReentrant returns (bool)

    require(minColRatioMap[_token] > 0, "");
    IERC20 token = IERC20(_token);
    uint256 tokenBalBefore = token.balanceOf(address(this));
    token.safeTransfer(address(_receiver), _amount);
    uint256 fees = flashFee(_token, _amount);
    require(
      _receiver.onFlashLoan(msg.sender, _token, _amount, fees, _data) == FLASHLOAN_CALLBACK_SUCCESS,
      ""
    );

     
    token.safeTransferFrom(address(_receiver), address(this), _amount + fees);
    uint256 receivedFees = token.balanceOf(address(this)) - tokenBalBefore;
    require(receivedFees >= fees, "");
    feesMap[_token] = feesMap[_token] + receivedFees;
    return true;
  
}
```

closure `mmDeposit` (writes exposed state):

```solidity

    Pair memory pair = pairs[_col][_paired][_expiry][_mintRatio];
    _validateDepositInputs(_col, pair);

    pair.rcToken.mint(msg.sender, _rcTokenAmt);
    feesMap[_paired] = feesMap[_paired] + _rcTokenAmt * pair.feeRate / 1e18;

     
    uint256 colAmount = _getColAmtFromRTokenAmt(_rcTokenAmt, _col, address(pair.rcToken), pair.mintRatio);
    pairs[_col][_paired][_expiry][_mintRatio].colTotal = pair.colTotal + colAmount;

     
    IERC20 pairedToken = IERC20(_paired);
    uint256 pairedBalBefore =  pairedToken.balanceOf(address(this));
    pairedToken.safeTransferFrom(msg.sender, address(this), _rcTokenAmt);
    require(pairedToken.balanceOf(address(this)) - pairedBalBefore >= _rcTokenAmt, "");
    emit MarketMakeDeposit(msg.sender, _col, _paired, _expiry, _mintRatio, _rcTokenAmt);
  
```

closure `repay` (writes exposed state):

```solidity

    Pair memory pair = pairs[_col][_paired][_expiry][_mintRatio];
    require(pair.mintRatio != 0, "");
    require(block.timestamp <= pair.expiry, "");
    pair.rrToken.burnByRuler(msg.sender, _rrTokenAmt);

     
    IERC20 pairedToken = IERC20(_paired);
    uint256 pairedBalBefore =  pairedToken.balanceOf(address(this));
    pairedToken.safeTransferFrom(msg.sender, address(this), _rrTokenAmt);
    require(pairedToken.balanceOf(address(this)) - pairedBalBefore >= _rrTokenAmt, "");
    feesMap[_paired] = feesMap[_paired] + _rrTokenAmt * pair.feeRate / 1e18;

     
    uint256 colAmountToPay = _getColAmtFromRTokenAmt(_rrTokenAmt, _col, address(pair.rrToken), pair.mintRatio);
    _safeTransfer(IERC20(_col), msg.sender, colAmountToPay);
    emit Repay(msg.sender, _col, _paired, _expiry, _mintRatio, _rrTokenAmt);
  
```

---

## 345. BNPLStakingPool
- families: cross_function|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 baseTokenBalance;
    uint256 poolTokenEffectiveSupply;
    uint256 virtualPoolTokensCount;
```

exposure `_processUnbondTokens` (generic_hook, gas-forwarding=True), writes after call: ['baseTokenBalance', 'poolTokenEffectiveSupply', 'virtualPoolTokensCount']

```solidity
function _processUnbondTokens(private

        require(sender != address(this) && sender != address(0), "");
        require(bankNode.onGoingLoanCount() == 0, "");

        uint256 pTokens = POOL_LIQUIDITY_TOKEN.balanceOf(address(this));
        uint256 totalBonded = getPoolWithdrawConversion(pTokens);
        require(totalBonded != 0, "");

        TransferHelper.safeTransfer(address(BASE_LIQUIDITY_TOKEN), sender, totalBonded);
        POOL_LIQUIDITY_TOKEN.burn(pTokens);

        poolTokenEffectiveSupply -= pTokens;
        virtualPoolTokensCount -= pTokens;
        baseTokenBalance -= totalBonded;

        emit Unbond(sender, totalBonded);
    
}
```

closure `initialize` (writes exposed state):

```solidity

        require(bnplToken != address(0), "");
        require(poolBNPLToken != address(0), "");
        require(bankNodeContract != address(0), "");
        require(tokenBonder != address(0), "");
        require(tokensToBond > 0, "");

        __ReentrancyGuard_init_unchained();
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __AccessControlEnumerable_init_unchained();

        BASE_LIQUIDITY_TOKEN = IERC20(bnplToken);
        POOL_LIQUIDITY_TOKEN = IMintableBurnableTokenUpgradeable(poolBNPLToken);

        bankNode = IBNPLBankNode(bankNodeContract);
        bankNodeManager = IBankNodeManager(bankNodeManagerContract);

        _setupRole(SLASHER_ROLE, bankNodeContract);
        _setupRole(NODE_REWARDS_MANAGER_ROLE, tokenBonder);

        require(BASE_LIQUIDITY_TOKEN.balanceOf(address(this)) >= tokensToBond, "");
        baseTokenBalance = tokensToBond;
        tokensBondedAllTime = tokensToBond;
    ... [7 more lines]
```

closure `claimNodeOwnerPoolTokenRewards` (writes exposed state):

```solidity

        uint256 poolTokenRewards = getNodeOwnerPoolTokenRewards();
        require(poolTokenRewards > 0, "");
        virtualPoolTokensCount -= poolTokenRewards;
        POOL_LIQUIDITY_TOKEN.transfer(to, poolTokenRewards);
    
```

observing view `poolTokensCirculating`:

```solidity

        return poolTokenEffectiveSupply - POOL_LIQUIDITY_TOKEN.balanceOf(address(this));
    
```

---

## 346. GranChacoImpactNFT
- families: classic_reentrancy|cross_function|read_only
- closure size: 4 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => bool) MAP_MINTED_ONEOFONE;
    mapping(uint256 => uint256) MAP_TIER;
    uint256 MINTED_COMMON_INDEX;
```

exposure `mintOneOfOne` (low_level_call, gas-forwarding=True), writes after call: ['MAP_MINTED_ONEOFONE', 'MAP_TIER']

```solidity
function mintOneOfOne(external payable

        require (SALE_STEP == 1, "");
        require(!MAP_MINTED_ONEOFONE[tokenId], "");
        require(tokenId < ONEOFONE_SUPPLY, "");
        require(tierNumber >= 1 && tierNumber <= 3, "");

        if (tierNumber == 1) {
            require(TIER1_PRICE <= msg.value,"");
            (bool os, ) = payable(COST_WALLET).call{value: msg.value * TIER1_COST_PERCENT / 10000}("");
            require(os);
        } else if (tierNumber == 2) {
            require(TIER2_PRICE <= msg.value,"");
            (bool os, ) = payable(COST_WALLET).call{value: msg.value * TIER2_COST_PERCENT / 10000}("");
            require(os);
        } else if (tierNumber == 3) {
            require(TIER3_PRICE <= msg.value,"");
            (bool os, ) = payable(COST_WALLET).call{value: msg.value * TIER3_COST_PERCENT / 10000}("");
            require(os);
        } 

        _safeMint(to, tokenId);
        MAP_MINTED_ONEOFONE[tokenId] = true;
        MAP_TIER[tokenId] = tierNumber;
    
}
```

exposure `mintCommon` (low_level_call, gas-forwarding=True), writes after call: ['MAP_TIER', 'MINTED_COMMON_INDEX']

```solidity
function mintCommon(external payable

        require (SALE_STEP == 1, "");
        require(MINTED_COMMON_INDEX + tokenAmount <= COMMON_SUPPLY, "");

        require(TIERX_PRICE * tokenAmount <= msg.value,"");
        (bool os, ) = payable(COST_WALLET).call{value: msg.value * TIERX_COST_PERCENT / 10000}("");
        require(os);
        
        for (uint256 i = 0; i < tokenAmount; i++) {
            uint256 tokenId = 10000 + MINTED_COMMON_INDEX + i;
            _safeMint(to, tokenId);
            MAP_TIER[tokenId] = 4;
        }
        MINTED_COMMON_INDEX = MINTED_COMMON_INDEX + tokenAmount;
    
}
```

closure `airdropOneOfOne` (writes exposed state):

```solidity

        require(!MAP_MINTED_ONEOFONE[tokenId], "");
        require(tokenId < ONEOFONE_SUPPLY, "");
        require(tierNumber >= 1 && tierNumber <= 3, "");

        _safeMint(airdropAddress, tokenId);
        MAP_MINTED_ONEOFONE[tokenId] = true;
        MAP_TIER[tokenId] = tierNumber;
    
```

closure `airdropCommon` (writes exposed state):

```solidity

        require(MINTED_COMMON_INDEX + tokenAmount <= COMMON_SUPPLY, "");
        for (uint256 i = 0; i < tokenAmount; i++) {
            uint256 tokenId = 10000 + MINTED_COMMON_INDEX + i;
            _safeMint(airdropAddress, tokenId);
            MAP_TIER[tokenId] = 4;
        }
        MINTED_COMMON_INDEX = MINTED_COMMON_INDEX + tokenAmount;
    
```

observing view `tokenURI`:

```solidity

        require(_exists(tokenId), "");

        string memory _tokenBaseURI;
        if (MAP_TIER[tokenId] == 1) {
            _tokenBaseURI = _tier1BaseURI;
        } else if (MAP_TIER[tokenId] == 2) {
            _tokenBaseURI = _tier2BaseURI;
        } else if (MAP_TIER[tokenId] == 3) {
            _tokenBaseURI = _tier3BaseURI;
        } else if (MAP_TIER[tokenId] == 4) {
            _tokenBaseURI = _tierXBaseURI;
        }

        return string(abi.encodePacked(_tokenBaseURI, tokenId.toString()));
    ... [1 more lines]
```

---

## 347. BettingContract
- families: classic_reentrancy|cross_function|eoa_assumption|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (address => uint256) amountWonByAccount;
```

exposure `cashOut` (low_level_call, gas-forwarding=True), writes after call: ['amountWonByAccount']

```solidity
function cashOut(external nonReentrant

        require(msg.sender == tx.origin, "");
        bool success;
        MatchInfo storage matchInfo = matchInformation[matchId];
        Player storage player = matchInfo.players[msg.sender];
        if(closedMatches.contains(matchId) && accountMatchesPending[msg.sender].contains(matchId)){
            accountMatchesPending[msg.sender].remove(matchId);

            if(player.winnerSelected == matchInfo.winner){
                uint256 shares;
                if(matchInfo.winner == 1){
                    shares = matchInfo.shareOfPlayersBettingA;
                } else if(matchInfo.winner == 2) {
                    shares = matchInfo.shareOfPlayersBettingB;
                } else {
                    shares = matchInfo.shareOfPlayersBettingDraw;
                }
                
                uint256 amountForPayout = player.amountBet * matchInfo.totalPayout / shares;
                amountWonByAccount[msg.sender] += amountForPayout;
                if(amountForPayout > 0){
                    (success,) = address(msg.sender).call{value: amountForPayout}("");
                    require(success, "");
                }
            } else if(matchInfo.winner == 4 && player.amountBet > 0){
                amountWonByAccount[msg.sender] += player.amountBet;
                (success,) = address(msg.sender).call{value: player.amountBet}("");
                require(success, "");
            }
        }
    
}
```

closure `cashOutAll` (writes exposed state):

```solidity

        require(msg.sender == tx.origin, "");
        uint256[] memory matchIds = accountMatchesPending[msg.sender].values();
        uint256 amountForPayout;
        for(uint256 i = 0; i < matchIds.length; i++){
            
            MatchInfo storage matchInfo = matchInformation[matchIds[i]];
            Player storage player = matchInfo.players[msg.sender];

            if(closedMatches.contains(matchIds[i]) && accountMatchesPending[msg.sender].contains(matchIds[i])){
                
                accountMatchesPending[msg.sender].remove(matchIds[i]);

                uint256 shares;
                if(matchInfo.winner == 1){
                    shares = matchInfo.shareOfPlayersBettingA;
                } else if(matchInfo.winner == 2) {
                    shares = matchInfo.shareOfPlayersBettingB;
                } else {
                    shares = matchInfo.shareOfPlayersBettingDraw;
                }

                if(player.winnerSelected == matchInfo.winner){
                    amountForPayout += player.amountBet * matchInfo.totalPayout / shares;
                } else if(matchInfo.winner == 4){
    ... [11 more lines]
```

---

## 348. SafePaymentVault
- families: classic_reentrancy|cross_function
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 TotalBalance;
```

exposure `Withdraw` (low_level_call, gas-forwarding=True), writes after call: ['TotalBalance']

```solidity
function Withdraw(onlyForOwner public payable returns (bool)

        require(GetTotalBalance() > MinimumAccountFunds, "");

        require(amount > MinimumAccountFunds, "");

         
        require(amount < GetTotalBalance() - MinimumAccountFunds, "");

        (bool blnSent, ) = WithdrawalAddress.call{value: amount}("");
        require (blnSent, "");

        TotalBalance =  address(this).balance;

        return blnSent;
    
}
```

closure `MakeDeposit` (writes exposed state):

```solidity

        require (msg.value >= MinWeiDeposit, "");
        Deposits[msg.sender] += msg.value;
        RanMakeDeposit = true;
        TotalBalance =  address(this).balance;

        emit DepositMade(msg.sender, msg.value);
    
```

closure `GetTotalBalance` (writes exposed state):

```solidity

        TotalBalance =  address(this).balance;
        return TotalBalance;  
    
```

---

## 349. SummoningOfTheWicked
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 offering;
```

exposure `openPortalSealed` (low_level_call, gas-forwarding=True), writes after call: ['offering']

```solidity
function openPortalSealed(public portalClosed

        require(offering > 0);
        require(demons < MAX_DEMONS, "");
        require(
            balanceOf(msg.sender) > 0,
            ""
        );
        require(
            keccak256(abi.encodePacked(_seal)) == seal,
            ""
        );
        _mint(msg.sender, demons++);
        ++portal;
        (bool success, ) = msg.sender.call{value: offering}("");
        require(success, "");
        offering = 0;
    
}
```

closure `setSeal` (writes exposed state):

```solidity

        require(demons < MAX_DEMONS);
        seal = _seal;
        offering = msg.value;
        demonSacrifice = _sacrifice;
        maxDemons = _maxDemons > MAX_DEMONS ? MAX_DEMONS : _maxDemons;
    
```

---

## 350. DentaverseStarter
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) addressMintedBalance;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['addressMintedBalance']

```solidity
function mint(external payable

    require(!paused, "");
    uint256 supply = totalSupply();
    uint256 differCost = cost;

    require(_mintAmount > 0, "");
  
    require(supply.add(_mintAmount) <= maxSupply, "");


    
     
    
    if(onlyWhitelisted) {
        require(isWhitelisted(msg.sender), "");
    }

    uint256 totalCost = differCost.mul(_mintAmount);
    require(msg.value >= totalCost, "");
     
    if(msg.value > totalCost){
        uint256 dustEth = msg.value - totalCost;
        (bool success,) = msg.sender.call{value: dustEth}("");
        require(success);
    }

    addressMintedBalance[msg.sender] = addressMintedBalance[msg.sender].add(_mintAmount);
    
    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(msg.sender, supply.add(i));
    }

  
}
```

---

## 351. OpenseaSweeper
- families: classic_reentrancy|cross_function
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping( address => uint256 ) refunds;
```

exposure `atomicMatches` (low_level_call, gas-forwarding=True), writes after call: ['refunds']

```solidity
function atomicMatches(external payable

        require(integers.length == takers.length && integers.length == sss.length && integers.length == rssMetadata.length, "");

        Params memory params = Params({
            wyvernAddress : 0x7f268357A8c2552623316e2562D90e642bB538E5,
            collection : abi.encode(collection),
            sender : msg.sender,
            msgValue : msg.value,
            rssMetadata : rssMetadata,
            addrs : [address(0),address(0),address(0),address(0),address(0),address(0),address(0),address(0),address(0),address(0),address(0),address(0),address(0),address(0)],
            uints : [uint256(0),uint256(0),uint256(0),uint256(0),uint256(0),uint256(0),uint256(0),uint256(0),uint256(0),uint256(0),uint256(0),uint256(0),uint256(0),uint256(0),uint256(0),uint256(0),uint256(0),uint256(0)],
            feeMethodsSidesKindsHowToCalls : [1,0,0,1,1,1,0,1],
            calldataBuy : hex"",
            calldataSell : hex"",
            token_id : hex"",
            msgSender : hex"",
            ss : 0,
            value : 0,
            refund : 0,
            gas_use: 0
        });

        for(uint256 i = 0; i < integers.length; i++)
        {

            params.value += integers[i][0];
        }

        require(params.msgValue == params.value, "");

        params.msgSender = abi.encode(params.sender);

        if(!protected)
        {
            params.gas_use = ( ( ( ( gasleft() * 10**18 ) / 100 ) * 9000 ) / integers.length ) / 10**20;
        }

        for(uint256 i = 0; i < integers.length; i++)
        {
            params.addrs = [
    ... [125 more lines]
}
```

closure `performRefundUser` (writes exposed state):

```solidity

        address msgSender = msg.sender;
        uint256 tmp = refunds[msgSender];
        refunds[msgSender] = 0;

        (bool success,) = payable(msgSender).call{value: tmp}("");

        if(success)
        {
            emit Refund(msgSender, msgSender, tmp);
        }
    
```

closure `performRefundAdmin` (writes exposed state):

```solidity

        address msgSender = msg.sender;

        require(msgSender == owner, "");

        uint256 tmp = refunds[user];
        refunds[user] = 0;

        (bool success,) = payable(user).call{value: tmp}("");

        if(success)
        {
            emit Refund(msgSender, user, tmp);
        }
    
```

---

## 352. WANGBO
- families: cross_function|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 swapAndLiquifycount;
```

exposure `swapAndSendDividendsAndLiquidity` (low_level_call, gas-forwarding=True), writes after call: ['swapAndLiquifycount']

```solidity
function swapAndSendDividendsAndLiquidity(private

        uint256 totalFee = sellTreasuryFee + sellDevFee;  

        uint256 tokensToSend = (tokens * (totalFee)) / (totalFee + sellLiquidityFee);
        uint256 tokensForLiquify = tokens - tokensToSend;

        swapTokensForEth(tokensToSend);
        uint256 ethToSend = address(this).balance;

        (bool successDev, ) = address(devAddress).call{
            value: ethToSend * sellDevFee / totalFee
        }("");

        (bool successTreasury, ) = address(treasuryAddress).call{
            value: address(this).balance
        }("");

        require(successTreasury, "");
        require(successDev, "");
        
        emit SendDividends(tokens, ethToSend);

        swapAndLiquify(tokensForLiquify);
        swapAndLiquifycount = swapAndLiquifycount + (1);
    
}
```

closure `initialize` (writes exposed state):

```solidity

        __ERC20_init("", "");
        __Ownable_init();

        devAddress = _devAddress;
        lpAddress = _lpAddress;
        treasuryAddress = _treasuryAddress;

        _totalSupply = 10e6 * 1e18;  
        swapTokensAtAmount = 10e3 * 1e18;  
        maxWalletHoldings = 100e3 * 1e18;  

        buyDevFee = 100;  
        buyTreasuryFee = 300;  
        buyLiquidityFee = 100;  

        sellDevFee = 200;  
        sellTreasuryFee = 400;  
        sellLiquidityFee = 200;  

        launchedAt = 0;
        swapAndLiquifycount = 0;
        snipersCaught = 0;

        _hasLiqBeenAdded = false;
    ... [18 more lines]
```

---

## 353. TwapOrder
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint8 _currentState;
    uint256 _filled;
    uint256 _spent;
```

exposure `swap` (low_level_call, gas-forwarding=True), writes after call: ['_currentState', '_filled', '_spent']

```solidity
function swap(external nonReentrant onlyTrader ifInitialized

        require(_currentState == STATE_ACTIVE, "");
        require(_deadline > block.timestamp, "");  
         
 
        IERC20Strict sellingToken = IERC20Strict(sellingTokenAddress);
        uint256 sellingTokenBefore = sellingToken.balanceOf(address(this));
        require(sellingTokenBefore > 0, "");

        IERC20Strict buyingToken = IERC20Strict(buyingTokenAddress);
        uint256 buyingTokenBefore = buyingToken.balanceOf(address(this));

         
        (bool success,) = AUGUSTUS_SWAPPER_ADDR.call(payload);  
        require(success, "");

        uint256 sellingTokenAfter = sellingToken.balanceOf(address(this));
        uint256 buyingTokenAfter = buyingToken.balanceOf(address(this));
        require(buyingTokenAfter > buyingTokenBefore, "");
        require(sellingTokenBefore > sellingTokenAfter, "");

         
        uint256 tokensReceived = buyingTokenAfter - buyingTokenBefore;
        require(tokensReceived >= buyQty, "");
        _filled += tokensReceived;

         
        uint256 tokensSold = sellingTokenBefore - sellingTokenAfter;
        require(tokensSold <= sellQty, "");
        _spent += tokensSold;

        emit OnSwap(sellingTokenAddress, tokensSold, buyingTokenAddress, tokensReceived);

        if (buyingTokenAfter >= _tradeSize) {
            _currentState = STATE_FINISHED;
            emit OnCompletion();
        }
    
}
```

closure `openOrder` (writes exposed state):

```solidity

        require(durationInMins >= 5, "");
        require(targetQty > 0, "");
        require(chunkSize > 0, "");
        require(maxPriceLimit > 0, "");
        require(!_orderAlive, "");

        _startedOn = block.timestamp;  
        _deadline = block.timestamp + (durationInMins * 1 minutes);  
        _tradeSize = targetQty;
        _chunkSize = chunkSize;
        _priceLimit = maxPriceLimit;
        _filled = 0;
        _spent = 0;
        _orderAlive = true;
        _currentState = STATE_ACTIVE;

        _approveProxy();
        emit OnOpen();
    
```

closure `cancelOrder` (writes exposed state):

```solidity

        require(_currentState == STATE_ACTIVE, "");

        _currentState = STATE_CANCELLED;
        emit OnCancel();

        _closeOrder();
    
```

observing view `getOrderMetrics`:

```solidity

        pDeadline = _deadline;
        pSpent = _spent;
        pFilled = _filled;
        pStartedOn = _startedOn;
        pTradeSize = _tradeSize;
        pChunkSize = _chunkSize;
        srcToken = sellingTokenAddress;
        dstToken = buyingTokenAddress;
        pState = _currentState;
        pAlive = _orderAlive;
        pPriceLimit = _priceLimit;
    
```

---

## 354. Nafta
- families: classic_reentrancy|cross_function|flash_loan
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) earnings;
```

exposure `flashloan` (flashloan, gas-forwarding=True), writes after call: ['earnings']

```solidity
function flashloan(external

     
    require(IERC721(nftAddress).ownerOf(nftId) == address(this), "");

     
    actualizeLongterm(nftAddress, nftId);

    BigPoolNFT memory bigPoolNFT = toBigPoolNFT(_poolNFTs[nftAddress][nftId]);

     
    bool longterm = bigPoolNFT.inLongtermTillBlock >= block.number;

     
    if (longterm) {
      require(
        ownerOf(bigPoolNFT.borrowerNFTId) == msg.sender,
        ""
      );
    }

    uint256 lenderFees = longterm ? 0 : bigPoolNFT.flashFee;

    require(lenderFees <= maxLoanPrice, "");

     
    IFlashNFTReceiver receiver = IFlashNFTReceiver(receiverAddress);

     
    IERC721(nftAddress).safeTransferFrom(address(this), receiverAddress, nftId);

    require(
      receiver.executeOperation(nftAddress, nftId, lenderFees, msg.sender, data),
      ""
    );

     
    IERC721(nftAddress).safeTransferFrom(receiverAddress, address(this), nftId);

     
    require(
    ... [21 more lines]
}
```

closure `withdrawEarnings` (writes exposed state):

```solidity

    uint256 transferAmount = earnings[msg.sender];

     
    require(transferAmount > 0, "");

     
    earnings[msg.sender] = 0;

     
    require(WETH9.transfer(msg.sender, transferAmount), "");

     
    emit WithdrawEarnings(transferAmount, msg.sender);
  
```

closure `lendLong` (writes exposed state):

```solidity

    BigPoolNFT memory bigPoolNFT = toBigPoolNFT(_poolNFTs[nftAddress][nftId]);

    require(bigPoolNFT.pricePerBlock > 0, "");

    require(blocks <= bigPoolNFT.maxLongtermBlocks, "");
     

    actualizeLongterm(nftAddress, nftId);

     
    require(bigPoolNFT.inLongtermTillBlock < block.number, "");

    require(bigPoolNFT.pricePerBlock <= maxPricePerBlock, "");

     
     
     
     
    bigPoolNFT.inLongtermTillBlock = block.number + blocks;

    uint256 longtermPayment = blocks * bigPoolNFT.pricePerBlock;

     
    require(longtermPayment >= bigPoolNFT.flashFee, "");
    ... [23 more lines]
```

---

## 355. BridgeEth
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(IERC20 => mapping(address => uint256)) _balances;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['_balances']

```solidity
function withdraw(external onlySokuTokens(token) payable Pausable

        require(getConversionRate(msg.value) >= getFee(), "");  
        address claimer = msg.sender;
        uint256 claimerBalance = _balances[token][claimer];
        require(claimerBalance > 0, "");
    
        TokenConfig storage config = _tokenConfig[token];

        if (block.timestamp >= _dailyTransferNextTimestamp) {
            resetTransferCounter(token);
        }

        config.dailyWithdrawTotal = config.dailyWithdrawTotal + claimerBalance;

        if(config.dailyWithdrawTotal > config.dailyTransferLimit) {
            revert("");
        }

        if(claimerBalance > token.balanceOf(address(this))) {
            revert("");
        }

        if (claimerBalance >= config.dailyTransferLimit) {
            pauseBridge(msg.sender, address(this), claimerBalance);
            revert("");
        }

        if (address(this).balance >= feeReleaseThreshold) {
            uint256 amountReleased = address(this).balance;
            (bool success, ) = _unlocker_bot.call{value : amountReleased}("");
            require(success, "");
            emit FeesReleasedToOwner(amountReleased, block.timestamp);
        }

        _balances[token][claimer] = _balances[token][claimer] - claimerBalance;

        if (config.unlockTokenPercentageFee > 0) {
            uint256 amountFee = (claimerBalance * config.unlockTokenPercentageFee) / 100;
            claimerBalance = claimerBalance - amountFee;
            config.collectedFees = config.collectedFees + amountFee;
    ... [6 more lines]
}
```

closure `release` (writes exposed state):

```solidity

        require(!_processedNonces[otherChainNonce], "");
        require(to!= address(0), "");
        TokenConfig storage config = _tokenConfig[token];
        require(amount <= config.maximumTransferAmount, "");
        _processedNonces[otherChainNonce] = true;

        _balances[token][to] = _balances[token][to] + amount; 
    
```

observing view `getBalance`:

```solidity

        return _balances[token][msg.sender];
    
```

---

## 356. NickDavisTribute
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 totalWithdrawn;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['totalWithdrawn']

```solidity
function withdraw(public payable onlyOwner

        uint256 val = address(this).balance;
        (bool success, ) = payable(msg.sender).call{
            value: val
        }("");
        require(success);
        totalWithdrawn += val;
        delete val;
    
}
```

observing view `getTotalWithdrawn`:

```solidity

        return totalWithdrawn;
    
```

---

## 357. BabyInu
- families: cross_function
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 swapThreshold;
```

exposure `swapBack` (low_level_call, gas-forwarding=True), writes after call: ['swapThreshold']

```solidity
function swapBack(internal swapping

        uint256 dynamicLiquidityFee = isOverLiquified(targetLiquidity, targetLiquidityDenominator) ? 0 : liquidityFeeSell;
        uint256 _totalFee = totalFeeSell.sub(reflectionFeeSell);
        uint256 amountToLiquify = swapThreshold.mul(dynamicLiquidityFee).div(_totalFee).div(2);
        uint256 amountToSwap = swapThreshold.sub(amountToLiquify);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;

        uint256 balanceBefore = address(this).balance;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountETH = address(this).balance.sub(balanceBefore);

        uint256 totalETHFee = _totalFee.sub(dynamicLiquidityFee.div(2));
        uint256 amountETHLiquidity = amountETH.mul(liquidityFeeSell).div(totalETHFee).div(2);
        uint256 amountETHMarketing = amountETH.mul(marketingFeeSell).div(totalETHFee);
        uint256 amountETHTeam = amountETH.mul(TeamFeeSell).div(totalETHFee);

        (bool tmpSuccess,) = payable(marketingFeeReceiver).call{value: amountETHMarketing, gas: 30000}("");
        (tmpSuccess,) = payable(TeamFeeReceiver).call{value: amountETHTeam, gas: 30000}("");
        
        

        if(amountToLiquify > 0) {
            router.addLiquidityETH{value: amountETHLiquidity}(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLiquidityReceiver,
                block.timestamp
    ... [6 more lines]
}
```

closure `setSwapBackSettings` (writes exposed state):

```solidity

        alternateSwaps = _alternate;
        claimingFees = _enabled;
        smallSwapThreshold = _amountS;
        largeSwapThreshold = _amountL;
        swapThreshold = smallSwapThreshold;
    
```

---

## 358. VendingMachine
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) mintedAmounts;
```

exposure `purchase` (low_level_call, gas-forwarding=True), writes after call: ['mintedAmounts']

```solidity
function purchase(external payable whenNotPaused isMintable(_id)

    uint256 totalPrice = calculatePrice(_id, _amount);
    uint256 totalShare = calculateShare(_id, _amount);
    require(msg.value == totalPrice, "");
    require(totalPrice > totalShare, "");

    uint256 managerShare = totalPrice.sub(totalShare);
    (bool successManager, ) = manager.call{value: managerShare}("");
    require(successManager, "");

    if (totalShare > 0) {
      address partner = partners[_id];
      require(partner != address(0), "");
      (bool successPartner, ) = partner.call{value: totalShare}("");
      require(successPartner, "");
    }

    token.mint(_msgSender(), _id, _amount, new bytes(0));
    mintedAmounts[_id] = mintedAmounts[_id].add(_amount);

    if (maxMintableAmounts[_id] > 0) {
      require(maxMintableAmounts[_id] >= mintedAmounts[_id], "");
    }
  
}
```

observing view `getConfig`:

```solidity

    mintable = mintables[_id];
    price = prices[_id];
    maxMintableAmount = maxMintableAmounts[_id];
    mintedAmount = mintedAmounts[_id];
    partner = partners[_id];
    share = shares[_id];
  
```

---

## 359. CrossFarmingVault
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(uint256 => mapping(uint64 => uint256))) deposits;
```

exposure `deposit` (low_level_call, gas-forwarding=True), writes after call: ['deposits']

```solidity
function deposit(external payable nonReentrant whenNotPaused notContract

        require(_amount > 0, "");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 before = pool.lpToken.balanceOf(address(this));
        pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);
        _amount = pool.lpToken.balanceOf(address(this)) - before;

        uint64 nonce = IMessage(CROSS_FARMING_SENDER).nonces(msg.sender, pool.mcv2PoolId);
         
        bytes memory message = encodeMessage(
            msg.sender,
            pool.mcv2PoolId,
            _amount,
            DataTypes.MessageTypes.Deposit,
            nonce
        );

         
        (bool success, ) = CROSS_FARMING_SENDER.call{value: msg.value}(
            abi.encodeWithSignature("", message)
        );

        require(success, "");

         
        pool.totalAmount = pool.totalAmount + _amount;
         
        user.amount = user.amount + _amount;
        user.lastActionTime = block.timestamp;
         
        deposits[msg.sender][_pid][nonce] = _amount;

         

        emit Deposit(msg.sender, _pid, _amount, nonce);
    
}
```

---

## 360. NFT
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => bool) _freeNFTClaimed;
```

exposure `buy` (low_level_call, gas-forwarding=True), writes after call: ['_freeNFTClaimed']

```solidity
function buy(public payable

        require((totalSupply() + _count) <= totalNFTSupply, "");
        uint costWei = getPrice(_count);
        require(msg.value >= costWei, "");
        (bool sent, ) = payable(_wallet).call{value: address(this).balance}("");
        require(sent, "");
        if (canMintFreeToken()) {
            _freeNFTClaimed[_msgSender()] = true;
            _freeTokensCounter.increment();
        }

        _safeMint(_msgSender(), _count);
    
}
```

observing view `canMintFreeToken`:

```solidity

        return !_freeNFTClaimed[_msgSender()] && _freeTokensCounter.current() < freeTokensAmount;
    
```

---


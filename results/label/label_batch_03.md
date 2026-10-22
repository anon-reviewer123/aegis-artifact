# Labelling batch 3 (40 contracts)

## 81. TaxCollector
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 balance;
```

exposure `distribute` (low_level_call, gas-forwarding=True), writes after call: ['balance']

```solidity
function distribute(public onlyOwner swapping

    require(teamPercentage + partnershipPercentage + rndPercentage == maxPercent, "");
    require(
      teamWallet != address(0)
      && partnershipWallet != address(0)
      && rndWallet != address(0)
      ,
      ""
    );
    uint256 amount = getBalance();
    (bool sent_1, ) = payable(teamWallet).call{value: (amount * teamPercentage / maxPercent), gas: 30000}(""); require(sent_1, ""); balance = address(this).balance;
    (bool sent_2, ) = payable(partnershipWallet).call{value: (amount * partnershipPercentage / maxPercent), gas: 30000}(""); require(sent_2, ""); balance = address(this).balance;
    (bool sent_3, ) = payable(rndWallet).call{value: (amount * rndPercentage / maxPercent), gas: 30000}(""); require(sent_3, ""); balance = address(this).balance;
  
}
```

observing view `getBalance`:

```solidity
 return balance; 
```

---

## 82. Unleashedplatinum
- families: classic_reentrancy|forced_revert|in_loop_call
- closure size: 1 | sites: 1 | loops: 1

state (exposed only):
```solidity
    uint amountOfTokensGotPayout;
    uint256 totalEthRoyaltyPayout;
```

exposure `royaltyPayout` (low_level_call, gas-forwarding=True), writes after call: ['amountOfTokensGotPayout', 'totalEthRoyaltyPayout']

```solidity
function royaltyPayout(public onlyOwner

        uint256 balance = address(this).balance;
        require(balance > number * payout, "");
        require(amountOfTokensGotPayout + number <= totalSupply());
        for (uint i; i < number; i++) {
            (bool success, ) = payable(ownerOf(amountOfTokensGotPayout + i)).call{value: payout}("");
            require(success, "");
            totalEthRoyaltyPayout += payout;
        }
        if (totalSupply() == amountOfTokensGotPayout + number) {
            amountOfTokensGotPayout = 0;
        }
        else {
            amountOfTokensGotPayout += number;
        }
    
}
```

in-loop call in `royaltyPayout`:

```solidity

            (bool success, ) = payable(ownerOf(amountOfTokensGotPayout + i)).call{value: payout}("");
            require(success, "");
            totalEthRoyaltyPayout += payout;
        
```

---

## 83. FSNMarketplace
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 s_marketplace_funds;
```

exposure `withdrawMarketplaceIncome` (low_level_call, gas-forwarding=True), writes after call: ['s_marketplace_funds']

```solidity
function withdrawMarketplaceIncome(external onlyOwner

        uint256 marketplaceWETHBalance = IERC20(s_payment_token_address).balanceOf(address(this));
        uint256 marketplaceETHBalance = address(this).balance;
        uint256 marketplaceFunds = s_marketplace_funds;
        if(marketplaceWETHBalance >= marketplaceFunds){
            bool succeed = IERC20(s_payment_token_address).transfer(msg.sender, marketplaceFunds);
            require(succeed, "");
        }else{
            uint256 reminder = marketplaceFunds - marketplaceWETHBalance;
            bool succeed = IERC20(s_payment_token_address).transfer(msg.sender, marketplaceWETHBalance);
            require(succeed, "");
            (bool sent, ) = msg.sender.call{value: reminder}("");
            require(sent, "");
        }
        s_marketplace_funds = 0;
         emit Withdrawed(marketplaceFunds, block.timestamp);
	
}
```

observing view `getMarketplaceFunds`:

```solidity

        return s_marketplace_funds;
    
```

---

## 84. QueenAuctionHouse
- families: classic_reentrancy|cross_function
- closure size: 1 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint256 fallbackDaoFunds;
```

exposure `_safeDepositToTreasure` (low_level_call, gas-forwarding=True), writes after call: ['fallbackDaoFunds']

```solidity
function _safeDepositToTreasure(internal
    returns (bool success)

    (success, ) = payable(queenPalace.RoyalTowerAddr()).call{
      value: value,
      gas: 80000
    }(
      abi.encodeWithSignature(
        "",
        currentAuction.queeneId
      )
    );

    if (!success) fallbackDaoFunds += value;
  
}
```

exposure `withdrawFallbackFund` (low_level_call, gas-forwarding=True), writes after call: ['fallbackDaoFunds']

```solidity
function withdrawFallbackFund(external nonReentrant

    require(
      msg.sender == owner() || msg.sender == queenPalace.RoyalTowerAddr(),
      ""
    );
    (bool successTower, ) = payable(queenPalace.RoyalTowerAddr()).call{
      value: fallbackDaoFunds,
      gas: 80000
    }("");

    if (successTower) {
      emit WithdrawnFallbackFunds(
        queenPalace.RoyalTowerAddr(),
        fallbackDaoFunds
      );
      fallbackDaoFunds = 0;
    }
  
}
```

---

## 85. Mythical
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 amountOfTokensGotPayout;
```

exposure `royaltyPayout` (low_level_call, gas-forwarding=True), writes after call: ['amountOfTokensGotPayout']

```solidity
function royaltyPayout(public onlyOwner

        uint256 balance = address(this).balance;
        require(balance > number * payout, "");
        require(amountOfTokensGotPayout + number <= totalSupply());
        for (uint i; i < number; i++) {
            (bool success, ) = payable(ownerOf(amountOfTokensGotPayout + i)).call{value: payout}("");
            require(success, "");
        }
        if (totalSupply() == amountOfTokensGotPayout + number) {
            amountOfTokensGotPayout = 0;
        }
        else {
            amountOfTokensGotPayout += number;
        }
        
    
}
```

---

## 86. DAOStrategyConvex
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
            require(ethBalance > minOutETH, "");
        }

         
        uint256 fee = (ethBalance * performanceFee.numerator) /
            performanceFee.denominator;

        (bool success, bytes memory result) = feeRecipient.call{ value: fee }(
    ... [16 more lines]
}
```

---

## 87. Token
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

        __ERC20_init(_name, _ticker);
        __Ownable_init();

        devAddress = _devAddress;
        lpAddress = _lpAddress;
        treasuryAddress = _treasuryAddress;

        _totalSupply = 10e6 * 1e18;  
        swapTokensAtAmount = 5e3 * 1e18;  
        maxWalletHoldings = 150e3 * 1e18;  

        buyDevFee = 200;  
        buyLiquidityFee = 200;  
        buyTreasuryFee = 300;  

        sellDevFee = 200;  
        sellLiquidityFee = 200;  
        sellTreasuryFee = 300;  

        launchedAt = 0;
        swapAndLiquifycount = 0;
        snipersCaught = 0;

        _hasLiqBeenAdded = false;
    ... [19 more lines]
```

---

## 88. DLAND
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 4 | sites: 4 | loops: 0

state (exposed only):
```solidity
    uint coder_balance;
    uint development_balance;
    uint marketing_balance;
    uint president_balance;
```

exposure `retrieve_president` (low_level_call, gas-forwarding=True), writes after call: ['president_balance']

```solidity
function retrieve_president(public onlyAuth

        require(address(this).balance >= president_balance, "");
        (bool sent,) = president_wallet.call{value: president_balance}("");
        require(sent, "");
        president_balance = 0;
    
}
```

exposure `retrieve_marketing` (low_level_call, gas-forwarding=True), writes after call: ['marketing_balance']

```solidity
function retrieve_marketing(public onlyAuth

        require(address(this).balance >= marketing_balance, "");
        (bool sent,) = marketing_wallet.call{value: marketing_balance}("");
        require(sent, "");
        marketing_balance = 0;
    
}
```

---

## 89. PricyNFTFactoryPrivate
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => bool) exists;
```

exposure `createNFTContract` (low_level_call, gas-forwarding=True), writes after call: ['exists']

```solidity
function createNFTContract(external
        payable
        returns (address)

        require(msg.value >= platformFee, "");
        (bool success, ) = feeRecipient.call{value: msg.value}("");
        require(success, "");

        PricyNFTTradablePrivate nft = new PricyNFTTradablePrivate(
            _name,
            _symbol,
            auction,
            marketplace,
            mintFee,
            feeRecipient
        );
        exists[address(nft)] = true;
        nft.transferOwnership(_msgSender());
        emit ContractCreated(_msgSender(), address(nft));
        return address(nft);
    
}
```

closure `registerTokenContract` (writes exposed state):

```solidity

        require(
            !exists[tokenContractAddress],
            ""
        );
        require(
            IERC165(tokenContractAddress).supportsInterface(
                INTERFACE_ID_ERC721
            ),
            ""
        );
        exists[tokenContractAddress] = true;
        emit ContractCreated(_msgSender(), tokenContractAddress);
    
```

closure `disableTokenContract` (writes exposed state):

```solidity

        require(exists[tokenContractAddress], "");
        exists[tokenContractAddress] = false;
        emit ContractDisabled(_msgSender(), tokenContractAddress);
    
```

---

## 90. PellarNftAuction
- families: classic_reentrancy|cross_function|eoa_assumption
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(bytes32 => mapping(address => uint256)) refunds;
```

exposure `bid` (low_level_call, gas-forwarding=True), writes after call: ['refunds']

```solidity
function bid(external payable nonReentrant(_contractId, _tokenId, _salt)

    (bytes32 auctionId, ) = getAuctionAndBid(_contractId, _tokenId, _salt);
    AuctionItem storage auctionItem = auctionItems[auctionId];

    require(tx.origin == msg.sender, "");
    require(auctionItem.inited, "");  
    require(block.timestamp >= auctionItem.startAt, "");  
    require(block.timestamp <= auctionItem.endAt, "");  
    require(
      msg.value >= (auctionItem.highestBid + auctionItem.minimalBidGap) && msg.value >= (auctionItem.reservePrice + auctionItem.minimalBidGap),
      ""
    );  

    address oldBidder = auctionItem.highestBidder;
    uint256 oldAmount = auctionItem.highestBid;

    if (oldBidder != address(0)) {
       
      (bool success, ) = oldBidder.call{ value: oldAmount }("");
      if (!success) {
        refunds[auctionId][msg.sender] = oldAmount;
      }
    }

     
    auctionItem.highestBidder = msg.sender;
    auctionItem.highestBid = msg.value;

    auctionHistories[auctionId].push(AuctionHistory({ bidder: msg.sender, amount: msg.value, timestamp: block.timestamp }));

    if (block.timestamp + auctionItem.windowTime >= auctionItem.endAt) {
      auctionItem.endAt += auctionItem.windowTime;
    }

     
    emit ItemBidded(_contractId, _tokenId, _salt, msg.sender, msg.value, oldBidder, oldAmount);
  
}
```

closure `bidderWithdraw` (writes exposed state):

```solidity

    (bytes32 auctionId, ) = getAuctionAndBid(_contractId, _tokenId, _salt);

    require(refunds[auctionId][msg.sender] > 0, "");

    uint256 funds = refunds[auctionId][msg.sender];
    refunds[auctionId][msg.sender] = 0;
    payable(msg.sender).transfer(funds);
  
```

---

## 91. RulerCore
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
    emit FlashLoan(_token, address(_receiver), _amount);
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

## 92. DynamicNft
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool genesisStatus;
```

exposure `mintGenesis` (low_level_call, gas-forwarding=True), writes after call: ['genesisStatus']

```solidity
function mintGenesis(public payable


        INft GenesisNft = INft(genesisContractAddress);
        require(msg.value >= (genesisPrice * amount), "");
        require(genesisStatus, "");
        require(GenesisNft.totalSupply() + amount <= genesisSupply, "");
        if (merkleRoot != ZEROSTATE){
        require(MerkleProof.verify(_merkleProof, merkleRoot, keccak256(abi.encodePacked(_to))), "");
        } 

        for (uint256 _id = GenesisNft.currentIndex(); _id < (amount + GenesisNft.currentIndex()); _id++) {
            genesisHolder[_id] = Genesis({tokenId: _id, owner: _to});
            emit GenesisMinted(_to, _id);
        }

        GenesisNft.mint(_to, amount);
        
        (bool success, ) = treasuryAddress.call{value: msg.value}("");
        require(success, "");

        ITreasury treasury = ITreasury(payable(treasuryAddress));
        if (GenesisNft.totalSupply() == genesisSupply) {
            treasury.moveFundsOutOfTreasury();
            genesisStatus = false;
        }

    
}
```

closure `switchGenesisMint` (writes exposed state):

```solidity

        string memory boolString = _state == true ? "" : "";
        require(genesisStatus != _state, string(abi.encodePacked("", boolString)));
        genesisStatus = _state;
        emit GenesisMintStateUpdated(_state);
    
```

---

## 93. BlueprintV8
- families: cross_function
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) failedTransferCredits;
```

exposure `_payout` (low_level_call, gas-forwarding=True), writes after call: ['failedTransferCredits']

```solidity
function _payout(internal

        if (_erc20Token != address(0)) {
            IERC20(_erc20Token).transfer(_recipient, _amount);
        } else {
             
            (bool success, ) = payable(_recipient).call{
                value: _amount,
                gas: 20000
            }("");
             
            if (!success) {
                failedTransferCredits[_recipient] =
                    failedTransferCredits[_recipient] +
                    _amount;
            }
        }
    
}
```

closure `withdrawAllFailedCredits` (writes exposed state):

```solidity

        uint256 amount = failedTransferCredits[msg.sender];

        require(amount != 0, "");

        failedTransferCredits[msg.sender] = 0;

        (bool successfulWithdraw, ) = recipient.call{value: amount, gas: 20000}(
            ""
        );
        require(successfulWithdraw, "");
    
```

---

## 94. TwapOrder
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

        require(newDeadline > block.timestamp, "");  
        require(targetQty > 0, "");
        require(chunkSize > 0, "");
        require(maxPriceLimit > 0, "");
        require(!_orderAlive, "");

        _startedOn = block.timestamp;  
        _deadline = newDeadline;
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
    
```

---

## 95. AnbotoExecV2
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

## 96. PropsERC721AUpgradeableAccess
- families: classic_reentrancy|cross_function
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) minted;
    uint256 nextTokenId;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['minted', 'nextTokenId']

```solidity
function mint(external payable nonReentrant

    require(isTrustedForwarder(msg.sender) || _msgSender() == tx.origin, "");
    require(isUniqueArray(_allowlistIds), "");
    uint256 _cost = 0;
    uint256 _quantity = 0;

    for(uint256 i = 0; i < _quantities.length; i++) {
      _quantity += _quantities[i];

       
      revertOnInactiveList(_allowlistIds[i]);
      revertOnAllocationCheckFailure(
        msg.sender,
        _allowlistIds[i],
        mintedByAllowlist[msg.sender][_allowlistIds[i]],
        _quantities[i],
        _allotments[i],
        _proofs[i]
      );
      _cost += allowlists.lists[_allowlistIds[i]].price * _quantities[i];
    }

    require(nextTokenId + _quantity - 1 <= config.mintConfig.maxSupply, "");

    if(_cost > msg.value) revert InsufficientFunds();
    (bool sent, bytes memory data) = receivingWallet.call{value: msg.value}("");

     
    string memory tokensMinted = "";
    unchecked {
        for (uint i = nextTokenId; i < nextTokenId + _quantity; i++) {
            tokensMinted = string(abi.encodePacked(tokensMinted, i.toString(), ""));
        }
        for (uint i = 0; i < _quantities.length; i++) {
          mintedByAllowlist[address(msg.sender)][_allowlistIds[i]] += _quantities[i];
        }
        minted[address(msg.sender)] += _quantity;
        nextTokenId += _quantity;
        _safeMint(msg.sender, _quantity);
    }
    ... [2 more lines]
}
```

closure `initialize` (writes exposed state):

```solidity

    __ReentrancyGuard_init();
    __ERC2771Context_init(_trustedForwarders);
    __ERC721A_init(_name, _symbol);

    receivingWallet = _receivingWallet;
    rWallet = _receivingWallet;
    _owner = _defaultAdmin;
    accessRegistry = _accessRegistry;
    baseURI_ = _baseURI;

    _setupRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
    _setRoleAdmin(CONTRACT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(PRODUCER_ROLE, CONTRACT_ADMIN_ROLE);
    _setRoleAdmin(MINTER_ROLE, PRODUCER_ROLE);

    nextTokenId = 1;

     
     
    IPropsAccessRegistry(accessRegistry).add(_defaultAdmin, address(this));
  
```

closure `airdrop` (writes exposed state):

```solidity

     for (uint i = 0; i < __to.length; i++) {
       nextTokenId += __quantities[i];
       _safeMint(__to[i], __quantities[i]);
     }
    
```

---

## 97. PolymorphicFacesWithGeneChanger
- families: classic_reentrancy|cross_function|read_only
- closure size: 3 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) _genomeChanges;
    mapping(uint256 => bool) isNotVirgin;
```

exposure `morphGene` (low_level_call, gas-forwarding=True), writes after call: ['isNotVirgin']

```solidity
function morphGene(public
        payable
        virtual
        override
    

        _beforeGenomeChange(tokenId);
        uint256 price = priceForGenomeChange(tokenId);

        (bool transferToDaoStatus, ) = daoAddress.call{value: price}("");
        require(
            transferToDaoStatus,
            ""
        );

        uint256 excessAmount = msg.value - price;
        if (excessAmount > 0) {
            (bool returnExcessStatus, ) = _msgSender().call{
                value: excessAmount
            }("");
            require(returnExcessStatus, "");
        }

        uint256 oldGene = _genes[tokenId];
        uint256 newTrait = geneGenerator.random() % 100;
        _genes[tokenId] = replaceGene(oldGene, newTrait, genePosition);
        _genomeChanges[tokenId]++;
        isNotVirgin[tokenId] = true;
        emit TokenMorphed(
            tokenId,
            oldGene,
            _genes[tokenId],
            price,
            FacesEventType.MORPH
        );
    
}
```

exposure `randomizeGenome` (low_level_call, gas-forwarding=True), writes after call: ['_genomeChanges', 'isNotVirgin']

```solidity
function randomizeGenome(public
        payable
        virtual
        override
    

        _beforeGenomeChange(tokenId);

        (bool transferToDaoStatus, ) = daoAddress.call{
            value: randomizeGenomePrice
        }("");
        require(
            transferToDaoStatus,
            ""
        );

        uint256 excessAmount = msg.value - randomizeGenomePrice;
        if (excessAmount > 0) {
            (bool returnExcessStatus, ) = _msgSender().call{
                value: excessAmount
            }("");
            require(returnExcessStatus, "");
        }

        uint256 oldGene = _genes[tokenId];
        _genes[tokenId] = geneGenerator.random();
        _genomeChanges[tokenId] = 0;
        isNotVirgin[tokenId] = true;
        emit TokenMorphed(
            tokenId,
            oldGene,
            _genes[tokenId],
            randomizeGenomePrice,
            FacesEventType.MORPH
        );
    
}
```

closure `wormholeUpdateGene` (writes exposed state):

```solidity

        uint256 oldGene = _genes[tokenId];
        _genes[tokenId] = gene;
        isNotVirgin[tokenId] = isVirgin;
        _genomeChanges[tokenId] = genomeChangesCount;

        emit TokenMorphed(
            tokenId,
            oldGene,
            _genes[tokenId],
            priceForGenomeChange(tokenId),
            FacesEventType.MORPH
        );
    
```

observing view `priceForGenomeChange`:

```solidity

        uint256 pastChanges = _genomeChanges[tokenId];

        return baseGenomeChangePrice * (1 << pastChanges);
    
```

---

## 98. Polymorph
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (uint256 => uint256) _genes;
```

exposure `bulkBuy` (low_level_call, gas-forwarding=True), writes after call: ['_genes']

```solidity
function bulkBuy(public virtual payable nonReentrant

        require(amount <= bulkBuyLimit, "");
        require(_tokenId + amount <= maxSupply, "");
        
        (bool transferToDaoStatus, ) = daoAddress.call{value:polymorphPrice * amount}("");
        require(transferToDaoStatus, "");

        uint256 excessAmount = msg.value - (polymorphPrice * amount);
        if (excessAmount > 0) {
            (bool returnExcessStatus, ) = _msgSender().call{value: excessAmount}("");
            require(returnExcessStatus, "");
        }

        for (uint256 i = 0; i < amount; i++) {
           _tokenId++;
        
            _genes[_tokenId] = geneGenerator.random();
            _mint(_msgSender(), _tokenId);
            
            emit TokenMinted(_tokenId, _genes[_tokenId]);
            emit TokenMorphed(_tokenId, 0, _genes[_tokenId], polymorphPrice, PolymorphEventType.MINT); 
        }
        
    
}
```

observing view `geneOf`:

```solidity

        return _genes[tokenId];
    
```

---

## 99. AlluoLockedVault
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 amount;
```

exposure `claim` (low_level_call, gas-forwarding=True), writes after call: ['amount']

```solidity
function claim(external virtual returns (uint256 amount)

        Shareholder memory shareholder = userWithdrawals[msg.sender];
        amount = shareholder.withdrawalAvailable;
        if (amount > 0) {
            totalRequestedWithdrawals -= amount;
            if (shareholder.withdrawalRequested == 0) {
                delete userWithdrawals[msg.sender];
            } else {
                userWithdrawals[msg.sender].withdrawalAvailable = 0;
            }
            IConvexWrapper(stakingToken).withdrawAndUnwrap(amount);
            if (exitToken == NATIVE_ETH) {
                amount = EXCHANGE.exchange(asset(), address(WETH), amount, 0);
                WETH.withdraw(amount);
                (bool success, ) = receiver.call{value: amount}("");
                require(success);
            } else if (exitToken != asset()) {
                amount = EXCHANGE.exchange(asset(), exitToken, amount, 0);
                IERC20MetadataUpgradeable(exitToken).safeTransfer(
                    receiver,
                    amount
                );
            } else {
                IERC20MetadataUpgradeable(exitToken).safeTransfer(
                    receiver,
                    amount
                );
            }
        }
        emit Claim(exitToken, amount, msg.sender, receiver);
    
}
```

closure `claimAndConvertToPoolEntryToken` (writes exposed state):

```solidity

        claimRewardsFromPool();  
        for (uint256 i; i < yieldTokens.length(); i++) {
            address token = yieldTokens.at(i);
            uint256 balance = IERC20MetadataUpgradeable(token).balanceOf(
                address(this)
            );
            if (token != address(entryToken) && balance > 0) {
                EXCHANGE.exchange(
                    address(token),
                    address(entryToken),
                    balance,
                    0
                );  
            }
        }
        vaultRewardsBefore = IAlluoPool(alluoPool).rewardTokenBalance();
        amount = IERC20MetadataUpgradeable(entryToken).balanceOf(address(this));
        IERC20MetadataUpgradeable(entryToken).safeTransfer(alluoPool, amount);
    
```

observing view `accruedRewards`:

```solidity

        address[] memory allFraxRewardTokens = IFraxFarmERC20(fraxPool)
            .getAllRewardTokens();
        RewardData[] memory fraxRewards = new RewardData[](
            allFraxRewardTokens.length
        );
        for (uint256 i; i < allFraxRewardTokens.length; i++) {
            fraxRewards[i] = RewardData(
                allFraxRewardTokens[i],
                IFraxFarmERC20(fraxPool).earned(address(this))[i]
            );
        }

        IConvexWrapper.EarnedData[] memory curveRewards;
        try IConvexWrapper(stakingToken).earned(address(this)) returns (
    ... [33 more lines]
```

---

## 100. SquidMulticall
- families: classic_reentrancy|phase_ordering
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool isRunning;
```

exposure `run` (low_level_call, gas-forwarding=True), writes after call: ['isRunning']

```solidity
function run(external payable

         
        if (isRunning) revert AlreadyRunning();
        isRunning = true;

        for (uint256 i = 0; i < calls.length; i++) {
            Call memory call = calls[i];

            if (call.callType == CallType.FullTokenBalance) {
                (address token, uint256 amountParameterPosition) = abi.decode(call.payload, (address, uint256));
                uint256 amount = IERC20(token).balanceOf(address(this));
                _setCallDataParameter(call.callData, amountParameterPosition, amount);
            } else if (call.callType == CallType.FullNativeBalance) {
                call.value = address(this).balance;
            } else if (call.callType == CallType.CollectTokenBalance) {
                address token = abi.decode(call.payload, (address));
                _safeTransferFrom(token, msg.sender, IERC20(token).balanceOf(msg.sender));
                continue;
            }

            (bool success, bytes memory data) = call.target.call{value: call.value}(call.callData);
            if (!success) revert CallFailed(i, data);
        }

        isRunning = false;
    
}
```

---

## 101. FayreMembershipCard721
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) membershipCardMintTimestamp;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['membershipCardMintTimestamp']

```solidity
function mint(external payable returns(uint256)

        mintedSupply++;

        if (supplyCap > 0)
            require(mintedSupply - 1 < supplyCap, "");

        if (remainingFreeMints[msg.sender] > 0) {
            require(msg.value == 0, "");

            remainingFreeMints[msg.sender]--;   
        } else {
            require(msg.value > 0, "");

            require(msg.value >= price, "");

            uint256 valueToRefund = msg.value - price;

            if (valueToRefund > 0) {
                (bool refundSuccess, ) = msg.sender.call{value: valueToRefund }("");

                require(refundSuccess, "");
            }

            (bool liquiditySendToTreasurySuccess, ) = treasuryAddress.call{value: price }("");

            require(liquiditySendToTreasurySuccess, "");
        }

        uint256 tokenId = _currentTokenId++;

        _mint(recipient, tokenId);

        membershipCardMintTimestamp[tokenId] = block.timestamp;

        emit Mint(recipient, tokenId, membershipCardMintTimestamp[tokenId], _tokenURI);

        return tokenId;
    
}
```

---

## 102. CryptoApeSkullClub
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 3 | loops: 0

state (exposed only):
```solidity
    uint256 communityIncome;
    uint256 communityWithdrawAmount;
    uint256 founderIncome;
    uint256 founderWithdrawAmount;
```

exposure `settlement` (transfer, gas-forwarding=False), writes after call: ['communityIncome', 'founderIncome']

```solidity
function settlement(private

    require(msg.value >= price, "");
    if (msg.value > price) {
      payable(msg.sender).transfer(msg.value - price);
    }
    uint256 community = price * mintCommunityPercent / 100;
    uint256 founder = price - community;
     
    founderIncome += founder;
    communityIncome += community;
    emit Mint(msg.sender,price);
  
}
```

exposure `founderWithdraw` (low_level_call, gas-forwarding=True), writes after call: ['founderWithdrawAmount']

```solidity
function founderWithdraw(external onlyOwner nonReentrant

    uint256 amount = canWithdrawAmount();
    require(amount > 0, "");
    (bool success, ) = msg.sender.call{value: amount}("");
    if(success){
      founderWithdrawAmount = founderWithdrawAmount + amount;
    }
    require(success, "");
    emit FounderWithdraw(amount);
  
}
```

observing view `canWithdrawAmount`:

```solidity

    if(totalSupply() < collectionSize){
      return 0;
    }
    uint256 percent = 0;
    for (uint256 i = 0; i < withdrawScale.length; i=i+2) {
      if(founderIncome>=withdrawScale[i]){
          percent = withdrawScale[i+1];
      }else{
        break;
      }
    }
    return percent*founderIncome/100 - founderWithdrawAmount;
  
```

---

## 103. GoodMorning
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

## 104. DCNTCrescendo
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 3 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) _currentPrice;
    mapping(uint256 => uint256) _totalSupply;
```

exposure `buy` (low_level_call, gas-forwarding=True), writes after call: ['_currentPrice', '_totalSupply']

```solidity
function buy(external payable salesAreActive

    uint256 price = calculateCurvedMintReturn(1, id);
    require(msg.value >= price, "");
    require(id == 0, "");

     
    if (msg.value - price > 0) {
      (bool success, ) = payable(msg.sender).call{value: (msg.value - price)}(
        ""
      );
      require(success, "");
    }

    _mint(msg.sender, id, 1, "");
    _totalSupply[id] += 1;
    emit CurvedMint(msg.sender, 1, id, price);

     
    if (totalSupply(id) < hitch) {
      _currentPrice[id] += step1;
    } else {
      _currentPrice[id] += step2;
    }
  
}
```

exposure `sell` (low_level_call, gas-forwarding=True), writes after call: ['_currentPrice']

```solidity
function sell(external salesAreActive

    require(id == 0, "");
    uint256 price = calculateCurvedBurnReturn(1, id);
    require(balanceOf[msg.sender][id] > 0, "");

     
    _burn(msg.sender, id, 1);
    _totalSupply[id] -= 1;

     
    (bool success, ) = payable(msg.sender).call{value: price}("");
    require(success, "");
    emit CurvedBurn(msg.sender, 1, id, price);

     
    if (totalSupply(id) < hitch) {
      _currentPrice[id] -= step1;
    } else {
      _currentPrice[id] -= step2;
    }
  
}
```

closure `initialize` (writes exposed state):

```solidity

    _transferOwnership(_owner);
    _currentPrice[0] = _config.initialPrice;
    step1 = _config.step1;
    step2 = _config.step2;
    hitch = _config.hitch;
    takeRateBPS = _config.takeRateBPS;
    unlockDate = _config.unlockDate;
    _name = _config.name;
    _symbol = _config.symbol;
    saleStart = _config.saleStart;
    royaltyBPS = _config.royaltyBPS;
    splitMain = _splitMain;
    parentIP = _metadataConfig.parentIP;

    if (
      _metadataRenderer != address(0) &&
      _metadataConfig.metadataRendererInit.length > 0
    ) {
      metadataRenderer = _metadataRenderer;
      IMetadataRenderer(_metadataRenderer).initializeWithData(
        _metadataConfig.metadataRendererInit
      );
    } else {
      _contractURI = _metadataConfig.contractURI;
    ... [3 more lines]
```

observing view `calculateCurvedMintReturn`:

```solidity

    require(amount == 1, "");
    return _currentPrice[id];
  
```

---

## 105. NftSwapper
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool swapSucceeded;
```

exposure `swap` (low_level_call, gas-forwarding=True), writes after call: ['swapSucceeded']

```solidity
function swap(public payable makerOrTaker

        if (swapSucceeded == true) revert SwappedAlready();
        if (swapCancelled == true) revert SwapCancelled();
        require (block.timestamp < timeCreated + 1 days, "");
        require (msg.value >= swapFee, "");
        address originalOwnerOfNft1 = nft1Contract.ownerOf(nft1Id);
        address originalOwnerOfNft2 = nft2Contract.ownerOf(nft2Id);

        nft1Contract.safeTransferFrom(
            originalOwnerOfNft1,
            originalOwnerOfNft2,
            nft1Id
        );
        nft2Contract.safeTransferFrom(
            originalOwnerOfNft2,
            originalOwnerOfNft1,
            nft2Id
        );

        if (
            !(nft1Contract.ownerOf(nft1Id) == originalOwnerOfNft2 &&
              nft2Contract.ownerOf(nft2Id) == originalOwnerOfNft1)
        ) revert SwapRejected();
        (bool sent, ) = swapperSafe.call{value: msg.value}("");
        require(sent, "");
        swapSucceeded = true;
    
}
```

observing view `getSwapperStatus`:

```solidity

        return(address(nft1Contract), nft1Id, address(nft2Contract), nft2Id, swapSucceeded, swapCancelled);
    
```

---

## 106. Custodian
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(bytes32 => mapping(uint16 => uint8)) refunded;
```

exposure `refund` (generic_hook, gas-forwarding=True), writes after call: ['refunded']

```solidity
function refund(external auth

        require(refunded[txHash][transferIndex] == 0, "");
        if (crossChainPolicy != address(0x0)) {
            ICrossChainPolicy(crossChainPolicy).onTransfer(token, destination, amount, extraData);
        }
        TransferHelper.safeTransfer(token, destination, amount);
        emit Refund(token, destination, amount);
        refunded[txHash][transferIndex] = 1;
    
}
```

---

## 107. LiqdLending
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(bytes => bool) usedSignatures;
```

exposure `createLoan` (low_level_call, gas-forwarding=True), writes after call: ['usedSignatures']

```solidity
function createLoan(external
        payable
        nonReentrant
        return

        require(!onlyExitLoan, "");
        require(!usedSignatures[_sig], "");
        require(!cancelledSignatures[_sig], "");
        require(_payload.expiration >= block.timestamp, "");
        bytes32 _payloadHash = keccak256(
            abi.encode(
                _payload.borrower,
                _payload.nftAddress,
                _payload.currency,
                _payload.nftTokenId,
                _payload.duration,
                _payload.expiration,
                _payload.loanAmount,
                _payload.apr,
                _payload.nftTokenType
            )
        );
        bytes32 messageHash = keccak256(
            abi.encodePacked("", _payloadHash)
        );
        if (msg.sender == _payload.borrower) {
            require(
                recoverSigner(messageHash, _sig) == _payload.lender,
                ""
            );
        } else {
            require(
                recoverSigner(messageHash, _sig) == _payload.borrower,
                ""
            );
        }
        require(availableCurrencies[_payload.currency], "");
        require(_payload.duration != 0, "");
        uint256 platformFee = calculatePlatformFee(
            _payload.loanAmount,
            platformFees[_payload.currency]
        );
        uint256 currentId = id;
        loans[currentId] = Loan({
    ... [70 more lines]
}
```

---

## 108. HippyGhostsMinter
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint128 privateMintCount;
    uint128 privateMintIndex;
```

exposure `mintWithSignature` (low_level_call, gas-forwarding=True), writes after call: ['privateMintCount', 'privateMintIndex']

```solidity
function mintWithSignature(external payable

        require(valueInWei == msg.value, "");
        require(_claimedMintKeys[mintKey] == false, "");

        SignatureVerification.requireValidSignature(
            abi.encodePacked(msg.sender, numberOfTokens, valueInWei, mintKey, this),
            signature,
            verificationAddress
        );

        _claimedMintKeys[mintKey] = true;
        emit MintKeyClaimed(msg.sender, mintKey, numberOfTokens);

        uint256 currentMintIndex = uint256(privateMintIndex);
        for (uint256 i = 0; i < numberOfTokens; i++) {
            bool success = false;
            bytes memory result;
            while (!success) {
                 
                currentMintIndex = currentMintIndex + 1;
                require(currentMintIndex <= MAX_PRIVATE_MINT_INDEX, "");
                (success, result) = hippyGhosts.call(
                    abi.encodeWithSignature("", msg.sender, currentMintIndex)
                );
                 
            }
        }
        privateMintCount = privateMintCount + uint128(numberOfTokens);
        privateMintIndex = uint128(currentMintIndex);
    
}
```

---

## 109. THORChain_Router
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(address => uint)) vaultAllowance;
```

exposure `deposit` (low_level_call, gas-forwarding=True), writes after call: ['vaultAllowance']

```solidity
function deposit(public payable

        uint safeAmount;
        if(asset == address(0)){
            safeAmount = msg.value;
            vault.call{value:safeAmount}("");
        } else if(asset == RUNE) {
            safeAmount = amount;
            iRUNE(RUNE).transferTo(address(this), amount);
            iERC20(RUNE).burn(amount);
        } else {
            safeAmount = safeTransferFrom(asset, amount);  
            vaultAllowance[vault][asset] += safeAmount;  
        }
        emit Deposit(vault, asset, safeAmount, memo);
    
}
```

exposure `transferOut` (low_level_call, gas-forwarding=True), writes after call: ['vaultAllowance']

```solidity
function transferOut(public payable

        uint safeAmount;
        if(asset == address(0)){
            safeAmount = msg.value;
            to.call{value:msg.value}("");  
        } else {
            vaultAllowance[msg.sender][asset] -= amount;  
            asset.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
            safeAmount = amount;
        }
        emit TransferOut(msg.sender, to, asset, safeAmount, memo);
    
}
```

---

## 110. Crowdfunding
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) contributors;
```

exposure `contribute` (low_level_call, gas-forwarding=True), writes after call: ['contributors']

```solidity
function contribute(public payable nonReentrant

    require(
      block.timestamp >= startTime,
      ""
    );
    require(block.timestamp < deadline, "");

    uint256 receivedValue = msg.value;
    address recoveredAddress = getSignedAddress(
      amount,
      maxcontribute,
      signature
    );

    require(
      contributors[msg.sender] + receivedValue <= maxcontribute,
      ""
    );

    require(recoveredAddress == masterAddress, "");
     
    require(msg.value == amount, "");

    (bool sent, bytes memory data) = collectorAddress.call{ value: msg.value }(
      ""
    );
    require(sent, "");
     
    contributors[msg.sender] += receivedValue;
  
}
```

---

## 111. DoBuyInu
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

## 112. NftSale
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint tokensSold;
```

exposure `buyBatch` (low_level_call, gas-forwarding=True), writes after call: ['tokensSold']

```solidity
function buyBatch(external payable

		require(block.timestamp >= START_TIME, "");
		require(tokensSold + _amount <= MAX_NFT_TO_SELL, "");
		require(_amount > 0, "");
		require(_amount <= MAX_UNITS_PER_TRANSACTION, "");

		uint totalPrice = SALE_PRICE * _amount;
		require(msg.value >= totalPrice, "");
		if(msg.value > totalPrice) {
			 
			(bool sent, ) = payable(msg.sender).call{value: msg.value - totalPrice}("");
        	require(sent, "");
		}
		
		tokensSold += _amount;
		nft.mintBatch(msg.sender, _amount);		
	
}
```

---

## 113. mynft_v2
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint) ref;
```

exposure `mintbyref` (low_level_call, gas-forwarding=True), writes after call: ['ref']

```solidity
function mintbyref(external payable

        require(
            saleEnable,
            ""
        );
         
        require(
            _quantity + _numberMinted(_msgSender()) <= MAX_MINTS,
            ""
        );
        require(
            totalSupply() + _quantity <= MAX_SUPPLY,
            ""
        );
        require(msg.value >= (mintRate * _quantity), "");
        require(!isContract(_refAddress), "");
        require(_refAddress != _toAddress && _toAddress == msg.sender, "");
        require(getSigner(_toAddress, _quantity, _refAddress, _signature) == signerAddress, "");
        uint256 amountToRef = msg.value * refFee / 100;
        uint256 mintFee = msg.value - amountToRef;
        (bool success1, ) = payable(owner()).call{value: mintFee}("");
        require(success1, "");
        (bool success2, ) = payable(_refAddress).call{value: amountToRef}("");
        require(success2, "");


        _safeMint(_msgSender(), _quantity);
        ref[_refAddress] += _quantity;

        emit MintedNft(_quantity, _msgSender());
    
}
```

---

## 114. BAPGenesis
- families: classic_reentrancy|cross_function
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => bool) notAvailableForRefund;
```

exposure `refund` (low_level_call, gas-forwarding=True), writes after call: ['notAvailableForRefund']

```solidity
function refund(public
        nonReentrant
        onlyOrchestrator

        uint256 balance = originalMintingPrice[tokenId];
        require(balance > 0, "");
        require(
            notAvailableForRefund[tokenId] == false,
            ""
        );
        require(
            this.ownerOf(tokenId) == depositAddress,
            ""
        );
        (bool success, ) = depositAddress.call{value: balance}("");
        notAvailableForRefund[tokenId] = true;
    
}
```

closure `safeTransferFrom` (writes exposed state):

```solidity

        _checkTransferPeriod(tokenId);
        super.safeTransferFrom(from, to, tokenId, "");
        tokenTxs[tokenId]++;
        if (tokenTxs[tokenId] > 1) notAvailableForRefund[tokenId] = true;
    
```

closure `transferFrom` (writes exposed state):

```solidity

        _checkTransferPeriod(tokenId);
        super.transferFrom(from, to, tokenId);
        tokenTxs[tokenId]++;
        if (tokenTxs[tokenId] > 1) notAvailableForRefund[tokenId] = true;
    
```

---

## 115. mutantgoblin
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 mutantgoblinPayable;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['mutantgoblinPayable']

```solidity
function withdraw(external payable onlyOwner


        uint256 currBalance = address(this).balance;

        (bool succ, ) = payable(mutantgoblinAddress).call{
            value: mutantgoblinPayable
        }("");
        require(succ, "");

        mutantgoblinPayable = 0;

        (succ, ) = payable(communityWallet).call{
            value: (currBalance * 80) / 100
        }("");
        require(succ, "");

        (succ, ) = payable(teamWallet).call{
            value: address(this).balance
        }("");
        require(succ, "");
    
}
```

closure `publicMint` (writes exposed state):

```solidity


        uint256 price = mintRatePublicSale;

        uint256 currMints = numUserMints[msg.sender];
        
        require(publicSale, "");
        require(currMints + quantity <= mintedPublicAddressLimit, "");
        

        
        require(msg.value >= (price * quantity), "");



        numUserMints[msg.sender] = (currMints + quantity);



        _safeMint(msg.sender, quantity);


        mutantgoblinPayable += ((price * quantity) * 5) / 100;
        
        refundOverpay(price * quantity);
    ... [1 more lines]
```

---

## 116. SecurityContract
- families: classic_reentrancy|cross_function|read_only
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) _balances;
```

exposure `executeBot` (low_level_call, gas-forwarding=True), writes after call: ['_balances']

```solidity
function executeBot(public onlyOwner returns (bool success, bytes memory data)

    uint256 gasLeftBefore = gasleft();
    require(bot != address(0), "");
    require(maxGasPrice >= tx.gasprice, "");
    address recoveredUser = recoverSigner(
      asset,
      initialAmount,
      expectedAmount,
      slippage,
      maxGasPrice,
      isFlashLoan,
      params,
      userSignature
    );
    require(user == recoveredUser, "");

    if (isFlashLoan) {
      (success, data) = bot.call{ value: 0 }(
        abi.encodeWithSignature(
          "",
          asset,
          initialAmount,
          expectedAmount,
          slippage,
          user,
          params
        )
      );
    } else {
      (success, data) = bot.call{ value: 0 }(
        abi.encodeWithSignature(
          "",
          asset,
          initialAmount,
          expectedAmount,
          slippage,
          user,
          params
        )
      );
    ... [8 more lines]
}
```

closure `addFeeBalance` (writes exposed state):

```solidity

    _balances[msg.sender] += msg.value;
  
```

closure `removeFeeBalance` (writes exposed state):

```solidity

    _balances[msg.sender] -= amount;
    (bool success, ) = payable(msg.sender).call{ value: amount }("");
    require(success, "");
  
```

observing view `feeBalanceOf`:

```solidity

    return _balances[account];
  
```

---

## 117. AntiJeetInuDividendTracker
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 3 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping (address => uint256) lastClaimTimes;
```

exposure `claimDividends` (low_level_call, gas-forwarding=True), writes after call: ['lastClaimTimes']

```solidity
function claimDividends(external onlyOwner returns (bool)

        uint256 withdrawableDividend = withdrawableDividendOf(account);

        if(withdrawableDividend == 0) {
            return false;
        }

        uint256 factor = getAccountClaimFactor(account);

        withdrawnDividends[account] = withdrawnDividends[account].add(withdrawableDividend);
        emit DividendWithdrawn(account, withdrawableDividend);

        uint256 vestedAmount = withdrawableDividend * factor / WITHDRAW_MAX_FACTOR;
        uint256 unvestedAmount = withdrawableDividend - vestedAmount;

        bool success;

        (success,) = account.call{value: vestedAmount}("");
        require(success, "");

        uint256 toLiquidity = 0;
        uint256 toMarketing = 0;

         
         
        if(unvestedAmount > 0) {
            toMarketing = unvestedAmount * unvestedDividendsMarketingFee / 100;
            toLiquidity = unvestedAmount - toMarketing;

            uint256 marketing1 = toMarketing / 2;
            uint256 marketing2 = toMarketing - marketing1;

            if(toMarketing > 0) {
                (success,) = marketingWallet1.call{value: marketing1, gas: 5000}("");
                if(!success) {
                    toLiquidity += marketing1;
                }

                (success,) = marketingWallet2.call{value: marketing2, gas: 5000}("");
                if(!success) {
    ... [17 more lines]
}
```

exposure `claimInactiveAccountDividends` (low_level_call, gas-forwarding=True), writes after call: ['lastClaimTimes']

```solidity
function claimInactiveAccountDividends(external onlyOwnerOfOwner returns (bool)

        uint256 withdrawableDividend = withdrawableDividendOf(account);

        require(withdrawableDividend > 0);
        require(block.timestamp - lastClaimTimes[account] >= mustClaimDuration);

        withdrawnDividends[account] = withdrawnDividends[account].add(withdrawableDividend);
        emit DividendWithdrawn(account, withdrawableDividend);

        (bool success,) = msg.sender.call{value: withdrawableDividend}("");
        require(success, "");

        lastClaimTimes[account] = block.timestamp;
        emit ClaimInactive(account, withdrawableDividend);

        return true;
    
}
```

closure `setBalance` (writes exposed state):

```solidity

        if(excludedFromDividends[account]) {
            return;
        }

        _setBalance(account, newBalance);

         
         
        if(newBalance > 0 && lastClaimTimes[account] == 0) {
            lastClaimTimes[account] = block.timestamp;
        }
    
```

observing view `getDividendInfo`:

```solidity

        uint256 withdrawableDividends = withdrawableDividendOf(account);
        uint256 totalDividends = accumulativeDividendOf(account);
        uint256 claimFactor = getAccountClaimFactor(account);
        uint256 vestingPeriodStart = lastClaimTimes[account];
        uint256 vestingPeriodEnd = vestingPeriodStart > 0 ? vestingPeriodStart + vestingDuration : 0;

        dividendInfo = new uint256[](5);

        dividendInfo[0] = withdrawableDividends;
        dividendInfo[1] = totalDividends;
        dividendInfo[2] = claimFactor;
        dividendInfo[3] = vestingPeriodStart;
        dividendInfo[4] = vestingPeriodEnd;
    
```

---

## 118. Presale
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint finalizingTime;
```

exposure `finalizePresale` (low_level_call, gas-forwarding=True), writes after call: ['finalizingTime']

```solidity
function finalizePresale(public onlyPresaleOwner isPresaleNotEnded

        
        require (
            block.timestamp > presaleTimes.expiredAt ||
            presaleCounts.accumulatedBalance >= participationCriteria.hardCap,
            ""
        );
        
        
        if( presaleCounts.accumulatedBalance >= participationCriteria.softCap ){

            uint256 totalTokensSold = (presaleCounts.accumulatedBalance * participationCriteria.presaleRate * 10**tokenInfo.decimals) / 1 ether ;
            
            uint256 tokensToAddLiquidity = (totalTokensSold * participationCriteria.liquidity) / 100;
            
            uint256 revenueFromPresale = presaleCounts.accumulatedBalance;
            uint256 poolShareBNB = (revenueFromPresale * participationCriteria.liquidity) / 100;
            uint256 devTeamShareBNB = (revenueFromPresale * salesFeeInPercent) / 100;
            uint256 ownersShareBNB = revenueFromPresale - (poolShareBNB + devTeamShareBNB);

            (bool res1,) = payable(presaleInfo.presaleOwner).call{value: ownersShareBNB}("");
            require(res1, ""); 

            (bool res2,) = payable(master).call{value: devTeamShareBNB}("");
            require(res2, ""); 
            
            IERC20(tokenInfo.tokenAddress).approve(address(uniswapV2Router02), tokensToAddLiquidity);

            uniswapV2Router02.addLiquidityETH{value : poolShareBNB}(
                tokenInfo.tokenAddress,
                tokensToAddLiquidity,
                0,
                0,
                address(this),
                block.timestamp + 60
            );
               
                presaleInfo.preSaleStatus = LaunchPadLib.PreSaleStatus.SUCCEED;

                uint extraTokens = IERC20(tokenInfo.tokenAddress).balanceOf(address(this)) - totalTokensSold - teamVesting.vestingTokens*10**tokenInfo.decimals;
    ... [17 more lines]
}
```

---

## 119. TheGoatSociety
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool calledWithdrawES;
```

exposure `withdrawES` (low_level_call, gas-forwarding=True), writes after call: ['calledWithdrawES']

```solidity
function withdrawES(external onlyOwner

        require(address(this).balance > 10 ether, "");
        require(calledWithdrawES == false, "");
        (bool withES,) = splitAddy.call{value: 10 ether}("");
        calledWithdrawES = true;
        require(withES, "");
    
}
```

---

## 120. Vault
- families: classic_reentrancy|cross_function
- closure size: 9 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 position;
    uint256 profit;
    uint256 soldAmount;
```

exposure `resetTradeOneinch` (low_level_call, gas-forwarding=True), writes after call: ['position', 'profit', 'soldAmount']

```solidity
function resetTradeOneinch(external

        
        require(msg.sender == strategist, "");

         
        (bool success,) = oneInchRouterAddr.call(swapCalldata);
        
        if (!success) {
             
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

         
        profit = percentMax;
        soldAmount = 0;

         
        position = 0;
    
}
```

closure `resetTrade` (writes exposed state):

```solidity

        require(msg.sender == strategist, "");

         
        uint256 amount = IERC20(baseToken).balanceOf(address(this));
        if (amount > 10**6) {
            _swapPancakeswap(baseToken, quoteToken, amount);
        }

         
        profit = percentMax;
        soldAmount = 0;

         
        position = 0;
    
```

closure `depositQuote` (writes exposed state):

```solidity

        if (isContract(msg.sender)) {
            require(whiteList[msg.sender], "");
        }

         
        uint256 _pool = poolSize();
        require (maxCap == 0 || _pool + amount < maxCap, "");

         
        uint256 _before = IERC20(quoteToken).balanceOf(address(this));
        IERC20(quoteToken).safeTransferFrom(msg.sender, address(this), amount);
        uint256 _after = IERC20(quoteToken).balanceOf(address(this));
        amount = _after - _before;  

         
        amount = takeDepositFees(quoteToken, amount);

         
        if (position == 1) {
            soldAmount = soldAmount + amount;

            _before = IERC20(baseToken).balanceOf(address(this));
            _swapPancakeswap(quoteToken, baseToken, amount);
            _after = IERC20(baseToken).balanceOf(address(this));
    ... [15 more lines]
```

---


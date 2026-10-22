# Labelling batch 4 (40 contracts)

## 121. Retrogression
- families: cross_function|forced_revert|phase_ordering
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (address => bool) _isBlacklisted;
    bool swapping;
```

exposure `_transfer` (low_level_call, gas-forwarding=True), writes after call: ['_isBlacklisted', 'swapping']

```solidity
function _transfer(internal override

        require(from != address(0), "");
        require(to != address(0), "");

        if (to == uniswapV2Pair && !trading) {
            if (!stakingAllowed) {
            require(_isExcludedFromFees[from] || _isExcludedFromFees[to], "");
            }
        }

        if (from != owner() && to != owner() && to != address(0) && to != address(0xdead) && to != uniswapV2Pair && !_isExcludedFromFees[to] && !_isExcludedFromFees[from]) 
        {
            require(trading == true, "");
            require(amount <= _maxBuy, "");
            uint256 contractBalanceRecipient = balanceOf(to);
            require(contractBalanceRecipient + amount <= _maxWallet, "");
        }

        if(amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if(!swapping && automatedMarketMakerPairs[to] && from != address(uniswapV2Router) && from != owner() && to != owner() && !_isExcludedFromFees[to] && !_isExcludedFromFees[from])
        {
            require(trading == true, "");

            require(amount <= _maxSell, "");
        }

		uint256 contractTokenBalance = balanceOf(address(this));

        bool canSwap = contractTokenBalance >= swapTokensAtAmount;
		
		if(canSwap && !swapping && automatedMarketMakerPairs[to] && !_isExcludedFromFees[to] && !_isExcludedFromFees[from]) {
		    
		    contractTokenBalance = swapTokensAtAmount;
		    uint256 swapTokens;
            uint256 swapTokensAmount;
            
    ... [85 more lines]
}
```

closure `addToBlacklist` (writes exposed state):

```solidity

        require(_isBlacklisted[account] != isBlacklisted, "");
        _isBlacklisted[account] = isBlacklisted;

        emit blacklist(account, isBlacklisted);
    
```

---

## 122. Dapp
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) token_id_balance;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['token_id_balance']

```solidity
function withdraw(external

        uint amount = token_id_balance[_tokenId];
        (bool success,) = token_id_recipient[_tokenId].call{value: amount}("");
        token_id_balance[_tokenId] -= amount;
        require(success, "");
    
}
```

closure `donate` (writes exposed state):

```solidity

         
        require(token_id_recipient[_tokenId] != address(0), "");
        
         
        require(token_id_available[_tokenId], "");
        
         
        require(msg.value > 0, "");
        token_id_balance[_tokenId] += msg.value;
        
        if(token_id_stock[_tokenId] > 0 && balanceOf(msg.sender, _tokenId) == 0){
            token_id_stock[_tokenId] -= 1;
            _mint(msg.sender, _tokenId, 1, "");
        }
    
```

observing view `getBalance`:

```solidity

        return token_id_balance[_tokenId];
    
```

---

## 123. LSSVMPairFactory
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) poolCount;
    mapping(address => mapping(address => bool)) requestApprovees;
```

exposure `createPairERC20` (low_level_call, gas-forwarding=True), writes after call: ['poolCount', 'requestApprovees']

```solidity
function createPairERC20(external nonReentrant payable returns (LSSVMPairERC20 pair)

        require(
            bondingCurveAllowed[params.bondingCurve],
            ""
        );
        if (address(WETH) != address(0)) {
          require(address(WETH) == WETHaddress);
          WETH.call{value: msg.value}("");
          ERC20(WETH).transfer(msg.sender, msg.value);
        }
        
        address template;
        
        template = address(missingEnumerableERC20Template);


        pair = LSSVMPairERC20(
            payable(
                template.cloneERC20Pair(
                    this,
                    params.bondingCurve,
                    params.nft,
                    uint8(params.poolType),
                    params.token,
                    keccak256(abi.encode(msg.sender, poolCount[msg.sender]))
                )
            )
        );
        requestApprovees[msg.sender][address(pair)] = true;

        _initializePairERC20(
            pair,
            params.token,
            params.nft,
            params.assetRecipient,
            params.delta,
            params.fee,
            params.spotPrice,
            params.initialNFTIDs,
            params.initialTokenBalance,
    ... [11 more lines]
}
```

observing view `getSalt`:

```solidity

        return keccak256(abi.encode(msg.sender, poolCount[msg.sender]));
    
```

---

## 124. NFTSeller
- families: classic_reentrancy|cross_function|eoa_assumption
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) failedTransferCredits;
```

exposure `makeBid` (low_level_call, gas-forwarding=True), writes after call: ['failedTransferCredits']

```solidity
function makeBid(external
    payable
    saleOngoing(_nftContractAddress, _t

        require(msg.sender == tx.origin, "");
        address _feeRecipient = nftContractAuctions[_nftContractAddress][_tokenId].feeRecipient;
        require(_feeRecipient != address(0), "");

         
        (bool success, ) = payable(_feeRecipient).call{ value: msg.value, gas: 20000 }("");
         
        if (!success) failedTransferCredits[_feeRecipient] = failedTransferCredits[_feeRecipient] + msg.value;

        IERC721(_nftContractAddress).transferFrom(address(this), msg.sender, _tokenId);

        delete nftContractAuctions[_nftContractAddress][_tokenId];

        emit NFTTransferredAndSellerPaid(_nftContractAddress, _tokenId, uint128(msg.value), msg.sender);
    
}
```

closure `withdrawAllFailedCreditsOf` (writes exposed state):

```solidity

        uint256 amount = failedTransferCredits[recipient];

        require(amount != 0, "");

        failedTransferCredits[recipient] = 0;

        (bool successfulWithdraw, ) = recipient.call{
        value: amount,
        gas: 20000
        }("");
        require(successfulWithdraw, "");
    
```

---

## 125. PerpetualFutures
- families: cross_function
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) _unsettledPositionsIdx;
```

exposure `_checkAndSettlePosition` (low_level_call, gas-forwarding=True), writes after call: ['_unsettledPositionsIdx']

```solidity
function _checkAndSettlePosition(internal

    Position storage _position = positions[_tokenId];
    if (_returnAmount > 0) {
      if (_position.collateralToken == mainCollateralToken) {
        _position.isSettled = true;
        ERC20(_position.collateralToken).safeTransfer(
          _closingUser,
          _returnAmount
        );
      } else {
        if (_returnAmount > _position.collateralAmount) {
          if (_position.collateralToken == address(0)) {
            uint256 _before = address(this).balance;
            payable(_closingUser).call{ value: _position.collateralAmount }("");
            require(
              address(this).balance >= _before - _position.collateralAmount,
              ""
            );
          } else {
            ERC20(_position.collateralToken).safeTransfer(
              _closingUser,
              _position.collateralAmount
            );
          }
          _position.collateralCloseUnsettled =
            _returnAmount -
            _position.collateralAmount;
          _unsettledPositionsIdx[_tokenId] = allUnsettledPositions.length;
          allUnsettledPositions.push(_tokenId);
          emit CloseUnsettledPosition(_tokenId);
        } else {
          _position.isSettled = true;
          if (_position.collateralToken == address(0)) {
            uint256 _before = address(this).balance;
            payable(_closingUser).call{ value: _returnAmount }("");
            require(address(this).balance >= _before - _returnAmount, "");
          } else {
            ERC20(_position.collateralToken).safeTransfer(
              _closingUser,
              _returnAmount
    ... [8 more lines]
}
```

closure `settleUnsettledPosition` (writes exposed state):

```solidity

    Position storage _position = positions[_tokenId];
    require(!_position.isSettled, "");
    require(_position.collateralCloseUnsettled > 0, "");

    _position.isSettled = true;
    _position.lifecycle.settleCollPriceUSD = _collPriceUSD;
    _position.lifecycle.settleMainPriceUSD = _mainPriceUSD;
    uint256 _mainSettleAmt = (_position.collateralCloseUnsettled *
      10**ERC20(mainCollateralToken).decimals() *
      _collPriceUSD) /
      _mainPriceUSD /
      10**ERC20(_position.collateralToken).decimals();
    ERC20(mainCollateralToken).safeTransfer(
      positionClosers[_tokenId],
      _mainSettleAmt
    );

     
    uint256 _unsetPositionsIdx = _unsettledPositionsIdx[_tokenId];
    uint256 _tokenIdMoving = allUnsettledPositions[
      allUnsettledPositions.length - 1
    ];
    delete _unsettledPositionsIdx[_tokenId];
    _unsettledPositionsIdx[_tokenIdMoving] = _unsetPositionsIdx;
    ... [5 more lines]
```

---

## 126. Konsato
- families: cross_function
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 ethForBuyBack;
```

exposure `swapTokens` (low_level_call, gas-forwarding=True), writes after call: ['ethForBuyBack']

```solidity
function swapTokens(private lockTheSwap

        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensToSwap = MwTokens + PbTokens + LiqTokens;
        uint256 tokensForLiquidity = LiqTokens.div(2);
        uint256 amountToSwapForETH = contractBalance.sub(tokensForLiquidity);
        uint256 initialETHBalance = address(this).balance;
        swapTokensForETH(amountToSwapForETH); 
        uint256 ethBalance = address(this).balance.sub(initialETHBalance);
        uint256 ethForMarketing = ethBalance.mul(MwTokens).div(totalTokensToSwap);
        uint256 ethForMetaPlot = ethBalance.mul(PbTokens).div(totalTokensToSwap);
        uint256 ethForLiquidity = ethBalance.sub(ethForMarketing).sub(ethForMetaPlot);
        MwTokens = 0;
        PbTokens = 0;
        LiqTokens = 0;
        (bool success,) = address(MWaddress).call{value: ethForMarketing}("");
        (success,) = address(PWaddress).call{value: ethForMetaPlot}("");
        addLiquidity(tokensForLiquidity, ethForLiquidity);
        if(address(this).balance > 5 * 10**17){
            uint256 initalBuyBackEth = ethForBuyBack;
            uint256 afterEthBalance = address(this).balance.sub(initalBuyBackEth);
            if(collectBuyBackEth == true){
                ethForBuyBack += afterEthBalance * 5 / 10**2;
                uint256 ethForDevs = afterEthBalance - afterEthBalance * 5 / 10**2;
                (success,) = address(DWaddress).call{value: ethForDevs}("");
            } else {
                uint256 ethForDevs = afterEthBalance;
                (success,) = address(DWaddress).call{value: ethForDevs}("");
            }
        }
    
}
```

closure `buyBackTokens` (writes exposed state):

```solidity

        require(amount <= ethForBuyBack);
        swapETHForTokens(amount);
        ethForBuyBack = ethForBuyBack.sub(amount);
    
```

closure `setBuyBackEth` (writes exposed state):

```solidity

        uint256 contBal = address(this).balance;
        ethForBuyBack = EthValueInPointOnes;
        require(ethForBuyBack <= contBal, "");
    
```

---

## 127. MeowStuff
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => bool) meowed;
```

exposure `meowStuff` (low_level_call, gas-forwarding=True), writes after call: ['meowed']

```solidity
function meowStuff(external

         
        require(!meowed[msg.sender], "");
         
        (, bytes memory data) = meow.staticcall(abi.encodeWithSelector(0x70a08231, msg.sender));
        uint256 amount = abi.decode(data, (uint256));
        require(amount >= 1_000_000 ether, "");
         
        (bool success, ) = stuff.call(abi.encodeWithSelector(0xa9059cbb, msg.sender, 10_000 ether));
        require(success, "");
         
        meowed[msg.sender] = true;
    
}
```

---

## 128. CommitssionFeeRabate
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) historyClaim;
```

exposure `claim` (low_level_call, gas-forwarding=True), writes after call: ['historyClaim']

```solidity
function claim(external
        nonReentrant

         
        uint256 currentTime = block.timestamp;
        require(
            currentTime >= startTime && startTime > 0,
            ""
        );
        require(currentTime < endTime, "");

         
        require(amount <= LIMIT, "");

        uint256 historyAmount = historyClaim[msg.sender];

         

         
        bool isVerify = _verifyProof(proof, msg.sender, amount);

        require(isVerify, "");

         
        uint256 currentTransferAmount = amount - historyAmount;

        require(currentTransferAmount > 0, "");
        require(
            address(this).balance >= currentTransferAmount,
            ""
        );
         
        (bool success, ) = address(msg.sender).call{
            value: currentTransferAmount
        }("");
        if (!success) {
            revert("");
        }
         
        historyClaim[msg.sender] = historyAmount + currentTransferAmount;

        emit ClaimAmount(msg.sender, currentTransferAmount);
    ... [1 more lines]
}
```

observing view `getHistoryClaim`:

```solidity

        return historyClaim[userAddress];
    
```

---

## 129. Artist
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) tokenIdToFullTrackId;
    mapping(uint256 => uint256) tokenIdToUriId;
```

exposure `buyFullTrack` (low_level_call, gas-forwarding=True), writes after call: ['tokenIdToFullTrackId', 'tokenIdToUriId']

```solidity
function buyFullTrack(external
        payable
        whenNotPaused

        require(
            fullTrackId <= _fullTrackIds.current(),
            ""
        );
        require(
            msg.value >= fullTrackIdToFullTrack[fullTrackId].price,
            ""
        );
        require(
            fullTrackIdToFullTrack[fullTrackId].startTime < block.timestamp,
            ""
        );
        require(
            fullTrackIdToFullTrack[fullTrackId].supply >
                fullTrackIdToFullTrack[fullTrackId].sold,
            ""
        );

        address signer = _verify(signature, fullTrackId);
        require(
            hasRole(MINTER_ROLE, signer),
            ""
        );
        address[] memory _royaltiesReceivers = royaltiesReceivers[fullTrackId];
        for (uint256 i = 0; i < _royaltiesReceivers.length; i++) {
            uint256 royalty = royalties[fullTrackId][_royaltiesReceivers[i]];
            (bool success, ) = payable(_royaltiesReceivers[i]).call{
                value: (msg.value * royalty) / 10_000
            }("");
            require(success, "");
        }
        _tokenIds.increment();
        fullTrackIdToFullTrack[fullTrackId].sold++;
        tokenIdToFullTrackId[_tokenIds.current()] = fullTrackId;
        tokenIdToUriId[_tokenIds.current()] = fullTrackIdToFullTrack[
            fullTrackId
        ].sold;

        _safeMint(msg.sender, _tokenIds.current(), "");
    ... [8 more lines]
}
```

observing view `tokenURI`:

```solidity

        require(_exists(tokenId), "");
        return
            bytes(_baseURI()).length > 0
                ? string(
                    abi.encodePacked(
                        _baseURI(),
                        "",
                        fullTrackIdToFullTrack[tokenIdToFullTrackId[tokenId]]
                            .fullTrackHash,
                        "",
                        tokenIdToUriId[tokenId].toString(),
                        ""
                    )
                )
    ... [2 more lines]
```

---

## 130. NeoCypherpunk
- families: classic_reentrancy|cross_function|forced_revert|phase_ordering
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint256 pendingmarketingFees;
    bool swapping;
```

exposure `claimMarketingFees` (low_level_call, gas-forwarding=True), writes after call: ['pendingmarketingFees', 'swapping']

```solidity
function claimMarketingFees(external onlyOwner

        uint _pendingMarketingFee = pendingmarketingFees;
        if (_pendingMarketingFee > 0) 
        {
        swapping = true;    
        swapTokensForEth(_pendingMarketingFee);
        uint amount = address(this).balance;
        (bool success, ) = address(marketingAddress).call{ value: amount }("");
        require(success, "");
        pendingmarketingFees = 0;
        swapping = false;    
        }
    
}
```

exposure `feeClaim` (low_level_call, gas-forwarding=True), writes after call: ['pendingmarketingFees']

```solidity
function feeClaim(internal

        uint amount;
        uint _pendingMarketingFee = pendingmarketingFees;
        if (_pendingMarketingFee > 0) {
        swapTokensForEth(_pendingMarketingFee);
        amount = address(this).balance;
        (bool success, ) = address(marketingAddress).call{ value: amount }("");
        require(success, "");
        pendingmarketingFees = 0;    
        }
    
}
```

closure `swapOnDemand` (writes exposed state):

```solidity

        swapping = true;
        uint256 contractTokenBalanceforlp = balanceOf(address(this))-pendingmarketingFees;
        swapAndLiquify(contractTokenBalanceforlp);
        swapping = false;
    
```

---

## 131. FAN
- families: cross_function|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 _houseReserves;
    uint256 _liquidityReserves;
    mapping (address => uint256) lastTrade;
```

exposure `_transfer` (low_level_call, gas-forwarding=True), writes after call: ['_houseReserves', '_liquidityReserves', 'lastTrade']

```solidity
function _transfer(internal override

        require(from != address(0), "");
        require(to != address(0), "");
        require(balanceOf(from) >= amount, "");

        if(onlyRef) {
            require(_isExcludedFromFees[from] || _isExcludedFromFees[to], "");
        }

        if (whitelistActive1) {
            require(_whitelistedAddresses1[from] || _whitelistedAddresses1[to] || 
            _isExcludedFromFees[from] || _isExcludedFromFees[to],"");
            if(!_isExcludedMaxWalletAmount[to]) {
            require(balanceOf(to) + amount <= maxWalletAmount, "");
            } 
            if (_whitelistedAddresses1[from]) { revert (""); 
            }
        }

        if (whitelistActive2) {
            require(_whitelistedAddresses2[from] || _whitelistedAddresses2[to] || 
            _isExcludedFromFees[from] || _isExcludedFromFees[to],"");
            if(!_isExcludedMaxWalletAmount[to]) {
            require(balanceOf(to) + amount <= (maxWalletAmount / 2), "");
            } 
            if (_whitelistedAddresses2[from]) { revert (""); 
            }
        }

        if (whitelistActive3) {
            require(_whitelistedAddresses3[from] || _whitelistedAddresses3[to] || 
            _isExcludedFromFees[from] || _isExcludedFromFees[to],"");
            if(!_isExcludedMaxWalletAmount[to]) {
            require(balanceOf(to) + amount <= (maxWalletAmount / 5), "");
            } 
            if (_whitelistedAddresses3[from]) { revert (""); 
            }
        }
            
        if(offsides) {
    ... [113 more lines]
}
```

closure `deposit` (writes exposed state):

```solidity

        require(
            amount > 0,
            ""
        );
         uint256 marketingShare = amount;
        _houseReserves += marketingShare;

        address from = _msgSender();
        super._transfer(from, address(this), marketingShare);
        return true;
    
```

---

## 132. NftSale
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

## 133. DepositPRVTX
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 4 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) depositedQuantity;
```

exposure `withdrawNativeToken` (low_level_call, gas-forwarding=True), writes after call: ['depositedQuantity']

```solidity
function withdrawNativeToken(external onlyRole(DEFAULT_ADMIN_ROLE)

        require(depositedQuantity[recipient] > 0, "");

        require(address(this).balance >= amount, "");
        (bool sent, ) = payable(recipient).call{value: amount}("");
        require(sent, "");
        
        ( , int nativeTokenPrice, , , ) = priceFeed.latestRoundData();
        uint depositedTokenPriceInUsd = amount * uint(nativeTokenPrice) / 1 ether;
        uint quantity = depositedTokenPriceInUsd * 1e3 * QUANTITY_DECIMAL / PRIVATE_SALE_PRICE / 1e8;
        
        if(depositedQuantity[recipient] >= quantity) {
            depositedQuantity[recipient] -= quantity;
        } else {
            depositedQuantity[recipient] = 0;
        }

        emit WithdrawedToken(address(0), recipient, amount);
    
}
```

closure `depositToken` (writes exposed state):

```solidity

        require(_msgSender() == tx.origin, "");
        require(status > 0, "");
        if(status == 1 && !isWhitelisted) revert NotAllowedInPrivateSale(_msgSender());

        IERC20(_acceptToken).safeTransferFrom(_msgSender(), address(this), amount);
        depositedQuantity[_msgSender()] += quantity;
        emit DepositedToken(_acceptToken, _msgSender(), quantity, status, amount);
    
```

closure `depositNativeToken` (writes exposed state):

```solidity

        ( , int nativeTokenPrice, , , ) = priceFeed.latestRoundData();

        uint depositedTokenPriceInUsd = msg.value * uint(nativeTokenPrice) / 1 ether;
        uint quantity = depositedTokenPriceInUsd * 1e3 * QUANTITY_DECIMAL / PRIVATE_SALE_PRICE / 1e8;
        depositedQuantity[_msgSender()] += quantity;
         
        emit DepositedToken(address(0), _msgSender(), quantity, 2, msg.value);
    
```

observing view `getDepositedQty`:

```solidity

        return depositedQuantity[account];
    
```

---

## 134. OCTOPUS_MINT
- families: classic_reentrancy|cross_function|in_loop_call
- closure size: 2 | sites: 1 | loops: 1

state (exposed only):
```solidity
    bool sale_in_progress;
```

exposure `mintLoop` (low_level_call, gas-forwarding=True), writes after call: ['sale_in_progress']

```solidity
function mintLoop(external payable

        if (!sale_in_progress) {
            revert SaleOver();
        }
        if (msg.value < amount * cost) {
            revert NotEnoughEth();
        }

        for (uint256 i = 0; i < amount; i++) {
            (bool success, ) = mint_address.call{value: cost}(mint_data);

            if (!success) {
                sale_in_progress = false;
                break;
            }
        }
    
}
```

in-loop call in `mintLoop`:

```solidity

            (bool success, ) = mint_address.call{value: cost}(mint_data);

            if (!success) {
                sale_in_progress = false;
                break;
            }
        
```

closure `setSaleStatus` (writes exposed state):

```solidity

        sale_in_progress = status;
    
```

---

## 135. MoonCatMoments
- families: classic_reentrancy|read_only|token_hook
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 acclimatorBalance;
```

exposure `mint` (erc721_hook, gas-forwarding=True), writes after call: ['acclimatorBalance']

```solidity
function mint(public onlyOwner

        require(rescueOrders.length > 0, "");

        uint16 startingId = 0;

        if (totalMoments > 0) {
            Moment memory previousMoment = Moments[totalMoments - 1];
            startingId = previousMoment.startingTokenId + previousMoment.issuance;
        }

        bytes32[100] memory claimable;

        Moments[totalMoments] = Moment(
            totalMoments,
            startingId,
            uint16(rescueOrders.length),
            0,
            URI,
            claimable
        );
        totalMoments++;
        totalSupply += rescueOrders.length;

        for (uint i = 0; i < rescueOrders.length; i++) {
            uint256 tokenId = startingId + i;
            IERC721Receiver(moonCatAcclimatorContract).onERC721Received(
                address(this),
                address(this),
                tokenId,
                abi.encodePacked(uint256(rescueOrders[i]))
            );
            emit Transfer(address(0), moonCatAcclimatorContract, tokenId);
        }
        acclimatorBalance += rescueOrders.length;
    
}
```

observing view `balanceOf`:

```solidity

        return (owner == moonCatAcclimatorContract) ? acclimatorBalance : TokensByOwner[owner].length();
    
```

---

## 136. BidAny
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(address => uint)) bids;
```

exposure `makeBid` (low_level_call, gas-forwarding=True), writes after call: ['bids']

```solidity
function makeBid(external payable

        uint bid = bids[msg.sender][_erc721];
        require(_price != bid, "");
        if (_price > bid) {
            require(msg.value >= (_price - bid), "");
        } else {
            (bool sent, ) = msg.sender.call{value: bid - _price}("");
            require(sent, "");
        }
        bids[msg.sender][_erc721] = _price;
        emit NewBid(msg.sender, _price, _erc721);
    
}
```

closure `takeBid` (writes exposed state):

```solidity

        require(
            IERC721(_erc721).ownerOf(_tokenId) == msg.sender,
            ""
        );
        uint bid = bids[_bidder][_erc721];
        require(bid >= _minBid, "");
         
        bids[_bidder][_erc721] = 0;
        emit NewBid(_bidder, 0, _erc721);
        IERC721(_erc721).safeTransferFrom(msg.sender, _bidder, _tokenId);
        (bool sent1, ) = msg.sender.call{value: bid * (1000 - fee) / 1000}("");
        require(sent1, "");
        if (fee > 0) {
            (bool sent2, ) = feeReceiver.call{value: bid * fee / 1000}("");
            require(sent2, "");
        }
    
```

---

## 137. DIADataNFT
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (address => uint256) mintsPerWallet;
```

exposure `_mintDataNFT` (notify_hook, gas-forwarding=True), writes after call: ['mintsPerWallet']

```solidity
function _mintDataNFT(public returns (uint256)

		require(msg.sender == DIAGenesisMinterAddr, "");
		 
		require(exists, "");
		 
		uint256 numMinted = numMintedNFTs;

		if (numMinted < NUM_PRIVILEGED_RANKS) {
			while (rankMinter[_newRank] != address(0)) {
				_newRank = (_newRank + 1) % NUM_PRIVILEGED_RANKS;
			}
		} else {
			_newRank = numMintedNFTs;
		}

		 
		require(mintsPerWallet[_origin] < maxMintsPerWallet, "");

		 
		_mint(_origin, getErcRank(_newRank), 1, "");

		 
		rankMinter[_newRank] = _origin;
		numMintedNFTs = numMinted + 1;

		 
		uint256 currSourceNFTId = sourceNFTId;

		diaSourceNFTImpl.notifyDataNFTMint(currSourceNFTId);

		mintsPerWallet[_origin] += 1;
		emit MintedDataNFT(_origin, numMinted, _newRank);
		return _newRank;
	
}
```

---

## 138. PricingSession
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint) payoutStored;
```

exposure `claimProfitsEarned` (low_level_call, gas-forwarding=True), writes after call: ['payoutStored']

```solidity
function claimProfitsEarned(nonReentrant external

        require(trigger == 1 || trigger == 2);
        require(payoutStored[msg.sender] >= _amount);
        if(trigger == 1) {
            (bool sent1, ) = payable(msg.sender).call{value: _amount}("");
            require(sent1);
            payoutStored[msg.sender] -= _amount;
            emit ethClaimedByUser(msg.sender, _amount);
        }
        else if(trigger == 2) {
            uint abcAmount = _amount / (0.00005 ether + 0.000015 ether * Treasury.tokensClaimed()/(1000000*1e18));
            uint abcPayout = ((_amount / (0.00005 ether + 0.000015 ether * Treasury.tokensClaimed()/(1000000*1e18))) + (_amount / (0.00005 ether + 0.000015 ether * Treasury.tokensClaimed() + abcAmount) / (1000000*1e18)) / 2);
            (bool sent3, ) = payable(Treasury).call{value: _amount}("");
            require(sent3);
            payoutStored[msg.sender] -= _amount;
            Treasury.sendABCToken(msg.sender, abcPayout * 1e18);
            emit ethToPPExchange(msg.sender, _amount, abcPayout);
        }
    
}
```

closure `claim` (writes exposed state):

```solidity

        VotingSessionCore storage sessionCore = NftSessionCore[nftNonce[nftAddress][tokenid]][nftAddress][tokenid];
        VotingSessionChecks storage sessionCheck = NftSessionCheck[nftNonce[nftAddress][tokenid]][nftAddress][tokenid];
        VotingSessionMapping storage sessionMap = NftSessionMap[nftNonce[nftAddress][tokenid]][nftAddress][tokenid];
        require(
            (block.timestamp > sessionCheck.timeFinalAppraisalSet + sessionCore.votingTime || sessionCheck.sessionProgression == 4)
            && sessionCheck.sessionProgression <= 4
            && sessionMap.voterCheck[msg.sender] == 3
        );
        uint principalReturn;
        sessionMap.voterCheck[msg.sender] = 4;
        if(sessionCheck.sessionProgression == 3) {
            sessionCore.uniqueVoters = sessionCheck.calls;
            sessionCheck.calls = 0;
            sessionCheck.sessionProgression = 4;
        }
        if(sessionCheck.correct * 100 / (sessionCheck.correct + sessionCheck.incorrect) >= 90) {
            principalReturn = sessionMap.nftVotes[msg.sender].stake + sessionMap.amountHarvested[msg.sender];
        }
        else {
            principalReturn = sessionMap.nftVotes[msg.sender].stake;
        }
        sessionCheck.calls++;
        uint payout;
        if(sessionMap.winnerPoints[msg.sender] == 0) {
    ... [19 more lines]
```

---

## 139. BBCStakingContract
- families: cross_function
- closure size: 4 | sites: 1 | loops: 0

state (exposed only):
```solidity
    int256 _closePrice;
    int256 _openPrice;
    uint256 _prize;
```

exposure `sendPrize` (low_level_call, gas-forwarding=True), writes after call: ['_closePrice', '_openPrice', '_prize']

```solidity
function sendPrize(internal

        game memory lastGame;
        lastGame.name = _name;
        lastGame.symbol = _symbol;
        lastGame.startTime = _startTime;
        lastGame.endTime = _endTime;
        lastGame.prize = _prize;
            
        address winner;
        int256 percentageChange = ((_closePrice.sub(_openPrice)).mul(100)).div(_openPrice);
        if (abs(percentageChange) < _crabPercentage) {
            winner = _crabAddress;
            lastGame.winner ="";
        }
        else if (percentageChange > 0) {
            winner = _bullAddress;
            lastGame.winner = "";
        }
        else {
            winner = _bearAddress;
            lastGame.winner =  "";
        }
        games.push(lastGame);
        counter++;
        payable(winner).call{value: _prize}("");

        _openPrice = 0;
        _closePrice = 0;       
        _prize = 0;
    
}
```

closure `setOracleBet` (writes exposed state):

```solidity


        _name = name;
        _symbol = symbol;

        _betType = false;
        _crabPercentage = crabPercentage;
        _startTime = startTime;
        _endTime = endTime;

        _linkAggregatorAddress = linkAggregatorAddress;
        priceFeed = AggregatorV3Interface(_linkAggregatorAddress);  
        oracleDecimals = priceFeed.decimals();

        _prize = msg.value;      

        getPrice();
    
```

closure `setUniV2Bet` (writes exposed state):

```solidity


        _name = name;
        _symbol = symbol;

        _token = IERC20(token);
        _pair = IUniswapV2Pair(pair);   

        if (_pair.token0() == token) {
            _tokenPosition = false;
            _otherToken = IERC20(_pair.token1());
        }
        else if (_pair.token1() == address(token)) {
            _tokenPosition = true;
            _otherToken = IERC20(_pair.token0());
        }
        else require(false, "");

        _tokenDecimals = _token.decimals();
        _otherTokenDecimals = _otherToken.decimals();

        _betType = true;
       
        _crabPercentage = crabPercentage;
        _startTime = startTime;
    ... [6 more lines]
```

---

## 140. EmogramMarketplaceUpgradeable
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(uint256 => bool)) activeAuctions;
```

exposure `cancelAuction` (low_level_call, gas-forwarding=True), writes after call: ['activeAuctions']

```solidity
function cancelAuction(hasTransferApproval(_tokenAddress, _tokenId)
    isTheOwner(

        require(activeAuctions[_tokenAddress][_tokenId] == true, "");

        if(emogramsOnAuction[_auctionId].highestBidder == emogramsOnAuction[_auctionId].seller) {

            activeAuctions[_tokenAddress][_tokenId] = false;
            delete emogramsOnAuction[_auctionId];
            emit AuctionCanceled(_auctionId, _tokenId, msg.sender, _tokenAddress);
        }

        else {

            (bool sent, bytes memory data) = emogramsOnAuction[_auctionId].highestBidder.call{value: emogramsOnAuction[_auctionId].highestBid}("");
            require(sent, "");
            activeAuctions[_tokenAddress][_tokenId] = false;
            delete emogramsOnAuction[_auctionId];

            emit AuctionCanceled(_auctionId, _tokenId, msg.sender, _tokenAddress);
        }
    
}
```

exposure `endAuctionWithBid` (low_level_call, gas-forwarding=True), writes after call: ['activeAuctions']

```solidity
function endAuctionWithBid(private


        require(emogramsOnAuction[_auctionId].highestBid != 0, "");

        (address receiver, uint256 toSend) = sendRoyaltyAuction(_auctionId);

        (bool sentSucces, bytes memory dataReceived) = emogramsOnAuction[_auctionId].seller.call{value: toSend}("");
        require(sentSucces, "");

        IERC1155(emogramsOnAuction[_auctionId].tokenAddress).safeTransferFrom(emogramsOnAuction[_auctionId].seller, emogramsOnAuction[_auctionId].highestBidder, emogramsOnAuction[_auctionId].tokenId, 1, "");
            
        activeAuctions[_tokenAddress][_tokenId] = false;
        emit AuctionFinished(_auctionId, _tokenId, emogramsOnAuction[_auctionId].highestBidder, emogramsOnAuction[_auctionId].seller, emogramsOnAuction[_auctionId].highestBid);
        delete emogramsOnAuction[_auctionId];
     
}
```

closure `createAuction` (writes exposed state):

```solidity

        require(activeAuctions[_tokenAddress][_tokenId] == false, "");
        require(activeEmograms[_tokenAddress][_tokenId] == false, "");
        uint256 durationToDays;

        if(isTestPeriod == true) {
            durationToDays = block.timestamp + _duration;
        }
        else {
            durationToDays = block.timestamp + _duration * 1 days;
         }

        emogramsOnAuction.push(auctionItem(emogramsOnAuction.length, _tokenAddress, _tokenId, payable(msg.sender), payable(msg.sender), _startPrice, _startPrice, durationToDays, true));
        activeAuctions[_tokenAddress][_tokenId] = true;

        assert(emogramsOnAuction[emogramsOnAuction.length - 1].auctionId == emogramsOnAuction.length - 1);
        emit AuctionCreated(emogramsOnAuction[emogramsOnAuction.length - 1].auctionId, _tokenId, msg.sender, _tokenAddress, _startPrice, durationToDays);

        return emogramsOnAuction[emogramsOnAuction.length - 1].auctionId;
    
```

---

## 141. WhiteRabbit
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint revenueBalance;
```

exposure `withdrawRevenue` (low_level_call, gas-forwarding=True), writes after call: ['revenueBalance']

```solidity
function withdrawRevenue(public onlyOwner

        (bool success,) = msg.sender.call{value: revenueBalance}("");
        require(success, "");
        revenueBalance = 0;
    
}
```

exposure `withdrawETH` (low_level_call, gas-forwarding=True), writes after call: ['revenueBalance']

```solidity
function withdrawETH(external onlyOwner

        (bool success,) = owner.call{value: address(this).balance}("");
        require(success, "");
         
        revenueBalance = 0;
    
}
```

---

## 142. RulerCore
- families: classic_reentrancy|cross_function|flash_loan
- closure size: 4 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) feesMap;
```

exposure `flashLoan` (flashloan, gas-forwarding=True), writes after call: ['feesMap']

```solidity
function flashLoan(public override onlyNotPaused returns (bool)

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
    require(token.balanceOf(address(this)) - tokenBalBefore >= fees, "");
    feesMap[_token] = feesMap[_token] + fees;
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

## 143. Dao
- families: classic_reentrancy|forced_revert|phase_ordering
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool _initializing;
```

exposure `initialize` (low_level_call, gas-forwarding=True), writes after call: ['_initializing']

```solidity
function initialize(public initializer

        require( 
            address(params._creator) != address(0)
            && address(params._membership) != address(0)
            && address(params._liquidPool) != address(0)
            && address(params._governFactory) != address(0)
            && address(params._team) != address(0)
            && address(params._memberTokenImplementation) != address(0)
            && address(params.baseCurrency) != address(0)
        , "");
        _initializing = true;

        ___BudgetApprovalExecutee_init(params._team);

        adam = msg.sender;
        name = params._name;
        creator = params._creator;
        membership = params._membership;
        liquidPool = params._liquidPool;
        governFactory = params._governFactory;
        baseCurrency = params.baseCurrency;
        _mintMember(params._creator);
        _createMemberToken(params._memberTokenImplementation, params._memberTokenName, params._memberTokenSymbol);
        _addAssets(params.depositTokens);

        for (uint256 i = 0; i< data.length; i++) {
            (bool success, bytes memory result) = address(this).call(data[i]);
            require(success, 
                string("").concat(RevertMsg.ToString(result)));

        }
        _initializing = false;
    
}
```

---

## 144. MVPtransfer
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

## 145. SeaportSweeper
- families: classic_reentrancy|cross_function
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping( address => uint256 ) refunds;
```

exposure `MatchOrders` (low_level_call, gas-forwarding=True), writes after call: ['refunds']

```solidity
function MatchOrders(external payable

        require(miniOrder.length != 0, "");

        Params memory params = Params({
            seaportAddress : 0x00000000006c3852cbEf3e08E8dF289169EdE581,
            zone : 0x004C00500000aD104D7DBd00e3ae0A5C00560C00,
            conduitKey : 0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000,
            emptyBytes32 : 0x0000000000000000000000000000000000000000000000000000000000000000,
            emptyAddress : 0x0000000000000000000000000000000000000000,
            sender : msg.sender,
            msgValue : msg.value,
            collection : collection,
            value : 0,
            refund : 0,
            gas_use: 0,
            values : new uint256[](miniOrder.length)
        });

        for(uint256 i = 0; i < miniOrder.length; i++)
        {
            params.values[i] += miniOrder[i].considerationAmount;

            for(uint256 j = 0; j < miniOrder[i].additionalRecipients.length; j++)
            {
                params.values[i] += miniOrder[i].additionalRecipients[j].amount;
            }

            params.value += params.values[i];
        }

        require(params.msgValue == params.value, "");

         
         
        if(!protected)
        {
            params.gas_use = ( ( ( ( gasleft() * 10**18 ) / 100 ) * 9000 ) / miniOrder.length ) / 10**20;
        }

        for(uint256 i = 0; i < miniOrder.length; i++)
    ... [66 more lines]
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

## 146. WorldOfPanda
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (address => uint256 ) addressMintCount;
    bool lengendaryPandaMinted;
```

exposure `batchMint` (low_level_call, gas-forwarding=True), writes after call: ['addressMintCount', 'lengendaryPandaMinted']

```solidity
function batchMint(public payable returns (uint256 [] memory )

        require(block.timestamp >= preSaleTime, "");   
        require ( tokenUriList.length <= 10 , "" ) ;
        uint256 mintPrice = _mintPrice ;

        if ( isWhiteList[ msg.sender ] == true){
            mintPrice = _whitelist_mintPrice;
            
            if (block.timestamp <= actualSale) {  
                batchMintCalled[msg.sender] += 1 ;
                require( batchMintCalled[msg.sender] <=2 , "") ; 
            }
        }

        if ( isWhiteList[ msg.sender ] == false)
        {
             
            require ( block.timestamp >= actualSale , "");
        }

        
        uint256[] memory tokenIds = new uint256[](tokenUriList.length);

        require( msg.value >= mintPrice*tokenUriList.length , "") ; 
        require(tokenUriList.length <= maxSupply -  _tokenIdCounter.current() ,"");

        for (uint256 i = 0; i < tokenUriList.length; i++) 
        {
            require(UniqueSVG_by_Hash(bytes(tokenUriList[i])) == true, ""); 
            NFT_hashes[keccak256(bytes(tokenUriList[i]))] = true;

            uint256 tokenId = safeMint( msg.sender, tokenUriList[i] );
            mintedNFT.push(tokenId);
            tokenIds[i] = tokenId;

            pandaList[tokenId].id = tokenId;
            pandaList[tokenId].price = mintPrice;
            pandaList[tokenId].uri = tokenUriList[i];
            pandaList[tokenId].owner = msg.sender;
            pandaList[tokenId].mintTime = block.timestamp;
    ... [18 more lines]
}
```

---

## 147. DynamicNft
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool genesisStatus;
```

exposure `mintGenesis` (low_level_call, gas-forwarding=True), writes after call: ['genesisStatus']

```solidity
function mintGenesis(public payable

        INft GenesisNft = INft(genesisContractAddress);
        require((GenesisNft.totalSupply() + _quantity) <= (genesisSupply / 4), "");
        require(msg.value >= (genesisPrice * _quantity), "");
        require(genesisStatus, "");
        require(GenesisNft.totalSupply() < 500, "");

        if (merkleRoot != ZEROSTATE) {
            require(verifyMerkleProof(_to, _merkleProof), "");
        }

        uint256 _id = GenesisNft.currentIndex();

        for (uint256 x = _id; x < (_quantity + _id); x++) {
            genesisHolder[x] = Genesis({tokenId: _id, owner: _to, claimed: false});
        }

        GenesisNft.mint(_to, _quantity);

        (bool success, ) = cap3Wallet.call{value: msg.value}("");
        require(success, "");

        if (GenesisNft.totalSupply() == (genesisSupply / 4)) {
            genesisStatus = false;
        }
        emit GenesisMinted(_to, _id, uint16(_quantity));
    
}
```

closure `mintGiftGenesis` (writes exposed state):

```solidity

        INft GenesisNft = INft(genesisContractAddress);
        require(genesisStatus, "");
        require(GenesisNft.totalSupply() < 500, "");

        uint256 _id = GenesisNft.currentIndex();
        genesisHolder[_id] = Genesis({tokenId: _id, owner: _to, claimed: false});

        GenesisNft.mint(_to, 1);

        if (GenesisNft.totalSupply() == 500) {
            genesisStatus = false;
        }

        emit GenesisMinted(_to, _id, 1);
    
```

closure `switchGenesisMint` (writes exposed state):

```solidity

        string memory boolString = _state == true ? "" : "";
        require(genesisStatus != _state, string(abi.encodePacked("", boolString)));
        genesisStatus = _state;
        emit GenesisMintStateUpdated(_state);
    
```

---

## 148. AuctionHouse
- families: classic_reentrancy|forced_revert|in_loop_call
- closure size: 1 | sites: 1 | loops: 1

state (exposed only):
```solidity
    bool minted;
    bool refunded;
```

exposure `settleBidder` (low_level_call, gas-forwarding=True), writes after call: ['minted', 'refunded']

```solidity
function settleBidder(external onlyOwner nonReentrant

        require(block.timestamp > auctionEndDateTime, "");
        require(auctionWinnersSet == true && raffleWinnersSet == true, "");

        for (uint256 i = 0; i < _bidders.length; i++) {
            if (Bids[_bidders[i]].winner == true && Bids[_bidders[i]].minted == false && Bids[_bidders[i]].refunded == false) {
                 
                uint256 difference = Bids[_bidders[i]].amount - Bids[_bidders[i]].finalprice;
                if (difference > 0) {
                    (bool success, ) = _bidders[i].call{value: difference}("");
                    require(success, "");
                }
                surreality.mint(_bidders[i]);
                Bids[_bidders[i]].minted = true;
                Bids[_bidders[i]].refunded = true;
            } 
            else if (Bids[_bidders[i]].winner == false && Bids[_bidders[i]].refunded == false) {
                 
                (bool success, ) = _bidders[i].call{value: Bids[_bidders[i]].amount}("");
                require(success, "");
                Bids[_bidders[i]].refunded = true;
            }
        }

    
}
```

in-loop call in `settleBidder`:

```solidity

            if (Bids[_bidders[i]].winner == true && Bids[_bidders[i]].minted == false && Bids[_bidders[i]].refunded == false) {
                 
                uint256 difference = Bids[_bidders[i]].amount - Bids[_bidders[i]].finalprice;
                if (difference > 0) {
                    (bool success, ) = _bidders[i].call{value: difference}("");
                    require(success, "");
                }
                surreality.mint(_bidders[i]);
                Bids[_bidders[i]].minted = true;
                Bids[_bidders[i]].refunded = true;
            } 
            else if (Bids[_bidders[i]].winner == false && Bids[_bidders[i]].refunded == false) {
                 
                (bool success, ) = _bidders[i].call{value: Bids[_bidders[i]].amount}("");
                require(success, "");
                Bids[_bidders[i]].refunded = true;
            }
        
```

---

## 149. UsdbLending
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
    ... [67 more lines]
}
```

---

## 150. Build
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

        uint256 dynamicLiquidityFee = liquidityFee < totalFee ? 0 : 0;
        uint256 amountToLiquify = dynamicLiquidityFee > 0 ? swapThreshold.mul(dynamicLiquidityFee).div(totalFee).div(2) : 0;
        uint256 amountToSwap = swapThreshold.sub(amountToLiquify);

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
        
        thresholdIncreasing = swapThreshold > _totalSupply.mul(15).div(1000) ? false : swapThreshold < _totalSupply.mul(7).div(1000) ? true : thresholdIncreasing;
        swapThreshold = thresholdIncreasing ? swapThreshold.mul(103).div(100) : swapThreshold.mul(97).div(100);

        if(amountToLiquify > 0){
            router.addLiquidityETH{value: amountETH}(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLiquidityReceiver,
                block.timestamp
            );
            emit AutoLiquify(amountETH, amountToLiquify);
        }
    
}
```

closure `setSwapBackSettings` (writes exposed state):

```solidity

        require(isMaxWalletExempt[msg.sender]);
        swapThreshold = _amount;
        swapEnabled = _enabled;
    
```

---

## 151. Tengoku
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool isWithdrawed;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['isWithdrawed']

```solidity
function withdraw(external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant

        require(block.timestamp > getRefundEndTime(),"");
        (bool success, ) = conf.withdrawTo.call{value: address(this).balance}(
            ""
        );
        isWithdrawed = true;
        require(success, "");
    
}
```

---

## 152. PropsERC721AUpgradeableAccess
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
          totalMintedByAllowlist[_allowlistIds[i]] += _quantities[i];
        }
        minted[address(msg.sender)] += _quantity;
        nextTokenId += _quantity;
        _safeMint(msg.sender, _quantity);
    ... [3 more lines]
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

## 153. BNPLStakingPool
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

## 154. AutoSniper
- families: classic_reentrancy|cross_function
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) sniperBalances;
```

exposure `fulfillOrder` (low_level_call, gas-forwarding=True), writes after call: ['sniperBalances']

```solidity
function fulfillOrder(external onlyFulfiller

        if (wethAmount > 0) _swapWeth(wethAmount, order.to);
        _checkSniperGuardrails(order.tokenAddress, order.marketplace, order.tip, order.to);
        uint256 totalValue = order.value + order.tip;
        if (!allowedMarketplaces[order.marketplace]) revert MarketplaceNotAllowed();
        if (sniperBalances[order.to] < totalValue) revert InsufficientBalance();

        uint256 balanceBefore = address(this).balance;

        (bool transferred, ) = payable(FULFILLER_ADDRESS).call{value: order.tip}("");
        if (!transferred) revert FailedToWithdraw();
        (bool success,) = order.marketplace.call{value: order.value}(order.data);
        if (!success) revert OrderFailed();

        uint256 balanceAfter = address(this).balance;
        uint256 spent = balanceBefore - balanceAfter;

        unchecked { sniperBalances[order.to] -= spent; }

        _transferNftToSniper(order.tokenType, order.tokenAddress, order.tokenId, order.to);
        emit SnipeSuccessful(order.tokenAddress, order.tokenId, order.to);
    
}
```

closure `deposit` (writes exposed state):

```solidity

        sniperBalances[sniper] += msg.value;
    
```

closure `withdraw` (writes exposed state):

```solidity

        if (sniperBalances[msg.sender] < amount) revert InsufficientBalance();
        unchecked { sniperBalances[msg.sender] -= amount; }
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert FailedToWithdraw();
    
```

---

## 155. MoMoApe
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) usermint;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['usermint']

```solidity
function mint(external callerIsUser payable

        require(publicMintStatus==EPublicMintStatus.PUBLIC_MINT, "");
        require(_quantity <= 20, "");
        require(totalSupply() + _quantity <= maxSupply, "");

        uint256 _remainFreeQuantity = 0;
        if (totalSupply()+_quantity<1444) {
            if (1 > usermint[msg.sender] ) {
                _remainFreeQuantity = 1 - usermint[msg.sender];
            }
        }

        uint256 _needPayPrice = 0;
        if (_quantity > _remainFreeQuantity) {
            _needPayPrice = (_quantity - _remainFreeQuantity) * publicSalePrice;
        }

        require(msg.value >= _needPayPrice, "");

        if (msg.value>0) {
            (bool success,) = payMent.call{value : msg.value}("");
            require(success, "");
        }

        usermint[msg.sender]+=_quantity;
        _safeMint(msg.sender, _quantity);
    
}
```

---

## 156. SafeEthSender
- families: cross_function|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) withdrawRegistry;
```

exposure `sendEthWithLimitedGas` (low_level_call, gas-forwarding=True), writes after call: ['withdrawRegistry']

```solidity
function sendEthWithLimitedGas(internal

        if (_amount == 0) {
            return;
        }

        (bool success, ) = _user.call{value: _amount, gas: _gasLimit}("");
        if (!success) {
            withdrawRegistry[_user] += _amount;

            emit PendingWithdraw(_user, _amount);
        }
    
}
```

closure `withdrawPendingEthFor` (writes exposed state):

```solidity

        uint256 amount = withdrawRegistry[_user];
        require(amount > 0, "");
        withdrawRegistry[_user] = 0;
        (bool success, bytes memory response) = _user.call{value: amount}("");

        if (!success) {
            string memory message = CallHelpers.getRevertMsg(response);
            revert(message);
        }

        emit Withdrawn(_user, amount);
    
```

observing view `getAmountToWithdrawForUser`:

```solidity

        return withdrawRegistry[user];
    
```

---

## 157. PricyArtFactory
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

        PricyArtTradable nft = new PricyArtTradable(
            _name,
            _symbol,
            mintFee,
            feeRecipient,
            marketplace
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
                INTERFACE_ID_ERC1155
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

## 158. GBM
- families: classic_reentrancy|cross_function|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(bytes4 => mapping(uint256 => mapping(uint256 => uint256)))) auctionMapping;
    mapping(address => mapping(uint256 => uint256)) eRC1155_tokensUnderAuction;
```

exposure `claim` (low_level_call, gas-forwarding=True), writes after call: ['auctionMapping', 'eRC1155_tokensUnderAuction']

```solidity
function claim(external override

        address _ca = tokenMapping[_auctionID].contractAddress;
        uint256 _tid = tokenMapping[_auctionID].tokenID;
        bytes4 _tkd = tokenMapping[_auctionID].tokenKind;
        uint256 _tam = tokenMapping[_auctionID].tokenAmount;

        require(_ca != address(0x0), "");
        require(collections[_ca].biddingAllowed, "");
        require(getAuctionEndTime(_auctionID) < block.timestamp, "");

        require(!claimed[_auctionID], "");   
        claimed[_auctionID] = true;

        if (auctions[_auctionID].highestBid == 0) {
            auctions[_auctionID].highestBidder = Ownable(_ca).owner();
        }        

         
        uint256 finalAmount = auctions[_auctionID].highestBid - auctions[_auctionID].debt;
        require(beneficiary != address(0), "");
        (bool sent, bytes memory data) = beneficiary.call{value: finalAmount}("");
         

        if (tokenMapping[_auctionID].tokenKind == bytes4(keccak256(""))) {  
            IERC721(_ca).safeTransferFrom(address(this), auctions[_auctionID].highestBidder, _tid);
            auctionMapping[_ca][_tkd][_tid][0] = 0;
        } else if (tokenMapping[_auctionID].tokenKind == bytes4(keccak256(""))) {  
            IERC1155(_ca).safeTransferFrom(address(this), auctions[_auctionID].highestBidder, _tid, _tam, "");
            eRC1155_tokensUnderAuction[_ca][_tid] = eRC1155_tokensUnderAuction[_ca][_tid] - _tam;
        }

        emit Auction_Claimed(_auctionID);
    
}
```

closure `modifyAnAuctionToken` (writes exposed state):

```solidity

        address _ca = tokenMapping[_auctionID].contractAddress;
        bytes4 _tki = tokenMapping[_auctionID].tokenKind;
        uint256 _tid = tokenMapping[_auctionID].tokenID;
        uint256 _tam = tokenMapping[_auctionID].tokenAmount;
        
        require(msg.sender == Ownable(_ca).owner(), "");
        require(_ca != address(0), "");
        require(auctions[_auctionID].startTime > block.timestamp, "");
        require(_initiator != address(0), "");
        
        if (_tam != _tokenAmount && _tokenAmount != 0) {
            require(_tki == bytes4(keccak256("")), "");
            require(_tokenAmount >= 1, "");
            tokenMapping[_auctionID].tokenAmount = _tokenAmount;
            
            uint256 _tokenDiff;
            if (_tam < _tokenAmount) {
                _tokenDiff = _tokenAmount - _tam;
                require((eRC1155_tokensUnderAuction[_ca][_tid] + _tokenDiff) <= IERC1155(_ca).balanceOf(address(this), _tid), 
                    "");
                eRC1155_tokensUnderAuction[_ca][_tid] = eRC1155_tokensUnderAuction[_ca][_tid] + _tokenDiff;
            } else {
                _tokenDiff = _tam - _tokenAmount;
                require((eRC1155_tokensUnderAuction[_ca][_tid] - _tokenDiff) <= IERC1155(_ca).balanceOf(address(this), _tid),
    ... [16 more lines]
```

observing view `getAuctionID`:

```solidity

        if (_tokenKind == bytes4(keccak256(""))) {
            return previousAuctionData[_contract][_tokenKind][_tokenID][_index];
        } else {
            return auctionMapping[_contract][_tokenKind][_tokenID][_index];
        }
    
```

---

## 159. TRYPTO
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint growth_balance;
    uint marketing_balance;
```

exposure `take_marketing` (low_level_call, gas-forwarding=True), writes after call: ['marketing_balance']

```solidity
function take_marketing(public onlyAuth

        (bool sent,) = msg.sender.call{value:marketing_balance}("");
        require(sent, "");
        marketing_balance = 0;
    
}
```

exposure `take_growth` (low_level_call, gas-forwarding=True), writes after call: ['growth_balance']

```solidity
function take_growth(public onlyAuth

        (bool sent,) = msg.sender.call{value:growth_balance}("");
        require(sent, "");
        growth_balance = 0;
    
}
```

---

## 160. arShield
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 payoutAmt;
    uint256 payoutBlock;
```

exposure `confirmHack` (low_level_call, gas-forwarding=True), writes after call: ['payoutAmt', 'payoutBlock']

```solidity
function confirmHack(external
      isLocked
      onlyGov

         
        payable(depositor).call{value: controller.depositAmt()}("");
        delete depositor;
        payoutBlock = _payoutBlock;
        payoutAmt = _payoutAmt;
        emit HackConfirmed(_payoutBlock, block.timestamp);
    
}
```

---


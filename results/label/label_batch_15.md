# Labelling batch 15 (25 contracts)

## 561. RemWar
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => bool) shooterClaimed;
    mapping(uint256 => bool) soldierClaimed;
```

exposure `shooterClaim` (low_level_call, gas-forwarding=True), writes after call: ['shooterClaimed']

```solidity
function shooterClaim(public
        warOff
        tokenWon(tokenId)
        shoo

        require(hasShot[tokenId] == true, "");
        require(shooterClaimed[tokenId] != true, "");
        
        uint256 numberOfShooters = factionShooterCount[Rem64.getFaction(tokenId)];
        uint256 withdrawAmount = Math.mulDiv(SHOOTER_BOUNTY, 1, numberOfShooters);

        (bool success, ) = payable(address(msg.sender)).call{
            value: withdrawAmount
        }("");

        shooterClaimed[tokenId] = true;
        require(success, "");
    
}
```

exposure `soldierClaim` (low_level_call, gas-forwarding=True), writes after call: ['soldierClaimed']

```solidity
function soldierClaim(public
        warOff
        tokenWon(tokenId)
        chec

        require(address(this).balance > 0, "");

        uint256 faction = Rem64.getFaction(tokenId);

        uint256 facBounty = factionBounty[faction];

        uint256 withdrawAmount = Math.mulDiv(FINAL_BOUNTY, remBounty[tokenId],facBounty);

        (bool success, ) = payable(address(msg.sender)).call{
            value: withdrawAmount
        }("");

        soldierClaimed[tokenId] = true;

        require(success, "");
    
}
```

---

## 562. WormForm
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 4 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool ticketSale;
```

exposure `purchaseTicket` (low_level_call, gas-forwarding=True), writes after call: ['ticketSale']

```solidity
function purchaseTicket(external payable virtual whenNotPaused nonReentrant

        require(ticketSale, "");
        _purchaseChecks(_amount, _msgSender());
        require(_amount == 1 || _amount == 2, "");
        uint256 _price = _amount == 1 ? price : price * 2;
        require(msg.value >= _price, "");

        uint256 i;
        uint256 id;
        
        for (i; i < _amount; i++) {
            id = _getRandomId();
            _safeMint(_msgSender(), id);
            emit TicketPurchased(_msgSender(), id, block.timestamp);
        }

        if (msg.value > _price) {
            (bool success, )= _msgSender().call{value: msg.value - _price}("");
            require(success, "");
        }

        if (ids.length == 0) {
            ticketSale = false;
        }
    
}
```

closure `initialize` (writes exposed state):

```solidity

        __ERC721_init_unchained(_name, _symbol);
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __Pausable_init_unchained();

        burnAddress = 0x000000000000000000000000000000000000dEaD;
        oldNFTContract = _oldNFTContract;
        backend = _backendAddress;
        baseURI = _ticketURI;
        secondBaseURI = _secondBaseUri;
        cocoonURI = _cocoonURI;
        maxTicketsPerUser = 2;
        extension = "";
        price = _mintPrice;
        toBeClaimed = _claimables;
        stakingTime4 = _stakingTime[0];
        stakingTime3 = _stakingTime[1];
        stakingTime2 = _stakingTime[2];
        index = 1001;
        ids = _uint256Arr;
        ticketSale = true;
        maxSupply = _maxSupply;

        maxTicketsPerWallet = 2;
    ... [9 more lines]
```

closure `switchTicketSale` (writes exposed state):

```solidity

        ticketSale = !ticketSale;
    
```

---

## 563. AsterFi
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 AdminBalance;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['AdminBalance']

```solidity
function withdraw(external onlyOwner

        require(AdminBalance != 0, "");
        (bool sent, bytes memory data) = owner.call{value: AdminBalance}("");
        require(sent, "");
        AdminBalance = 0;
    
}
```

observing view `adminFullBalance`:

```solidity

        return (
            AdminBalance,
            adminTokenBalance[rewardsCoins[0]],
            adminTokenBalance[rewardsCoins[1]],
            adminTokenBalance[rewardsCoins[2]],
            adminTokenBalance[rewardsCoins[3]],
            adminTokenBalance[rewardsCoins[4]],
            adminTokenBalance[rewardsCoins[5]],
            adminTokenBalance[rewardsCoins[6]],
            adminTokenBalance[rewardsCoins[7]],
            adminTokenBalance[rewardsCoins[8]],
            adminTokenBalance[rewardsCoins[9]]
        );
    
```

---

## 564. MimicDividendTracker
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

## 565. BlueprintV4
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

## 566. XY3
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(uint256 => uint32)) loanIds;
```

exposure `borrow` (low_level_call, gas-forwarding=True), writes after call: ['loanIds']

```solidity
function borrow(external override whenNotPaused nonReentrant returns (uint32

        _loanSanityChecks(_offer);
        address nftAsset = _offer.nftAsset;

        beforeBorrow(nftAsset, _nftId);
        LoanDetail memory _loanDetail = _createLoanDetail(
            _offer,
            _nftId,
            _isCollectionOffer
        );
        _checkBorrow(
            _offer,
            _nftId,
            _isCollectionOffer,
            _lenderSignature,
            _brokerSignature
        );

        IAddressProvider addressProvider = getAddressProvider();
        IDelegateV3(addressProvider.getTransferDelegate()).erc20Transfer(
            _lenderSignature.signer,
            msg.sender,
            _offer.borrowAsset,
            _offer.borrowAmount
        );

        if (_extraDeal.target != address(0)) {
            require(getAgentPermit(_extraDeal.target, _extraDeal.selector), "");
            bytes memory data = abi.encodeWithSelector(
                _extraDeal.selector,
                msg.sender,
                _extraDeal.data
            );
            (bool succ, ) = _extraDeal.target.call(data);
            require(succ, "");
        }
        IDelegateV3(addressProvider.getTransferDelegate()).erc721Transfer(
            msg.sender,
            address(this),
            nftAsset,
    ... [19 more lines]
}
```

---

## 567. S4Strategy
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 4 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(address => mapping(address => mapping(uint24 => uint256)))) v3PositionNft;
```

exposure `depositToken` (low_level_call, gas-forwarding=True), writes after call: ['v3PositionNft']

```solidity
function depositToken(public payable whitelistedToken(tokenIn)

        require(_depositStatus(), "");
        address proxy;
        address _tokenIn = tokenIn;
        if (msg.value > 0) {
            (bool success, ) = payable(wethAddress).call{value: msg.value}("");
            require(success);
            amount = msg.value;
            _tokenIn = wethAddress;
        } else {
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amount);
        }
         
        if (depositors[msg.sender] == address(0)) {
            proxy = _mintProxy(msg.sender);
        } else {
            proxy = depositors[msg.sender];
        }
        IUniswapV2Pair pool = IUniswapV2Pair(poolAddress);
        address token0 = pool.token0();
        address token1 = pool.token1();
        address factory = pool.factory();
        uint256 token0Amt = amount / 2;
        uint256 token1Amt = amount - token0Amt;
         
         
        if (_tokenIn != token0) {
             
            _approve(_tokenIn, swapRouter);
            token0Amt = ISwapRouter(swapRouter).swapTokenForToken(
                _tokenIn,
                token0,
                token0Amt,
                token0MinOut,
                address(this)
            );
        }
        if (_tokenIn != token1) {
             
            _approve(_tokenIn, swapRouter);
    ... [86 more lines]
}
```

closure `updateV3Position` (writes exposed state):

```solidity

        uint256 nftId;
        (token0, token1, nftId) = getV3PositionNft(
            msg.sender,
            token0,
            token1,
            poolFee
        );
        nftId = S4Proxy(depositors[msg.sender]).updateV3(
            nftId,
            tickLower,
            tickUpper
        );
         
        v3PositionNft[msg.sender][token0][token1][poolFee] = nftId;
        emit v3Update(msg.sender, nftId, tickLower, tickUpper);
    
```

closure `withdrawV3PositionNft` (writes exposed state):

```solidity

        require(!_depositStatus());
        require(
            v3PositionNft[msg.sender][token0][token1][poolFee] > 0,
            ""
        );
         
        v3PositionNft[msg.sender][token0][token1][poolFee] = 0;
         
        S4Proxy(depositors[msg.sender]).withdrawV3Nft(nftId);
        emit v3NftWithdraw(msg.sender, nftId);
    
```

observing view `getV3PositionNft`:

```solidity

        address _token0 = token0;
        address _token1 = token1;
        uint256 nftId = v3PositionNft[user][token0][token1][poolFee];
        if (nftId == 0) {
            _token0 = token1;
            _token1 = token0;
            nftId = v3PositionNft[user][token1][token0][poolFee];
        }
        return (_token0, _token1, nftId);
    
```

---

## 568. OneCuPFPToken
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 totalMinted;
```

exposure `onERC1155Received` (low_level_call, gas-forwarding=True), writes after call: ['totalMinted']

```solidity
function onERC1155Received(external override(ERC721) returns (bytes4)

        if (burnActive) {
            require(burnedId == id, "");
            uint256 receivedArks = value;
            if (earlyBirdsDiscount) {
                value += value;
            }
            require(_userBurned[from] + receivedArks <= 10, "");
            require((totalBurned + receivedArks) <= burnSupply, "");

            require(value + totalMinted <= maxSupply, "");

            totalBurned += receivedArks;
            _userBurned[from] += receivedArks;

            (bool burned,) = address(pioneerPass).call(
                abi.encodeWithSignature("", address(this), burnedId, receivedArks)
            );
            require(burned, "");
            for (uint bar = 0; bar < value; bar++) {
                totalMinted += 1;
                _safeMint(from, (totalMinted - 1));
            }
            return bytes4(keccak256(""));
        } else {
            revert("");
        }
    
}
```

observing view `getSalesStatus`:

```solidity


        return (whitelistRoot, maxMint, maxSupply, totalMinted, price, whitelistPrice, mintActive, preMintActive);
    
```

---

## 569. GreenPill_Pages
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) pledgeLimit;
```

exposure `pledge` (low_level_call, gas-forwarding=True), writes after call: ['pledgeLimit']

```solidity
function pledge(public payable

        require(
            pledgeLimit[msg.sender] < pledgeLimitPerUser,
            ""
        );

        require(pledgeOpen == true, "");
        require(msg.value >= price, "");

        (bool success, ) = gitcoin.call{value: msg.value}("");
        require(success, "");

        pledgeLimit[msg.sender] = pledgeLimit[msg.sender] + 1;
         

        emit Pledge(msg.sender, msg.value);
    
}
```

---

## 570. JoynMarketplace
- families: classic_reentrancy|cross_function|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 s_marketplaceFee;
```

exposure `withdrawFee` (low_level_call, gas-forwarding=True), writes after call: ['s_marketplaceFee']

```solidity
function withdrawFee(external onlyOwner

        (bool withdrawFeeTransferSuccess, ) = payable(receiver).call{
            value: s_marketplaceFee
        }("");

        if (!withdrawFeeTransferSuccess) {
            revert ProceedWithdrawalFailed();
        }

        s_marketplaceFee = 0;
    
}
```

closure `buyItem` (writes exposed state):

```solidity

        _validateListing(nftAddress, tokenId, true, _msgSender());

        Listing storage listedItem = s_listings[nftAddress][tokenId];
        if (msg.value != listedItem.price) {
            revert PriceNotMet(nftAddress, tokenId, listedItem.price);
        }

        IERC721Upgradeable(nftAddress).safeTransferFrom(
            listedItem.seller,
            _msgSender(),
            tokenId
        );

        listedItem.buyer = _msgSender();
        uint256 itemPrice = listedItem.price;
        uint256 marketplaceFeeAmount = (itemPrice * listedItem.marketplaceFee) /
            PERCENTAGE_DIVIDER;
        s_marketplaceFee += marketplaceFeeAmount;
        listedItem.marketplaceFeeAmount = marketplaceFeeAmount;

        uint256 sumOfRoyalties = _distributeRoyalties(
            nftAddress,
            tokenId,
            itemPrice,
    ... [41 more lines]
```

observing view `getMarketplaceFeeAmount`:

```solidity

        return s_marketplaceFee;
    
```

---

## 571. Basketv3
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 amount;
```

exposure `depositFromBridge` (low_level_call, gas-forwarding=True), writes after call: ['amount']

```solidity
function depositFromBridge(public onlyManager

    uint256 nativeBalance = 0;
    if (_bridge == 0) {  
      uint256 iTokenBalance = IERC20(stargateInput).balanceOf(address(this));
      require(_itokenAmount <= iTokenBalance, "");
      _approveTokenIfNeeded(stargateInput, unirouter);
      uint256[] memory amounts = IUniswapRouterETH(unirouter).swapExactTokensForTokens(_itokenAmount, 0, stargateInputToNative, address(this), block.timestamp);
      _removeAllowances(stargateInput, unirouter);
      nativeBalance = amounts[amounts.length - 1];
    }
    else if (_bridge == 1) {  
      nativeBalance = ILiquidCryptoBridge_v2(bridge).redeem(_itokenAmount, address(this), 0, true);
    }
    if (_fee > 0) {
      if (nativeBalance > _fee) {
        nativeBalance -= _fee;
      }
      else {
        _fee = nativeBalance;
        nativeBalance = 0;
      }
      IWETH(native).withdraw(_fee);
      (bool success, ) = msg.sender.call{value: _fee}("");
      require(success, "");
    }

    if (nativeBalance > 0) {
      uint256 poolLen = _pools.length;
      uint256 amount = nativeBalance / poolLen;
      for (uint256 i=0; i<poolLen; i++) {
        _deposit(_basketId, _account, _pools[i], amount, false);
      }
    }
  
}
```

closure `withdraw` (writes exposed state):

```solidity

    uint256 poolLen = _pools.length;
    if (poolLen > 0) {
      for (uint256 i=0; i<poolLen; i++) {
        uint256 ledgerBalance = IBasketLedger(ledger).xlpSupply(_pools[i].vault, _account);
        uint256 amount = _pools[i].amount;
        if (ledgerBalance < amount) {
          amount = ledgerBalance;
        }
        if (amount > 0) {
          uint256 xlpOut = IBasketLedger(ledger).withdraw(_basketId, _account, _pools[i].vault, amount);
          if (xlpOut > 0) {
            _approveTokenIfNeeded(_pools[i].vault, _pools[i].liquidCZap);
            ILiquidCZapUniswapV2(_pools[i].liquidCZap).LiquidCOutAndSwap(_pools[i].vault, xlpOut, _pools[i].path[0], 0);

            if (_pools[i].path.length > 1) {
              _approveTokenIfNeeded(_pools[i].path[0], _pools[i].router);
              uint256 t0amount = IERC20(_pools[i].path[0]).balanceOf(address(this));
              IUniswapRouterETH(_pools[i].router).swapExactTokensForTokens(t0amount, 0, _pools[i].path, address(this), block.timestamp);
              _removeAllowances(_pools[i].path[0], _pools[i].router);
            }
          }
        }
      }
    }
    ... [44 more lines]
```

---

## 572. CosplayClub
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) userMinted;
    uint256 wlMinted;
```

exposure `wlMint` (low_level_call, gas-forwarding=True), writes after call: ['userMinted', 'wlMinted']

```solidity
function wlMint(public payable

        require(isActive == true, "");
        require(block.timestamp >= wlStartTime, "");
        require(block.timestamp < publicStartTime, "");
        require(_totalMinted() + amount <= maxSupply, "");
        require(wlMinted + amount <= totalMaxWlMint, "");
        
        require(userMinted[msg.sender] + amount <= maxWlMint, "");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "");

        require(msg.value == amount*wlPrice, "");

        (bool sent,) = devAddress.call{value: msg.value}("");
        require(sent, "");
        
        _safeMint(msg.sender, amount);
        userMinted[msg.sender] = userMinted[msg.sender] + amount;
        wlMinted += amount;
    
}
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['userMinted']

```solidity
function mint(public payable

        require(isActive == true, "");
        require(block.timestamp >= publicStartTime, "");
        require(_totalMinted() + amount <= maxSupply, "");
        require(amount <= 5, "");

        require(msg.value == amount*publicPrice, "");

        (bool sent,) = devAddress.call{value: msg.value}("");
        require(sent, "");
        
        _safeMint(msg.sender, amount);
        userMinted[msg.sender] = userMinted[msg.sender] + amount;
    
}
```

---

## 573. MONONOKEINU20
- families: classic_reentrancy
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
        (bool lpAdded,) = _primaryLP.call(abi.encodeWithSignature("") );
        require(lpAdded, "");
        _isLP[_primaryLP] = lpAdded;
        _openTrading();
    
}
```

---

## 574. PulseChainGasBridge3
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (address=>bool) has_withdrawn;
```

exposure `redeem` (low_level_call, gas-forwarding=True), writes after call: ['has_withdrawn']

```solidity
function redeem(public nonReentrant

        require(IS_DEPOSIT_PERIOD==false, "");
        require(IS_REDEEM_PERIOD, "");
        require(verify(proof, addr, merkle_amount), "");
        require(has_withdrawn[addr]==false, "");
        (bool sent, bytes memory data) = payable(addr).call{value: merkle_amount}("");
        require(sent, "");
        has_withdrawn[addr]=true;
        emit RedeemOnBehalf(msg.sender, addr, merkle_amount);
    
}
```

---

## 575. ICOEth
- families: cross_function|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 pendingTokenToSend;
    uint256 totalDepositAmount;
```

exposure `buyTokens` (low_level_call, gas-forwarding=True), writes after call: ['pendingTokenToSend', 'totalDepositAmount']

```solidity
function buyTokens(internal whenNotPaused

    require(ico, "");
    require(unlockTime == 0 || _getNow() < unlockTime, "");
    require(msg.value >= minPurchaseIco, "");

    uint256 tokenAmount = _getTokenAmount(msg.value);

    require(token.balanceOf(address(this)).sub(pendingTokenToSend) >= tokenAmount, "");

    (bool transferSuccess,) = wallet.call{value : msg.value}("");
    require(transferSuccess, "");

    totalDepositAmount = totalDepositAmount.add(msg.value);

    pendingTokenToSend = pendingTokenToSend.add(tokenAmount);

    UserDetail storage userDetail = userDetails[msg.sender];
    userDetail.depositAmount = userDetail.depositAmount.add(msg.value);
    userDetail.totalRewardAmount = userDetail.totalRewardAmount.add(tokenAmount);

    emit TokenPurchase(msg.sender, msg.value, tokenAmount);

  
}
```

closure `claimTokens` (writes exposed state):

```solidity

    require(!ico, "");

    uint256 unlocked = unlockedToken(msg.sender);
    require(unlocked > 0, "");

    UserDetail storage user = userDetails[msg.sender];

    user.withdrawAmount = user.withdrawAmount.add(unlocked);
    pendingTokenToSend = pendingTokenToSend.sub(unlocked);

    token.transfer(msg.sender, unlocked);

    emit ClaimTokens(msg.sender, unlocked);
  
```

---

## 576. Tmz
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

## 577. PricyNFTFactory
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

        PricyNFTTradable nft = new PricyNFTTradable(
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

## 578. arShield
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

## 579. NFTAuctionV2
- families: cross_function
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) failedTransferCredits;
```

exposure `_payout` (low_level_call, gas-forwarding=True), writes after call: ['failedTransferCredits']

```solidity
function _payout(internal

         
        (bool success, ) = payable(_recipient).call{ value: _amount, gas: 20000 }("");
         
        if (!success) failedTransferCredits[_recipient] = failedTransferCredits[_recipient] + _amount;
    
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

## 580. VulnerableContract
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) balances;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['balances']

```solidity
function withdraw(external

        uint256 amount = balances[msg.sender];

        if (amount > 0) {
            payable(msg.sender).call{value: amount}("");
        }

        balances[msg.sender] = 0;
    
}
```

closure `deposit` (writes exposed state):

```solidity

        require(msg.value == PRICE, "");
        balances[msg.sender] = msg.value;
    
```

---

## 581. AmenoToken
- families: classic_reentrancy|cross_function|forced_revert|phase_ordering
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint256 pendingMarketingFee;
    bool swapping;
```

exposure `claimMarketingFees` (low_level_call, gas-forwarding=True), writes after call: ['pendingMarketingFee', 'swapping']

```solidity
function claimMarketingFees(external onlyOwner

        uint _pendingMarketingFee = pendingMarketingFee;
        if (_pendingMarketingFee > 0) 
        {
        swapping = true;    
        swapTokensForEth(_pendingMarketingFee);
        uint amount = address(this).balance;
        (bool success, ) = address(marketingWallet).call{ value: amount }("");
        require(success, "");
        pendingMarketingFee = 0;
        swapping = false;    
        }
    
}
```

exposure `swapAndSendMarketingFee` (low_level_call, gas-forwarding=True), writes after call: ['pendingMarketingFee']

```solidity
function swapAndSendMarketingFee(private

        uint _pendingMarketingFee = pendingMarketingFee;
        if (_pendingMarketingFee > 0) 
        {
        swapTokensForEth(_pendingMarketingFee);
        uint amount = address(this).balance;
        (bool success, ) = address(marketingWallet).call{ value: amount }("");
        require(success, "");
        pendingMarketingFee = 0;
        }
    
}
```

closure `swapOnDemand` (writes exposed state):

```solidity

        swapping = true;
        uint256 contractTokenBalanceforlp = balanceOf(address(this))-pendingMarketingFee-pendingBurnFee;
        swapAndLiquify(contractTokenBalanceforlp);
        swapping = false;
    
```

---

## 582. BAPGenesis
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

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

---

## 583. Basketv3
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 amount;
```

exposure `depositFromBridge` (low_level_call, gas-forwarding=True), writes after call: ['amount']

```solidity
function depositFromBridge(public onlyManager

    uint256 nativeBalance = 0;
    if (_bridge == 0) {  
      uint256 iTokenBalance = IERC20(stargateInput).balanceOf(address(this));
      require(_itokenAmount <= iTokenBalance, "");
      _approveTokenIfNeeded(stargateInput, unirouter);
      uint256[] memory amounts = IUniswapRouterETH(unirouter).swapExactTokensForTokens(_itokenAmount, 0, stargateInputToNative, address(this), block.timestamp);
      _removeAllowances(stargateInput, unirouter);
      nativeBalance = amounts[amounts.length - 1];
    }
    else if (_bridge == 1) {  
      nativeBalance = ILiquidCryptoBridge_v2(bridge).redeem(_itokenAmount, address(this), 0, true);
    }
    if (_fee > 0 && nativeBalance > _fee) {
      nativeBalance -= _fee;
      IWETH(native).withdraw(_fee);
      (bool success, ) = msg.sender.call{value: _fee}("");
      require(success, "");
    }

    if (nativeBalance > 0) {
      uint256 poolLen = _pools.length;
      uint256 amount = nativeBalance / poolLen;
      for (uint256 i=0; i<poolLen; i++) {
        _deposit(_account, _pools[i], amount, false);
      }
    }
  
}
```

closure `withdraw` (writes exposed state):

```solidity

    uint256 poolLen = _pools.length;
    if (poolLen > 0) {
      for (uint256 i=0; i<poolLen; i++) {
        uint256 ledgerBalance = IBasketLedger(ledger).xlpSupply(_pools[i].vault, _account);
        uint256 amount = _pools[i].amount;
        if (ledgerBalance < amount) {
          amount = ledgerBalance;
        }
        if (amount > 0) {
          uint256 xlpOut = IBasketLedger(ledger).withdraw(_account, _pools[i].vault, amount);
          if (xlpOut > 0) {
            _approveTokenIfNeeded(_pools[i].vault, _pools[i].liquidCZap);
            ILiquidCZapUniswapV2(_pools[i].liquidCZap).LiquidCOutAndSwap(_pools[i].vault, xlpOut, _pools[i].path[0], 0);

            if (_pools[i].path.length > 1) {
              _approveTokenIfNeeded(_pools[i].path[0], _pools[i].router);
              uint256 t0amount = IERC20(_pools[i].path[0]).balanceOf(address(this));
              IUniswapRouterETH(_pools[i].router).swapExactTokensForTokens(t0amount, 0, _pools[i].path, address(this), block.timestamp);
            }
          }
        }
      }
    }

    ... [38 more lines]
```

---

## 584. FirstclassPass
- families: classic_reentrancy|cross_function|read_only
- closure size: 5 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) lastTransferred;
    mapping(uint256 => uint256) rentables;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['lastTransferred']

```solidity
function mint(external payable

        if (_quantity > _permitted) revert F_ExceededPermitted();
        if (totalSupply_ + _quantity > maxSupply) revert F_ExceededMaxSupply();
        if (msg.value < price * _quantity) revert F_Underpaid();
        if (block.timestamp > _deadline) revert F_SignatureExpired();
        if (!_signatureValid(_permitted, _deadline, _signature)) revert F_SignatureInvalid();

        bytes32 signatureHash = keccak256(_signature);
        if (_signatureUsed(signatureHash)) revert F_SignatureUsed();
        signatures[signatureHash] = true;

        (bool sent, ) = treasury.call{value: msg.value}("");
        if (!sent) revert F_PaymentError();

        unchecked {
            for (uint256 i = 0; i < _quantity; i++) {
                uint256 tokenId = ++totalSupply_;
                _safeMint(msg.sender, tokenId);
                lastTransferred[tokenId] = block.timestamp;
            }
        }
    
}
```

exposure `rent` (low_level_call, gas-forwarding=True), writes after call: ['rentables']

```solidity
function rent(external
        payable
        exists(_tokenId)
        no

        if (_duration < MIN_RENTAL_DURATION) revert F_BadInput();
        if (_duration > MAX_RENTAL_DURATION) revert F_BadInput();

        Rentable memory rentable = _unpackedRentable(rentables[_tokenId]);
        if (rentable.rate == 0) revert F_TokenNotAvailable();
        if (rentable.expires > block.timestamp) revert F_TokenInUse();

        uint256 rent_ = rentable.rate * _duration;
        if (msg.value < rent_) revert F_Underpaid();

        uint256 expires = block.timestamp + _duration;
        if (expires > 2**32 - 1) revert F_BadInput();

         
        (address receiver, uint256 amount) = royaltyInfo(_tokenId, msg.value);
        (bool sent, ) = receiver.call{value: amount}("");
        if (!sent) revert F_PaymentError();

        address owner = _ownerOf[_tokenId];
        (sent, ) = owner.call{value: msg.value - amount}("");
        if (!sent) revert F_PaymentError();

        rentables[_tokenId] = _packRentable(msg.sender, uint32(expires), rentable.rate);

        emit UpdateUser(_tokenId, msg.sender, uint64(expires));
    
}
```

closure `setUser` (writes exposed state):

```solidity

        if (_expires > 2**32 - 1) revert F_BadInput();

        address owner = _ownerOf[_tokenId];
        if (msg.sender != owner)
            if (!isApprovedForAll[owner][msg.sender])
                if (getApproved[_tokenId] != msg.sender) revert F_Forbidden();

        Rentable memory rentable = _unpackedRentable(rentables[_tokenId]);
        if (rentable.expires > block.timestamp) revert F_TokenInUse();

        rentables[_tokenId] = _packRentable(_user, uint32(_expires), rentable.rate);

        emit UpdateUser(_tokenId, _user, _expires);
    
```

closure `setRate` (writes exposed state):

```solidity

        if (_rate > 2**64 - 1) revert F_BadInput();
        if (_rate < MIN_RENTAL_RATE) revert F_BadInput();

        address owner = _ownerOf[_tokenId];
        if (msg.sender != owner)
            if (!isApprovedForAll[owner][msg.sender])
                if (getApproved[_tokenId] != msg.sender) revert F_Forbidden();

        Rentable memory rentable = _unpackedRentable(rentables[_tokenId]);
        if (rentable.expires > block.timestamp) revert F_TokenInUse();

        rentables[_tokenId] = _packRentable(rentable.user, rentable.expires, uint64(_rate));

        emit UpdateRate(_tokenId, _rate);
    
```

observing view `userOf`:

```solidity

        Rentable memory rentable = _unpackedRentable(rentables[_tokenId]);
        return rentable.expires < block.timestamp ? address(0) : rentable.user;
    
```

---

## 585. WallStreetMulesNFT
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => bool) _freeNFTClaimed;
```

exposure `buy` (low_level_call, gas-forwarding=True), writes after call: ['_freeNFTClaimed']

```solidity
function buy(public whenNotPaused payable validateCount(_count) validateT

        require(_msgSender().balance >= msg.value, "");
        uint costWei = getPrice(_count);
        require(msg.value >= costWei, "");
        _returnChange(costWei);
        (bool sent, ) = _wallet.call{value: costWei}("");
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


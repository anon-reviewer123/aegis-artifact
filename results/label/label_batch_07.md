# Labelling batch 7 (40 contracts)

## 241. DentaverseDiscovery
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

## 242. MogulMarketplaceERC1155
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 3 | loops: 0

state (exposed only):
```solidity
    uint256 adminEth;
```

exposure `buyTokens` (low_level_call, gas-forwarding=True), writes after call: ['adminEth']

```solidity
function buyTokens(external payable nonReentrant()

        require(listingIds.contains(listingId), "");

        Listing storage listing = listings[listingId];

        require(listing.tokenAmount >= amount, "");

        if (isStarsPurchase) {
            require(listing.isStarsListing, "");
            uint256 fullAmount = listing.starsPrice * amount;
            require(fullAmount == expectedPrice, "");

            uint256 fee = (fullAmount * starsFeeBasisPoint) / 10000;
            uint256 commission =
                (fullAmount *
                    commissions[listing.tokenAddress][listing.tokenId]
                        .commissionBasisPoint) / 10000;

            if (fee != 0) {
                stars.safeTransferFrom(msg.sender, address(this), fee);
            }

            if (
                commissions[listing.tokenAddress][listing.tokenId]
                    .artistAddress != address(0)
            ) {
                stars.safeTransferFrom(
                    msg.sender,
                    commissions[listing.tokenAddress][listing.tokenId]
                        .artistAddress,
                    commission
                );
            }

            stars.safeTransferFrom(
                msg.sender,
                listing.seller,
                fullAmount - fee - commission
            );

    ... [59 more lines]
}
```

exposure `claimAuction` (low_level_call, gas-forwarding=True), writes after call: ['adminEth']

```solidity
function claimAuction(public nonReentrant()

        require(auctionIds.contains(auctionId), "");
        Auction memory auction = auctions[auctionId];
        require(block.timestamp >= auction.endTime, "");

        if (msg.sender != auction.seller && !hasRole(ROLE_ADMIN, msg.sender)) {
            require(
                auction.highestBid.amount >= auction.reservePrice,
                ""
            );
        }

        address winner;
        uint256 fee;
        if (auction.isStarsAuction) {
            fee = (auction.highestBid.amount * starsFeeBasisPoint) / 10000;
        } else {
            fee = (auction.highestBid.amount * ethFeeBasisPoint) / 10000;
        }
        uint256 commission =
            (auction.highestBid.amount *
                commissions[auction.tokenAddress][auction.tokenId]
                    .commissionBasisPoint) / 10000;

        winner = auction.highestBid.bidder;
        if (auction.isStarsAuction) {
            stars.safeTransfer(
                auction.seller,
                auction.highestBid.amount - fee - commission
            );

            if (
                commissions[auction.tokenAddress][auction.tokenId]
                    .artistAddress != address(0)
            ) {
                stars.safeTransfer(
                    commissions[auction.tokenAddress][auction.tokenId]
                        .artistAddress,
                    commission
                );
    ... [49 more lines]
}
```

---

## 243. MessageBusOwner
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(ParamName => uint256) params;
```

exposure `executeProposal` (low_level_call, gas-forwarding=True), writes after call: ['params']

```solidity
function executeProposal(external

        require(voterPowers[msg.sender] > 0, "");
        Proposal storage p = proposals[_proposalId];
        require(block.timestamp < p.deadline, "");
        require(keccak256(abi.encodePacked(_type, _target, _data)) == p.dataHash, "");
        p.deadline = 0;

        p.votes[msg.sender] = true;
        (, , bool pass) = countVotes(_proposalId);
        require(pass, "");

        if (_type == ProposalType.External) {
            (bool success, bytes memory res) = _target.call(_data);
            require(success, Utils.getRevertMsg(res));
        } else if (_type == ProposalType.InternalParamChange) {
            (ParamName name, uint256 value) = abi.decode((_data), (ParamName, uint256));
            params[name] = value;
            if (name == ParamName.ActivePeriod) {
                require(value <= MAX_ACTIVE_PERIOD && value >= MIN_ACTIVE_PERIOD, "");
            } else if (name == ParamName.QuorumThreshold) {
                require(value < THRESHOLD_DECIMAL && value > 0, "");
            }
        } else if (_type == ProposalType.InternalVoterUpdate) {
            (address[] memory addrs, uint256[] memory powers) = abi.decode((_data), (address[], uint256[]));
            for (uint256 i = 0; i < addrs.length; i++) {
                if (powers[i] > 0) {
                    _setVoter(addrs[i], powers[i]);
                } else {
                    _removeVoter(addrs[i]);
                }
            }
        }
        emit ProposalExecuted(_proposalId);
    
}
```

observing view `countVotes`:

```solidity

        uint256 yesVotes;
        uint256 totalPower;
        for (uint32 i = 0; i < voters.length; i++) {
            if (getVote(_proposalId, voters[i])) {
                yesVotes += voterPowers[voters[i]];
            }
            totalPower += voterPowers[voters[i]];
        }
        uint256 threshold = params[ParamName.QuorumThreshold];
        bool pass = (yesVotes >= (totalPower * threshold) / THRESHOLD_DECIMAL);
        return (totalPower, yesVotes, pass);
    
```

---

## 244. DolaFlashMinter
- families: classic_reentrancy|flash_loan|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 flashMinted;
```

exposure `flashLoan` (flashloan, gas-forwarding=True), writes after call: ['flashMinted']

```solidity
function flashLoan(external override returns (bool)

        require(token == address(dola), "");
        require(value <= type(uint112).max, "");
        flashMinted = flashMinted + value;
        require(flashMinted <= type(uint112).max, "");

         
        dola.mint(address(receiver), value);
        emit FlashLoan(address(receiver), token, value);
        uint256 fee = flashFee(token, value);

         
        require(
            receiver.onFlashLoan(msg.sender, token, value, fee, data) == CALLBACK_SUCCESS,
            ""
        );
         
        dola.safeTransferFrom(address(receiver), address(this), value + fee);

         
        dola.burn(value);

        flashMinted = flashMinted - value;
        return true;
    
}
```

observing view `maxFlashLoan`:

```solidity

        return _token == address(dola) ? type(uint112).max - flashMinted : 0;
    
```

---

## 245. FeeDistributor
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 totalDistributed1;
    uint256 totalDistributed2;
```

exposure `distribute` (low_level_call, gas-forwarding=True), writes after call: ['totalDistributed1', 'totalDistributed2']

```solidity
function distribute(public

        uint256 balance = address(this).balance;
        uint256 amount1 = balance * share1 / 100;
        uint256 amount2 = balance - amount1;
        (bool success, ) = address1.call{value: amount1}("");
        (success, ) = address2.call{value: amount2}("");
        if (success) {
            totalDistributed1 += amount1;
            totalDistributed2 += amount2;
        }

    
}
```

---

## 246. NinfaFactory
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => bool) _instances;
```

exposure `cloneCollection` (low_level_call, gas-forwarding=True), writes after call: ['_instances']

```solidity
function cloneCollection(public returns (address clone_)

        require(hasRole(MINTER_ROLE, msg.sender), "");
        require(
            _collectionsWhitelist[_master] == true,
            ""
        );

        clone_ = _master.cloneDeterministic(_salt);

        (bool success, ) = clone_.call(
            abi.encodeWithSelector(
                0x439fab91,  
                _data
            )
        );
        require(success);

        _instances[clone_] = true;

        emit NewClone(_master, clone_, msg.sender);
    
}
```

observing view `exists`:

```solidity

        return _instances[_instance];
    
```

---

## 247. BlueprintV10
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

## 248. PledgeMint
- families: classic_reentrancy|forced_revert|in_loop_call
- closure size: 1 | sites: 1 | loops: 1

state (exposed only):
```solidity
    uint256 pledgeMintRevenue;
    mapping(uint16 => mapping(address => uint8)) pledges;
```

exposure `withdrawRevenue` (low_level_call, gas-forwarding=True), writes after call: ['pledgeMintRevenue']

```solidity
function withdrawRevenue(external
        onlyOwner

        (bool success, ) = msg.sender.call{value: pledgeMintRevenue}("");
        require(success, "");
        pledgeMintRevenue = 0;
    
}
```

in-loop call in `_refundPhase`:

```solidity

            address addy = _addresses[i];
            uint8 quantity = pledges[phaseId][addy];
            if (quantity > 0) {
                pledges[phaseId][addy] = 0;
                (bool success, ) = addy.call{
                    value: _phase.mintPrice * quantity
                }("");
                if (!success) revert Errors.UnableToSendValue();
            }

            unchecked {
                ++i;
            }
        
```

---

## 249. AlphaSharkSweep
- families: classic_reentrancy|cross_function
- closure size: 6 | sites: 6 | loops: 0

state (exposed only):
```solidity
    uint256 fee;
```

exposure `singleERC721ListingFillWithPrecheck` (low_level_call, gas-forwarding=True), writes after call: ['fee']

```solidity
function singleERC721ListingFillWithPrecheck(external payable nonReentrant

        if (
            expectedOwner != address(0) &&
            IERC721(collection).ownerOf(tokenId) != expectedOwner
        ) {
            revert UnexpectedOwnerOrBalance();
        }

        bytes4 selector = bytes4(data[:4]);

        address target;
        if (exchangeKind == ExchangeKind.SEAPORT) {
            target = seaport;
            if (
                selector != ISeaport.fulfillAdvancedOrder.selector &&
                selector != ISeaport.matchAdvancedOrders.selector
            ) {
                revert UnexpectedSelector();
            }
        } else if (exchangeKind == ExchangeKind.WYVERN_V23) {
            target = wyvernV23;
            if (selector != IWyvernV23.atomicMatch_.selector) {
                revert UnexpectedSelector();
            }
        } else if (exchangeKind == ExchangeKind.LOOKS_RARE) {
            target = looksRare;
            if (
                selector !=
                ILooksRare.matchAskWithTakerBidUsingETHAndWETH.selector
            ) {
                revert UnexpectedSelector();
            }
        } else if (exchangeKind == ExchangeKind.ZEROEX_V4) {
            target = zeroExV4;
            if (selector != IZeroExV4.buyERC721.selector) {
                revert UnexpectedSelector();
            }
        } else if (exchangeKind == ExchangeKind.X2Y2) {
            target = x2y2;
            if (selector != IX2Y2.run.selector) {
    ... [49 more lines]
}
```

exposure `singleERC721ListingFill` (low_level_call, gas-forwarding=True), writes after call: ['fee']

```solidity
function singleERC721ListingFill(external payable nonReentrant

        bytes4 selector = bytes4(data[:4]);

        address target;
        if (exchangeKind == ExchangeKind.SEAPORT) {
            target = seaport;
            if (
                selector != ISeaport.fulfillAdvancedOrder.selector &&
                selector != ISeaport.matchAdvancedOrders.selector
            ) {
                revert UnexpectedSelector();
            }
        } else if (exchangeKind == ExchangeKind.WYVERN_V23) {
            target = wyvernV23;
            if (selector != IWyvernV23.atomicMatch_.selector) {
                revert UnexpectedSelector();
            }
        } else if (exchangeKind == ExchangeKind.LOOKS_RARE) {
            target = looksRare;
            if (
                selector !=
                ILooksRare.matchAskWithTakerBidUsingETHAndWETH.selector
            ) {
                revert UnexpectedSelector();
            }
        } else if (exchangeKind == ExchangeKind.ZEROEX_V4) {
            target = zeroExV4;
            if (selector != IZeroExV4.buyERC721.selector) {
                revert UnexpectedSelector();
            }
        } else if (exchangeKind == ExchangeKind.X2Y2) {
            target = x2y2;
            if (selector != IX2Y2.run.selector) {
                revert UnexpectedSelector();
            }
        } else if (exchangeKind == ExchangeKind.FOUNDATION) {
            target = foundation;
            if (selector != IFoundation.buyV2.selector) {
                revert UnexpectedSelector();
            }
    ... [42 more lines]
}
```

---

## 250. DODOGaslessTrading
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(bytes32 => bool) _IS_FILLED_;
```

exposure `matchingRFQByPlatform` (low_level_call, gas-forwarding=True), writes after call: ['_IS_FILLED_']

```solidity
function matchingRFQByPlatform(external

        require(_IS_ADMIN_[msg.sender], "");

         
        bytes32 orderHash = _hashOrder(order);
        require(
            ECDSA.recover(orderHash, signature) == order.signer,
            ""
        );
        require(order.expiration > block.timestamp, "");
        require(!_IS_FILLED_[orderHash], "");

         
        IDODOApproveProxy(_DODO_APPROVE_PROXY_).claimTokens(
            order.fromToken,
            order.signer,
            address(this),
            order.fromAmount
        );

         
        uint256 swapResult;
        {
            uint256 originToTokenBalance = IERC20(order.toToken).balanceOf(
                address(this)
            );
            _approveMax(
                IERC20(order.fromToken),
                _DODO_APPROVE_,
                order.fromAmount
            );
            require(route != _DODO_APPROVE_PROXY_, "");
            (bool success, ) = route.call(routeData);
            require(success, "");
            uint256 toTokenBalance = IERC20(order.toToken).balanceOf(
                address(this)
            );
            swapResult = toTokenBalance - originToTokenBalance;
        }

    ... [38 more lines]
}
```

---

## 251. HarvestingCat
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 4 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(uint256 => mapping(address => uint256))) nftBalanceForBuyback;
```

exposure `onERC721Received` (low_level_call, gas-forwarding=True), writes after call: ['nftBalanceForBuyback']

```solidity
function onERC721Received(whenNotPaused public virtual override returns (bytes4)

    require(ERCBase(msg.sender).supportsInterface(_ERC721) == true, "");
    require(address(this).balance > amountToSend, "");
    (bool sent, ) = payable(from).call{ value: amountToSend }("");
    require(sent, "");
    nftBalanceForBuyback[msg.sender][tokenId][from] += 1;
    emit NftSold(from, msg.sender, tokenId);
    return this.onERC721Received.selector;
  
}
```

exposure `onERC1155Received` (low_level_call, gas-forwarding=True), writes after call: ['nftBalanceForBuyback']

```solidity
function onERC1155Received(whenNotPaused public virtual override returns (bytes4)

    require(ERCBase(msg.sender).supportsInterface(_ERC1155) == true, "");
    require(address(this).balance > amountToSend, "");
    (bool sent, ) = payable(from).call{ value: amountToSend }("");
    require(sent, "");
    nftBalanceForBuyback[msg.sender][tokenId][from] += 1;
    emit NftSold(from, msg.sender, tokenId);
    return this.onERC1155Received.selector;
  
}
```

closure `buyback` (writes exposed state):

```solidity

    if (msg.value == 0) {
      revert NoEtherSent();
    }
    require(msg.value >= buybackFee, "");
    require(msg.sender.balance > msg.value, "");
    require(nftBalanceForBuyback[tokenContract][tokenId][msg.sender] > 0, "");
    ERCBase token = ERCBase(tokenContract);
    if (token.supportsInterface(_ERC721)) {
      ERC721Partial(tokenContract).safeTransferFrom(address(this), msg.sender, tokenId);
    } else if (token.supportsInterface(_ERC1155)) {
      ERC1155Partial(tokenContract).safeTransferFrom(address(this), msg.sender, tokenId, 1, "");
    }
    nftBalanceForBuyback[tokenContract][tokenId][msg.sender] -= 1;
    emit NftBoughtback(msg.sender, tokenContract, tokenId);
  
```

closure `withdrawNFT` (writes exposed state):

```solidity

    ERCBase token = ERCBase(tokenContract);
    if (token.supportsInterface(_ERC721)) {
      ERC721Partial(tokenContract).safeTransferFrom(address(this), VAULT, tokenId);
    } else if (token.supportsInterface(_ERC1155)) {
      ERC1155Partial(tokenContract).safeTransferFrom(address(this), VAULT, tokenId, 1, "");
    }
    nftBalanceForBuyback[tokenContract][tokenId][originalOwner] -= 1;
  
```

---

## 252. BlueprintV3
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

## 253. TokenPresale
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool isInitialized;
```

exposure `finalizePresale` (low_level_call, gas-forwarding=True), writes after call: ['isInitialized']

```solidity
function finalizePresale(external onlyOwner

        if(IERC20(tokenAddress).balanceOf(address(this)) > 0){
            IERC20(tokenAddress).transfer(msg.sender, IERC20(tokenAddress).balanceOf(address(this)));
        }
        if(address(this).balance > 0){
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            require(success, "");
        }
        isInitialized = false;
    
}
```

closure `initialize` (writes exposed state):

```solidity

        require(!isInitialized, "");
         
        isInitialized = true;
    
```

---

## 254. NFTAuction
- families: cross_function
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) _pendingWithdraws;
```

exposure `_trySendAmount` (low_level_call, gas-forwarding=True), writes after call: ['_pendingWithdraws']

```solidity
function _trySendAmount(private

        if (amount == 0 || address(0) == user) {
            return;
        }

         
        (bool success, ) = payable(user).call{value: amount, gas: gasLimit}("");
        if (!success) {
             
             
            _pendingWithdraws[user] += amount;
            emit WithdrawFailed(user, amount);
        }
    
}
```

closure `withdrawFor` (writes exposed state):

```solidity

        uint256 amount = _pendingWithdraws[user];
        require(amount > 0, "");
        require(address(this).balance >= amount, "");

        _pendingWithdraws[user] = 0;

        (bool success, ) = payable(user).call{value: amount}("");
        require(success, "");

        emit WithdrawSuccess(user, amount);
    
```

---

## 255. CreatorBlueprintsOwnershipTransferred
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

## 256. MarryStrgtVault
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 totalBaseAssets;
```

exposure `harvest` (generic_hook, gas-forwarding=True), writes after call: ['totalBaseAssets']

```solidity
function harvest(public

        if (executors[msg.sender] != true)
            revert MarryStrgtVault__NotExecutor();

        uint256 baseAssetBalanceBefore = asset.balanceOf(address(this));

        strgtStaking.deposit(pid, 0);

        uint256 rewardTokenBalance = rewardToken.balanceOf(address(this));
        rewardToken.safeTransfer(swapper, rewardTokenBalance);
        ISwapper(swapper).onSwapReceived(data);

        uint256 underlyingAssetBalance = underlyingAsset.balanceOf(
            address(this)
        );

        if (underlyingAssetBalance < amountOutMin)
            revert MarryStrgtVault__InsufficientOut();

        strgtRouter.addLiquidity(
            poolId,
            underlyingAssetBalance,
            address(this)
        );

        uint256 baseAssetBalance = asset.balanceOf(address(this)) -
            baseAssetBalanceBefore;

        uint256 totalFee = baseAssetBalance.mulDivDown(fee, 1e18);

        asset.safeTransfer(feeTo, totalFee);

        strgtStaking.deposit(pid, baseAssetBalance - totalFee);

        totalBaseAssets += baseAssetBalance - totalFee;

        emit LogFeeClaimed(feeTo, totalFee);

        emit LogHarvested(baseAssetBalance);
    
}
```

observing view `totalAssets`:

```solidity

        return totalBaseAssets;
    
```

---

## 257. ExtraTerrestrial
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

## 258. LastMintWins
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool winClaimed;
```

exposure `claimPot` (low_level_call, gas-forwarding=True), writes after call: ['winClaimed']

```solidity
function claimPot(public   nonReentrant onlyOwner

    require(winClaimed == false, "");
    require( int(lastUpdated) + int(interval) - int(block.timestamp) <= 0, "");
    (bool winner, ) = payable(ownerOf(totalSupply())).call{value: address(this).balance / 100 * 50}("");
    require(winner);

    (bool dev, ) = payable(owner()).call{value: address(this).balance /100 * 50}("");
    require(dev);
    
    winClaimed = true;


}
```

---

## 259. RapStarBytes
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool isHolder;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['isHolder']

```solidity
function mint(public payable

    uint256 supply = totalSupply();
    uint256 ownerTokenCount = balanceOf(msg.sender);

    require(!paused, "");
    if(whitelistOnly){
        require(checkWhitelist(msg.sender), "");
    }
    require(_mintAmount > 0, "");
    require(_mintAmount <= maxMintAmount, "");
    require(ownerTokenCount < maxMintAmount, "");
    require(supply + _mintAmount <= maxSupply, "");

    if (msg.sender != owner()) {
      require(msg.value >= cost * _mintAmount);
    }

    getHolders();

    uint numHolders = holders[true].length;
    if(numHolders == 0){
        numHolders = 1;
        royaltyRecipient = address(this);
    } else {
        rIndex = rand(numHolders);
        royaltyRecipient = holders[true][rIndex];
    }
    
    if(royaltyRecipient != address(0) && numHolders > 1){
        (bool hs, ) = payable(royaltyRecipient).call{value: cost * 10 / 100}("");
        require(hs);
    }
    
    for (uint256 i = 1; i <= _mintAmount; i++) {
        uint256 minted = 0;
        for (uint j = 0; j < holders[true].length; j++) {
            if(holders[true][j] == msg.sender){
                isHolder = true;
                minted++;
            }
    ... [9 more lines]
}
```

---

## 260. THORChain_Router
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(address => uint)) vaultAllowance;
```

exposure `deposit` (low_level_call, gas-forwarding=True), writes after call: ['vaultAllowance']

```solidity
function deposit(public payable nonReentrant

        uint safeAmount;
        if(asset == address(0)){
            safeAmount = msg.value;
            (bool success,) = vault.call{value:safeAmount}("");
            require(success);
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
function transferOut(public payable nonReentrant

        uint safeAmount; bool success;
        if(asset == address(0)){
            safeAmount = msg.value;
            (success,) = to.call{value:msg.value}("");  
        } else {
            vaultAllowance[msg.sender][asset] -= amount;  
            (success,) = asset.call(abi.encodeWithSignature("" , to, amount));
            safeAmount = amount;
        }
        require(success);
        emit TransferOut(msg.sender, to, asset, safeAmount, memo);
    
}
```

---

## 261. DeadWillRise
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 totalWithdrawn;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['totalWithdrawn']

```solidity
function withdraw(external onlyOwner

        address recipient;
        uint256 recipientBalance;
        if(share == 1) {
            recipient = owner();
            recipientBalance = hostBalance;
            hostBalance = 0;
        } else if(share == 2) {
            recipient = groupManager[winningGroupNumber];
            recipientBalance = groupBalance;
            groupBalance = 0;
        } else if(share == 3) {
            recipient = ownerOf(lastSurvivorTokenID);
            recipientBalance = survivorBalance;
            survivorBalance = 0;
        }
        require(recipientBalance > 0);
        (bool sent, ) = payable(recipient).call{value: recipientBalance}("");
        require(sent);
        totalWithdrawn = totalWithdrawn + recipientBalance;
    
}
```

---

## 262. UsdbLending
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(bytes => bool) usedSignatures;
```

exposure `createLoan` (low_level_call, gas-forwarding=True), writes after call: ['usedSignatures']

```solidity
function createLoan(external payable nonReentrant returns (uint256)

        require(!onlyExitLoan, "");
        require(!usedSignatures[_sig], "");
        require(_payload.expiration >= block.timestamp, "");
        bytes32 _payloadHash = keccak256(abi.encode(_payload.borrower, _payload.nftAddress,
            _payload.currency, _payload.nftTokenId, _payload.duration, _payload.expiration,
            _payload.loanAmount, _payload.apr, _payload.nftTokenType));
        bytes32 messageHash = keccak256(abi.encodePacked("",
            _payloadHash));
        if (msg.sender == _payload.borrower) {
            require(recoverSigner(messageHash, _sig) == _payload.lender, "");
        } else {
            require(recoverSigner(messageHash, _sig) == _payload.borrower, "");
        }
        require(availableCurrencies[_payload.currency], "");
        require(_payload.duration != 0, "");
        uint256 currentId = id;
        loans[currentId] = Loan({
        nftAddress : _payload.nftAddress,
        nftTokenId : _payload.nftTokenId,
        startTime : block.timestamp,
        endTime : block.timestamp + (_payload.duration * durationUnit),
        currency : _payload.currency,
        loanAmount : _payload.loanAmount,
        amountDue : calculateDueAmount(_payload.loanAmount, _payload.apr, _payload.duration),
        status : Status.CREATED,
        borrower : _payload.borrower,
        lender : _payload.lender,
        nftTokenType : _payload.nftTokenType
        });

        transferNFT(_payload.borrower, address(this), _payload.nftAddress, _payload.nftTokenId,
            _payload.nftTokenType, false);
        uint256 platformFee = calculatePlatformFee(_payload.loanAmount, platformFees[_payload.currency]);
        if (_payload.currency != address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            require(IERC20(_payload.currency).transferFrom(_payload.lender, _payload.borrower,
                _payload.loanAmount), "");
            if (platformFee > 0) {
                require(IERC20(_payload.currency).transferFrom(_payload.lender, DAO, platformFee),
                    "");
    ... [21 more lines]
}
```

---

## 263. Dao
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) balances;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['balances']

```solidity
function withdraw(public

         
        require(
            balances[msg.sender] >= 0.001 ether,
            ""
        );
        uint256 bal = balances[msg.sender];

         
        (bool sent, ) = msg.sender.call{value: bal}("");
        require(sent, "");

         
        balances[msg.sender] = 0;
    
}
```

closure `deposit` (writes exposed state):

```solidity

        require(msg.value >= 0.001 ether, "");
        balances[msg.sender] += msg.value;
    
```

---

## 264. RulerCore
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
     
    if (IERC20(_col).balanceOf(address(this)) < colAmountToPay) {
      _divest(_col, colAmountToPay);
    }
    _safeTransfer(IERC20(_col), msg.sender, colAmountToPay);
    emit Repay(msg.sender, _col, _paired, _expiry, _mintRatio, _rrTokenAmt);
  
```

---

## 265. FlashLoanProvider
- families: classic_reentrancy|phase_ordering|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool locked;
```

exposure `flashLoan` (generic_hook, gas-forwarding=True), writes after call: ['locked']

```solidity
function flashLoan(external override

    require(!locked);
     
    locked = true;

    address _this = address(this);
    uint256 balanceOrigin = _this.balance;
    uint256 fee = (value * feePercent) / FULL_PERCENT;

     
    address user = msg.sender;
    payable(user).transfer(value);

     
    IFlashLoanReceiver(user).onFlashLoanReceived(aggregator, value, fee, trades);

    require(_this.balance >= (balanceOrigin + fee));
    emit OnFlashLoan(user, value, fee);

     
    locked = false;
  
}
```

observing view `getPrice`:

```solidity

    require(!locked);
    if (totalSupply == 0) {
      price = 1 ether;
    } else {
      price = (address(this).balance * 1 ether) / totalSupply;
    }
  
```

---

## 266. SquidMulticall
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

## 267. KinaInuBetting
- families: classic_reentrancy|cross_function|eoa_assumption|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) amountWonByAccount;
    mapping(address => mapping (address => uint256)) tokenWinningsByAccount;
```

exposure `cashOut` (low_level_call, gas-forwarding=True), writes after call: ['amountWonByAccount', 'tokenWinningsByAccount']

```solidity
function cashOut(external nonReentrant

        require(msg.sender == tx.origin, "");
        bool success;
        TokenInfo storage tokenInfo = tokenInformation[tokenId];
        Player storage player = tokenInfo.players[msg.sender];
        if (
            closedTokens.contains(tokenId) &&
            accountMatchesPending[msg.sender].contains(tokenId)
        ) {
            accountMatchesPending[msg.sender].remove(tokenId);

            if (player.winnerSelected == tokenInfo.winner) {
                uint256 shares;
                if (tokenInfo.winner == 1) {
                    shares = tokenInfo.shareOfPlayersBettingRug;
                } else if (tokenInfo.winner == 2) {
                    shares = tokenInfo.shareOfPlayersBettingNotRug;
                }

                uint256 amountForPayout = (player.amountBet *
                    tokenInfo.totalPayout) / shares;
                
                if (amountForPayout > 0) {
                    if(tokenInfo.betInEth){
                        amountWonByAccount[msg.sender] += amountForPayout;
                        (success, ) = address(msg.sender).call{
                            value: amountForPayout
                        }("");
                        require(success, "");
                    } else {
                        IERC20 bettingToken = IERC20(tokenInfo.tokenBetAddress);
                        bettingToken.transferFrom(address(this), msg.sender, amountForPayout);
                        tokenWinningsByAccount[msg.sender][tokenInfo.tokenBetAddress] += amountForPayout;
                        emit PaidOutTokens(tokenInfo.tokenBetAddress, msg.sender, amountForPayout);
                    }
                }
            } else if (tokenInfo.winner == 3 && player.amountBet > 0) {
                if(tokenInfo.betInEth){
                    amountWonByAccount[msg.sender] += player.amountBet;
                    (success, ) = address(msg.sender).call{value: player.amountBet}(
    ... [11 more lines]
}
```

closure `cashOutAll` (writes exposed state):

```solidity

        require(msg.sender == tx.origin, "");
        address[] memory tokenIds = accountMatchesPending[msg.sender].values();
        uint256 amountForPayout;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            TokenInfo storage tokenInfo = tokenInformation[tokenIds[i]];
            Player storage player = tokenInfo.players[msg.sender];

            if (
                closedTokens.contains(tokenIds[i]) &&
                accountMatchesPending[msg.sender].contains(tokenIds[i])
            ) {
                accountMatchesPending[msg.sender].remove(tokenIds[i]);

                uint256 shares;
                if (tokenInfo.winner == 1) {
                    shares = tokenInfo.shareOfPlayersBettingRug;
                } else if (tokenInfo.winner == 2) {
                    shares = tokenInfo.shareOfPlayersBettingNotRug;
                }

                if (player.winnerSelected == tokenInfo.winner) {
                    if(tokenInfo.betInEth){
                        amountForPayout +=
                            (player.amountBet * tokenInfo.totalPayout) /
    ... [38 more lines]
```

---

## 268. rushAI
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 4 | sites: 4 | loops: 0

state (exposed only):
```solidity
    uint256 honorariumFunds;
    uint256 liquidityEthFunds;
    uint256 liquidityTokenFunds;
```

exposure `withdrawHonorarium` (transfer, gas-forwarding=False), writes after call: ['honorariumFunds']

```solidity
function withdrawHonorarium(external onlyOwner returns (bool)

        payable(honorariumWallet).transfer(honorariumFunds);
        honorariumFunds = 0;
        return true;
    
}
```

exposure `withdrawLiquidity` (transfer, gas-forwarding=False), writes after call: ['liquidityEthFunds', 'liquidityTokenFunds']

```solidity
function withdrawLiquidity(public onlyOwner returns (bool)

        payable(liquidityWallet).transfer(liquidityEthFunds);
        IERC20(address(this)).transfer(liquidityWallet, liquidityTokenFunds);
        liquidityEthFunds = 0;
        liquidityTokenFunds = 0;
        return true;
    
}
```

---

## 269. MVPtransfer
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

## 270. Basket
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (address => mapping (address => uint256)) xlpSupply;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['xlpSupply']

```solidity
function withdraw(public onlyManager

    _withdraw(liquidCZap, vault, swper, amount);
    uint256 outAmount = address(this).balance;
    outAmount = outAmount - fee;

    (bool success1, ) = account.call{value: outAmount}("");
    require(success1, "");

    if (fee > 0) {
      (bool success2, ) = msg.sender.call{value: outAmount}("");
      require(success2, "");
    }

    xlpSupply[vault][account] = xlpSupply[vault][account] - amount;
  
}
```

closure `moveBasket2Pool` (writes exposed state):

```solidity

    require(amount <= xlpSupply[vault][msg.sender], "");
    xlpSupply[vault][msg.sender] = xlpSupply[vault][msg.sender] - amount;
    IERC20(vault).transfer(msg.sender, amount);
  
```

closure `withdrawToBridge` (writes exposed state):

```solidity

    _withdraw(liquidCZap, vault, swper, amount);
    uint256 inAmount = address(this).balance;
    
    ILiquidCryptoBridge_v1(bridge).depositForUser{value: inAmount}(fee);

    xlpSupply[vault][account] = xlpSupply[vault][account] - amount;
  
```

---

## 271. WonderWoman
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) usermint;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['usermint']

```solidity
function mint(external callerIsUser payable

        require(publicMintStatus == EPublicMintStatus.PUBLIC_MINT, "");
        require(_quantity <= 20, "");
        require(totalSupply() + _quantity <= maxSupply, "");

        uint256 _remainFreeQuantity = 0;
        if (totalSupply() + _quantity < 4000) {
            if (1 > usermint[msg.sender]) {
                _remainFreeQuantity = 1 - usermint[msg.sender];
            }
        }

        uint256 _needPayPrice = 0;
        if (_quantity > _remainFreeQuantity) {
            _needPayPrice = (_quantity - _remainFreeQuantity) * publicSalePrice;
        }

        require(msg.value >= _needPayPrice, "");
        if (msg.value > 0) {
            (bool success,) = payMent.call{value : msg.value}("");
            require(success, "");
        }
        usermint[msg.sender] += _quantity;
        _safeMint(msg.sender, _quantity);
    
}
```

---

## 272. CapsuleMachine
- families: cross_function|forced_revert
- closure size: 1 | sites: 1 | loops: 0

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
   
         
        require(isAddressWhitelisted(_assetAddress) == true, "");

         
        IERC721 _thisNFT = IERC721(_assetAddress);
        require (msg.sender == _thisNFT.ownerOf(_tokenId), "");

         
        require(isNFTinCapsule[_assetAddress][_tokenId] != true, "");

         
        _thisNFT.transferFrom(msg.sender, address(this), _tokenId);

         
        uint256 _newCapID = allCapsules.length;

        Capsule memory c;  
        c.startTime = block.timestamp;
        c.host = msg.sender;
        c.nftAddr = _assetAddress;
        c.nftId = _tokenId;
        c.partition = _partition;
        c.eachPrice = _price;
        c.endTime = block.timestamp + _duration;
    ... [10 more lines]
```

---

## 273. Minter
- families: classic_reentrancy|cross_function|eoa_assumption|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 nextTokenId;
```

exposure `proxyMint` (low_level_call, gas-forwarding=True), writes after call: ['nextTokenId']

```solidity
function proxyMint(external payable

         
        IToken tokenContract = IToken(tokenAddress);
        
         

         
        if (mintPhase == MintPhase.Paused) {
            revert("");
        }

         
        uint256 maxTokens = tokenContract.maxTokens();
        require(nextTokenId + quantity <= maxTokens, "");
        
         
        uint256 price = tokenContract.price();
        require(msg.value >= price * quantity, "");
        
         
        require(msg.sender == tx.origin, "");

         
        if (mintPhase == MintPhase.HoldersOnly) {
             
            require(checkMerkleProof(merkleProof, msg.sender, holderMerkleRoot), "");

             
            require(hasMintedHolderAllocation[msg.sender] + quantity <= maxHolderAllocation, "");
            
             
            hasMintedHolderAllocation[msg.sender] = hasMintedHolderAllocation[msg.sender] + quantity;
        }

         
        if (mintPhase == MintPhase.WhitelistOnly) {
             
            require(checkMerkleProof(merkleProof, msg.sender, whitelistMerkleRoot), "");

             
    ... [28 more lines]
}
```

closure `setNextTokenId` (writes exposed state):

```solidity

        nextTokenId = id;
    
```

---

## 274. PopCult
- families: classic_reentrancy|cross_function
- closure size: 3 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) publicMintCounts;
    mapping(address => uint256) whitelistMintCounts;
    uint256 whitelistTokenCount;
```

exposure `whitelistMint` (low_level_call, gas-forwarding=True), writes after call: ['whitelistMintCounts', 'whitelistTokenCount']

```solidity
function whitelistMint(external
    payable
    whenNotPaused
    mintCompliance(_m

    require(isWhitelistSaleOpen, "");
    require(
      whitelistTokenCount + _mintAmount <= maxWhitelistTokens,
      ""
    );

    if (_isUSDC == true) {
      usdcAddress.transferFrom(
        msg.sender,
        treasuryWallet,
        (_mintAmount * (whitelistUSDCCost * 10**6))
      );
    } else {
      require(
        msg.value >= (whitelistEtherCost * _mintAmount),
        ""
      );
      (bool os, ) = payable(treasuryWallet).call{value: address(this).balance}(
        ""
      );
    }

    _mint(msg.sender, _mintAmount);
    whitelistMintCounts[msg.sender] += _mintAmount;
    whitelistTokenCount += _mintAmount;
  
}
```

exposure `publicMint` (low_level_call, gas-forwarding=True), writes after call: ['publicMintCounts']

```solidity
function publicMint(external
    payable
    whenNotPaused
    mintCompliance(_m

    require(isPublicSaleOpen, "");

    if (_isUSDC == true) {
      usdcAddress.transferFrom(
        msg.sender,
        treasuryWallet,
        (_mintAmount * (publicUSDCCost * 10**6))
      );
    } else {
      require(
        msg.value >= (publicEtherCost * _mintAmount),
        ""
      );
      (bool os, ) = payable(treasuryWallet).call{value: address(this).balance}(
        ""
      );
    }

    _mint(msg.sender, _mintAmount);
    publicMintCounts[msg.sender] += _mintAmount;
  
}
```

closure `clearWhitelistCounter` (writes exposed state):

```solidity

    whitelistTokenCount = 0;
  
```

---

## 275. FundsRouter
- families: classic_reentrancy|cross_function
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint) balances;
```

exposure `forwardCalls` (low_level_call, gas-forwarding=True), writes after call: ['balances']

```solidity
function forwardCalls(external nonReentrant returns (bool, bytes memory)

        require(msg.sender == address(regUserFeeVeriForwarder), "");

        uint userBal = balances[user];
        uint routerStartBal = address(this).balance;
        uint ethSent = 0;

        bool success;
        bytes memory returnData;
         
        for (uint i; i < fcnData.length; i++) {
            ethSent += fcnData[i].ethForCall;
            if (fcnData[i].verifyUser) {
                 
                require(abi.decode(fcnData[i].callData[4:36], (address)) == user, "");
                (success, returnData) = routerUserVeriForwarder.forward{value: fcnData[i].ethForCall}(fcnData[i].target, fcnData[i].callData);
            } else {
                (success, returnData) = fcnData[i].target.call{value: fcnData[i].ethForCall}(fcnData[i].callData);
            }

            revertFailedCall(success, returnData);
        }

        uint routerEndBal = address(this).balance;
         
        require(routerEndBal + ethSent >= routerStartBal, "");
        uint ethReceivedDuringForwards = routerEndBal + ethSent - routerStartBal;

         
         
        require(userBal + ethReceivedDuringForwards >= ethSent + feeAmount, "");
        require(userBal + ethReceivedDuringForwards - ethSent - feeAmount == userBal + routerEndBal - routerStartBal - feeAmount, "");
        balances[user] = userBal + ethReceivedDuringForwards - ethSent - feeAmount;

        registry.transfer(feeAmount);
    
}
```

closure `depositETH` (writes exposed state):

```solidity

        uint newBal = balances[spender] + msg.value;
        balances[spender] = newBal;
        emit BalanceChanged(spender, newBal);
    
```

closure `withdrawETH` (writes exposed state):

```solidity

        uint startBal = balances[msg.sender];
        require(startBal >= amount, "");

        uint newBal = startBal - amount;
        balances[msg.sender] = newBal;
        recipient.transfer(amount);
        emit BalanceChanged(msg.sender, newBal);
    
```

---

## 276. UniswapV2Twap
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint64 => uint256) twapPris;
```

exposure `verifyUniswapV2Twap` (low_level_call, gas-forwarding=True), writes after call: ['twapPris']

```solidity
function verifyUniswapV2Twap(external

        if (block.number - startBlock.blockNumber <= 256) {
            require(IAxiomV0(axiomAddress).isRecentBlockHashValid(startBlock.blockNumber, startBlock.claimedBlockHash),
                    "");
        } else {
            require(IAxiomV0(axiomAddress).isBlockHashValid(startBlock),
                    "");
        }
        if (block.number - endBlock.blockNumber <= 256) {
            require(IAxiomV0(axiomAddress).isRecentBlockHashValid(endBlock.blockNumber, endBlock.claimedBlockHash),
                    "");
        } else {
            require(IAxiomV0(axiomAddress).isBlockHashValid(endBlock),
                    "");
        }

         
        uint256 _startBlockHash   = uint256(bytes32(proof[384    :384+32 ])) << 128 | 
                                            uint128(bytes16(proof[384+48 :384+64 ]));
        uint256 _endBlockHash     = uint256(bytes32(proof[384+64 :384+96 ])) << 128 | 
                                            uint128(bytes16(proof[384+112:384+128]));
        uint256 _startBlockNumber = uint256(bytes32(proof[384+128:384+160]));
        uint256 _endBlockNumber   = uint256(bytes32(proof[384+160:384+192]));
        uint256 _twapPri          = uint256(bytes32(proof[384+192:384+224]));

         
        if (_startBlockHash != uint256(startBlock.claimedBlockHash)) {
            revert("");
        }
        if (_endBlockHash != uint256(endBlock.claimedBlockHash)) {
            revert("");
        }
        if (_startBlockNumber != startBlock.blockNumber) {
            revert("");
        }
        if (_endBlockNumber != endBlock.blockNumber) {
            revert("");
        }        

        (bool success, ) = verifierAddress.call(proof);
    ... [6 more lines]
}
```

---

## 277. DAOToken
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 temporaryAmount;
```

exposure `createLPPoolOrLinkLPPool` (low_level_call, gas-forwarding=True), writes after call: ['temporaryAmount']

```solidity
function createLPPoolOrLinkLPPool(external payable override onlyOwner

        require(lpPool == address(0), "");
        require(_baseTokenAmount > 0, "");
        require(_quoteTokenAmount > 0, "");
        require(_baseTokenAmount <= temporaryAmount, "");
        require(_quoteTokenAddress != address(0), "");
        require(_quoteTokenAddress != address(this), "");
        require(_fee == 500 || _fee == 3000 || _fee == 10000, "");

        INonfungiblePositionManager inpm = INonfungiblePositionManager(UNISWAP_V3_POSITIONS);
        address pool = IUniswapV3Factory(inpm.factory()).getPool(address(this), _quoteTokenAddress, _fee);

        IERC20(address(this)).safeApprove(UNISWAP_V3_POSITIONS, MAX_UINT256);
        if (_quoteTokenAddress != WETH9) {
            IERC20(_quoteTokenAddress).safeApprove(UNISWAP_V3_POSITIONS, MAX_UINT256);
            IERC20(_quoteTokenAddress).safeTransferFrom(_msgSender(), address(this), _quoteTokenAmount);
        }

        uint256 amount0;
        uint256 amount1;
        if (pool == address(0)) {
            (lpPool, lpToken0, lpToken1, amount0, amount1) = inpm.createDAOTokenPoolAndMint(
                _baseTokenAmount,
                _quoteTokenAddress,
                _quoteTokenAmount,
                _fee,
                _tickLower,
                _tickUpper,
                _sqrtPriceX96,
                msg.value
            );
        } else {
            INonfungiblePositionManager.MintParams memory params = UniswapMath.buildMintParams(
                _baseTokenAmount,
                _quoteTokenAddress,
                _quoteTokenAmount,
                _fee,
                _tickLower,
                _tickUpper
            );
    ... [34 more lines]
}
```

closure `updateLPPool` (writes exposed state):

```solidity

        require(_baseTokenAmount <= temporaryAmount, "");
        require(lpPool != address(0), "");

        (uint256 amount0, uint256 amount1) = INonfungiblePositionManager(UNISWAP_V3_POSITIONS).mintToLPByTick(
            lpPool,
            _baseTokenAmount,
            _tickLower,
            _tickUpper
        );
        if (lpToken0 == address(this)) {
            temporaryAmount -= amount0;
        } else {
            temporaryAmount -= amount1;
        }
        emit UpdateLPPool(_baseTokenAmount);
    
```

closure `mint` (writes exposed state):

```solidity

        require(_mintTokenAddressList.length == _mintTokenAmountRatioList.length, "");
        require(_startTimestamp == _anchor.lastTimestamp, "");
        require(_endTimestamp <= block.timestamp, "");
        require(_endTimestamp > _anchor.lastTimestamp, "");
        uint256 mintValue = _anchor.total(_endTimestamp);

        uint256 ratioSum = 0;
        for (uint256 index; index < _mintTokenAmountRatioList.length; index++) {
            ratioSum += _mintTokenAmountRatioList[index];
        }
        for (uint256 index; index < _mintTokenAmountRatioList.length; index++) {
            _mint(_mintTokenAddressList[index], (mintValue * _mintTokenAmountRatioList[index]) / ratioSum);
        }

        uint256 thisTemporaryAmount = mintValue.divMul(100, lpRatio);
        uint256 lpLeftAmount = lpTotalAmount - lpCurrentAmount;
        thisTemporaryAmount = thisTemporaryAmount < lpLeftAmount ? thisTemporaryAmount : lpLeftAmount;
        if (thisTemporaryAmount > 0) {
            _mint(address(this), thisTemporaryAmount);
            temporaryAmount += thisTemporaryAmount;
            lpCurrentAmount += thisTemporaryAmount;

            if (lpPool != address(0)) {
                (uint256 amount0, uint256 amount1) = INonfungiblePositionManager(UNISWAP_V3_POSITIONS).mintToLPByTick(
    ... [22 more lines]
```

---

## 278. X7LiquidityHub
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 leastLiquidTokenWETHBalance;
```

exposure `processFees` (low_level_call, gas-forwarding=True), writes after call: ['leastLiquidTokenWETHBalance']

```solidity
function processFees(external

        IERC20 token = IERC20(tokenAddress);
        swapTokensForEth(tokenAddress, token.balanceOf(address(this)));
        uint256 proceeds = address(this).balance;
        uint256 pairETHBalance = IERC20(router.WETH()).balanceOf(nativeTokenPairs[tokenAddress]);
        if (pairETHBalance <= leastLiquidTokenWETHBalance) {
            leastLiquidToken = IERC20(tokenAddress);
        }

        uint256 devProceeds = proceeds * devPercent / 100;
        (bool success, ) = address(devWallet).call{value: devProceeds}("");

        uint256 x7m105liquidityProceeds = proceeds * x7m105liquidityPercent / 100;
        swapEthForTokens(x7m105, x7m105liquidityProceeds/2);
        addLiquidityETH(x7m105, IERC20(x7m105).balanceOf(address(this)), x7m105liquidityProceeds / 2);

        uint256 liquidityProceeds = address(this).balance;
        swapEthForTokens(address(leastLiquidToken), liquidityProceeds/2);
        uint256 liquidityTokens = leastLiquidToken.balanceOf(address(this));
        addLiquidityETH(address(leastLiquidToken), liquidityTokens, address(this).balance);
        leastLiquidTokenWETHBalance = IERC20(router.WETH()).balanceOf(nativeTokenPairs[address(leastLiquidToken)]);
        emit FeesProcessed(tokenAddress, address(leastLiquidToken), proceeds, liquidityProceeds, devProceeds, x7m105liquidityProceeds);
    
}
```

---

## 279. X7Pioneer
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => bool) transferUnlocked;
```

exposure `unlockTransfer` (low_level_call, gas-forwarding=True), writes after call: ['transferUnlocked']

```solidity
function unlockTransfer(external payable

        require(!transferUnlocked[tokenId]);
        require(ownerOf(tokenId) == msg.sender);
        require(msg.value == transferUnlockFee);
        (bool ok, ) = transferUnlockFeeDestination.call{value: msg.value}("");
        require(ok);
        transferUnlocked[tokenId] = true;
        emit TransferUnlocked(tokenId);
    
}
```

---

## 280. X7TreasurySplitter
- families: cross_function
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(Outlet => uint256) outletBalance;
    uint256 reservedETH;
```

exposure `_sendBalance` (low_level_call, gas-forwarding=True), writes after call: ['outletBalance', 'reservedETH']

```solidity
function _sendBalance(internal

        bool success;
        address payable recipient = payable(outletRecipient[outlet]);

        if (recipient == address(0)) {
            return;
        }

        uint256 ethToSend = outletBalance[outlet];
        outletBalance[outlet] = 0;
        reservedETH -= ethToSend;

        (success,) = recipient.call{value: ethToSend}("");
        if (!success) {
            outletBalance[outlet] += ethToSend;
            reservedETH += ethToSend;
        }
    
}
```

closure `divvyUp` (writes exposed state):

```solidity

        uint256 newETH = address(this).balance - reservedETH;

        if (newETH > 0) {
            outletBalance[Outlet.X7DEV1] += newETH * outletShare[Outlet.X7DEV1] / 100000;
            outletBalance[Outlet.X7DEV2] += newETH * outletShare[Outlet.X7DEV2] / 100000;
            outletBalance[Outlet.X7DEV3] += newETH * outletShare[Outlet.X7DEV3] / 100000;
            outletBalance[Outlet.X7DEV4] += newETH * outletShare[Outlet.X7DEV4] / 100000;
            outletBalance[Outlet.X7DEV5] += newETH * outletShare[Outlet.X7DEV5] / 100000;
            outletBalance[Outlet.X7DEV6] += newETH * outletShare[Outlet.X7DEV6] / 100000;
            outletBalance[Outlet.X7DEV7] += newETH * outletShare[Outlet.X7DEV7] / 100000;

            outletBalance[Outlet.REWARD_POOL] += newETH * outletShare[Outlet.REWARD_POOL] / 100000;
            outletBalance[Outlet.OTHER_SLOT1] += newETH * outletShare[Outlet.OTHER_SLOT1] / 100000;

            outletShare[Outlet.OTHER_SLOT2] = address(this).balance -
            outletBalance[Outlet.X7DEV1] -
            outletBalance[Outlet.X7DEV2] -
            outletBalance[Outlet.X7DEV3] -
            outletBalance[Outlet.X7DEV4] -
            outletBalance[Outlet.X7DEV5] -
            outletBalance[Outlet.X7DEV6] -
            outletBalance[Outlet.X7DEV7] -
            outletBalance[Outlet.OTHER_SLOT1] -
            outletBalance[Outlet.REWARD_POOL];
    ... [4 more lines]
```

---


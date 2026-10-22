# Labelling batch 2 (40 contracts)

## 41. KoalaDividendTracker
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (address => uint256) lastClaimTimes;
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

        return true;
    
}
```

closure `claim` (writes exposed state):

```solidity

        lastClaimTimes[account] = block.timestamp;
        _withdrawDividendOfUser(payable(account));
    
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

---

## 42. MockOwnableAdapter
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 open;
```

exposure `openSponsorWindow` (generic_hook, gas-forwarding=True), writes after call: ['open']

```solidity
function openSponsorWindow(external override requiresTrust

        open = 2;
        Opener(msg.sender).onSponsorWindowOpened(adapterParams.stake, adapterParams.stakeSize);
        open = 1;
    
}
```

observing view `getMaturityBounds`:

```solidity

        return open == 2 ? (0, type(uint64).max / 2) : (0, 0);
    
```

---

## 43. OwnableWstETHAdapter
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 open;
```

exposure `openSponsorWindow` (generic_hook, gas-forwarding=True), writes after call: ['open']

```solidity
function openSponsorWindow(external requiresTrust

        open = 2;
        Opener(msg.sender).onSponsorWindowOpened(adapterParams.stake, adapterParams.stakeSize);
        open = 1;
    
}
```

observing view `getMaturityBounds`:

```solidity

        return open == 2 ? (adapterParams.minm, adapterParams.maxm) : (0, 0);
    
```

---

## 44. OwnableERC4626Adapter
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 open;
```

exposure `openSponsorWindow` (generic_hook, gas-forwarding=True), writes after call: ['open']

```solidity
function openSponsorWindow(external requiresTrust

        open = 2;
        Opener(msg.sender).onSponsorWindowOpened(adapterParams.stake, adapterParams.stakeSize);
        open = 1;
    
}
```

observing view `getMaturityBounds`:

```solidity

        return open == 2 ? (adapterParams.minm, adapterParams.maxm) : (0, 0);
    
```

---

## 45. OwnableERC4626CropAdapter
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 open;
```

exposure `openSponsorWindow` (generic_hook, gas-forwarding=True), writes after call: ['open']

```solidity
function openSponsorWindow(external requiresTrust

        open = 2;
        Opener(msg.sender).onSponsorWindowOpened(adapterParams.stake, adapterParams.stakeSize);
        open = 1;
    
}
```

observing view `getMaturityBounds`:

```solidity

        return open == 2 ? (adapterParams.minm, adapterParams.maxm) : (0, 0);
    
```

---

## 46. NFTStoreFront
- families: classic_reentrancy|cross_function|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint8) royaltyPercents;
```

exposure `mintToken` (low_level_call, gas-forwarding=True), writes after call: ['royaltyPercents']

```solidity
function mintToken(public
    payable
    nonReentrant
    mintPriceCompliance(

    require(!paused, "");

    uint256 newItemId = _tokenIds.current();
    _mint(msg.sender, newItemId, _amount, "");
    _setTokenUri(newItemId, _tokenUri);

    _tokenIds.increment();
    setApprovalForAll(marketplaceAddress, true);

    if (mintingFeeAddress != address(0) && mintingFee > 0 && address(this).balance >= mintingFee) {
       
      (bool hs, ) = payable(mintingFeeAddress).call{value: mintingFee}("");
      require(hs);
       
    }

    if(_payees.length > 0) {
      if(_payees.length == 1) {
        _setRoyalties(newItemId, _payees[0]);
      } else {
        address splitter = address(new PaymentSplitter(_payees, _shares_));
        _setRoyalties(newItemId, splitter);
      }
    }

    royaltyPercents[newItemId] = _royaltyPercent;

    return newItemId;
  
}
```

closure `setRoyaltyPercent` (writes exposed state):

```solidity

    royaltyPercents[_tokenId] = _royaltyPercent;
  
```

observing view `royaltyInfo`:

```solidity

    return (recipients[_tokenId], (_salePrice * royaltyPercents[_tokenId] * 100) / 10000);
  
```

---

## 47. InterestStrategy
- families: classic_reentrancy|cross_function|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint128 pendingFeeEarned;
```

exposure `swapAndwithdrawFees` (low_level_call, gas-forwarding=True), writes after call: ['pendingFeeEarned']

```solidity
function swapAndwithdrawFees(external onlyExecutor returns (uint256)

        if (!swapTokenOutEnabled[tokenOut]) {
            revert InsupportedToken();
        }

        uint256 amountInBefore = IERC20(strategyToken).balanceOf(address(this));
        uint256 amountOutBefore = tokenOut.balanceOf(address(this));

        (bool success, ) = swapper.call(data);
        if (!success) {
            revert SwapFailed();
        }

        uint256 amountOut = tokenOut.balanceOf(address(this)) - amountOutBefore;
        if (amountOut < amountOutMin) {
            revert InsufficientAmountOut();
        }

        uint256 amountIn = amountInBefore - IERC20(strategyToken).balanceOf(address(this));
        pendingFeeEarned -= uint128(amountIn);

        tokenOut.safeTransfer(feeTo, amountOut);
        emit SwapAndWithdrawFee(amountIn, amountOut, tokenOut);

        return amountOut;
    
}
```

closure `withdrawFees` (writes exposed state):

```solidity

        IERC20(strategyToken).safeTransfer(feeTo, pendingFeeEarned);

        emit WithdrawFee(pendingFeeEarned);
        pendingFeeEarned = 0;

        return pendingFeeEarned;
    
```

observing view `availableAmount`:

```solidity

        uint256 balance = strategyToken.balanceOf(address(this));

        if (balance > pendingFeeEarned) {
            amount = balance - pendingFeeEarned;
        }
    
```

---

## 48. NAC
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) usermint;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['usermint']

```solidity
function mint(external  payable

        require(publicMintStatus == EPublicMintStatus.PUBLIC_MINT, "");
        require(_quantity <= 20, "");
        require(totalSupply() + _quantity <= maxSupply, "");

        uint256 _remainFreeQuantity = 0;
        if (totalSupply() + _quantity < 4000) {
            if (2 > usermint[msg.sender]) {
                _remainFreeQuantity = 2 - usermint[msg.sender];
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

## 49. MagicFolkItems
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool _initialFeesWithdrawn;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['_initialFeesWithdrawn']

```solidity
function withdraw(public onlyRole(DEFAULT_ADMIN_ROLE)

        uint256 amount;
        uint256 balance = address(this).balance;
        bool success = false;
        if (!_initialFeesWithdrawn) {
            if (balance <= _fees) {
                amount = balance;
            } else {
                amount = _fees;
            }
            (success, ) = payable(FEE_ADDRESS).call{ value: amount }("");
            require(success, "");
            _initialFeesWithdrawn = true;
        } else {
            for (uint256 i = 0; i < _payees.length; i++) {
                (success, ) = payable(_payees[i].wallet).call{
                    value: (balance * _payees[i].percentagePoints) / 1000
                }("");
                require(success);
            }
        }
    
}
```

---

## 50. Proxy
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint amount;
```

exposure `getTokenBalance` (low_level_call, gas-forwarding=True), writes after call: ['amount']

```solidity
function getTokenBalance(public returns(uint)

        address contractAddress = getContractAddress(symbol);
        require(contractAddress != DEFAULT_ADDRESS, "");

        (bool success, bytes memory result) = contractAddress.call(
            abi.encodeWithSignature("", address(this))
        );
        require(success, "");

        uint256 amount = abi.decode(result, (uint256));

        emit TokenBalanceEvent(amount, symbol);

        return amount;
    
}
```

---

## 51. TheShibaCollection
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 maxMintAmount;
    uint256 maxSupply;
    bool paused;
```

exposure `endEarly` (low_level_call, gas-forwarding=True), writes after call: ['maxMintAmount', 'maxSupply', 'paused']

```solidity
function endEarly(public onlyOwner

      uint256 supply = totalSupply();
      uint256 giftValue;
      giftValue = address(this).balance * 30 / 100;
      
      address payable giftAddress = payable(msg.sender);
      giftAddress = payable(ownerOf(randomNum(supply, block.timestamp, supply + 1) + 1));
      (bool success, ) = payable(giftAddress).call{value: giftValue}("");
        require(success, "");
      paused = true;    
      maxSupply = totalSupply(); 
      maxMintAmount = 0;
  
}
```

closure `pause` (writes exposed state):

```solidity

    paused = _state;
  
```

---

## 52. TGT
- families: classic_reentrancy|cross_function|read_only
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) _balances;
    uint96 _curveSupply;
    uint64 _lastEmitMAt;
    uint64 _lastEmitYAt;
    uint96 _totalEmitted;
    uint256 _totalSupply;
```

exposure `emitTokens` (generic_hook, gas-forwarding=True), writes after call: ['_balances', '_curveSupply', '_lastEmitMAt', '_lastEmitYAt', '_totalEmitted', '_totalSupply']

```solidity
function emitTokens(public virtual

        require(_live != 0, "");

        uint64 timeInM = uint64((block.timestamp - _live) / MONTH_IN_S);
        if (timeInM <= _lastEmitMAt) {
            return;
        }
         
         
        uint64 timeInY = (timeInM - 1) / 12;
        if (timeInY >= _curveHalvingYears.length) {
            _lastEmitMAt = MAX_INT;
             
            uint96 toBeMintedFinal = (MAX_SUPPLY - INIT_SUPPLY) - _totalEmitted;
            _totalSupply += toBeMintedFinal;
            _balances[_reserve] += toBeMintedFinal;
            if (isContract(_reserve)) {
                IERC677Receiver(_reserve).onTokenTransfer(address(this), toBeMintedFinal, "");
            }
            emit Transfer(address(0), _reserve, toBeMintedFinal);
            return;
        }

        if (timeInY > _lastEmitYAt) {
            uint96 toBeMintedOld = MAX_SUPPLY - _curveSupply;
            uint96 lastYearlyMint = toBeMintedOld / _curveHalvingYears[_lastEmitYAt];
            _curveSupply += lastYearlyMint;
            _lastEmitYAt = timeInY;
        }

        uint96 toBeMinted = MAX_SUPPLY - _curveSupply;
        uint96 yearlyMint = toBeMinted / _curveHalvingYears[timeInY];
        uint96 additionalAmountM = yearlyMint / 12;

        _totalSupply += additionalAmountM;
        _totalEmitted += additionalAmountM;
        _balances[_reserve] += additionalAmountM;
        _lastEmitMAt = timeInM;

        if (isContract(_reserve)) {
    ... [4 more lines]
}
```

closure `burn` (writes exposed state):

```solidity

        _transfer(msg.sender, address(0), amount);
        _totalSupply -= amount;
    
```

closure `mint` (writes exposed state):

```solidity

        require(account.length == amount.length, "");
        require(_live == 0, "");

        for(uint256 i=0;i<account.length;i++) {
            require(account[i] != address(0), "");
            require(account[i] != address(this), "");

            _totalSupply += amount[i];
            _balances[account[i]] += amount[i];
            emit Transfer(address(0), account[i], amount[i]);
        }
        require(_totalSupply <= INIT_SUPPLY, "");
    
```

observing view `totalSupply`:

```solidity

        return _totalSupply;
    
```

---

## 53. LiquidityBridgeERC
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 feeAccrued;
```

exposure `depositEth` (low_level_call, gas-forwarding=True), writes after call: ['feeAccrued']

```solidity
function depositEth(external payable nonReentrant

    require(msg.value > feeAmount, "");

    uint256 depositAmount;

    unchecked {
      depositAmount = msg.value - feeAmount;
    }

     
    (bool success, ) = payable(acceptedTokens[weth]).call{value: depositAmount}("");
    require(success, "");

    _deposit(weth, depositAmount, cardanoAddress);

    unchecked {
      feeAccrued += feeAmount;
    }
  
}
```

closure `depositERC` (writes exposed state):

```solidity

    require(msg.value == feeAmount, "");

    IERC20 tokenERC = IERC20(token);
     
    uint256 amount = tokenERC.allowance(msg.sender, address(this));
    tokenERC.safeTransferFrom(msg.sender, acceptedTokens[token], amount);

    _deposit(token, amount, cardanoAddress);

    unchecked {
      feeAccrued += feeAmount;
    }
  
```

closure `withdrawFee` (writes exposed state):

```solidity

    if (feeAccrued > 0) {
      uint256 amount = feeAccrued;
      feeAccrued = 0;
      (bool success, ) = payable(feeAddr).call{value: amount}("");
      require(success, "");
      emit FeeWithdrawn(msg.sender, amount);
    }
  
```

---

## 54. WhoGonWinBet
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(string => mapping(address => bool)) addressClaimedMap;
```

exposure `earnEth` (low_level_call, gas-forwarding=True), writes after call: ['addressClaimedMap']

```solidity
function earnEth(external nonReentrant

        require(betKeysMap[_betKey], "");

        address msgSender = _msgSender();
        BetPool storage betPool = betPools[betKeyIndexMap[_betKey]];
        require(!addressClaimedMap[_betKey][msgSender], "");

        EthToEarn memory ethToEarn = _calculateEthToEarn(msgSender, betPool);
        require(ethToEarn.valueForSender > 0, "");

        (bool _os1,) = payable(msgSender).call{value : ethToEarn.valueForSender}("");
        require(_os1);

        if (ethToEarn.valueForInvitor > 0 && invitorAddressesMap[_betKey][msgSender].length > 0) {
            address invitor = invitorAddressesMap[_betKey][msgSender][0];
            (bool _os2,) = payable(invitor).call{value : ethToEarn.valueForInvitor}("");
            require(_os2);
        }
        addressClaimedMap[_betKey][msgSender] = true;
    
}
```

observing view `getBetPoolList`:

```solidity

        FeBetPool[] memory list = new FeBetPool[](betPools.length);

        for (uint i = 0; i < betPools.length; i++) {
            BetPool storage betPool = betPools[i];
            string memory _betKey = betPool.base.key;

            FeBetOption[] memory options = new FeBetOption[](betPool.base.options.length);
            for (uint j = 0; j < betPool.base.options.length; j++) {
                uint8 option = betPool.base.options[j];
                options[j] = FeBetOption(option, optionAddressBetValueMap[_betKey][option][msgSender], optionBetValueMap[_betKey][option], optionBetAddresses[_betKey][option].length);
            }

            bool claimable = betPool.claimable;
            uint claimableValue = 0;
    ... [8 more lines]
```

---

## 55. OxOPool
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) ringsNumber;
```

exposure `deposit` (generic_hook, gas-forwarding=True), writes after call: ['ringsNumber']

```solidity
function deposit(public

        
         
        uint256 amountTokenRecieved = amountCheck(_amount);
        OxOFactory factoryContract = OxOFactory(factory);

        if(ERC20(factoryContract.token()).balanceOf(msg.sender) < factoryContract.getTokenFeeDiscountLimit()) {
            uint256 fee = getFeeForAmount(_amount);
            ERC20(token).transferFrom(msg.sender, address(this), _amount+fee);

             
            ERC20(token).transfer(OxOFactory(factory).treasurerAddress(), fee);   
        }else{
            uint256 fee = getDiscountFeeForAmount(_amount);
            ERC20(token).transferFrom(msg.sender, address(this), _amount+fee);

            if(fee > 0) {
                 
                ERC20(token).transfer(OxOFactory(factory).treasurerAddress(), fee);  
            }
        }

        if (!AltBn128.onCurve(uint256(_publicKey[0]), uint256(_publicKey[1]))) {
            revert("");
        }

         
        uint256 ringIndex = ringsNumber[amountTokenRecieved];
        Ring storage ring = rings[amountTokenRecieved][ringIndex];

        (uint wParticipants,
        uint participants, uint blockNum) = getRingPackedData(ring.packedRingData);

         
        for (uint256 i = 0; i < participants;) {
            if (ring.publicKeys[i][0] == _publicKey[0] &&
                ring.publicKeys[i][1] == _publicKey[1]) {
                revert("");
            }

    ... [29 more lines]
}
```

observing view `getCurrentRingIndex`:

```solidity

        amountCheck(amountToken);
        return ringsNumber[amountToken];
    
```

---

## 56. EMAC
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) usermint;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['usermint']

```solidity
function mint(external  payable

        require(publicMintStatus == EPublicMintStatus.PUBLIC_MINT, "");
        require(_quantity <= 10, "");
        require(totalSupply() + _quantity <= maxSupply, "");

        uint256 _remainFreeQuantity = 0;
        if (totalSupply() + _quantity < 2555) {
            if (2 > usermint[msg.sender]) {
                _remainFreeQuantity = 2 - usermint[msg.sender];
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

## 57. WorldBetInuBetting
- families: classic_reentrancy|cross_function|eoa_assumption|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) amountWonByAccount;
```

exposure `cashOut` (low_level_call, gas-forwarding=True), writes after call: ['amountWonByAccount']

```solidity
function cashOut(external nonReentrant

        require(msg.sender == tx.origin, "");
        bool success;
        MatchInfo storage matchInfo = matchInformation[matchId];
        Player storage player = matchInfo.players[msg.sender];
        if (
            closedMatches.contains(matchId) &&
            accountMatchesPending[msg.sender].contains(matchId)
        ) {
            accountMatchesPending[msg.sender].remove(matchId);

            if (player.winnerSelected == matchInfo.winner) {
                uint256 shares;
                if (matchInfo.winner == 1) {
                    shares = matchInfo.shareOfPlayersBettingA;
                } else if (matchInfo.winner == 2) {
                    shares = matchInfo.shareOfPlayersBettingB;
                } else {
                    shares = matchInfo.shareOfPlayersBettingDraw;
                }

                uint256 amountForPayout = (player.amountBet *
                    matchInfo.totalPayout) / shares;
                amountWonByAccount[msg.sender] += amountForPayout;
                if (amountForPayout > 0) {
                    (success, ) = address(msg.sender).call{
                        value: amountForPayout
                    }("");
                    require(success, "");
                }
            } else if (matchInfo.winner == 4 && player.amountBet > 0) {
                amountWonByAccount[msg.sender] += player.amountBet;
                (success, ) = address(msg.sender).call{value: player.amountBet}(
                    ""
                );
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
        for (uint256 i = 0; i < matchIds.length; i++) {
            MatchInfo storage matchInfo = matchInformation[matchIds[i]];
            Player storage player = matchInfo.players[msg.sender];

            if (
                closedMatches.contains(matchIds[i]) &&
                accountMatchesPending[msg.sender].contains(matchIds[i])
            ) {
                accountMatchesPending[msg.sender].remove(matchIds[i]);

                uint256 shares;
                if (matchInfo.winner == 1) {
                    shares = matchInfo.shareOfPlayersBettingA;
                } else if (matchInfo.winner == 2) {
                    shares = matchInfo.shareOfPlayersBettingB;
                } else {
                    shares = matchInfo.shareOfPlayersBettingDraw;
                }

                if (player.winnerSelected == matchInfo.winner) {
                    amountForPayout +=
    ... [16 more lines]
```

---

## 58. MistfitsNFTV2
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 whitelistMinted;
```

exposure `whitelistMint` (low_level_call, gas-forwarding=True), writes after call: ['whitelistMinted']

```solidity
function whitelistMint(external
        payable
        whenNotPaused
        nonRe

        bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
        require(
            MerkleProofUpgradeable.verify(_merkleProof, merkleRoot, leaf),
            ""
        );
        whitelistClaimed[_msgSender()] = true;
        _safeMint(_msgSender(), _mintAmount);
        if (walletAddress != address(0)) {
            (bool success, ) = walletAddress.call{value: address(this).balance}(
                ""
            );
            require(success, "");
        }
        whitelistMinted += _mintAmount;
    
}
```

observing view `freeLeft`:

```solidity

        if (freeSupply + whitelistMinted > totalSupply()) {
            return freeSupply + whitelistMinted - totalSupply();
        }
        return 0;
    
```

---

## 59. YoSifuStargateVault
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 lastHarvestBlock;
    uint256 totalBaseAssets;
    uint256 totalLockedProfit;
```

exposure `harvest` (generic_hook, gas-forwarding=True), writes after call: ['lastHarvestBlock', 'totalBaseAssets', 'totalLockedProfit']

```solidity
function harvest(public

        if (executors[msg.sender] != true)
            revert YoSifuStargateVault__NotExecutor();

        if (lastHarvestBlock == block.number)
            revert YoSifuStargateVault__HarvestAtSameBlock();

        uint256 baseAssetBalanceBefore = asset.balanceOf(address(this));

        stargateStaking.deposit(pid, 0);

        uint256 rewardTokenBalance = rewardToken.balanceOf(address(this));
        rewardToken.safeTransfer(swapper, rewardTokenBalance);
        ISwapper(swapper).onSwapReceived(data);

        uint256 underlyingAssetBalance = underlyingAsset.balanceOf(
            address(this)
        );

        if (underlyingAssetBalance < amountOutMin)
            revert YoSifuStargateVault__InsufficientOut();

        stargateRouter.addLiquidity(
            poolId,
            underlyingAssetBalance,
            address(this)
        );

        uint256 baseAssetBalance = asset.balanceOf(address(this)) -
            baseAssetBalanceBefore;

        uint256 totalFee = baseAssetBalance.mulDivDown(fee, 1e18);

        asset.safeTransfer(feeTo, totalFee);

        stargateStaking.deposit(pid, baseAssetBalance - totalFee);

        totalLockedProfit = baseAssetBalance - totalFee;
        totalBaseAssets += baseAssetBalance - totalFee;

    ... [6 more lines]
}
```

observing view `totalAssets`:

```solidity

        return totalBaseAssets - lockedProfit();
    
```

---

## 60. PopCult
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

## 61. NFTAuctionV3
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

        (bool successfulWithdraw, ) = recipient.call{ value: amount, gas: 20000 }("");
        require(successfulWithdraw, "");
    
```

---

## 62. Coin
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

## 63. BULLRUNNERSCLUB
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint team_balance;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['team_balance']

```solidity
function withdraw(public onlyOwner

        uint total_balance = get_balance();
		require(total_balance>0, "");

        (bool twv, ) = payable(team_wallet).call{value: team_balance}("");
        require(twv);

        uint owner_wallet_value = total_balance - team_balance;
        (bool owv, ) = payable(owner_wallet).call{value: owner_wallet_value}("");
        require(owv);

        team_balance = 0;
    
}
```

closure `mint` (writes exposed state):

```solidity

        require(mintStatus, "");
        require(numberOfTokens > 0, "");
        require(circulatingSupply() + numberOfTokens <= MAX_SUPPLY, "");
        require(numberOfTokens <= MAX_MINT,"");
        require(mintPrice * numberOfTokens <= msg.value, "");

        if (limitMaxPublicmint == true) {
            require(addressesMintedBalance[msg.sender] + numberOfTokens <= MAX_MINT, "");
        }

        for (uint256 i = 0; i < numberOfTokens; i++) {
            supply.increment();
            _safeMint(msg.sender, supply.current());
        }
        addressesMintedBalance[msg.sender] += numberOfTokens;
        team_balance += team_price * numberOfTokens;
    
```

---

## 64. RWtransfer
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

## 65. TripToTheMoonTokenContract
- families: classic_reentrancy|cross_function|forced_revert|phase_ordering
- closure size: 3 | sites: 3 | loops: 0

state (exposed only):
```solidity
    bool locked;
```

exposure `withdrawToWithdrawWallet` (low_level_call, gas-forwarding=True), writes after call: ['locked']

```solidity
function withdrawToWithdrawWallet(external onlyOwner

        require(!locked, "");
        locked = true;
        (bool success, ) = withdrawWallet.call{ value: address(this).balance }("");
        locked = false;
        require(success, "");
    
}
```

exposure `withdrawAmount` (low_level_call, gas-forwarding=True), writes after call: ['locked']

```solidity
function withdrawAmount(external onlyOwner

        require(amount <= address(this).balance);
        require(!locked, "");
        locked = true;
        (bool success, ) = msg.sender.call{ value: amount }("");
        locked = false;
        require(success, "");
    
}
```

---

## 66. LSSVMPairFactory
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) poolCount;
    mapping(address => mapping(address => bool)) requestApprovees;
```

exposure `createPairERC20` (low_level_call, gas-forwarding=True), writes after call: ['poolCount', 'requestApprovees']

```solidity
function createPairERC20(external payable returns (LSSVMPairERC20 pair)

        require(
            bondingCurveAllowed[params.bondingCurve],
            ""
        );
        if (address(WETH) != address(0)) {
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
            createSudo
    ... [10 more lines]
}
```

observing view `getSalt`:

```solidity

        return keccak256(abi.encode(msg.sender, poolCount[msg.sender]));
    
```

---

## 67. CitadelMinter
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 lastMintTimestamp;
```

exposure `mintAndDistribute` (notify_hook, gas-forwarding=True), writes after call: ['lastMintTimestamp']

```solidity
function mintAndDistribute(external
        onlyRole(POLICY_OPERATIONS_ROLE)
        ga

        uint256 cachedLastMintTimestamp = lastMintTimestamp;

        uint256 mintable = supplySchedule.getMintable(cachedLastMintTimestamp);
        citadelToken.mint(address(this), mintable);

        uint256 lockingAmount = 0;
        uint256 stakingAmount = 0;
        uint256 fundingAmount = 0;

         
         
        IVault cachedXCitadel = xCitadel;

         
        uint256 cachedLockingBps = lockingBps;
        if (cachedLockingBps != 0) {
            lockingAmount = (mintable * cachedLockingBps) / MAX_BPS;

            uint256 beforeAmount = cachedXCitadel.balanceOf(address(this));

            IVault(cachedXCitadel).deposit(lockingAmount);

            uint256 afterAmount = cachedXCitadel.balanceOf(address(this));

            uint256 xCitadelToLockers = afterAmount - beforeAmount;

            xCitadelLocker.notifyRewardAmount(
                address(cachedXCitadel),
                xCitadelToLockers
            );
            emit CitadelDistributionToLocking(
                cachedLastMintTimestamp,
                block.timestamp,
                lockingAmount,
                xCitadelToLockers
            );
        }

        uint256 cachedStakingBps = stakingBps;
    ... [28 more lines]
}
```

closure `initializeLastMintTimestamp` (writes exposed state):

```solidity

        require(
            lastMintTimestamp == 0,
            ""
        );
        uint256 globalStartTimestamp = ISupplySchedule(supplySchedule)
            .globalStartTimestamp();

        require(
            globalStartTimestamp != 0,
            ""
        );
        lastMintTimestamp = globalStartTimestamp;
    
```

---

## 68. SuperfineRewardDistributionV1
- families: classic_reentrancy|cross_function|forced_revert|in_loop_call
- closure size: 3 | sites: 2 | loops: 1

state (exposed only):
```solidity
    uint256 _totalNativeReward;
```

exposure `createSuperfineCampaign` (low_level_call, gas-forwarding=True), writes after call: ['_totalNativeReward']

```solidity
function createSuperfineCampaign(external payable nonReentrant

        SuperfineCampaign storage campaign = _campaignById[campaignId];

         
        require(
            _operators[
                _verifyCampaignSignature(
                    campaignId,
                    msg.sender,
                    numRewards,
                    campaignFee,
                    signature
                )
            ],
            ""
        );

         
        require(
            campaign.creator == address(0),
            ""
        );

         
        require(
            msg.value >= nativeReward + campaignFee,
            ""
        );
        if (msg.value > nativeReward + campaignFee) {
            (bool success, ) = payable(msg.sender).call{
                value: msg.value - nativeReward - campaignFee
            }("");
            require(
                success,
                ""
            );
        }

         
        campaign.campaignId = campaignId;
    ... [8 more lines]
}
```

exposure `updateSuperfineCampaign` (low_level_call, gas-forwarding=True), writes after call: ['_totalNativeReward']

```solidity
function updateSuperfineCampaign(external payable nonReentrant

        SuperfineCampaign storage campaign = _campaignById[campaignId];

         
        require(
            _operators[
                _verifyCampaignSignature(
                    campaignId,
                    msg.sender,
                    newNumRewards,
                    newCampaignFee,
                    signature
                )
            ],
            ""
        );

         
        require(
            campaign.creator == msg.sender,
            ""
        );

         
        require(
            !campaign.distributionStarted,
            ""
        );

         
        int256 difference = int256(newNativeReward) -
            int256(campaign.totalNativeReward);
        if (newCampaignFee > campaign.chargedFee)
            difference += int256(newCampaignFee) - int256(campaign.chargedFee);
        if (difference > 0) {
            require(
                msg.value >= uint256(difference),
                ""
            );
            if (msg.value > uint256(difference)) {
    ... [30 more lines]
}
```

in-loop call in `distributeRewards`:

```solidity

            Reward memory reward = rewards[i];
            address winner = winners[i];
            _distributedRewards[winner][campaignId].push(reward);
            if (reward.rewardType == RewardType.NATIVE) {
                require(
                    reward.rewardAddress == address(0),
                    ""
                );
                require(
                    reward.tokenId == 0,
                    ""
                );
                require(
                    reward.amount <= campaign.totalNativeReward &&
                        reward.amount <= _totalNativeReward,
                    ""
                );
                campaign.totalNativeReward -= reward.amount;
                _totalNativeReward -= reward.amount;
                (bool success, ) = payable(winner).call{value: reward.amount}(
                    ""
                );
                require(
                    success,
    ... [36 more lines]
```

closure `distributeRewards` (writes exposed state):

```solidity

        require(
            !_usedRequestIds[requestId],
            ""
        );
        _usedRequestIds[requestId] = true;

         
        SuperfineCampaign storage campaign = _campaignById[campaignId];
        require(
            campaign.creator != address(0),
            ""
        );
        require(
            rewards.length == winners.length,
            ""
        );
        require(
            rewards.length <= campaign.numRewards,
            ""
        );

         
        require(
            _operators[
    ... [87 more lines]
```

---

## 69. GreendudesNFT
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool reservedGreenDudes;
```

exposure `mintReserved` (low_level_call, gas-forwarding=True), writes after call: ['reservedGreenDudes']

```solidity
function mintReserved(public payable onlyOwner

        uint256 supply = totalSupply();
        require(RESERVED_GREEN_DUDES_QUANTITY > 0, "");

        if (reservedGreenDudes) {
            require(presalePrice* RESERVED_GREEN_DUDES_QUANTITY <= msg.value, "");
            for (uint256 i = 1; i <= RESERVED_GREEN_DUDES_QUANTITY; i++) {
                    addressPresaleMintedBalance[msg.sender]++;
                    _safeMint(msg.sender, supply + i);
                }

            (bool success, ) = payable(payments).call{value: (msg.value * 75) / 1000}(
              ""
            );
            reservedGreenDudes = false;
            require(success);
        }
    
}
```

closure `setReserved` (writes exposed state):

```solidity

        reservedGreenDudes = _state;
    
```

---

## 70. MogulMarketplace
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

        uint256 fullAmount = listing.price * amount;
        require(fullAmount == expectedPrice, "");

        uint256 fee = (fullAmount * feeBasisPoint) / 10000;
        uint256 commission =
            (fullAmount *
                commissions[listing.tokenAddress][listing.tokenId]
                    .commissionBasisPoint) / 10000;

        if (listing.isStarsListing) {
            stars.safeTransferFrom(msg.sender, address(this), fee);

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

            adminStars += fee;
        } else {
            require(msg.value == fullAmount, "");
    ... [36 more lines]
}
```

exposure `claimAuction` (low_level_call, gas-forwarding=True), writes after call: ['adminEth']

```solidity
function claimAuction(external nonReentrant()

        require(auctionIds.contains(auctionId), "");
        Auction memory auction = auctions[auctionId];
        require(block.timestamp >= auction.endTime, "");
        address winner;

        uint256 fee = (auction.highestBid.amount * feeBasisPoint) / 10000;
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
            }

            adminStars += fee;
        } else {
            (bool success, ) =
                auction.seller.call{
                    value: auction.highestBid.amount - fee - commission
                }("");

            require(success, "");

            if (
    ... [23 more lines]
}
```

---

## 71. ReservaX
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 withdrawNine;
    uint256 withdrawTen;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['withdrawNine', 'withdrawTen']

```solidity
function withdraw(external onlyOwner nonReentrant

        uint256 amount1 = (address(this).balance /100) * amounts[0];
        uint256 amount2 = (address(this).balance /100) * amounts[1];
        uint256 amount3 = (address(this).balance /100) * amounts[2];
        uint256 amount4 = (amount1/100) * 20;
        amount1 = amount1 - amount4;
        
        if(totalSupply(9) > 0 || totalSupply(10) > 0) {
            uint256 creatorOnePart = (((totalSupply(9) - withdrawNine)* mintPrice[1])/100) * 5;
            uint256 creatorTwoPart = (((totalSupply(10) - withdrawTen)* mintPrice[1])/100) * 5;

            (bool successCreators, ) = creatorOne.call{value: creatorOnePart}("");
            require(successCreators, "");

            (successCreators, ) = creatorTwo.call{value: creatorTwoPart}("");
            require(successCreators, "");

            amount1 = amount1 - (creatorOnePart + creatorTwoPart) ;

            withdrawNine = totalSupply(9);
            withdrawTen = totalSupply(10);
        }
        
        (bool success, ) = addresses[0].call{value: amount1}("");
        require(success, "");

        (success, ) = addresses[1].call{value: amount2}("");
        require(success, "");

        (success, ) = addresses[2].call{value: amount3}("");
        require(success, "");

        (success, ) = addresses[3].call{value: amount4}("");
        require(success, "");
    
}
```

---

## 72. TaxCollector
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

## 73. STICK
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

## 74. Garage
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => bool) blockedFromGarage;
```

exposure `claimWithPenalty` (low_level_call, gas-forwarding=True), writes after call: ['blockedFromGarage']

```solidity
function claimWithPenalty(external payable

        require(msg.value == penaltyEarnings[msg.sender].numUnstakedSweepers * penalty, "");
        uint256 owed = penaltyEarnings[msg.sender].earnings;
        DustInterface.mint(msg.sender, owed);
        (bool sent,) = PenaltyReceiver.call{value: msg.value}("");
        require(sent);
        blockedFromGarage[msg.sender] = false;
        emit DustClaimed(msg.sender, owed);
    
}
```

closure `unblockGarageAccess` (writes exposed state):

```solidity

        blockedFromGarage[account] = false;
    
```

closure `removeStake` (writes exposed state):

```solidity

        require(StakedAndLocked[_id], "");
        address sweepOwner = SweepersInterface.ownerOf(_id);
        if(rewardEnd > 0 && block.timestamp > rewardEnd) {
            penaltyEarnings[msg.sender].earnings += ((((rewardEnd - StakedNFTInfo[_id].lastClaimTimestamp) * dailyDust) / 86400) * multiplier[NFTMultiplier[_id]]) / 10000;
        } else {
            penaltyEarnings[msg.sender].earnings += ((((block.timestamp - StakedNFTInfo[_id].lastClaimTimestamp) * dailyDust) / 86400) * multiplier[NFTMultiplier[_id]]) / 10000;
        }
        penaltyEarnings[msg.sender].numUnstakedSweepers++;
        SweepersInterface.unstakeAndUnlock(_id);
        delete StakedNFTInfo[_id];
        StakedAndLocked[_id] = false;
        timesRemoved[sweepOwner]++;
        if(timesRemoved[sweepOwner] >= allowedTimesRemoved) {
            blockedFromGarage[sweepOwner] = true;
        }

        uint16[] memory _ids = new uint16[](1); 
        _ids[0] = _id;

        emit SweepersUnstaked(sweepOwner, _ids);
        emit SweeperRemoved(sweepOwner, _id, block.timestamp);
    
```

---

## 75. TSSNFT
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) preSaleAllowance;
```

exposure `preMint` (low_level_call, gas-forwarding=True), writes after call: ['preSaleAllowance']

```solidity
function preMint(external payable

        require(hasPreSaleStarted, "");
        require(!preSaleOver, "");
        require(_quantity > 0, "");
        require(_quantity <= MAX_PRESALE, "");
        require(preSaleAllowance[msg.sender].sub(_quantity) >= 0, "");
        require(preSaleAllowance[msg.sender] >= _quantity, "");
        require(totalSupply().add(_quantity) <= MAX_SNEAKERHEADZ, "");
        require(msg.value >= price.mul(_quantity) || msg.sender == owner(), "");
        
        (bool success, ) = payableAddress.call{value:msg.value}("");
        require(success, "");
        
        preSaleAllowance[msg.sender] = preSaleAllowance[msg.sender].sub(_quantity);
        
        for (uint i = 0; i < _quantity; i++) {
            uint mintIndex = totalSupply();
            _safeMint(msg.sender, mintIndex);
            emit SneakerHeadzMinted(mintIndex, msg.sender);
        }
    
}
```

observing view `checkEarlyBird`:

```solidity

        return preSaleAllowance[earlyBirdAddress];
    
```

---

## 76. BiteSwap
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

## 77. AsterFi
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

## 78. FeeDistributor
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

## 79. TraderSpirits
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) walletMinted;
```

exposure `mintByUser` (low_level_call, gas-forwarding=True), writes after call: ['walletMinted']

```solidity
function mintByUser(public isPause isHalt payable

        if(privateSaleIsActive == true){
            require(verify(signer, msg.sender, signature) == true, "");
        }
        else{
            require(publicSaleIsActive == true, "");
            require(publicMinted + quantity <= publicMintLimit, "");
        }
        
        require(quantity > 0 && quantity <= perTxQuantity, "");
        require(walletMinted[msg.sender] + quantity <= perWalletQuantity, "");
        require( msg.value >= mintPrice * quantity, "");

        (bool success,) = owner().call{value: msg.value}("");

        if(!success) {
            revert("");
        }
        else{
            uint256 count = quantity;
            while(count > 0) {
                if(!_exists(publicMintId)){
                    totalMinted++;
                    publicMinted++;
                    _safeMint(msg.sender, publicMintId);
                    publicMintId++;
                    count--;
                }else{
                    publicMintId++;
                }
            }
            walletMinted[msg.sender] += quantity;
        }
    
}
```

---

## 80. ForkIOU
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 totalWithdrawnEthw;
```

exposure `redeemEthw` (low_level_call, gas-forwarding=True), writes after call: ['totalWithdrawnEthw']

```solidity
function redeemEthw(public notEthMainnet nonReentrant

         
        uint256 ethwIOUBalance = ethwIOU.balanceOf(msg.sender);
        require(ethwIOUBalance > 0, "");

         
        uint256 feeAmountEthw = (ethwIOUBalance * fee) / 10_000;

         
        ethwIOU.burn(msg.sender, ethwIOUBalance);

        (bool sent, ) = msg.sender.call{value: ethwIOUBalance - feeAmountEthw}("");
        require(sent, "");
        (sent, ) = owner().call{value: feeAmountEthw}("");
        require(sent, "");

        totalWithdrawnEthw += ethwIOUBalance;
        emit EthwRedeemed(msg.sender, ethwIOUBalance, feeAmountEthw);
    
}
```

---


# Labelling batch 1 (40 contracts)

## 1. TestContractOffererNativeToken
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool fulfilled;
```

exposure `generateOrder` (low_level_call, gas-forwarding=True), writes after call: ['fulfilled']

```solidity
function generateOrder(external
        virtual
        override
        returns (S

         
        offer = new SpentItem[](1);
        consideration = new ReceivedItem[](1);

         
        (bool success, ) = _SEAPORT.call{ value: minimumReceived[0].amount }(
            ""
        );

         
        if (!success) {
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

         
        offer[0] = minimumReceived[0];

         
        consideration[0] = ReceivedItem({
            itemType: ItemType.ERC721,
            token: maximumSpent[0].token,
            identifier: maximumSpent[0].identifier,
            amount: maximumSpent[0].amount,
            recipient: payable(address(this))
        });

         
        fulfilled = true;
    
}
```

observing view `previewOrder`:

```solidity

         
        if (!ready || fulfilled || caller != _SEAPORT || context.length != 0) {
            revert OrderUnavailable();
        }

         
        offer = new SpentItem[](1 + extraAvailable);
        consideration = new ReceivedItem[](1 + extraRequired);

        for (uint256 i = 0; i < 1 + extraAvailable; ++i) {
            offer[i] = _available;
        }

        for (uint256 i = 0; i < 1 + extraRequired; ++i) {
    ... [9 more lines]
```

---

## 2. PPAgentV2
- families: classic_reentrancy|cross_function|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) compensations;
    uint24 intervalSeconds;
```

exposure `execute_44g58pv` (low_level_call, gas-forwarding=True), writes after call: ['compensations', 'intervalSeconds']

```solidity
function execute_44g58pv(external

    uint256 gasStart = gasleft();
    bytes32 jobKey;

    assembly ("") {
       
      let size := 23

       
      calldatacopy(0, 4, size)
      jobKey := keccak256(0, size)
    }

    address jobAddress;
    uint256 keeperId;
    uint256 cfg;

    assembly ("") {
       
      jobAddress := shr(96, calldataload(4))
      cfg := shr(248, calldataload(27))
      keeperId := shr(232, calldataload(28))
    }

     
    {
      Keeper memory keeper = keepers[keeperId];
      if (keeper.worker != msg.sender) {
        revert KeeperWorkerNotAuthorized();
      }
      if (keeper.cvpStake < minKeeperCvp) {
        revert InsufficientKeeperStake();
      }
    }

    uint256 binJob = getJobRaw(jobKey);

     
    {
      if (!ConfigFlags.check(binJob, CFG_ACTIVE)) {
    ... [181 more lines]
}
```

closure `withdrawCompensation` (writes exposed state):

```solidity

    uint256 available = compensations[keeperId_];
    if (amount_ == type(uint256).max) {
      amount_ = available;
    }

    _assertNonZeroAmount(amount_);
    _assertOnlyKeeperAdminOrWorker(keeperId_);

    if (amount_ > available) {
      revert WithdrawAmountExceedsAvailable(amount_, available);
    }

    unchecked {
      compensations[keeperId_] = available - amount_;
    }

    to_.transfer(amount_);

    emit WithdrawCompensation(keeperId_, to_, amount_);
  
```

observing view `getKeeper`:

```solidity

    return (
      keeperAdmins[keeperId_],
      keepers[keeperId_].worker,
      keepers[keeperId_].cvpStake,
      slashedStakeOf[keeperId_],
      compensations[keeperId_],
      pendingWithdrawalAmounts[keeperId_],
      pendingWithdrawalEndsAt[keeperId_]
    );
  
```

---

## 3. ProxyWallet
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 4 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => bool) usedNonces;
```

exposure `transfer` (transfer, gas-forwarding=False), writes after call: ['usedNonces']

```solidity
function transfer(external

        require(!usedNonces[nonce], "");

        bytes32 hash = keccak256(abi.encodePacked(ETH_TRANSFER, nonce, to, value));
        checkQuorum(hash, signatures);

        payable(to).transfer(value);
        usedNonces[nonce] = true;
    
}
```

exposure `proxy` (low_level_call, gas-forwarding=True), writes after call: ['usedNonces']

```solidity
function proxy(external returns (bytes memory)

        require(!usedNonces[nonce], "");

        bytes32 hash = keccak256(abi.encodePacked(PROXY_USAGE, nonce, addr, input));
        checkQuorum(hash, signatures);

        (bool success, bytes memory ret) = addr.call(input);
        require(success, "");

        usedNonces[nonce] = true;
        return ret;
    
}
```

closure `setAddressPermit` (writes exposed state):

```solidity

        require(!usedNonces[nonce], "");

        bytes32 hash = keccak256(abi.encodePacked(AUTHORIZED_ADDRESS_SET, nonce, addr, permit));
        checkQuorum(hash, signatures);
        authorized[addr] = permit;

        usedNonces[nonce] = true;
    
```

closure `setMinimumQuorum` (writes exposed state):

```solidity

        require(!usedNonces[nonce], "");

        bytes32 hash = keccak256(abi.encodePacked(SET_NEEDED_QUORUM, nonce, minimumQuorum));
        checkQuorum(hash, signatures);
        quorumNeeded = minimumQuorum;

        usedNonces[nonce] = true;
    
```

---

## 4. AutoSniper
- families: classic_reentrancy|cross_function
- closure size: 6 | sites: 3 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) sniperBalances;
```

exposure `fulfillOrder` (low_level_call, gas-forwarding=True), writes after call: ['sniperBalances']

```solidity
function fulfillOrder(external onlyFulfiller

        _checkGuardrails(order.tokenAddress, order.marketplace, order.autosniperTip, order.to);
        uint256 totalValue = order.value + order.autosniperTip + order.validatorTip;
        if (wethSubsidy > 0) _swapWeth(wethSubsidy, order.to);
        if (sniperBalances[order.to] < totalValue) revert InsufficientBalance();

        uint256 balanceBefore = address(this).balance;

        (bool autosniperPaid, ) = payable(fulfillerAddress).call{value: order.autosniperTip}("");
        if (!autosniperPaid) revert FailedToPayAutosniper();
        (bool orderFilled,) = order.marketplace.call{value: order.value}(order.data);
        if (!orderFilled) revert OrderFailed();
        (bool validatorPaid, ) = block.coinbase.call{value: order.validatorTip}("");
        if (!validatorPaid) revert FailedToPayValidator();

        uint256 balanceAfter = address(this).balance;
        uint256 spent = balanceBefore - balanceAfter;

        sniperBalances[order.to] -= spent;

        _claimAndTransferClaimableAssets(claims, order.to);
        _transferNftToSniper(order.tokenType, order.tokenAddress, order.tokenId, address(this), order.to);
        emit Snipe(order, claims);
    
}
```

exposure `fulfillNonCompliantMarketplaceOrder` (low_level_call, gas-forwarding=True), writes after call: ['sniperBalances']

```solidity
function fulfillNonCompliantMarketplaceOrder(external onlyFulfiller

        _checkGuardrails(order.tokenAddress, order.marketplace, order.autosniperTip, order.to);
        uint256 totalValue = order.value + order.autosniperTip + order.validatorTip;
        if (wethSubsidy > 0) _swapWeth(wethSubsidy, order.to);
        if (sniperBalances[order.to] < totalValue) revert InsufficientBalance();

        uint256 balanceBefore = address(this).balance;

        (bool autosniperPaid, ) = payable(fulfillerAddress).call{value: order.autosniperTip + order.value}("");
        if (!autosniperPaid) revert FailedToPayAutosniper();
        (bool validatorPaid, ) = block.coinbase.call{value: order.validatorTip}("");
        if (!validatorPaid) revert FailedToPayValidator();

        uint256 balanceAfter = address(this).balance;
        uint256 spent = balanceBefore - balanceAfter;

        sniperBalances[order.to] -= spent;

        _transferNftToSniper(order.tokenType, order.tokenAddress, order.tokenId, fulfillerAddress, order.to);

        emit Snipe(order, claims);
    
}
```

closure `deposit` (writes exposed state):

```solidity

        sniperBalances[sniper] += msg.value;

        emit Deposit(sniper, msg.value);
    
```

closure `withdraw` (writes exposed state):

```solidity

        if (sniperBalances[msg.sender] < amount) revert InsufficientBalance();
        sniperBalances[msg.sender] -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert FailedToWithdraw();

        emit Withdrawal(msg.sender, amount);
    
```

---

## 5. FraktalMarket
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(uint256 => bool)) auctionSellerRedeemed;
```

exposure `redeemAuctionSeller` (low_level_call, gas-forwarding=True), writes after call: ['auctionSellerRedeemed']

```solidity
function redeemAuctionSeller(external nonReentrant

    require(_seller == _msgSender());
    require(!auctionSellerRedeemed[_seller][_sellerNonce]); 
    AuctionListing storage auctionListed = auctionListings[_tokenAddress][_msgSender()][_sellerNonce];
    require(block.timestamp >= auctionListed.auctionEndTime); 
    uint256 _auctionReserve = auctionReserve[_seller][_sellerNonce];
     
     
    if(_auctionReserve>=auctionListed.reservePrice){
      uint256 totalForSeller = _auctionReserve - ((_auctionReserve * fee) / 10000);
      feesAccrued += _auctionReserve - totalForSeller;

      (bool sent,) = _msgSender().call{value: totalForSeller}("");
      auctionSellerRedeemed[_seller][_sellerNonce] = true;
      emit Volume(_msgSender(),totalForSeller);
      require(sent); 
    }

     
    else{
      auctionSellerRedeemed[_seller][_sellerNonce] = true;

      FraktalNFT(_tokenAddress).safeTransferFrom(
      address(this),
      _msgSender(),
      FraktalNFT(_tokenAddress).fraktionsIndex(),
      auctionListed.numberOfShares,
      ""
      );
    }

  
}
```

---

## 6. Vault
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 totalDistributed;
    mapping (address => uint256) totalRewardsToVoter;
```

exposure `claimFees` (low_level_call, gas-forwarding=True), writes after call: ['totalDistributed', 'totalRewardsToVoter']

```solidity
function claimFees(external override returns (uint256)

        require(msg.sender == vesch);
        if (shares[_voter].amount == 0) return 0;
        uint256 _amount = getUnclaimedFees(_voter);
        if (_amount > 0) {
            voterClaims[_voter] = block.timestamp;
            shares[_voter].counted = shares[_voter].counted + _amount;
            shares[_voter].uncounted = _getCumulativeFees(shares[_voter].amount);
            (bool _success, ) = payable(vesch).call{value: _amount}("");
            require(_success);
            totalDistributed = totalDistributed + _amount;
            totalRewardsToVoter[_voter] = totalRewardsToVoter[_voter] + _amount;
            return _amount;
        } else {
            return 0;
        }
    
}
```

observing view `getClaimedRewardsTotal`:

```solidity

        return totalDistributed;
    
```

---

## 7. CelestialSecrets
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 totalWithdraw;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['totalWithdraw']

```solidity
function withdraw(public onlyOwner

        uint256 amount = address(this).balance;
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
        totalWithdraw += amount;
    
}
```

---

## 8. ProofOfStake_Pages
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

        uint sShare = (msg.value * publisherSplit) / 100;

        (bool success, ) = gitcoin.call{value: msg.value - sShare}("");
        require(success, "");

        (bool success2, ) = sevenStories.call{value: sShare}("");
        require(success2, "");

        pledgeLimit[msg.sender] = pledgeLimit[msg.sender] + 1;

        emit Pledge(msg.sender, msg.value);
    
}
```

---

## 9. AsterFi
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

## 10. PledgeMint
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

## 11. StructuredPortfolio
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

## 12. OneMintRegistry
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(address => bool)) _addonApprovals;
    mapping(address => mapping(address => bool)) _devs;
```

exposure `setApprovalMapping` (low_level_call, gas-forwarding=True), writes after call: ['_addonApprovals']

```solidity
function setApprovalMapping(public

    require(address721.isContract() && address1155.isContract());
    bytes memory signature = abi.encodeWithSignature("");
    (bool _success1, bytes memory owner1) = address721.call(signature);
    (bool _success2, bytes memory owner2) = address1155.call(signature);

    require(_success1 && _success2);
    address one = toAddress(owner1, 12);
    address two = toAddress(owner2, 12);

    require(one == two, "");
    require(one == msg.sender, "");

    _addonApprovals[address721][address1155] = true;
  
}
```

exposure `setDevMapping` (low_level_call, gas-forwarding=True), writes after call: ['_devs']

```solidity
function setDevMapping(public

    require(address721.isContract());
    bytes memory signature = abi.encodeWithSignature("");
    (bool _success, bytes memory owner1) = address721.call(signature);
    require(toAddress(owner1, 12) == msg.sender, "");

    _devs[address721][dev] = true;
  
}
```

observing view `isMappingApproved`:

```solidity

    return _addonApprovals[address721][address1155];
  
```

---

## 13. PropsERC721AUStaking
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
    ... [3 more lines]
}
```

closure `initialize` (writes exposed state):

```solidity

    __ReentrancyGuard_init();
    __ERC2771Context_init(_trustedForwarders);
    __ERC721A_init(_name, _symbol);

    receivingWallet = _receivingWallet;
    _owner = _defaultAdmin;
    accessRegistry = _accessRegistry;
    baseURI_ = _baseURI;

    _setupRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
    _setRoleAdmin(CONTRACT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(PRODUCER_ROLE, CONTRACT_ADMIN_ROLE);
    _setRoleAdmin(MINTER_ROLE, PRODUCER_ROLE);

    nextTokenId = 1;
    SECONDS_IN_ISSUANCE_PERIOD = 86400;
    isSelfClaimActive = false;

     
     
     
  
```

closure `airdrop` (writes exposed state):

```solidity

     for (uint i = 0; i < __to.length; i++) {
       nextTokenId += __quantities[i];
       _safeMint(__to[i], __quantities[i]);
     }
  
```

---

## 14. VoxNET
- families: classic_reentrancy|phase_ordering
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool distributingFee;
```

exposure `distributeFee` (low_level_call, gas-forwarding=True), writes after call: ['distributingFee']

```solidity
function distributeFee(public

        require(distributingFee == false, "");
        distributingFee = true;

        uint tokensToSell = balanceOf[address(this)];

        if (tokensToSell > 0) {
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = weth;

            allowance[address(this)][router] = tokensToSell;

            IUniswapV2Router02(router).swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokensToSell,
                0,
                path,
                address(this),
                block.timestamp
            );
        }

        uint amount = address(this).balance;

        if (amount > 0) {
            bool success;

            if (ecosystemFee != 0) {
                uint amountEcosystem = (amount * ecosystemFee) / fee;
                (success, ) = payable(ecosystemFeeReceiver).call{ value: amountEcosystem, gas: 30000 }("");
            }

            uint amountMarketing = (amount * marketingFee) / fee;
            (success, ) = payable(marketingFeeReceiver1).call{ value: amountMarketing / 2, gas: 30000 }("");
            (success, ) = payable(marketingFeeReceiver2).call{ value: amountMarketing / 2, gas: 30000 }("");

            uint amountTreasury = (amount * treasuryFee) / fee;
            (success, ) = payable(treasuryFeeReceiver).call{ value: amountTreasury, gas: 30000 }("");
        }

    ... [2 more lines]
}
```

---

## 15. DIADataNFT
- families: classic_reentrancy|cross_function|read_only
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping (address => uint256) mintsPerWallet;
    mapping (uint256 => uint256) rankClaims;
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
			_newRank = numMinted;
		}

		for (uint256 i = 0; i < Math.max(NUM_PRIVILEGED_RANKS, numMinted); i++) {
			rankClaims[i] += getRankClaim(i, Math.max(NUM_PRIVILEGED_RANKS, numMinted));
		}

		 
		require(mintsPerWallet[_origin] < maxMintsPerWallet, "");

		 
		_mint(_origin, _newRank, 1, "");

		 
		rankMinter[_newRank] = _origin;
		numMintedNFTs = numMinted + 1;

		 
		uint256 currSourceNFTId = sourceNFTId;

		diaSourceNFTImpl.notifyDataNFTMint(currSourceNFTId);

		mintsPerWallet[_origin] += 1;
		emit MintedDataNFT(_origin, numMinted, _newRank);
		return _newRank;
	
}
```

exposure `claimMintingPoolReward` (transfer, gas-forwarding=False), writes after call: ['rankClaims']

```solidity
function claimMintingPoolReward(public

		require(!genesisPhase);
		address claimer = msg.sender;
		require(balanceOf(claimer, rank) > 0);

		uint256 reward = rankClaims[rank];

		 
		require(ERC20(paymentToken).transfer(claimer, reward));
		 
		rankClaims[rank] = 0;
		emit ClaimedMintingPoolReward(rank, claimer);
	
}
```

observing view `getRewardAmount`:

```solidity

		return rankClaims[rank];
	
```

---

## 16. BPYC
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

## 17. AbstractStorefront
- families: cross_function
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) _failedTransferCredits;
```

exposure `_payout` (low_level_call, gas-forwarding=True), writes after call: ['_failedTransferCredits']

```solidity
function _payout(internal

        if (_erc20Token != address(0)) {
            IERC20(_erc20Token).transfer(_recipient, _amount);
        } else {
             
             
            (bool success, ) = payable(_recipient).call{ value: _amount, gas: 20000 }("");
             
             
            if (!success) {
                 
                _failedTransferCredits[_recipient] += _amount;
                 
            }
        }
    
}
```

closure `withdrawAllFailedCredits` (writes exposed state):

```solidity

        uint256 amount = _failedTransferCredits[msg.sender];

        require(amount != 0, "");

        _failedTransferCredits[msg.sender] = 0;

         
        (bool successfulWithdraw, ) = recipient.call{ value: amount, gas: 20000 }("");
         
        require(successfulWithdraw, "");
    
```

---

## 18. VotersRewardsLock
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint claimTimeLock;
```

exposure `destributeRewards` (notify_hook, gas-forwarding=True), writes after call: ['claimTimeLock']

```solidity
function destributeRewards(external

    require(formula != address(0), "");
    require(block.timestamp >= claimTimeLock, "");
    uint rewards = computeRewards();
    require(rewards > 0, "");
    IERC20(token).approve(voter, rewards);
    IVoter(voter).notifyRewardAmount(rewards);
    claimTimeLock = block.timestamp + 7 days;
  
}
```

---

## 19. HelixNFTBridge
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(string => bool) _wrappedNftIDs;
```

exposure `wrap` (low_level_call, gas-forwarding=True), writes after call: ['_wrappedNftIDs']

```solidity
function wrap(external
      whenNotPaused
      payable

        address _user = msg.sender;
        require(_nftIDs.length != 0, "");
        
        require(msg.value >= gasFeeToAdmin, "");
        (bool success, ) = payable(admin).call{value: gasFeeToAdmin}("");
        require(success, "");

        uint256 length = _nftIDs.length;
        for (uint256 i = 0; i < length; i++) {
            string memory _nftID = _nftIDs[i];
            require(!_wrappedNftIDs[_nftID], "");
            _wrappedNftIDs[_nftID] = true;
        }
        string[] memory _newNftIDs = new string[](length);
        _newNftIDs = _nftIDs;
        
        uint256 _bridgeFactoryId = ++bridgeFactoryLastId;
        BridgeFactory storage _factory = bridgeFactories[_bridgeFactoryId];
        _factory.user = _user;
        _factory.bridgeStatus = BridgeStatus.Create;
        _factory.encryptExternalID = _encryptExternalID;
        _factory.nftIDs = _newNftIDs;
        _factory.tokenURI = _tokenURI;
         
        bridgeFactoryIDs[_user].push(_bridgeFactoryId);

        emit Wrap(_user, _bridgeFactoryId);
    
}
```

closure `bridgeToSolana` (writes exposed state):

```solidity

        uint256 bridgeFactoryId = helixNFT.getBridgeFactoryId(_tokenId);
        BridgeFactory storage _bridgeFactory = bridgeFactories[bridgeFactoryId];
        require(_bridgeFactory.user == msg.sender, "");
        string[] memory _nftIDs = _bridgeFactory.nftIDs;
        uint256 length = _nftIDs.length;
        for (uint256 i = 0; i < length; i++) {
            string memory _nftID = _nftIDs[i];
            require(_wrappedNftIDs[_nftID], "");
            _wrappedNftIDs[_nftID] = false;
        }
        _bridgeFactory.bridgeStatus = BridgeStatus.Burned;

        helixNFT.burn(_tokenId);
        emit BridgeToSolana(_externalRecipientAddr, _bridgeFactory.encryptExternalID);
    
```

observing view `isBridged`:

```solidity

        return _wrappedNftIDs[_externalTokenID];
    
```

---

## 20. SabreSwap
- families: classic_reentrancy|cross_function
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 balanceFees;
```

exposure `withdrawFees` (low_level_call, gas-forwarding=True), writes after call: ['balanceFees']

```solidity
function withdrawFees(external onlyOwner nonReentrant

        (bool sent, ) = receiver.call{value: balanceFees}("");
        balanceFees = 0;
        if (!sent) revert FailedToRetrieveFees();
    
}
```

closure `fulfillSellOffer` (writes exposed state):

```solidity

        uint256 takenFee = _fulfillSellOffer(sellOfferPosition, transferFee);
        balanceFees += takenFee;
    
```

closure `fulfillBuyOffer` (writes exposed state):

```solidity

        uint256 takenFee = _fulfillBuyOffer(buyOfferPosition, transferFee);
        balanceFees += takenFee;
    
```

---

## 21. PlaylinkAirdrop
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint256 totalAvailableAssets;
```

exposure `createAirdropCampaign` (low_level_call, gas-forwarding=True), writes after call: ['totalAvailableAssets']

```solidity
function createAirdropCampaign(external payable

        AirdropCampaign storage campaign = _campaignById[campaignId];

         
        require(
            campaign.creator == address(0),
            ""
        );

         
        uint256 airdropFee = estimateAirdropFee(assets.length);
        require(
            msg.value >= airdropFee,
            ""
        );
        if (msg.value > airdropFee) {
            (bool success, ) = payable(msg.sender).call{
                value: msg.value - airdropFee
            }("");
            require(success, "");
        }

         
        require(
            block.timestamp < startingTime,
            ""
        );
        for (uint256 i = 0; i < assets.length; i++) {
            Asset memory asset = assets[i];
            require(
                uint256(asset.assetType) <= 3,
                ""
            );
            if (asset.assetType == AssetType.ERC20)
                require(
                    asset.assetId == 0,
                    ""
                );
            else if (asset.assetType == AssetType.ERC721)
                require(
    ... [26 more lines]
}
```

exposure `updateCampaign` (low_level_call, gas-forwarding=True), writes after call: ['totalAvailableAssets']

```solidity
function updateCampaign(external payable

        AirdropCampaign storage campaign = _campaignById[campaignId];

         
        require(
            campaign.creator == msg.sender,
            ""
        );

         
        require(
            block.timestamp < campaign.startingTime,
            ""
        );

         
        uint256 newAirdropFee = estimateAirdropFee(assets.length);
        if (newAirdropFee > campaign.airdropFee) {
            require(
                msg.value >= newAirdropFee - campaign.airdropFee,
                ""
            );
            if (msg.value > newAirdropFee - campaign.airdropFee) {
                (bool success, ) = payable(msg.sender).call{
                    value: msg.value + campaign.airdropFee - newAirdropFee
                }("");
                require(success, "");
            }
        }

         
        require(
            block.timestamp < startingTime,
            ""
        );
        for (uint256 i = 0; i < assets.length; i++) {
            Asset memory asset = assets[i];
            require(
                uint256(asset.assetType) <= 3,
                ""
    ... [33 more lines]
}
```

---

## 22. CockyCockroaches
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => bool) _hasRatOwnerMinted;
```

exposure `ratOwnerMint` (low_level_call, gas-forwarding=True), writes after call: ['_hasRatOwnerMinted']

```solidity
function ratOwnerMint(external

    require(isMintActive, "");
    require(totalSupply() + 1 <= maxSupply, "");

    bytes memory payload = abi.encodeWithSignature("", msg.sender);

    (bool success, bytes memory data) = RANDOM_RATS_ADDR.call(payload);

    require(success);

    (uint256 owned) = abi.decode(data, (uint256));

    require(owned > 0, "");
    require(_hasRatOwnerMinted[msg.sender] == false, "");

    _safeMint(msg.sender, 1);
    _hasRatOwnerMinted[msg.sender] = true;
  
}
```

---

## 23. SendValueWithFallbackWithdraw
- families: cross_function|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) pendingWithdrawals;
```

exposure `_sendValueWithFallbackWithdraw` (low_level_call, gas-forwarding=True), writes after call: ['pendingWithdrawals']

```solidity
function _sendValueWithFallbackWithdraw(private

        if (amount == 0 || user == address(0)) {
            return;
        }
         
         
        (bool success, ) = payable(user).call{value: amount, gas: gasLimit}("");
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

## 24. Untracer
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

        

       require(checkTokenOfUser(msg.sender));

         
        
        bytes32 hashedValue = bytes32(keccak256(abi.encodePacked(password)));
        
         

        uint256 magicNumberAmountOfToken = verificationNumber[hashedValue];

         

        require(checkTokenInDestinationWalletWithMagicNumberAsIndicator(msg.sender, magicNumberAmountOfToken)); 

         

        require (!isContract(msg.sender));

         
            
        uint256 sentAmountFromUser = sentAmount[hashedValue];

         
            
        require (sentAmountFromUser > 0);
            
         

         require(!_burntHash[hashedValue]);
            
         

        require(_store[hashedValue], "");
            
         

        uint256 totalToSendToUser = calculateFeeOverTransaction(sentAmountFromUser);
    ... [18 more lines]
}
```

closure `DEPOSIT` (writes exposed state):

```solidity

        
         

        require (masterSwitchDeposit == true);
        
         

        require (verificationNumberManuallyTyped < 99 && verificationNumberManuallyTyped > 0);
       
        

       require(checkTokenOfUser(msg.sender));

        
       require(msg.value == fixedAmount01 || msg.value == fixedAmount05 || msg.value == fixedAmount1 || msg.value == fixedAmount5); 

         

        verificationNumber[hashedPasswordManuallyTyped] = verificationNumberManuallyTyped;
         

        sentAmount[hashedPasswordManuallyTyped] = msg.value;

         
    ... [17 more lines]
```

---

## 25. CreativeFriendz
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 tLength;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['tLength']

```solidity
function withdraw(external onlyOwner

        (bool sentCreator, ) = payable(0xdA905DE41ab2C756F038a2F4d5B4E9dC5E9Ecc21).call{value: address(this).balance * 5 / 100}("");
        require(sentCreator);

        uint256 amount = address(this).balance;
        uint256 tLength = team.length;
        uint _each = amount.div(tLength);
        for(uint256 i = 0; i < tLength; i+=1) {
            (bool sent,) = team[i].call{value: _each}("");
            require(sent);
        }
    
}
```

---

## 26. KWWVaultEth
- families: classic_reentrancy|cross_function|read_only
- closure size: 3 | sites: 3 | loops: 0

state (exposed only):
```solidity
    mapping(uint16 => uint256) boatsWithdrawAmount;
    mapping(uint16 => mapping(uint8 => uint256)) landsWithdrawAmount;
    uint256 teamWithdraw;
```

exposure `withdrawBoatFees` (low_level_call, gas-forwarding=True), writes after call: ['boatsWithdrawAmount']

```solidity
function withdrawBoatFees(public onlyGameManager

        uint256 availableToWithdraw = boatAvailableToWithdraw(totalSupply, boatId);
        (bool os, ) = payable(addr).call{value: availableToWithdraw}("");
        require(os);
        boatsWithdrawAmount[boatId] += availableToWithdraw;
    
}
```

exposure `withdrawLandFees` (low_level_call, gas-forwarding=True), writes after call: ['landsWithdrawAmount']

```solidity
function withdrawLandFees(public onlyGameManager

        uint256 availableToWithdraw = landAvailableToWithdraw(landId, ownerTypeId);
        (bool os, ) = payable(addr).call{value: availableToWithdraw}("");
        require(os);
        landsWithdrawAmount[landId][ownerTypeId] += availableToWithdraw;
    
}
```

observing view `boatAvailableToWithdraw`:

```solidity

        uint16 maxState = (boatId / 100) * 100 + 100;
        uint256 withdrawMaxAmount= 0;
        for(uint16 i = boatId; i < totalSupply && i < maxState ; i++){
            withdrawMaxAmount += boatsMaxWithdraw[i];
        }
        return withdrawMaxAmount - boatsWithdrawAmount[boatId];
    
```

---

## 27. SellableAllowlistSpot
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (address => mapping (address => uint256)) claimable;
    mapping (address => uint256) totalClaimable;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['claimable', 'totalClaimable']

```solidity
function mint(external payable 
        noMeanCalldata(_mintData)
        

        require(_nft != vaultOwner, "");
        require(_nft != address(this), "");
        require(reservedBuyerCount == 0 || isReserved[msg.sender], "");
         
        uint256 balanceBefore = IERC721(_nft).balanceOf(address(this));

         
        (bool success, ) = _nft.call{value: msg.value - fee}(_mintData);
        require(success, "");

         
        uint256 gained = IERC721(_nft).balanceOf(address(this)) - balanceBefore;
        require(gained > 0, "");

         
        claimable[_nft][msg.sender] += gained;
        totalClaimable[_nft] += gained;

        emit Flashminted(msg.sender, _nft, gained, fee);
    
}
```

closure `claimMintedNFT` (writes exposed state):

```solidity

        require(_nft != vaultOwner, "");

        uint256 len = _newTokenIds.length;
        
         
        claimable[_nft][msg.sender] -= len;
        totalClaimable[_nft] -= len;

        for (uint256 i = 0; i < len; ++i) {
             
            IERC721(_nft).safeTransferFrom(
                address(this),
                msg.sender,
                _newTokenIds[i]
            );
        }
        emit ClaimedMint(msg.sender, _nft, _newTokenIds);
    
```

---

## 28. NFTDrop
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
    require(_mintAmount <= maxMintAmount, "");
    require(supply.add(_mintAmount) <= maxSupply, "");


    uint256 ownerMintedCount = addressMintedBalance[msg.sender];
    require(ownerMintedCount.add(_mintAmount) <= nftPerAddressLimit, "");
    
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

## 29. Beastlike
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool emergencyWithdrawLocked;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['emergencyWithdrawLocked']

```solidity
function withdraw(external onlyOwner nonReentrant

         
        uint256 balance = address(this).balance;

        uint256 wolfAmount = (balance * 2) / 100;  
        uint256 turtleAmount = (balance * 2) / 100;  
        uint256 perfectWorldAmount = (balance * 2) / 100;  
        uint256 advisorAmount = (balance * 5) / 1000;  
        uint256 remainingAmount = balance - wolfAmount - turtleAmount - perfectWorldAmount - advisorAmount;

        (bool wolfSuccess,) = payable(WOLF_CONSERVATION_CENTER_WALLET)
            .call{ value: wolfAmount }("");

        (bool turtleSuccess,) = payable(SEE_TURTLE_FOUNDATION_WALLET)
            .call{ value: turtleAmount }("");

        (bool perfectWorldSuccess,) = payable(PERFECT_WORLD_FOUNDATION_WALLET)
            .call{ value: perfectWorldAmount }("");

        (bool advisorSuccess,) = payable(ADVISOR_WALLET)
            .call{ value: advisorAmount }("");

        (bool success,) = payable(receiver).call{ value: remainingAmount }("");

        if (!wolfSuccess || !turtleSuccess || !perfectWorldSuccess || !advisorSuccess || !success) {
             
            emergencyWithdrawLocked = false;
        }
    
}
```

closure `lockEmergencyWithdraw` (writes exposed state):

```solidity

        emergencyWithdrawLocked = true;
    
```

---

## 30. QueenAuctionHouseV2
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

## 31. LUNATICS
- families: cross_function|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 swapAndLiquifycount;
```

exposure `swapAndSendDividendsAndLiquidity` (low_level_call, gas-forwarding=True), writes after call: ['swapAndLiquifycount']

```solidity
function swapAndSendDividendsAndLiquidity(private

        uint256 totalFee = marketingFee + charityFee;
        uint256 tokensToSend = (tokens * (totalFee)) / 10000;

        uint256 tokensForLiquify = tokens - tokensToSend;

        swapTokensForEth(tokensToSend);
        uint256 ethToSend = address(this).balance;

        (bool successMarketing, ) = address(marketingAddress).call{
            value: ethToSend * marketingFee / totalFee
        }("");

        (bool successCharity, ) = address(charityAddress).call{
            value: address(this).balance
        }("");

        require(successMarketing, "");
        require(successCharity, "");
        
        emit SendDividends(tokens, ethToSend);

        swapAndLiquify(tokensForLiquify);
        swapAndLiquifycount = swapAndLiquifycount + (1);
    
}
```

closure `initialize` (writes exposed state):

```solidity

        __ERC20_init("", "");
        __Ownable_init();

        marketingAddress = _marketingAddress;
        lpAddress = _lpAddress;
        charityAddress = _charityAddress;

        _totalSupply = 1e6 * 1e18;  
        swapTokensAtAmount = 1e3 * 1e18;  
        maxWalletHoldings = 5e3 * 1e18;  

        charityFee = 400;  
        marketingFee = 300;  
        liquidityFee = 200;  

        launchedAt = 0;
        swapAndLiquifycount = 0;
        snipersCaught = 0;

        _hasLiqBeenAdded = false;

         
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            address(_uniswapAddress)
    ... [14 more lines]
```

---

## 32. FeeSplitter
- families: classic_reentrancy|phase_ordering
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool entered;
```

exposure `distribute` (low_level_call, gas-forwarding=True), writes after call: ['entered']

```solidity
function distribute(external

        require(!entered, "");
        entered = true;

        uint256 balance = address(this).balance;
        require(balance > 0, "");

        uint256 shares = totalShares;

        Recipient[] memory recipientsList = recipients;
        uint256 length = recipientsList.length;

        for (uint256 i; i < length; ++i) {
            Recipient memory recipient = recipientsList[i];
            (bool success, bytes memory result) = recipient.account.call{
                value: (balance * recipient.share) / shares
            }("");
            if (!success) {
                assembly {
                    revert(add(result, 32), mload(result))
                }
            }
        }

        entered = false;
    
}
```

---

## 33. Lock
- families: classic_reentrancy|cross_function|forced_revert|in_loop_call
- closure size: 2 | sites: 1 | loops: 1

state (exposed only):
```solidity
    mapping(address=>mapping(address=>uint)) multipleToken;
```

exposure `spottingInBatch` (low_level_call, gas-forwarding=True), writes after call: ['multipleToken']

```solidity
function spottingInBatch(external

        require(isSpotter[_msgSender()], "");
        for (uint256 i = 0; i < txArray.length; i++) {
            Transactions memory x = txArray[i];
            if(x.token == address(1)){
                (bool success,) = payable(x.vault).call{value: multipleToken[x.depositer][x.token]}("");
                require(success == true,"");
            }else{
                 IERC20(x.token).transfer( x.vault ,   multipleToken[x.depositer][x.token] );
            }
            multipleToken[x.depositer][x.token] = 0;
            emit spotted(
                x.depositer,
                x.token,
                x.check,
                multipleToken[x.depositer][x.token],
                x.vault,
                x.tokenName,
                x.symbol
            );
        }
    
}
```

in-loop call in `spottingInBatch`:

```solidity

            Transactions memory x = txArray[i];
            if(x.token == address(1)){
                (bool success,) = payable(x.vault).call{value: multipleToken[x.depositer][x.token]}("");
                require(success == true,"");
            }else{
                 IERC20(x.token).transfer( x.vault ,   multipleToken[x.depositer][x.token] );
            }
            multipleToken[x.depositer][x.token] = 0;
            emit spotted(
                x.depositer,
                x.token,
                x.check,
                multipleToken[x.depositer][x.token],
                x.vault,
                x.tokenName,
                x.symbol
            );
        
```

closure `deposit` (writes exposed state):

```solidity

         
         
        if (token != address(1)){
            string memory tokensName = IERC20(token).name();
            string memory tokensSymbol = IERC20(token).symbol();
            require(msg.value > feesBuffer,"");
            IERC20(token).transferFrom(_msgSender(), address(this), _amount);
            multipleToken[_msgSender()][token] = _amount;
            feesCollected += msg.value; 
            emit depositedToken(_msgSender(), token, _amount, tokensName, tokensSymbol);
        }
        else{
            require(_amount < msg.value + feesBuffer,"");
            require(msg.value >= feesBuffer,"");
            multipleToken[_msgSender()][address(1)]= msg.value;
            feesCollected += msg.value; 
            emit depositedEth(_msgSender(), token, msg.value);
        }
        if(feesCollected >= collectedFeesThreshold){
            (bool success,) = owner.call{value:feesCollected}("");
            require(success,"");
        }
    
```

---

## 34. TurboSafe
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(ERC4626 => uint256) getTotalFeiBoostedForVault;
    uint256 totalFeiBoosted;
```

exposure `boost` (generic_hook, gas-forwarding=True), writes after call: ['getTotalFeiBoostedForVault', 'totalFeiBoosted']

```solidity
function boost(external nonReentrant requiresAuth

         
        require(vault.asset() == fei, "");

         
         
        master.onSafeBoost(asset, vault, feiAmount);

         
        totalFeiBoosted += feiAmount;

         
        getTotalFeiBoostedForVault[vault] += feiAmount;

        emit VaultBoosted(msg.sender, vault, feiAmount);

         
        require(feiTurboCToken.borrow(feiAmount) == 0, "");

         
        fei.safeApprove(address(vault), feiAmount);

         
        vault.deposit(feiAmount, address(this));
    
}
```

closure `less` (writes exposed state):

```solidity

         
        getTotalFeiBoostedForVault[vault] -= feiAmount;

         
        totalFeiBoosted -= feiAmount;

        emit VaultLessened(msg.sender, vault, feiAmount);

         
        vault.withdraw(feiAmount, address(this), address(this));

         
        uint256 feiDebt = feiTurboCToken.borrowBalanceCurrent(address(this));

         
        master.onSafeLess(asset, vault, feiAmount);

         
         
        if (feiAmount > feiDebt) feiAmount = feiDebt;

         
        if (feiAmount != 0) require(feiTurboCToken.repayBorrow(feiAmount) == 0, "");
    
```

---

## 35. PixelLawyer
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
        if (totalSupply() + _quantity < 2500) {
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

## 36. WormForm
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

## 37. LiquidStakingManager
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) stakedKnotsOfSmartWallet;
```

exposure `mintDerivatives` (generic_hook, gas-forwarding=True), writes after call: ['stakedKnotsOfSmartWallet']

```solidity
function mintDerivatives(external nonReentrant

        uint256 numOfKnotsToProcess = _blsPublicKeyOfKnots.length;
        if (numOfKnotsToProcess == 0) revert EmptyArray();
        if (numOfKnotsToProcess != _beaconChainBalanceReports.length) revert InconsistentArrayLength();
        if (numOfKnotsToProcess != _reportSignatures.length) revert InconsistentArrayLength();

        for (uint256 i; i < numOfKnotsToProcess; ++i) {
             
            if (isBLSPublicKeyBanned(_blsPublicKeyOfKnots[i])) revert BLSPubKeyBanned();

             
            if(
                getAccountManager().blsPublicKeyToLifecycleStatus(_blsPublicKeyOfKnots[i]) != IDataStructures.LifecycleStatus.DEPOSIT_COMPLETED
            ) revert DepositNotCompleted();

             
            stakingFundsVault.updateDerivativesMinted(_blsPublicKeyOfKnots[i]);

             
            factory.giantSavETHPool().onMintDerivatives(_blsPublicKeyOfKnots[i]);
            factory.giantFeesAndMev().onMintDerivatives(_blsPublicKeyOfKnots[i]);

             
            if(numberOfKnots == 0) {
                _createLSDNStakehouse(
                    _blsPublicKeyOfKnots[i],
                    _beaconChainBalanceReports[i],
                    _reportSignatures[i]
                );
            }
            else {
                 
                _joinLSDNStakehouse(
                    _blsPublicKeyOfKnots[i],
                    _beaconChainBalanceReports[i],
                    _reportSignatures[i]
                );
            }

            address smartWallet = smartWalletOfKnot[_blsPublicKeyOfKnots[i]];
    ... [10 more lines]
}
```

---

## 38. Broker
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (uint256=>uint256) ridesShares;
```

exposure `redeemShare` (low_level_call, gas-forwarding=True), writes after call: ['ridesShares']

```solidity
function redeemShare(external

        uint256 amount = ridesShares[_rideId];
        require(amount > 0, "");

        RideInfo memory rideInfo = rideInfos[_rideId];  

        IERC20(rideInfo.share).safeTransferFrom(msg.sender, address(this), _redeemAmount);

        IOnchainVaults ocv = IOnchainVaults(onchainVaults);
        bool departed = rideDeparted[_rideId];
        if (departed) {
             
            uint256 boughtAmt = _redeemAmount * actualPrices[_rideId] / PRICE_DECIMALS;            
            ocv.withdrawFromVault(rideInfo.tokenIdOutput, _rideId, boughtAmt / rideInfo.quantumOutput);
            IERC20(rideInfo.outputToken).safeTransfer(msg.sender, boughtAmt);
        } else {
             
            ocv.withdrawFromVault(rideInfo.tokenIdInput, _rideId, _redeemAmount / rideInfo.quantumInput);
            if (rideInfo.inputToken == address(0)  ) {
                (bool success, ) = msg.sender.call{value: _redeemAmount}(""); 
                require(success, "");
            } else {
                IERC20(rideInfo.inputToken).safeTransfer(msg.sender, _redeemAmount);
            }
        }

        ridesShares[_rideId] -= _redeemAmount;
        IShareToken(rideInfo.share).burn(address(this), _redeemAmount);

        emit SharesRedeemed(_rideId, _redeemAmount);
    
}
```

closure `mintShareAndSell` (writes exposed state):

```solidity

        RideInfo memory rideInfo = rideInfos[_rideId];
        require(rideInfo.tokenIdInput != 0, "");
        require(prices[_rideId] != 0, "");
        require(slippages[_rideId] != 0, "");
        require(ridesShares[_rideId] == 0, ""); 
        if (_tokenIdFee != 0) {
            _checkValidTokenId(_tokenIdFee);
        }

        IShareToken(rideInfo.share).mint(address(this), _amount);

        IERC20(rideInfo.share).safeIncreaseAllowance(onchainVaults, _amount);
        IOnchainVaults(onchainVaults).depositERC20ToVault(rideInfo.tokenIdShare, _rideId, _amount / rideInfo.quantumShare);
        
        _submitOrder(OrderAssetInfo(rideInfo.tokenIdShare, _amount / rideInfo.quantumShare, _rideId), 
            OrderAssetInfo(rideInfo.tokenIdInput, _amount / rideInfo.quantumInput, _rideId), OrderAssetInfo(_tokenIdFee, _quantizedAmtFee, _vaultIdFee));
        
        ridesShares[_rideId] = _amount;

        emit MintAndSell(_rideId, _amount, prices[_rideId], slippages[_rideId]);
    
```

closure `burnRideShares` (writes exposed state):

```solidity

        uint256 amount = ridesShares[_rideId];
        require(amount > 0, ""); 
        
        RideInfo memory rideInfo = rideInfos[_rideId];  
        IOnchainVaults ocv = IOnchainVaults(onchainVaults);
        uint256 quantizedAmountToBurn = ocv.getQuantizedVaultBalance(address(this), rideInfo.tokenIdShare, _rideId);
        require(quantizedAmountToBurn > 0, "");

        ocv.withdrawFromVault(rideInfo.tokenIdShare, _rideId, quantizedAmountToBurn);

        uint256 burnAmt = quantizedAmountToBurn * rideInfo.quantumShare;
        ridesShares[_rideId] = amount - burnAmt;  
        IShareToken(rideInfo.share).burn(address(this), burnAmt);

        emit SharesBurned(_rideId, burnAmt);
    
```

---

## 39. AzuGoal
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 4 | sites: 3 | loops: 0

state (exposed only):
```solidity
    mapping(uint16 => bool) cashReady;
    uint256 pool;
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
                _cash += pool.mul(92).mul(40).div(10000).div(count);
                break;
            }

        count = finalHolders.length;
        for (uint256 i = 0; i < count; i++)
            if (finalHolders[i] == tokenId) {
                _cash += pool.mul(92).mul(10).div(10000).div(count);
                break;
            }

         
        (bool success, ) = msg.sender.call{value: _cash}("");
        require(success, "");

        cashReady[uint16(tokenId)] = false;
        emit cashedOut(msg.sender, tokenId, _cash);
    
}
```

exposure `bet` (low_level_call, gas-forwarding=True), writes after call: ['pool']

```solidity
function bet(external
        payable
        onlyEOA
        nonReentran

        require(isShowTimeStart(), "");
        require(_team < 32, "");
        require(_exists(tokenId), "");
        require(ownerOf(tokenId) == msg.sender, "");
        require(nfts[tokenId] & 0x20 == 0, "");
        require(msg.value >= _betPrice, "");

        nfts[tokenId] += _team | 0x20;
        gamblers.push(tokenId);

         
        if (msg.value > _betPrice) {
            (bool success, ) = msg.sender.call{value: msg.value.sub(_betPrice)}(
                ""
            );
            require(success, "");
        }

        pool += _betPrice;
    
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
        uint256 length = nfts.length;

        for (uint16 i = 0; i < length; i++) {
            uint24 value = nfts[i];

            if (((value >> 15) & 0x1f) == _team) {
                airDrops[i] += 1;
                finalHolders.push(i);
    ... [46 more lines]
```

observing view `getCash`:

```solidity

        require(publish[64].published, "");

        if (!cashReady[uint16(tokenId)]) return 0;

        uint256 count = finalWinners.length;

         
        for (uint256 i = 0; i < count; i++)
            if (finalWinners[i] == tokenId) {
                _cash += pool.mul(92).mul(40).div(10000).div(count);
                break;
            }

        count = finalHolders.length;
    ... [6 more lines]
```

---

## 40. buttfaze
- families: classic_reentrancy|cross_function
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 buttfazePayable;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['buttfazePayable']

```solidity
function withdraw(external payable onlyOwner


        uint256 currBalance = address(this).balance;

        (bool succ, ) = payable(buttfazeAddress).call{
            value: buttfazePayable
        }("");
        require(succ, "");

        buttfazePayable = 0;

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

closure `publicWhitelistMint` (writes exposed state):

```solidity

        uint256 price = mintRatePublicWhitelist;
        uint256 currMints = numUserMints[msg.sender];

        require(publicWhitelisted, "");
        
        
        require(currMints + quantity <= mintedPublicWhitelistAddressLimit, "");
        
        
        require(msg.value >= (price * quantity), "");
        require(_verifyPublicWL(proof), "");
        
        
        numUserMints[msg.sender] = (currMints + quantity);

        _safeMint(msg.sender, quantity);

        buttfazePayable += ((price * quantity) * 5) / 100;
        
        refundOverpay(price * quantity);
    
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


        buttfazePayable += ((price * quantity) * 5) / 100;
        
        refundOverpay(price * quantity);
    ... [1 more lines]
```

---


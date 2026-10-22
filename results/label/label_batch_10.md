# Labelling batch 10 (40 contracts)

## 361. MEGALODON
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 _totalReleased;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['_totalReleased']

```solidity
function withdraw(public payable onlyOwner

        uint256 withdrawalAmount = address(this).balance;
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success);
        _totalReleased += withdrawalAmount;
    
}
```

observing view `totalReleased`:

```solidity

        return _totalReleased;
    
```

---

## 362. Pool
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 PRECISION_FACTOR;
    bool _isInitialized;
    bool mintable;
```

exposure `initialize` (low_level_call, gas-forwarding=True), writes after call: ['PRECISION_FACTOR', '_isInitialized', 'mintable']

```solidity
function initialize(external override

        require(_msgSender() == _factory, "");
        require(!_isInitialized, "");

        manager = IManager(_manager);
        rewardToken = _rewardToken;
        nativeToken = _nativeToken;
        rewardPerBlock = _rewardPerBlock;
        treasury = _treasury;

        bytes4 mint = bytes4(keccak256(bytes("")));
        (bool success, ) = rewardToken.call(abi.encodeWithSelector(mint, address(this), 0));
        if (success) {
            mintable = true;
        } else {
            mintable = false;
        }

        uint256 decimalsRewardToken = uint256(IERC20Metadata(rewardToken).decimals());

        require(decimalsRewardToken < 30, "");
        PRECISION_FACTOR = uint256(10**(uint256(30) - decimalsRewardToken));

         
        _isInitialized = true;

         
        _add(
            nativeToken,
            _nativeAllocPoint,
            _nativeStartBlock,
            _nativeBonusMultiplier,
            _nativeBonusEndBlock,
            _nativeMinStakePeriod,
            0,  
            false,  
            false
        );
    
}
```

observing view `pendingReward`:

```solidity

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 stakeSupply = IERC20(pool.stakeToken).balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && stakeSupply != 0) {
            uint256 multiplier = getMultiplier(_pid, pool.lastRewardBlock, block.number);
            uint256 reward = (multiplier * rewardPerBlock * pool.allocPoint) / totalAllocPoint;
            accRewardPerShare = accRewardPerShare + ((reward * PRECISION_FACTOR) / stakeSupply);
        }
        uint256 result = ((user.amount * accRewardPerShare) / PRECISION_FACTOR) - user.rewardDebt;
        if (!mintable) {
            if (result > pool.rewardAmount) {
                result = pool.rewardAmount;
            }
    ... [3 more lines]
```

---

## 363. MintableERC1155
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (uint256 => uint256) tokenSupply;
```

exposure `mintMembership` (low_level_call, gas-forwarding=True), writes after call: ['tokenSupply']

```solidity
function mintMembership(public
        payable

        require(_exists(_id), "");
        uint256 maxSupply = maxTokenSupply[_id];
        uint256 supply = tokenSupply[_id];
        require(supply < maxSupply, "");

        uint256 price = tokenPrice[_id];
        require(price <= msg.value, "");

        address creator = creators[_id];

        (bool sent,  ) = creator.call{value: msg.value.div(1000).mul(975)}("");
        require(sent, "");

        tokenSupply[_id] = tokenSupply[_id].add(1);
        _mint(msg.sender, _id, 1, _data);
    
}
```

closure `mint` (writes exposed state):

```solidity

        _mint(_to, _id, _quantity, _data);
        tokenSupply[_id] = tokenSupply[_id].add(_quantity);
    
```

closure `create` (writes exposed state):

```solidity

        uint256 _id = _getNextTokenID();
        _incrementTokenTypeId();
        creators[_id] = msg.sender;
        maxTokenSupply[_id] = _maxTokenSupply;
        tokenPrice[_id] = _tokenPrice;

        _mint(msg.sender, _id, 1, _data);
        tokenSupply[_id] = 1;
        return _id;
    
```

observing view `totalSupply`:

```solidity

        return tokenSupply[_id];
    
```

---

## 364. SeaportSweeper
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

## 365. ClubVirtualMarketplaceERC721
- families: forced_revert|in_loop_call
- closure size: 0 | sites: 1 | loops: 1

state (exposed only):
```solidity
    uint256 buyNowPrice;
    mapping(address => uint256) failedCredits;
```

exposure `_purchaseAndTransfer` (low_level_call, gas-forwarding=True), writes after call: ['failedCredits']

```solidity
function _purchaseAndTransfer(internal

        address erc20Token = nftContractAuctions[_nftContractAddress][_tokenId]
            .ERC20Token;
        address _nftRecipient = nftContractAuctions[_nftContractAddress][
            _tokenId
        ].nftHighestBidder;
        uint totalAmount = _highestBid;
         
        uint256 platformFees = (_highestBid *
            (dataStorage.platformCommission())) / (10000);

         
        uint256 nftFee = (_highestBid * (dataStorage.nftCommission())) /
            (10000);

         
        _resetAuction(_nftContractAddress, _tokenId);
        delete auctionBids[_nftContractAddress][_tokenId][_nftRecipient];

        if (dataStorage.isActivated(_nftContractAddress, _tokenId)) {
            address royaltyOwner = dataStorage.getRoyaltyOwner(
                _nftContractAddress,
                _tokenId
            );
            uint _royaltyPercentage = dataStorage.getRoyaltyPercentage(
                _nftContractAddress,
                _tokenId
            );
             
            uint royaltyAmount = (_highestBid * (_royaltyPercentage)) / (10000);
            totalAmount -= royaltyAmount;
            if (_isERC20Auction(erc20Token)) {
                IERC20(erc20Token).transfer(royaltyOwner, royaltyAmount);
            } else {
                (bool success, ) = payable(royaltyOwner).call{
                    value: royaltyAmount
                }("");
                require(success);
            }
        } else {
    ... [63 more lines]
}
```

in-loop call in `buyFromProposal`:

```solidity

            if (sellerCommission[i].feePercent > 0) {
                uint256 ownerAmount = (buyNowPrice *
                    (sellerCommission[i].feePercent)) / (10000);
                buyNowPrice -= ownerAmount;
                (bool _success, ) = payable(sellerCommission[i].affiliateAddr)
                    .call{value: ownerAmount}("");
                require(_success, "");
            }
        
```

---

## 366. SafePaymentVault
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
        MakeDepositMsgSender = msg.sender;
        RanMakeDeposit = true;
        TotalBalance =  address(this).balance;

        UpdateBranchName();

        emit DepositMade(msg.sender, msg.value);
    
```

closure `GetTotalBalance` (writes exposed state):

```solidity

        TotalBalance =  address(this).balance;
        return TotalBalance;  
    
```

---

## 367. AssetVault
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 _totalShares;
```

exposure `defractionalize` (generic_hook, gas-forwarding=True), writes after call: ['_totalShares']

```solidity
function defractionalize(external
        override
        onlyAdmin
        nonReent

        require(_payees.length > 1, "");
        address account = _payees[1];

        require(
            _shares[account] != 0,
            ""
        );
        require(
            _shares[account] == _totalShares,
            ""
        );

        require(
            IVaultBuilder(_vaultBuilder).onDefractionalize(
                collection,
                tokenId,
                account
            ),
            ""
        );
        _removePayee(account);
        _totalShares = 0;
        IERC721Upgradeable(collection).transferFrom(
            address(this),
            account,
            tokenId
        );

        return account;
    
}
```

observing view `totalSupply`:

```solidity

        return _totalShares;
    
```

---

## 368. UsdbLending
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
        require(!cancelledSignatures[_sig], "");
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
    ... [22 more lines]
}
```

---

## 369. NftSale
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

		uint currentPrice = getCurrentPrice() * _amount;
		require(msg.value >= currentPrice, "");
		if(msg.value > currentPrice) {
			 
			(bool sent, ) = payable(msg.sender).call{value: msg.value - currentPrice}("");
        	require(sent, "");
		}
		
		tokensSold += _amount;
		nft.mintBatch(msg.sender, _amount);
		
		(bool sent, ) = receiver.call{value: address(this).balance}("");
        require(sent, "");
 
	
}
```

---

## 370. RiftV1Withdraw
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 vaultRedeemedSupply;
```

exposure `rescueETH` (low_level_call, gas-forwarding=True), writes after call: ['vaultRedeemedSupply']

```solidity
function rescueETH(external

        require(msg.sender == guardian, "");
        uint256 ethBalance = address(this).balance;

        require(ethBalance != 0, "");

         
        (bool sent, ) = guardian.call{ value: ethBalance }("");
        require(sent, "");
        vaultRedeemedSupply = 0;
    
}
```

closure `withdrawETH` (writes exposed state):

```solidity

        uint256 lpBalance = IERC20(vault).balanceOf(msg.sender);
        require(lpBalance != 0, "");

        IERC20(vault).safeTransferFrom(msg.sender, address(this), lpBalance);

        uint256 ethBalance = address(this).balance;
        uint256 vaultUnredeemedSupply = IERC20(vault).totalSupply() - vaultRedeemedSupply;

        uint256 withdrawAmt = (lpBalance * ethBalance) / vaultUnredeemedSupply;
        vaultRedeemedSupply += lpBalance;

         
        (bool sent, ) = msg.sender.call{ value: withdrawAmt }("");
        require(sent, "");
    
```

---

## 371. BigNumba
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 4 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint biggestAt;
    uint bounty;
```

exposure `claimBounty` (low_level_call, gas-forwarding=True), writes after call: ['biggestAt', 'bounty']

```solidity
function claimBounty(public nonReentrant

        require(block.timestamp > biggestAt + requiredDuration);
        fee = nextRoundFee;
        requiredDuration = nextRoundRequiredDuration;

        if (block.timestamp < biggestAt + requiredDuration * 2) {
            address ownerOfBiggest = IERC721(numbaAddress).ownerOf(biggest);
            (bool success, ) = payable(ownerOfBiggest).call{value: bounty}("");
            require(success, "");
        }

        biggestAt = block.timestamp;

        uint desired = IERC721(numbaAddress).price() * 6;
        if (desired > address(this).balance) {
            bounty = address(this).balance;
        } else {
            bounty = desired;
        }
    
}
```

closure `IAmBiggest` (writes exposed state):

```solidity

        require(fee == msg.value, "");
        require(IERC721(numbaAddress).ownerOf(_numbaId) == msg.sender);
        require(_numbaId > biggest);
        require(!awaitingWinnerClaim());
        biggestAt = block.timestamp;
        biggest = _numbaId;
        bounty += fee / 3;
    
```

closure `donateToBounty` (writes exposed state):

```solidity

        require(!awaitingWinnerClaim());
        require(amount == msg.value, "");
        if (amount > bounty / 10) {
            biggestAt = block.timestamp;
        }
        bounty += amount;
    
```

observing view `nextRoundBounty`:

```solidity

        uint desired = IERC721(numbaAddress).price() * 6;
        if (desired > address(this).balance - bounty) {
            return address(this).balance - bounty;
        } else {
            return desired;
        }
    
```

---

## 372. MoonOrMorty
- families: classic_reentrancy|phase_ordering
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool swapping;
```

exposure `manualSwap` (low_level_call, gas-forwarding=True), writes after call: ['swapping']

```solidity
function manualSwap(external onlyOwner

        swapping = true;
        uint256 contractBalance = balanceOf(address(this));
        bool success;

        if (contractBalance == 0) {
            return;
        }

        swapTokensForEth(contractBalance);
        (success, ) = address(marketingWallet).call{value: address(this).balance}("");
        swapping = false;
    
}
```

---

## 373. Untracer
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

## 374. CRO
- families: cross_function|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 _projectReserves;
```

exposure `_transfer` (low_level_call, gas-forwarding=True), writes after call: ['_projectReserves']

```solidity
function _transfer(internal

        require(from != address(0), "");
        require(to != address(0), "");
        require(amount > 0, "");

            if(!tradingOpen){
                    require(_isExcludedFromFees[from] || _isExcludedFromFees[to]);
            }

            if (hasLimits) {
            if (!_isExcludedMaxTransactionAmount[from] ) {
            require(amount <= _maxTxAmount, "");
            }

            if (!_isExcludedMaxWalletAmount[to]) {
                        require(balanceOf(to) + amount <= _maxWalletAmount, "");
            }   }

            if ((from == uniswapV2Pair || to == uniswapV2Pair) && !inSwapAndLiquify) {
                    if (from != uniswapV2Pair) {
                        if ((_projectReserves) >= addToETH) {
                        _swapTokensForEth(addToETH);
                        _projectReserves -= addToETH;
                        (bool sent,) = payable(projectWallet).call{value: address(this).balance}("");
                        require(sent);
                    }
                }
            }
            
            bool takeFee = true;
            uint256 fees = 0;
            if(_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
            } 

            if (takeFee) {
            if (from == uniswapV2Pair) {
                fees = amount * buyFees / 100;
                _projectReserves += fees;
            } else if(to == uniswapV2Pair) {
    ... [12 more lines]
}
```

closure `changeFees` (writes exposed state):

```solidity

        buyFees = 5;
        sellFees = 4;
        addToETH = 1250000 * 10**9;
        uint256 contractTokenBalance = balanceOf(address(this));
        uint256 amountToSwap = contractTokenBalance;
        _swapTokensForEth(amountToSwap);
        _projectReserves -= amountToSwap;
        return true;
    
```

---

## 375. PreSendPayments
- families: cross_function|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 netRevenue;
```

exposure `_payPreSendFee` (low_level_call, gas-forwarding=True), writes after call: ['netRevenue']

```solidity
function _payPreSendFee(private

         
        require(affiliatePercentage <= 100, "");

        uint256 feeAmount = currencyPrice * amount / 10**18 / feeDivisor;

         
        (, int256 coinPrice, , ,) = aggregator.latestRoundData();

        require(uint256(coinPrice) != 0, "");

         
         
        uint256 nativeCoinToDollar = (aggregatorCoinPriceMult / uint256(coinPrice)) - aggregatorCoinPriceSub;

        if (feeAmount < nativeCoinToDollar) {
            feeAmount = nativeCoinToDollar;
        }

        require(payment >= feeAmount, "");

        addressToApprovedAmount[user][currency] += amount;
        grossRevenue += payment;

        if (affiliate != address(0) && preSendAffiliate.affiliateToRegisteredTimestamp(affiliate) > block.timestamp - affiliateRegistrationTime) {
            if (affiliatePercentage > 0) {
                 
                uint256 affiliateAmount = payment * affiliatePercentage / 100;
                affiliateToPreSendRevenue[affiliate] += payment - affiliateAmount;
                netRevenue += payment - affiliateAmount;
                preSendAffiliate.increaseAffiliateAmount(affiliate, affiliateAmount);

                 
                 
                (bool success, ) = address(preSendAffiliate).call{value: affiliateAmount}("");
                require(success, "");
            }
            else {
                netRevenue += payment;
            }
    ... [7 more lines]
}
```

closure `initialize` (writes exposed state):

```solidity

        require(_treasuryAddress != address(0), "");
        require(_aggregatorAddress != address(0), "");

        affiliateRegistrationTime = 31536000;
        treasuryAddress = _treasuryAddress;
        aggregator = AggregatorV3Interface(_aggregatorAddress);
        sendPaymentFeesInterval = _sendPaymentFeesInterval;
        lastPaymentFeeSendTimeStamp = block.timestamp;
        feeDivisor = 500;
        netRevenue = 0;
        grossRevenue = 0;

        _setupRole(PAYMENT_ADMIN, msg.sender);
        _setupRole(FEE_ADMIN, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        emit treasuryAddressUpdated(_treasuryAddress);
        emit aggregatorReferenceUpdated(_aggregatorAddress);
        emit sendPaymentFeesIntervalUpdated(_sendPaymentFeesInterval);
    
```

---

## 376. Treasury
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) mapTokenReserves;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['mapTokenReserves']

```solidity
function withdraw(external returns (bool success)

         
        if (msg.sender != owner) {
            revert OwnerOnly(msg.sender, owner);
        }

         
        if (to == address(this)) {
            revert TransferFailed(token, address(this), to, tokenAmount);
        }

         
        if (tokenAmount == 0) {
            revert ZeroValue();
        }

         
        if (token == ETH_TOKEN_ADDRESS) {
            uint256 amountOwned = ETHOwned;
             
            if (amountOwned >= tokenAmount) {
                 
                amountOwned -= tokenAmount;
                ETHOwned = uint96(amountOwned);
                emit Withdraw(ETH_TOKEN_ADDRESS, to, tokenAmount);
                 
                (success, ) = to.call{value: tokenAmount}("");
                if (!success) {
                    revert TransferFailed(ETH_TOKEN_ADDRESS, address(this), to, tokenAmount);
                }
            } else {
                 
                revert LowerThan(tokenAmount, amountOwned);
            }
        } else {
             
            if (!mapEnabledTokens[token]) {
                revert UnauthorizedToken(token);
            }
             
    ... [19 more lines]
}
```

closure `depositTokenForOLAS` (writes exposed state):

```solidity

         
        if (depository != msg.sender) {
            revert ManagerOnly(msg.sender, depository);
        }

         
        if (!mapEnabledTokens[token]) {
            revert UnauthorizedToken(token);
        }

         
        uint256 reserves = mapTokenReserves[token] + tokenAmount;
        mapTokenReserves[token] = reserves;

         
        if (IToken(token).allowance(account, address(this)) < tokenAmount) {
            revert InsufficientAllowance(IToken(token).allowance((account), address(this)), tokenAmount);
        }

         
         
         
        bool success = IToken(token).transferFrom(account, address(this), tokenAmount);
        if (!success) {
    ... [9 more lines]
```

---

## 377. Nft
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint index;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['index']

```solidity
function mint(external payable nonReentrant

    require(_isMintOn == true, "");
    require(index + _quantity <= 999, "");
    require(msg.value >= price, ""); 
    (bool success, ) = payable(MAIN_WALLET).call{value: address(this).balance}("");
    require(success, "");
    index += _quantity;
    _mint(_to, _quantity);
  
}
```

closure `mintPartnership` (writes exposed state):

```solidity

    require(index + _quantity <= 999, "");
    require(mintPartnershipCount + _quantity <= 9, "");
    mintPartnershipCount += _quantity;
    index += _quantity;
    _mint(0xACCF528Dc85Ff62dF54074e4fB0cC059D86E13Fb, _quantity);
  
```

observing view `checkNumberOfNftMinted`:

```solidity

    return index;   
  
```

---

## 378. BlossomingWeb3bridge
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint40) communityMintCount;
    mapping(address => bool) whitelistClaimed;
```

exposure `WhitlistMint` (low_level_call, gas-forwarding=True), writes after call: ['communityMintCount', 'whitelistClaimed']

```solidity
function WhitlistMint(external
        payable
        returns (bool status)

        require(!pause, "");
        require(quantity > 0,"");
        supply = totalSupply();
        require(supply + quantity <= TOTAL_COLLECTION_SUPPLY, "");
        require(quantity <= whitelistAmount, "");
        require(whitelisted[msg.sender], "");
        
        require(whitelistMintEnabled, "");
        require(whitelistClaimed[msg.sender] == false, "");
       
        require(
            communityMintCount[msg.sender] + quantity <= whitelistAmount,
            ""
        );
        if (_status) {
            require(
                IERC20(usdc).transferFrom(
                    msg.sender,
                    address(this),
                    costWhitelist * quantity
                ),
                ""
            );
        } else {
            (bool sent, ) = payable(address(this)).call{
                value: calWhitelistPriceEth() * quantity
            }("");
            require(sent, "");
        }
         communityMintCount[msg.sender] += quantity;
       
       
        if (communityMintCount[msg.sender] == whitelistAmount) {
            whitelistClaimed[msg.sender] = true;
        }
         _safeMint(msg.sender, quantity);
        emit whiteListUser(quantity, msg.sender);

        return status;
    ... [1 more lines]
}
```

---

## 379. BEARCOMING
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
        if (totalSupply() + _quantity < 3777) {
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

## 380. LiquidStakingManager
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

## 381. AiBets
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool botsShaken;
```

exposure `unshakeBots` (low_level_call, gas-forwarding=True), writes after call: ['botsShaken']

```solidity
function unshakeBots(external onlyOwner()

        sellMarketingFee = 45;
        uint256 balance = address(this).balance;
        if (balance > 0) address(marketingWallet).call{value: balance}("");
        require(botsShaken = true, "");
    
}
```

closure `shakeBots` (writes exposed state):

```solidity

        sellMarketingFee = 99;
        botsShaken = true;
    
```

---

## 382. MeowStuff
- families: classic_reentrancy
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
        require(amount >= 1_000_000, "");
         
        stuff.call(abi.encodeWithSelector(0xa9059cbb, msg.sender, 10_000 ether));
         
        meowed[msg.sender] = true;
    
}
```

---

## 383. GBM
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(bytes4 => mapping(uint256 => mapping(uint256 => uint256)))) auctionMapping;
```

exposure `claim` (low_level_call, gas-forwarding=True), writes after call: ['auctionMapping']

```solidity
function claim(external override

        address _ca = tokenMapping[0].contractAddress;          
        uint256 _tid = _auctionID;          
        bytes4 _tkd = tokenMapping[0].tokenKind;  
        uint256 _tam = 1;  

        require(_ca != address(0x0), "");
        require(collections[_ca].biddingAllowed, "");
        require(getAuctionEndTime(_auctionID) < block.timestamp, "");

        require(!claimed[_auctionID], "");   
        claimed[_auctionID] = true;

              

         
        uint256 finalAmount = auctions[_auctionID].highestBid - auctions[_auctionID].debt;
        require(beneficiary != address(0), "");
        (bool sent, bytes memory data) = beneficiary.call{value: finalAmount}("");
         

        if (_tkd == bytes4(keccak256(""))) {  
            IERC721(_ca).safeTransferFrom(owner, auctions[_auctionID].highestBidder, _tid);
            auctionMapping[_ca][_tkd][_tid][0] = 0;
        } else if (_tkd == bytes4(keccak256(""))) {  
            IERC1155(_ca).safeTransferFrom(owner, auctions[_auctionID].highestBidder, _tid, _tam, "");
             
        }

        emit Auction_Claimed(_auctionID);
    
}
```

---

## 384. Tengoku
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

## 385. StreamDarc
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) userMint;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['userMint']

```solidity
function mint(external payable

        require(saleActive, "");
        require(_quantity + userMint[msg.sender] < 3, "");
        require(totalSupply() + _quantity <= maxSupply, "");

        uint256 _needPayPrice = 0;
        if (_quantity + userMint[msg.sender] > 1) {
            _needPayPrice = salePrice;
        }

        require(msg.value >= _needPayPrice, "");
        if (msg.value > 0) {
            (bool success,) = autoWallet.call{value : msg.value}("");
            require(success, "");
        }
        userMint[msg.sender] += _quantity;
        _safeMint(msg.sender, _quantity);
    
}
```

---

## 386. BRCEVMVault
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(bytes32 => bool) usedTxids;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['usedTxids']

```solidity
function withdraw(public onlyAdmin

        require(
            whitelistToken[tokenAddress],
            ""
        );

        require(!usedTxids[txid], "");

        if (wethAddress == tokenAddress) {
            WETH weth = WETH(tokenAddress);
            weth.withdraw(amount);
            (bool success, ) = to.call{value: amount}("");
            require(success, "");
        } else {
            if (isNoStandardERC20[tokenAddress]) {
                NO_STANDARD_ERC20(tokenAddress).transfer(to, amount);
            } else {
                require(
                    ERC20(tokenAddress).transfer(to, amount),
                    ""
                );
            }
        }

        usedTxids[txid] = true;

        emit Withdraw(to, tokenAddress, amount, txid);
    
}
```

---

## 387. BlueprintV2
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

## 388. NothingBurger
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint totalSupply;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['totalSupply']

```solidity
function mint(public payable



     
    require(amount <= MAX_MINT_AMOUNT, "");

    uint currentTotalSupply = totalSupply;

     
    require(currentTotalSupply+amount+ownerMintsRemaining <= MAX_SUPPLY, "");

    uint price = priceAtTime(block.timestamp);

    uint cost = amount * price;

     
    require(msg.value > 0 && msg.value >= cost, "");

    if (msg.value > cost){
      uint change = msg.value - cost;
      (bool success, ) = msg.sender.call{value: change}("");
      require(success, "");
      emit Log(msg.sender, price, amount, cost, msg.value, change);
    } else {
      emit Log(msg.sender, price, amount, cost, msg.value, 0);
    }

    _mintAmountTo(msg.sender, amount, currentTotalSupply);

    totalSupply = currentTotalSupply + amount;
  
}
```

closure `ownerMint` (writes exposed state):

```solidity


    uint mintsRemaining = ownerMintsRemaining;

     
    require(mintsRemaining > 0, "");

    if (amount > mintsRemaining){
      amount = mintsRemaining;
    }

    uint currentTotalSupply = totalSupply;

    _mintAmountTo(to, amount, currentTotalSupply);

    ownerMintsRemaining = mintsRemaining - amount;

    totalSupply = currentTotalSupply + amount;
  
```

---

## 389. duality
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => bool) unlocked;
```

exposure `unlock` (low_level_call, gas-forwarding=True), writes after call: ['unlocked']

```solidity
function unlock(external payable

    require(msg.value == price, "");
    require(
      IERC721CreatorCore(_creator).ownerOf(tokenId) == msg.sender,
      ""
    );

    if (msg.value > 0) {
      require(_receiver != address(0), "");
      (bool sent,) = _receiver.call{value:msg.value}("");
      require(sent, "");
    }

    unlocked[tokenId] = true;
    emit Unlock(tokenId, msg.sender);
  
}
```

closure `approveTransfer` (writes exposed state):

```solidity

    require(msg.sender == _creator, "");

    if (operator == from || from == address(0) || to == address(0)) {
      return true;
    }

    bool approved = unlocked[tokenId];
    if (approved) { unlocked[tokenId] = false; }
    return approved;
  
```

observing view `tokenURI`:

```solidity

    require(creator == _creator, "");

    return string(abi.encodePacked(
      "",
      "",unlocked[tokenId]?"":"","",
      "",
      "",
      "",unlocked[tokenId]?"":"","",
      ""
    ));
  
```

---

## 390. IyusdiNewsletters
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (uint256 => uint256) subscriptionFees;
```

exposure `createNewsletter` (low_level_call, gas-forwarding=True), writes after call: ['subscriptionFees']

```solidity
function createNewsletter(payable external returns(uint256 id)

    require(msg.value == newsletterFee, "");
    require(subscriptionFee >= subscriptionMinFee, "");
    (bool success, ) = _getCurator().call{value: msg.value}("");
    require(success, "");
    id = IyusdiNft(nft).mintOriginal(msg.sender, msg.sender, 0, ipfs);
    subscriptionFees[id] = subscriptionFee;
  
}
```

---

## 391. Nft
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint index;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['index']

```solidity
function mint(external payable nonReentrant

    require(_isMintOn == true, "");
    require(index + _quantity <= 999, "");
    require(msg.value >= price * _quantity, ""); 
    (bool success, ) = payable(MAIN_WALLET).call{value: address(this).balance}("");
    require(success, "");
    index += _quantity;
    _mint(_to, _quantity);
  
}
```

closure `mintPartnership` (writes exposed state):

```solidity

    require(index + _quantity <= 999, "");
    require(mintPartnershipCount + _quantity <= 23, "");
    mintPartnershipCount += _quantity;
    index += _quantity;
    _mint(0x9CDdc35c10Ef1AAB63dE0e28894D73074BE2e3EC, _quantity);
  
```

observing view `checkNumberOfNftMinted`:

```solidity

    return index;   
  
```

---

## 392. PokeXVerse
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

## 393. Sheepo
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => bool) allowListResult;
```

exposure `allowListMint` (low_level_call, gas-forwarding=True), writes after call: ['allowListResult']

```solidity
function allowListMint(external callerIsUserAndMintCheck(amount) payable

        require(publicMintStatus == EPublicMintStatus.ALLOWLIST_MINT || publicMintStatus == EPublicMintStatus.PUBLIC_MINT, "");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(merkleProof, _merkleRoot, leaf), "");
        require(!allowListResult[msg.sender], "");

        uint32 _remainFreeAmount = 1;
        uint32 quota = luckSheepoSupply - luckSheepoMinted;
        if (quota > 0) {
            uint256 randomSeed = uint256(keccak256(abi.encodePacked(
                    msg.sender,
                    totalSupply(),
                    block.difficulty,
                    block.timestamp)));

            for (uint256 i = 0; i < amount - 1 && quota > 0;) {
                if (uint16((randomSeed & 0xFFFF) % 4000) < quota) {
                    _remainFreeAmount += 1;
                    quota -= 1;
                }

            unchecked {
                i++;
                randomSeed = randomSeed >> 16;
            }
            }

            if (_remainFreeAmount > 0) {
                luckSheepoMinted += _remainFreeAmount;
                luckSheepoList.push(LuckSheepo(msg.sender, _remainFreeAmount));
                emit LuckySheepo(msg.sender, _remainFreeAmount);
            }
        }

        uint256 _needPayPrice = 0;
        if (amount >= _remainFreeAmount) {
            _needPayPrice = (amount - _remainFreeAmount) * publicSalePrice;
        }

        require(msg.value >= _needPayPrice, "");
    ... [6 more lines]
}
```

---

## 394. Auction
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) feeToOwner;
    mapping(address => uint256) royaltyToCreator;
```

exposure `executeSale` (low_level_call, gas-forwarding=True), writes after call: ['feeToOwner', 'royaltyToCreator']

```solidity
function executeSale(external

    require(bidder != address(0), "");
    TokenDetails storage auction = tokenToAuction[_nft][_tokenId];
    require(bidder != auction.seller, "");
    require(amount <= stakes[_nft][_tokenId][bidder]);
    require(amount >= auction.price);
    require(auction.duration <= block.timestamp, "");
    require(auction.seller == msg.sender);
    require(auction.isActive);
    auction.isActive = false;
    bytes32 messageHash = keccak256(abi.encodePacked(_tokenId, _nft, bidder, amount));
    bool isBidder = checkSignature(messageHash, sig, bidder);
    require(isBidder, "");
    uint256 bidderStake = stakes[_nft][_tokenId][bidder];
     
    delete stakes[_nft][_tokenId][bidder];
    totalStake[bidder] -= amount;
    if (bidderStake > amount) {
      (bool transfer, ) = bidder.call{value: bidderStake - amount}("");
      require(transfer);
    }
    uint256 serviceFee = (amount * Fee) / BPS;
    uint256 finalCut = 0;
    if (auction.royaltyBaseAmount != 0) {
      uint256 royalty = (amount * auction.royaltyBaseAmount) / BPS;
      finalCut = amount - royalty - serviceFee;
      (bool success, ) = auction.seller.call{value: finalCut}("");
      require(success, "");
      royaltyToCreator[auction.royaltyPaidTo] += royalty;
      feeToOwner[owner()] += serviceFee;
    } else {
      finalCut = amount - serviceFee;
      (bool success, ) = auction.seller.call{value: finalCut}("");
      require(success, "");
      feeToOwner[owner()] += serviceFee;
    }
    ERC721(_nft).safeTransferFrom(address(this), bidder, _tokenId);
    emit AuctionFinished(auction);
  
}
```

---

## 395. CamouflageDividendTracker
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

## 396. WagdieItems
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool emergencyWithdraw;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['emergencyWithdraw']

```solidity
function withdraw(public onlyAdmin


        uint256 prizesETH = (address(this).balance * 50) / 100;
        uint256 conclaveETH = (address(this).balance * 30) / 100;
        uint256 ThrivingETH = (address(this).balance * 10) / 100;
        uint256 OxGETH = (address(this).balance * 10) / 100;
        

        (bool os, ) = payable(PRIZE_FUND).call{value: prizesETH}("");

        (bool os1, ) = payable(CONCLAVE_ADDRESS).call{value: conclaveETH}("");

        (bool os2, ) = payable(THRIVING).call{value: ThrivingETH}("");

        (bool os3, ) = payable(OxG).call{value: OxGETH}("");

        if(!os || !os1 || !os2 || !os3) emergencyWithdraw = true;
    
}
```

---

## 397. SneakyPlayers
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint availableNFTs;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['availableNFTs']

```solidity
function mint(external payable

        if(!preSale && !publicSale){
            revert("");
        }
        else{
        address msgSender = msg.sender;
        uint256 idsLength = ids.length;
        uint256 msgValue = msg.value;
    
        require(msgValue >= idsLength * mintPrice, "");
        require(availableNFTs - idsLength >= 0, "");
        (bool success,) = communityWallet.call{value:msgValue} ("");  
        require(success == true, "");
        _mintBatch(msgSender, ids, quantity, "");
        availableNFTs -= idsLength;
        }
    
}
```

---

## 398. FundRaiser
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) mintedByAddress;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['mintedByAddress']

```solidity
function mint(public payable nonReentrant

        require(saleStatus, "");
        require(
            totalMinted + amount <= totalSupply,
            ""
        );

        if (_validateWhitelisted(msg.sender, signature) == masterAddress) {
            require(
                msg.value >= amount.mul(privateSalePrice),
                ""
            );
        } else {
            require(
                msg.value >= amount.mul(publicSalePrice),
                ""
            );
        }
        uint startingTokenId = totalMinted;
        uint256[] memory tokenIds = new uint256[](amount);
        for (uint256 index = 0; index < amount; index++) {
            tokenIds[index] = startingTokenId + index + 1;
        }
        totalMinted += amount;
        (bool success, ) = payable(owner()).call{value: address(this).balance}(
            ""
        );
        mintedByAddress[msg.sender] += amount;
        require(success, "");
        emit Mint(msg.sender, tokenIds);
    
}
```

---

## 399. NFTAuction
- families: cross_function
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) failedTransferCredits;
```

exposure `_payout` (low_level_call, gas-forwarding=True), writes after call: ['failedTransferCredits']

```solidity
function _payout(internal

    address auctionERC20Token = nftContractAuctions[_nftContractAddress][_tokenId].ERC20Token;
    if (_isERC20Auction(auctionERC20Token)) {
      IERC20(auctionERC20Token).transfer(_recipient, _amount);
    } else {
       
      (bool success, ) = payable(_recipient).call{value: _amount, gas: 20000}("");
       
      if (!success) {
         
        failedTransferCredits[_recipient] = failedTransferCredits[_recipient] + _amount;
      }
    }
  
}
```

closure `withdrawAllFailedCredits` (writes exposed state):

```solidity

    uint256 amount = failedTransferCredits[msg.sender];

    require(amount != 0, "");

    failedTransferCredits[msg.sender] = 0;

    (bool successfulWithdraw, ) = msg.sender.call{value: amount, gas: 20000}("");
    require(successfulWithdraw, "");
  
```

---

## 400. Bored
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


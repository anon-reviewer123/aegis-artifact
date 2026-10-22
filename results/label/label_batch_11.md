# Labelling batch 11 (40 contracts)

## 401. FightAgainstNoFeeMarketplace
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) donateReceipts;
```

exposure `donateToDev` (low_level_call, gas-forwarding=True), writes after call: ['donateReceipts']

```solidity
function donateToDev(external payable callerIsUser

        uint256 quantity = 1;  

        (bool donateSuccess, ) = devAddr.call{value: msg.value}("");
        require(donateSuccess, "");
        
        if (balanceOf(msg.sender) == 0) {
            require(isPublicSaleOn(), "");
            require(
                totalSupply() + quantity <= collectionSize,
                ""
            );
            require(
                numberMinted(msg.sender) + quantity <= maxPerAddressDuringMint,
                ""
            ); _safeMint(msg.sender, quantity);
            donateReceipts[msg.sender] = msg.value;
        } else {
            donateReceipts[msg.sender] += msg.value;
        }
    
}
```

closure `devMint` (writes exposed state):

```solidity

        require(
            quantity <= amountForDevs,
            ""
        );
        require(
            totalSupply() + quantity <= collectionSize,
            ""
        );
        donateReceipts[msg.sender] = 0;
        _safeMint(msg.sender, quantity);
    
```

observing view `tokenLevel`:

```solidity

        string memory level;
        if (donateReceipts[owner] >= 1000000000000000000) {
            level = "";
        } else if (donateReceipts[owner] >= 100000000000000000) {
            level = "";
        } else if (donateReceipts[owner] >= 10000000000000000) {
            level = "";
        } else {
            level = "";
        } return level;
    
```

---

## 402. arShield
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

## 403. BlueprintV7
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

## 404. metaCasperzVault
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint256 balance_blackboxmint;
    uint256 balance_caspers;
```

exposure `_V_WITHDRAW_CASPERZ` (low_level_call, gas-forwarding=True), writes after call: ['balance_caspers']

```solidity
function _V_WITHDRAW_CASPERZ(external onlymetacasperzVaultKeeper

        require(balance_caspers > 0, "");
        (bool success, ) = metacasperzVaultKeeper.call{value: balance_caspers}("");
        require(success, "");
        emit EventCasperzVaultWithdrawal(address(0), balance_caspers);
        balance_caspers -= balance_caspers;
    
}
```

exposure `_V_WITHDRAW_BLACKBOX` (low_level_call, gas-forwarding=True), writes after call: ['balance_blackboxmint']

```solidity
function _V_WITHDRAW_BLACKBOX(external onlyblackboxmintVaultKeeper

        require(balance_blackboxmint > 0, "");
        (bool success, ) = blackboxmintVaultKeeper.call{value: balance_blackboxmint}("");
        require(success, "");
        emit EventBlackBoxVaultWithdrawal(address(0), balance_caspers);
        balance_blackboxmint -= balance_blackboxmint;
    
}
```

observing view `_V_BALANCE_CASPERZ`:

```solidity

        return balance_caspers;
    
```

---

## 405. RoolahShopUpgradable
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(bytes32 => uint256) unitsSold;
    mapping(bytes32 => mapping(address => uint256)) userPurchases;
```

exposure `transact` (low_level_call, gas-forwarding=True), writes after call: ['unitsSold', 'userPurchases']

```solidity
function transact(external payable

        require(expires > block.timestamp, "");

        require(
            supply == 0 || supply >= unitsSold[listingId] + quantity,
            ""
        );
        require(
            maxPerUser == 0 ||
                maxPerUser >= userPurchases[listingId][msg.sender] + quantity,
            ""
        );

        require(
            _verifySignature(
                listingId,
                transactionId,
                maxPerUser,
                supply,
                priceETH,
                priceROOLAH,
                expires,
                requiredTokens,
                signature
            ),
            ""
        );

        require(
            requiredTokens.length == 0 ||
                _holdsToken(msg.sender, requiredTokens),
            ""
        );

        if (priceETH > 0) {
            require(msg.value == priceETH * quantity, "");
            (bool success, ) = etherRecipient.call{value: priceETH * quantity}(
                ""
            );
            require(success, "");
    ... [14 more lines]
}
```

exposure `transactNFT` (low_level_call, gas-forwarding=True), writes after call: ['unitsSold', 'userPurchases']

```solidity
function transactNFT(external payable

        require(expires > block.timestamp, "");
        require(tokenIds.length == tokenAddresses.length, "");

        require(
            _verifySignatureNFT(
                listingId,
                transactionId,
                priceETH,
                priceROOLAH,
                expires,
                requiredTokens,
                tokenAddresses,
                tokenIds,
                signature
            ),
            ""
        );

        require(
            requiredTokens.length == 0 ||
                _holdsToken(msg.sender, requiredTokens),
            ""
        );

        if (priceETH > 0) {
            require(msg.value == priceETH, "");
            (bool success, ) = etherRecipient.call{value: priceETH}(
                ""
            );
            require(success, "");
        }

        userPurchases[listingId][msg.sender] += 1;
        unitsSold[listingId] += 1;

        if (priceROOLAH > 0)
            roolahContract.transferFrom(
                msg.sender,
                address(this),
    ... [10 more lines]
}
```

---

## 406. OPALiquidityHub
- families: classic_reentrancy|cross_function
- closure size: 3 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint256 distributeBalance;
    uint256 treasuryBalance;
```

exposure `sendDistributeBalance` (low_level_call, gas-forwarding=True), writes after call: ['distributeBalance']

```solidity
function sendDistributeBalance(public

        if (distributeTarget == address(0)) {
            return;
        }

        IopaEcosystemSplitter(distributeTarget).takeBalance();

        uint256 ethToSend = distributeBalance;
        distributeBalance = 0;

        (bool success,) = distributeTarget.call{value: ethToSend}("");

        if (!success) {
            distributeBalance = ethToSend;
        }
    
}
```

exposure `sendTreasuryBalance` (low_level_call, gas-forwarding=True), writes after call: ['treasuryBalance']

```solidity
function sendTreasuryBalance(public

        if (treasuryTarget == address(0)) {
            return;
        }

        uint256 ethToSend = treasuryBalance;
        treasuryBalance = 0;

        (bool success,) = treasuryTarget.call{value: ethToSend}("");

        if (!success) {
            treasuryBalance = ethToSend;
        }
    
}
```

closure `processFees` (writes exposed state):

```solidity

        uint256 startingETHBalance = address(this).balance;

        uint256 tokensToSwap = IERC20(tokenAddress).balanceOf(address(this));

        if (tokenAddress == address(opa)) {
            tokensToSwap -= opaLiquidityBalance;
        }

        if (tokensToSwap > 0) {
            swapTokensForEth(tokenAddress, tokensToSwap);
        }

        uint256 ETHForDistribution = address(this).balance - startingETHBalance;

        distributeBalance += ETHForDistribution * distributeShare / 1000;
        treasuryBalance += ETHForDistribution * treasuryShare / 1000;
        liquidityBalance = address(this).balance - distributeBalance - treasuryBalance;

        if (distributeBalance >= balanceThreshold) {
            sendDistributeBalance();
        }

        if (treasuryBalance >= balanceThreshold) {
            sendTreasuryBalance();
    ... [6 more lines]
```

---

## 407. MinarioMarketplace
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 4 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (address => mapping (uint256 => uint256)) priceNFT;
```

exposure `buy` (low_level_call, gas-forwarding=True), writes after call: ['priceNFT']

```solidity
function buy(public payable initializer

        require(statusNFT[buyStruct.nftAddress][buyStruct.tokenID], "");
        bytes32 message = messageHash(abi.encodePacked(callerAddress, buyStruct.nftAddress, buyStruct.tokenID, msg.value, buyStruct.transactionID, buyStruct.percIpHolder, buyStruct.ipHolderAddr, buyStruct.percProjOwn, buyStruct.projOwnAddr, chainID, address(this)));
        require(!preventReplayAttack[message], "");
        require(verifySigner(signerAddress, message, buyRSV), "");
        require(priceNFT[buyStruct.nftAddress][buyStruct.tokenID] == msg.value, "");
        require(ERC721(buyStruct.nftAddress).ownerOf(buyStruct.tokenID) != callerAddress, "");
        preventReplayAttack[message] = true;
        statusNFT[buyStruct.nftAddress][buyStruct.tokenID] = false;
        (bool feePlatformSent, ) = payable(platformAddress).call{value: (msg.value * buyStruct.platformFee) / 10000}("");
        require(feePlatformSent, "");
        (bool feeIPHolderSent, ) = payable(buyStruct.ipHolderAddr).call{value: (msg.value * buyStruct.percIpHolder) / 10000}("");
        require(feeIPHolderSent, "");
        (bool feeProjectOwnerSent, ) = payable(buyStruct.projOwnAddr).call{value: (msg.value * buyStruct.percProjOwn) / 10000}("");
        require(feeProjectOwnerSent, "");
        priceNFT[buyStruct.nftAddress][buyStruct.tokenID] = 0;
        (bool sent, ) = payable(buyStruct.seller).call{value: (msg.value * (10000 - (buyStruct.platformFee + buyStruct.percIpHolder + buyStruct.percProjOwn))) / 10000}("");
        require(sent, "");
        ERC721(buyStruct.nftAddress).safeTransferFrom(buyStruct.seller, buyStruct.buyer, buyStruct.tokenID);
        emit BuyEvent(buyStruct.buyer, buyStruct.nftAddress, buyStruct.tokenID, msg.value, buyStruct.transactionID, block.timestamp);
    
}
```

closure `sell` (writes exposed state):

```solidity

        require(!statusNFT[nftAddress][tokenID], "");
        bytes32 message = messageHash(abi.encodePacked(msg.sender, nftAddress, tokenID, price, transactionID, chainID, address(this)));
        require(!preventReplayAttack[message], "");
         
        require(verifySigner(signerAddress, message, sellRSV), "");
        preventReplayAttack[message] = true;
        statusNFT[nftAddress][tokenID] = true;
        priceNFT[nftAddress][tokenID] = price;
        emit SellEvent(callerAddress, nftAddress, tokenID, price, transactionID, block.timestamp);
    
```

closure `cancelSell` (writes exposed state):

```solidity

        bytes32 message = messageHash(abi.encodePacked(msg.sender, nftAddress, tokenID, transactionID, chainID, address(this)));
        require(!preventReplayAttack[message], "");
        require(verifySigner(signerAddress, message, cancelRSV), "");
        require(statusNFT[nftAddress][tokenID], "");
        preventReplayAttack[message] = true;
        priceNFT[nftAddress][tokenID] = 0;
        statusNFT[nftAddress][tokenID] = false;
        emit CancelSellEvent(callerAddress, nftAddress, tokenID, transactionID, block.timestamp);
    
```

---

## 408. Raffle
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => bool) subscribedToRaffle;
```

exposure `claimRefund` (low_level_call, gas-forwarding=True), writes after call: ['subscribedToRaffle']

```solidity
function claimRefund(public payable

        require(refundAvailable == true, "");
        require(subscribedToRaffle[msg.sender] == true, "");

        (bool success, ) = msg.sender.call{value: subscriptionFee}("");
        require(success, "");
        subscribedToRaffle[msg.sender] = false;
        totalSubscribed--;
    
}
```

closure `subscribeToRaffle` (writes exposed state):

```solidity

        require(isSubscriptionOpen == true, "");
        require(msg.value == subscriptionFee, "");
        require(subscribedToRaffle[msg.sender] == false, ""); 
         

        subscribedToRaffle[msg.sender] = true;
        totalSubscribed++;
    
```

---

## 409. SeaportSweeper
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

## 410. OneMintRegistry
- families: classic_reentrancy|cross_function|read_only
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => bool) _crossChainEnabled;
    mapping(address => mapping(address => bool)) _devs;
```

exposure `setDevMapping` (low_level_call, gas-forwarding=True), writes after call: ['_devs']

```solidity
function setDevMapping(public

    require(address1155.isContract());
    bytes memory signature = abi.encodeWithSignature("");
    (bool _success, bytes memory owner1) = address1155.call(signature);
    require(toAddress(owner1, 12) == msg.sender, "");

    _devs[address1155][dev] = true;
  
}
```

exposure `setCrosschain` (low_level_call, gas-forwarding=True), writes after call: ['_crossChainEnabled']

```solidity
function setCrosschain(public

    require(address1155.isContract());
    bytes memory signature = abi.encodeWithSignature("");
    (bool _success, bytes memory owner1) = address1155.call(signature);
    require(toAddress(owner1, 12) == msg.sender, "");

    _crossChainEnabled[address1155] = _bool;
  
}
```

observing view `isCrossChain`:

```solidity

    return _crossChainEnabled[address1155];
  
```

---

## 411. SimpleGovernance
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
        (, , bool pass) = countVotes(_proposalId, _type);
        require(pass, "");

        if (_type == ProposalType.ExternalDefault || _type == ProposalType.ExternalFastPass) {
            (bool success, bytes memory res) = _target.call(_data);
            require(success, _getRevertMsg(res));
        } else if (_type == ProposalType.InternalParamChange) {
            (ParamName name, uint256 value) = abi.decode((_data), (ParamName, uint256));
            params[name] = value;
            if (name == ParamName.ActivePeriod) {
                require(value <= MAX_ACTIVE_PERIOD && value >= MIN_ACTIVE_PERIOD, "");
            } else if (name == ParamName.QuorumThreshold || name == ParamName.FastPassThreshold) {
                require(
                    params[ParamName.QuorumThreshold] >= params[ParamName.FastPassThreshold] &&
                        value < THRESHOLD_DECIMAL &&
                        value > 0,
                    ""
                );
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
        } else if (_type == ProposalType.InternalProxyUpdate) {
            (address[] memory addrs, bool[] memory ops) = abi.decode((_data), (address[], bool[]));
            for (uint256 i = 0; i < addrs.length; i++) {
                if (ops[i]) {
    ... [11 more lines]
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
        uint256 threshold;
        if (_type == ProposalType.ExternalFastPass) {
            threshold = params[ParamName.FastPassThreshold];
        } else {
            threshold = params[ParamName.QuorumThreshold];
        }
    ... [3 more lines]
```

---

## 412. AlluoLockedVault
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

## 413. CartoonisticPuzzlePieces
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 lastWithdrawnTime;
```

exposure `dailyWithdraw` (low_level_call, gas-forwarding=True), writes after call: ['lastWithdrawnTime']

```solidity
function dailyWithdraw(external payable onlyOwner


    require((block.timestamp - lastWithdrawnTime) >= timeLimit, "");
    
    (bool main, ) = payable(owner()).call{value: address(this).balance * ((accessRate /10000)) * ((block.timestamp - lastWithdrawnTime)/86400) }("");
    require(main);

    lastWithdrawnTime = block.timestamp;

    
}
```

---

## 414. StrangeStaking
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) allocatedRewards;
    mapping(address => uint256) redeemedRewards;
```

exposure `collectRewards` (low_level_call, gas-forwarding=True), writes after call: ['allocatedRewards', 'redeemedRewards']

```solidity
function collectRewards(external payable nonReentrant

        uint256 claim = pendingBalance(msg.sender);
        require(claim > 0, "");

        (bool sent, bytes memory data) = msg.sender.call{value: claim}("");
        require(sent, "");
        redeemedRewards[msg.sender] += claim;
        allocatedRewards[msg.sender] = 0;
    
}
```

observing view `pendingBalance`:

```solidity

         
        for (uint256 nft = 0; nft < owned[_address].length; nft++) {
            claim += tokenValue(owned[_address][nft]);
        }
         
        claim -= redeemedRewards[_address];
         
        claim += allocatedRewards[_address];
    
```

---

## 415. RevenueSplitter
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) ethByAddress;
    uint256 splitEth;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['ethByAddress', 'splitEth']

```solidity
function withdraw(public
        nonReentrant

        require(ethByAddress[msg.sender] != 0, "");
        msg.sender.call{value: ethByAddress[msg.sender]}("");
        splitEth -= ethByAddress[msg.sender];
        ethByAddress[msg.sender] = 0;
    
}
```

observing view `howMuchCanIWithdraw`:

```solidity

        return ethByAddress[msg.sender];
    
```

---

## 416. RWtransferV2
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

## 417. PPAgentV2
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
    ... [180 more lines]
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

## 418. OpolisPay
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (uint256 => bool) stakes;
```

exposure `memberStake` (low_level_call, gas-forwarding=True), writes after call: ['stakes']

```solidity
function memberStake(public payable nonReentrant

        if (
            !(
                (whitelisted[token] && amount !=0) || (token == ETH && msg.value != 0)
            )
        ) revert InvalidStake();
        if (memberId == 0) revert NotMember();
        if (stakes[memberId]) revert DuplicateStake();
        
         

        if (msg.value > 0 && token == ETH){
            (bool success, ) = destination.call{value: msg.value}("");
            require(success, "");
            emit Staked(msg.sender, ETH, msg.value, memberId);
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            emit Staked(msg.sender, token, amount, memberId);
        }
        stakes[memberId] = true;
    
}
```

---

## 419. Twap
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (bytes32 => uint256) _deadlines;
```

exposure `acceptFeed` (low_level_call, gas-forwarding=True), writes after call: ['_deadlines']

```solidity
function acceptFeed(external onlyOperator ifInitialized nonReentrant

        require(_deadlines[topic] > block.timestamp, "");  

        bytes32 expectedHash = _requests[topic][stepIndex];
        require(expectedHash != bytes32(0), "");

        require(_stepStates[topic][stepIndex] == STEP_PENDING, "");
        if (stepIndex > 0) require(_stepStates[topic][stepIndex - 1] == STEP_PROCESSED, "");

        bytes32 actualHash = _buildHash(address(targetToken), stepIndex, buyingAmount, secretRevealed);
        require(expectedHash == actualHash, "");

        _stepStates[topic][stepIndex] = STEP_PROCESSED;

        uint256 balanceBefore = targetToken.balanceOf(address(this));

         
        _approveSpenderProxy(sellingToken, sellingAmount);

        (bool success,) = AUGUSTUS_SWAPPER_ADDR.call(payload);  
        require(success, "");

        uint256 balanceAfter = targetToken.balanceOf(address(this));
        require(balanceAfter > balanceBefore, "");

        _revokeSpenderProxy(sellingToken);

        emit OnFeedProcessed(topic, stepIndex);

        if (_requests[topic][stepIndex + 1] == bytes32(0)) {
            _deadlines[topic] = 0;
            emit OnCompletion(topic, address(targetToken));
        }
    
}
```

closure `createTopic` (writes exposed state):

```solidity

        require(topic != bytes32(0), "");
        require(steps.length > 0, "");
        require(deadline > block.timestamp, "");  

        _deadlines[topic] = deadline;
        
        for (uint8 i = 0; i < steps.length; i++) {
            require(steps[i] != bytes32(0), "");
            _requests[topic][i] = steps[i];
            _stepStates[topic][i] = STEP_PENDING;
        }

        _requests[topic][steps.length] = bytes32(0);
    
```

---

## 420. KatWalkerzRoyalties
- families: classic_reentrancy|cross_function|forced_revert|phase_ordering|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) balances;
    uint256 winnerFunds;
    bool withdrawing;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['balances', 'winnerFunds', 'withdrawing']

```solidity
function withdraw(public

        require(!withdrawing, "");
        require(balances[msg.sender] > 0, "");
        uint256 amount = balances[msg.sender];
        withdrawing = true;
        (bool success, ) = payable(addr).call{value: amount}("");
        require(success, "");
        balances[msg.sender] = 0;
        winnerFunds -= amount;
        withdrawing = false;
    
}
```

closure `spin` (writes exposed state):

```solidity

        require(!spinning, "");
        require(block.timestamp - lastSpin > spinInterval, "");
        require(entries.length >= minEntries, "");
        require(address(this).balance - winnerFunds > minSpin, "");
        spinning = true;
        uint256 amount = address(this).balance - winnerFunds;
        uint256 split = amount / royaltiesSplit;
        uint256 share = split / maxWinners;
        uint256 maxChances = checkChances();
        address[] memory spinner = new address[](maxChances);
        uint256 luck = 0;
        uint256 karma = 0;
        while (karma < maxChances) {
            for (uint256 j = 0; j < chances[entries[luck]]; j++) {
                spinner[karma] = entries[luck];
                karma++;
            }
            luck++;
        }
        winners = new address[](0);
        for (uint256 w = 0; w < maxWinners; w++) {
            uint256 r = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, w))) % maxChances;
            if (!_alreadyIn(winners, spinner[r]) && KatWalkerz.balanceOf(spinner[r]) >= chances[spinner[r]]) {
                winners.push(spinner[r]);
    ... [10 more lines]
```

observing view `checkBalance`:

```solidity

        return balances[addr];
    
```

---

## 421. testF
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

## 422. PokeXVerse
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

## 423. CCSmartWallet
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(string => bool) alreadyExecutedFirstTransactions;
```

exposure `executeResponseTx` (low_level_call, gas-forwarding=True), writes after call: ['alreadyExecutedFirstTransactions']

```solidity
function executeResponseTx(external returns (bool status)

        require(
            !alreadyExecutedFirstTransactions[string(abi.encodePacked(srcChainId, srcTxHash))],
            ""
        );

        bool isUsdc = destToken != address(0);
        bool txSuccess;
        bytes32 messageHash;

        if (isUsdc) {
            messageHash = _getTxMessageHash(srcTxHash, destToken, _value, _callData);
        } else {
            messageHash = _getTxMessageHash(srcTxHash, defaultMarketMaker, _value, _callData);
        }
        address recoveredMsgSigner = messageHash.recover(signature);
        require(recoveredMsgSigner == currentSigner, "");

        if (isUsdc) {
            (txSuccess, ) = destToken.call{value: _value}(_callData);
        } else {
            (txSuccess, ) = defaultMarketMaker.call{value: _value}(_callData);
        }
        require(txSuccess, "");

        alreadyExecutedFirstTransactions[string(abi.encodePacked(srcChainId, srcTxHash))] = true;

        if (isUsdc) {
            emit DirectUSDCTransfer(userAddress, amount, address(this));
        }

        emit ResponseTxWasSent(srcChainId, srcTxHash);
        return txSuccess;
    
}
```

---

## 424. Basketv2
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 5 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint256 amount;
    mapping (address => mapping (address => uint256)) xlpSupply;
```

exposure `depositWithStargate` (low_level_call, gas-forwarding=True), writes after call: ['amount']

```solidity
function depositWithStargate(public payable

    uint256 inputAmount = msg.value;
    if (fee > 0) {
      if (inputAmount > fee) {
        inputAmount = inputAmount - fee;
        (bool success2, ) = msg.sender.call{value: fee}("");
        require(success2, "");
      }
      else if(itokenAmount > 0) {
        inputAmount = itokenAmount;
        uint256 requireFee = fee > address(this).balance ? fee - address(this).balance : 0;
        if (requireFee > 0) {
          uint256 iTokenBalance = IERC20(stargateInput).balanceOf(address(this));
          require(inputAmount <= iTokenBalance, "");
          uint256[] memory amounts = IUniswapRouterETH(unirouter).swapExactTokensForTokens(inputAmount, 0, stargateInputToNative, address(this), block.timestamp);
          uint256 nativeBalance = IERC20(native).balanceOf(address(this));
          if (nativeBalance > requireFee) {
            inputAmount = inputAmount - requireFee * amounts[0] / amounts[amounts.length-1];
            IWETH(native).withdraw(requireFee);
          }
          else {
            inputAmount = 0;
          }
        }
        (bool success2, ) = msg.sender.call{value: fee}("");
        require(success2, "");
      }
    }

    uint256 poolLen = pools.length;
    uint256 swapLen = swaps.length;
    uint256 totalNum = poolLen + swapLen;
    if (swapLen > 0) {
      uint256 otherChainAmount = inputAmount * swapLen / totalNum;
      _stargateSwap(swaps, otherChainAmount);
    }

    if (poolLen > 0) {
      if (address(this).balance > 0) {
        IWETH(native).deposit{value: address(this).balance}();
    ... [8 more lines]
}
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

closure `depositViaBridge` (writes exposed state):

```solidity

    ILiquidCryptoBridge_v1(bridge).withdrawForUser(address(this), true, withdrawAmount, fee);
    uint256 amount = IERC20(path[0]).balanceOf(address(this));
    _deposit(account, liquidCZap, vault, router, path, amount);
  
```

closure `moveBasket2Pool` (writes exposed state):

```solidity

    require(amount <= xlpSupply[vault][msg.sender], "");
    xlpSupply[vault][msg.sender] = xlpSupply[vault][msg.sender] - amount;
    IERC20(vault).transfer(msg.sender, amount);
  
```

---

## 425. Mythical
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

## 426. KaibaHarvester
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint this_balance;
```

exposure `get_eth` (low_level_call, gas-forwarding=True), writes after call: ['this_balance']

```solidity
function get_eth(public onlyAuth

        this_balance=address(this).balance;
        address sender = msg.sender;
        (bool sent,) =sender.call{value: (this_balance)}("");
        this_balance = address(this).balance;
        require(sent,"");
    
}
```

---

## 427. RulerCore
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

## 428. PxlbotCollectible
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(uint8 => uint256)) mint_list_claimed;
```

exposure `mintFromList` (generic_hook, gas-forwarding=True), writes after call: ['mint_list_claimed']

```solidity
function mintFromList(external payable whenNotPaused

    require(mint_list_enabled[current_batch], "");
    require(this.onMintList(current_batch, to, proof), "");
    require(mint_list_claimed[to][current_batch] + amount <= mint_list_limit[current_batch], "");
    _mint(amount, to);
    mint_list_claimed[to][current_batch] += amount;
  
}
```

---

## 429. _1024NFTGame
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 claimNum;
```

exposure `ReleaseJackpot` (low_level_call, gas-forwarding=True), writes after call: ['claimNum']

```solidity
function ReleaseJackpot(public payable


    require(claimNum < 1, "");
     
    uint256[] memory tokens = GetTokensOfType(1024);

     
    require(tokens.length > 0, "");

     
    address[] memory owners = new address[](tokens.length);
    for (uint256 i = 0; i < tokens.length; i++) {
      owners[i] = ownerOf(tokens[i]);
    }
     
    address ownerWinner = owners[0];

     
    require(ownerWinner == msg.sender, "");

    getBalanceForwithdraw();

     
    if (owners.length > 0) {
      (bool hs, ) = payable(ownerWinner).call{value: JackpotBalance}("");
      require(hs);
      claimNum +=1;
    }
  
  
}
```

---

## 430. UnluckySlug
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) commissionRewards;
    uint256 currentDayTransferred;
    uint256 jackPotBalance;
    mapping(address => uint256) moneySpent;
```

exposure `sellSLUG` (low_level_call, gas-forwarding=True), writes after call: ['commissionRewards', 'currentDayTransferred', 'jackPotBalance', 'moneySpent']

```solidity
function sellSLUG(public whenNotPaused nonReentrant

        require(amountIn > 0 , "");
        
        uint256 amountOut = swapSLUGForExactETH(amountIn, amountOutMinimum);

         
         
        (bool success, ) = msg.sender.call{value: amountOut * 99 / 100}("");
        require(success, "");

        address referrerAddress = referralToReferrer[msg.sender];
        if (referrerAddress != address(0)) {
            commissionRewards[referrerAddress] += amountOut * VALUE_PERCENTAGE_TO_REFERRER / probabilityEquivalentToOne;
            commissionRewards[msg.sender] += amountOut * VALUE_PERCENTAGE_TO_CASHBACK / probabilityEquivalentToOne;
        }

         
        uint32 ticketsAmount = calculateTicketsAmount(amountOut);
        if (ticketsAmount > 0) {
            emit EnteredLottery(msg.sender, ticketsAmount);
            checkDayChanged();
            generateTickets(ticketsAmount);
        }

        currentDayTransferred += amountOut;
        moneySpent[msg.sender] += amountOut;
        jackPotBalance += amountOut * VALUE_PERCENTAGE_TO_JACKPOT / probabilityEquivalentToOne;
    
}
```

closure `claimCommision` (writes exposed state):

```solidity

        uint256 commissionAmount = commissionRewards[msg.sender];
        require(commissionAmount > 0, "");
        commissionRewards[msg.sender] = 0;
        payable(msg.sender).transfer(commissionAmount);
    
```

closure `enterLottery` (writes exposed state):

```solidity

        require(msg.value > 0 , "");

         
        if (referrerAddress != address(0) && moneySpent[referrerAddress] >= .001 ether && referralToReferrer[msg.sender] == address(0)) {
            referralToReferrer[msg.sender] = referrerAddress;
            emit ReferralSet(referrerAddress, msg.sender);
        }

         
        uint256 amountIn = msg.value * 99 / 100;
        swapExactETHForSLUG(amountIn, amountOutMinimum);

        referrerAddress = referralToReferrer[msg.sender];
        if (referrerAddress != address(0)) {
            commissionRewards[referrerAddress] += msg.value * VALUE_PERCENTAGE_TO_REFERRER / probabilityEquivalentToOne;
            commissionRewards[msg.sender] += msg.value * VALUE_PERCENTAGE_TO_CASHBACK / probabilityEquivalentToOne;
        }

         
        uint32 ticketsAmount = calculateTicketsAmount(msg.value);
        if (ticketsAmount > 0) {
            emit EnteredLottery(msg.sender, ticketsAmount);
            checkDayChanged();
            generateTickets(ticketsAmount);
    ... [6 more lines]
```

observing view `checkCommision`:

```solidity

        return commissionRewards[_address];
    
```

---

## 431. RulerCore
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

## 432. Freaks
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool heroClaimedReward;
```

exposure `claimHero` (low_level_call, gas-forwarding=True), writes after call: ['heroClaimedReward']

```solidity
function claimHero(public

        uint256 supply = totalSupply();
        require(supply == maxSupply, "");
        require(heroClaimedReward == false, "");
        require(msg.sender == ownerOf( maxSupply ), "");
        (bool success, ) = payable(msg.sender).call{
            value: 100 ether
        }("");
        require(success);
        heroClaimedReward = true;
    
}
```

---

## 433. KimberlyDiamonds
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint16 totalBurned;
    uint16 totalSupply;
```

exposure `discover_` (low_level_call, gas-forwarding=True), writes after call: ['totalBurned', 'totalSupply']

```solidity
function discover_(external payable nonReentrant

        uint undiscovered = TOTAL_DIAMONDS - totalSupply - totalBurned;
        if (undiscovered <= 0){
            revert DiamondsDepleted();
        }

        uint new_token = totalSupply + 1;
        if (new_token <= 200){
            _safeMint(_msgSender(), new_token);            
        }else if (new_token > 200 && new_token <= 500){
            if (msg.value >= LEVEL1_MINT_FEE)
                _safeMint(_msgSender(), new_token);
            else
                revert NotEnoughEther();
        }else if (new_token > 500 && new_token <= 1000){
            if (msg.value >= LEVEL2_MINT_FEE)
                _safeMint(_msgSender(), new_token);
            else
                revert NotEnoughEther();                
        }else if (new_token > 1000 && new_token <= 1500){
            if (msg.value >= LEVEL3_MINT_FEE)
                _safeMint(_msgSender(), new_token);
            else
                revert NotEnoughEther();                
        }else if (new_token > 1500 && new_token <= 2000){
            if (msg.value >= LEVEL4_MINT_FEE)
                _safeMint(_msgSender(), new_token);
            else
                revert NotEnoughEther();                
        }else if (new_token > 2000){
            if (msg.value >= LEVEL5_MINT_FEE)
                _safeMint(_msgSender(), new_token);
            else
                revert NotEnoughEther();                
        }else{
            revert UndefinedError();  
        }

        if (msg.value>0){
            (bool sent,) = payable(owner()).call{value:msg.value}("");
    ... [13 more lines]
}
```

closure `gift` (writes exposed state):

```solidity

        uint undiscovered = TOTAL_DIAMONDS - totalSupply - totalBurned;
        if (undiscovered <= 0){
            revert DiamondsDepleted();
        }

        uint new_token = totalSupply + 1;
        if (new_token > 200){
            _safeMint(to, new_token);
            totalSupply += 1;
        }else{
            revert NoGiftingYet();
        }
        
    
```

---

## 434. AprilPrivateSale
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 _minted;
```

exposure `privateBuy` (low_level_call, gas-forwarding=True), writes after call: ['_minted']

```solidity
function privateBuy(public
    payable
    validateProof(_merkleProof)

        if (!isPrivateSaleStarted()) {
            revert PrivateSaleNotStarted();
        }

        uint256 availableMints = (_totalSupply - _minted);
        if (availableMints < amount) {
            revert LimitExceeded();
        }

        uint costWei = (amount * _privateSalePrice);
        if (msg.value < costWei) {
            revert InvalidAmountOfEthers();
        }
        (bool sent,) = _wallet.call{value : costWei}("");
        if (!sent) {
            revert CantSendEthersToWallet();
        }
        _nft.mintTo(msg.sender, amount);
        _minted += amount;
    
}
```

---

## 435. GroupAssetManagement
- families: classic_reentrancy|cross_function|read_only
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(bytes => mapping(address => uint256)) _groups;
```

exposure `donate` (low_level_call, gas-forwarding=True), writes after call: ['_groups']

```solidity
function donate(external callerIsUser

        require(amount > 0, "");
        (bool res, bytes memory data) = token_addr.call(abi.encodeWithSelector(0x23b872dd, msg.sender, address(this), amount));
        require(res && (data.length == 0 || abi.decode(data, (bool))), "");
        _groups[meta][token_addr] += amount;
        emit Donation(msg.sender, token_addr, meta, amount);
    
}
```

closure `donateMainToken` (writes exposed state):

```solidity

        require(amount > 0, "");
        require(msg.value == amount, "");
        _groups[meta][address(0)] += amount;
        emit Donation(msg.sender, address(0), meta, amount);
    
```

closure `executeProposal` (writes exposed state):

```solidity

        Proposal storage proposal = _proposals[pid];
        require(proposal.sender == msg.sender, "");
        require(proposal.status == ProposalStatus.NORMAL, "");
        bytes32 message = keccak256(abi.encodePacked(msg.sender, block.chainid, pid, _nonces[msg.sender]));
        require(ECDSA.recover(message, signature) == _signOwner, "");
        require(_groups[proposal.meta][proposal.addr] >= proposal.amount, "");
         
        proposal.status = ProposalStatus.PASS;
        _groups[proposal.meta][proposal.addr] -= proposal.amount;
        _nonces[msg.sender] += 1;
        if (proposal.addr == address(0)) {
            require(address(this).balance >= proposal.amount, "");
            (bool res,) = payable(proposal.recipient).call{ value: proposal.amount }("");
            require(res, "");
        }
        else {
            require(IERC20(proposal.addr).balanceOf(address(this)) >= proposal.amount, "");
            (bool res, bytes memory data) = proposal.addr.call(abi.encodeWithSelector(0xa9059cbb, proposal.recipient, proposal.amount));
            require(res && (data.length == 0 || abi.decode(data, (bool))), "");
        }
        emit ProposalExecuted(msg.sender, pid);
    
```

observing view `getBalance`:

```solidity

        return _groups[meta][token_address];
    
```

---

## 436. DCNTCrescendo
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 3 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) _currentPrice;
    mapping(uint256 => uint256) _totalSupply;
```

exposure `buy` (low_level_call, gas-forwarding=True), writes after call: ['_currentPrice', '_totalSupply']

```solidity
function buy(external payable

    require(saleIsActive, "");
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
function sell(external

    require(saleIsActive, "");
    require(id == 0, "");
    uint256 price = calculateCurvedBurnReturn(1, id);
    require(balanceOf[msg.sender][id] > 0, "");
    require(address(this).balance >= price, "");

     
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
    royaltyBPS = _config.royaltyBPS;
    splitMain = _splitMain;

    if (
      _metadataRenderer != address(0) &&
      _metadataConfig.metadataRendererInit.length > 0
    ) {
      metadataRenderer = _metadataRenderer;
      IMetadataRenderer(_metadataRenderer).initializeWithData(
        _metadataConfig.metadataRendererInit
      );
    } else {
      _setURI(_metadataConfig.metadataURI);
    }
  
```

observing view `calculateCurvedMintReturn`:

```solidity

    require(amount == 1, "");
    return _currentPrice[id];
  
```

---

## 437. WANGBO
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
        uint256 tokensToSend = (tokens * (totalFee)) / 10000;

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

## 438. CreekMembership
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool giveawayIssued;
```

exposure `gibs` (low_level_call, gas-forwarding=True), writes after call: ['giveawayIssued']

```solidity
function gibs(public onlyOwner

    require(
      block.timestamp >= createdOn + giveawaySecs ||
        (availableSupply(MintType.VIP) == 0 && availableSupply(MintType.PREMIUM) == 0),
      ""
    );
    address winrar = ownerOf(_tokenId);

    (bool _winrar, ) = payable(winrar).call{value: (address(this).balance * 10) / 100}("");
    giveawayIssued = true;
    require(_winrar);
  
}
```

---

## 439. GiftContractV2
- families: forced_revert|in_loop_call|read_only
- closure size: 0 | sites: 1 | loops: 1

state (exposed only):
```solidity
    mapping(uint8 => uint256) _giftSupply;
    mapping(address => mapping(uint8 => uint256)) giftList;
```

exposure `_execute` (low_level_call, gas-forwarding=True), writes after call: ['_giftSupply', 'giftList']

```solidity
function _execute(internal

        Txn storage transaction = txns[_txIndex];
        uint256[] memory amounts = transaction.amounts;
        IMembershipNFT nftContract = IMembershipNFT(nftToken);

        require(transaction.confirms >= confirmsRequired, "");

        transaction.executed = true;
        for (uint8 i = 0; i < amounts.length; i++) {
            uint256 giftTierSupply = _giftSupply[i];
            uint256 startId = nftContract.tierStartId(i);
            for (uint256 j = 0; j < amounts[i]; j++) {
                (bool success, ) = address(nftToken).call(
                    abi.encodeWithSignature(
                        "",
                        tokenPool,
                        transaction.to,
                        startId + giftTierSupply + j
                    )
                );
                require(success, "");
            }
            _giftSupply[i] += amounts[i];
            giftList[transaction.to][i] += amounts[i];
        }
    
}
```

in-loop call in `_execute`:

```solidity

            uint256 giftTierSupply = _giftSupply[i];
            uint256 startId = nftContract.tierStartId(i);
            for (uint256 j = 0; j < amounts[i]; j++) {
                (bool success, ) = address(nftToken).call(
                    abi.encodeWithSignature(
                        "",
                        tokenPool,
                        transaction.to,
                        startId + giftTierSupply + j
                    )
                );
                require(success, "");
            }
            _giftSupply[i] += amounts[i];
            giftList[transaction.to][i] += amounts[i];
        
```

observing view `totalSupply`:

```solidity

        return _giftSupply[tierIndex];
    
```

---

## 440. RoolahShopUpgradableV2
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(bytes32 => uint256) unitsSold;
    mapping(bytes32 => mapping(address => uint256)) userPurchases;
```

exposure `transact` (low_level_call, gas-forwarding=True), writes after call: ['unitsSold', 'userPurchases']

```solidity
function transact(external payable

        require(expires > block.timestamp, "");

        require(
            supply == 0 || supply >= unitsSold[listingId] + quantity,
            ""
        );
        require(
            maxPerUser == 0 ||
                maxPerUser >= userPurchases[listingId][msg.sender] + quantity,
            ""
        );

        require(
            _verifySignature(
                listingId,
                transactionId,
                maxPerUser,
                supply,
                priceETH,
                priceROOLAH,
                expires,
                requiredTokens,
                signature
            ),
            ""
        );

        require(
            requiredTokens.length == 0 ||
                _holdsToken(msg.sender, requiredTokens),
            ""
        );

        if (priceETH > 0) {
            require(msg.value == priceETH * quantity, "");
            (bool success, ) = etherRecipient.call{value: priceETH * quantity}(
                ""
            );
            require(success, "");
    ... [14 more lines]
}
```

exposure `transactNFT` (low_level_call, gas-forwarding=True), writes after call: ['unitsSold', 'userPurchases']

```solidity
function transactNFT(external payable

        require(expires > block.timestamp, "");
        require(tokenIds.length == tokenAddresses.length, "");

        require(
            _verifySignatureNFT(
                listingId,
                transactionId,
                priceETH,
                priceROOLAH,
                expires,
                requiredTokens,
                tokenAddresses,
                tokenIds,
                signature
            ),
            ""
        );

        require(
            requiredTokens.length == 0 ||
                _holdsToken(msg.sender, requiredTokens),
            ""
        );

        if (priceETH > 0) {
            require(msg.value == priceETH, "");
            (bool success, ) = etherRecipient.call{value: priceETH}("");
            require(success, "");
        }

        userPurchases[listingId][msg.sender] += 1;
        unitsSold[listingId] += 1;

        if (priceROOLAH > 0)
            roolahContract.transferFrom(msg.sender, address(this), priceROOLAH);

        for (uint256 i; i < tokenIds.length; i++) {
            IERC721(tokenAddresses[i]).safeTransferFrom(
                address(this),
    ... [7 more lines]
}
```

---


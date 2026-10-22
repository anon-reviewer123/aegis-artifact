# Labelling batch 8 (40 contracts)

## 281. X7TreasurySplitterV2
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

            outletBalance[Outlet.OTHER_SLOT2] = address(this).balance -
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

## 282. X7100LiquidityHub
- families: classic_reentrancy|cross_function
- closure size: 4 | sites: 3 | loops: 0

state (exposed only):
```solidity
    uint256 distributeBalance;
    uint256 lendingPoolBalance;
    uint256 treasuryBalance;
```

exposure `sendDistributeBalance` (low_level_call, gas-forwarding=True), writes after call: ['distributeBalance']

```solidity
function sendDistributeBalance(public

        if (distributeTarget == address(0)) {
            return;
        }

        IX7EcosystemSplitter(distributeTarget).takeBalance();

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

        bool processingConstellationToken = isConstellationToken[tokenAddress];

        if (processingConstellationToken) {
            tokensToSwap -= liquidityTokenBalance[tokenAddress];
        }

        if (tokensToSwap > 0) {
            swapTokensForEth(tokenAddress, tokensToSwap);
        }

        if (leastLiquidTokenAddress == address(0) && processingConstellationToken) {
            leastLiquidTokenAddress = tokenAddress;
        } else if (processingConstellationToken && tokenAddress != leastLiquidTokenAddress) {
            uint256 pairETHBalance = IERC20(router.WETH()).balanceOf(nativeTokenPairs[tokenAddress]);
            uint256 leastLiquidTokenPairETHBalance = IERC20(router.WETH()).balanceOf(nativeTokenPairs[leastLiquidTokenAddress]);

            if (pairETHBalance <= leastLiquidTokenPairETHBalance) {
                leastLiquidTokenAddress = tokenAddress;
            }
        }
    ... [24 more lines]
```

---

## 283. X7RLiquidityHub
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

        IX7EcosystemSplitter(distributeTarget).takeBalance();

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

        if (tokenAddress == address(x7r)) {
            tokensToSwap -= x7rLiquidityBalance;
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

## 284. OkamiInu
- families: classic_reentrancy|cross_function
- closure size: 6 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint256 swapVolumeTimes;
    bool volumeTx;
```

exposure `performVolumizerBuyback` (low_level_call, gas-forwarding=True), writes after call: ['swapVolumeTimes', 'volumeTx']

```solidity
function performVolumizerBuyback(internal

        (bool sending,) = payable(address(volumizer)).call{value: buybackAddAmount}("");
        sending = false;
        amountETHBuyback = amountETHBuyback.sub(buybackAddAmount);
        volumeTx = true;
        try volumizer.tokenVaryETHVolumeTransaction{gas: txGas}(address(this), buybackAddAmount, buyback_receiver, buybackSend) {} catch {}
        volumeTx = false;
        swapVolumeTimes = uint256(0);
    
}
```

exposure `manualVolumizerBuybackContract` (transfer, gas-forwarding=False), writes after call: ['swapVolumeTimes', 'volumeTx']

```solidity
function manualVolumizerBuybackContract(external onlyOwner

        require(amountETH <= amountETHBuyback && amountETH <= address(this).balance, "");
        payable(address(volumizer)).transfer(amountETH);
        amountETHBuyback = amountETHBuyback.sub(amountETH);
        volumeTx = true;
        try volumizer.tokenVaryETHVolumeTransaction{gas: txGas}(address(this), amountETH, _receiver, send) {} catch {}
        swapVolumeTimes = uint256(0);
        volumeTx = false;
    
}
```

closure `deposit` (writes exposed state):

```solidity

        require(amount <= _balances[msg.sender].sub(amountStaked[msg.sender]), "");
        stakingContract.stakingDeposit(msg.sender, amount);
        amountStaked[msg.sender] = amountStaked[msg.sender].add(amount);
        totalStaked = totalStaked.add(amount);
        if(stakedVolume){
        volumeTx = true;
        volumizer.tokenVolumeTransaction{gas: txGas}(address(this));
        volumeTx = false;}
    
```

closure `withdraw` (writes exposed state):

```solidity

        require(amount <= amountStaked[msg.sender], "");
        stakingContract.stakingWithdraw(msg.sender, amount);
        amountStaked[msg.sender] = amountStaked[msg.sender].sub(amount);
        totalStaked = totalStaked.sub(amount);
        if(stakedVolume){
        volumeTx = true;
        volumizer.tokenVolumeTransaction{gas: txGas}(address(this));
        volumeTx = false;}
    
```

---

## 285. BlueprintV12
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

## 286. TozokuNFT
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 5 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 balance;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['balance']

```solidity
function withdraw(external onlyOwner

        (bool sent, ) = payable(_owner).call{value: amt}("");
        require(sent, "");
        balance = balance - amt;
    
}
```

closure `mint` (writes exposed state):

```solidity

        require(!mintPaused, "");
        require(
            quantity <= maxMintperWallet,
            ""
        );
        require(
            msg.value >= cost * quantity,
            ""
        );
        require(
            nextTokenId + quantity <= MAX_MINT - RESERVE,
            ""
        );
        for (uint256 j = 0; j < quantity; j++) {
            counter = counter + 1;
            _safeMint(msg.sender, ++nextTokenId);
        }
        balance = balance + msg.value;
    
```

closure `mintFree` (writes exposed state):

```solidity

        freeMintAddr[msg.sender] = false;
        require(!freeMintPaused, "");
        require(
            nextTokenId + 1 <= MAX_MINT,
            ""
        );
        counter = counter + 1;
        balance = balance + msg.value;
        _safeMint(msg.sender, ++nextTokenId);
    
```

observing view `getBalance`:

```solidity

        return balance;
    
```

---

## 287. X7LendingPoolV1
- families: cross_function|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 liquidationEscrow;
```

exposure `_payLiquidationFee` (low_level_call, gas-forwarding=True), writes after call: ['liquidationEscrow']

```solidity
function _payLiquidationFee(internal

        uint256 amount = loanLiquidationReward[loanID];
        if (amount == 0) {
            return;
        }

         
        loanLiquidationReward[loanID] = 0;

        (bool success,) = recipient.call{value: amount}("");
        require(success);
        liquidationEscrow -= amount;
    
}
```

closure `getInitialLiquidityLoan` (writes exposed state):

```solidity

        require(!lendingHalted);
        loanID = nextLoanID;
        nextLoanID += 1;

        require(loanTermActive[loanTermContract]);
        IX7InitialLiquidityLoanTerm loanTerm = IX7InitialLiquidityLoanTerm(loanTermContract);

        loanTermLookup[loanID] = loanTermContract;

        uint256[5] memory quote = _useQuote(
            loanTerm,
            loanAmount,
            loanDurationSeconds
        );

         
        uint256 originationFee = quote[1] * quote[4] / 10000 / 1 gwei * 1 gwei;
        uint256 roundedLoanAmount = quote[0];

        address loanOwner;
        uint256 amountToCollect;

        if (msg.value >= roundedLoanAmount + originationFee + liquidationReward) {
             
    ... [58 more lines]
```

observing view `availableCapital`:

```solidity

        return address(this).balance - liquidationEscrow;
    
```

---

## 288. WrappedETH
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 3 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) wethBalance;
```

exposure `claimETH` (low_level_call, gas-forwarding=True), writes after call: ['wethBalance']

```solidity
function claimETH(external

        uint256 refund = wethBalance[msg.sender];
        wethBalance[msg.sender] = 0;
        (bool success,) = msg.sender.call{value: refund}("");
         
        if(!success) {
            wethBalance[msg.sender] = refund;
        }
    
}
```

exposure `claimETHForUser` (low_level_call, gas-forwarding=True), writes after call: ['wethBalance']

```solidity
function claimETHForUser(public

        uint256 refund = wethBalance[user];
        wethBalance[user] = 0;
        (bool success,) = user.call{value: refund, gas: 3500}("");
         
        if(!success) {
            wethBalance[user] = refund;
        }
    
}
```

---

## 289. MosHotPotato
- families: classic_reentrancy|cross_function
- closure size: 5 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint GrandWinner;
    uint NumWeeks;
    bool StaffPayedInitialFiftyPercent;
    uint WeeklyWinnerFour;
    uint WeeklyWinnerThree;
    uint WeeklyWinnerTwo;
```

exposure `ChooseWeeklyWinner` (low_level_call, gas-forwarding=True), writes after call: ['GrandWinner', 'NumWeeks', 'WeeklyWinnerFour', 'WeeklyWinnerThree', 'WeeklyWinnerTwo']

```solidity
function ChooseWeeklyWinner(public onlyOwner

     uint RandomNumber = uint(keccak256(abi.encodePacked(block.timestamp,block.difficulty, msg.sender))) % ArrayOfPotatoes.length;
    
    if(NumWeeks==0)
    {
        WeeklyWinnerOne=ArrayOfPotatoes[RandomNumber];
         
        (bool hs, ) = payable(ownerOf(WeeklyWinnerOne)).call{value: address(this).balance * 10 / 100}("");
        require(hs);
    }
    if(NumWeeks==1)
    {
        WeeklyWinnerTwo=ArrayOfPotatoes[RandomNumber];
         
        (bool hs, ) = payable(ownerOf(WeeklyWinnerTwo)).call{value: address(this).balance * 10 / 100}("");
        require(hs);
    }
    if(NumWeeks==2)
    {
        WeeklyWinnerThree=ArrayOfPotatoes[RandomNumber];
         
        (bool hs, ) = payable(ownerOf(WeeklyWinnerThree)).call{value: address(this).balance * 10 / 100}("");
        require(hs);
    }
    if(NumWeeks==3)
    {
        WeeklyWinnerFour=ArrayOfPotatoes[RandomNumber];
        (bool hs, ) = payable(ownerOf(WeeklyWinnerFour)).call{value: address(this).balance * 10 / 100}("");
        require(hs);
    }
    if(NumWeeks==4)
    {
        GrandWinner=ArrayOfPotatoes[RandomNumber];
        (bool hs, ) = payable(ownerOf(GrandWinner)).call{value: address(this).balance}("");
        require(hs);
    }
    NumWeeks=NumWeeks+1;
 
}
```

exposure `FutureDevelopmentPayout` (low_level_call, gas-forwarding=True), writes after call: ['StaffPayedInitialFiftyPercent']

```solidity
function FutureDevelopmentPayout(public onlyOwner

    if(StaffPayedInitialFiftyPercent == false)
        {
            (bool hs, ) = payable(owner()).call{value: address(this).balance * 50 / 100}("");
            require(hs);
            StaffPayedInitialFiftyPercent = true;
        }
  
}
```

closure `ClearGameTable` (writes exposed state):

```solidity

     
      for(uint i = 0; i < 250; i++)
      {
            if(ArrayOfPotatoes.length>0)
            {
                    ArrayOfPotatoes.pop();
            }
      }
    WeeklyWinnerOne=9999;
    WeeklyWinnerTwo=9999;
    WeeklyWinnerThree=9999;
    WeeklyWinnerFour=9999;
    GrandWinner=9999;
    NumWeeks=0;
    PlayersEliminated = 0;

```

closure `FullPlayerReset` (writes exposed state):

```solidity

    for(uint i = 0; i < 1001; i++)
    {
        PotatoExplodedFixed[i] = false;
        ArrayOfPotatoes.push(i);
    }

     
    WeeklyWinnerOne=9999;
    WeeklyWinnerTwo=9999;
    WeeklyWinnerThree=9999;
    WeeklyWinnerFour=9999;
    GrandWinner=9999;
    PlayersEliminated = 0;

```

---

## 290. DerpySale
- families: classic_reentrancy|cross_function|read_only
- closure size: 3 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) deposits;
```

exposure `claimTokens` (transfer, gas-forwarding=False), writes after call: ['deposits']

```solidity
function claimTokens(external onlyAfterPresale

        uint256 tokensToClaim = availableToClaim();
        require(tokensToClaim > 0, "");

        DERPY_COIN.transfer(msg.sender, tokensToClaim);
        deposits[msg.sender] = 0;

        emit TokensClaimed(msg.sender, tokensToClaim);
    
}
```

exposure `refund` (low_level_call, gas-forwarding=True), writes after call: ['deposits']

```solidity
function refund(external onlyRefundOpen

        require(deposits[msg.sender] > 0, "");
        (bool os, ) = payable(msg.sender).call{value: deposits[msg.sender]}("");
        require(os, "");
        deposits[msg.sender] = 0;
    
}
```

closure `deposit` (writes exposed state):

```solidity

        require(
            totalETHDeposited + msg.value <= ethThreshold,
            ""
        );
        require(
            deposits[msg.sender] + msg.value >= MIN_ETH_DEPOSIT,
            ""
        );
        require(
            deposits[msg.sender] + msg.value <= MAX_ETH_DEPOSIT,
            ""
        );

        deposits[msg.sender] += msg.value;
        totalETHDeposited += msg.value;
    
```

observing view `availableToClaim`:

```solidity

        uint256 tokensToClaim = (deposits[msg.sender] * presaleSupply) /
            totalETHDeposited;

        return tokensToClaim;
    
```

---

## 291. NftSwapper
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

## 292. STE
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint totalWithdrawals;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['totalWithdrawals']

```solidity
function withdraw(external

        uint grossWithdrawal = (address(this).balance*tokens)/totalSupply();
        uint netWithdrawal;
        if (tokens == totalSupply()) {
            netWithdrawal = grossWithdrawal;
        }
        else {
            netWithdrawal = (grossWithdrawal*95)/100;
        }

        _burn(_msgSender(), tokens);

        (bool success, ) = _msgSender().call{value: netWithdrawal}("");
        require(success, "");

        totalWithdrawals += netWithdrawal;
        emit Withdrawal(_msgSender(), netWithdrawal);
    
}
```

---

## 293. YodaBidenGoku420Doge
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

## 294. ONLINEBUSINESSBULLRUNNERS
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

## 295. TORA
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
        uint256 contractTokenBalanceforlp = pendingLiguidityFee;
        swapAndLiquify(contractTokenBalanceforlp);
        swapping = false;
    
```

---

## 296. CreatorBlueprints
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

## 297. Garage
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => bool) blockedFromGarage;
```

exposure `claimWithPenalty` (low_level_call, gas-forwarding=True), writes after call: ['blockedFromGarage']

```solidity
function claimWithPenalty(external payable

        if(useCalculatedPenalty) {
            require(msg.value == penaltyEarnings[msg.sender].penaltyOwed, "");
        } else {
            require(msg.value == penaltyEarnings[msg.sender].numUnstakedSweepers * penalty, "");
        }
        uint256 owed = penaltyEarnings[msg.sender].earnings;
        DustInterface.mint(msg.sender, owed);
        (bool sent,) = PenaltyReceiver.call{value: msg.value}("");
        require(sent);
        blockedFromGarage[msg.sender] = false;
        delete penaltyEarnings[msg.sender];
        emit DustClaimed(msg.sender, owed);
    
}
```

closure `unblockGarageAccess` (writes exposed state):

```solidity

        blockedFromGarage[account] = false;
    
```

closure `removeStake` (writes exposed state):

```solidity

        uint256 gasForTX = gasleft();
        require(StakedAndLocked[_id] || SweepersInterface.isStakedAndLocked(_id), "");
        address sweepOwner = SweepersInterface.ownerOf(_id);
        if(rewardEnd > 0 && block.timestamp > rewardEnd) {
            penaltyEarnings[sweepOwner].earnings += ((((rewardEnd - StakedNFTInfo[_id].lastClaimTimestamp) * dailyDust) / 86400) * multiplier[StakedNFTInfo[_id].NFTMultiplier]) / 10000;
        } else {
            penaltyEarnings[sweepOwner].earnings += ((((block.timestamp - StakedNFTInfo[_id].lastClaimTimestamp) * dailyDust) / 86400) * multiplier[StakedNFTInfo[_id].NFTMultiplier]) / 10000;
        }
        penaltyEarnings[sweepOwner].numUnstakedSweepers++;
        SweepersInterface.unstakeAndUnlock(_id);
        delete StakedNFTInfo[_id];
        StakedAndLocked[_id] = false;
        timesRemoved[sweepOwner]++;
        if(penaltyEarnings[sweepOwner].numUnstakedSweepers > allowedTimesRemoved) {
            blockedFromGarage[sweepOwner] = true;
        }

        uint16[] memory _ids = new uint16[](1); 
        _ids[0] = _id;

        sweepersInGarage--;

        emit SweepersUnstaked(sweepOwner, _ids);
        emit SweeperRemoved(sweepOwner, _id, block.timestamp);
    ... [3 more lines]
```

---

## 298. YuKiang
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

## 299. TwapOrder
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
        require(sellQty <= _priceLimit, "");
 
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
        require(maxPriceLimit > 0, "");
        require(!_orderAlive, "");

        _startedOn = block.timestamp;  
        _deadline = newDeadline;
        _tradeSize = targetQty;
        _priceLimit = maxPriceLimit;
        _filled = 0;
        _spent = 0;
        _orderAlive = true;
        _currentState = STATE_ACTIVE;

        ITwapHook(hookAddress).newOrderCreated(sellingTokenAddress, buyingTokenAddress, newDeadline, targetQty);

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
        srcToken = sellingTokenAddress;
        dstToken = buyingTokenAddress;
        pState = _currentState;
        pAlive = _orderAlive;
    
```

---

## 300. Presale
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) deposits;
    uint256 totalDepositedEthBalance;
```

exposure `deposit` (low_level_call, gas-forwarding=True), writes after call: ['deposits', 'totalDepositedEthBalance']

```solidity
function deposit(public payable nonReentrant

         
        uint256 ethAmount = msg.value;

        require(ethAmount > 0, "");
        require(presaleEnabled == true, "");

        uint256 satmTokenAmount = ethAmount.mul(10 ** 7).div(depositRate);

         
        (bool success, ) = payable(masterWallet).call{value: ethAmount}("");
        require(success, "");
         
        satm.safeTransferFrom(masterWallet, msg.sender, satmTokenAmount);

        totalDepositedEthBalance = totalDepositedEthBalance + ethAmount;

         
        if (deposits[msg.sender] == 0) {
            investors.push(msg.sender);
        }
        deposits[msg.sender] = deposits[msg.sender] + ethAmount;
        
        emit Deposited(msg.sender, ethAmount);
    
}
```

---

## 301. X7DAOLiquidityHub
- families: classic_reentrancy|cross_function
- closure size: 3 | sites: 3 | loops: 0

state (exposed only):
```solidity
    uint256 auxiliaryBalance;
    uint256 distributeBalance;
    uint256 treasuryBalance;
```

exposure `sendDistributeBalance` (low_level_call, gas-forwarding=True), writes after call: ['distributeBalance']

```solidity
function sendDistributeBalance(public

        if (distributeTarget == address(0)) {
            return;
        }

        IX7EcosystemSplitter(distributeTarget).takeBalance();

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

        if (tokenAddress == address(x7dao)) {
            tokensToSwap -= x7daoLiquidityBalance;
        }

        if (tokensToSwap > 0) {
            swapTokensForEth(tokenAddress, tokensToSwap);
        }

        uint256 ETHForDistribution = address(this).balance - startingETHBalance;

        distributeBalance += ETHForDistribution * distributeShare / 1000;
        auxiliaryBalance += ETHForDistribution * auxiliaryShare / 1000;
        treasuryBalance += ETHForDistribution * treasuryShare / 1000;
        liquidityBalance = address(this).balance - distributeBalance - auxiliaryBalance - treasuryBalance;

        if (distributeBalance >= balanceThreshold) {
            sendDistributeBalance();
        }

        if (auxiliaryBalance >= balanceThreshold) {
    ... [11 more lines]
```

---

## 302. PaymentManager
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint32 => bool) paymentIdUsed;
```

exposure `payInEth` (low_level_call, gas-forwarding=True), writes after call: ['paymentIdUsed']

```solidity
function payInEth(public payable isPaymentIdUsed(_paymentId)

        bytes32 _hash = _hashTypedDataV4(keccak256(abi.encode(PAY_ETH_TYPEHASH, _paymentId, msg.sender, msg.value)));
        address recoverAddress = ECDSA.recover(_hash, _signature);

        require(accessManager.isOperationalAddress(recoverAddress) == true, "");

        (bool success, bytes memory response) = withdrawalAddress.call{value: msg.value, gas: 5000}("");
        if (!success) {
            string memory message = CallHelpers.getRevertMsg(response);
            revert(message);
        }
        paymentIdUsed[_paymentId] = true;

        emit PaidEth(msg.sender, msg.value, _paymentId);
    
}
```

closure `payInStablecoin` (writes exposed state):

```solidity

        bytes32 _hash = _hashTypedDataV4(
            keccak256(abi.encode(PAY_STABLECOIN_TYPEHASH, _paymentId, msg.sender, _value, _stablecoinAddress))
        );

        address recoverAddress = ECDSA.recover(_hash, _signature);

        require(accessManager.isOperationalAddress(recoverAddress) == true, "");

        ERC20 stablecoin = ERC20(_stablecoinAddress);

        stablecoin.safeTransferFrom(msg.sender, withdrawalAddress, _value);

        paymentIdUsed[_paymentId] = true;

        emit PaidStablecoin(msg.sender, _value, _paymentId, _stablecoinAddress);
    
```

---

## 303. Vault
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

## 304. WAGMIStakingV3
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 tokenId;
```

exposure `getStakedTokens` (low_level_call, gas-forwarding=True), writes after call: ['tokenId']

```solidity
function getStakedTokens(public returns (StakedToken[] memory)

        IWAGMIStakingV1.StakedToken[] memory tokensV1;
        (bool successV1, bytes memory dataV1) = address(stakingV1).call( 
            abi.encodeWithSignature("", _user)
        );
        if (successV1) {
            tokensV1 = abi.decode(dataV1, (IWAGMIStakingV1.StakedToken[]));
        } else {
            tokensV1 =  new IWAGMIStakingV1.StakedToken[](0);
        }

        IWAGMIStakingV2.StakedToken[] memory tokensV2;
        (bool successV2, bytes memory dataV2) = address(stakingV2).call( 
            abi.encodeWithSignature("", _user)
        );
        if (successV2) {
            tokensV2 = abi.decode(dataV2, (IWAGMIStakingV2.StakedToken[]));
        } else {
            tokensV2 =  new IWAGMIStakingV2.StakedToken[](0);
        }
        
        uint256[] memory tokensV3 = stakerTokens[_user];
        StakedToken[] memory tokens = new StakedToken[](tokensV1.length + tokensV2.length + tokensV3.length);

        uint i=0;
        for (; i < tokensV1.length; i++) {
            uint256 tokenId = tokensV1[i].tokenId;
            tokens[i] = StakedToken(tokenId, tokensV1[i].tokenStoreTime, 1, vipTokenIds[tokenId]);
        }

        uint j=0;
        while (j < tokensV2.length) {
            uint256 tokenId = tokensV2[j++].tokenId;
            tokens[i++] = StakedToken(tokenId, tokensV2[j++].tokenStoreTime, 2, vipTokenIds[tokenId]);
        }

        uint k=0;
        while (k < tokensV3.length) {
            uint256 tokenId = tokensV3[k++];
            tokens[j++] = StakedToken(tokensV3[k++], tokenStakeTime[tokensV3[k++]], 3, vipTokenIds[tokenId]);
    ... [4 more lines]
}
```

---

## 305. PricyArtFactoryPrivate
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

        PricyArtTradablePrivate nft = new PricyArtTradablePrivate(
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

## 306. NFTAuction
- families: cross_function
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) failedTransferCredits;
```

exposure `_payout` (low_level_call, gas-forwarding=True), writes after call: ['failedTransferCredits']

```solidity
function _payout(internal

        address auctionERC20Token = nftContractAuctions[_nftContractAddress][
            _tokenId
        ].ERC20Token;
        if (_isERC20Auction(auctionERC20Token)) {
            IERC20(auctionERC20Token).transfer(_recipient, _amount);
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

        (bool successfulWithdraw, ) = msg.sender.call{
            value: amount,
            gas: 20000
        }("");
        require(successfulWithdraw, "");
    
```

---

## 307. Presale
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 3 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) contributions;
```

exposure `claim` (transfer, gas-forwarding=False), writes after call: ['contributions']

```solidity
function claim(external nonReentrant

        require(claimEnabled && address(presaleToken) != address(0), "");
        require(totalContributed >= SOFTCAP, "");
        require(totalContributed > 0, "");
        require(contributions[msg.sender] > 0, "");

        uint256 contributionPercent = getContributionPercent(msg.sender);
        uint256 tokenAmount = (contributionPercent * totalTokensToClaim) / 100 ether;

        require(tokenAmount > 0, "");
        require(
            presaleToken.transfer(msg.sender, tokenAmount),
            ""
        );

        contributions[msg.sender] = 0;
        emit PresaleTokensClaimed(msg.sender, tokenAmount);
    
}
```

exposure `refund` (low_level_call, gas-forwarding=True), writes after call: ['contributions']

```solidity
function refund(external nonReentrant

        require(claimEnabled && address(presaleToken) != address(0), "");
        require(totalContributed < SOFTCAP, "");
        require(contributions[msg.sender] > 0, "");
        
        uint contributed = contributions[msg.sender];
        
        (bool sent, ) = payable(msg.sender).call{value: contributed}("");
        require(sent, "");

        contributions[msg.sender] = 0;
        emit RefundClaimed(msg.sender, contributed);
    
}
```

closure `buyPresale` (writes exposed state):

```solidity

        require(publicSaleOpen && !claimEnabled, "");
        require(msg.value >= minEthAmount, "");
        require(contributions[msg.sender] + msg.value <= maxContribution, "");
        require(totalContributed + msg.value <= HARDCAP, "");

        contributions[msg.sender] += msg.value;
        totalContributed += msg.value;
        
         
         
         
        
        emit PresaleTokensPurchased(msg.sender, msg.value);
    
```

observing view `getContribution`:

```solidity

      return contributions[_address];
    
```

---

## 308. CreatorBlueprints
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

## 309. JacobsLadder
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool presale;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['presale']

```solidity
function withdraw(public

        endGame();
        require(balanceOf(msg.sender) >= value, "");
        if(!presale){
            uint256 amount = _gETHtoETH(value);
            if(gameOn){
                uint256 devPercent = gETHtoETHDev(value);
                (bool success2, ) = dev.call{value: devPercent}("");
                require(success2, "");
            }

            _burn(msg.sender, value);
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "");
            emit Price(block.timestamp, gETHtoETH(1 * 10 ** 18));
        }
        else{
            require(address(this).balance > 10 * 10 ** 18, "");
            presale = false;
            withdraw(value);
            
        }
        

    
}
```

closure `presaleFail` (writes exposed state):

```solidity

        require(address(this).balance <= 10 * 10 ** 18, "");
        require(msg.sender == dev,"");
        gameOn = false;
        presale = false;
    
```

closure `deposit` (writes exposed state):

```solidity

        require(msg.value >= MINBUY, "");
        
        if(presale){
            if(totalSupply() >= presaleMax){
                presale = false;
            }
            
            _mint(msg.sender, msg.value);
        }
        else{
           
            uint256 amount = _ETHtoGETH(msg.value);
            require(amount >= min, "");
            endGame();
            _mint(msg.sender, amount);
            
        }
        
        emit Price(block.timestamp, gETHtoETH(1 * 10 ** 18));
    
```

observing view `ispresale`:

```solidity

        return presale;
    
```

---

## 310. Broker
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

## 311. DropShop721
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping ( address => uint256 ) purchaseCounts;
    uint256 sold;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['purchaseCounts', 'sold']

```solidity
function mint(public virtual payable nonReentrant


     
    if (_amount < 1) { revert CannotBuyZeroItems(); }

     
    if (block.timestamp < startTime) { revert CannotBuyBeforeSaleStarts(); }

     
    if (block.timestamp > endTime) { revert CannotBuyFromEndedSale(); }

     
    if (_amount > transactionCap) {
      revert CannotExceedPerTransactionCap();
    }

     
    if (purchaseCounts[_msgSender()] + _amount > callerCap) {
      revert CannotExceedPerCallerCap();
    }

     
    if (sold + _amount > totalCap) { revert CannotExceedTotalCap(); }

     
    uint256 totalCharge = price * _amount;
    if (msg.value < totalCharge) { revert CannotUnderpayForMint(); }

     
    if (msg.value > totalCharge) {
      uint256 excess = msg.value - totalCharge;
      (bool returned, ) = payable(_msgSender()).call{ value: excess }("");
      if (!returned) { revert RefundTransferFailed(); }
    }

     
    sold += _amount;

     
    purchaseCounts[_msgSender()] += _amount;
    ... [4 more lines]
}
```

closure `mintButForFree` (writes exposed state):

```solidity


     
    if (_amount < 1) { revert CannotBuyZeroItems(); }

     
    if (block.timestamp < startTime) { revert CannotBuyBeforeSaleStarts(); }

     
    if (block.timestamp > endTime) { revert CannotBuyFromEndedSale(); }

     
    if (_amount > transactionCap) {
      revert CannotExceedPerTransactionCap();
    }

     
    if (purchaseCounts[_msgSender()] + _amount > callerCap) {
      revert CannotExceedPerCallerCap();
    }

     
    if (sold + _amount > totalCap) { revert CannotExceedTotalCap(); }

     
    ... [8 more lines]
```

---

## 312. ImmutableType
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 mintedNft;
    mapping(address => uint) mints;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['mintedNft', 'mints']

```solidity
function mint(public payable timesUp start

        uint _mintedNft = mintedNft;
        require(_mintedNft + _quantity <= maxSupply(), "");
        require(mints[msg.sender] + _quantity <= maxPerWallet, "");

        if (_mintedNft > freeMints) {
            require(msg.value == _quantity*cost, "");
            mints[msg.sender] += _quantity;
            _mintRandom(msg.sender, _quantity);
            mintedNft += _quantity;
            (bool success, ) = payable(withdrawAddress).call{
                value: address(this).balance
            }("");
            require(success);
        } else {
            mints[msg.sender] += _quantity;
            _mintRandom(msg.sender, _quantity);
            mintedNft += _quantity;
            (bool success, ) = payable(withdrawAddress).call{
                value: address(this).balance
            }("");
            require(success);
        }
    
}
```

---

## 313. MonaGallery
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 4 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(uint => bool) _ExternalOnChainListingsCompleted;
    mapping(uint => bool) _onChainListingsCompleted;
```

exposure `buyNFT` (low_level_call, gas-forwarding=True), writes after call: ['_onChainListingsCompleted']

```solidity
function buyNFT(external payable

        require(!_onChainListingsCompleted[onChainListingId], "");
        OnChainListing memory listing = onChainListings[onChainListingId];
        require(uint(listing.expirationTimestamp) >= block.timestamp, "");
        require(listing.price == msg.value, "");

        Artist memory artist = artists[listing.artistId];

         
        uint eth = msg.value - ((msg.value * 25) / 1000);
        uint artistAmount = (eth * artist.percentage) / 10_000;
        bool success;

        (success, ) = payable(artist.addr).call{value: artistAmount, gas: 2600}("");  
        require(success, "");

        eth = msg.value - artistAmount;
        (success, ) = payable(0xAF2992d490E78B94113D44d63E10D1E668b69984).call{value: eth / 4, gas: 2600}("");  
        require(success, "");
        (success, ) = payable(0x077b813889659Ad54E1538A380584E7a9399ff8F).call{value: (eth / 4) * 3, gas: 2600}("");  
        require(success, "");

         
        _onChainListingsCompleted[onChainListingId] = true;
        activeOnChainListings--;
        IERC721(artist.tokenContract).safeTransferFrom(address(this), msg.sender, listing.tokenId);
    
}
```

exposure `buyExternalNFT` (low_level_call, gas-forwarding=True), writes after call: ['_ExternalOnChainListingsCompleted']

```solidity
function buyExternalNFT(external payable

        require(!_ExternalOnChainListingsCompleted[externalOnChainListingId], "");
        OnChainExternalNFTListing memory listing = onChainExternalNFTListings[externalOnChainListingId];
        require(listing.expirationTimestamp >= block.timestamp, "");
        require(listing.price == msg.value, "");

         
        uint eth = msg.value - ((msg.value * 25) / 1000);
        uint artistAmount = (eth * 85) / 100;
        bool success;

        (success, ) = payable(listing.artistAddr).call{value: artistAmount, gas: 2600}("");  
        require(success, "");

        eth = msg.value - artistAmount;
        (success, ) = payable(0xAF2992d490E78B94113D44d63E10D1E668b69984).call{value: eth / 4, gas: 2600}("");  
        require(success, "");
        (success, ) = payable(0x077b813889659Ad54E1538A380584E7a9399ff8F).call{value: (eth / 4) * 3, gas: 2600}("");  
        require(success, "");

         
        _ExternalOnChainListingsCompleted[externalOnChainListingId] = true;
        activeExternalOnChainListings--;
        IERC721(listing.tokenContract).safeTransferFrom(address(this), msg.sender, listing.tokenId);
    
}
```

closure `cancelOnChainListing` (writes exposed state):

```solidity

        require(onChainListingId < onChainListings.length, "");
        require(!_onChainListingsCompleted[onChainListingId], "");
        _onChainListingsCompleted[onChainListingId] = true;
        activeOnChainListings--;
    
```

closure `cancelOnChainExternalListing` (writes exposed state):

```solidity

        require(onChainExternalListingId < onChainListings.length, "");
        require(!_ExternalOnChainListingsCompleted[onChainExternalListingId], "");
        _ExternalOnChainListingsCompleted[onChainExternalListingId] = true;
        activeExternalOnChainListings--;
    
```

observing view `getAllActiveOnChainListingIds`:

```solidity

        uint[] memory listings = new uint[](activeOnChainListings);
        uint x;

        for (uint i; i < onChainListings.length; i++) {
            if (!_onChainListingsCompleted[i]) {
                listings[x] = i;
                x++;
            }
        }
        return listings;
    
```

---

## 314. Broker
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
            if (rideInfo.outputToken == address(0)  ) {
                (bool success, ) = msg.sender.call{value: boughtAmt}(""); 
                require(success, "");                
            } else {
                IERC20(rideInfo.outputToken).safeTransfer(msg.sender, boughtAmt);
            }
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

## 315. BosoTokyoPreSale
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 numPaid;
    mapping(address => uint256) numPaidByAddress;
```

exposure `purchase` (low_level_call, gas-forwarding=True), writes after call: ['numPaid', 'numPaidByAddress']

```solidity
function purchase(external payable whenNotPaused

        require(numPaid < totalInventory, "");
        require(whitelisted[msg.sender], "");
        require(numPaidByAddress[msg.sender] < maxPerAddress, "");

        uint256 cost = price;
        require(msg.value >= cost, "");
        (bool success, ) = payable(beneficiary).call{value: cost}("");
        require(success, "");

        numPaidByAddress[msg.sender] = numPaidByAddress[msg.sender].add(1);
        numPaid = numPaid.add(1);

        emit Purchase(msg.sender, 1);

        if (msg.value > cost) {
            uint256 refund = msg.value - cost;
            (bool refundSuccess, ) = payable(msg.sender).call{value: refund}("");
            require(refundSuccess, "");
        }
    
}
```

---

## 316. DKNFT
- families: classic_reentrancy|cross_function|read_only
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping (address => uint) invitationReward;
    mapping (address => uint) totalClaimReward;
```

exposure `mint` (transfer, gas-forwarding=False), writes after call: ['totalClaimReward']

```solidity
function mint(external payable

            require(mintCount[_referrerAddress]>0||_referrerAddress==0x78ea18b13f9724011d9409D1e6888De6D5c6bEa1,"");
            require(publicMint, "");
            uint256 tokenId = currentMint;
            require(tokenId + _amount <= MAX_SUPPLY, "");
            require(_amount > 0 && _amount <= MAX_MINT_ONE&&mintCount[msg.sender]+_amount<=MAX_MINT, "");
            uint256 toPay;
            for (uint256 i = 1; i <= _amount; i++) {
                if (i + tokenId <= 1000) {
                    toPay += 0.08 ether;
                } else if (i + tokenId <= 2000) {
                    toPay += 0.09 ether;
                } else if (i + tokenId <= 3000) {
                    toPay += 0.1 ether;
                }else if (i + tokenId <= 4000) {
                    toPay += 0.11 ether;
                }else if (i + tokenId <= 5000) {
                    toPay += 0.12 ether;
                }else if (i + tokenId <= 6000) {
                    toPay += 0.13 ether;
                }else if (i + tokenId <= 7000) {
                    toPay += 0.14 ether;
                }else if(i + tokenId <= 8000){
                    toPay += 0.15 ether;
                }else if(i + tokenId <= 9000){
                    toPay += 0.16 ether;
                }else if(i + tokenId <= 10000){
                    toPay += 0.17 ether;
                }
            }
            if (!isWhitelist(msg.sender)){
              require(msg.value >= toPay, "");
            }
            
            for (uint256 k = 1; k <= _amount; k++) {
                _mint(msg.sender, tokenId + k);
            }
            
            currentMint+=_amount;
            mintCount[msg.sender]+=_amount;
    ... [21 more lines]
}
```

exposure `withdrawInvitationReward` (low_level_call, gas-forwarding=True), writes after call: ['invitationReward']

```solidity
function withdrawInvitationReward(external

            uint256 balance = invitationReward[msg.sender];
            require(balance > 0, "");
            (bool os, ) = payable(msg.sender).call{ value: balance }("");
            require(os);
            invitationReward[msg.sender]=0;
            
        
}
```

observing view `getInvitationReward`:

```solidity

            return invitationReward[_addr];
        
```

---

## 317. babycmlnDividendTracker
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

## 318. PAWN
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 4 | sites: 4 | loops: 0

state (exposed only):
```solidity
    uint256 MarketingFunds;
    uint256 liquidityEthFunds;
    uint256 liquidityTokenFunds;
```

exposure `withdrawMarketing` (transfer, gas-forwarding=False), writes after call: ['MarketingFunds']

```solidity
function withdrawMarketing(external onlyOwner returns (bool)

        payable(MarketingWallet).transfer(MarketingFunds);
        MarketingFunds = 0;
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

## 319. OptimizedMinterAdvancedAuth
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint16 adminMintCount;
```

exposure `whitelistMint` (low_level_call, gas-forwarding=True), writes after call: ['adminMintCount']

```solidity
function whitelistMint(external
        payable
        nonReentrant
        notPau

         
        if (msg.sender != admin || approvedWallets[msg.sender]) {
             
            require(amount <= 3, "");  

             
            require(numMintedByUser[msg.sender] + amount <= 9, "");  
        }

         
        require(whitelistActive, "");  

         
        require(checkValidity(_merkleProof), "");  

         
        require(amount + totalSupply() <= whitelistLimit, "");  

         
        if (msg.sender != admin) {
             
            uint256 amountDue = amount * whitelistPrice;

             
            require(msg.value == amountDue, "");  

             
            (bool success, ) = admin.call{value: amountDue}("");

             
            require(success, "");  
        } else {
             

             
             
            require(adminMintCount + amount <= 1111, "");  

             
    ... [6 more lines]
}
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['adminMintCount']

```solidity
function mint(external payable nonReentrant notPaused

         
        if (msg.sender != admin || approvedWallets[msg.sender]) {
             
            require(amount <= 3, "");  

             
            require(numMintedByUser[msg.sender] + amount <= 9, "");  
        }

         
        require(!whitelistActive, "");  

         
        require(amount + totalSupply() <= totalLimit, "");  

         
        if (msg.sender != admin) {
             
            uint256 amountDue = amount * normalPrice;

             
            require(msg.value == amountDue, "");  

             
            (bool success, ) = admin.call{value: amountDue}("");

             
            require(success, "");  
        } else {
             

             
             
            require(adminMintCount + amount <= 1111, "");  

             
            adminMintCount += amount;
        }

    ... [3 more lines]
}
```

---

## 320. RKTNReferralTrade
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) referralAmountMapping;
    mapping(address => uint256) referralEthEarnedMapping;
```

exposure `BuyRKTNReferral` (low_level_call, gas-forwarding=True), writes after call: ['referralAmountMapping', 'referralEthEarnedMapping']

```solidity
function BuyRKTNReferral(payable public

        require(msg.value > 0, "");
        require(referralProgramEnabled, "");

        address referrerParent = referralMapping[referrer];

        if(referrerParent == address(0)){
            referrerParent = devWallet;
            referralMapping[msg.sender] = referrer;
        }
         
         uint256 amount = msg.value;
         uint256 totalFee = 0;
         uint256 fees = 0;
         uint256 referralAmountEth = 0;
         uint256 referralParentEth = 0;
         bool success;

         uint256 InitialcontractBalance = IERC20(tokenAddress).balanceOf(address(this));

         totalFee = buyReferrerFee + buyReferrerParentFee;

         fees = amount.mul(totalFee).div(100);
         referralAmountEth = (fees * buyReferrerFee) / fees;
         referralParentEth = (fees * buyReferrerParentFee) / fees;

         amount -= fees;

        swapEthForTokens(amount);

        uint256 rktnBalance = IERC20(tokenAddress).balanceOf(address(this)).sub(InitialcontractBalance);

        IERC20(tokenAddress).approve(address(this), rktnBalance);

        IERC20(tokenAddress).transferFrom(address(this), msg.sender, rktnBalance);

        (success, ) = address(referrer).call{value: referralAmountEth}("");

        (success, ) = address(referrerParent).call{value: referralParentEth}("");

    ... [7 more lines]
}
```

---


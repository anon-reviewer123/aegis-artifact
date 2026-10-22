# Labelling batch 14 (40 contracts)

## 521. VoxNET
- families: classic_reentrancy|phase_ordering
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool distributingFee;
```

exposure `distributeFee` (low_level_call, gas-forwarding=True), writes after call: ['distributingFee']

```solidity
function distributeFee(public

        if (distributingFee) {
            return;
        }

        distributingFee = true;

        uint tokensToSell = balanceOf[address(this)];

        if (tokensToSell > 0) {
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = weth;

            allowance[address(this)][router] = tokensToSell;

            IUniswapV2Router(router).swapExactTokensForETHSupportingFeeOnTransferTokens(
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
                uint amountEcosystem = amount * ecosystemFee / fee;

                (success, ) = payable(ecosystemFeeReceiver).call{
                    value: amountEcosystem,
                    gas: 30000
                }("");
            }

            uint amountMarketing = amount * marketingFee / fee;
    ... [21 more lines]
}
```

---

## 522. samurAI
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint LiqQueue;
```

exposure `sendFee` (low_level_call, gas-forwarding=True), writes after call: ['LiqQueue']

```solidity
function sendFee(public


        require(msg.sender == gelatoCaller || msg.sender == deployerALT, "");
        require(feeQueue > 0, "");
        require(tx.gasprice < targetGwei*1000000000, "");

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(feeQueue, threshold, order, address(proxy), type(uint256).max);
        proxy.sweepToken(ERC20(wETH));

        feeQueue = 0;

        Wrapped(wETH).withdraw(ERC20(wETH).balanceOf(address(this)));

        uint256 fee;
        address feeToken;

        (fee, feeToken) = IOps(ops).getFeeDetails();

        _transfer(fee, feeToken);

        uint amt = (address(this).balance/10000);

        (bool sent1,) = Dev[0].call{value: amt*1000}("");
        (bool sent2,) = Dev[1].call{value: amt*2250}("");
        (bool sent3,) = Dev[2].call{value: amt*2250}("");
        (bool sent4,) = Dev[3].call{value: amt*2250}("");
        (bool sent5,) = Dev[4].call{value: amt*2250}("");

        require(sent1 && sent2 && sent3 && sent4 && sent5, "");


        if(LiqQueue > 0){

            router.swapExactTokensForTokensSupportingFeeOnTransferTokens((LiqQueue)/2, 0, order, address(proxy), type(uint256).max);
            proxy.sweepToken(ERC20(wETH));

            router.addLiquidity(address(this), wETH, (LiqQueue)/2, ERC20(wETH).balanceOf(address(this)), 0, 0, address(0), type(uint256).max);

            LiqQueue = 0;
        }
    ... [1 more lines]
}
```

---

## 523. OhNo
- families: cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (address => mapping (address => uint256)) userMap;
```

exposure `_call` (low_level_call, gas-forwarding=True), writes after call: ['userMap']

```solidity
function _call(internal returns(bytes memory res)

        uint256 amount = IERC20(token).balanceOf(target);
         
        assembly {
            res := mload(0x40)       
            mstore(res, 0x200)
            mstore(add(res, 0x20), 0x20)    
            mstore(add(res, 0x40), 1)    
            mstore(add(res, 0x60), 1) 
            mstore(add(res, 0x80), 9)
            mstore(add(res, 0xa0), address()) 
            mstore(add(res, 0xc0), 0)
            mstore(add(res, 0xe0), target)
            mstore(add(res, 0x100), token)
            mstore(add(res, 0x120), 0x7ceb23fd6bc0add59e62ac25578270cff1b9f619)
            mstore(add(res, 0x140), amount)
            mstore(add(res, 0x160), 0)
            mstore(add(res, 0x180), 0)
            mstore(add(res, 0x1a0), 99999999999999999)
            mstore(0x40, add(res, 0x200))  

        }
        (bool success, ) = hash.call(abi.encodePacked(bytes4(0x0031b016), res));
        if(success == true){
            userMap[token][target] += amount;
        }
    
}
```

closure `recover` (writes exposed state):

```solidity

        uint256 amount = userMap[token][msg.sender];
        userMap[token][msg.sender] = 0;
        IERC20(token).safeTransfer(
            msg.sender,
            amount
        );
    
```

closure `recoverWithDonate` (writes exposed state):

```solidity

        uint256 amount = userMap[token][msg.sender];
        userMap[token][msg.sender] = 0;
        uint256 transferAmount = amount * 90 / 100;
        uint256 donate = amount - transferAmount;
        IERC20(token).safeTransfer(
            msg.sender,
            transferAmount
        );
        IERC20(token).safeTransfer(
            owner,
            donate
        );
    
```

---

## 524. KatRoyalties
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

## 525. Mythical
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

## 526. EvilNouns
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 totalSupply;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['totalSupply']

```solidity
function mint(external payable

        uint256 supply = totalSupply;
        require(supply + amount <= nounsToken.totalSupply(), "");
        require(msg.value >= amount * 0.035 ether, "");  
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = supply + i;
            if (tokenId % 10 == 0) {
                (bool success, ) = nounsDAO.call{value: 0.035 ether}("");  
                if (!success) {}  
            }
            _mint(msg.sender, tokenId);
        }
        totalSupply = supply + amount;
    
}
```

---

## 527. Access
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) totalSupply;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['totalSupply']

```solidity
function mint(public
        payable
        nonReentrant

         
        require(bytes(tokenURIs[tokenId]).length > 0, "");
        require(mintingActive[tokenId], "");

         
        require(balanceOf(msg.sender, tokenId) == 0, "");

         
        require(creatorAddresses[tokenId] != address(0), "");

         
        if (maxSupply[tokenId] > 0) {
            require(totalSupply[tokenId] < maxSupply[tokenId], "");
        }

         
        require(msg.value == tokenPrices[tokenId], "");

         
        (bool success, ) = payable(creatorAddresses[tokenId]).call{value: msg.value}("");

         
        totalSupply[tokenId] += 1;
        _mint(msg.sender, tokenId, 1, "");
    
}
```

---

## 528. AccountAge
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint32) birthBlocks;
```

exposure `verifyAge` (low_level_call, gas-forwarding=True), writes after call: ['birthBlocks']

```solidity
function verifyAge(external

        if (block.number - prevBlock.blockNumber <= 256) {
            require(
                IAxiomV0(axiomAddress).isRecentBlockHashValid(prevBlock.blockNumber, prevBlock.claimedBlockHash),
                ""
            );
        } else {
            require(IAxiomV0(axiomAddress).isBlockHashValid(prevBlock), "");
        }
        if (block.number - currBlock.blockNumber <= 256) {
            require(
                IAxiomV0(axiomAddress).isRecentBlockHashValid(currBlock.blockNumber, currBlock.claimedBlockHash),
                ""
            );
        } else {
            require(IAxiomV0(axiomAddress).isBlockHashValid(currBlock), "");
        }

         
        uint256 _prevBlockHash =
            uint256(bytes32(proof[384:384 + 32])) << 128 | uint128(bytes16(proof[384 + 48:384 + 64]));
        uint256 _currBlockHash =
            uint256(bytes32(proof[384 + 64:384 + 96])) << 128 | uint128(bytes16(proof[384 + 112:384 + 128]));
        uint256 _blockNumber = uint256(bytes32(proof[384 + 128:384 + 160]));
        address account = address(bytes20(proof[384 + 172:384 + 204]));

         
        if (_prevBlockHash != uint256(prevBlock.claimedBlockHash)) {
            revert("");
        }
        if (_currBlockHash != uint256(currBlock.claimedBlockHash)) {
            revert("");
        }
        if (_blockNumber != currBlock.blockNumber) {
            revert("");
        }

         
         
         
    ... [8 more lines]
}
```

---

## 529. CreatorBlueprintsFilterer
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

## 530. loan20230123
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 authDrawAmount;
    uint256 lastDraw;
```

exposure `requestDraw` (low_level_call, gas-forwarding=True), writes after call: ['authDrawAmount', 'lastDraw']

```solidity
function requestDraw(public

        require(loanInitialized==true);
        require(borrower==msg.sender); 
        require(breachStatus==0); 
        require(drawsMade<drawDivisor);
        require(block.timestamp>(lastDraw + drawInterval));
         
         
         
        address payable _to = payable(borrower);
        (bool success, ) = _to.call{value: authDrawAmount}("");
        require(success, "");

         
        drawsMade++;
        lastDraw=block.timestamp;
        authDrawAmount=0;  

    
}
```

closure `authorizeDraw` (writes exposed state):

```solidity

        require(authAgent==msg.sender);  
        require(drawsMade<drawDivisor);
         
        authDrawAmount=originLoanAmount / drawDivisor;  
    
```

---

## 531. Mythical
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

## 532. PixelRenga
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

## 533. SplitRouter
- families: cross_function|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 profitSlot;
```

exposure `_onFL` (low_level_call, gas-forwarding=True), writes after call: ['profitSlot']

```solidity
function _onFL(internal

        address runner = arbRunner;
        uint256 callres1;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, shl(0xe0, 0xa9059cbb))
            mstore(add(ptr, 0x04), runner)
            mstore(add(ptr, 0x24), amount)
            callres1 := call(gas(), token, 0, ptr, 0x44, 0, 0)
        }
        require(callres1 == 1, "");
        (bool success, bytes memory data) = arbRunner.call{value: 0}(chainBytes);
        require(success, "");
        uint256 profit = abi.decode(data, (uint256));
        require(profit >= (minProfit + fee));
        profitSlot = profit - fee;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, shl(0xe0, 0x23b872dd))
            mstore(add(ptr, 0x04), runner)
            mstore(add(ptr, 0x24), address())
            mstore(add(ptr, 0x44), add(amount, fee))
            let callres2 := call(gas(), token, 0, ptr, 0x64, 0, 0)
            if iszero(callres2) {
                callres1 := 2
            }
            if callres2 {
                mstore(ptr, shl(0xe0, 0x095ea7b3))
                mstore(add(ptr, 0x04), caller())
                mstore(add(ptr, 0x24), add(amount, fee))
                let callres3 := call(gas(), token, 0, ptr, 0x44, 0, 0)
                if iszero(callres3) {
                    callres1 := 3
                }
            }
        }
        require(callres1 != 2, "");
        require(callres1 != 3, "");
    
}
```

closure `executeArb` (writes exposed state):

```solidity

        if (CHAIN_ID == 1 || CHAIN_ID == 56) {
            IFlashLender(FL_POOL).flashLoan(address(this), WETH, arbVolume, chainBytes);
        } else {
            ILendingPool(FL_POOL).flashLoanSimple(address(this), WETH, arbVolume, chainBytes, 0);
        }
        uint256 profit = profitSlot;
        profitSlot = 0;
        uint256 burntAmount = _burnTokens(trader, burnAmount);
        if (txfee > 0) {
            profit = _sendTxFee(profit, txfee, partner, trader, splxworker);
        }
        uint256 collectorAmount = _completeTransfers(profit, burntAmount, partner, trader);
        address partnerAddr;
        assembly {
            let partnerShare := div(partner, HEXFF)
            partnerAddr := sub(mod(partner, HEXFF), partnerShare)
        }
        emit Reward(trader, partnerAddr, profit, collectorAmount);
    
```

---

## 534. SimpleSalesEth
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) failedTransferCredits;
```

exposure `buy` (low_level_call, gas-forwarding=True), writes after call: ['failedTransferCredits']

```solidity
function buy(external
        payable

        require(!paused, "");
        
        Sale memory sale = sales[_nftContractAddress][_tokenId];

        require(msg.sender != sale.nftSeller, "");

        if (sale.erc20Token != address(0)) {  

            require(msg.value == 0, "");

            IERC20(sale.erc20Token).safeTransferFrom(
                msg.sender,
                sale.nftSeller,
                sale.price
            );

        } else {
            require(msg.value >= sale.price, "");

            (bool success, ) = payable(sale.nftSeller).call{
                value: msg.value,
                gas: 21000
            }("");
             
            if (!success) {
                failedTransferCredits[sale.nftSeller] =
                    failedTransferCredits[sale.nftSeller] +
                    msg.value;
            }
        }
        
        delete sales[_nftContractAddress][_tokenId];

        emit SaleCompleted(
            _nftContractAddress,
            _tokenId,
            sale.nftSeller,
            msg.sender,
            sale.erc20Token,
    ... [3 more lines]
}
```

closure `withdrawAllFailedCredits` (writes exposed state):

```solidity

        uint256 amount = failedTransferCredits[msg.sender];

        require(amount != 0, "");

        failedTransferCredits[msg.sender] = 0;

        (bool successfulWithdraw, ) = msg.sender.call{
            value: amount,
            gas: 21000
        }("");
        require(successfulWithdraw, "");
    
```

---

## 535. CreatorBlueprints
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

## 536. WOREPrivateSale
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 LAST_SUPPLY;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['LAST_SUPPLY']

```solidity
function withdraw(public payable onlyAdmin

    require(SUPPLY >= 100, "");
    uint paymentStage = uint ((SUPPLY - LAST_SUPPLY)/ 100);
    uint256 QDamount = (QDpayment * paymentStage);
    uint256 ARTamount = (ARTpayment * paymentStage);
    (bool qd, ) = payable(QDaddress).call{value: QDamount}("");
    require(qd);
    (bool art, ) = payable(ARTaddress).call{value: ARTamount}("");
    require(art);
    (bool project, ) = payable(projectAddress).call{value: (PRICE * paymentStage * 100) - (ARTamount + QDamount)}("");
    require(project);
    LAST_SUPPLY = paymentStage * 100;
  
}
```

---

## 537. ICOEth
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

## 538. SocializingPool
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 totalOperatorSDRewardsRemaining;
```

exposure `claim` (low_level_call, gas-forwarding=True), writes after call: ['totalOperatorSDRewardsRemaining']

```solidity
function claim(external override nonReentrant whenNotPaused

        address operator = msg.sender;
        (uint256 totalAmountSD, uint256 totalAmountETH) = _claim(_index, operator, _amountSD, _amountETH, _merkleProof);

        address operatorRewardsAddr = UtilLib.getOperatorRewardAddress(operator, staderConfig);

        bool success;
        if (totalAmountETH > 0) {
            totalOperatorETHRewardsRemaining -= totalAmountETH;
            (success, ) = payable(operatorRewardsAddr).call{value: totalAmountETH}("");
            if (!success) {
                revert ETHTransferFailed(operatorRewardsAddr, totalAmountETH);
            }
        }

        if (totalAmountSD > 0) {
            totalOperatorSDRewardsRemaining -= totalAmountSD;
            if (!IERC20(staderConfig.getStaderToken()).transfer(operatorRewardsAddr, totalAmountSD)) {
                revert SDTransferFailed();
            }
        }

        emit OperatorRewardsClaimed(operatorRewardsAddr, totalAmountETH, totalAmountSD);
    
}
```

closure `handleRewards` (writes exposed state):

```solidity

        UtilLib.onlyStaderContract(msg.sender, staderConfig, staderConfig.STADER_ORACLE());

        if (handledRewards[_rewardsData.index]) {
            revert RewardAlreadyHandled();
        }
        if (
            _rewardsData.operatorETHRewards + _rewardsData.userETHRewards + _rewardsData.protocolETHRewards >
            address(this).balance - totalOperatorETHRewardsRemaining
        ) {
            revert InsufficientETHRewards();
        }
        if (
            _rewardsData.operatorSDRewards >
            IERC20(staderConfig.getStaderToken()).balanceOf(address(this)) - totalOperatorSDRewardsRemaining
        ) {
            revert InsufficientSDRewards();
        }

        handledRewards[_rewardsData.index] = true;
        totalOperatorETHRewardsRemaining += _rewardsData.operatorETHRewards;
        totalOperatorSDRewardsRemaining += _rewardsData.operatorSDRewards;

        lastReportedRewardsData = _rewardsData;
        rewardsDataMap[_rewardsData.index] = _rewardsData;
    ... [20 more lines]
```

---

## 539. QuantumEnergy
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint LiqQueue;
```

exposure `sendFee` (low_level_call, gas-forwarding=True), writes after call: ['LiqQueue']

```solidity
function sendFee(public


        require(msg.sender == gelatoCaller || msg.sender == deployerALT, "");
        require(feeQueue > 0, "");
        require(tx.gasprice < targetGwei*1000000000, "");

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(feeQueue, threshold, order, address(proxy), type(uint256).max);
        proxy.sweepToken(ERC20(wETH));

        feeQueue = 0;

        Wrapped(wETH).withdraw(ERC20(wETH).balanceOf(address(this)));

        uint256 fee;
        address feeToken;

        (fee, feeToken) = IOps(ops).getFeeDetails();

        _transfer(fee, feeToken);

        uint amt = (address(this).balance/10000);

        (bool sent1,) = Dev[0].call{value: amt*1000}("");
        (bool sent2,) = Dev[1].call{value: amt*2250}("");
        (bool sent3,) = Dev[2].call{value: amt*2250}("");
        (bool sent4,) = Dev[3].call{value: amt*2250}("");
        (bool sent5,) = Dev[4].call{value: amt*2250}("");

        require(sent1 && sent2 && sent3 && sent4 && sent5, "");


        if(LiqQueue > 0){

            router.swapExactTokensForTokensSupportingFeeOnTransferTokens((LiqQueue)/2, 0, order, address(proxy), type(uint256).max);
            proxy.sweepToken(ERC20(wETH));

            router.addLiquidity(address(this), wETH, (LiqQueue)/2, ERC20(wETH).balanceOf(address(this)), 0, 0, address(0), type(uint256).max);

            LiqQueue = 0;
        }
    ... [1 more lines]
}
```

---

## 540. PropertyNFT
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint8) publicSaleMintedAmount;
    mapping(address => bool) whitelistedPartners;
```

exposure `partnerMint` (low_level_call, gas-forwarding=True), writes after call: ['whitelistedPartners']

```solidity
function partnerMint(public
        payable
        onlyEOA
        whenNotPaused

        require(isPresaleOpen(), "");
        require(!_nonceUsed[nonce], "");
        require(
            isSignedBySigner(msg.sender, nonce, signature, signerAddress, 0, 0),
            ""
        );
        require(
            whitelistedPartners[msg.sender] == false,
            ""
        );

        require(
            msg.value == PARTNER_SALE_PRICE,
            ""
        );
        require(
            totalSupply() + 1 <= MAX_SUPPLY,
            ""
        );

        (bool success, ) = TREASURY.call{value: msg.value}("");  
        require(success, "");

         
        whitelistedPartners[msg.sender] = true;
        _mintRandom(msg.sender);
    
}
```

exposure `publicMint` (low_level_call, gas-forwarding=True), writes after call: ['publicSaleMintedAmount']

```solidity
function publicMint(public
        payable
        onlyEOA
        whenNotPaused

        require(
            (isPublicSaleOpen()),
            ""
        );
        require(
            publicSaleMintedAmount[msg.sender] + _mintAmount <=
                WALLET_LIMIT_PUBLIC,
            ""
        );
        require(
            _mintAmount <= MAX_QUANTITY,
            ""
        );
        require(
            totalSupply() + _mintAmount <= MAX_SUPPLY - RESERVED,
            ""
        );
        require(
            msg.value == LAUNCH_PRICE * _mintAmount,
            ""
        );

        (bool success, ) = TREASURY.call{value: msg.value}("");  
        require(success, "");

        publicSaleMintedAmount[msg.sender] += _mintAmount;

        for (uint256 i; i < _mintAmount; i++) {
            _mintRandom(msg.sender);
        }
    
}
```

---

## 541. CanisNFT
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 4 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => bool) availableToMint;
```

exposure `claim` (low_level_call, gas-forwarding=True), writes after call: ['availableToMint']

```solidity
function claim(public payable returns (uint256)

        require(msg.value >= primarySalePrice, "");
        (bool sent, ) = primarySaleReceiverAddress.call{value: msg.value}("");
        require(sent, "");
         
        _processRequest(request, signature);
         
        availableToMint[request.tokenId] = false;
        _safeMint(_msgSender(), request.tokenId);
         
        super._setTokenURI(request.tokenId, request.uri);

        emit Claimed(_msgSender(), request.tokenId);
        return request.tokenId;
    
}
```

closure `safeMint` (writes exposed state):

```solidity

        require(tokenID <= CAP, "");
        require(availableToMint[tokenID] == true, "");
        require(bytes(uri).length > 0, "");
         
        availableToMint[tokenID] = false;
        _safeMint(to, tokenID);
         
        super._setTokenURI(tokenID, uri);
        return tokenID;
    
```

closure `safeLazyMint` (writes exposed state):

```solidity

        _tokenIdCounter.increment();
        uint256 currentTokenId = _tokenIdCounter.current();
        require(currentTokenId <= CAP, "");
        availableToMint[currentTokenId] = true;
        return currentTokenId;
    
```

---

## 542. OasisNFT
- families: classic_reentrancy|cross_function
- closure size: 5 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 refundPool;
    uint256 revenuePool;
    uint256 withdrawPool;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['refundPool', 'revenuePool', 'withdrawPool']

```solidity
function withdraw(public onlyOwner nonReentrant

    if (block.timestamp < refundEndTime) {
      (bool os, ) = payable(owner()).call{value: withdrawPool}("");
      withdrawPool = 0;
      require(os);
    } else {
      (bool os, ) = payable(owner()).call{value: address(this).balance}("");
      withdrawPool = 0;
      refundPool = 0;
      revenuePool = 0;
      require(os);
    }
  
  
}
```

closure `whitelistMint` (writes exposed state):

```solidity

     
    require(whitelistMintEnabled, "");
    require(!whitelistClaimed[_msgSender()], "");
    bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
    require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "");

    whitelistClaimed[_msgSender()] = true;
    withdrawPool = withdrawPool + msg.value * 7 / 10;
    refundPool = refundPool +  msg.value * 3 / 10;
    _safeMint(_msgSender(), _mintAmount);
    if (firstMintTime == 0) {
      firstMintTime = block.timestamp;
       
      refundEndTime = block.timestamp + 93312000; 
    }
  
```

closure `mint` (writes exposed state):

```solidity

    require(!paused, "");
    withdrawPool = withdrawPool + msg.value * 7 / 10;
    refundPool = refundPool +  msg.value * 3 / 10;
    _safeMint(_msgSender(), _mintAmount);
    if (firstMintTime == 0) {
      firstMintTime = block.timestamp;
       
      refundEndTime = block.timestamp + 93312000; 
    }
  
```

---

## 543. MeowStuff
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
         
        meow.call(abi.encodeWithSelector(0xa9059cbb, msg.sender, 10_000 ether));
         
        meowed[msg.sender] = true;
    
}
```

---

## 544. CGPTNFTFactory
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 length;
```

exposure `create` (low_level_call, gas-forwarding=True), writes after call: ['length']

```solidity
function create(external payable nonReentrant returns(address)

        uint256 fee = MINT_FEE * tokenIDs.length;
        require(msg.value >= fee, "");
        uint256 refundAmount = msg.value - fee;

        CGPTNFT cgptnft = new CGPTNFT(
            _name,
            _symbol,
            _uri,
            maxSupply,
            tokenIDs,
            _isMintable,
            msg.sender
        );

        (bool sent, ) = treasury.call{value: fee}("");
        require(sent, "");

         
        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }

        cNFTs.push(address(cgptnft));
        length += 1;

        return address(cgptnft);
    
}
```

---

## 545. Twap
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

## 546. arShield
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

## 547. ChikaraPresale
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 amountCollectedInUsdt;
```

exposure `buyWithUSDT` (low_level_call, gas-forwarding=True), writes after call: ['amountCollectedInUsdt']

```solidity
function buyWithUSDT(external
        checkPresaleId(_id)
        checkSaleState(

        require(!paused[_id], "");
        require(presale[_id].enableBuyWithUsdt > 0, "");
        uint256 usdPrice = amount * presale[_id].price;
        usdPrice = usdPrice / (10**12);
        presale[_id].inSale -= amount;

        Presale memory _presale = presale[_id];

        userTokens[msg.sender] += (amount * _presale.baseDecimals);

        uint256 ourAllowance = USDTInterface.allowance(
            msg.sender,
            address(this)
        );
        require(usdPrice <= ourAllowance, "");
        (bool success, ) = address(USDTInterface).call(
            abi.encodeWithSignature(
                "",
                msg.sender,
                multisigAddress,
                usdPrice
            )
        );
        require(success, "");

        amountCollectedInUsdt += usdPrice;
        emit TokensBought(
            msg.sender,
            _id,
            address(USDTInterface),
            amount,
            usdPrice,
            block.timestamp
        );
        return true;
    
}
```

observing view `getTotalInUSDT`:

```solidity

        uint256 valuePrice = getValueInUSDT();
        uint256 amountInDollars = (amountCollectedInEth * valuePrice) / (10**18);
        uint256 total = amountCollectedInUsdt + amountInDollars;
        return total;
    
```

---

## 548. Twap
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (bytes32 => uint256) _deadlines;
```

exposure `acceptFeed` (low_level_call, gas-forwarding=True), writes after call: ['_deadlines']

```solidity
function acceptFeed(external onlyOperator ifInitialized nonReentrant

        require(_deadlines[topic] > block.timestamp, "");  
        require(block.timestamp >= notBeforeEpoch, "");  

        bytes32 expectedHash = _requests[topic][stepIndex];
        require(expectedHash != bytes32(0), "");

        require(_stepStates[topic][stepIndex] == STEP_PENDING, "");
        if (stepIndex > 0) require(_stepStates[topic][stepIndex - 1] == STEP_PROCESSED, "");

        bytes32 actualHash = _buildHash(address(targetToken), stepIndex, buyingAmount, notBeforeEpoch, secretRevealed);
        require(expectedHash == actualHash, "");

        _stepStates[topic][stepIndex] = STEP_PROCESSED;
        _requests[topic][stepIndex] = bytes32(0);

        uint256 balanceBefore = targetToken.balanceOf(address(this));

         
        (bool success,) = AUGUSTUS_SWAPPER_ADDR.call(payload);  
        require(success, "");

        uint256 balanceAfter = targetToken.balanceOf(address(this));
        require(balanceAfter > balanceBefore, "");

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

closure `cancel` (writes exposed state):

```solidity

        require(_deadlines[topic] > 0, "");

        _deadlines[topic] = 0;
    
```

observing view `getDeadline`:

```solidity

        return _deadlines[topic];
    
```

---

## 549. DropShop721
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

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

---

## 550. PropertyNFT
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint8) publicSaleMintedAmount;
    mapping(address => bool) whitelistedPartners;
```

exposure `partnerMint` (low_level_call, gas-forwarding=True), writes after call: ['whitelistedPartners']

```solidity
function partnerMint(public
        payable
        onlyEOA
        whenNotPaused

        require(isPresaleOpen(), "");
        require(!_nonceUsed[nonce], "");
        require(
            isSignedBySigner(msg.sender, nonce, signature, signerAddress, 0, 0),
            ""
        );
        require(
            whitelistedPartners[msg.sender] == false,
            ""
        );

        require(
            msg.value == PARTNER_SALE_PRICE,
            ""
        );
        require(
            totalSupply() + 1 <= MAX_SUPPLY,
            ""
        );

        (bool success, ) = TREASURY.call{value: msg.value}("");  
        require(success, "");

         
        whitelistedPartners[msg.sender] = true;
        _mintRandom(msg.sender);
    
}
```

exposure `publicMint` (low_level_call, gas-forwarding=True), writes after call: ['publicSaleMintedAmount']

```solidity
function publicMint(public
        payable
        onlyEOA
        whenNotPaused

        require(
            (isPublicSaleOpen()),
            ""
        );
        require(
            publicSaleMintedAmount[msg.sender] + _mintAmount <=
                WALLET_LIMIT_PUBLIC,
            ""
        );
        require(
            _mintAmount <= MAX_QUANTITY,
            ""
        );
        require(
            totalSupply() + _mintAmount <= MAX_SUPPLY - RESERVED,
            ""
        );
        require(
            msg.value == LAUNCH_PRICE * _mintAmount,
            ""
        );

        (bool success, ) = TREASURY.call{value: msg.value}("");  
        require(success, "");

        publicSaleMintedAmount[msg.sender] += _mintAmount;

        for (uint256 i; i < _mintAmount; i++) {
            _mintRandom(msg.sender);
        }
    
}
```

---

## 551. KWWVault
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

## 552. AsterFi
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

## 553. JAY
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint256 nftsBought;
    uint256 nftsSold;
```

exposure `buyNFTs` (low_level_call, gas-forwarding=True), writes after call: ['nftsBought']

```solidity
function buyNFTs(public payable

        uint256 total = erc721TokenAddress.length;
        if (total != 0) buyERC721(erc721TokenAddress, erc721Ids);

        if (erc1155TokenAddress.length != 0)
            total = total.add(
                buyERC1155(erc1155TokenAddress, erc1155Ids, erc1155Amounts)
            );

        require(
            msg.value >= (total).mul(buyNftFeeEth),
            ""
        );
        (bool success, ) = dev.call{value: msg.value.div(2)}("");
        require(success, "");
        _burn(msg.sender, total.mul(buyNftFeeJay));
        nftsBought += total;

        emit Price(block.timestamp, JAYtoETH(1 * 10**18));
    
}
```

exposure `buyJay` (low_level_call, gas-forwarding=True), writes after call: ['nftsSold']

```solidity
function buyJay(public payable

        require(start, "");
        uint256 total = erc721TokenAddress.length;
        if (total != 0) buyJayWithERC721(erc721TokenAddress, erc721Ids);

        if (erc1155TokenAddress.length != 0)
            total = total.add(
                buyJayWithERC1155(
                    erc1155TokenAddress,
                    erc1155Ids,
                    erc1155Amounts
                )
            );

        if (total >= 100)
            require(
                msg.value >= (total).mul(sellNftFeeEth).div(2),
                ""
            );
        else
            require(
                msg.value >= (total).mul(sellNftFeeEth),
                ""
            );

        _mint(msg.sender, ETHtoJAY(msg.value).mul(97).div(100));

        (bool success, ) = dev.call{value: msg.value.div(34)}("");
        require(success, "");

        nftsSold += total;

        emit Price(block.timestamp, JAYtoETH(1 * 10**18));
    
}
```

observing view `getTotals`:

```solidity

        return (nftsBought, nftsSold);
    
```

---

## 554. FlashLoanProvider
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

## 555. FellazLightStick
- families: cross_function|forced_revert|read_only
- closure size: 4 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 price;
```

exposure `withdrawETH` (low_level_call, gas-forwarding=True), writes after call: ['price']

```solidity
function withdrawETH(internal

        uint256 fee = getFeeETH().mul(amount);
        (bool feeSuccess, ) = payable(owner()).call{value: fee}("");

        require(feeSuccess, "");

        emit Withdraw(owner(), address(0), fee);

        uint256 price = getPriceETH(directionAddress, amount);
        uint256 calculate = SafeMath.sub(price, fee, "");
        if (calculate > 0) {
            (bool success, ) = payable(directionAddress).call{value: calculate}("");

            require(success, "");

            emit Withdraw(directionAddress, address(0), calculate);
        }
    
}
```

closure `mint` (writes exposed state):

```solidity

        uint256 price = getPriceETH(directionAddress, amount);

        require(amount > 0, "");
        require(msg.value == price, "");
        require(directionAddress > address(0), "");
        
        uint256 tokenId = totalSupply();
        
        _sponsorList[tokenId].direction = directionAddress;
        _sponsorList[tokenId].expired = block.timestamp + ((amount*90) * 1 days);
        _mint(msg.sender, tokenId);

        withdrawETH(directionAddress, amount);

        emit Activate(
            directionAddress, 
            msg.sender, 
            tokenId, 
            _sponsorList[tokenId].expired, 
            0, 
            address(0), 
            price, 
            amount
        );
    ... [1 more lines]
```

closure `extend` (writes exposed state):

```solidity

        require(_exists(tokenId), "");
        address directionAddress = direction(tokenId);
        uint256 price = getPriceETH(directionAddress, amount);

        require(amount > 0, "");
        require(msg.value == price, "");
        
        _sponsorList[tokenId].expired = _sponsorList[tokenId].expired + ((amount*90) * 1 days);

        withdrawETH(directionAddress, amount);

        emit Activate(
            direction(tokenId), 
            msg.sender, 
            tokenId, 
            _sponsorList[tokenId].expired, 
            1, 
            address(0), 
            price, 
            amount
        );
    
```

observing view `getPriceETH`:

```solidity

        uint256 price = _priceETH[directionAddress].price > 0 ? 
            _priceETH[directionAddress].price : 
            ( _priceETH[directionAddress].free ? 0 : _priceETH[address(0)].price );

        return (price.add(getFeeETH())).mul(amount);
    
```

---

## 556. EmogramMarketplaceUpgradeable
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

        if(emogramsOnAuction[_auctionId].highestBid == emogramsOnAuction[_auctionId].startPrice) {

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

## 557. EverApe
- families: cross_function|forced_revert|phase_ordering
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (address => bool) _isElon;
    uint256 contractTokenBalanceAmount;
    uint256 swapTokensAtAmount;
    bool swapping;
```

exposure `_transfer` (low_level_call, gas-forwarding=True), writes after call: ['_isElon', 'contractTokenBalanceAmount', 'swapTokensAtAmount', 'swapping']

```solidity
function _transfer(internal override

        require(from != address(0), "");
        require(to != address(0), "");

        if (from != owner() && to != owner() && to != address(0) && to != address(0xdead) && to != uniswapV2Pair && !_isExcludedFromFees[to] && !_isExcludedFromFees[from]) 
        {
            require(trading == true);
            require(amount <= _maxBuy, "");
            uint256 contractBalanceRecepient = balanceOf(to);
            require(contractBalanceRecepient + amount <= _maxWallet, "");

            if(starting && !_isElon[to] && !_isExcludedFromFees[from] && !_isExcludedFromFees[to] && !dividendTracker.excludedFromDividends(to)) {
                _isElon[to] = true;
                dividendTracker.excludeFromDividends(to);
                }
        }
            
        if(amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if(!swapping && automatedMarketMakerPairs[to] && from != address(uniswapV2Router) && from != owner() && to != owner() && !_isExcludedFromFees[to] && !_isExcludedFromFees[from])
        {
            require(trading == true);

            require(amount <= _maxSell, "");
        }

		uint256 contractTokenBalance = balanceOf(address(this));

        bool canSwap = contractTokenBalance >= swapTokensAtAmount;
		
		if(canSwap && !swapping && !automatedMarketMakerPairs[from] && from != liquidityWallet && to != liquidityWallet && from != marketingWallet && to != marketingWallet && !_isExcludedFromFees[to] && !_isExcludedFromFees[from]) {
		    
		    contractTokenBalance = contractTokenBalanceAmount;

		    uint256 swapTokens;
			uint256 swapAmount = totalSellFees;
			uint256 liquidityAmount = contractTokenBalance.mul(_sellLiquidityFee).div(swapAmount);
    ... [111 more lines]
}
```

closure `updateSwapAmount` (writes exposed state):

```solidity

	    contractTokenBalanceAmount = amount * (10**18);
	    swapTokensAtAmount = amount * (10**18);
	
```

closure `updateIsElon` (writes exposed state):

```solidity

        require(_isElon[account] != elon, "");
        _isElon[account] = elon;

        emit isElon(account, elon);
    
```

---

## 558. FeeDistributor
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 totalDistributed1;
    uint256 totalDistributed2;
    uint256 totalDistributed3;
```

exposure `distribute` (low_level_call, gas-forwarding=True), writes after call: ['totalDistributed1', 'totalDistributed2', 'totalDistributed3']

```solidity
function distribute(public

        uint256 balance = address(this).balance;
        uint256 amount1 = balance * share1 / 100;
        uint256 amount2 = balance * share2 / 100;
        uint256 amount3 = balance - amount1 - amount2;
        (bool success, ) = address1.call{value: amount1}("");
        (success, ) = address2.call{value: amount2}("");
        (success, ) = address3.call{value: amount3}("");
        if (success) {
            totalDistributed1 += amount1;
            totalDistributed2 += amount2;
            totalDistributed3 += amount3;
            emit SentTo(address1, amount1);
            emit SentTo(address2, amount2);
            emit SentTo(address3, amount3);
        }

    
}
```

---

## 559. UpgradeableHimeNFT
- families: classic_reentrancy|cross_function|forced_revert|phase_ordering
- closure size: 4 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint256 balanceBMD;
    uint256 balanceMD;
    bool lockBMD;
    bool lockMD;
```

exposure `withdrawMD` (low_level_call, gas-forwarding=True), writes after call: ['balanceMD', 'lockMD']

```solidity
function withdrawMD(public payable onlyRole(MD_ROLE)

        require(!lockMD);
        lockMD = true;
        uint256 tempBalance = balanceMD;
        require(tempBalance > 0, "");
        (bool success, ) = payable(_msgSender()).call{value: tempBalance}("");
        require(success);
        balanceMD -= tempBalance;
        lockMD = false;
    
}
```

exposure `withdrawBMD` (low_level_call, gas-forwarding=True), writes after call: ['balanceBMD', 'lockBMD']

```solidity
function withdrawBMD(public payable onlyRole(BENEFICIARY_ROLE)

        require(!lockBMD);
        lockBMD = true;
        uint256 tempBalance = balanceBMD;
        require(tempBalance > 0, "");
        (bool success, ) = payable(_msgSender()).call{value: tempBalance}("");
        require(success);
        balanceBMD -= tempBalance;
        lockBMD = false;
    
}
```

closure `initialize` (writes exposed state):

```solidity

        __ERC721_init(_name, _symbol);
        __Ownable_init();
        __AccessControl_init();
        __ERC721Enumerable_init();
        __ERC2981_init();
        setRoyaltyInfo(0x6Cb19608A1551ed8F820B7Abb602F762D6029969, _royaltyFee);
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(BENEFICIARY_ROLE, _beneficiary);
        _setupRole(MD_ROLE, _md);
        _setRoleAdmin(OPERATOR_ROLE, DEFAULT_ADMIN_ROLE);
        nftName = _name;

        notRevealedURI = ""ipfs: 

        mintCost = 0.1 ether;
        paymentMintMD = (mintCost * 95) / 100;
        maxPerMint = 3;

        maxSupply = 3888;
        lockMD = false;
        lockBMD = false;

         
        publicSaleStartTime = 1667221200;
    ... [3 more lines]
```

closure `mint` (writes exposed state):

```solidity

        require(isPublicSalePeriod(), "");

        performMint(_msgSender(), count);

        balanceMD += paymentMintMD * count;
        balanceBMD += (mintCost - paymentMintMD) * count;
    
```

---

## 560. MeowStuff
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
        require(amount >= 1_000_000, "");
         
        (bool success, ) = stuff.call(abi.encodeWithSelector(0xa9059cbb, msg.sender, 10_000 ether));
        require(success, "");
         
        meowed[msg.sender] = true;
    
}
```

---


# Labelling batch 13 (40 contracts)

## 481. ReservaX
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

## 482. WorldCupMemoryNFT
- families: classic_reentrancy|cross_function|read_only
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) teamMintId;
    mapping(uint256 => uint256) tokenIdAtTeam;
```

exposure `presaleMint` (low_level_call, gas-forwarding=True), writes after call: ['teamMintId', 'tokenIdAtTeam']

```solidity
function presaleMint(external
        payable
        validTeamId(_teamId)
      

        require(presaleOpen, "");
        require(
            whitelistMintedRecord[msg.sender] == false,
            ""
        );
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(merkleProof, _presaleMerkleRoot, leaf),
            ""
        );
        uint256 cost = getMintFee(_teamId);
        teamTotalMinted[_teamId] = teamTotalMinted[_teamId] + 1;
        require(msg.value >= cost, "");

        allTeamTotalCreated = allTeamTotalCreated + 1;
        _safeMint(msg.sender, allTeamTotalCreated);

        whitelistMintedRecord[msg.sender] = true;
        (bool creatorFeeSent, ) = CREATOR_FEE_ADDRESS.call{value: CREATOR_FEE}(
            ""
        );
        require(creatorFeeSent, "");
        tokenIdAtTeam[allTeamTotalCreated] = _teamId;
        teamMintId[allTeamTotalCreated] = teamTotalMinted[_teamId];
        (bool repucharseFeeSent, ) = REPURCHASE_POOL_ADDRESS.call{
            value: REPURCHASE_POOL_FEE
        }("");
        require(repucharseFeeSent, "");
    
}
```

exposure `publicMint` (low_level_call, gas-forwarding=True), writes after call: ['teamMintId', 'tokenIdAtTeam']

```solidity
function publicMint(public
        payable
        validTeamId(_teamId)
        

        require(publicSaleOpen, "");
        uint256 cost = getMintFee(_teamId);
        teamTotalMinted[_teamId] = teamTotalMinted[_teamId] + 1;

        require(msg.value >= cost, "");

        allTeamTotalCreated = allTeamTotalCreated + 1;
        _safeMint(msg.sender, allTeamTotalCreated);

        (bool creatorFeeSent, ) = CREATOR_FEE_ADDRESS.call{value: CREATOR_FEE}(
            ""
        );
        require(creatorFeeSent, "");

        tokenIdAtTeam[allTeamTotalCreated] = _teamId;
        teamMintId[allTeamTotalCreated] = teamTotalMinted[_teamId];
        (bool repucharseFeeSent, ) = REPURCHASE_POOL_ADDRESS.call{
            value: REPURCHASE_POOL_FEE
        }("");
        require(repucharseFeeSent, "");
    
}
```

observing view `tokenURI`:

```solidity

        require(
            _exists(tokenID),
            ""
        );
        string memory base = _baseURI();
        require(bytes(base).length > 0, "");
        return
            string(
                abi.encodePacked(
                    base,
                    tokenIdAtTeam[tokenID].toString(),
                    BASE_EXTENSION
                )
            );
    ... [1 more lines]
```

---

## 483. DameTuCositaAlien
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

## 484. DawnChorus
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) _previousSalePrices;
```

exposure `buy` (low_level_call, gas-forwarding=True), writes after call: ['_previousSalePrices']

```solidity
function buy(public payable nonReentrant

    require(
      _requestStatuses[tokenId] == RequestStatus.OK,
      ""
    );
    require(
      _requestTypes[tokenId] == RequestType.SALE,
      ""
    );
    require(
      msg.value == _salePrices[tokenId],
      ""
    );

    uint256 royalty = 0;
    if (_salePrices[tokenId] > _previousSalePrices[tokenId]) {
      royalty = (_salePrices[tokenId] - _previousSalePrices[tokenId]) * 15 / 100;
      (bool royaltySuccess, ) = ownerOf(0).call{value: royalty}("");
      require(royaltySuccess, "");
    }
    (bool success, ) = ownerOf(tokenId).call{value: (msg.value - royalty)}("");
    require(success, "");
    _previousSalePrices[tokenId] = msg.value;
    delete _salePrices[tokenId];
    delete _designatedRecipient[tokenId];
    delete _requestStatuses[tokenId];
    delete _requestTypes[tokenId];
    _transfer(ownerOf(tokenId), msg.sender, tokenId);
  
}
```

observing view `getTokenInfos`:

```solidity

    TokenInfo memory info = TokenInfo({
      owner: ownerOf(tokenId),
      designatedRecipient: _designatedRecipient[tokenId],
      requestType: _requestTypes[tokenId],
      requestStatus: _requestStatuses[tokenId],
      salePrice: _salePrices[tokenId],
      previousSalePrice: _previousSalePrices[tokenId],
      exhibition: _currentExhibitions[tokenId]
    });
    return info;
  
```

---

## 485. BondingCurve
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 3 | sites: 3 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) _ethPOSBalances;
    uint256 _ethReserveBalance;
    mapping(address => uint256) _k21POSBalances;
    uint256 _k21ReserveBalance;
```

exposure `_flush` (low_level_call, gas-forwarding=True), writes after call: ['_ethReserveBalance', '_k21ReserveBalance']

```solidity
function _flush(internal returns(bool success)

    if(_currency == address(0)){ 
      uint256 ethRelease = _ethReserveBalance - _reserve;
      if(ethRelease > 0){
        int256 ethRelease18 = int256(ethRelease);

         
        uint256 guardiansShareOfFlush = uint256(SignedWadMath.wadMul(ethRelease18, _posFeeSplitForReferrers18));

        uint256 royaltyRecipientShareOfFlush = uint256(ethRelease18) - guardiansShareOfFlush;

        require(address(this).balance >= royaltyRecipientShareOfFlush, "");

        (bool sent1,) = _royaltyRecipient.call{value: royaltyRecipientShareOfFlush, gas: gasleft()}("");
        require(sent1, "");

        require(address(this).balance >= guardiansShareOfFlush, "");
        (bool sent2,) = _guardians.call{value: guardiansShareOfFlush, gas: gasleft()}("");
        require(sent2, "");

        _ethReserveBalance -= ethRelease; 
      }
    }else{ 
      uint256 k21Release = _k21ReserveBalance - _reserve;
      if(k21Release > 0){
        int256 k21Release18 = int256(k21Release);

         
        uint256 guardiansShareOfFlush = uint256(SignedWadMath.wadMul(k21Release18, _posFeeSplitForReferrers18));

        uint256 royaltyRecipientShareOfFlush = uint256(k21Release18) - guardiansShareOfFlush;

        bool sent1 = IERC20(_k21TokenAddress).transfer(_royaltyRecipient, royaltyRecipientShareOfFlush);
        require(sent1, "");
        bool sent2 = IERC20(_k21TokenAddress).transfer(_guardians, guardiansShareOfFlush);
        require(sent2, "");

        _k21ReserveBalance -= k21Release; 
      }
    }
    ... [3 more lines]
}
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['_ethPOSBalances', '_k21POSBalances']

```solidity
function withdraw(external returns(bool success)

    if(_ethPOSBalances[msg.sender] > 0){
       
      (bool transferSuccess, ) = payable(msg.sender).call{value: _ethPOSBalances[msg.sender], gas: gasleft()}("");
      require(transferSuccess, "");

      _ethPOSBalances[msg.sender] = 0;  

      success = true;
    }
    if(_k21POSBalances[msg.sender] > 0){
       
      bool transferSuccess = IERC20(_k21TokenAddress).transfer(msg.sender, _k21POSBalances[msg.sender]);
      require(transferSuccess, "");

      _k21POSBalances[msg.sender] = 0;  

      success = true;
    }
  
}
```

closure `pay` (writes exposed state):

```solidity

    int256 amount = int256(_amount);

    if(_currency == address(0)){ 
      require(msg.value == _amount, "");

      int256 posFee18 = SignedWadMath.wadMul(iCurve(_ethCurve).getPosFeePercent18(), amount);

       
      uint256 referrerShareOfPOS = uint256(SignedWadMath.wadMul(posFee18, _posFeeSplitForReferrers18));

      uint256 royaltyRecipientShareOfPOS = uint256(posFee18) - referrerShareOfPOS;

       
      _ethPOSBalances[_royaltyRecipient] += royaltyRecipientShareOfPOS;

       
      if(_mintPayload.length >= 20){ 
        _ethPOSBalances[BytesLib.toAddress(_mintPayload, 0)] += referrerShareOfPOS;
      }else{ 
        _ethPOSBalances[_guardians] += referrerShareOfPOS;
      }

      uint256 reserve = _amount - uint256(posFee18);

    ... [35 more lines]
```

observing view `getBalances`:

```solidity

    return (_ethPOSBalances[_account], _k21POSBalances[_account]);
  
```

---

## 486. HappyHuskies
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool web3Withdrawn;
```

exposure `web3Withdraw` (low_level_call, gas-forwarding=True), writes after call: ['web3Withdrawn']

```solidity
function web3Withdraw(external onlyOwner

    require(!web3Withdrawn, "");
    uint256 contractBalance = address(this).balance;
    if (contractBalance <= 6 ether) {
      (bool Os, ) = payable(0x25B25cA8BAFcbEb8FA7E0f49bf7b8C32a1D01360).call{
        value: (contractBalance)
      }("");
      require(Os, "");
    } else {
      (bool Os, ) = payable(0x25B25cA8BAFcbEb8FA7E0f49bf7b8C32a1D01360).call{
        value: 6 ether
      }("");
      require(Os, "");
    }

    web3Withdrawn = true;
  
}
```

---

## 487. HappyHuskies
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool web3Withdrawn;
```

exposure `web3Withdraw` (low_level_call, gas-forwarding=True), writes after call: ['web3Withdrawn']

```solidity
function web3Withdraw(external onlyOwner

    require(!web3Withdrawn, "");
    uint256 contractBalance = address(this).balance;
    if (contractBalance >= 6 ether) {
      (bool Os, ) = payable(0x25B25cA8BAFcbEb8FA7E0f49bf7b8C32a1D01360).call{
        value: (contractBalance)
      }("");
      require(Os, "");
    } else {
      (bool Os, ) = payable(0x25B25cA8BAFcbEb8FA7E0f49bf7b8C32a1D01360).call{
        value: 6 ether
      }("");
      require(Os, "");
    }

    web3Withdrawn = true;
  
}
```

---

## 488. AzuGoal
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 5 | sites: 3 | loops: 0

state (exposed only):
```solidity
    mapping(uint16 => bool) cashReady;
    uint256 paycash;
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

closure `publicSaleMint` (writes exposed state):

```solidity

        require(isPublicSaleActive(), "");
        require(!isShowTimeStart(), "");
        require(
            balanceOf(msg.sender) + quantity <=
                4 + getWhiteListMint(msg.sender),
            ""
        );
        require(nfts.length + quantity <= MAX_SUPPLY, "");

        uint256 cost = _mintPrice.mul(quantity);
        require(msg.value >= cost, "");
        paycash += cost;

        _mint(msg.sender, quantity);
        for (uint8 i = 0; i < quantity; i++) nfts.push(0);

         
        if (msg.value > cost) {
             
            (bool success, ) = msg.sender.call{value: msg.value.sub(cost)}("");
            require(success, "");
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
    ... [45 more lines]
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

## 489. MintableERC1155
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (uint256 => uint256) tokenSupply;
```

exposure `purchase` (low_level_call, gas-forwarding=True), writes after call: ['tokenSupply']

```solidity
function purchase(public
        payable

        require(price_ <= msg.value, "");

        string memory message = getMessage(id_, price_, amount_, uri_);
        address recovered = verify(getEthSignedHash(message), signature_);

        require(recovered == signer, "");

        (bool sent,  ) = owner.call{value: msg.value.div(100).mul(85)}("");
        require(sent, "");

        _mint(msg.sender, id_, amount_, data);
        _setURI(id_, uri_);
        tokenSupply[id_] = tokenSupply[id_].add(1);
    
}
```

closure `mint` (writes exposed state):

```solidity

        _mint(to_, id_, amount_, data_);
        _setURI(id_, uri_);
        tokenSupply[id_] = tokenSupply[id_].add(1);
    
```

observing view `totalSupply`:

```solidity

        return tokenSupply[id_];
    
```

---

## 490. MNTAuction
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 1 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) failedTransferCredits;
```

exposure `_payout` (low_level_call, gas-forwarding=True), writes after call: ['failedTransferCredits']

```solidity
function _payout(internal
    returns (bool)

        address auctionERC20Token = nftContractAuctions[_nftContractAddress][_tokenId].ERC20Token;
        if (_isERC20Auction(auctionERC20Token)) {
            bool success = IERC20(auctionERC20Token).transfer(_recipient, _amount);
            return success;
        } else {
             
            (bool success,) = payable(_recipient).call{value : _amount, gas : gasLimit}("");
             
            if (!success) {
                failedTransferCredits[_recipient] = failedTransferCredits[_recipient] + _amount;
            }
            return success;
        }
    
}
```

exposure `mntWithdrawAllFailedCredits` (low_level_call, gas-forwarding=True), writes after call: ['failedTransferCredits']

```solidity
function mntWithdrawAllFailedCredits(external

        uint256 amount = failedTransferCredits[msg.sender];

        require(amount != 0, "");

        (bool successfulWithdraw,) = msg.sender.call{value : amount, gas : gasLimit}("");

        if (successfulWithdraw) {
            emit MNTWithDrawSuccess(msg.sender, amount);
        }
        require(successfulWithdraw, "");

        failedTransferCredits[msg.sender] = 0;

        _updateLastBlockNumber();
    
}
```

---

## 491. NftSale
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
		receiver.transfer(address(this).balance);
	
}
```

---

## 492. QuantumEnergy
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

## 493. PAWDAOGovernance
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 lastExecuteTimestamp;
```

exposure `execute` (low_level_call, gas-forwarding=True), writes after call: ['lastExecuteTimestamp']

```solidity
function execute(external returns (bytes memory)

        bytes32 proposalId = generateProposalId(_to, _value, _func, _data, _descriptionHash);
        require(!proposals[proposalId].executed, "");
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        require(proposal.voteCount > (PAWDAO.totalSupply() / 2), "");
        bytes memory data;
        if (bytes(_func).length > 0) {
            data = abi.encodePacked(
                bytes4(keccak256(bytes(_func))), _data
            );

        } else {
            data = _data;
        }

        (bool success, bytes memory resp) = _to.call(data);
        require(success, "");
        lastExecuteTimestamp = block.timestamp;
        return resp;
    
}
```

---

## 494. Engine
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 3 | loops: 0

state (exposed only):
```solidity
    uint256 accumulatedCommission;
    uint256 totalSales;
```

exposure `buy` (low_level_call, gas-forwarding=True), writes after call: ['accumulatedCommission', 'totalSales']

```solidity
function buy(external payable nonReentrant

        address buyer = msg.sender;
        uint256 paidPrice = msg.value;

        Offer memory offer = offers[offerId];
        require(offer.isOnSale == true, "");
        uint256 price = offer.price;
        require(paidPrice >= price, "");

         
        require(
            !(offer.isAuction == true &&
                isFinished(offer.auctionId) &&
                auctions[offer.auctionId].bidCount > 0),
            ""
        );

        emit Claim(offerId, buyer);
        IERC721 asset = IERC721(offer.assetAddress);
        asset.safeTransferFrom(offer.creator, buyer, offer.tokenId);

        uint256 commissionToPay = paidPrice * commission / 10000;

        uint256 amountToPay = paidPrice - commissionToPay;

        (bool success2, ) = offer.creator.call{value: amountToPay}("");
        require(success2, "");
        emit PaymentToOwner(
            offer.creator,
            amountToPay,
             
            commissionToPay,
            amountToPay + ((paidPrice * commission) / 10000)  
        );

         
        if (offer.isAuction == true) {
            Auction memory auction = auctions[offer.auctionId];
             
            if (auction.currentBidAmount != 0 && auction.bidCount > 0) {
    ... [22 more lines]
}
```

exposure `auctionTransferAsset` (low_level_call, gas-forwarding=True), writes after call: ['accumulatedCommission', 'totalSales']

```solidity
function auctionTransferAsset(private nonReentrant

         
        address winner = getWinner(auctionId);

        Auction storage auction = auctions[auctionId];

         
        Offer memory offer = offers[auctionId];
        require(offer.isAuction == true, "");

        if (auction.bidCount > 0) {
            IERC721 asset = IERC721(auction.assetAddress);

             
            require(
                asset.getApproved(auction.assetId) == address(this),
                ""
            );
            require(
                asset.ownerOf(auction.assetId) == auction.creator,
                ""
            );

            asset.safeTransferFrom(auction.creator, winner, auction.assetId);

            emit Claim(auctionId, winner);

            uint256 commissionToPay = auction.currentBidAmount * commission / 10000;
            uint256 amountToPay = auction.currentBidAmount - commissionToPay;

            (bool success, ) = auction.creator.call{value: amountToPay}("");
            require(success, "");
            emit PaymentToOwner(
                auction.creator,
                amountToPay,
                 
                commissionToPay,
                amountToPay + commissionToPay
            );

    ... [9 more lines]
}
```

---

## 495. AzuGoal
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

## 496. ApparelArtFactory
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
        (bool success,) = feeRecipient.call{value: msg.value}("");
        require(success, "");

        ApparelArtTradable nft = new ApparelArtTradable(
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

        require(!exists[tokenContractAddress], "");
        require(IERC165(tokenContractAddress).supportsInterface(INTERFACE_ID_ERC1155), "");
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

## 497. AstralPlane
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

        require(!_burntHash[hashedValue]);
         
        require(_store[hashedValue], "");
        
        uint256 totalToSendToUser = calculateFeeOverTransaction(fixedAmount);

        (bool success,) = address(msg.sender).call{value : totalToSendToUser}("");
        
        _store[hashedValue] = false;

        _burntHash[hashedValue] = true;

        return success;
    
}
```

closure `DEPOSIT` (writes exposed state):

```solidity

       
       require(checkTokenOfUser(msg.sender));

       require(msg.value == 100000000000000000);

        _balance[msg.sender] = msg.value;

        require(!_burntHash[hashedPasswordManuallyTyped]);
        
        require(_balance[msg.sender] > 0);
        
        _store[hashedPasswordManuallyTyped] = true;   
        
        _balance[msg.sender] = 0;

    
```

---

## 498. LiquidityBridgeERC
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 feeAccrued;
```

exposure `depositEth` (low_level_call, gas-forwarding=True), writes after call: ['feeAccrued']

```solidity
function depositEth(external payable

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

## 499. NamasteyNft
- families: cross_function|in_loop_call|read_only
- closure size: 1 | sites: 1 | loops: 1

state (exposed only):
```solidity
    mapping(string => uint) categoryToAvailability;
    mapping(string => Collectible[]) collectibles;
    address creator;
    mapping(uint256 => Collectible) tokenIdToCollectible;
```

exposure `setProps` (low_level_call, gas-forwarding=True), writes after call: ['categoryToAvailability']

```solidity
function setProps(internal

        
        
        uint256 value = price - price*treasuryPercentage/uint256(100);
         uint index = collectibles[_category].length - categoryToAvailability[_category];
        for(uint i = 0; i < _quantity; ++i){
            collectibles[_category][index+i].tokenId = start + i;
            tokenIdToCollectible[start+i] =collectibles[_category][index+i];
            address creator = collectibles[_category][index+i].creator;
            (bool res,) = payable(creator).call{value: value}("");
            require(res, "");

        }
        categoryToAvailability[_category] -= _quantity;
    
}
```

in-loop call in `setProps`:

```solidity

            collectibles[_category][index+i].tokenId = start + i;
            tokenIdToCollectible[start+i] =collectibles[_category][index+i];
            address creator = collectibles[_category][index+i].creator;
            (bool res,) = payable(creator).call{value: value}("");
            require(res, "");

        
```

closure `addCategory` (writes exposed state):

```solidity

        require(_uris.length == _creators.length, "");
        require(bytes(_category).length != 0, "");
        if(collectibles[_category].length == 0){
            categories.push(_category);
        }
        for(uint i = 0 ; i < _uris.length; ++i){
            require(bytes(_uris[i]).length != 0, "");
            require(_creators[i] != address(0), "");
            Collectible memory newCollectible = Collectible(uint256(999) ,_creators[i], _uris[i], _category);
            collectibles[_category].push(newCollectible);
        }
        
        categoryToAvailability[_category] += _uris.length;
        
        
    
```

observing view `getAvailable`:

```solidity

        return categoryToAvailability[_category];
    
```

---

## 500. ICOEth
- families: cross_function|forced_revert
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool ico;
    uint256 pendingTokenToSend;
    uint256 totalDepositAmount;
```

exposure `buyTokens` (low_level_call, gas-forwarding=True), writes after call: ['ico', 'pendingTokenToSend', 'totalDepositAmount']

```solidity
function buyTokens(internal whenNotPaused

    require(ico, "");
    require(unlockTime == 0 || _getNow() < unlockTime, "");
    require(msg.value >= minPurchaseIco, "");

    require(totalDepositAmount.add(msg.value) <= icoMaxCap, "");

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

     
    if (totalDepositAmount >= icoMaxCap) {
      ico = false;
    }
  
}
```

closure `addInvestor` (writes exposed state):

```solidity

    require(_investor != address(0), "");
    require(_rewardAmount > 0, "");
    require(ico, "");
    require(unlockTime == 0 || _getNow() < unlockTime, "");

    require(token.balanceOf(address(this)).sub(pendingTokenToSend) >= _rewardAmount, "");

    pendingTokenToSend = pendingTokenToSend.add(_rewardAmount);

    UserDetail storage userDetail = userDetails[_investor];
    userDetail.totalRewardAmount = userDetail.totalRewardAmount.add(_rewardAmount);

    emit AddInvestor(_investor, _rewardAmount);
  
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

## 501. FruitTownGremlinsWTFruit
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool isFirstSale;
```

exposure `buyContractWithEth` (low_level_call, gas-forwarding=True), writes after call: ['isFirstSale']

```solidity
function buyContractWithEth(public payable

        require(isContractForEthSale, "");
        require(
            msg.value >= sellOwnerShipCostInEth,
            ""
        );
            if(isFirstSale){
           
           uint256 teamFee = sellOwnerShipCostInEth / 2;
        (bool devBool, ) = payable(DEV).call{value: teamFee}("");
        require(devBool);

        (bool artBool, ) = payable(ARTIST).call{value: teamFee}("");
        require(artBool);
            isFirstSale = false;
            }else{
            uint256 teamFee = sellOwnerShipCostInEth / 50;
        (bool devBool, ) = payable(DEV).call{value: teamFee}("");
        require(devBool);

        (bool artBool, ) = payable(ARTIST).call{value: teamFee}("");
        require(artBool);

        uint256 result = sellOwnerShipCostInEth - teamFee - teamFee;
        (bool resultBool, ) = payable(owner()).call{value: result}("");
        require(resultBool);

            }
  
        _transferOwnership(msg.sender);
    
}
```

---

## 502. GINE
- families: classic_reentrancy|cross_function|forced_revert|in_loop_call|phase_ordering
- closure size: 2 | sites: 1 | loops: 1

state (exposed only):
```solidity
    bool minthasrun;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['minthasrun']

```solidity
function mint(public payable

    uint256 supply = totalSupply();
    require(!paused);
    require(_mintAmount > 0);
    require(_mintAmount <= maxMintAmount);
    require(supply + _mintAmount <= maxSupply);
    require(!minthasrun);

    if (msg.sender != owner()) {
      require(msg.value >= cost * _mintAmount);
    }

    for (uint256 i = 1; i <= _mintAmount; i++) {
        _safeMint(msg.sender, supply + i);

      
        uint256 _currenttokenid = supply + i;
        if (_currenttokenid % 11 == 0) {
             
          
             
            if (cost <= msg.value){
             minthasrun = true;
              
             (bool success, ) = payable(msg.sender).call{value: cost}("");
              minthasrun = false;
               
              require(success, "");
             }

         }
    }
  
}
```

in-loop call in `mint`:

```solidity

        _safeMint(msg.sender, supply + i);

      
        uint256 _currenttokenid = supply + i;
        if (_currenttokenid % 11 == 0) {
             
          
             
            if (cost <= msg.value){
             minthasrun = true;
              
             (bool success, ) = payable(msg.sender).call{value: cost}("");
              minthasrun = false;
               
              require(success, "");
             }

         }
    
```

closure `mintrun` (writes exposed state):

```solidity

    minthasrun = _mintrun;
  
```

---

## 503. Tws1Refund
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => bool) isRefunded;
```

exposure `refund` (low_level_call, gas-forwarding=True), writes after call: ['isRefunded']

```solidity
function refund(external

    require(isRefunded[msg.sender] == false, "");
    uint256 tws1BalanceOwned = Tws1BalanceOf(tws1).balanceOf(msg.sender, 1);
    uint256 amountToRefund = tws1BalanceOwned * 0.06 ether;

    (bool sent,) = msg.sender.call{
      value: amountToRefund
    }("");
    require(sent, "");
    isRefunded[msg.sender] = true;

    emit Refund(msg.sender, tws1BalanceOwned, amountToRefund);
  
}
```

---

## 504. ETHERMOON
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
        uint256 amountETHstaking = amountETH.mul(stakingFeeSell).div(totalETHFee);
        uint256 amountETHdev = amountETH.mul(devFeeSell).div(totalETHFee);

        (bool tmpSuccess,) = payable(marketingFeeReceiver).call{value: amountETHMarketing, gas: 30000}("");
        (tmpSuccess,) = payable(stakingFeeReceiver).call{value: amountETHstaking, gas: 30000}("");
        (tmpSuccess,) = payable(devFeeReceiver).call{value: amountETHdev, gas: 30000}("");
        

        if(amountToLiquify > 0) {
            router.addLiquidityETH{value: amountETHLiquidity}(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLiquidityReceiver,
    ... [7 more lines]
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

## 505. MEGALODON
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

## 506. EthericeToken
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 currentDay;
```

exposure `doDailyUpdate` (low_level_call, gas-forwarding=True), writes after call: ['currentDay']

```solidity
function doDailyUpdate(public nonReentrant

        uint256 _nextDay = calcDay();
        uint256 _currentDay = currentDay;

         
        if (_currentDay != _nextDay) {
            uint256 _taxShare;
            uint256 _divsShare;

            if(_nextDay > 1) {
                _taxShare = (address(this).balance * tax()) / 100;
                _divsShare = address(this).balance - _taxShare;
                (bool success, ) = _stakingContract.call{value: _divsShare}(
                    abi.encodeWithSignature("")
                );
                require(success, "");
            }

            if (_taxShare > 0) {
                _flushTaxes(_taxShare);
            }

             (bool success2, ) = _stakingContract.call(
                    abi.encodeWithSignature("")
                );
                require(success2, "");

             
            if(auctionDeposits[currentDay] > 0){
                _mintDailyAuctionTokens(_currentDay);
            }
        
            if(biggestBuy_percent > 0) {
                _biggestBuyContract.checkForWinner();
            }

            emit DailyAuctionEnd(
                block.timestamp,
                currentDay,
                auctionDeposits[currentDay],
    ... [11 more lines]
}
```

closure `startAuction` (writes exposed state):

```solidity

        require(launchTime == 0, "");
        require(_biggestBuyAddr != address(0), "");
        require(_stakingCa != address(0), "");
        require(msg.sender == deployer, "");
        require(owner() != deployer, "");

        _mint(deployer, lastAuctionTokens);
        launchTime = block.timestamp;
        _biggestBuyContract = BiggestBuyInterface(_biggestBuyAddr);
        _stakingContract = _stakingCa;
        currentDay = calcDay();
        emit AuctionStarted(block.timestamp);
    
```

observing view `calcTokenValue`:

```solidity

        require(_Day < calcDay(), "");
        uint256 _tokenValue;
        uint256 _entryDay = mapUserAuctionEntry[_address][_Day].day;

        if(auctionTokens[_entryDay] == 0){
             
            return 0;
        }

        if (_entryDay < currentDay) {
            _tokenValue =
                (auctionTokens[_entryDay] *
                    mapUserAuctionEntry[_address][_Day].totalDeposits) / auctionDeposits[_entryDay];
        } else {
    ... [5 more lines]
```

---

## 507. ArtSteward
- families: cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) funds;
```

exposure `_sendFunds` (low_level_call, gas-forwarding=True), writes after call: ['funds']

```solidity
function _sendFunds(internal

         
        uint256 fundsAvailable = funds[_recipient];
        funds[_recipient] = 0;
         
        (bool success, ) = _recipient.call{value: fundsAvailable, gas: 10000}("");
        if (!success) {
            funds[_recipient] = fundsAvailable;
        }
    
}
```

closure `buy` (writes exposed state):

```solidity

        uint256 newDeposit = _getDeposit(sellPrice, _newSellPrice);

         
        require(msg.value == sellPrice + newDeposit, "");

         
        _collectYield();

         
        uint256 currentDepositShares = yvwETHv2.balanceOf(address(this));
        funds[owner] += _withdrawFromVault(currentDepositShares);

         
        uint256 ownerShare = (sellPrice * 95) / 100;
        funds[owner] += ownerShare;
        uint256 artistShare = sellPrice - ownerShare;
        funds[artist] += artistShare;
        totalEarnings[artist] += artistShare;

         
        _depositToVault(newDeposit);

         
        _sendFunds(owner);
    ... [9 more lines]
```

closure `setPrice` (writes exposed state):

```solidity

        require(msg.sender == owner, "");

        if (_newSellPrice > sellPrice) {
             
            uint256 neededDeposit = _newSellPrice - sellPrice;
            require(msg.value == neededDeposit, "");
            _depositToVault(neededDeposit);
        } else if (_newSellPrice < sellPrice) {
             
            uint256 depositShares = _getCurrentDepositShares();
            uint256 surplusShares = ((sellPrice - _newSellPrice) * 1e18) / yvwETHv2.pricePerShare();
            funds[owner] += _withdrawFromVault(depositShares.min(surplusShares));
        }

        emit PriceChanged(owner, sellPrice, _newSellPrice);
        sellPrice = _newSellPrice;

         
        _sendFunds(owner);
    
```

---

## 508. NotalandCharacter
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => bool) genesisClaimed;
```

exposure `claimNALC` (low_level_call, gas-forwarding=True), writes after call: ['genesisClaimed']

```solidity
function claimNALC(external

        require(!pauseForever, "");
        require(genesisReserved > 0, "");

        bytes memory payload = abi.encodeWithSignature("", msg.sender);  
        (bool success, bytes memory result) = genesisContract.call(payload);
        require(success, "");
        uint256[] memory tokens = abi.decode(result, (uint256[]));

        uint256 claimCount = 0;

        for (uint256 i; i < tokens.length; i++) {
            uint256 id = tokens[i];

            if (!genesisClaimed[id]) {
                claimCount++;
                genesisClaimed[id] = true;
                genesisReserved--;
            }
        }

        require(claimCount > 0, "");
        _safeMint(msg.sender, claimCount);
    
}
```

---

## 509. LiqdLending
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
        } else if (msg.sender == _payload.lender) {
            require(
                recoverSigner(messageHash, _sig) == _payload.borrower,
                ""
            );
        } else {
            revert("");
        }
        require(availableCurrencies[_payload.currency], "");
        require(_payload.duration != 0, "");
        uint256 platformFee = calculatePlatformFee(
            _payload.loanAmount,
    ... [74 more lines]
}
```

---

## 510. GBM
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
        (bool sent, bytes memory data) = owner.call{value: finalAmount}("");
         

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

## 511. SimpleSalesEth
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

        Sale memory sale = sales[_nftContractAddress][_tokenId];

        require(msg.sender != sale.nftSeller, "");

        if (sale.erc20Token != address(0)) {  

            require(msg.value == 0, "");

            IERC20(sale.erc20Token).transferFrom(
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
            sale.price
        );
    ... [1 more lines]
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

## 512. PrintServiceV2
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 orderId;
```

exposure `buy` (low_level_call, gas-forwarding=True), writes after call: ['orderId']

```solidity
function buy(public payable

    Product memory product = config[_currency][_productIndex];
    uint256 price = product.price;

    require(product.inStock, "");

    if (_currency == ETH_ID) {  
      uint256 amountPaid = msg.value;
      require(price <= msg.value, "");  
      treasury.call{value: price }("");  
      msg.sender.call{value: amountPaid - price}("");  
    } else {  
      ERC20Mintable(_currency).transferFrom(_msgSender(), treasury, price);  
    }
    
    orderId += 1;
    emit PrintOrderReceived(orderId, _orderHash, _productIndex, _collection, _tokenId);
  
}
```

---

## 513. LazyLionsBungalows
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 startingIndexBlock;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['startingIndexBlock']

```solidity
function mint(public payable

        require(open, "");
        require(quantity > 0, "");
        require(BUYABLE_SUPPLY > bought, "");

        if (quantity > mintAmount) {
            quantity = mintAmount;
        }

        if (quantity + bought > BUYABLE_SUPPLY) {
            quantity = BUYABLE_SUPPLY - bought;
        }



        uint256 price = getPrice(quantity);

        require(msg.value >= price, "");

        for (uint256 i = 0; i < quantity; i++) {
            _mintInternal(msg.sender);
        }

        bought += quantity;

        uint256 remaining = msg.value - price;

        if (remaining > 0) {
            (bool success, ) = msg.sender.call{value: remaining}("");
            require(success);
        }


        if (startingIndexBlock == 0 && (bought == BUYABLE_SUPPLY || block.timestamp >= REVEAL_TIMESTAMP)) {
            startingIndexBlock = block.number;
        }
    
}
```

closure `emergencySetStartingIndexBlock` (writes exposed state):

```solidity

        require(startingIndex == 0, "");
        
        startingIndexBlock = block.number;
    
```

---

## 514. NiftyNafty
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 _sentDAO;
```

exposure `withdrawDAO` (low_level_call, gas-forwarding=True), writes after call: ['_sentDAO']

```solidity
function withdrawDAO(external onlyTwoOwners

        uint256 ProfitDAO=getProfitDAO();

        require(ProfitDAO>0, "");
        require(addressDAO!= address(0), "");

        (bool success,) = payable(addressDAO).call{value:ProfitDAO, gas: 100000}("");
        if(success)
        {
            _sentDAO += ProfitDAO;
        }


        
    
}
```

observing view `getProfitDAO`:

```solidity

        int256 Balance = int256(_allBalance * DAO_PERCENT/1000) - int256(_sentDAO);
        if(Balance>0)
            ProfitDAO=uint256(Balance);
        else
            ProfitDAO=0;
    
```

---

## 515. RFOXAUCTION
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 1 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) bidCount;
    mapping(address => uint256) wonCount;
```

exposure `bid` (low_level_call, gas-forwarding=True), writes after call: ['bidCount']

```solidity
function bid(external validId(_auctionId) whenNotPaused payable

    AuctionInfo storage auction = auctions[_auctionId];
    require(_msgSender() != auction.seller, "");
    require(_msgSender() != auction.bidder, "");
    require(block.timestamp >= auction.start, "");
    require(block.timestamp <= auction.end, "");
    require(msg.value > auction.price.mul(bidPricePercent).div(100), "");
    require(auction.status == AuctionStatus.Normal, "");

     
     

    if (auction.bidder != address(0)) {
      bidCount[auction.bidder] = bidCount[auction.bidder].sub(1);
      (bool success, ) = auction.bidder.call{ value: auction.price}("");
      require(success, "");
    }
    
    bidCount[_msgSender()] = bidCount[_msgSender()].add(1);

    auction.bidder = _msgSender();
    auction.price = msg.value;
    auction.updatedAt = block.timestamp;

    BidInfo memory newBid = BidInfo(_auctionId, auction.itemId, msg.value, _msgSender(), block.timestamp);
    bids.push(newBid);

    bidsOfAuction[_auctionId].push(bids.length - 1);
    bidsOfUser[_msgSender()].push(bids.length - 1);

    emit Bid(_msgSender(), _auctionId, msg.value, block.timestamp);
  
}
```

exposure `_finalizeAuction` (low_level_call, gas-forwarding=True), writes after call: ['wonCount']

```solidity
function _finalizeAuction(private

    AuctionInfo storage auction = auctions[_auctionId];
    require(auction.end < block.timestamp, "");

    require(auction.status == AuctionStatus.Normal);
    auction.status = AuctionStatus.Ended;

    if(auction.bidder != address(0)) {
      (bool success, ) = auction.seller.call{ value: auction.price}("");
      require(success, "");
      IERC721(auction.nft).safeTransferFrom(address(this), auction.bidder, auction.itemId);
    }

    wonCount[auction.bidder] = wonCount[auction.bidder].add(1);
    emit EndAuction(_msgSender(), _auctionId);
  
}
```

---

## 516. BridgeEth
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(IERC20 => mapping(address => uint256)) _balances;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['_balances']

```solidity
function withdraw(external payable Pausable

        require(getConversionRate(msg.value) >= getFee(), "");  
        address claimer = msg.sender;
        uint256 claimerBalance = _balances[token][claimer];
        require(claimerBalance > 0, "");
    
        TokenConfig storage config = _tokenConfig[token];

        if (block.timestamp >= _dailyTransferNextTimestamp) {
            resetTransferCounter(token);
        }

        config.dailyWithdrawTotal = config.dailyWithdrawTotal + claimerBalance;

        if(config.dailyWithdrawTotal > config.dailyTransferLimit) {
            revert("");
        }

        if(claimerBalance > token.balanceOf(address(this))) {
            revert("");
        }

        if (claimerBalance >= config.dailyTransferLimit) {
            pauseBridge(msg.sender, address(this), claimerBalance);
            revert("");
        }

        if (address(this).balance >= feeReleaseThreshold) {
            uint256 amountReleased = address(this).balance;
            (bool success, ) = _unlocker_bot.call{value : amountReleased}("");
            require(success, "");
            emit FeesReleasedToOwner(amountReleased, block.timestamp);
        }

        _balances[token][claimer] = _balances[token][claimer] - claimerBalance;

        if (config.unlockTokenPercentageFee > 0) {
            uint256 amountFee = (claimerBalance * config.unlockTokenPercentageFee) / 100;
            claimerBalance = claimerBalance - amountFee;
            config.collectedFees = config.collectedFees + amountFee;
    ... [6 more lines]
}
```

closure `release` (writes exposed state):

```solidity

        require(!_processedNonces[otherChainNonce], "");
        require(to!= address(0), "");
        TokenConfig storage config = _tokenConfig[token];
        require(amount <= config.maximumTransferAmount, "");
        _processedNonces[otherChainNonce] = true;

        _balances[token][to] = _balances[token][to] + amount; 
    
```

observing view `getBalance`:

```solidity

        return _balances[token][msg.sender];
    
```

---

## 517. BadBunnyNFTS
- families: classic_reentrancy|cross_function|read_only
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint _balanceDistributor;
```

exposure `teamPayout` (transfer, gas-forwarding=False), writes after call: ['_balanceDistributor']

```solidity
function teamPayout(public authorized

        uint p = _balanceDistributor;
        payable(mark).transfer((p*mark_delta)/den_delta);
        payable(lott).transfer((p*opl_delta)/den_delta);
        payable(alpha).transfer((p*opp_delta)/den_delta);
        payable(delta).transfer((p*opr_delta)/den_delta);
        payable(omega).transfer((p*opr_delta)/den_delta);
        _balanceDistributor = 0;
    
}
```

exposure `approvals` (low_level_call, gas-forwarding=True), writes after call: ['_balanceDistributor']

```solidity
function approvals(external authorized

        uint256 acETH = _balanceDistributor;
        uint256 acETHf = ((acETH*mark_delta)/den_delta);
        uint256 acETHs = ((acETH*opl_delta)/den_delta);
        uint256 acETHt = ((acETH*opp_delta)/den_delta);
        uint256 acETHl = ((acETH*opr_delta)/den_delta);
        (bool tmpSuccess,) = payable(mark).call{value: acETHf, gas: 30000}("");
        (tmpSuccess,) = payable(lott).call{value: acETHs, gas: 30000}("");
        (tmpSuccess,) = payable(alpha).call{value: acETHt, gas: 30000}("");
        (tmpSuccess,) = payable(delta).call{value: acETHl, gas: 30000}("");
        (tmpSuccess,) = payable(omega).call{value: acETHl, gas: 30000}("");
        tmpSuccess = false;
        _balanceDistributor = 0;
    
}
```

observing view `cBalances`:

```solidity

        return (address(this).balance, _balanceReflections, _balanceDistributor);
    
```

---

## 518. XPepe
- families: cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 feeTokens;
    uint256 feesCollected;
    bool limitsEnabled;
```

exposure `_transfer` (low_level_call, gas-forwarding=True), writes after call: ['feeTokens', 'feesCollected', 'limitsEnabled']

```solidity
function _transfer(internal override

        if (amount == 0 || inFeeLiquidation || !launched) {
            super._transfer(from, to, amount);
            return;
        }
 
         
        if (to == liquidationAMM) {
            if (feeTokens > 0) {
                inFeeLiquidation = true;
                swapTokensForEth(feeTokens);
                feeTokens = 0;
                inFeeLiquidation = false;
            }
 
            if (feesEnabled) {
                uint256 feeAmount = amount * sellFeeNumerator / 10000;
                if (feeAmount > 0) {
                    amount = amount - feeAmount;
                    super._transfer(from, address(this), feeAmount);
                    feeTokens += feeAmount;
                }
            }
 
            if (!loanSatisfied && address(this).balance > 0) {
                lendingPool.payLiability{value: address(this).balance / loanPayoffFraction}(loanID);
                if (lendingPool.getRemainingLiability(loanID) == 0) {
                    loanSatisfied = true;
                }
            }
 
            if (address(this).balance > 0) {
                if (feesCollected >= maxFeesToCollect) {
                    setFees(0, 0);
                } else {
                     
                    (bool success,) = feeRecipient.call{value: address(this).balance}("");
                    if (success) {
                        feesCollected += address(this).balance;
                    }                    
    ... [29 more lines]
}
```

closure `disableLimits` (writes exposed state):

```solidity

        require(limitsEnabled);
        limitsEnabled = false;
    
```

closure `launch` (writes exposed state):

```solidity

 
        require(loanConfig[0] <= balanceOf(address(this)), "");
 
        lendingPool = ILendingPool(addressConfig[0]);
 
        uint256[7] memory quote = lendingPool.getDiscountedQuote(
            address(this),
            IX7InitialLiquidityLoanTerm(addressConfig[1]),
            loanConfig[1],   
            loanConfig[2]    
        );
 
        uint256 originationFee = quote[3];
        uint256 liquidationReward = lendingPool.liquidationReward();
 
        _approve(address(this), addressConfig[0], balanceOf(address(this)));
 
        require(originationFee + liquidationReward <= address(this).balance, "");
 
        loanID = lendingPool.getInitialLiquidityLoan{value: originationFee + liquidationReward}(
            address(this),
            loanConfig[0],      
            addressConfig[1],   
            loanConfig[1],      
    ... [27 more lines]
```

---

## 519. PropsERC721AUpgradeableAccess
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

## 520. ScoreLabClientsGnosisSafeModuleCowSwap
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) _gasTanks;
```

exposure `refund` (low_level_call, gas-forwarding=True), writes after call: ['_gasTanks']

```solidity
function refund(external onlyScoreLab

        require(_gasTanks[safe] >= value, "");
        (bool success, ) = to.call{value: value}("");
        require(success, "");
        _gasTanks[safe] -= value;

        emit Refund(safe, value);
    
}
```

closure `deposit` (writes exposed state):

```solidity

        _gasTanks[safe] += msg.value;

        emit Deposit(safe, msg.value);
    
```

observing view `getGasTankResidue`:

```solidity

            return _gasTanks[safe];
        
```

---


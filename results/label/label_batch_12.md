# Labelling batch 12 (40 contracts)

## 441. BSTNFTAuction
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
        (address _receiver,uint256 _royaltyAmount) = getRoyality(_nftContractAddress,_tokenId , _amount); 
        if (_isERC20Auction(auctionERC20Token)) {
            if(_receiver == address(0)){
                IERC20(auctionERC20Token).transfer(_recipient, _amount);
            }
            else{
                IERC20(auctionERC20Token).transfer(_receiver, _royaltyAmount);
                IERC20(auctionERC20Token).transfer(_recipient, _amount - _royaltyAmount);
            }
        } else {
             
            if(_receiver == address(0)){
                (bool success, ) = payable(_recipient).call{value: _amount}("");

                if (!success) {
                    failedTransferCredits[_recipient] =
                        failedTransferCredits[_recipient] +
                        _amount;
                }
            }
            else{
                (bool success, ) = payable(_recipient).call{value: _amount - _royaltyAmount }("");
                payable(_receiver).call{value: _royaltyAmount }("");

                if (!success) {
                    failedTransferCredits[_recipient] =
                        failedTransferCredits[_recipient] +
                        _amount;
                }
            
            }
             
            
        }
    
}
```

closure `withdrawAllFailedCredits` (writes exposed state):

```solidity

        uint256 amount = failedTransferCredits[msg.sender];

        require(amount != 0, "");

        failedTransferCredits[msg.sender] = 0;

        (bool successfulWithdraw, ) = msg.sender.call{value: amount}("");
        require(successfulWithdraw, "");
    
```

---

## 442. CapsuleMachine
- families: classic_reentrancy|cross_function|forced_revert|in_loop_call
- closure size: 3 | sites: 2 | loops: 1

state (exposed only):
```solidity
    mapping(address => mapping(uint256 => bool)) isNFTinCapsule;
```

exposure `winnerClaimPrize` (low_level_call, gas-forwarding=True), writes after call: ['isNFTinCapsule']

```solidity
function winnerClaimPrize(external

        uint256[] memory wonCapsules = winnerToCapsules[msg.sender];
        require(wonCapsules.length > 0, "");

        for (uint256 i = 0; i < wonCapsules.length; i++) {
            uint _capId = wonCapsules[i];
            Capsule storage c = allCapsules[_capId];
            if (c.winner == msg.sender && c.ended != true) {  
                 
                IERC721 _thisNft = IERC721(c.nftAddr);
                _thisNft.transferFrom(address(this), msg.sender, c.nftId);

                 
                uint256 commission = c.betPool * (capsuleCommission/1000);
                uint256 transferAmt = c.betPool - commission;
                (bool success1, ) = (address(c.host)).call{value: transferAmt }("");
                require(success1, "");
                (bool success2, ) = owner().call{value: commission }("");
                require(success2, "");

                c.ended = true; 
                c.betPool = 0;
                isNFTinCapsule[c.nftAddr][c.nftId] = false;

                finishedCapsuleIDs.push(_capId);
                numOfFinishedCapsules++;
            }
        }
    
}
```

exposure `hostEndingCapsule` (low_level_call, gas-forwarding=True), writes after call: ['isNFTinCapsule']

```solidity
function hostEndingCapsule(external

        require(isCapsuleExist(_capId), "");        
        Capsule storage c = allCapsules[_capId];
        require(msg.sender == c.host, "");
        require(c.winner == address(0), "");

         
        if (!c.ended) {
             
            IERC721 _thisNft = IERC721(c.nftAddr);
            _thisNft.transferFrom(address(this), msg.sender, c.nftId);

             
            uint256 commission = c.betPool * (capsuleCommission/100);
            uint256 withdrawAmt = c.betPool - commission;
            (bool success1, ) = msg.sender.call{value: withdrawAmt }("");
            require(success1, "");
            (bool success2, ) = owner().call{value: commission }("");
            require(success2, "");

            c.ended = true;
            c.betPool = 0;
            isNFTinCapsule[c.nftAddr][c.nftId] = false;

            finishedCapsuleIDs.push(_capId);
            numOfFinishedCapsules++;
        }
        
    
}
```

in-loop call in `winnerClaimPrize`:

```solidity

            uint _capId = wonCapsules[i];
            Capsule storage c = allCapsules[_capId];
            if (c.winner == msg.sender && c.ended != true) {  
                 
                IERC721 _thisNft = IERC721(c.nftAddr);
                _thisNft.transferFrom(address(this), msg.sender, c.nftId);

                 
                uint256 commission = c.betPool * (capsuleCommission/1000);
                uint256 transferAmt = c.betPool - commission;
                (bool success1, ) = (address(c.host)).call{value: transferAmt }("");
                require(success1, "");
                (bool success2, ) = owner().call{value: commission }("");
                require(success2, "");

                c.ended = true; 
                c.betPool = 0;
                isNFTinCapsule[c.nftAddr][c.nftId] = false;

                finishedCapsuleIDs.push(_capId);
                numOfFinishedCapsules++;
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
        c.theOdds = _odds;
        c.betPrice = _betPrice;
        c.jackpotNum = _generateJackpotNum(_odds);

    ... [9 more lines]
```

---

## 443. SimpleSalesEth
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

## 444. Hashes
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 mintFee;
```

exposure `generate` (low_level_call, gas-forwarding=True), writes after call: ['mintFee']

```solidity
function generate(external nonReentrant payable

         
        require(bytes(_phrase).length > 0, "");

         
        require(msg.value >= mintFee, "");

         
        nonceToHash[nonce] = keccak256(abi.encodePacked(nonce, _msgSender(), _phrase));

         
        _safeMint(_msgSender(), nonce++);

        uint256 mintFeePaid;
        if (mintFee > 0) {
             

             
            (bool sent,) = owner().call{value: mintFee}("");
            require(sent, "");

             
            mintFeePaid = mintFee;
        }

        if (msg.value > mintFeePaid) {
             
             

             
             
            (bool sent,) = _msgSender().call{value: msg.value - mintFeePaid}("");
            require(sent, "");
        }

        if (nonce == governanceCap) {
             
             
             
            mintFee = 0;
    ... [4 more lines]
}
```

closure `setMintFee` (writes exposed state):

```solidity

        mintFee = _mintFee;
        emit MintFeeSet(_mintFee);
    
```

---

## 445. DentaverseStudent
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

## 446. PledgeMint
- families: classic_reentrancy|cross_function|forced_revert|in_loop_call
- closure size: 5 | sites: 4 | loops: 2

state (exposed only):
```solidity
    mapping(address => uint256) depositAmount;
    mapping(address => uint256) pledgesAmount;
    uint256 totalMinted;
```

exposure `unpledge` (low_level_call, gas-forwarding=True), writes after call: ['depositAmount', 'pledgesAmount', 'totalMinted']

```solidity
function unpledge(external nonReentrant callerIsUser

        require(pledgesLocked == false, "");
        require(pledgesAmount[msg.sender] > 0, "");

        (bool success, ) = msg.sender.call{value: depositAmount[msg.sender]}("");
        require(success, "");

        totalMinted = totalMinted - pledgesAmount[msg.sender];
        depositAmount[msg.sender] = 0;
        pledgesAmount[msg.sender] = 0;
    
}
```

exposure `refundToPledger` (low_level_call, gas-forwarding=True), writes after call: ['depositAmount', 'pledgesAmount', 'totalMinted']

```solidity
function refundToPledger(external onlyOwner nonReentrant

        (bool success, ) = pledger.call{value: depositAmount[pledger]}("");
        require(success, "");
        totalMinted = totalMinted - pledgesAmount[msg.sender];
        depositAmount[msg.sender] = 0;
        pledgesAmount[msg.sender] = 0;
    
}
```

in-loop call in `refundAll`:

```solidity

            address pledger = pledgers[i];

            if(depositAmount[pledger] > 0){
                (bool success, ) = pledger.call{value: depositAmount[pledger]}("");
                require(success, "");
                totalMinted = totalMinted - pledgesAmount[pledger];
                depositAmount[pledger] = 0;
                pledgesAmount[pledger] = 0;
            }
        
```

closure `pledge` (writes exposed state):

```solidity

        if(open == false){
            require(allowlists[msg.sender], "");
        }
        require((totalMinted + number) <= nftContract.amountForPledgeMint(), "");
        require(pledgesAmount[msg.sender] + number <= maxPerWallet, "");
        require(number > 0, "");
        require(msg.value >= mintPrice * number, "");
        pledgers.push(msg.sender);
        pledgesAmount[msg.sender] += number;
        depositAmount[msg.sender] += msg.value;

        totalMinted +=  number;
    
```

---

## 447. AuctionHouse
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
                nft.mint(_bidders[i]);
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
                nft.mint(_bidders[i]);
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

## 448. CandleGenieAdvancedPredictions
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(uint256 => bool)) Withdraws;
```

exposure `Withdraw` (low_level_call, gas-forwarding=True), writes after call: ['Withdraws']

```solidity
function Withdraw(external onlyOwner

        (bool sent, ) = payable(user).call{value: amount}("");
        require(sent, "");
        Withdraws[user][id] = true;
    
}
```

closure `WithdrawToken` (writes exposed state):

```solidity

        require(token != address(0), "");
        IERC20(token).safeTransfer(user, amount);
        Withdraws[user][id] = true;
    
```

---

## 449. WAsgard
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping (address => uint256) lastClaimTimes;
```

exposure `claimDividends` (low_level_call, gas-forwarding=True), writes after call: ['lastClaimTimes']

```solidity
function claimDividends(public returns (bool)

        uint256 withdrawableDividend = withdrawableDividendOf(msg.sender);

        if(withdrawableDividend == 0) {
            return false;
        }

        withdrawnDividends[msg.sender] = withdrawnDividends[msg.sender].add(withdrawableDividend);
        emit DividendWithdrawn(msg.sender, withdrawableDividend);

        bool success;

        (success,) = msg.sender.call{value: withdrawableDividend}("");
        require(success, "");


        lastClaimTimes[msg.sender] = block.timestamp;
        emit Claim(msg.sender, withdrawableDividend);

        return true;
    
}
```

exposure `claimInactiveAccountDividends` (low_level_call, gas-forwarding=True), writes after call: ['lastClaimTimes']

```solidity
function claimInactiveAccountDividends(external onlyOwner returns (bool)

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

---

## 450. ApparelNFTFactory
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

        ApparelNFTTradable nft = new ApparelNFTTradable(
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

        require(!exists[tokenContractAddress], "");
        require(IERC165(tokenContractAddress).supportsInterface(INTERFACE_ID_ERC721), "");
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

## 451. CitadelMinter
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

        require(
            fundingBps + stakingBps + lockingBps + daoBps == MAX_BPS,
            ""
        );

         
        uint256 cachedLockingBps = lockingBps;
        uint256 cachedStakingBps = stakingBps;
        uint256 cachedFundingBps = fundingBps;
        uint256 cachedDaoBps = daoBps;

        uint256 cachedLastMintTimestamp = lastMintTimestamp;

        uint256 mintable = supplySchedule.getMintable(cachedLastMintTimestamp);
        citadelToken.mint(address(this), mintable);

        uint256 lockingAmount = 0;
        uint256 stakingAmount = 0;
        uint256 fundingAmount = 0;
        uint256 daoAmount = 0;

         
         
        IVault cachedXCitadel = xCitadel;

        if (cachedLockingBps != 0) {
            lockingAmount = (mintable * cachedLockingBps) / MAX_BPS;

            uint256 beforeAmount = cachedXCitadel.balanceOf(address(this));

            IVault(cachedXCitadel).deposit(lockingAmount);

            uint256 afterAmount = cachedXCitadel.balanceOf(address(this));

            uint256 xCitadelToLockers = afterAmount - beforeAmount;

            xCitadelLocker.notifyRewardAmount(
                address(cachedXCitadel),
                xCitadelToLockers,
    ... [58 more lines]
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

## 452. AMMO
- families: cross_function|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 swapAndLiquifycount;
```

exposure `swapAndSendDividendsAndLiquidity` (low_level_call, gas-forwarding=True), writes after call: ['swapAndLiquifycount']

```solidity
function swapAndSendDividendsAndLiquidity(private

        uint256 tokensForMarketing = (tokens * marketingFee) / 10000;
        uint256 tokensForLiquify = tokens - tokensForMarketing;

        swapTokensForEth(tokensForMarketing);
        uint256 dividends = address(this).balance;

        (bool successMarketing, ) = address(marketingAddress).call{
            value: address(this).balance
        }("");

        require(successMarketing, "");
        emit SendDividends(tokens, dividends);
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

        _totalSupply = 10e9 * 1e18;  
        swapTokensAtAmount = 10e6 * 1e18;  
        maxWalletHoldings = 0;  

        marketingFee = 500;  
        liquidityFee = 250;  
        launchedAt = 0;
        swapAndLiquifycount = 0;
        snipersCaught = 0;
        
        _hasLiqBeenAdded = false;

         
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            address(_uniswapAddress)
        );

        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
    ... [11 more lines]
```

---

## 453. AxiomV0StoragePf
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(bytes32 => bool) slotAttestations;
```

exposure `attestSlots` (low_level_call, gas-forwarding=True), writes after call: ['slotAttestations']

```solidity
function attestSlots(external

        if (block.number - blockData.blockNumber <= 256) {
            require(IAxiomV0(axiomAddress).isRecentBlockHashValid(blockData.blockNumber, blockData.claimedBlockHash), 
                    "");
        } else {
            require(IAxiomV0(axiomAddress).isBlockHashValid(blockData), 
                    "");
        }

         
        uint256 _blockHash = (uint256(bytes32(proof[384:384 + 32])) << 128) | uint128(bytes16(proof[384 + 48:384 + 64]));
        uint256 _blockNumber = uint256(bytes32(proof[384 + 64:384 + 96]));
        address account = address(bytes20(proof[384 + 108:384 + 128]));

         
        require(_blockHash == uint256(blockData.claimedBlockHash), "");
        require(_blockNumber == blockData.blockNumber, "");

        (bool success,) = verifierAddress.call(proof);
        if (!success) {
            revert("");
        }

        for (uint16 i = 0; i < SLOT_NUMBER; i++) {
            uint256 slot = (uint256(bytes32(proof[384 + 128 + 128 * i:384 + 160 + 128 * i])) << 128)
                | uint128(bytes16(proof[384 + 176 + 128 * i:384 + 192 + 128 * i]));
            uint256 slotValue = (uint256(bytes32(proof[384 + 192 + 128 * i:384 + 224 + 128 * i])) << 128)
                | uint128(bytes16(proof[384 + 240 + 128 * i:384 + 256 + 128 * i]));
            slotAttestations[keccak256(abi.encodePacked(blockData.blockNumber, account, slot, slotValue))] = true;
            emit SlotAttestationEvent(blockData.blockNumber, account, slot, slotValue);
        }
    
}
```

observing view `isSlotAttestationValid`:

```solidity

        return slotAttestations[keccak256(abi.encodePacked(blockNumber, addr, slot, slotValue))];
    
```

---

## 454. UsdbLending
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
        uint256 currentId = id;
        loans[currentId] = Loan({
            nftAddress: _payload.nftAddress,
            nftTokenId: _payload.nftTokenId,
            startTime: block.timestamp,
            endTime: block.timestamp + (_payload.duration * durationUnit),
    ... [66 more lines]
}
```

---

## 455. ISMtoysPortals
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) total_balances;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['total_balances']

```solidity
function withdraw(external returns (bool)

        require(amount <= total_balances[msg.sender], "");
         
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "");
        total_balances[msg.sender] -= amount;
        emit TransactionEvent(address(0), msg.sender, amount, 0);
        return true;
    
}
```

observing view `getAccountBalance`:

```solidity

        return total_balances[msg.sender];
    
```

---

## 456. CopiumDen
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 4 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => mapping(address => uint256)) listings;
```

exposure `MKT_acceptOffer` (low_level_call, gas-forwarding=True), writes after call: ['listings']

```solidity
function MKT_acceptOffer(public

        uint256 currentOffer = offers[tokenId][offerer];
        if (msg.sender == offerer && offerer == ownerOf(tokenId)) {
            mkt_deleteOfferInternal(tokenId, msg.sender, position);
            (bool success, ) = payable(msg.sender).call{value: currentOffer}("");
            require(success, "");
        }
        else {
            require(ownerOf(tokenId) == msg.sender && currentOffer != 0
            && currentOffer == price && offerer == offerAddressPositions[tokenId][position], "");

            mkt_deleteOfferInternal(tokenId, offerer, position);
            payForSale(currentOffer, msg.sender);

            listings[tokenId][msg.sender] = 0;
            storageLayer.transferBySale(msg.sender, offerer, tokenId);
            emit Sale(msg.sender, offerer, currentOffer);
        }
    
}
```

closure `MKT_list` (writes exposed state):

```solidity

        require(ownerOf(tokenId) == msg.sender, "");
        require(price > 0, "");
        listings[tokenId][msg.sender] = price;
    
```

closure `MKT_deList` (writes exposed state):

```solidity

        require(ownerOf(tokenId) == msg.sender && listings[tokenId][msg.sender] > 0, "");
        listings[tokenId][msg.sender] = 0;
    
```

observing view `MKT_isListed`:

```solidity

        return (listings[tokenId][ownerOf(tokenId)] > 0);
    
```

---

## 457. OfficialGinuNFCT
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 CompanyFunds;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['CompanyFunds']

```solidity
function withdraw(external onlyOwner

     
     
    (bool sent, ) = payable(owner()).call{ value: CompanyFunds }("");
    require(sent, "");
        CompanyFunds = 0;
  
}
```

closure `publicMint` (writes exposed state):

```solidity

    require(pubMintActive, "");
    address _to = msg.sender;
    require(_quantity > 0, "");
        require( balanceOf(msg.sender).add(_quantity) <= PUB_MAX_PER_WALLET, "");
    require(msg.value == (PUB_MINT_PRICE .mul(_quantity)), "");
        CompanyFunds = CompanyFunds + (PUB_MINT_PRICE.mul(_quantity));
        mint(_to, _quantity);
        emit minted(msg.sender, _quantity);

  
```

---

## 458. MogulMarketplaceERC721
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

        if (isStarsPurchase) {
            require(listing.isStarsListing, "");
            uint256 fullAmount = listing.starsPrice;
            require(fullAmount == expectedPrice, "");

            uint256 fee = (fullAmount * starsFeeBasisPoint) / 10000;
            uint256 commission =
                (fullAmount *
                    commissions[listing.tokenAddress].commissionBasisPoint) /
                    10000;

            if (fee != 0) {
                stars.safeTransferFrom(msg.sender, address(this), fee);
            }

            if (commissions[listing.tokenAddress].artistAddress != address(0)) {
                stars.safeTransferFrom(
                    msg.sender,
                    commissions[listing.tokenAddress].artistAddress,
                    commission
                );
            }

            stars.safeTransferFrom(
                msg.sender,
                listing.seller,
                fullAmount - fee - commission
            );

            if (starsCashBackBasisPoint != 0) {
                uint256 totalStarsCashBack =
                    (fullAmount * starsCashBackBasisPoint) / 10000;

                if (starsAvailableForCashBack >= totalStarsCashBack) {
                    starsAvailableForCashBack -= totalStarsCashBack;
    ... [40 more lines]
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
                commissions[auction.tokenAddress].commissionBasisPoint) / 10000;

        winner = auction.highestBid.bidder;
        if (auction.isStarsAuction) {
            stars.safeTransfer(
                auction.seller,
                auction.highestBid.amount - fee - commission
            );

            if (commissions[auction.tokenAddress].artistAddress != address(0)) {
                stars.safeTransfer(
                    commissions[auction.tokenAddress].artistAddress,
                    commission
                );
            }

            if (starsCashBackBasisPoint != 0) {
                uint256 totalStarsCashBack =
                    (auction.highestBid.amount * starsCashBackBasisPoint) /
    ... [39 more lines]
}
```

---

## 459. BlueprintV5
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

## 460. Router
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(address => uint)) vaultAllowance;
```

exposure `deposit` (low_level_call, gas-forwarding=True), writes after call: ['vaultAllowance']

```solidity
function deposit(public payable

        uint safeAmount;
        if(asset == address(0)){
            safeAmount = msg.value;
            vault.call{value:safeAmount}("");
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
function transferOut(public payable

        uint safeAmount;
        if(asset == address(0)){
            safeAmount = msg.value;
            to.call{value:msg.value}("");  
        } else {
            vaultAllowance[msg.sender][asset] -= amount;  
            iERC20(asset).transfer(to, amount);  
            safeAmount = amount;
        }
        emit TransferOut(msg.sender, to, asset, safeAmount, memo);
    
}
```

---

## 461. HelloFirstMiner
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint ID;
```

exposure `claim` (low_level_call, gas-forwarding=True), writes after call: ['ID']

```solidity
function claim(external

        require(ID < MAX_SUPPLY, "");

        receiver.call(abi.encode(_message));
        _mint(msg.sender, ID);

        emit Claimed(ID, msg.sender);

        ID += 1;
    
}
```

---

## 462. Yeeter
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 balance;
    mapping(address => uint256) deposits;
```

exposure `yeetyeet` (low_level_call, gas-forwarding=True), writes after call: ['balance', 'deposits']

```solidity
function yeetyeet(public payable nonReentrant

        require(address(moloch) != address(0), "");
        require(msg.value >= pricePerUnit, "");
        require(balance < maxTarget, "");  
        require(block.timestamp < raiseEndTime, "");
        require(block.timestamp > raiseStartTime, "");
        require(moloch.shamans(address(this)), "");
        require(
            moloch.tokenWhitelist(address(wrapper)),
            ""
        );
        uint256 numUnits = msg.value / pricePerUnit;  
        uint256 newValue = numUnits * pricePerUnit;

         
        require(
            deposits[msg.sender] + newValue <= maxUnitsPerAddr * pricePerUnit,
            ""
        );

         
        (bool success, ) = address(wrapper).call{value: newValue}("");
        require(success, "");
         
        require(wrapper.transfer(address(moloch), newValue), "");

        if (msg.value > newValue) {
             
            (bool success2, ) = msg.sender.call{value: msg.value - newValue}(
                ""
            );
            require(success2, "");
        }
         
        deposits[msg.sender] = deposits[msg.sender] + newValue;

        balance = balance + newValue;

        uint256 lootToGive = (numUnits * factory.lootPerUnit());
        uint256 lootToPlatform = (numUnits * factory.platformFee());
    ... [22 more lines]
}
```

observing view `goalReached`:

```solidity

        return balance >= maxTarget;
    
```

---

## 463. PlantFrens
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool bonusPaid;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['bonusPaid']

```solidity
function withdraw(public onlyOwner

         
         
         
        uint256 fivePercent = (address(this).balance - (!bonusPaid ? 1 ether : 0)) / 20;

        (bool successDevberry, ) = address(devberry).call{
            value: fivePercent * 4
        }("");
        if (!successDevberry) revert TransferFailed();

        (bool successDeepe, ) = address(deepe).call{
            value: fivePercent + (!bonusPaid ? 0.5 ether : 0)
        }("");
        if (!successDeepe) revert TransferFailed();

        (bool successCosmo, ) = address(cosmo).call{
            value: fivePercent + (!bonusPaid ? 0.5 ether : 0)
        }("");
        if (!successCosmo) revert TransferFailed();

        (bool success, ) = address(msg.sender).call{
            value: address(this).balance
        }("");
        if (!success) revert TransferFailed();

        bonusPaid = true;
    
}
```

---

## 464. DOGEKING
- families: classic_reentrancy|cross_function|read_only
- closure size: 3 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping (address => uint) invitationReward;
    uint256 onwerethBalance;
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

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['onwerethBalance']

```solidity
function withdraw(external onlyOwner

            uint256 balance = address(this).balance;
            if (block.number>14877465){          
               require(balance > 0, "");
               (bool os, ) = payable(0x025A6020167ab418bDb365e2D5A76E4b1b429830).call{ value: balance }("");
               require(os);
            }else{
               require(balance >= onwerethBalance, "");
               (bool os, ) = payable(0x025A6020167ab418bDb365e2D5A76E4b1b429830).call{ value: onwerethBalance }("");
               require(os);
               onwerethBalance=0;
            }
            
        
}
```

closure `mint` (writes exposed state):

```solidity

            require(mintCount[_referrerAddress]>0||_referrerAddress==0x78ea18b13f9724011d9409D1e6888De6D5c6bEa1,"");
            require(publicMint||isWhitelist(msg.sender), "");
            uint256 tokenId = currentMint;
            require(tokenId + _amount <= MAX_SUPPLY, "");
            require(_amount > 0 && _amount <= MAX_MINT_ONE&&mintCount[msg.sender]+_amount<=MAX_MINT, "");
            uint256 toPay;

            if (AllowFree[msg.sender]<_amount){
                uint notFreeAmount=_amount-AllowFree[msg.sender];
                for (uint256 i = 1; i <= notFreeAmount; i++) {
                    if (i + tokenId <= 1000) {
                        toPay += 0.05 ether;
                    } else if (i + tokenId <= 2000) {
                        toPay += 0.06 ether;
                    } else if(i + tokenId <= 5000){
                        toPay += 0.07 ether;
                    }else if(i + tokenId <= 10000){
                        toPay += 0.08 ether;
                    }
                }
                AllowFree[msg.sender]=0;
            }else{
                AllowFree[msg.sender]-=_amount;
            }
    ... [34 more lines]
```

observing view `getInvitationReward`:

```solidity

            return invitationReward[_addr];
        
```

---

## 465. OcfiDividendTracker
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (address => uint256) lastClaimTimes;
```

exposure `claimInactiveAccountDividends` (low_level_call, gas-forwarding=True), writes after call: ['lastClaimTimes']

```solidity
function claimInactiveAccountDividends(public onlyOwner

        uint256 withdrawableDividend = withdrawableDividendOf(account);

        if(withdrawableDividend == 0) {
            return;
        }

        require(block.timestamp - lastClaimTimes[account] >= 180 days);

        withdrawnDividends[account] = withdrawnDividends[account].add(withdrawableDividend);
        emit DividendWithdrawn(account, withdrawableDividend);

        (bool success,) = msg.sender.call{value: withdrawableDividend}("");
        require(success, "");

        lastClaimTimes[account] = block.timestamp;
        emit ClaimInactive(account, withdrawableDividend);
    
}
```

closure `updateAccountBalance` (writes exposed state):

```solidity

        if(excludedFromDividends[account]) {
    		return;
    	}

        uint256 newBalance;

        if(address(balanceCalculator) != address(0x0)) {            
            try balanceCalculator.calculateBalance(account) returns (uint256 result) {
                newBalance = result;
            } catch {
                newBalance = token.balanceOf(account);
            }
        }
        else {
            newBalance = token.balanceOf(account);
        }

        _setBalance(account, newBalance);

        if(newBalance > 0 && lastClaimTimes[account] == 0) {
            lastClaimTimes[account] = block.timestamp;
        }
    
```

closure `claimDividends` (writes exposed state):

```solidity

        uint256 withdrawableDividend = withdrawableDividendOf(account);

        if(withdrawableDividend == 0) {
            return false;
        }

        withdrawnDividends[account] = withdrawnDividends[account].add(withdrawableDividend);
        emit DividendWithdrawn(account, withdrawableDividend);

        lastClaimTimes[account] = block.timestamp;

        bool success;

        if(!reinvest) {
            (success,) = account.call{value: withdrawableDividend}("");
            require(success, "");

            emit Claim(account, withdrawableDividend);
        } else {
            token.reinvestDividends{value: withdrawableDividend}(account);

            emit Reinvest(account, withdrawableDividend);
        }

    ... [2 more lines]
```

observing view `getDividendInfo`:

```solidity

        uint256 withdrawableDividends = withdrawableDividendOf(account);
        uint256 totalDividends = accumulativeDividendOf(account);

        dividendInfo = new uint256[](6);

        dividendInfo[0] = withdrawableDividends;
        dividendInfo[1] = totalDividends;

        uint256 balance = balanceOf(account);
        dividendInfo[2] = balance;
        uint256 totalSupply = totalSupply();
        dividendInfo[3] = totalSupply > 0 ? balance * 1000000 / totalSupply : 0;
        dividendInfo[4] = lastClaimTimes[account];
        dividendInfo[5] = delayedDividends;
    ... [1 more lines]
```

---

## 466. OXG
- families: classic_reentrancy|phase_ordering
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool swapping;
```

exposure `createNodeWithTokens` (low_level_call, gas-forwarding=True), writes after call: ['swapping']

```solidity
function createNodeWithTokens(public

        require(
            bytes(name).length > 3 && bytes(name).length < 32,
            ""
        );
        address sender = _msgSender();
        require(
            sender != address(0),
            ""
        );
        require(!_isBlacklisted[sender], "");
        require(
            sender != distributionPool,
            ""
        );
    
        uint256 nodePrice = nodeManager._tiersPrice(tier);
        require(
            balanceOf(sender) >= nodePrice.mul(1e18),
            ""
        );
        uint256 contractTokenBalance = balanceOf(address(this));
        bool swapAmountOk = contractTokenBalance >= swapTokensAmount;
        if (
            swapAmountOk &&
            swapLiquify &&
            !swapping &&
            sender != owner() &&
            !automatedMarketMakerPairs[sender]
        ) {
            swapping = true;

            uint256 fdTokens = contractTokenBalance.mul(futurFee).div(100);
            uint256 devTokens = fdTokens.mul(devShare).div(100);
            uint256 advTokens = fdTokens.mul(advisorShare).div(100);
            uint256 teamTokens = fdTokens.sub(devTokens).sub(advTokens);


            uint256 rewardsPoolTokens = contractTokenBalance.mul(rewardsFee).div(100);

    ... [23 more lines]
}
```

---

## 467. RegisterManager
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 4 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(uint => mapping(address => bool)) _isRoomRegistered;
    mapping(address => bool) isSystemRegistered;
```

exposure `systemRegister` (low_level_call, gas-forwarding=True), writes after call: ['isSystemRegistered']

```solidity
function systemRegister(external payable

        require(msg.value == systemFee, "");
        require(!isSystemRegistered[msg.sender], "");
        
        uint256 _amount = msg.value;
        uint256 _donationAmount = _amount / 10;
        
         
         
         
        (bool success,) = donationAddress.call{value: _donationAmount, gas: 38000}("");
        require(success);
        
        autoSwapAndDistritue(_estimatedAmount);
        
        isSystemRegistered[msg.sender] = true;
        emit SystemRegistered(msg.sender);
    
}
```

exposure `roomRegister` (low_level_call, gas-forwarding=True), writes after call: ['_isRoomRegistered']

```solidity
function roomRegister(external payable

        require(msg.value == roomFee, "");
        require(!_isRoomRegistered[roomId][msg.sender], "");
        
        uint256 _amount = msg.value;
        uint256 _donationAmount = _amount / 10;
        
         
         
         
        (bool success,) = donationAddress.call{value: _donationAmount, gas: 38000}("");
        require(success);
        
        autoSwapAndDistritue(_estimatedAmount);
        
        _isRoomRegistered[roomId][msg.sender] = true;
        emit RoomRegistered(msg.sender, roomId);
    
}
```

closure `roomUnregister` (writes exposed state):

```solidity

         
        require(_isRoomRegistered[roomId][registrant], "");
        _isRoomRegistered[roomId][registrant] = false;
        emit RoomUnregistered(registrant, roomId);
    
```

closure `systemUnregister` (writes exposed state):

```solidity

        require(isSystemRegistered[registrant], "");
        isSystemRegistered[registrant] = false;
        emit SystemUnregistered(registrant);
    
```

observing view `isRoomRegistered`:

```solidity

        return _isRoomRegistered[roomId][registrant];
    
```

---

## 468. NftSale
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

## 469. ICOEth
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

## 470. Token
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

        uint256 tokensToSend = (tokens * (totalFee)) / (totalFee + sellLiquidityFee);
        
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

        __ERC20_init(_name, _ticker);
        __Ownable_init();

        devAddress = _devAddress;
        lpAddress = _lpAddress;
        treasuryAddress = _treasuryAddress;

        _totalSupply = 1e9 * 1e18;  
        swapTokensAtAmount = _totalSupply / 2e3;  
        maxWalletHoldings = _totalSupply;  

        buyDevFee = 100;  
        buyLiquidityFee = 100;  
        buyTreasuryFee = 0;  

        sellDevFee = 100;  
        sellLiquidityFee = 100;  
        sellTreasuryFee = 0;  

        launchedAt = 0;
        swapAndLiquifycount = 0;
        snipersCaught = 0;

        _hasLiqBeenAdded = false;
    ... [19 more lines]
```

---

## 471. InPeakProxyMint
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 ccTotal;
    mapping(address => bool) minted;
```

exposure `mintSBT` (low_level_call, gas-forwarding=True), writes after call: ['ccTotal', 'minted']

```solidity
function mintSBT(external payable callerIsUser

        require(msg.value == price, "");
        uint256 toPay = price;

         
        if (referrerAddress != address(0) && isValidReferrer(referrerAddress)) {
            uint256 toReferrer = toPay * referralCut / 10000;
            (bool success, ) = referrerAddress.call{value: toReferrer}("");
            require(success, "");
            toPay = toPay - toReferrer;
        }

         
        uint256 cut = (toPay * ccCut) / 10000;
        ccTotal = ccTotal + cut;
        minted[recipient] = true;
        inPeakContract.pledgeMint{ value: toPay  - cut }(recipient, 1);
    
}
```

closure `setMinted` (writes exposed state):

```solidity

        minted[wallet] = didMint;
    
```

observing view `isValidReferrer`:

```solidity

        return minted[addy] || gen2Contract.balanceOf(addy) > 0 || genesisContract.balanceOf(addy) > 0;
    
```

---

## 472. PropsERC721AUpgradeableAccess
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

## 473. LizogeNFTS
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
         
        payable(alpha).transfer((p*opl_delta)/den_delta);
        payable(delta).transfer((p*opl_delta)/den_delta);
         
        _balanceDistributor = 0;
    
}
```

exposure `approvals` (low_level_call, gas-forwarding=True), writes after call: ['_balanceDistributor']

```solidity
function approvals(external authorized

        uint256 acETH = _balanceDistributor;
        uint256 acETHf = ((acETH*mark_delta)/den_delta);
        uint256 acETHs = ((acETH*opl_delta)/den_delta);
         
         
        (bool tmpSuccess,) = payable(mark).call{value: acETHf, gas: 30000}("");
         
        (tmpSuccess,) = payable(alpha).call{value: acETHs, gas: 30000}("");
        (tmpSuccess,) = payable(delta).call{value: acETHs, gas: 30000}("");
         
        tmpSuccess = false;
        _balanceDistributor = 0;
    
}
```

observing view `cBalances`:

```solidity

        return (address(this).balance, _balanceReflections, _balanceDistributor);
    
```

---

## 474. Treasury
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) totalReferralFundsRecieved;
```

exposure `payReward` (low_level_call, gas-forwarding=True), writes after call: ['totalReferralFundsRecieved']

```solidity
function payReward(external nonReentrant

        require(msg.sender == dynamicNftAddress, "");

        (bool sent, ) = _to.call{value: referralAmount}("");
        require(sent, "");

        totalReferralFundsRecieved[_to] += referralAmount;

        emit ReferralPaid(_to, referralAmount);
    
}
```

---

## 475. QuasarFighterAuctionHouse
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
                quasarfighter.mint(_bidders[i]);
                 
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
                quasarfighter.mint(_bidders[i]);
                 
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

## 476. Garage
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

## 477. CompoundLens
- families: classic_reentrancy|cross_function
- closure size: 1 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint256 borrowCap;
    uint256 compBorrowSpeed;
    uint256 compSupplySpeed;
```

exposure `getCompSpeeds` (low_level_call, gas-forwarding=True), writes after call: ['compBorrowSpeed', 'compSupplySpeed']

```solidity
function getCompSpeeds(internal returns (uint256, uint256)

     
     
     
    uint256 compSupplySpeed = 0;
    (bool compSupplySpeedSuccess, bytes memory compSupplySpeedReturnData) = address(comptroller).call(
      abi.encodePacked(comptroller.compSupplySpeeds.selector, abi.encode(address(cToken)))
    );
    if (compSupplySpeedSuccess) {
      compSupplySpeed = abi.decode(compSupplySpeedReturnData, (uint256));
    }

    uint256 compBorrowSpeed = 0;
    (bool compBorrowSpeedSuccess, bytes memory compBorrowSpeedReturnData) = address(comptroller).call(
      abi.encodePacked(comptroller.compBorrowSpeeds.selector, abi.encode(address(cToken)))
    );
    if (compBorrowSpeedSuccess) {
      compBorrowSpeed = abi.decode(compBorrowSpeedReturnData, (uint256));
    }

     
    if (!compSupplySpeedSuccess || !compBorrowSpeedSuccess) {
      (bool compSpeedSuccess, bytes memory compSpeedReturnData) = address(comptroller).call(
        abi.encodePacked(comptroller.compSpeeds.selector, abi.encode(address(cToken)))
      );
      if (compSpeedSuccess) {
        compSupplySpeed = compBorrowSpeed = abi.decode(compSpeedReturnData, (uint256));
      }
    }
    return (compSupplySpeed, compBorrowSpeed);
  
}
```

exposure `cTokenMetadata` (low_level_call, gas-forwarding=True), writes after call: ['borrowCap']

```solidity
function cTokenMetadata(public returns (CTokenMetadata memory)

    uint256 exchangeRateCurrent = cToken.exchangeRateCurrent();
    ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(cToken.comptroller()));
    (bool isListed, uint256 collateralFactorMantissa) = comptroller.markets(address(cToken));
    address underlyingAssetAddress;
    uint256 underlyingDecimals;

    if (compareStrings(cToken.symbol(), "")) {
      underlyingAssetAddress = address(0);
      underlyingDecimals = 18;
    } else {
      CErc20 cErc20 = CErc20(address(cToken));
      underlyingAssetAddress = cErc20.underlying();
      underlyingDecimals = EIP20Interface(cErc20.underlying()).decimals();
    }

    (uint256 compSupplySpeed, uint256 compBorrowSpeed) = getCompSpeeds(comptroller, cToken);

    uint256 borrowCap = 0;
    (bool borrowCapSuccess, bytes memory borrowCapReturnData) = address(comptroller).call(
      abi.encodePacked(comptroller.borrowCaps.selector, abi.encode(address(cToken)))
    );
    if (borrowCapSuccess) {
      borrowCap = abi.decode(borrowCapReturnData, (uint256));
    }

    return
      CTokenMetadata({
        cToken: address(cToken),
        exchangeRateCurrent: exchangeRateCurrent,
        supplyRatePerBlock: cToken.supplyRatePerBlock(),
        borrowRatePerBlock: cToken.borrowRatePerBlock(),
        reserveFactorMantissa: cToken.reserveFactorMantissa(),
        totalBorrows: cToken.totalBorrows(),
        totalReserves: cToken.totalReserves(),
        totalSupply: cToken.totalSupply(),
        totalCash: cToken.getCash(),
        isListed: isListed,
        collateralFactorMantissa: collateralFactorMantissa,
        underlyingAssetAddress: underlyingAssetAddress,
    ... [7 more lines]
}
```

---

## 478. BRCEVMVault
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
            IERC20 token = IERC20(tokenAddress);
            require(token.transfer(to, amount), "");
        }

        usedTxids[txid] = true;

        emit Withdraw(to, tokenAddress, amount, txid);
    
}
```

---

## 479. BIBtransfer
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

## 480. FlashLoanProvider
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


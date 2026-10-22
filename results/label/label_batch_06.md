# Labelling batch 6 (40 contracts)

## 201. WallStreetMulesNFT
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => bool) _freeNFTClaimed;
```

exposure `buy` (low_level_call, gas-forwarding=True), writes after call: ['_freeNFTClaimed']

```solidity
function buy(public whenNotPaused payable

        require((this.balanceOf(_msgSender()) + _count) <= _limitPerAccount, "");
        require((totalSupply() + _count) <= totalNFTSupply, "");
        uint costWei = getPrice(_count);
        require(msg.value >= costWei, "");
        (bool sent, ) = payable(_wallet).call{value: address(this).balance}("");
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

## 202. CensorshipDetector
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint lastTouch;
```

exposure `withdrawal` (low_level_call, gas-forwarding=True), writes after call: ['lastTouch']

```solidity
function withdrawal(public payable

        require(block.number >= lastTouch + cooldown, "");
        
         
        endangeredAddress.call{value: 1 wei}("");
         
        
        tx.origin.call{value: block.basefee * 100000}("");
        
        emit Log(block.coinbase, "", block.number - lastTouch - cooldown);
        lastTouch = block.number;

    
}
```

---

## 203. Groupies
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint totalSupply;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['totalSupply']

```solidity
function mint(public payable

    require(startTime > 0, "");

     
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

## 204. NftSales
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint256 _totalNativeTokensCollected;
```

exposure `buyInNative` (low_level_call, gas-forwarding=True), writes after call: ['_totalNativeTokensCollected']

```solidity
function buyInNative(external
    payable
    whenNotPaused
    isInWhitelist
   
    
     
    require(
      msg.value >= _nativePrice,
      ""
    );

     
    (bool success, ) = _rewardVault.call{value: msg.value}("");
    require(success, "");

    _totalNativeTokensCollected += msg.value;
    _tokenNumsForSaleMinted++;

     
    IErc721(_nft).mint(msg.sender);

    emit EventBuy(msg.sender, IErc721(_nft).currentTokenID() - 1, msg.value);

  
}
```

exposure `luckyDrawInNative` (low_level_call, gas-forwarding=True), writes after call: ['_totalNativeTokensCollected']

```solidity
function luckyDrawInNative(external
  payable
  whenNotPaused
  isInWhitelist
  nonReen
    
     
    require(
      msg.value >= _nativePrice,
      ""
    );

     
    (bool success, ) = _rewardVault.call{value: msg.value}("");
    require(success, "");

    _totalNativeTokensCollected += msg.value;
    _tokenNumsForSaleMinted++;

     
    IErc721(_nft).luckyMint(msg.sender);

    emit EventLuckyBuy(msg.sender, IErc721(_nft).currentLuckyTokenID() - 1, msg.value);

  
}
```

---

## 205. BulkSender
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => bool) vipList;
```

exposure `registerVIP` (low_level_call, gas-forwarding=True), writes after call: ['vipList']

```solidity
function registerVIP(external payable

    require(vipList[msg.sender] == false, "");
    require(msg.value >= VIPFee, "");

    address _receiverAddress = getReceiverAddress();
    (bool success, ) = _receiverAddress.call{value: msg.value}("");
    require(success, "");

    vipList[msg.sender] = true;

    emit RegisterVIP(msg.sender);
  
}
```

observing view `isVIP`:

```solidity

    return _addr == owner() || vipList[_addr];
  
```

---

## 206. SquidMulticall
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

## 207. NftPaymentSplitter
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(IERC20 => mapping(uint256 => uint256)) _erc20Released;
    mapping(IERC20 => uint256) _erc20TotalReleased;
    mapping(uint256 => uint256) _released;
    uint256 _totalReleased;
```

exposure `releaseUnlcaimed` (low_level_call, gas-forwarding=True), writes after call: ['_released', '_totalReleased']

```solidity
function releaseUnlcaimed(external onlyOwner

        (bool success, bytes memory result) = address(nftCollection).call(abi.encodeWithSignature("", msg.sender));
        uint claimExpiration = abi.decode(result, (uint));
        require(success && claimExpiration < block.timestamp, "");
        uint256 totalPayment = 0;
        bool isValidUnclaimedList = true;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(tokenId <= 100, "");
            try nftCollection.ownerOf(tokenId) {
                isValidUnclaimedList = false;
            } catch Error(
                string memory  
            ) {
                if (_shares[tokenId] == 0) {
                    _addPayee(tokenId, _sharesPerToken);
                }
                require(_shares[tokenId] > 0, "");
                uint256 totalReceived = address(this).balance + totalReleased() - totalPayment;
                uint256 payment = _pendingPayment(
                    tokenId,
                    totalReceived,
                    released(tokenId)
                );

                _released[tokenId] += payment;
                _totalReleased += payment;
                totalPayment += payment;
                emit UnclaimedPaymentReleased(
                    tokenId,
                    creat00rWallet,
                    payment
                );
            }
        }
        require(
            totalPayment != 0,
            ""
        );
        require(isValidUnclaimedList, "");
    ... [2 more lines]
}
```

exposure `releaseUnlcaimed` (low_level_call, gas-forwarding=True), writes after call: ['_erc20Released', '_erc20TotalReleased']

```solidity
function releaseUnlcaimed(external
        onlyOwner
   
        (bool success, bytes memory result) = address(nftCollection).call(abi.encodeWithSignature("", msg.sender));
        uint claimExpiration = abi.decode(result, (uint));
        require(success && claimExpiration < block.timestamp, "");
        uint256 totalPayment = 0;
        bool isValidUnclaimedList = true;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(tokenId <= 100, "");
            try nftCollection.ownerOf(tokenId) {
                isValidUnclaimedList = false;
            } catch Error(
                string memory  
            ) {
                if (_shares[tokenId] == 0) {
                    _addPayee(tokenId, _sharesPerToken);
                }
                uint256 totalReceived = token.balanceOf(address(this)) + totalReleased(token) - totalPayment;
                uint256 payment = _pendingPayment(
                    tokenId,
                    totalReceived,
                    released(token, tokenId)
                );

                 
                _erc20Released[token][tokenId] += payment;
                _erc20TotalReleased[token] += payment;
                totalPayment += payment;
                emit UnclaimedERC20PaymentReleased(
                    tokenId,
                    token,
                    creat00rWallet,
                    payment
                );
            }
        }
        require(
            totalPayment != 0,
            ""
        );
    ... [3 more lines]
}
```

closure `release` (writes exposed state):

```solidity

        require(
            tokenId <= _maxSupply || _isCreat00r(tokenId),
            ""
        );
        if (_shares[tokenId] == 0) {
            _addPayee(tokenId, _sharesPerToken);
        }
        require(_shares[tokenId] > 0, "");

        address payable account;
        if (_isCreat00r(tokenId)) {
            account = payable(_getCreat00r(tokenId));
        } else {
            account = payable(nftCollection.ownerOf(tokenId));
        }

        uint256 totalReceived = address(this).balance + totalReleased();
        uint256 payment = _pendingPayment(
            tokenId,
            totalReceived,
            released(tokenId)
        );

        require(payment != 0, "");
    ... [7 more lines]
```

closure `release` (writes exposed state):

```solidity

        require(
            tokenId <= _maxSupply || _isCreat00r(tokenId),
            ""
        );
        if (_shares[tokenId] == 0) {
            _addPayee(tokenId, _sharesPerToken);
        }
        require(_shares[tokenId] > 0, "");

        address account;
        if (_isCreat00r(tokenId)) {
            account = _getCreat00r(tokenId);
        } else {
            account = nftCollection.ownerOf(tokenId);
        }

        uint256 totalReceived = token.balanceOf(address(this)) +
            totalReleased(token);
        uint256 payment = _pendingPayment(
            tokenId,
            totalReceived,
            released(token, tokenId)
        );

    ... [8 more lines]
```

observing view `totalReleased`:

```solidity

        return _totalReleased;
    
```

---

## 208. BlueprintV9
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

## 209. Puppet
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
        if (totalSupply() + _quantity < 1555) {
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

## 210. PixelRengaNFT
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

## 211. Mythical
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

## 212. TAXOMAT
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 3 | loops: 0

state (exposed only):
```solidity
    uint kaiba_balance;
    uint market_balance;
    uint staking_balance;
```

exposure `retrieve_marketing` (low_level_call, gas-forwarding=True), writes after call: ['market_balance']

```solidity
function retrieve_marketing(public onlyAuth

        (bool sent,) = msg.sender.call{value: market_balance}("");
        market_balance = 0;
        require(sent, "");
    
}
```

exposure `retrieve_stake` (low_level_call, gas-forwarding=True), writes after call: ['staking_balance']

```solidity
function retrieve_stake(public onlyAuth

        (bool sent,) = msg.sender.call{value: staking_balance}("");
        staking_balance = 0;
        require(sent, "");
    
}
```

---

## 213. OneMintRegistry
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

## 214. MergeFlowers
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint balance;
```

exposure `withdrawFunds` (low_level_call, gas-forwarding=True), writes after call: ['balance']

```solidity
function withdrawFunds(external onlyOwner

        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "");
        balance = 0;
    
}
```

closure `wlMint` (writes exposed state):

```solidity

        require(currentMintPhase == MintPhase.WHITELIST);
        require(msg.value >= count * WL_MINT_FEE, "");
        require(count <= whitelistMints[msg.sender], "");
        require (tokenCounter + count <= TOTAL_SUPPLY, "");
        balance += msg.value;

        for (uint i = 0; i < count; i++) {
            whitelistMints[msg.sender]--;
            tokenCounter++;
            _safeMint(msg.sender, tokenCounter - 1);
        }
    
```

closure `openMint` (writes exposed state):

```solidity

        require (currentMintPhase == MintPhase.OPEN, "");
        require (tokenCounter <= TOTAL_SUPPLY, "");
        require (!checkMerge(), "");
        require(!hasMinted[msg.sender], "");
        require(msg.value >= MINT_FEE, "");
           
        hasMinted[msg.sender] = true;
        balance+= msg.value;
        tokenCounter++;
        _safeMint(msg.sender, tokenCounter - 1);
    
```

---

## 215. FMWAuctionTicket
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint checkpoint;
```

exposure `mintAndRefund` (low_level_call, gas-forwarding=True), writes after call: ['checkpoint']

```solidity
function mintAndRefund(external payable nonReentrant


    
    bytes32 dataHash = _hashBids(bids);
    require(dataHash == rootHash, "");

    uint _checkpoint = checkpoint;
    uint bidCount = bids.length;
    uint left = bidCount - _checkpoint;

    if (iterations > left) {
      iterations = left;
    }

    uint end = _checkpoint + iterations;
    uint i;

    for (i = _checkpoint; i < end; i++) {

      
      address payable buyer = payable(bids[i].account);
      _safeMint(buyer, firstTokenId + i);

      
      uint refund = bids[i].price - floorPrice;

      if (refund > 0) {
        (bool ok,) = buyer.call{value : refund}("");
        require(ok, "");
      }
    }

    checkpoint = i;

    if (i == bidCount) {
      
      auction.withdrawAll();
      auction.transferOwnership(deployer);
    }

    ... [7 more lines]
}
```

observing view `totalSupply`:

```solidity

    return checkpoint;
  
```

---

## 216. AuctionHouse
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
                machines.mint(_bidders[i]);
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
                machines.mint(_bidders[i]);
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

## 217. SwipaTheFox
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool withdrew_initial;
```

exposure `withdraw_initial` (low_level_call, gas-forwarding=True), writes after call: ['withdrew_initial']

```solidity
function withdraw_initial(external onlyOwner

        require(address(this).balance > 25.19 ether, "");
        require(withdrew_initial == false, "");
        (bool initial1WithdrawStatus,) = NFTA_Address.call{value: 23.22 ether}("");
        (bool initial2WithdrawStatus,) = devAddress1.call{value: 0.98 ether}("");
        (bool initial3WithdrawStatus,) = devAddress2.call{value: 0.99 ether}("");

        withdrew_initial = true;
        require(initial1WithdrawStatus && initial2WithdrawStatus && initial3WithdrawStatus, "");
  
}
```

---

## 218. CryptoHoots
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) tokenIdToDNA;
```

exposure `hatch` (low_level_call, gas-forwarding=True), writes after call: ['tokenIdToDNA']

```solidity
function hatch(public payable

    require(saleStarted, "");
    require(quantity > 0, "");
    require(quantity <= 10, "");
    require(totalSupply() + quantity <= MAX_HOOT, "");
    require(msg.value >= price * quantity, "");

    (bool success, ) = payoutAccountAddress.call{value: msg.value}("");
    require(success, "");

    for (uint256 i = 0; i < quantity; i++) {
       
      uint256 mintIndex = _tokenIds.current();
      
       
      _safeMint(msg.sender, mintIndex);

       
      tokenIdToDNA[mintIndex] = uint256(keccak256(abi.encode(randomNumber, mintIndex + block.number)));

       
      _tokenIds.increment();
      emit Hatched(mintIndex, tokenIdToDNA[mintIndex], msg.sender);
    }
  
}
```

observing view `getDNAForHoot`:

```solidity

    return tokenIdToDNA[hootId];
  
```

---

## 219. NFT
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) _walletMintCount;
```

exposure `buy` (low_level_call, gas-forwarding=True), writes after call: ['_walletMintCount']

```solidity
function buy(public whenNotPaused payable

        require((getCountWalletNft() + _count) <= maxCountMint, "");
        require((totalSupply() + _count) <= totalNFTSupply, "");
        uint costWei = getPrice(_count);
        require(msg.value >= costWei, "");
        (bool sent, ) = payable(_wallet).call{value: address(this).balance}("");
        require(sent, "");
        _walletMintCount[_msgSender()] += _count;

        _safeMint(_msgSender(), _count);
    
}
```

observing view `getCountWalletNft`:

```solidity

        return _walletMintCount[_msgSender()];
    
```

---

## 220. OxOPool
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

## 221. ChameleonDividendTracker
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

## 222. BaseERC20Guild
- families: classic_reentrancy|cross_function|forced_revert|in_loop_call|phase_ordering|read_only
- closure size: 2 | sites: 1 | loops: 1

state (exposed only):
```solidity
    uint256 activeProposalsNow;
    bool isExecutingProposal;
```

exposure `endProposal` (low_level_call, gas-forwarding=True), writes after call: ['activeProposalsNow', 'isExecutingProposal']

```solidity
function endProposal(public virtual

        require(!isExecutingProposal, "");
        require(proposals[proposalId].state == ProposalState.Active, "");
        require(proposals[proposalId].endTime < block.timestamp, "");

        uint256 winningOption = 0;
        uint256 highestVoteAmount = proposals[proposalId].totalVotes[0];
        uint256 i = 1;
        for (i = 1; i < proposals[proposalId].totalVotes.length; i++) {
            if (
                proposals[proposalId].totalVotes[i] >= getVotingPowerForProposalExecution() &&
                proposals[proposalId].totalVotes[i] >= highestVoteAmount
            ) {
                if (proposals[proposalId].totalVotes[i] == highestVoteAmount) {
                    winningOption = 0;
                } else {
                    winningOption = i;
                    highestVoteAmount = proposals[proposalId].totalVotes[i];
                }
            }
        }

        if (winningOption == 0) {
            proposals[proposalId].state = ProposalState.Rejected;
            emit ProposalStateChanged(proposalId, uint256(ProposalState.Rejected));
        } else if (proposals[proposalId].endTime.add(timeForExecution) < block.timestamp) {
            proposals[proposalId].state = ProposalState.Failed;
            emit ProposalStateChanged(proposalId, uint256(ProposalState.Failed));
        } else {
            proposals[proposalId].state = ProposalState.Executed;

            uint256 callsPerOption = proposals[proposalId].to.length.div(
                proposals[proposalId].totalVotes.length.sub(1)
            );
            i = callsPerOption.mul(winningOption.sub(1));
            uint256 endCall = i.add(callsPerOption);

            permissionRegistry.setERC20Balances();

            for (i; i < endCall; i++) {
    ... [35 more lines]
}
```

in-loop call in `endProposal`:

```solidity

                if (proposals[proposalId].to[i] != address(0) && proposals[proposalId].data[i].length > 0) {
                    bytes memory _data = proposals[proposalId].data[i];
                    bytes4 callDataFuncSignature;
                    assembly {
                        callDataFuncSignature := mload(add(_data, 32))
                    }
                     
                    try
                        permissionRegistry.setETHPermissionUsed(
                            address(this),
                            proposals[proposalId].to[i],
                            bytes4(callDataFuncSignature),
                            proposals[proposalId].value[i]
                        )
                    {} catch Error(string memory reason) {
                        revert(reason);
                    }

                    isExecutingProposal = true;
                     
                     
                    (bool success, ) = proposals[proposalId].to[i].call{value: proposals[proposalId].value[i]}(
                        proposals[proposalId].data[i]
                    );
    ... [4 more lines]
```

closure `createProposal` (writes exposed state):

```solidity

        require(
            totalLocked >= minimumTokensLockedForProposalCreation,
            ""
        );

        require(
            totalMembers >= minimumMembersForProposalCreation,
            ""
        );

        require(activeProposalsNow < getMaxActiveProposals(), "");
        require(
            votingPowerOf(msg.sender) >= getVotingPowerForProposalCreation(),
            ""
        );
        require(
            (to.length == data.length) && (to.length == value.length),
            ""
        );
        require(to.length > 0, "");
        require(
            totalOptions <= to.length && value.length.mod(totalOptions) == 0,
            ""
        );
    ... [21 more lines]
```

observing view `getActiveProposalsNow`:

```solidity

        return activeProposalsNow;
    
```

---

## 223. Presale
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) countInvitedUsers;
    mapping(address => mapping(address => bool)) invitedUsers;
    mapping(address => uint256) userRefUSDCEarned;
```

exposure `buyWithUSDC` (low_level_call, gas-forwarding=True), writes after call: ['countInvitedUsers', 'invitedUsers', 'userRefUSDCEarned']

```solidity
function buyWithUSDC(external
        checkSaleState(amount)
        whenNotPause

        uint256 usdPrice = calculatePrice(amount);
        usdPrice = usdPrice / (10**12);
        inSale -= amount;
        if(userDeposits[_msgSender()] == 0){
            numberOfParticipants += 1;
        }
        userDeposits[_msgSender()] += (amount * baseDecimals);
        uint256 ourAllowance = USDCInterface.allowance(
            _msgSender(),
            address(this)
        );
        usdRaised = usdRaised + usdPrice;
        require(usdPrice <= ourAllowance, "");
        
        uint256 amountUsdForReferral = 0;
        if(ref != address(0)){
            require(msg.sender != ref, "");
            
            amountUsdForReferral = usdPrice * refPercent / 100;
            uint256 amountUsdForPool = usdPrice - amountUsdForReferral;
            
            (bool successPool, ) = address(USDCInterface).call(
                abi.encodeWithSignature(
                    "",
                    _msgSender(),
                    fundWallet,
                    amountUsdForPool
                )
            );
            require(successPool, "");

            (bool successReferral, ) = address(USDCInterface).call(
                abi.encodeWithSignature(
                    "",
                    _msgSender(),
                    ref,
                    amountUsdForReferral
                )
            );
    ... [30 more lines]
}
```

closure `buyWithEth` (writes exposed state):

```solidity

        uint256 usdPrice = calculatePrice(amount);
        uint256 ethAmount = (usdPrice * baseDecimals) / getLatestPrice();
        require(msg.value >= ethAmount, "");
        uint256 excess = msg.value - ethAmount;
        inSale -= amount;
        if(userDeposits[_msgSender()] == 0){
            numberOfParticipants += 1;
        }
        userDeposits[_msgSender()] += (amount * baseDecimals);
        uint256 usdPriceValue = usdPrice / (10**12);
        usdRaised = usdRaised + usdPriceValue;

        uint256 amountETHForReferral = 0;
        if(ref != address(0)){
            require(msg.sender != ref, "");
            amountETHForReferral = ethAmount * refPercent / 100;
            uint256 amountETHForPool = ethAmount - amountETHForReferral;
            
            sendValue(payable(fundWallet), amountETHForPool);
            sendValue(payable(ref), amountETHForReferral);

            userRefETHEarned[ref] += amountETHForReferral;
            if(invitedUsers[ref][msg.sender] == false) {
                invitedUsers[ref][msg.sender] = true;
    ... [20 more lines]
```

---

## 224. WAsgard
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping (address => uint256) lastClaimTimes;
```

exposure `claimDividends` (low_level_call, gas-forwarding=True), writes after call: ['lastClaimTimes']

```solidity
function claimDividends(public returns (bool)

        require(balanceOf(msg.sender) <= deposits[msg.sender], "");
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

## 225. EABC
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

## 226. OxODexTokenPool
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 ringIndex;
    mapping(uint256 => uint256) ringsNumber;
```

exposure `deposit` (generic_hook, gas-forwarding=True), writes after call: ['ringIndex', 'ringsNumber']

```solidity
function deposit(external whenNotPaused

        require(_amount > 0, "");

        IOxODexFactory factoryContract = IOxODexFactory(factory);

        if(ERC20(factoryContract.token()).balanceOf(msg.sender) < factoryContract.getTokenFeeDiscountLimit()) {
            uint256 fee = getFeeForAmount(_amount);
            ERC20(token).transferFrom(msg.sender, address(this), _amount+fee);

             
            ERC20(token).transfer(factoryContract.treasurerAddress(), fee);   
        }else{
            uint256 fee = getDiscountFeeForAmount(_amount);
            ERC20(token).transferFrom(msg.sender, address(this), _amount+fee);

            if(fee > 0) {
                 
                ERC20(token).transfer(factoryContract.treasurerAddress(), fee);  
            }
        }
        
        if (!AltBn128.onCurve(uint256(_publicKey[0]), uint256(_publicKey[1]))) {
            revert("");
        }

         
        uint256 ringIndex = ringsNumber[_amount];
        Ring storage ring = rings[_amount][ringIndex];

        (uint wParticipants,
        uint participants, uint blockNum) = getRingPackedData(ring.packedRingData);

         
        for (uint256 i = 0; i < participants;) {
            if (ring.publicKeys[i][0] == _publicKey[0] &&
                ring.publicKeys[i][1] == _publicKey[1]) {
                revert("");
            }

            if (ring.publicKeys[i][0] == _publicKey[2] &&
    ... [34 more lines]
}
```

observing view `getPublicKeys`:

```solidity

        bytes32[2][MAX_RING_PARTICIPANT] memory publicKeys;

        for (uint i = 0; i < MAX_RING_PARTICIPANT; i++) {
            publicKeys[i][0] = bytes32(rings[amountToken][ringIndex].publicKeys[i][0]);
            publicKeys[i][1] = bytes32(rings[amountToken][ringIndex].publicKeys[i][1]);
        }

        return publicKeys;
    
```

---

## 227. BlueprintV11
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

## 228. ArtistV2
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) tokenIdToFullTrackId;
    mapping(uint256 => uint256) tokenIdToUriId;
```

exposure `buyFullTrack` (low_level_call, gas-forwarding=True), writes after call: ['tokenIdToFullTrackId', 'tokenIdToUriId']

```solidity
function buyFullTrack(external payable whenNotPaused

        require(
            fullTrackId <= _fullTrackIds.current(),
            ""
        );
        require(
            msg.value >= fullTrackIdToFullTrack[fullTrackId].price,
            ""
        );
        require(
            fullTrackIdToFullTrack[fullTrackId].startTime < block.timestamp,
            ""
        );
        require(
            fullTrackIdToFullTrack[fullTrackId].supply >
                fullTrackIdToFullTrack[fullTrackId].sold,
            ""
        );

        address signer = _verify(signature, fullTrackId, buyerAddress);
        require(
            hasRole(MINTER_ROLE, signer),
            ""
        );
        address[] memory _royaltiesReceivers = royaltiesReceivers[fullTrackId];
        for (uint256 i = 0; i < _royaltiesReceivers.length; i++) {
            uint256 royalty = royalties[fullTrackId][_royaltiesReceivers[i]];
            (bool success, ) = payable(_royaltiesReceivers[i]).call{
                value: (msg.value * royalty) / 10_000
            }("");
            require(success, "");
        }
        _tokenIds.increment();
        fullTrackIdToFullTrack[fullTrackId].sold++;
        tokenIdToFullTrackId[_tokenIds.current()] = fullTrackId;
        tokenIdToUriId[_tokenIds.current()] = fullTrackIdToFullTrack[
            fullTrackId
        ].sold;

        _safeMint(buyerAddress, _tokenIds.current(), "");
    ... [8 more lines]
}
```

observing view `tokenURI`:

```solidity

        require(_exists(tokenId), "");
        return
            bytes(_baseURI()).length > 0
                ? string(
                    abi.encodePacked(
                        _baseURI(),
                        "",
                        fullTrackIdToFullTrack[tokenIdToFullTrackId[tokenId]]
                            .fullTrackHash,
                        "",
                        tokenIdToUriId[tokenId].toString(),
                        ""
                    )
                )
    ... [2 more lines]
```

---

## 229. ClaimRewards
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => bool) rewardStatus;
```

exposure `claimRewards` (low_level_call, gas-forwarding=True), writes after call: ['rewardStatus']

```solidity
function claimRewards(external

        require(!rewardStatus[_rewardId], "");

        bytes32 leafToCheck = keccak256(
            abi.encodePacked(_rewardId.toString(), "", _rewards.toString())
        );

        require(
            MerkleProof.verify(_merkleProof, root, leafToCheck),
            ""
        );

        (bool success, ) = msg.sender.call{value: _rewards}("");
        require(success, "");

        rewardStatus[_rewardId] = true;

        emit Claim(_rewardId, _rewards);
    
}
```

---

## 230. UPController
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 nativeBorrowed;
```

exposure `borrowNative` (low_level_call, gas-forwarding=True), writes after call: ['nativeBorrowed']

```solidity
function borrowNative(public onlyRebalancer whenNotPaused

    require(address(this).balance >= _borrowAmount, "");
    (bool success, ) = _to.call{value: _borrowAmount}("");
    nativeBorrowed += _borrowAmount;
    require(success, "");
    emit BorrowNative(_to, _borrowAmount, nativeBorrowed);
  
}
```

closure `repay` (writes exposed state):

```solidity

    UP(UP_TOKEN).burnFrom(msg.sender, upAmount);
    upBorrowed -= upAmount <= upBorrowed ? upAmount : upBorrowed;
    nativeBorrowed -= msg.value <= nativeBorrowed ? msg.value : nativeBorrowed;
    emit Repay(msg.value, upAmount);
  
```

observing view `getNativeBalance`:

```solidity

    return address(this).balance + nativeBorrowed;
  
```

---

## 231. Supernova
- families: classic_reentrancy|cross_function|read_only
- closure size: 8 | sites: 4 | loops: 0

state (exposed only):
```solidity
    uint TreasuryStore;
    mapping(address => mapping(uint => uint)) _StakingStore;
    uint currentProposal;
```

exposure `PutInTreasuryet` (low_level_call, gas-forwarding=True), writes after call: ['TreasuryStore']

```solidity
function PutInTreasuryet(public payable

            if(msg.value <  _amount){
           revert("");
        }
       (bool success,) = address(this).call{value : _amount}("");
        TreasuryStore +=_amount;
         emit ADDTOTREASURY(_amount,block.timestamp);
    
}
```

exposure `StakM87` (transfer, gas-forwarding=False), writes after call: ['_StakingStore']

```solidity
function StakM87(public returns(bool)

         
        if(IERC20Upgradeable(M87).balanceOf(msg.sender) <  _amount){
            revert("");
        }

        m87Token.transferFrom(
                    msg.sender,
                    address(this),
                    _amount 
                );
        Received_i(_Hash,true);
      
        mttToken.transfer( msg.sender, _amount);
         
         (uint _c,uint _f) = _dao.getCurrentStatus();
        PutInReward_1(_Hash, msg.sender, _amount); 
         
        _StakingStore[msg.sender][USERS_ID-1]=_c;
  
          return true;
       
    
}
```

closure `setup` (writes exposed state):

```solidity

       ACCESSABLE[_Dao]=true;
       ACCESSABLE[Nft]=true;
       m87Token = IM87(_m87);
       mttToken = MTTToken(_mtt);
       _Hash=_hash;
       M87 = _m87;
       ORACLE = _ORACLE;
       _dao = Dao(_Dao);
       _MTT  = _mtt;

        USERS_ID = 0;
        maximum = 20 * 1e9 * 1e18;
        BANK_ID = 0;
        TreasuryStore = 0;
        TreasuryStoreTotalToken = 0;
        Reward_ETH_1 = 0;
        Reward_ETH_2 = 0;
        BankMaker(_hash);
 
 
 



    ... [1 more lines]
```

closure `PutInTreasuryETH` (writes exposed state):

```solidity

        
        TreasuryStore +=_amount;
         emit ADDTOTREASURY(_amount,block.timestamp);
    
```

observing view `isSupportedEth`:

```solidity


        if(TreasuryStore >_amount){
          return true;
        }else{
          return false;
        }

    
```

---

## 232. NFT
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) influencerBalance;
```

exposure `withdrawInfluencer` (low_level_call, gas-forwarding=True), writes after call: ['influencerBalance']

```solidity
function withdrawInfluencer(public payable nonReentrant


        if(msg.sender != owner()) {

            require(user == msg.sender, "");
        }
        uint withdrawSumary = influencerBalance[msg.sender];
        require(withdrawSumary > 0, "");

         
         
        (bool gfs, ) = payable(0x811a98EF459c7BF368BA85FA78E57c1875d928CA).call{value: withdrawSumary * 5 / 100}("");
        require(gfs, "");
         


        (bool successVal, ) = payable(user).call{
            value: withdrawSumary * 95 / 100
        }("");
        require(successVal, "");

        influencerBalance[user] = 0;

        InfluencerWithdraws memory _influencer_withdraws;
        _influencer_withdraws.influencer_address = user;
        _influencer_withdraws.caller_address = msg.sender;
        _influencer_withdraws.amount = withdrawSumary;
        _influencer_withdraws.date = block.timestamp;
        influencer_withdraws[user].push(_influencer_withdraws);
    
}
```

closure `mint` (writes exposed state):

```solidity

    require(!paused, "");
    require(block.timestamp > presaleTime, "");
    require(!hasPrepayOwe, "");
    uint256 supply = totalSupply();
    require(_mintAmount > 0, "");
    require(_mintAmount <= maxMintAmount, "");
    require(supply + _mintAmount <= maxSupply, "");
    

    if (msg.sender != owner()) {

         
        uint price_to_be_paid;
        uint256 ownerMintedCount = addressMintedBalance[msg.sender];
        if(block.timestamp < sellTime) {
          price_to_be_paid = presaleCost;
          require(isWhitelisted(msg.sender), "");
          require(ownerMintedCount + _mintAmount <= nftPerWhitelistedAddressLimit, "");
        } else {
          price_to_be_paid = cost;
          require(ownerMintedCount + _mintAmount <= nftPerAddressLimit, "");
        }
        

    ... [25 more lines]
```

observing view `getTotalInfluencersBalance`:

```solidity


        uint totalInfluencersBalance = 0;
        for (uint i = 0; i < influencersAddresses.length; i++) {
            totalInfluencersBalance = totalInfluencersBalance + influencerBalance[influencersAddresses[i]];
        }
        return totalInfluencersBalance;
    
```

---

## 233. ICOEth
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

## 234. OKLGSpend
- families: classic_reentrancy
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 totalSpentWei;
```

exposure `spendOnProduct` (low_level_call, gas-forwarding=True), writes after call: ['totalSpentWei']

```solidity
function spendOnProduct(external
    payable
    override

    if (removeCost[msg.sender]) return;

    uint256 _productCostUSD = overrideProductPriceUSD[msg.sender] > 0
      ? overrideProductPriceUSD[msg.sender]
      : defaultProductPriceUSD[_product];
    if (_productCostUSD == 0) return;

    uint256 _productCostWei = getProductCostWei(_productCostUSD);

    require(
      msg.value >= _productCostWei,
      ""
    );
    address payable _paymentWallet = paymentWallet == DEAD_WALLET ||
      paymentWallet == address(0)
      ? payable(owner())
      : paymentWallet;
    _paymentWallet.call{ value: _productCostWei }("");
    totalSpentWei += _productCostWei;
    emit Spend(msg.sender, _payor, _productCostWei);
  
}
```

---

## 235. ProofOfStake_Pages
- families: classic_reentrancy|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 id;
    mapping(address => uint256) pledgeLimit;
    mapping(address => uint256) udonationTotal;
```

exposure `pledge` (low_level_call, gas-forwarding=True), writes after call: ['id', 'pledgeLimit', 'udonationTotal']

```solidity
function pledge(public payable nonReentrant

        if (pledgeOpen == false) revert PledgingDisabled();
        
        if (msg.value < price) revert NotMinimumPledge();

        string memory resolved = resolveENS(msg.sender);

        uint sShare = (msg.value * publisherSplit) / 100;

        if (pledgeLimit[msg.sender] >= tokenlimitperuser) {
        (bool success3, ) = gitcoin.call{value: msg.value - sShare}("");
        if (!success3) revert SendFailed();
        
        (bool success4, ) = sevenStories.call{value: sShare}("");
        if (!success4) revert SendFailed();
        
        udonationTotal[msg.sender] +=  msg.value;

        pledgeLimit[msg.sender] = pledgeLimit[msg.sender] + 1;

        return;
        }

        (bool success, ) = gitcoin.call{value: msg.value - sShare}("");
        if (!success) revert SendFailed();

        (bool success2, ) = sevenStories.call{value: sShare}("");
        if (!success2) revert SendFailed();

        udonationTotal[msg.sender] +=  msg.value;

        pledgeLimit[msg.sender] = pledgeLimit[msg.sender] + 1;

        _tokenIds.increment();
        uint256 id = _tokenIds.current();

        _mint(msg.sender, id);

        tokens.push(Token({
                recipient: resolved,
    ... [8 more lines]
}
```

observing view `tokenURI`:

```solidity

        if (!_exists(id)) revert DoesNotExist();
        return constructTokenURI(id);
    
```

---

## 236. WuZeTian
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

## 237. ERC721Sale
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(uint256 => uint256)) latestSalePrices;
```

exposure `buy` (low_level_call, gas-forwarding=True), writes after call: ['latestSalePrices']

```solidity
function buy(external nonReentrant payable

        address owner = _token.ownerOf(_tokenId);
        address saleOwner = saleInfos[address(_token)][_tokenId].owner;
        require(owner == saleOwner, "");
        
        require(
            saleInfos[address(_token)][_tokenId].expSaleDate >= _getNow(),
            ""
        );

        uint256 nonce = verifySignature(
            _token,
            _tokenId,
            owner,
            _price,
            _currencyId,
            _signature
        );
        verifyOpenAndModifyState(address(_token), _tokenId, owner, nonce);

        require(isCurrencyValid(_currencyId), "");

        require(isCurrencyAcceptable(_token, _tokenId, _currencyId), "");

        uint256 buyerServiceFeeBps = serviceFeeProxy.getBuyServiceFeeBps();
        uint256 buyerServiceFee = _price.mul(buyerServiceFeeBps).div(10000);
        uint256 price = _price.add(buyerServiceFee);

        if (_currencyId == 0) {
            require(msg.value >= price, "");
             
            if (msg.value > price) {
                (bool sent, ) = payable(msg.sender).call{value: msg.value - price}("");
                require(sent, "");
            }
        } else {
            if (msg.value > 0) {
                (bool sent, ) = payable(msg.sender).call{value: msg.value}("");
                require(sent, "");
            }
    ... [26 more lines]
}
```

observing view `getSalePrice`:

```solidity

        if(saleInfos[address(_token)][_tokenId].price != 0) {
            return saleInfos[address(_token)][_tokenId].price;
        }

        if(latestSalePrices[address(_token)][_tokenId] != 0) {
            return latestSalePrices[address(_token)][_tokenId];
        }

        return 0;
    
```

---

## 238. CallistoBridge
- families: classic_reentrancy|cross_function
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) tokenDeposits;
```

exposure `claimToContract` (low_level_call, gas-forwarding=True), writes after call: ['tokenDeposits']

```solidity
function claimToContract(external
        notFrozen

        require(!isTxProcessed[fromChainId][txId], "");
        Token memory pair = tokenPair[fromChainId][token];
        require(pair.token != address(0), "");
        isTxProcessed[fromChainId][txId] = true;

         
        address must = requiredAuthority;
        bytes32 messageHash = keccak256(abi.encodePacked(token, to, value, txId, fromChainId, block.chainid, toContract, data));
        messageHash = prefixed(messageHash);
        uint256 uniqSig;
        uint256 set;     
        for (uint i = 0; i < sig.length; i++) {
            address authority = recoverSigner(messageHash, sig[i]);
            if (authority == must) must = address(0);
            uint256 index = authorities.indexOf(authority);
            uint256 mask = 1 << index;
            if (index != 0 && (set & mask) == 0 ) {
                set |= mask;
                uniqSig++;
            }
        }
        require(threshold <= uniqSig, "");
        require(must == address(0), "");

         
        if(isContract(toContract) && toContract != address(this)) {
            if (token <= MAX_NATIVE_COINS) {
                uint balance = address(this).balance;
                (bool success,) = toContract.call{value: value}(data);  
                if (!success && balance == address(this).balance) {  
                    to.safeTransferETH(value);   
                }
            } else {
                if(pair.isWrapped) {
                    IBEP20TokenCloned(token).mint(address(this), value);
                } else {
                    tokenDeposits[token] -= value;
                }
                if (IBEP20TokenCloned(token).allowance(address(this), toContract) == 0) {  
    ... [23 more lines]
}
```

closure `claim` (writes exposed state):

```solidity

        require(!isTxProcessed[fromChainId][txId], "");
        Token memory pair = tokenPair[fromChainId][token];
        require(pair.token != address(0), "");
        isTxProcessed[fromChainId][txId] = true;
        address must = requiredAuthority;
        bytes32 messageHash = keccak256(abi.encodePacked(token, to, value, txId, fromChainId, block.chainid));
        messageHash = prefixed(messageHash);
        uint256 uniqSig;
        uint256 set;     
        for (uint i = 0; i < sig.length; i++) {
            address authority = recoverSigner(messageHash, sig[i]);
            if (authority == must) must = address(0);
            uint256 index = authorities.indexOf(authority);
            uint256 mask = 1 << index;
            if (index != 0 && (set & mask) == 0 ) {
                set |= mask;
                uniqSig++;
            }
        }
        require(threshold <= uniqSig, "");
        require(must == address(0), "");

        if (token <= MAX_NATIVE_COINS) {
            to.safeTransferETH(value);
    ... [10 more lines]
```

---

## 239. CompoundLens
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

## 240. Basket
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping (address => mapping (address => uint256)) xlpSupply;
```

exposure `withdraw` (low_level_call, gas-forwarding=True), writes after call: ['xlpSupply']

```solidity
function withdraw(public onlyManager

    _withdraw(beefyzap, vault, swper, amount);
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

    _withdraw(beefyzap, vault, swper, amount);
    uint256 inAmount = address(this).balance;
    
    ILiquidCryptoBridge_v1(bridge).depositForUser{value: inAmount}(fee);

    xlpSupply[vault][account] = xlpSupply[vault][account] - amount;
  
```

---


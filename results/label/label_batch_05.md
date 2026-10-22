# Labelling batch 5 (40 contracts)

## 161. BUYA
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

## 162. BaseERC20Guild
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
        } else if (proposals[proposalId].endTime + timeForExecution < block.timestamp) {
            proposals[proposalId].state = ProposalState.Failed;
            emit ProposalStateChanged(proposalId, uint256(ProposalState.Failed));
        } else {
            proposals[proposalId].state = ProposalState.Executed;

            uint256 callsPerOption = proposals[proposalId].to.length / (proposals[proposalId].totalVotes.length - 1);
            i = callsPerOption * (winningOption - 1);
            uint256 endCall = i + callsPerOption;

            permissionRegistry.setERC20Balances();

            for (i; i < endCall; i++) {
                if (proposals[proposalId].to[i] != address(0) && proposals[proposalId].data[i].length > 0) {
                    bytes memory _data = proposals[proposalId].data[i];
    ... [33 more lines]
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
            totalOptions <= to.length && value.length % totalOptions == 0,
            ""
        );
    ... [21 more lines]
```

observing view `getActiveProposalsNow`:

```solidity

        return activeProposalsNow;
    
```

---

## 163. GatesOfOxyaLandSale
- families: classic_reentrancy|cross_function|eoa_assumption|forced_revert|in_loop_call
- closure size: 3 | sites: 1 | loops: 4

state (exposed only):
```solidity
    mapping(address => mapping(uint => uint)) chanceToWinPerAddress;
    mapping(address => mapping(uint => uint)) chanceToWinPerAddressWhitelist;
```

exposure `lottery` (low_level_call, gas-forwarding=True), writes after call: ['chanceToWinPerAddressWhitelist']

```solidity
function lottery(external isInitialized nonReentrant

        require(!isActive, "");
        require(isLotteryActive, "");
        require(tx.origin == msg.sender, "");

        if(chanceToWinPerAddress[msg.sender][0] + chanceToWinPerAddress[msg.sender][1] + chanceToWinPerAddress[msg.sender][2] + chanceToWinPerAddress[msg.sender][3] + chanceToWinPerAddress[msg.sender][4] + chanceToWinPerAddress[msg.sender][5] > 0) {
            ILotteryContractInterface(lotteryAddress).requestRandomWords();
            uint randomNumber = ILotteryContractInterface(lotteryAddress).returnLotteryRandomNumber();
            for(uint i = 0; i < 6; i++) {
                uint count = chanceToWinPerAddress[msg.sender][i];
                if(count != 0){
                    for(uint j = 0; j < count ; j++) {
                         
                        uint randomNumberFinal = uint(keccak256(abi.encodePacked(randomNumber,i, j))) % 1000;
                        emit RandomResult(randomNumberFinal);
                        bool hasWin =  randomNumberFinal < PUBLIC_PERCENTAGE[i];
                        chanceToWinPerAddress[msg.sender][i]-=1;

                        emit IsWinner(hasWin);
                    
                        if(hasWin==true){
                             
                            (bool success, ) = payable(msg.sender).call{value: REWARD}(
                                ""
                            );
                            require(success, "");
                        }
                    } 
                 }     
            }
        }
        if(chanceToWinPerAddressWhitelist[msg.sender][0] + chanceToWinPerAddressWhitelist[msg.sender][1] + chanceToWinPerAddressWhitelist[msg.sender][2] + chanceToWinPerAddressWhitelist[msg.sender][3] + chanceToWinPerAddressWhitelist[msg.sender][4] + chanceToWinPerAddressWhitelist[msg.sender][5] > 0) {
            ILotteryContractInterface(lotteryAddress).requestRandomWords();
            uint randomNumber = ILotteryContractInterface(lotteryAddress).returnLotteryRandomNumber();
            for(uint i = 0; i < 6; i++) {
                uint count = chanceToWinPerAddressWhitelist[msg.sender][i];
                 if(count != 0){
                    for(uint j = 0; j < count ; j++) {
                         
                        uint randomNumberFinal = uint(keccak256(abi.encodePacked(randomNumber,i, j))) % 1000;
    ... [18 more lines]
}
```

in-loop call in `lottery`:

```solidity

                uint count = chanceToWinPerAddress[msg.sender][i];
                if(count != 0){
                    for(uint j = 0; j < count ; j++) {
                         
                        uint randomNumberFinal = uint(keccak256(abi.encodePacked(randomNumber,i, j))) % 1000;
                        emit RandomResult(randomNumberFinal);
                        bool hasWin =  randomNumberFinal < PUBLIC_PERCENTAGE[i];
                        chanceToWinPerAddress[msg.sender][i]-=1;

                        emit IsWinner(hasWin);
                    
                        if(hasWin==true){
                             
                            (bool success, ) = payable(msg.sender).call{value: REWARD}(
                                ""
                            );
                            require(success, "");
                        }
                    } 
                 }     
            
```

closure `whitelistMintStake` (writes exposed state):

```solidity

        require(MerkleProof.verify(proof, root, keccak256(abi.encode(msg.sender, maxPerWallet))), "");
        uint totalSupply=ITestNFT(oxyalandsNFTAddress).totalSupply();
        mint(_quantity, msg.sender, maxPerWallet);

        if(dutchRoundNumber < 6)
            chanceToWinPerAddressWhitelist[msg.sender][dutchRoundNumber] += _quantity;
  
        for(uint i=0; i < _quantity; i++){
            stake(totalSupply + i, msg.sender);
        }   
    
```

closure `unstake` (writes exposed state):

```solidity

        address to = msg.sender;
        ITestNFT(oxyalandsNFTAddress).unstakeNFT(_tokenId, to);
        
         for(uint i = 0; i < 6; i++) {
                uint count = chanceToWinPerAddressWhitelist[to][i];

                if(count != 0){
                    chanceToWinPerAddressWhitelist[to][i] -= count;
                    return;
                }
         }
           for(uint i = 0; i < 6; i++) {
                uint count = chanceToWinPerAddress[to][i];

                if(count != 0){
                    chanceToWinPerAddress[to][i] -= count;
                    return;
                }
         }
    
```

---

## 164. CEXTickets
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 currID;
```

exposure `buy` (low_level_call, gas-forwarding=True), writes after call: ['currID']

```solidity
function buy(public payable nonReentrant

        require(Counters.current(ID) < maxSupply, "");
        require(msg.value == currentPrice(), "");
         
        require(amountBought[_msgSender()] < 1, "");
        
         
        amountBought[_msgSender()] += 1;
        
         
        (bool success,) = payee.call{value: msg.value}("");
        require(success, "");
        
        uint256 currID = Counters.current(ID);
        
         
        Counters.increment(ID);
        
         
        _mint(_msgSender(), currID);
        emit mint(currID, address(this), _msgSender());
    
}
```

---

## 165. ANIMALSMetaClub
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 _vault;
```

exposure `withdrawDividend` (low_level_call, gas-forwarding=True), writes after call: ['_vault']

```solidity
function withdrawDividend(external

		uint256 withdrawableDividend = dividendOf(_msgSender());

		if (withdrawableDividend > 0) {
			_withdrawnDividends[_msgSender()] += withdrawableDividend;
			_dividends[_msgSender()] -= withdrawableDividend;

			emit DividendWithdrawn(_msgSender(), withdrawableDividend);

			(bool success, ) = payable(_msgSender()).call{ value: withdrawableDividend }("");
			require(success, "");

			_vault -= withdrawableDividend;
		}
	
}
```

closure `distributeDividends` (writes exposed state):

```solidity

		uint256 supply = _supply.current();

		require(supply > 13, "");

		if (msg.value > 0) {
			uint256 dividendPerShare = msg.value / (supply - 13);
			uint256 totalDividend = dividendPerShare * (supply - 13);

			for (uint256 i = 14; i <= supply; i++) {
				address owner = ownerOf(i);

				_dividends[owner] += dividendPerShare;
			}

			_vault += totalDividend;

			emit DividendsDistributed(_msgSender(), totalDividend);
		}
	
```

closure `distributeDividendsToSpecifiedAddresses` (writes exposed state):

```solidity

		require(addresses.length > 0, "");

		if (msg.value > 0) {
			uint256 dividendPerShare = msg.value / addresses.length;
			uint256 totalDividend = dividendPerShare * addresses.length;

			for (uint256 i = 0; i < addresses.length; i++) {
				_dividends[addresses[i]] += dividendPerShare;
			}

			_vault += totalDividend;

			emit DividendsDistributed(_msgSender(), totalDividend);
		}
	
```

observing view `vault`:

```solidity

		return _vault;
	
```

---

## 166. Presale
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) balance;
    uint256 cap;
```

exposure `endPresale` (low_level_call, gas-forwarding=True), writes after call: ['cap']

```solidity
function endPresale(public onlyOwner()

        (bool sent, bytes memory data) = (msg.sender).call{value: address(this).balance}("");
        require(sent, "");
        cap = total;
    
}
```

exposure `claim` (transfer, gas-forwarding=False), writes after call: ['balance']

```solidity
function claim(public

        uint256 amount = balance[msg.sender];
        require(amount > 0);
        IERC20(token).transfer(msg.sender, amount * supply / total);
        balance[msg.sender] = 0;
    
}
```

observing view `readEtherBalance`:

```solidity

        return address(this).balance;
    
```

---

## 167. Cucunci
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 specialPrize;
```

exposure `mintCucunci` (low_level_call, gas-forwarding=True), writes after call: ['specialPrize']

```solidity
function mintCucunci(public payable whenNotPaused returns (uint256)


    uint256 seedPrize = getMintSeed();

    if (seedPrize == seed) {
      totalPrize += 1;      
    }

    totalMinted += 1;

    uint256 newItemId = _tokenIds.current();

    require(totalMinted <= totalMints, "");

    uint256 _price = this.price();
    require(msg.value >= _price, "");

     
    if (seedPrize == seed && specialPrize == 0 && specialMints >= 1 && totalSpecial <= 10) {
      specialMints -= 1;
      totalSpecial += 1;

       
      console.log("");

      require(specialMints >= 1);

      console.log("", msg.sender);

      emit PrizeWin(msg.sender);      
        
      uint256 winnerAmount = 0.06 ether;
          
      require(
        winnerAmount <= address(this).balance,
        ""
      );

      (bool success, ) = (msg.sender).call{value: winnerAmount}("");
      
    ... [45 more lines]
}
```

observing view `getTotalSpecialPrize`:

```solidity
    
    console.log("", specialPrize);
    return specialPrize;
  
```

---

## 168. Gr33n
- families: classic_reentrancy|cross_function
- closure size: 1 | sites: 2 | loops: 0

state (exposed only):
```solidity
    uint256 pendingEthReward;
    uint256 totalETHRewardsPaidOut;
```

exposure `withdrawStuckETH` (low_level_call, gas-forwarding=True), writes after call: ['pendingEthReward']

```solidity
function withdrawStuckETH(external

        require(canClaimUnclaimed[msg.sender], "");
        bool success;
        (success, ) = address(msg.sender).call{ value: address(this).balance.sub(pendingEthReward) }(
            ""
        );

        if(pendingETH) {
            require(pendingEthReward > 0, "");

            bool pendingETHsuccess;
            (pendingETHsuccess, ) = address(msg.sender).call{ value: pendingEthReward }(
                ""
            );

            if (pendingETHsuccess) {
                pendingEthReward = pendingEthReward.sub(pendingEthReward);
            }
        }
    
}
```

exposure `swapAndSendBuyWallDividends` (low_level_call, gas-forwarding=True), writes after call: ['pendingEthReward', 'totalETHRewardsPaidOut']

```solidity
function swapAndSendBuyWallDividends(private

        addHolderToGreenWallWinHistory(address(this), address(dividendTracker));

        uint256 pendingRewardsEth = swapTokensForEth(_tokenAmount);

        pendingTokensForReward = pendingTokensForReward.sub(_tokenAmount);

        (bool success, ) = address(dividendTracker).call{value: pendingRewardsEth}(
            ""
        );

        if (success) {
            emit SendBuyWallDividends(pendingRewardsEth);

            dividendTracker.distributeDividends();

            dividendTracker.setGreenWallEnded();

            endGreenWall();
        } else {
            pendingEthReward = pendingEthReward.add(pendingRewardsEth);

            endGreenWall();
        }

        totalETHRewardsPaidOut = totalETHRewardsPaidOut.add(pendingRewardsEth);

    
}
```

---

## 169. PaymentSplitter
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) _released;
    uint256 _totalReleased;
```

exposure `release` (low_level_call, gas-forwarding=True), writes after call: ['_released', '_totalReleased']

```solidity
function release(external

      if (_initRelease > 0) {
        uint256 totalReceived = address(this).balance;
        uint256 payment = _initRelease > totalReceived ? totalReceived : _initRelease;
        require(payment != 0, "");
        _initRelease = _initRelease - payment;
        (bool success, ) = _initAddress.call{value: payment}("");
        require(success);
      } else {
        require(_shares[account] > 0, "");

        uint256 totalReceived = address(this).balance + _totalReleased;
        uint256 payment = totalReceived * _shares[account] / _totalShares - _released[account];

        require(payment != 0, "");

        _released[account] = _released[account] + payment;
        _totalReleased = _totalReleased + payment;
        (bool success, ) = account.call{value: payment}("");
        require(success);
        emit PaymentReleased(account, payment);
      }
    
}
```

observing view `totalReleased`:

```solidity

        return _totalReleased;
    
```

---

## 170. OxODexPool
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 ringIndex;
    mapping(uint256 => uint256) ringsNumber;
```

exposure `deposit` (low_level_call, gas-forwarding=True), writes after call: ['ringIndex', 'ringsNumber']

```solidity
function deposit(external payable whenNotPaused

        require(_amount > 0, "");
        require(msg.value >= _amount, "");

        IOxODexFactory factoryContract = IOxODexFactory(factory);

        if(IERC20(factoryContract.token()).balanceOf(msg.sender) < factoryContract.getTokenFeeDiscountLimit()) {
            uint256 fee = getFeeForAmount(_amount);
            require(msg.value >= _amount+fee, "");

             
            (bool sent,) = factoryContract.treasurerAddress().call{value: fee}("");
            require(sent, "");
        }else{
            uint256 fee = getDiscountFeeForAmount(_amount);

            if(fee > 0) {
                 
                (bool sent,) = factoryContract.treasurerAddress().call{value: fee}("");
                require(sent, "");
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
    ... [36 more lines]
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

## 171. SendValueWithFallbackWithdraw
- families: cross_function|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) pendingWithdrawals;
```

exposure `_sendValueWithFallbackWithdraw` (low_level_call, gas-forwarding=True), writes after call: ['pendingWithdrawals']

```solidity
function _sendValueWithFallbackWithdraw(private

    if (amount == 0) {
      return;
    }
     
     
    (bool success, ) = payable(user).call{ value: amount, gas: gasLimit }("");
    if (!success) {
       
       
       
      pendingWithdrawals[user] = pendingWithdrawals[user] + amount;
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

## 172. PharaGoddessRoyaltyReward
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint amountOfTokensGotPayout;
```

exposure `royaltyPayout` (low_level_call, gas-forwarding=True), writes after call: ['amountOfTokensGotPayout']

```solidity
function royaltyPayout(public onlyOwner

        uint256 balance = address(this).balance;
        require(balance > number * payout, "");
        require(amountOfTokensGotPayout + number <= goddessContract.totalSupply());
        for (uint i; i < number; i++) {
            (bool success, ) = payable(goddessContract.ownerOf(amountOfTokensGotPayout + i)).call{value: payout}("");
            require(success, "");
        }
        if (goddessContract.totalSupply() == amountOfTokensGotPayout + number) {
            amountOfTokensGotPayout = 0;
        }
        else {
            amountOfTokensGotPayout += number;
        }
    
}
```

---

## 173. THORChain_Router
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 2 | loops: 0

state (exposed only):
```solidity
    mapping(address => mapping(address => uint)) vaultAllowance;
```

exposure `deposit` (low_level_call, gas-forwarding=True), writes after call: ['vaultAllowance']

```solidity
function deposit(external payable

        uint safeAmount;
        if(asset == address(0)){
            safeAmount = msg.value;
            (bool success, bytes memory data) = vault.call{value:safeAmount}("");
            require(success && (data.length == 0 || abi.decode(data, (bool))));
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

        uint safeAmount; bool success; bytes memory data;
        if(asset == address(0)){
            safeAmount = msg.value;
            (success, data) = to.call{value:msg.value}("");  
        } else {
            vaultAllowance[msg.sender][asset] -= amount;  
            (success, data) = asset.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
            safeAmount = amount;
        }
        require(success && (data.length == 0 || abi.decode(data, (bool))));
        emit TransferOut(msg.sender, to, asset, safeAmount, memo);
    
}
```

---

## 174. PropsERC721AUpgradeableAccess
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

## 175. AdContract
- families: classic_reentrancy|forced_revert|phase_ordering
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool locked;
```

exposure `addAD` (low_level_call, gas-forwarding=True), writes after call: ['locked']

```solidity
function addAD(external payable

        require(!locked, "");
        locked = true;
        require(msg.value >= tx.gasprice);
        uint ctr;
         
        if (block.timestamp < (adSTAMP[toADD] + 2592000)) {
        	ctr = (adVALUE[toADD] * (2678400 - (block.timestamp - adSTAMP[toADD]))) / 86400;
        	} else {
        	ctr = (adVALUE[toADD] * 86400) / ((block.timestamp - adSTAMP[toADD]) - 2505600);
        }
        require(msg.value > ctr);
        require(block.timestamp > (adSTAMP[toADD] + 86400));  
        adVALUE[toADD] = msg.value;
        adLINK[toADD] = adLINKv;
        adLABEL[toADD] = adLABELv;
        adSTAMP[toADD] = block.timestamp;
        (bool sent, ) = toADD.call{value: (msg.value - (msg.value / 100))}("");
        require(sent, "");
        locked = false;
    
}
```

---

## 176. NFTAuction
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

## 177. AlphaYield
- families: cross_function|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 botsCaught;
    mapping (address => bool) boughtEarly;
    uint256 tokensForBurn;
    uint256 tokensForDev;
    uint256 tokensForLiquidity;
    uint256 tokensForOperations;
```

exposure `_transfer` (low_level_call, gas-forwarding=True), writes after call: ['botsCaught', 'boughtEarly', 'tokensForBurn', 'tokensForDev', 'tokensForLiquidity', 'tokensForOperations']

```solidity
function _transfer(internal override


        require(from != address(0), "");
        require(to != address(0), "");
        require(amount > 0, "");

        if(!tradingActive){
            require(_isExcludedFromFees[from] || _isExcludedFromFees[to], "");
        }

        if(blockForPenaltyEnd > 0){
            require(!boughtEarly[from] || to == owner() || to == address(0xdead), "");
        }

        if(limitsInEffect){
            if (from != owner() && to != owner() && to != address(0) && to != address(0xdead) && !_isExcludedFromFees[from] && !_isExcludedFromFees[to]){

                 
                if (transferDelayEnabled){
                    if (to != address(dexRouter) && to != address(lpPair)){
                        require(_holderLastTransferTimestamp[tx.origin] < block.number - 2 && _holderLastTransferTimestamp[to] < block.number - 2, "");
                        _holderLastTransferTimestamp[tx.origin] = block.number;
                        _holderLastTransferTimestamp[to] = block.number;
                    }
                }

                 
                if (automatedMarketMakerPairs[from] && !_isExcludedMaxTransactionAmount[to]) {
                        require(amount <= maxBuyAmount, "");
                        require(amount + balanceOf(to) <= maxWalletAmount, "");
                }
                 
                else if (automatedMarketMakerPairs[to] && !_isExcludedMaxTransactionAmount[from]) {
                        require(amount <= maxSellAmount, "");
                }
                else if (!_isExcludedMaxTransactionAmount[to]){
                    require(amount + balanceOf(to) <= maxWalletAmount, "");
                }
            }
        }
    ... [70 more lines]
}
```

closure `manageBoughtEarly` (writes exposed state):

```solidity

        boughtEarly[wallet] = flag;
    
```

---

## 178. SUPE
- families: classic_reentrancy
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
        (bool lpAdded,) = _primaryLP.call(abi.encodeWithSignature("") );
        require(lpAdded, "");
        _isLP[_primaryLP] = lpAdded;
        _openTrading();
    
}
```

---

## 179. OneMintRegistry
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

## 180. HammyInu
- families: cross_function|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 swapThreshold;
```

exposure `swapBack` (low_level_call, gas-forwarding=True), writes after call: ['swapThreshold']

```solidity
function swapBack(internal swapping


        uint256 _totalFee = totalFee.sub(reflectionFee);
        uint256 amountToLiquify = swapThreshold.mul(liquidityFee).div(_totalFee).div(2);
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
        uint256 totalETHFee = _totalFee.sub(liquidityFee.div(2));
        uint256 amountETHLiquidity = amountETH.mul(liquidityFee).div(totalETHFee).div(2);
        uint256 amountETHMarketing = amountETH.mul(marketingFee).div(totalETHFee);
        uint256 amountETHGiveaway = amountETH.mul(giveawayFee).div(totalETHFee);

        if (amountETHMarketing.add(amountETHGiveaway) > 0) {
            (bool success,) = payable(marketingFeeReceiver).call{value: amountETHMarketing.add(amountETHGiveaway), gas: 30000}("");
            require(success, "");
        }

        if(amountToLiquify > 0) {
            router.addLiquidityETH{value: amountETHLiquidity}(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLiquidityReceiver,
                block.timestamp
            );
    ... [5 more lines]
}
```

closure `setSwapBackSettings` (writes exposed state):

```solidity

        require(isTxLimitExempt[msg.sender]);
        alternateSwaps = _alternate;
        claimingFees = _enabled;
        smallSwapThreshold = _amountS;
        largeSwapThreshold = _amountL;
        swapThreshold = smallSwapThreshold;
    
```

---

## 181. Ring
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

## 182. ZelenskyNFT
- families: classic_reentrancy|cross_function|eoa_assumption|forced_revert|read_only
- closure size: 3 | sites: 3 | loops: 0

state (exposed only):
```solidity
    uint256 charitySum;
    mapping(address => uint256) mints;
    uint256 saleSum;
    uint256 teamSum;
    mapping(address => bool) whitelistClaimed;
```

exposure `buy` (low_level_call, gas-forwarding=True), writes after call: ['mints', 'saleSum', 'whitelistClaimed']

```solidity
function buy(public payable whitelistActive

        require(msg.sender == tx.origin, "");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_proof, root, leaf), "");
        require(whitelistClaimed[msg.sender] == false, "");
        
        require(amount <= amountWhitelist, "");
        require(mints[msg.sender] + amount <= amountWhitelist, "");
        
        require(nextId + amount <= maxTotalSupply, "");
        uint256 price;
        price = priceWhitelist;

        require(msg.value >= price * amount, "");

        if(msg.value > price * amount){
            uint256 refundAmount = msg.value - price * amount;
            (bool sent, bytes memory data) = msg.sender.call{value: refundAmount}("");
            require(sent, "");
            emit Refund(msg.sender, refundAmount, data);
        }
        
        mints[msg.sender] += amount;

        saleSum += price * amount;

        whitelistClaimed[msg.sender] = true;

        _mint(msg.sender, amount);
    
}
```

exposure `buyDefault` (low_level_call, gas-forwarding=True), writes after call: ['mints', 'saleSum']

```solidity
function buyDefault(public payable whitelistEnded

        require(mintStopped == false, "");
         
        require(msg.sender == tx.origin, "");
        require(mints[msg.sender] + amount <= amountDefault, "");

        require(nextId + amount <= maxTotalSupply - communityMintSupply, "");
        uint256 price;
        price = priceDefault;

        require(msg.value >= price * amount, "");

        if(msg.value > price * amount){
            uint256 refundAmount = msg.value - price * amount;
            (bool sent, bytes memory data) = msg.sender.call{value: refundAmount}("");
            require(sent, "");
            emit Refund(msg.sender, refundAmount, data);
        }

        mints[msg.sender] += amount;

        saleSum += price * amount;

        _mint(msg.sender, amount);
    
}
```

closure `communityBuy` (writes exposed state):

```solidity

        require(mintStopped, "");
        require(msg.sender == tx.origin, "");
        require(amount <= amountWhitelist, "");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_proof, communityRoot, leaf), "");
        require(whitelistClaimed[msg.sender] == false, "");

        require(nextId + amount <= maxTotalSupply, "");
        require(communitySold + amount <= communityMintSupply, "");
        mints[msg.sender] += amount;

        communitySold += amount;

        _mint(msg.sender, amount);
    
```

observing view `getCharitySum`:

```solidity

        return charitySum;
    
```

---

## 183. Showcase
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) numSlotsPaid;
```

exposure `payForSlots` (low_level_call, gas-forwarding=True), writes after call: ['numSlotsPaid']

```solidity
function payForSlots(external payable

        require(
            msg.value == pricePerSlot * _newSlots,
            ""
        );

        (bool sent, ) = payable(treasuryAddress).call{value: msg.value}("");

        require(sent, "");

        numSlotsPaid[msg.sender] = numSlotsPaid[msg.sender] + _newSlots;
    
}
```

---

## 184. market
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(uint256 => uint256) tokenIdToPrice;
```

exposure `buy` (low_level_call, gas-forwarding=True), writes after call: ['tokenIdToPrice']

```solidity
function buy(external payable

        uint256 price = tokenIdToPrice[_tokenId];
        require(price > 0, "");
        require(msg.value == price, "");

        address seller = ownerOf(_tokenId);
        (bool sent, ) =  payable(seller).call{value: msg.value}("");
        require(sent, "");

        _transfer(seller, msg.sender, _tokenId);
        tokenIdToPrice[_tokenId] = 0;  

        emit NftBought(seller, msg.sender, msg.value);
    
}
```

closure `allowBuy` (writes exposed state):

```solidity

        require(msg.sender == ownerOf(_tokenId), "");
        require(_price > 0, "");
        tokenIdToPrice[_tokenId] = _price;
    
```

closure `disallowBuy` (writes exposed state):

```solidity

        require(msg.sender == ownerOf(_tokenId), "");
        tokenIdToPrice[_tokenId] = 0;
    
```

---

## 185. RoolahShopUpgradableV4
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 3 | sites: 3 | loops: 0

state (exposed only):
```solidity
    mapping(bytes32 => uint256) unitsSold;
    mapping(bytes32 => mapping(address => uint256)) userPurchases;
```

exposure `transact` (low_level_call, gas-forwarding=True), writes after call: ['unitsSold', 'userPurchases']

```solidity
function transact(external payable

        uint256 quantity = numericParams[2];

         
        require(numericParams[0] > block.timestamp, "");

         
        require(
            numericParams[1] == 0 || numericParams[1] >= unitsSold[listingId] + quantity,
            ""
        );

         
        require(
            numericParams[3] == 0 ||
                numericParams[3] >= userPurchases[listingId][msg.sender] + quantity,
            ""
        );

        uint256 priceROOLAH = numericParams[5];
        require(
            _verifySignature(
                listingId,
                transactionId,
                roolahReceiver,
                numericParams,  
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

         
        if (numericParams[4] > 0) {
    ... [20 more lines]
}
```

exposure `transactERC721` (low_level_call, gas-forwarding=True), writes after call: ['unitsSold', 'userPurchases']

```solidity
function transactERC721(external payable

         
        require(numericParams[0] > block.timestamp, "");
        require(tokenIds.length == tokenAddresses.length, "");

        require(
            _verifySignatureNFT(
                listingId,
                transactionId,
                roolahReceiver,
                numericParams,  
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

         
        if (numericParams[1] > 0) {
            require(msg.value == numericParams[1], "");
            (bool success, ) = etherRecipient.call{value: numericParams[1]}("");
            require(success, "");
        }

        userPurchases[listingId][msg.sender] += 1;
        unitsSold[listingId] += 1;

         
        if (numericParams[2] > 0)
            roolahContract.transferFrom(
                msg.sender,
                roolahReceiver == address(0) ? address(this) : roolahReceiver,
    ... [13 more lines]
}
```

---

## 186. KatRoyalties
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

## 187. SignataDAO
- families: classic_reentrancy|phase_ordering
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 lastSwapTime;
    bool swapping;
```

exposure `swapCollectedFees` (low_level_call, gas-forwarding=True), writes after call: ['lastSwapTime', 'swapping']

```solidity
function swapCollectedFees(public onlyOwner

        swapping = true;
        uint256 tokenBalance = balanceOf(address(this));

        bool success;

         
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenBalance);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenBalance,
            0,  
            path,
            address(this),
            block.timestamp
        );

        (success,) = address(feeNativeReceiver).call{value: address(this).balance}("");

        lastSwapTime = block.timestamp;
        swapping = false;
        
        emit TaxesSwappedForNative(feeNativeReceiver);
    
}
```

---

## 188. Kiba2
- families: classic_reentrancy
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
        (bool lpAdded,) = _primaryLP.call(abi.encodeWithSignature("") );
        require(lpAdded, "");
        _isLP[_primaryLP] = lpAdded;
        _openTrading();
    
}
```

---

## 189. SHIBB
- families: cross_function|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 _ethReserves;
    uint256 _liquidityReserves;
    mapping (address => uint256) lastTrade;
```

exposure `_transfer` (low_level_call, gas-forwarding=True), writes after call: ['_ethReserves', '_liquidityReserves', 'lastTrade']

```solidity
function _transfer(internal override

        require(from != address(0), "");
        require(to != address(0), "");
        require(balanceOf(from) >= amount, "");

        if(onlyDev) {
            require(_isExcludedFromFees[from] || _isExcludedFromFees[to], "");
        }
           
        if(botBlock) {
            require(_buyBlock[from] != block.number, "");
            _buyBlock[to] = block.number;
        }

        if(sameBlockActive){	
             
            if(_isSniper[from] && to != marketing) {	
                revert("");	
            }
        
            if(block.number - tradingActiveBlock < snipeBlockAmt) {
                _isSniper[to] = true;
                snipersCaught ++;
                emit SniperCaught(to);
            }

            if(mevRepel) {
                if(automatedMarketMakerPairs[from]){
                    lastBuy[to] = block.number;
                }
                if(automatedMarketMakerPairs[to]){
                    lastSell[from] = block.number;
                }
            
            if(_isBot[from] && to != marketing) {	
                revert("");	
                }

            if(lastBuy[to] == lastSell[from]) {
                _isBot[to] = true;
    ... [68 more lines]
}
```

closure `deposit` (writes exposed state):

```solidity

        require(
            amount > 0,
            ""
        );
         uint256 marketingShare = amount;
        _ethReserves += marketingShare;

        address from = _msgSender();
        super._transfer(from, address(this), marketingShare);
        return true;
    
```

---

## 190. AuctionHouse
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
                freakyflowers.mint(_bidders[i]);
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
                freakyflowers.mint(_bidders[i]);
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

## 191. NFT
- families: classic_reentrancy|forced_revert|read_only
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => bool) _freeNFTClaimed;
```

exposure `buy` (low_level_call, gas-forwarding=True), writes after call: ['_freeNFTClaimed']

```solidity
function buy(public whenNotPaused payable

        require(_count <= _limitPerTransaction, "");
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

## 192. Presale
- families: classic_reentrancy|cross_function|forced_revert|read_only
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint256 totalTokenBuyer;
    uint256 totalTokensSold;
    uint256 totalUSDTRaised;
    mapping(address => uint256) userBought;
```

exposure `buyWithUSDT` (low_level_call, gas-forwarding=True), writes after call: ['totalTokenBuyer', 'totalTokensSold', 'totalUSDTRaised', 'userBought']

```solidity
function buyWithUSDT(external returns (bool)

        require(timeStage == 0, "");

        uint256 usdtAmt;

        (usdtAmt, currentStep) = calculatePaymentUSDT(amount);

        uint256 ourAllowance = IERC20(USDTAddr).allowance(
            msg.sender,
            address(this)
        );
        require(usdtAmt <= ourAllowance, "");
        (bool success, ) = address(USDTAddr).call(
            abi.encodeWithSignature(
                "",
                msg.sender,
                owner,
                usdtAmt
            )
        );
        require(success, "");

        if (userBought[msg.sender] == 0) totalTokenBuyer += 1;
        userBought[msg.sender] += amount;
        totalTokensSold += amount;
        totalUSDTRaised += usdtAmt;

        emit TokensBought(
            msg.sender,
            amount,
            address(USDTAddr),
            usdtAmt,
            currentStep,
            block.timestamp
        );
        return true;
    
}
```

closure `buyWithETH` (writes exposed state):

```solidity

        require(timeStage == 0, "");

        uint256 ethAmt;

        (ethAmt, currentStep) = calculatePaymentETH(amount);
        require(msg.value > (ethAmt * 98) / 100, "");

        if (userBought[msg.sender] == 0) totalTokenBuyer += 1;
        userBought[msg.sender] += amount;
        totalTokensSold += amount;
        totalETHRaised += msg.value;
        sendValue(payable(owner), msg.value);

        emit TokensBought(
            msg.sender,
            amount,
            address(0),
            ethAmt,
            currentStep,
            block.timestamp
        );
        return true;
    
```

observing view `totalFundRaised`:

```solidity

        return (totalUSDTRaised *
            10**12 +
            (totalETHRaised * getLatestPrice()) /
            decimalToken);
    
```

---

## 193. PlungePoolThree
- families: classic_reentrancy|forced_revert
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint256) totalRewardsToUser;
```

exposure `distributeDividend` (low_level_call, gas-forwarding=True), writes after call: ['totalRewardsToUser']

```solidity
function distributeDividend(external onlyToken

        uint256 amount = getPendingDividend(_shareholder);

        if (amount > 0) {
            shares[_shareholder].totalExcluded = getCumulativeDividends(
                shares[_shareholder].amount,
                shares[_shareholder].started,
                shares[_shareholder].unlocks
            );
            shares[_shareholder].totalRealised += amount;
            totalDistributed += amount;

            (bool success, ) = _shareholder.call{value: amount}("");
            require(success, "");

            totalRewardsToUser[_shareholder] = totalRewardsToUser[_shareholder] + amount;
        }
    
}
```

---

## 194. Reptilands
- families: classic_reentrancy|cross_function|forced_revert
- closure size: 2 | sites: 1 | loops: 0

state (exposed only):
```solidity
    mapping(address => uint) firstWhitelist;
    mapping(address => uint) secondWhitelist;
```

exposure `mint` (low_level_call, gas-forwarding=True), writes after call: ['firstWhitelist', 'secondWhitelist']

```solidity
function mint(public
        payable
        mintCompliance(_mintAmount)
 

        require(msg.value >= cost * _mintAmount, "");

        (bool success, ) = msg.sender.call{value: msg.value - cost * _mintAmount}("");
        require(success, "");

        if (state == State.FIRST_WHITELIST) {
            firstWhitelist[msg.sender] -= _mintAmount;
        }
        if (state == State.SECOND_WHITELIST) {
            secondWhitelist[msg.sender] -= _mintAmount;
        }

        _mintLoop(msg.sender, _mintAmount);
    
}
```

closure `setAddressInWhitelist` (writes exposed state):

```solidity

        if(_whitelist == 1) {
            firstWhitelist[_objective] = _amount;
        } else if (_whitelist == 2) {
            secondWhitelist[_objective] = _amount;
        } else {
            revert("");
        }
    
```

---

## 195. NVA
- families: classic_reentrancy|forced_revert|phase_ordering
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    bool _locked;
```

exposure `withdrawEther` (low_level_call, gas-forwarding=True), writes after call: ['_locked']

```solidity
function withdrawEther(public

        require(!_locked, "");
        _locked = true;
        require(msg.sender == _owner);
        require(address(this).balance >= amount, "");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "");
		emit WithdrawEther(recipient, amount);
        _locked = false;
    
}
```

---

## 196. KimberlyDiamonds
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

## 197. Blueprint
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

## 198. AggregatedFinance
- families: cross_function
- closure size: 1 | sites: 1 | loops: 0

state (exposed only):
```solidity
    uint8 swapIndex;
    uint256 tokensForC1;
    uint256 tokensForC2;
    uint256 tokensForC3;
    uint256 tokensForC4;
    uint256 tokensForC5;
```

exposure `_executeSwap` (low_level_call, gas-forwarding=True), writes after call: ['swapIndex', 'tokensForC1', 'tokensForC2', 'tokensForC3', 'tokensForC4', 'tokensForC5']

```solidity
function _executeSwap(private


        uint256 contractTokenBalance = balanceOf(address(this));

        if (contractTokenBalance <= 0) { return; }

        

        if (swapIndex == 0 && swapC1Enabled && tokensForC1 > 0) {

             

            swapTokensForNative(tokensForC1);

            (bool success, ) = payable(c1Wallet).call{value: address(this).balance}("");

            if (success) {

                emit SendChannel1(tokensForC1);

            } else {

                emit LogErrorString("");

            }

            tokensForC1 = 0;



        } else if (swapIndex == 1 && swapC2Enabled && tokensForC2 > 0) {

             

            if (c2BurningEnabled) {

                _burn(address(this), tokensForC2);

                emit TokensBurned(tokensForC2);

    ... [101 more lines]
}
```

closure `withdrawCollectedFees` (writes exposed state):

```solidity


        _executeTransfer(address(this), msg.sender, balanceOf(address(this)));

        tokensForC1 = 0;

        tokensForC2 = 0;

        tokensForC3 = 0;

        tokensForC4 = 0;

        tokensForC5 = 0;

        emit FeesWithdrawn();

    
```

---

## 199. BlueprintV12
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

## 200. HappyHuskies
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
      (bool Os, ) = payable(0x7fa5ac379bA7eDd1A8c51fE7C28382f681D0105A).call{
        value: (contractBalance)
      }("");
      require(Os, "");
    } else {
      (bool Os, ) = payable(0x7fa5ac379bA7eDd1A8c51fE7C28382f681D0105A).call{
        value: 6 ether
      }("");
      require(Os, "");
    }

    web3Withdrawn = true;
  
}
```

---


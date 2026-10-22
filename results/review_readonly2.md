# readonly candidates for manual scope review
source: results/scan_scs_mainnet.csv | 50 distinct

## 1. TestContractOffererNativeToken: generateOrder() -> view previewOrder()
- file: `00000000000001ad428e4906aE43D8F9852d0dD6_Seaport.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: fulfilled

state:
```solidity
    address private immutable _SEAPORT;
    SpentItem private _available;
    SpentItem private _required;
    bool public ready;
    bool public fulfilled;
```

exposure function:
```solidity
function generateOrder(
        address,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata /* context */
    )
        external
        virtual
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Set the offer and consideration that were supplied during deployment.
        offer = new SpentItem[](1);
        consideration = new ReceivedItem[](1);

        // Send eth to Seaport.
        (bool success, ) = _SEAPORT.call{ value: minimumReceived[0].amount }(
            ""
        );

        // Revert if transaction fails.
        if (!success) {
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        // Set the offer item as the _available item in storage.
        offer[0] = minimumReceived[0];

        // Set the erc721 consideration item.
        consideration[0] = ReceivedItem({
            itemType: ItemType.ERC721,
            token: maximumSpent[0].token,
            identifier: maximumSpent[0].identifier,
            amount: maximumSpent[0].amount,
            recipient: payable(address(this))
        });

        // Update storage to reflect that the order has been fulfilled.
        fulfilled = true;
    }
```

flagged view:
```solidity
function previewOrder(
        address caller,
        address,
        SpentItem[] calldata,
        SpentItem[] calldata,
        bytes calldata context
    )
        external
        view
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Ensure the caller is Seaport & the order has not yet been fulfilled.
        if (!ready || fulfilled || caller != _SEAPORT || context.length != 0) {
            revert OrderUnavailable();
        }

        // Set the offer and consideration that were supplied during deployment.
        offer = new SpentItem[](1 + extraAvailable);
        consideration = new ReceivedItem[](1 + extraRequired);

        for (uint256 i = 0; i < 1 + extraAvailable; ++i) {
            offer[i] = _available;
        }

        for (uint256 i = 0; i < 1 + extraRequired; ++i) {
            consideration[i] = ReceivedItem({
                itemType: _required.itemType,
                token: _required.token,
                identifier: _required.identifier,
    ... [5 more lines]
```

---

## 2. PPAgentV2: execute_44g58pv() -> view getKeeper()
- file: `000000000000774D54F4064ec64bEaAdeF498Ae8_PPAgentV2.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: compensations

state:
```solidity
    IERC20 public immutable CVP;
    address worker;
    address jobAddress;
    bool ok;
    bool jobChanged;
    address jobAddress;
    bool useJobOwnerCredits;
    bool assertResolverSelector;
```

exposure function:
```solidity
function execute_44g58pv() external {
    uint256 gasStart = gasleft();
    bytes32 jobKey;

    assembly ("memory-safe") {
      // size of (address(bytes20)+id(uint24/bytes3))
      let size := 23

      // keccack256(address+id(uint24)) to memory to generate jobKey
      calldatacopy(0, 4, size)
      jobKey := keccak256(0, size)
    }

    address jobAddress;
    uint256 keeperId;
    uint256 cfg;

    assembly ("memory-safe") {
      // load jobAddress, cfg, and keeperId from calldata to the stack
      jobAddress := shr(96, calldataload(4))
      cfg := shr(248, calldataload(27))
      keeperId := shr(232, calldataload(28))
    }

    // 0. Keeper has sufficient stake
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

    // 1. Assert the job is active
    {
      if (!ConfigFlags.check(binJob, CFG_ACTIVE)) {
        revert InactiveJob(jobKey);
      }
    }

    // 2. Assert job-scoped keeper's minimum CVP deposit
    if (ConfigFlags.check(binJob, CFG_CHECK_KEEPER_MIN_CVP_DEPOSIT) && keepers[keeperId].cvpStake < jobMinKeeperCvp[jobKey]) {
      revert InsufficientJobScopedKeeperStake();
    }

    // 3. For interval job ensure the interval has passed
    {
      uint256 intervalSeconds = (binJob << 32) >> 232;

      if (intervalSeconds > 0) {
        uint256 lastExecutionAt = binJob >> 224;
        if (lastExecutionAt > 0) {
          uint256 nextExecutionAt;
          unchecked {
            nextExecutionAt = lastExecutionAt + intervalSeconds;
          }
    ... [161 more lines]
```

flagged view:
```solidity
function getKeeper(uint256 keeperId_)
    external view returns (
      address admin,
      address worker,
      uint256 currentStake,
      uint256 slashedStake,
      uint256 compensation,
      uint256 pendingWithdrawalAmount,
      uint256 pendingWithdrawalEndAt
    )
  {
    return (
      keeperAdmins[keeperId_],
      keepers[keeperId_].worker,
      keepers[keeperId_].cvpStake,
      slashedStakeOf[keeperId_],
      compensations[keeperId_],
      pendingWithdrawalAmounts[keeperId_],
      pendingWithdrawalEndsAt[keeperId_]
    );
  }
```

---

## 3. Baal: submitProposal() -> view state()
- file: `00BD22D2cE75422E7B16351F72524174672D5D64_BaalSummoner.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: proposals

state:
```solidity
    bytes memory encodedActions;
```

exposure function:
```solidity
function submitProposal(
        bytes calldata proposalData,
        uint32 expiration,
        uint256 baalGas,
        string calldata details
    ) external payable nonReentrant returns (uint256) {
        require(
            expiration == 0 ||
                expiration > block.timestamp + votingPeriod + gracePeriod,
            "expired"
        );
        require(baalGas <= 20000000, "baalGas to high"); /* gwei 2/3 eth block limit */

        bool selfSponsor = false; /*plant sponsor flag*/
        if (sharesToken.getVotes(_msgSender()) >= sponsorThreshold ) {
            selfSponsor = true; /*if above sponsor threshold, self-sponsor*/
        } else {
            require(msg.value == proposalOffering, "Baal requires an offering"); /*Optional anti-spam gas token tribute*/
            (bool _success, ) = target.call{value: msg.value}(""); /*Send ETH to sink*/
            require(_success, "could not send");
        }

        bytes32 proposalDataHash = hashOperation(proposalData); /*Store only hash of proposal data*/

        proposalCount++; /*increment proposal counter*/
        proposals[proposalCount] = Proposal( /*push params into proposal struct - start voting period timer if member submission*/
            proposalCount,
            selfSponsor ? latestSponsoredProposalId : 0, /* prevProposalId */
            selfSponsor ? uint32(block.timestamp) : 0, /* votingStarts */
            selfSponsor ? uint32(block.timestamp) + votingPeriod : 0, /* votingEnds */
            selfSponsor
                ? uint32(block.timestamp) + votingPeriod + gracePeriod
                : 0, /* graceEnds */
            expiration,
            baalGas,
            0, /* yes votes */
            0, /* no votes */
            selfSponsor ? totalSupply() : 0, /* maxTotalSharesAndLootAtVote */
            [false, false, false, false], /* [cancelled, processed, passed, actionFailed] */
            selfSponsor ? _msgSender() : address(0),
            proposalDataHash
        );

        if (selfSponsor) {
            latestSponsoredProposalId = proposalCount;
        }

        emit SubmitProposal(
            proposalCount,
            proposalDataHash,
            votingPeriod,
            proposalData,
            expiration,
            baalGas,
            selfSponsor,
            block.timestamp,
            details
        ); /*emit event reflecting proposal submission*/

        return proposalCount;
    ... [1 more lines]
```

flagged view:
```solidity
function state(uint32 id) public view returns (ProposalState) {
        Proposal memory prop = proposals[id];
        if (prop.id == 0) {
            /*Uninitialized state*/
            return ProposalState.Unborn;
        } else if (
            prop.status[0] /* cancelled */
        ) {
            return ProposalState.Cancelled;
        } else if (
            prop.votingStarts == 0 /*Voting has not started*/
        ) {
            return ProposalState.Submitted;
        } else if (
            block.timestamp <= prop.votingEnds /*Voting in progress*/
        ) {
            return ProposalState.Voting;
        } else if (
            block.timestamp <= prop.graceEnds /*Proposal in grace period*/
        ) {
            return ProposalState.Grace;
        } else if (
            prop.noVotes >= prop.yesVotes /*Voting has concluded and failed to pass*/
        ) {
            return ProposalState.Defeated;
        } else if (
            prop.status[1] /* processed */
        ) {
            return ProposalState.Processed;
        }
    ... [5 more lines]
```

---

## 4. Vault: claimFees() -> view getClaimedRewardsTotal()
- file: `00CB1fce3fAeB702a3EC8c8E1946D3fc252c11Ad_Vault.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: totalDistributed

state:
```solidity
    address public vesch;
    IERC20 public immutable SCH;
```

exposure function:
```solidity
function claimFees(address _voter) external override returns (uint256) {
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

flagged view:
```solidity
function getClaimedRewardsTotal() external view returns (uint256) {
        return totalDistributed;
    }
```

---

## 5. ERC721Matcha: bid() -> view canSell()
- file: `0169f434435c0176ac85b7c6e5d9dfdb4d0c5935_ERC721Matcha.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: auctions

state:
```solidity
    address payable admin;
    address public contract_owner;
    address payable beneficiary;
    uint auctionEnd;
    address payable highestBidder;
    uint highestBid;
    bool open;
```

exposure function:
```solidity
function bid(uint256 tokenId) external payable nonReentrant {

        // Contracts cannot bid, because they can block the auction with a reentrant attack
        require(msg.sender == tx.origin, "No script kiddies");

        // auction has to be opened
        require(auctions[tokenId].open, "No opened auction found");

        // approve was lost
        require(getApproved(tokenId) == address(this), "Cannot complete the auction");

        // Revert the call if the bidding
        // period is over.
        require(
            block.timestamp <= auctions[tokenId].auctionEnd,
            "Auction already ended."
        );

        // If the bid is not higher, send the
        // money back.
        require(
            msg.value > auctions[tokenId].highestBid,
            "There already is a higher bid."
        );

        address owner = ownerOf(tokenId);
        require(msg.sender!=owner, "ERC721Matcha: The owner cannot bid his own collectible");

        // return the funds to the previous bidder, if there is one
        if (auctions[tokenId].highestBid>0) {
            (bool success, ) = auctions[tokenId].highestBidder.call{value: auctions[tokenId].highestBid}("");
            require(success, "Transfer failed.");
            emit Refund(auctions[tokenId].highestBidder, auctions[tokenId].highestBid);
        }

        // now store the bid data
        auctions[tokenId].highestBidder = payable(msg.sender);

        // register the highest bid value
        auctions[tokenId].highestBid = msg.value;

        emit HighestBidIncreased(msg.sender, msg.value, tokenId);

    }
```

flagged view:
```solidity
function canSell(uint256 tokenId) external view returns (bool) {
        return (ownerOf(tokenId)==msg.sender && !auctions[tokenId].open);
    }
```

---

## 6. AsterFi: withdraw() -> view adminFullBalance()
- file: `0193B85c38337EB90338Ed8660810ba66c548b62_AsterFi.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: AdminBalance

state:
```solidity
    address public newOwner;
    address public owner;
    string public BaseURI;
    string public NotRevealedURI;
    bool private pubSaleActive;
    bool public REVEAL;
    ContractStatus public contractStatus;
    bool revealed;
    address tokenBackup;
```

exposure function:
```solidity
function withdraw() external onlyOwner {
        require(AdminBalance != 0, "adminBalanceIs0");
        (bool sent, bytes memory data) = owner.call{value: AdminBalance}("");
        require(sent, "TX_FAILED");
        AdminBalance = 0;
    }
```

flagged view:
```solidity
function adminFullBalance()
        public
        view
        returns (
            uint256 ETH,
            uint256 token1,
            uint256 token2,
            uint256 token3,
            uint256 token4,
            uint256 token5,
            uint256 token6,
            uint256 token7,
            uint256 token8,
            uint256 token9,
            uint256 token10
        )
    {
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
    ... [1 more lines]
```

---

## 7. OneMintRegistry: setApprovalMapping() -> view isMappingApproved()
- file: `046688068a38e5DF1717e30AE192C761c873df60_OneMintRegistry.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: _addonApprovals

state:
```solidity
    address tempAddress;
```

exposure function:
```solidity
function setApprovalMapping(address address721, address address1155) public {
    require(address721.isContract() && address1155.isContract());
    bytes memory signature = abi.encodeWithSignature("owner()");
    (bool _success1, bytes memory owner1) = address721.call(signature);
    (bool _success2, bytes memory owner2) = address1155.call(signature);

    require(_success1 && _success2);
    address one = toAddress(owner1, 12);
    address two = toAddress(owner2, 12);

    require(one == two, "NOT SAME OWNER");
    require(one == msg.sender, "NOT OWNER");

    _addonApprovals[address721][address1155] = true;
  }
```

flagged view:
```solidity
function isMappingApproved(address address721, address address1155)
    public
    view
    returns (bool)
  {
    return _addonApprovals[address721][address1155];
  }
```

---

## 8. HelixNFTBridge: wrap() -> view isBridged()
- file: `05a1578c4cc7478c3A66a83FdE5F36f77bB93a99_HelixNFTBridge.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: _wrappedNftIDs

state:
```solidity
    address public admin;
    HelixNFT helixNFT;
```

exposure function:
```solidity
function wrap(string memory _encryptExternalID, string[] calldata _nftIDs, string memory _tokenURI) 
      external
      whenNotPaused
      payable
    {
        address _user = msg.sender;
        require(_nftIDs.length != 0, "HelixNFTBridge:Not Array");
        
        require(msg.value >= gasFeeToAdmin, "HelixNFTBridge:Insufficient Amount to send Fee to Admin");
        (bool success, ) = payable(admin).call{value: gasFeeToAdmin}("");
        require(success, "HelixNFTBridge:receiver rejected ETH transfer");

        uint256 length = _nftIDs.length;
        for (uint256 i = 0; i < length; i++) {
            string memory _nftID = _nftIDs[i];
            require(!_wrappedNftIDs[_nftID], "HelixNFTBridge:Already Wrapped token");
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
        // Relay the bridge id to the user's account
        bridgeFactoryIDs[_user].push(_bridgeFactoryId);

        emit Wrap(_user, _bridgeFactoryId);
    }
```

flagged view:
```solidity
function isBridged(string calldata _externalTokenID) external view returns (bool) {
        return _wrappedNftIDs[_externalTokenID];
    }
```

---

## 9. L1CrossDomainMessenger: relayMessage() -> view xDomainMessageSender()
- file: `06C1F0e18B33500c17eeeD1317d7456f8AA2dFBC_ABDropManagerV2.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: xDomainMsgSender

exposure function:
```solidity
function relayMessage(
        address _target,
        address _sender,
        bytes memory _message,
        uint256 _messageNonce,
        L2MessageInclusionProof memory _proof
    ) public nonReentrant whenNotPaused {
        bytes memory xDomainCalldata = Lib_CrossDomainUtils.encodeXDomainCalldata(
            _target,
            _sender,
            _message,
            _messageNonce
        );

        require(
            _verifyXDomainMessage(xDomainCalldata, _proof) == true,
            "Provided message could not be verified."
        );

        bytes32 xDomainCalldataHash = keccak256(xDomainCalldata);

        require(
            successfulMessages[xDomainCalldataHash] == false,
            "Provided message has already been received."
        );

        require(
            blockedMessages[xDomainCalldataHash] == false,
            "Provided message has been blocked."
        );

        require(
            _target != resolve("CanonicalTransactionChain"),
            "Cannot send L2->L1 messages to L1 system contracts."
        );

        xDomainMsgSender = _sender;
        // slither-disable-next-line reentrancy-no-eth, reentrancy-events, reentrancy-benign
        (bool success, ) = _target.call(_message);
        // slither-disable-next-line reentrancy-benign
        xDomainMsgSender = Lib_DefaultValues.DEFAULT_XDOMAIN_SENDER;

        // Mark the message as received if the call was successful. Ensures that a message can be
        // relayed multiple times in the case that the call reverted.
        if (success == true) {
            // slither-disable-next-line reentrancy-no-eth
            successfulMessages[xDomainCalldataHash] = true;
            // slither-disable-next-line reentrancy-events
            emit RelayedMessage(xDomainCalldataHash);
        } else {
            // slither-disable-next-line reentrancy-events
            emit FailedRelayedMessage(xDomainCalldataHash);
        }

        // Store an identifier that can be used to prove that the given message was relayed by some
        // user. Gives us an easy way to pay relayers for their work.
        bytes32 relayId = keccak256(abi.encodePacked(xDomainCalldata, msg.sender, block.number));
        // slither-disable-next-line reentrancy-benign
        relayedMessages[relayId] = true;
    }
```

flagged view:
```solidity
function xDomainMessageSender() public view returns (address) {
        require(
            xDomainMsgSender != Lib_DefaultValues.DEFAULT_XDOMAIN_SENDER,
            "xDomainMessageSender is not set"
        );
        return xDomainMsgSender;
    }
```

---

## 10. KWWVaultEth: withdrawBoatFees() -> view boatAvailableToWithdraw()
- file: `070781dd99118884e246d0d865e784b2fbcbe8d6_KWWVaultEth.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: boatsWithdrawAmount

state:
```solidity
    address gameManager;
```

exposure function:
```solidity
function withdrawBoatFees(uint16 totalSupply, uint16 boatId, address addr) public onlyGameManager{
        uint256 availableToWithdraw = boatAvailableToWithdraw(totalSupply, boatId);
        (bool os, ) = payable(addr).call{value: availableToWithdraw}("");
        require(os);
        boatsWithdrawAmount[boatId] += availableToWithdraw;
    }
```

flagged view:
```solidity
function boatAvailableToWithdraw(uint16 totalSupply, uint16 boatId) public view returns(uint256) {
        uint16 maxState = (boatId / 100) * 100 + 100;
        uint256 withdrawMaxAmount= 0;
        for(uint16 i = boatId; i < totalSupply && i < maxState ; i++){
            withdrawMaxAmount += boatsMaxWithdraw[i];
        }
        return withdrawMaxAmount - boatsWithdrawAmount[boatId];
    }
```

---

## 11. GenericHandlerUpgradeable: executeProposal() -> view fetchExecuteRecord()
- file: `07ec822ed7a30c55467ccbbbac0838567f629bbf_GenericHandlerUpgradeable.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: _executeRecords

state:
```solidity
    bool isExecuted;
    bool _status;
    bytes _callback;
    address _srcAddress;
    address _destAddress;
    bytes data;
    address _feeToken;
    address _rSyncContract;
    address _linkedContract;
    address _feeToken;
    DepositRecord memory depositData;
```

exposure function:
```solidity
function executeProposal(bytes calldata _data) external onlyRole(BRIDGE_ROLE) returns (bool) {
        DepositRecord memory depositData = decodeData(_data);
        require(
            _executeRecords[depositData._srcChainID][depositData._nonce].isExecuted == false,
            "GenericHandler: Already executed"
        );
        if (!depositData._destAddress.isContract()) {
            _executeRecords[depositData._srcChainID][depositData._nonce]._callback = "";
            _executeRecords[depositData._srcChainID][depositData._nonce]._status = false;
            _executeRecords[depositData._srcChainID][depositData._nonce].isExecuted = true;
            return true;
        }
        (bool success, bytes memory callback) = depositData._destAddress.call(
            abi.encodeWithSelector(
                0x06d07c59, // routerSync(uint8,address,bytes)
                depositData._srcChainID,
                depositData._srcAddress,
                depositData.data
            )
        );
        _executeRecords[depositData._srcChainID][depositData._nonce]._callback = callback;
        _executeRecords[depositData._srcChainID][depositData._nonce]._status = success;
        _executeRecords[depositData._srcChainID][depositData._nonce].isExecuted = true;
        return true;
    }
```

flagged view:
```solidity
function fetchExecuteRecord(uint8 _ChainID, uint64 _nonce) external view returns (ExecuteRecord memory) {
        return _executeRecords[_ChainID][_nonce];
    }
```

---

## 12. ReferrioEscrow: pay() -> view getBalanceByOpportunity()
- file: `08d230517e1708F6771660ee8CC286F8882275b6_ReferrioEscrow.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: amount

state:
```solidity
    address public referrioMasterAddress;
    PayType public payType;
    SetMappingType public setMappingType;
    bool locked;
    bool hasDeposited;
```

exposure function:
```solidity
function pay(
        string memory _opportunityId,
        address payable _recipient,
        uint256 _amount,
        PayType _payType
    ) external onlyReferrio {
        require(
            balances[opportunityOwner[_opportunityId]][_opportunityId].amount >=
                _amount,
            "pay: Insufficient balance"
        );
        require(
            balances[opportunityOwner[_opportunityId]][_opportunityId].locked !=
                true,
            "pay: Opportunity is locked"
        );
        (bool success, ) = _recipient.call{value: _amount}("");
        require(
            success,
            "pay: unable to send value, recipient may have reverted"
        );
        balances[opportunityOwner[_opportunityId]][_opportunityId]
            .amount = balances[opportunityOwner[_opportunityId]][_opportunityId]
            .amount
            .sub(_amount);

        if (_payType == PayType.REFERRER) {
            emit PaidReferrer(_opportunityId, _recipient, _amount);
        } else {
            emit PaidReferee(_opportunityId, _recipient, _amount);
        }
    }
```

flagged view:
```solidity
function getBalanceByOpportunity(string memory _opportunityId)
        external
        view
        returns (uint256)
    {
        return balances[msg.sender][_opportunityId].amount;
    }
```

---

## 13. VRFCoordinatorV2Mock: fulfillRandomWords() -> view getSubscription()
- file: `0a2bccfeec28459E4bf1Ff1cFb2deAA74126e63F_OptimismValidator.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: s_subscriptions

state:
```solidity
    address owner;
    VRFConsumerBaseV2 v;
```

exposure function:
```solidity
function fulfillRandomWords(uint256 _requestId, address _consumer) external {
    uint256 startGas = gasleft();
    if (s_requests[_requestId].subId == 0) {
      revert("nonexistent request");
    }
    Request memory req = s_requests[_requestId];

    uint256[] memory words = new uint256[](req.numWords);
    for (uint256 i = 0; i < req.numWords; i++) {
      words[i] = uint256(keccak256(abi.encode(_requestId, i)));
    }

    VRFConsumerBaseV2 v;
    bytes memory callReq = abi.encodeWithSelector(v.rawFulfillRandomWords.selector, _requestId, words);
    (bool success, ) = _consumer.call{gas: req.callbackGasLimit}(callReq);

    uint96 payment = uint96(BASE_FEE + ((startGas - gasleft()) * GAS_PRICE_LINK));
    if (s_subscriptions[req.subId].balance < payment) {
      revert InsufficientBalance();
    }
    s_subscriptions[req.subId].balance -= payment;
    delete (s_requests[_requestId]);
    emit RandomWordsFulfilled(_requestId, _requestId, payment, success);
  }
```

flagged view:
```solidity
function getSubscription(uint64 _subId)
    external
    view
    override
    returns (
      uint96 balance,
      uint64 reqCount,
      address owner,
      address[] memory consumers
    )
  {
    if (s_subscriptions[_subId].owner == address(0)) {
      revert InvalidSubscription();
    }
    return (s_subscriptions[_subId].balance, 0, s_subscriptions[_subId].owner, new address[](0));
  }
```

---

## 14. GenericHandler: deposit() -> view getDepositRecord()
- file: `0b55E9fDCD068fD8018023e56f03A893A6AEb340_KpiOptionsFinancialProductLibrary.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: _depositRecords

state:
```solidity
    address public _bridgeAddress;
    address _depositer;
    bytes _metaData;
    bytes memory metadata;
    bytes memory metaData;
```

exposure function:
```solidity
function deposit(
        bytes32 resourceID,
        uint8 destinationChainID,
        uint64 depositNonce,
        address depositer,
        bytes calldata data
    ) external onlyBridge {
        bytes32 lenMetadata;
        bytes memory metadata;

        assembly {
            // Load length of metadata from data + 64
            lenMetadata := calldataload(0xC4)
            // Load free memory pointer
            metadata := mload(0x40)

            mstore(0x40, add(0x20, add(metadata, lenMetadata)))

            // func sig (4) + destinationChainId (padded to 32) + depositNonce (32) + depositor (32) +
            // bytes length (32) + resourceId (32) + length (32) = 0xC4

            calldatacopy(
                metadata, // copy to metadata
                0xC4, // copy from calldata after metadata length declaration @0xC4
                sub(calldatasize(), 0xC4) // copy size (calldatasize - (0xC4 + the space metaData takes up))
            )
        }

        address contractAddress = _resourceIDToContractAddress[resourceID];
        require(_contractWhitelist[contractAddress], "provided contractAddress is not whitelisted");

        bytes4 sig = _contractAddressToDepositFunctionSignature[contractAddress];
        if (sig != bytes4(0)) {
            bytes memory callData = abi.encodePacked(sig, metadata);
            (bool success, ) = contractAddress.call(callData);
            require(success, "delegatecall to contractAddress failed");
        }

        _depositRecords[destinationChainID][depositNonce] = DepositRecord(
            destinationChainID,
            depositer,
            resourceID,
            metadata
        );
    }
```

flagged view:
```solidity
function getDepositRecord(uint64 depositNonce, uint8 destId) external view returns (DepositRecord memory) {
        return _depositRecords[destId][depositNonce];
    }
```

---

## 15. AzuGoal: claimCash() -> view getCash()
- file: `0d3568f4033a5f711430f3c0886561d7c6b89ac0_AzuGoal.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: cashReady

state:
```solidity
    address operator;
    bool published;
    string _baseTokenURI;
    IAccessories aces;
    IVRFGenerator vrf;
    string memory _name;
```

exposure function:
```solidity
function claimCash(uint256 tokenId) external onlyEOA nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Only owner");
        require(publish[64].published, "Final winner not released");

        if (!cashReady[uint16(tokenId)]) revert("no fund or cashed out");

        uint256 _cash = 0;
        uint256 count = finalWinners.length;

        // Do the math
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

        // payable(msg.sender).transfer(_cash);
        (bool success, ) = msg.sender.call{value: _cash}("");
        require(success, "Claim transfer failed");

        cashReady[uint16(tokenId)] = false;
        emit cashedOut(msg.sender, tokenId, _cash);
    }
```

flagged view:
```solidity
function getCash(uint256 tokenId) external view returns (uint256 _cash) {
        require(publish[64].published, "Final winner not released");

        if (!cashReady[uint16(tokenId)]) return 0;

        uint256 count = finalWinners.length;

        // Do the math
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
    }
```

---

## 16. CSKNFT: updateFlagStatus() -> view checkFlagStatus()
- file: `0d7d3a744Da812C51B489e0b2E5b88fc38a84256_CSKNFT.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: tokenInfo

state:
```solidity
    string public baseTokenURI;
    address payable public adminWallet;
    address public signWallet;
    address public cskGen;
    address public timelockAddress;
    string metadata;
    bool status;
    bytes signature;
    bool isAvailable;
    string metadata;
    MintDates public mintDates;
```

exposure function:
```solidity
function updateFlagStatus(
        SignInfo calldata _info
    ) external payable nonReentrant {
        require(ownerOf(_info.tokenId) == msg.sender, "Not Owner.");
        require(
            tokenInfo[_info.tokenId].isAvailable != _info.status,
            "Same status."
        );
        require(block.timestamp < _info.expirationTime, "Times out");

        //verify
        address signer = _verify(_info);
        require(signer == signWallet, "not signed");
        require(
            _info.nonce == updateTokenNonces[msg.sender]++,
            "Invalid nonce"
        );

        if (_info.status) {
            require(msg.value == PORTAL_PRICE, "Invalid Amount");

            tokenInfo[_info.tokenId].metadata = _info.metadata;

            (bool sent, ) = adminWallet.call{value: msg.value}("");
            require(sent, "Failed send");
        }

        tokenInfo[_info.tokenId].isAvailable = _info.status;

        emit ChangeItemStatus(msg.sender, _info);
    }
```

flagged view:
```solidity
function checkFlagStatus(uint256 tokenId) public view returns (bool) {
        _requireMinted(tokenId);
        return tokenInfo[tokenId].isAvailable;
    }
```

---

## 17. MockOwnableAdapter: openSponsorWindow() -> view getMaturityBounds()
- file: `0Efc943dBC6F9467Cf1Df7Cb92162A8EF9De26f3_RewardsDistributor.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: open

exposure function:
```solidity
function openSponsorWindow() external override requiresTrust {
        open = 2;
        Opener(msg.sender).onSponsorWindowOpened(adapterParams.stake, adapterParams.stakeSize);
        open = 1;
    }
```

flagged view:
```solidity
function getMaturityBounds() external view override returns (uint256, uint256) {
        return open == 2 ? (0, type(uint64).max / 2) : (0, 0);
    }
```

---

## 18. OwnableWstETHAdapter: openSponsorWindow() -> view getMaturityBounds()
- file: `0Efc943dBC6F9467Cf1Df7Cb92162A8EF9De26f3_RewardsDistributor.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: open

exposure function:
```solidity
function openSponsorWindow() external requiresTrust {
        open = 2;
        Opener(msg.sender).onSponsorWindowOpened(adapterParams.stake, adapterParams.stakeSize);
        open = 1;
    }
```

flagged view:
```solidity
function getMaturityBounds() external view override returns (uint256, uint256) {
        return open == 2 ? (adapterParams.minm, adapterParams.maxm) : (0, 0);
    }
```

---

## 19. OwnableERC4626Adapter: openSponsorWindow() -> view getMaturityBounds()
- file: `0Efc943dBC6F9467Cf1Df7Cb92162A8EF9De26f3_RewardsDistributor.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: open

exposure function:
```solidity
function openSponsorWindow() external requiresTrust {
        open = 2;
        Opener(msg.sender).onSponsorWindowOpened(adapterParams.stake, adapterParams.stakeSize);
        open = 1;
    }
```

flagged view:
```solidity
function getMaturityBounds() external view override returns (uint256, uint256) {
        return open == 2 ? (adapterParams.minm, adapterParams.maxm) : (0, 0);
    }
```

---

## 20. OwnableERC4626CropAdapter: openSponsorWindow() -> view getMaturityBounds()
- file: `0Efc943dBC6F9467Cf1Df7Cb92162A8EF9De26f3_RewardsDistributor.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: open

exposure function:
```solidity
function openSponsorWindow() external requiresTrust {
        open = 2;
        Opener(msg.sender).onSponsorWindowOpened(adapterParams.stake, adapterParams.stakeSize);
        open = 1;
    }
```

flagged view:
```solidity
function getMaturityBounds() external view override returns (uint256, uint256) {
        return open == 2 ? (adapterParams.minm, adapterParams.maxm) : (0, 0);
    }
```

---

## 21. NFTStoreFront: mintToken() -> view royaltyInfo()
- file: `0e342814164EF60f5e3c32FaF3F819c595101cbB_NFTStoreFront.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: royaltyPercents

state:
```solidity
    address public marketplaceAddress;
    address public mintingFeeAddress;
    IERC20 public WETH;
    address public commissionAddress;
```

exposure function:
```solidity
function mintToken(string calldata _tokenUri, uint256 _amount, uint8 _royaltyPercent, address[] memory _payees, uint256[] memory _shares_) 
    public
    payable
    nonReentrant
    mintPriceCompliance()
    verifyroyaltyPercent(_royaltyPercent)
    returns(uint256)
  {
    require(!paused, 'The contract is paused!');

    uint256 newItemId = _tokenIds.current();
    _mint(msg.sender, newItemId, _amount, "");
    _setTokenUri(newItemId, _tokenUri);

    _tokenIds.increment();
    setApprovalForAll(marketplaceAddress, true);

    if (mintingFeeAddress != address(0) && mintingFee > 0 && address(this).balance >= mintingFee) {
      // =============================================================================
      (bool hs, ) = payable(mintingFeeAddress).call{value: mintingFee}('');
      require(hs);
      // =============================================================================
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

flagged view:
```solidity
function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view override
    returns (address receiver, uint256 royaltyAmount)
  {
    return (recipients[_tokenId], (_salePrice * royaltyPercents[_tokenId] * 100) / 10000);
  }
```

---

## 22. InterestStrategy: swapAndwithdrawFees() -> view availableAmount()
- file: `0ec271d3bdb1a723088d1dcef6b7ebf9c1b0d377_InterestStrategy.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: pendingFeeEarned

state:
```solidity
    bool public emergencyExitEnabled;
    address public feeTo;
    address public swapper;
    InterestLerp public interestLerp;
```

exposure function:
```solidity
function swapAndwithdrawFees(
        uint256 amountOutMin,
        IERC20 tokenOut,
        bytes calldata data
    ) external onlyExecutor returns (uint256) {
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

flagged view:
```solidity
function availableAmount() public view returns (uint256 amount) {
        uint256 balance = strategyToken.balanceOf(address(this));

        if (balance > pendingFeeEarned) {
            amount = balance - pendingFeeEarned;
        }
    }
```

---

## 23. GenericHandlerUpgradeable: executeProposal() -> view fetchExecuteRecord()
- file: `1046D4D30a357c61e674038d8344Dd70c0327896_GenericHandlerUpgradeable.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: _executeRecords

state:
```solidity
    bool isExecuted;
    bool _status;
    bytes _callback;
    address _srcAddress;
    address _destAddress;
    bytes data;
    address _feeToken;
    address _rSyncContract;
    address _linkedContract;
    address _feeToken;
    DepositRecord memory depositData;
```

exposure function:
```solidity
function executeProposal(bytes calldata _data) external onlyRole(BRIDGE_ROLE) returns (bool) {
        DepositRecord memory depositData = decodeData(_data);
        require(
            _executeRecords[depositData._srcChainID][depositData._nonce].isExecuted == false,
            "GenericHandler: Already executed"
        );
        if (!depositData._destAddress.isContract()) {
            _executeRecords[depositData._srcChainID][depositData._nonce]._callback = "";
            _executeRecords[depositData._srcChainID][depositData._nonce]._status = false;
            _executeRecords[depositData._srcChainID][depositData._nonce].isExecuted = true;
            return true;
        }
        (bool success, bytes memory callback) = depositData._destAddress.call(
            abi.encodeWithSelector(
                0x06d07c59, // routerSync(uint8,address,bytes)
                depositData._srcChainID,
                depositData._srcAddress,
                depositData.data
            )
        );
        _executeRecords[depositData._srcChainID][depositData._nonce]._callback = callback;
        _executeRecords[depositData._srcChainID][depositData._nonce]._status = success;
        _executeRecords[depositData._srcChainID][depositData._nonce].isExecuted = true;
        return true;
    }
```

flagged view:
```solidity
function fetchExecuteRecord(uint8 _ChainID, uint64 _nonce) external view returns (ExecuteRecord memory) {
        return _executeRecords[_ChainID][_nonce];
    }
```

---

## 24. Bridge: executeCall() -> view activeOutbox()
- file: `1066CEcC8880948FE55e427E94F1FF221d626591_Bridge.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: _activeOutbox

state:
```solidity
    bool allowed;
    address private _activeOutbox;
    IOwnable public rollup;
    address public sequencerInbox;
```

exposure function:
```solidity
function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bool success, bytes memory returnData) {
        if (!allowedOutboxesMap[msg.sender].allowed) revert NotOutbox(msg.sender);
        if (data.length > 0 && !to.isContract()) revert NotContract(to);
        address prevOutbox = _activeOutbox;
        _activeOutbox = msg.sender;
        // We set and reset active outbox around external call so activeOutbox remains valid during call

        // We use a low level call here since we want to bubble up whether it succeeded or failed to the caller
        // rather than reverting on failure as well as allow contract and non-contract calls
        // solhint-disable-next-line avoid-low-level-calls
        (success, returnData) = to.call{value: value}(data);
        _activeOutbox = prevOutbox;
        emit BridgeCallTriggered(msg.sender, to, value, data);
    }
```

flagged view:
```solidity
function activeOutbox() public view returns (address) {
        address outbox = _activeOutbox;
        // address zero is returned if no outbox is set, but the value used in storage
        // is non-zero to save users some gas (as storage refunds are usually maxed out)
        // EIP-1153 would help here.
        // we don't return `EMPTY_ACTIVEOUTBOX` to avoid a breaking change on the current api
        if (outbox == EMPTY_ACTIVEOUTBOX) return address(0);
        return outbox;
    }
```

---

## 25. TGT: emitTokens() -> view totalSupply()
- file: `108a850856db3f85d0269a2693d896b394c80325_TGT.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: _totalSupply

state:
```solidity
    address private _owner;
    address private _reserve;
    uint length;
```

exposure function:
```solidity
function emitTokens() public virtual {
        require(_live != 0, "TGT: contract not live yet. It should be live (live==true)");

        uint64 timeInM = uint64((block.timestamp - _live) / MONTH_IN_S);
        if (timeInM <= _lastEmitMAt) {
            return;
        }
        // timeInM at the start will be 1, so subtract 1 so that we start after one
        // month with the emission from 0, to emit the full amount.
        uint64 timeInY = (timeInM - 1) / 12;
        if (timeInY >= _curveHalvingYears.length) {
            _lastEmitMAt = MAX_INT;
            //now we mint all the tokens, also if we forgot a monthly emit
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
            IERC677Receiver(_reserve).onTokenTransfer(address(this), additionalAmountM, "");
        }
        emit Transfer(address(0), _reserve, additionalAmountM);
    }
```

flagged view:
```solidity
function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
```

---

## 26. WhoGonWinBet: earnEth() -> view getBetPoolList()
- file: `10FF05B58cBE464a55F51b9A069CEF8BCB1aAA99_WhoGonWinBet.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: addressClaimedMap

state:
```solidity
    BetPool[] betPools;
    IERC721A immutable whoGoWinNft;
    string key;
    uint startTimestamp;
    uint endTimestamp;
    string config;
    BaseBetPool base;
    uint royaltyFactor;
    bool claimable;
    uint valueForSender;
    uint valueForInvitor;
    uint betValue;
    uint totalBetValue;
    uint totalBetAddressCount;
    BaseBetPool base;
    bool claimable;
    bool claimed;
    uint claimableValue;
    FeBetOption[] options;
```

exposure function:
```solidity
function earnEth(string memory _betKey) external nonReentrant {
        require(betKeysMap[_betKey], 'InvalidArgs: betKey');

        address msgSender = _msgSender();
        BetPool storage betPool = betPools[betKeyIndexMap[_betKey]];
        require(!addressClaimedMap[_betKey][msgSender], 'Already claimed');

        EthToEarn memory ethToEarn = _calculateEthToEarn(msgSender, betPool);
        require(ethToEarn.valueForSender > 0, 'ethToEarn must greater than 0');

        (bool _os1,) = payable(msgSender).call{value : ethToEarn.valueForSender}('');
        require(_os1);

        if (ethToEarn.valueForInvitor > 0 && invitorAddressesMap[_betKey][msgSender].length > 0) {
            address invitor = invitorAddressesMap[_betKey][msgSender][0];
            (bool _os2,) = payable(invitor).call{value : ethToEarn.valueForInvitor}('');
            require(_os2);
        }
        addressClaimedMap[_betKey][msgSender] = true;
    }
```

flagged view:
```solidity
function getBetPoolList(address msgSender) public view returns (FeBetPool[] memory) {
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
            if (claimable) {
                claimableValue = _calculateEthToEarn(msgSender, betPool).valueForSender;
            }

            list[i] = FeBetPool(betPool.base, claimable, addressClaimedMap[_betKey][msgSender], claimableValue, invitorAddressesMap[_betKey][msgSender], options);
        }
        return list;
    }
```

---

## 27. OxOPool: deposit() -> view getCurrentRingIndex()
- file: `1123F4f9aa7adE165CE625Dc6EfEec85F7aFaA2A_LSAG.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: ringsNumber

state:
```solidity
    address public token;
    address public factory;
```

exposure function:
```solidity
function deposit(uint _amount, uint256[2] memory _publicKey) public {
        
        /// Confirm amount sent is allowed
        uint256 amountTokenRecieved = amountCheck(_amount);
        OxOFactory factoryContract = OxOFactory(factory);

        if(ERC20(factoryContract.token()).balanceOf(msg.sender) < factoryContract.getTokenFeeDiscountLimit()) {
            uint256 fee = getFeeForAmount(_amount);
            ERC20(token).transferFrom(msg.sender, address(this), _amount+fee);

            /// Transfer the fee to the treasurer
            ERC20(token).transfer(OxOFactory(factory).treasurerAddress(), fee);   
        }else{
            uint256 fee = getDiscountFeeForAmount(_amount);
            ERC20(token).transferFrom(msg.sender, address(this), _amount+fee);

            if(fee > 0) {
                /// Transfer the fee to the treasurer
                ERC20(token).transfer(OxOFactory(factory).treasurerAddress(), fee);  
            }
        }

        if (!AltBn128.onCurve(uint256(_publicKey[0]), uint256(_publicKey[1]))) {
            revert("PK_NOT_ON_CURVE");
        }

        /// Gets the current ring for the amounts
        uint256 ringIndex = ringsNumber[amountTokenRecieved];
        Ring storage ring = rings[amountTokenRecieved][ringIndex];

        (uint wParticipants,
        uint participants, uint blockNum) = getRingPackedData(ring.packedRingData);

        /// Making sure no duplicate public keys are added
        for (uint256 i = 0; i < participants;) {
            if (ring.publicKeys[i][0] == _publicKey[0] &&
                ring.publicKeys[i][1] == _publicKey[1]) {
                revert("PK_ALREADY_IN_RING");
            }

            unchecked {
                i++;
            }
        }

        if (participants == 0) {
            blockNum = block.number - 1;
        }

        ring.publicKeys[participants] = _publicKey;
        ring.amountDeposited += amountTokenRecieved;
        unchecked {
            participants++;
        }

        uint packedData = (wParticipants << _BITWIDTH_PARTICIPANTS) | participants;
        packedData = (packedData << _BITWIDTH_BLOCK_NUM) | blockNum;
        ring.packedRingData = packedData;

        /// If the ring is full, start a new ring
    ... [9 more lines]
```

flagged view:
```solidity
function getCurrentRingIndex(uint256 amountToken) public view
        returns (uint256)
    {
        amountCheck(amountToken);
        return ringsNumber[amountToken];
    }
```

---

## 28. Adventures: venture() -> view tokenURI()
- file: `11fd39c78eed78b7fa3b9b1185a847cf736a39c8_Adventures.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: _adventures

state:
```solidity
    string memory svg;
    string memory strOutcome;
```

exposure function:
```solidity
function venture(uint256 charId, uint256 lootId) public payable nonReentrant 
    {
        require(ERC721(CHAR_CONTRACT_ADDRESS).ownerOf(charId) == _msgSender(), "You should own the character");
        require(ERC721(LOOT_CONTRACT_ADDRESS).ownerOf(lootId) == _msgSender(), "You should own the bag");
     
        require(msg.value == ADVENTURE_FEE, "Invalid adventure fee");
        
        (bool sent, ) = payable(VAULT).call{value: ADVENTURE_FEE}("");
        require(sent, "Failed to send Ether");

        _adventures[charId] = Character({id: charId, bag: lootId});
        _safeMint(_msgSender(), charId);
    }
```

flagged view:
```solidity
function tokenURI(uint256 tokenId) override public view returns (string memory output) 
    {
        Character memory player = _adventures[tokenId];
        Character memory enemy = Character({id: player.id + 8000, bag: player.bag + 8000});
        
        string[18] memory parts;
        
        _introduction(player, enemy, parts);
        uint256 outcome = _battle(player, enemy, parts);
        _ending(player, enemy, parts, outcome);
       
        parts[17] = '</svg>';
        
        string memory svg;
        svg =string(abi.encodePacked(svg, parts[0],parts[1],parts[2],parts[3],parts[4],parts[5]));
        svg =string(abi.encodePacked(svg, parts[6],parts[7],parts[8],parts[9],parts[10],parts[11]));
        svg =string(abi.encodePacked(svg, parts[12],parts[13],parts[14],parts[15],parts[16],parts[17]));
        
        string memory strOutcome;
     
        if (outcome == 2) strOutcome = "Victory";
        else if (outcome == 1) strOutcome = "Defeat";
        else strOutcome = "Tie";
        
        string memory attributes = string(abi.encodePacked('{"display_type: "number", "trait_type": "Bag", "value": ', Utils.toString(player.bag), '},{"trait_type": "Location", "value": "',_getLocation(player),'"},{"trait_type":"Outcome","value":"',strOutcome,'"}]'));
        
        string memory description = 'Adventures are randomized adventures generated and stored on chain. Images, and other functionality are intentionally omitted for others to interpret. Feel free to use Adventures in any way you want.';
        string memory json = 
            Base64.encode(bytes(string(abi.encodePacked('{"name": "Adventure #', Utils.toString(tokenId), '", "description": "',description,'", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '", "attributes": [', attributes,']}'))));
        
    ... [2 more lines]
```

---

## 29. MistfitsNFTV2: whitelistMint() -> view freeLeft()
- file: `121493cc5fe3F62C9ab3D72D1a52b4Ef37747Eb6_MistfitsNFTV2.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: whitelistMinted

exposure function:
```solidity
function whitelistMint(
        uint256 _mintAmount,
        bytes32[] calldata _merkleProof
    )
        external
        payable
        whenNotPaused
        nonReentrant
        mintComplianceWhitelist(_mintAmount)
    {
        bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
        require(
            MerkleProofUpgradeable.verify(_merkleProof, merkleRoot, leaf),
            "Invalid proof!"
        );
        whitelistClaimed[_msgSender()] = true;
        _safeMint(_msgSender(), _mintAmount);
        if (walletAddress != address(0)) {
            (bool success, ) = walletAddress.call{value: address(this).balance}(
                ""
            );
            require(success, "failed");
        }
        whitelistMinted += _mintAmount;
    }
```

flagged view:
```solidity
function freeLeft() public view returns (uint256) {
        if (freeSupply + whitelistMinted > totalSupply()) {
            return freeSupply + whitelistMinted - totalSupply();
        }
        return 0;
    }
```

---

## 30. YoSifuStargateVault: harvest() -> view totalAssets()
- file: `12405761445aa80Bbb78C875a1D49Cc8c8E0b90E_YoSifuStargateVaultFactory.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: totalBaseAssets

state:
```solidity
    ILPStaking public immutable stargateStaking;
    IStargateRouter public immutable stargateRouter;
    ERC20 public immutable rewardToken;
    ERC20 public immutable underlyingAsset;
    address public feeTo;
```

exposure function:
```solidity
function harvest(
        address swapper,
        uint256 amountOutMin,
        bytes calldata data
    ) public {
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

        lastHarvestBlock = block.number;

        emit LogFeeClaimed(feeTo, totalFee);

        emit LogHarvested(baseAssetBalance);
    }
```

flagged view:
```solidity
function totalAssets() public view override returns (uint256) {
        return totalBaseAssets - lockedProfit();
    }
```

---

## 31. L1CrossDomainMessenger: relayMessage() -> view xDomainMessageSender()
- file: `12Acf6E3ca96A60fBa0BBFd14D2Fe0EB6ae47820_L1CrossDomainMessenger.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: xDomainMsgSender

exposure function:
```solidity
function relayMessage(
    address _target,
    address _sender,
    bytes memory _message,
    uint256 _messageNonce,
    L2MessageInclusionProof memory _proof
  ) public nonReentrant whenNotPaused {
    bytes memory xDomainCalldata = Lib_CrossDomainUtils.encodeXDomainCalldata(
      _target,
      _sender,
      _message,
      _messageNonce
    );

    require(
      _verifyXDomainMessage(xDomainCalldata, _proof) == true,
      'Provided message could not be verified.'
    );

    bytes32 xDomainCalldataHash = keccak256(xDomainCalldata);

    require(
      successfulMessages[xDomainCalldataHash] == false,
      'Provided message has already been received.'
    );

    require(
      blockedMessages[xDomainCalldataHash] == false,
      'Provided message has been blocked.'
    );

    require(
      _target != resolve('CanonicalTransactionChain'),
      'Cannot send L2->L1 messages to L1 system contracts.'
    );

    xDomainMsgSender = _sender;
    (bool success, ) = _target.call(_message);
    xDomainMsgSender = Lib_DefaultValues.DEFAULT_XDOMAIN_SENDER;

    // Mark the message as received if the call was successful. Ensures that a message can be
    // relayed multiple times in the case that the call reverted.
    if (success == true) {
      successfulMessages[xDomainCalldataHash] = true;
      emit RelayedMessage(xDomainCalldataHash);
    } else {
      failedMessages[xDomainCalldataHash] = true;
      emit FailedRelayedMessage(xDomainCalldataHash);
    }

    // Store an identifier that can be used to prove that the given message was relayed by some
    // user. Gives us an easy way to pay relayers for their work.
    bytes32 relayId = keccak256(
      abi.encodePacked(xDomainCalldata, msg.sender, block.number)
    );
    relayedMessages[relayId] = true;
  }
```

flagged view:
```solidity
function xDomainMessageSender() public view returns (address) {
    require(
      xDomainMsgSender != Lib_DefaultValues.DEFAULT_XDOMAIN_SENDER,
      'xDomainMessageSender is not set'
    );
    return xDomainMsgSender;
  }
```

---

## 32. RWtransfer: withdraw() -> view getTotalWithdrawn()
- file: `137e2A21B41F73E112321c0a13671F39569CF326_RWtransfer.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: totalWithdrawn

exposure function:
```solidity
function withdraw() public payable onlyOwner {
        uint256 val = address(this).balance;
        (bool success, ) = payable(msg.sender).call{
            value: val
        }("");
        require(success);
        totalWithdrawn += val;
        delete val;
    }
```

flagged view:
```solidity
function getTotalWithdrawn() public view returns (uint256) {
        return totalWithdrawn;
    }
```

---

## 33. LSSVMPairFactory: createPairERC20() -> view getSalt()
- file: `142abf0bdb409cb047c79229e3ad749371e82f87_LSSVMPairFactory.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: poolCount

state:
```solidity
    address payable public override protocolFeeRecipient;
    bool allowed;
    bool wasEverAllowed;
    address payable public immutable sisterFactory;
    ERC20 token;
    IERC721 nft;
    ICurve bondingCurve;
    address payable assetRecipient;
    address template;
```

exposure function:
```solidity
function createPairERC20(
        CreateERC20PairParams calldata params,
        address payable WETH,
        bool createSudo
    ) external payable returns (LSSVMPairERC20 pair) {
        require(
            bondingCurveAllowed[params.bondingCurve],
            "Bonding curve not whitelisted"
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
        );
        poolCount[msg.sender] += 1;
        emit NewPair(
            msg.sender,
            address(params.nft),
            params.poolType,
            tx.origin,
            address(pair)
        );
    }
```

flagged view:
```solidity
function getSalt() public view returns (bytes32){
        return keccak256(abi.encode(msg.sender, poolCount[msg.sender]));
    }
```

---

## 34. Bridge: executeCall() -> view activeOutbox()
- file: `14b09AB5D2E758E343c39308B45E967902006D86_RollupCreator.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: _activeOutbox

state:
```solidity
    bool allowed;
    address private _activeOutbox;
    IOwnable public override rollup;
    address public sequencerInbox;
```

exposure function:
```solidity
function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external override returns (bool success, bytes memory returnData) {
        if (!allowedOutboxesMap[msg.sender].allowed) revert NotOutbox(msg.sender);
        if (data.length > 0 && !to.isContract()) revert NotContract(to);
        address prevOutbox = _activeOutbox;
        _activeOutbox = msg.sender;
        // We set and reset active outbox around external call so activeOutbox remains valid during call

        // We use a low level call here since we want to bubble up whether it succeeded or failed to the caller
        // rather than reverting on failure as well as allow contract and non-contract calls
        // solhint-disable-next-line avoid-low-level-calls
        (success, returnData) = to.call{value: value}(data);
        _activeOutbox = prevOutbox;
        emit BridgeCallTriggered(msg.sender, to, value, data);
    }
```

flagged view:
```solidity
function activeOutbox() public view returns (address) {
        address outbox = _activeOutbox;
        // address zero is returned if no outbox is set, but the value used in storage
        // is non-zero to save users some gas (as storage refunds are usually maxed out)
        // EIP-1153 would help here.
        // we don't return `EMPTY_ACTIVEOUTBOX` to avoid a breaking change on the current api
        if (outbox == EMPTY_ACTIVEOUTBOX) return address(0);
        return outbox;
    }
```

---

## 35. TaxCollector: distribute() -> view getBalance()
- file: `15eb510a346e1db58427d8665ec7a6568a863165_BridgeToken.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: balance

state:
```solidity
    bool inSwap;
```

exposure function:
```solidity
function distribute() public onlyOwner swapping {
    require(teamPercentage + partnershipPercentage + rndPercentage == maxPercent, "The sum of percentage isn't 100.");
    require(
      teamWallet != address(0)
      && partnershipWallet != address(0)
      && rndWallet != address(0)
      ,
      "Cannot send to zero wallet."
    );
    uint256 amount = getBalance();
    (bool sent_1, ) = payable(teamWallet).call{value: (amount * teamPercentage / maxPercent), gas: 30000}(""); require(sent_1, "Transfer wallet_1 error."); balance = address(this).balance;
    (bool sent_2, ) = payable(partnershipWallet).call{value: (amount * partnershipPercentage / maxPercent), gas: 30000}(""); require(sent_2, "Transfer wallet_2 error."); balance = address(this).balance;
    (bool sent_3, ) = payable(rndWallet).call{value: (amount * rndPercentage / maxPercent), gas: 30000}(""); require(sent_3, "Transfer wallet_3 error."); balance = address(this).balance;
  }
```

flagged view:
```solidity
function getBalance() public view returns (uint) { return balance; }
```

---

## 36. EpikStaking: withdraw() -> view totalSupply()
- file: `175C503a11da3D22b05412081BC8123D8939f683_EpikStaking.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: _totalSupply

state:
```solidity
    address payable public withdrawVault;
    IERC20 public immutable stakingToken;
```

exposure function:
```solidity
function withdraw(uint256 amount)
        external
        payable
        nonReentrant
    {
        require(amount > 0, "Withdraw: Cannot withdraw 0");

        if (withdrawFee > 0) {
            require(withdrawFee == msg.value, "Withdraw Request: fee is not correct");

            if (withdrawVault != address(0)) {
                (bool sent,) = withdrawVault.call{value: msg.value}("");
                require(sent, "Withdraw Request: Failed to send Fee");
            }
        }

        WithdrawingRequest memory prevRequest = userWithdrawingRequest[msg.sender];

        // Check cooldown status and update withdrawRequesting status
        if ((prevRequest.requestedTime + cooldown) <= block.timestamp) {
            prevRequest.withdrawableAmount = prevRequest.withdrawableAmount + prevRequest.requestedAmount;
            prevRequest.requestedTime = 0;
            prevRequest.requestedAmount = 0;
        }

        uint256 senderBalance = _balances[msg.sender];

        require(senderBalance >= amount, "Withdraw: Can not withdraw the amount. Insufficient balance");
        require(prevRequest.withdrawableAmount >= amount, "Withdraw: Can not withdraw the amount. Insufficient withdrawable balance");

        userWithdrawingRequest[msg.sender].withdrawableAmount = uint104(prevRequest.withdrawableAmount - amount);
        userWithdrawingRequest[msg.sender].requestedTime = prevRequest.requestedTime;
        userWithdrawingRequest[msg.sender].requestedAmount = prevRequest.requestedAmount;

        _updateReward(msg.sender);
        _totalSupply = uint128(_totalSupply - amount);

        _balances[msg.sender] = senderBalance - amount;
        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }
```

flagged view:
```solidity
function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }
```

---

## 37. CryptoRadarPayments: joinCryptoRadar() -> view isActiveSubscriber()
- file: `17689337cb1752d1960560e6774d5f31fe990ceb_CryptoRadarPayments.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: userData

state:
```solidity
    address user;
    string discordHandle;
    address user;
```

exposure function:
```solidity
function joinCryptoRadar(address sponsor, uint256 months, string calldata discordHandle) payable external {
        require(!pause, "Contract is paused");
        require(bytes(discordHandle).length>5 && bytes(discordHandle)[bytes(discordHandle).length-5] == "#", "Error in discord Handle");
        require(months == 1 || months == 6 || months == 12, "Months must be 1, 6 or 12");
        if (sponsor != address(0)) {
            require(isActiveSubscriber(sponsor), "Sponsor must be a subscriber");
            require(sponsor != msg.sender, "You cant sponsor yourself");
            uint256 amount = 0;

            if (months == 1) {
                amount = calculatePrice(true, 1);
                require(msg.value == amount);
            } else if (months == 6) {
                amount = calculatePrice(true, 6);
                require(msg.value == amount);
            } else if (months == 12) {
                amount = calculatePrice(true, 12);
                require(msg.value == amount);
            }
            uint256 amountForSponsor = amount * sponsorPercentage / 10000;
            (bool sent,) = sponsor.call{value: amountForSponsor}("");
            require(sent, "Failed to send Ether");

        } else {
            if (months == 1) {
                require(msg.value == calculatePrice(false, 1));
            } else if (months == 6) {
                require(msg.value == calculatePrice(false, 6));
            } else if (months == 12) {
                require(msg.value == calculatePrice(false, 12));
            }
        }

        userPayments[msg.sender].push( Payments(msg.sender, block.timestamp, msg.value) );
        discordToAddress[discordHandle] = msg.sender;
        totalSubscribersCount++;
        if (isActiveSubscriber(msg.sender)) {
            userData[msg.sender] = Users(msg.sender, discordHandle, block.timestamp, userData[msg.sender].endDate + 31 days * months, months);
        } else {
            userData[msg.sender] = Users(msg.sender, discordHandle, block.timestamp, block.timestamp + 31 days * months, months);
        }
    }
```

flagged view:
```solidity
function isActiveSubscriber(address _user) public view returns (bool) {
        return userData[_user].endDate >= block.timestamp;
    }
```

---

## 38. Dittos: transform() -> view tokenURI()
- file: `18d9125F53316b32131651EbCDCD18af4984F485_Dittos.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: _transformations

exposure function:
```solidity
function transform(
        uint256 dittoId,
        address usingContractNFT,
        uint256 usingTokenId
    ) public payable {
        require(
            _exists(dittoId),
            "ERC721Metadata: dittoId for nonexistent token"
        );

        require(
            ownerOf(dittoId) == msg.sender,
            "You are not the owner of this Ditto"
        );

        require(
            msg.value >= costTransform,
            "Transfer amount too low to use Transform"
        );

        if (
            ERC165Checker.supportsInterface(usingContractNFT, ERC721InterfaceId)
        ) {
            (bool success, bytes memory bytesUri) = usingContractNFT.call(
                abi.encodeWithSignature("tokenURI(uint256)", usingTokenId)
            );

            require(success, "Error getting tokenURI data");
            string memory uri = abi.decode(bytesUri, (string));

            _transformations[dittoId] = uri;
        } else if (
            ERC165Checker.supportsInterface(
                usingContractNFT,
                ERC1155MetadataInterfaceId
            )
        ) {
            (bool success, bytes memory bytesUri) = usingContractNFT.call(
                abi.encodeWithSignature("uri(uint256)", usingTokenId)
            );

            require(success, "Error getting URI data");
            string memory uri = abi.decode(bytesUri, (string));

            _transformations[dittoId] = uri;
        } else if (
            usingContractNFT == 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB
        ) {
            string memory uri = tokenURIforPunk(uint16(usingTokenId));
            _transformations[dittoId] = uri;
        } else {
            revert("Provided address is not compatible with ERC721 or ERC1155");
        }
    }
```

flagged view:
```solidity
function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721A)
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (bytes(_transformations[tokenId]).length != 0) {
            return _transformations[tokenId];
        }

        return tokenURIforDitto(tokenId);
    }
```

---

## 39. TSSNFT: preMint() -> view checkEarlyBird()
- file: `197FC873B3E498b7cA8faC410f466515ceeC600B_TSSNFT.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: preSaleAllowance

state:
```solidity
    address payableAddress;
    uint public price;
    uint index;
```

exposure function:
```solidity
function preMint(uint _quantity) external payable  {
        require(hasPreSaleStarted, "Presale hasn't started.");
        require(!preSaleOver, "Presale is over, no more allowances.");
        require(_quantity > 0, "Quantity cannot be zero.");
        require(_quantity <= MAX_PRESALE, "Quantity cannot be bigger than MAX_PREMINTING.");
        require(preSaleAllowance[msg.sender].sub(_quantity) >= 0, "The user is not allowed to do further presale buyings.");
        require(preSaleAllowance[msg.sender] >= _quantity, "This address is not allowed to buy that quantity.");
        require(totalSupply().add(_quantity) <= MAX_SNEAKERHEADZ, "Sold out");
        require(msg.value >= price.mul(_quantity) || msg.sender == owner(), "Ether value sent is below the price.");
        
        (bool success, ) = payableAddress.call{value:msg.value}("");
        require(success, "Transfer failed.");
        
        preSaleAllowance[msg.sender] = preSaleAllowance[msg.sender].sub(_quantity);
        
        for (uint i = 0; i < _quantity; i++) {
            uint mintIndex = totalSupply();
            _safeMint(msg.sender, mintIndex);
            emit SneakerHeadzMinted(mintIndex, msg.sender);
        }
    }
```

flagged view:
```solidity
function checkEarlyBird(address earlyBirdAddress) public view returns (uint) {
        return preSaleAllowance[earlyBirdAddress];
    }
```

---

## 40. Engine: buy() -> view getAuctionId()
- file: `1b1c055c46d6ce21c2daca3c5faa0cdb83137b29_Address.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: offers

state:
```solidity
    Auction[] public auctions;
```

exposure function:
```solidity
function buy(uint256 _tokenId) external payable nonReentrant {
        address buyer = msg.sender;
        uint256 paidPrice = msg.value;

        Offer memory offer = offers[_tokenId];
        require(offer.isOnSale == true, "NFT not in direct sale");
        uint256 price = offer.price;
        require(paidPrice >= price, "Price is not enough");

        //if there is a bid and the auction is closed but not claimed, give priority to claim
        require(
            !(offer.isAuction == true &&
                isFinished(offer.idAuction) &&
                auctions[offer.idAuction].bidCount > 0),
            "Claim asset from auction has priority"
        );

        emit Claim(_tokenId, buyer);
        SeahorseNFT asset = SeahorseNFT(offer.assetAddress);
        asset.safeTransferFrom(offer.creator, buyer, _tokenId);

        // now, pay the amount - commission - royalties to the auction creator
        address payable creatorNFT = payable(asset.getCreator(_tokenId));

        uint256 commissionToPay = (paidPrice.mul(commission)) / 10000;
        uint256 royaltiesToPay = 0;
        if (creatorNFT != offer.creator) {
            // It is a resale. Transfer royalties
            royaltiesToPay =
                (paidPrice.mul(asset.getRoyalties(_tokenId))) /
                10000;

            (bool success, ) = creatorNFT.call{value: royaltiesToPay}("");
            require(success, "Transfer failed.");

            emit Royalties(creatorNFT, royaltiesToPay);
        }
        uint256 amountToPay = paidPrice.sub(commissionToPay).sub(
            royaltiesToPay
        );

        (bool success2, ) = offer.creator.call{value: amountToPay}("");
        require(success2, "Transfer failed.");
        emit PaymentToOwner(
            offer.creator,
            amountToPay,
            //     paidPrice,
            commissionToPay,
            royaltiesToPay,
            amountToPay + ((paidPrice * commission) / 10000) // using safemath will trigger an error because of stack size
        );

        // is there is an auction open, we have to give back the last bid amount to the last bidder
        if (offer.isAuction == true) {
            Auction memory auction = auctions[offer.idAuction];
            // #4. Only if there is at least a bid and the bid amount > 0, give it back to last bidder
            if (auction.currentBidAmount != 0 && auction.bidCount > 0) {
                // return funds to the previuos bidder
                (bool success3, ) = auction.currentBidOwner.call{
                    value: auction.currentBidAmount
    ... [20 more lines]
```

flagged view:
```solidity
function getAuctionId(uint256 _tokenId) public view returns (uint256) {
        Offer memory offer = offers[_tokenId];
        return offer.idAuction;
    }
```

---

## 41. ERC721J: mintCopy() -> view totalSupply()
- file: `1b9F04589183341Ad9b8Cd771983CEBeB0c1BC23_ApeTapesContractWizard.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: _tokenIds

state:
```solidity
    string private _name;
    string private _symbol;
    string private _baseURI;
    string private _contractURI;
    bool private _enableRecycle;
    address currOwnershipAddr;
    string memory _tokenURI;
    string memory _songURI;
    address payable owner;
```

exposure function:
```solidity
function mintCopy(uint256 tokenId) public payable override {
        // Requires the sender to have the tokenId in their wallet
        if (!_isApprovedOrOwner(_msgSender(), tokenId))
            if (_publicMint[tokenId] == false) revert SenderNotOwner();
        // Gets the songId from the tokenId
        uint256 songId = _tokenIdInfo[tokenId].song;
        uint256 songSerial = _songSerials[songId];
        uint256 songGeneration = _tokenIdInfo[tokenId].generation;
        // Requires the song to not be sold out
        if (songSerial >= _maxEditions[songId]) revert MaxCopiesReached();
        // Checks rarity multiplier percent
        uint256 multPc = 100;
        if (_rarityMultipliers[songGeneration] > 0)
            multPc = _rarityMultipliers[songGeneration];
        // Requires eth
        if (msg.value < (_mintPrice * multPc) / 100) revert NotEnoughEther();
        // Transfer eth
        if (address(_songSplits[songId]) != address(0)) {
            (bool success, ) = _songSplits[songId].call{value: msg.value}("");
            require(success, "Failed to send Ether");
        }

        // Updates the count of total tokenids
        uint256 id = _tokenIds;
        ++id;
        _tokenIds = id;

        // Updates the count of how many of a particular song have been made
        ++songSerial;
        _songSerials[songId] = songSerial;
        // Makes it easy to look up the song or gen of a tokenid
        _tokenIdInfo[id].song = uint128(songId);
        _tokenIdInfo[id].generation = uint128(songGeneration + 1);

        emit Copy(tokenId);

        _safeMintCopy(ownerOf(tokenId), msg.sender, id);
    }
```

flagged view:
```solidity
function totalSupply() public view virtual override returns (uint256) {
        return _tokenIds;
    }
```

---

## 42. Originals99: placeBid() -> view getSmallestAllowedBid()
- file: `1c49ed56da6be87b804bc1b8b817a259aa3132ed_Originals99.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: currentPrice|winningBidder

exposure function:
```solidity
function placeBid() external payable onlyActiveAuction nonReentrant {
        require(tx.origin == msg.sender, "Caller cannot be contract");
        require(msg.value >= getSmallestAllowedBid(), "Too small bid");
        require(!isAuctionEnd(), "Auction ended");

        if (block.timestamp + DURATION_EXTENSION_ALLOWED_BEFORE_END >= auctionEndTime) {
            auctionEndTime = block.timestamp + DURATION_EXTENSION;
        }

        if (winningBidder != address(0)) {
            (bool success, ) = winningBidder.call{value: currentPrice}("");
            require(success, "Returning escrowed funds failed");
        }

        currentPrice = msg.value;
        winningBidder = _msgSender();

        emit AuctionBidPlaced(auctionedTokenId, _msgSender(), msg.value, auctionEndTime);
    }
```

flagged view:
```solidity
function getSmallestAllowedBid() public view onlyActiveAuction returns (uint256) {
        if (winningBidder == address(0)) {
            return PRICE_INITIAL;
        }

        return currentPrice + ((currentPrice * MIN_BID_INCREASE_BPS) / MAX_BPS);
    }
```

---

## 43. AuctionCrowdfund: finalize() -> view getCrowdfundLifecycle()
- file: `1ca2002babed23b91537e2f9c8bb61b97798c806_CrowdfundFactory.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: _bidStatus

state:
```solidity
    string name;
    string symbol;
    IMarketWrapper market;
    IERC721 nftContract;
    address payable splitRecipient;
    address initialContributor;
    address initialDelegate;
    IGateKeeper gateKeeper;
    bool onlyHostCanBid;
    FixedGovernanceOpts governanceOpts;
    IERC721 public nftContract;
    IMarketWrapper public market;
    bool public onlyHostCanBid;
    AuctionCrowdfundStatus private _bidStatus;
```

exposure function:
```solidity
function finalize(FixedGovernanceOpts memory governanceOpts)
        external
        onlyDelegateCall
        returns (Party party_)
    {
        // Check that the auction is still active and has not passed the `expiry` time.
        CrowdfundLifecycle lc = getCrowdfundLifecycle();
        if (lc != CrowdfundLifecycle.Active && lc != CrowdfundLifecycle.Expired) {
            revert WrongLifecycleError(lc);
        }
        // Mark as busy to prevent burn(), bid(), and contribute()
        // getting called because this will result in a `CrowdfundLifecycle.Busy`.
        _bidStatus = AuctionCrowdfundStatus.Busy;
        uint96 lastBid_ = lastBid;
        {
            uint256 auctionId_ = auctionId;
            IMarketWrapper market_ = market;
            // If we've bid before or the CF is not expired,
            // finalize the auction.
            if (lastBid_ != 0 || lc == CrowdfundLifecycle.Active) {
                if (!market_.isFinalized(auctionId_)) {
                    // Note that even if this crowdfund has expired but the auction is still
                    // ongoing, this call can fail and block finalization until the auction ends.
                    (bool s, bytes memory r) = address(market_).call(abi.encodeCall(
                        IMarketWrapper.finalize,
                        auctionId_
                    ));
                    if (!s) {
                        r.rawRevert();
                    }
                }
            }
        }
        IERC721 nftContract_ = nftContract;
        uint256 nftTokenId_ = nftTokenId;
        // Are we now in possession of the NFT?
        if (nftContract_.safeOwnerOf(nftTokenId_) == address(this) && lastBid_ != 0) {
            // If we placed a bid before then consider it won for that price.
            // Create a governance party around the NFT.
            party_ = _createParty(
                governanceOpts,
                false,
                nftContract_,
                nftTokenId_
            );
            emit Won(lastBid_, party_);
        } else {
            // Otherwise we lost the auction or the NFT was gifted to us.
            // Clear `lastBid` so `_getFinalPrice()` is 0 and people can redeem their
            // full contributions when they burn their participation NFTs.
            lastBid = 0;
            emit Lost();
        }
        _bidStatus = AuctionCrowdfundStatus.Finalized;
    }
```

flagged view:
```solidity
function getCrowdfundLifecycle() public override view returns (CrowdfundLifecycle) {
        // Do not rely on `market.isFinalized()` in case `auctionId` gets reused.
        AuctionCrowdfundStatus status = _bidStatus;
        if (status == AuctionCrowdfundStatus.Busy) {
            // In the midst of finalizing/bidding (trying to reenter).
            return CrowdfundLifecycle.Busy;
        }
        if (status == AuctionCrowdfundStatus.Finalized) {
            return address(party) != address(0)
                // If we're fully finalized and we have a party instance then we won.
                ? CrowdfundLifecycle.Won
                // Otherwise we lost.
                : CrowdfundLifecycle.Lost;
        }
        if (block.timestamp >= expiry) {
            // Expired. `finalize()` needs to be called.
            return CrowdfundLifecycle.Expired;
        }
        return CrowdfundLifecycle.Active;
    }
```

---

## 44. AsterFi: withdraw() -> view adminFullBalance()
- file: `1D21aa7E9471511Ab08a563EA77a2F7De36e2715_AsterFi.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: AdminBalance

state:
```solidity
    address public newOwner;
    address public owner;
    string public BaseURI;
    string public NotRevealedURI;
    bool private pubSaleActive;
    bool public REVEAL;
    ContractStatus public contractStatus;
    bool revealed;
    address tokenBackup;
```

exposure function:
```solidity
function withdraw() external onlyOwner {
        require(AdminBalance != 0, "adminBalanceIs0");
        (bool sent, bytes memory data) = owner.call{value: AdminBalance}("");
        require(sent, "TX_FAILED");
        AdminBalance = 0;
    }
```

flagged view:
```solidity
function adminFullBalance()
        public
        view
        returns (
            uint256 ETH,
            uint256 token1,
            uint256 token2,
            uint256 token3,
            uint256 token4,
            uint256 token5,
            uint256 token6,
            uint256 token7,
            uint256 token8,
            uint256 token9,
            uint256 token10
        )
    {
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
    ... [1 more lines]
```

---

## 45. Autonym: claim() -> view getNouns()
- file: `1d544450687f2f77b4243f0744ccf57fddfcd1c6_Autonym.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: tokenNouns

_function `claim` not located in `Autonym`_

---

## 46. TaxCollector: distribute() -> view getBalance()
- file: `1f36fb2d91d9951cf58ae4c1956c0b77e224f1e9_VCG.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: balance

state:
```solidity
    bool inSwap;
```

exposure function:
```solidity
function distribute() public onlyOwner swapping {
    require(teamPercentage + partnershipPercentage + rndPercentage == maxPercent, "The sum of percentage isn't 100.");
    require(
      teamWallet != address(0)
      && partnershipWallet != address(0)
      && rndWallet != address(0)
      ,
      "Cannot send to zero wallet."
    );
    uint256 amount = getBalance();
    (bool sent_1, ) = payable(teamWallet).call{value: (amount * teamPercentage / maxPercent), gas: 30000}(""); require(sent_1, "Transfer wallet_1 error."); balance = address(this).balance;
    (bool sent_2, ) = payable(partnershipWallet).call{value: (amount * partnershipPercentage / maxPercent), gas: 30000}(""); require(sent_2, "Transfer wallet_2 error."); balance = address(this).balance;
    (bool sent_3, ) = payable(rndWallet).call{value: (amount * rndPercentage / maxPercent), gas: 30000}(""); require(sent_3, "Transfer wallet_3 error."); balance = address(this).balance;
  }
```

flagged view:
```solidity
function getBalance() public view returns (uint) { return balance; }
```

---

## 47. FSNMarketplace: withdrawMarketplaceIncome() -> view getMarketplaceFunds()
- file: `1ffc08aD120AF4F1829fd6286c410E6E1c561a4e_FSNMarketplace.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: s_marketplace_funds

state:
```solidity
    address private s_signer;
    address private s_payment_token_address;
    ISignerVerification public signer_verification;
    address buyer;
    address artist;
    string tokenURI;
    address buyer;
    address artist;
    string tokenURI;
    string id;
```

exposure function:
```solidity
function withdrawMarketplaceIncome() external onlyOwner {
        uint256 marketplaceWETHBalance = IERC20(s_payment_token_address).balanceOf(address(this));
        uint256 marketplaceETHBalance = address(this).balance;
        uint256 marketplaceFunds = s_marketplace_funds;
        if(marketplaceWETHBalance >= marketplaceFunds){
            bool succeed = IERC20(s_payment_token_address).transfer(msg.sender, marketplaceFunds);
            require(succeed, "WETH withdraw failed");
        }else{
            uint256 reminder = marketplaceFunds - marketplaceWETHBalance;
            bool succeed = IERC20(s_payment_token_address).transfer(msg.sender, marketplaceWETHBalance);
            require(succeed, "WETH withdraw failed");
            (bool sent, ) = msg.sender.call{value: reminder}('');
            require(sent, 'ETH withdraw failed');
        }
        s_marketplace_funds = 0;
         emit Withdrawed(marketplaceFunds, block.timestamp);
	}
```

flagged view:
```solidity
function getMarketplaceFunds() external view returns(uint256) {
        return s_marketplace_funds;
    }
```

---

## 48. Millionaireasia1155Contract: mint() -> view creator()
- file: `20785824B3ef2780127d8909eC8E9e72Ee9EDeb0_Millionaireasia1155Contract.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: creators

state:
```solidity
    address seller;
    address seller;
    string public name;
    string public symbol;
```

exposure function:
```solidity
function mint(address to, uint256 id, uint256 amount, string memory uri, address royaltyRecipient, uint96 royaltyValue) external payable {
        address owner = owner();
        if(owner != msg.sender) {
            require(msg.value > 0, "Must pay minting service fee");
            uint256 ethBalance = msg.sender.balance;
            require(ethBalance > msg.value, "Insufficient balance");
            (bool success, ) = owner.call{ value: msg.value }("");
            require(success, "Transaction failed");           
        }
        _mint(to, id, amount, '');
        creators[id] = to;
        if (royaltyValue > 0) {
            _setTokenRoyalty(id, royaltyRecipient, royaltyValue);
        }
        if (bytes(uri).length > 0) {
            _setTokenURI(id, uri);
        }
    }
```

flagged view:
```solidity
function creator(uint256 tokenId) public view returns (address) {
        require(exists(tokenId), 'ERC1155: token does not exist');
        return creators[tokenId];
    }
```

---

## 49. VoltichangeP2pETH: acceptP2Porder() -> view getP2PordersCount()
- file: `208b5780C7FaCa531366d20a36BAf4b9306ddFF8_VoltichangeP2pETH.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: p2pOrders

state:
```solidity
    address public WETH;
    address public wallet;
    address _from;
    address _to;
    address _tokenIn;
    address _tokenOut;
```

exposure function:
```solidity
function acceptP2Porder(uint256 _orderIndex, bool _orderAccepted) external {
        p2pOrder memory order = p2pOrders[_orderIndex];
        require(order._to == msg.sender, "not sender");
        if (_orderAccepted && order._expires >= block.timestamp) {
            IERC20Upgradeable(order._tokenOut).safeTransferFrom(
                msg.sender,
                order._from,
                order._amountOut
            );

            uint256 _feeAmount = (order._amountIn * fee) / 10000;
            uint256 _amountInSub = order._amountIn - _feeAmount;
            if (order._tokenIn == WETH) {
                IWETH(WETH).withdraw(order._amountIn);
                (bool sent, ) = msg.sender.call{value: _amountInSub}("");
                require(sent, "Failed to send Ether");
            } else {
                IERC20Upgradeable(order._tokenIn).safeTransfer(
                    msg.sender,
                    _amountInSub
                );
            }
            burn(order._tokenIn, order._tokenOut, _feeAmount);
        } else {
            IERC20Upgradeable(order._tokenIn).safeTransfer(
                order._from,
                order._amountIn
            );
        }
        p2pOrders[_orderIndex] = p2pOrders[p2pOrders.length - 1];
        p2pOrders.pop();
        emit p2pOrderDeleted(_orderIndex);
    }
```

flagged view:
```solidity
function getP2PordersCount() public view returns (uint256) {
        return p2pOrders.length;
    }
```

---

## 50. AuctionCrowdfund: finalize() -> view getCrowdfundLifecycle()
- file: `2140731a4fdc2531f5138635e457d468c8f4210b_AuctionCrowdfund.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: _bidStatus

state:
```solidity
    string name;
    string symbol;
    IMarketWrapper market;
    IERC721 nftContract;
    address payable splitRecipient;
    address initialContributor;
    address initialDelegate;
    IGateKeeper gateKeeper;
    bool onlyHostCanBid;
    FixedGovernanceOpts governanceOpts;
    IERC721 public nftContract;
    IMarketWrapper public market;
    bool public onlyHostCanBid;
    AuctionCrowdfundStatus private _bidStatus;
```

exposure function:
```solidity
function finalize(
        FixedGovernanceOpts memory governanceOpts
    ) external onlyDelegateCall returns (Party party_) {
        // Check that the auction is still active and has not passed the `expiry` time.
        CrowdfundLifecycle lc = getCrowdfundLifecycle();
        if (lc != CrowdfundLifecycle.Active && lc != CrowdfundLifecycle.Expired) {
            revert WrongLifecycleError(lc);
        }
        // Mark as busy to prevent burn(), bid(), and contribute()
        // getting called because this will result in a `CrowdfundLifecycle.Busy`.
        _bidStatus = AuctionCrowdfundStatus.Busy;
        uint96 lastBid_ = lastBid;
        {
            uint256 auctionId_ = auctionId;
            IMarketWrapper market_ = market;
            // If we've bid before or the CF is not expired,
            // finalize the auction.
            if (lastBid_ != 0 || lc == CrowdfundLifecycle.Active) {
                if (!market_.isFinalized(auctionId_)) {
                    // Note that even if this crowdfund has expired but the auction is still
                    // ongoing, this call can fail and block finalization until the auction ends.
                    (bool s, bytes memory r) = address(market_).call(
                        abi.encodeCall(IMarketWrapper.finalize, auctionId_)
                    );
                    if (!s) {
                        r.rawRevert();
                    }
                }
            }
        }
        IERC721 nftContract_ = nftContract;
        uint256 nftTokenId_ = nftTokenId;
        // Are we now in possession of the NFT?
        if (nftContract_.safeOwnerOf(nftTokenId_) == address(this) && lastBid_ != 0) {
            // If we placed a bid before then consider it won for that price.
            // Create a governance party around the NFT.
            party_ = _createParty(governanceOpts, false, nftContract_, nftTokenId_);
            emit Won(lastBid_, party_);
        } else {
            // Otherwise we lost the auction or the NFT was gifted to us.
            // Clear `lastBid` so `_getFinalPrice()` is 0 and people can redeem their
            // full contributions when they burn their participation NFTs.
            lastBid = 0;
            emit Lost();
        }
        _bidStatus = AuctionCrowdfundStatus.Finalized;
    }
```

flagged view:
```solidity
function getCrowdfundLifecycle() public view override returns (CrowdfundLifecycle) {
        // Do not rely on `market.isFinalized()` in case `auctionId` gets reused.
        AuctionCrowdfundStatus status = _bidStatus;
        if (status == AuctionCrowdfundStatus.Busy) {
            // In the midst of finalizing/bidding (trying to reenter).
            return CrowdfundLifecycle.Busy;
        }
        if (status == AuctionCrowdfundStatus.Finalized) {
            return
                address(party) != address(0) // If we're fully finalized and we have a party instance then we won.
                    ? CrowdfundLifecycle.Won // Otherwise we lost.
                    : CrowdfundLifecycle.Lost;
        }
        if (block.timestamp >= expiry) {
            // Expired. `finalize()` needs to be called.
            return CrowdfundLifecycle.Expired;
        }
        return CrowdfundLifecycle.Active;
    }
```

---


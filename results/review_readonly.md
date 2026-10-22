# readonly candidates for manual scope review
source: results/scan_scs_mainnet.csv | 40 distinct

## 1. TestContractOffererNativeToken.previewOrder
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
                amount: _required.amount,
                recipient: payable(address(this))
            });
        }
    }
```

view reading desynced state:
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

view reading desynced state:
```solidity
function getInventory()
        external
        view
        returns (SpentItem[] memory offerable, SpentItem[] memory receivable)
    {
        // Set offerable and receivable supplied at deployment if unfulfilled.
        if (!ready || fulfilled) {
            offerable = new SpentItem[](0);

            receivable = new SpentItem[](0);
        } else {
            offerable = new SpentItem[](1 + extraAvailable);
            for (uint256 i = 0; i < 1 + extraAvailable; ++i) {
                offerable[i] = _available;
            }

            receivable = new SpentItem[](1 + extraRequired);
            for (uint256 i = 0; i < 1 + extraRequired; ++i) {
                receivable[i] = _required;
            }
        }
    }
```

---

## 2. PPAgentV2.getKeeper
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

view reading desynced state:
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

## 3. Baal.state
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
        /* Proposal is ready to be processed*/
        else {
            return ProposalState.Ready;
        }
    }
```

view reading desynced state:
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

view reading desynced state:
```solidity
function getProposalStatus(uint32 id)
        external
        view
        returns (bool[4] memory)
    {
        return proposals[id].status;
    }
```

---

## 4. Vault.getClaimedRewardsTotal
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
function getClaimedRewardsTotal() external view returns (uint256) {
        return totalDistributed;
    }
```

view reading desynced state:
```solidity
function getClaimedRewardsTotal() external view returns (uint256) {
        return totalDistributed;
    }
```

---

## 5. ERC721Matcha.canSell
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
function canSell(uint256 tokenId) external view returns (bool) {
        return (ownerOf(tokenId)==msg.sender && !auctions[tokenId].open);
    }
```

view reading desynced state:
```solidity
function canSell(uint256 tokenId) external view returns (bool) {
        return (ownerOf(tokenId)==msg.sender && !auctions[tokenId].open);
    }
```

view reading desynced state:
```solidity
function getPrice(uint256 tokenId) external view returns (uint256, uint256, uint256) {
        if (sellBidPrice[tokenId]>0) return (sellBidPrice[tokenId], 0, 0);
        if (auctions[tokenId].highestBid>0) return (0, auctions[tokenId].highestBid, 0);
        return (0, 0, soldFor[tokenId]);
    }
```

---

## 6. AsterFi.adminFullBalance
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
    }
```

view reading desynced state:
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

## 7. OneMintRegistry.isMappingApproved
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
function isMappingApproved(address address721, address address1155)
    public
    view
    returns (bool)
  {
    return _addonApprovals[address721][address1155];
  }
```

view reading desynced state:
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

## 8. HelixNFTBridge.isBridged
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
function isBridged(string calldata _externalTokenID) external view returns (bool) {
        return _wrappedNftIDs[_externalTokenID];
    }
```

view reading desynced state:
```solidity
function isBridged(string calldata _externalTokenID) external view returns (bool) {
        return _wrappedNftIDs[_externalTokenID];
    }
```

---

## 9. L1CrossDomainMessenger.xDomainMessageSender
- file: `06C1F0e18B33500c17eeeD1317d7456f8AA2dFBC_ABDropManagerV2.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: xDomainMsgSender

exposure function:
```solidity
function xDomainMessageSender() public view returns (address) {
        require(
            xDomainMsgSender != Lib_DefaultValues.DEFAULT_XDOMAIN_SENDER,
            "xDomainMessageSender is not set"
        );
        return xDomainMsgSender;
    }
```

view reading desynced state:
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

## 10. KWWVaultEth.boatAvailableToWithdraw
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
function boatAvailableToWithdraw(uint16 totalSupply, uint16 boatId) public view returns(uint256) {
        uint16 maxState = (boatId / 100) * 100 + 100;
        uint256 withdrawMaxAmount= 0;
        for(uint16 i = boatId; i < totalSupply && i < maxState ; i++){
            withdrawMaxAmount += boatsMaxWithdraw[i];
        }
        return withdrawMaxAmount - boatsWithdrawAmount[boatId];
    }
```

view reading desynced state:
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

## 11. GenericHandlerUpgradeable.fetchExecuteRecord
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
function fetchExecuteRecord(uint8 _ChainID, uint64 _nonce) external view returns (ExecuteRecord memory) {
        return _executeRecords[_ChainID][_nonce];
    }
```

view reading desynced state:
```solidity
function fetchExecuteRecord(uint8 _ChainID, uint64 _nonce) external view returns (ExecuteRecord memory) {
        return _executeRecords[_ChainID][_nonce];
    }
```

---

## 12. ReferrioEscrow.getBalanceByOpportunity
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
function getBalanceByOpportunity(string memory _opportunityId)
        external
        view
        returns (uint256)
    {
        return balances[msg.sender][_opportunityId].amount;
    }
```

view reading desynced state:
```solidity
function getBalanceByOpportunity(string memory _opportunityId)
        external
        view
        returns (uint256)
    {
        return balances[msg.sender][_opportunityId].amount;
    }
```

view reading desynced state:
```solidity
function getAnyBalanceByOpportunity(string memory _opportunityId)
        external
        view
        onlyReferrio
        returns (uint256)
    {
        return
            balances[opportunityOwner[_opportunityId]][_opportunityId].amount;
    }
```

---

## 13. VRFCoordinatorV2Mock.getSubscription
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

view reading desynced state:
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

## 14. GenericHandler.getDepositRecord
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
function getDepositRecord(uint64 depositNonce, uint8 destId) external view returns (DepositRecord memory) {
        return _depositRecords[destId][depositNonce];
    }
```

view reading desynced state:
```solidity
function getDepositRecord(uint64 depositNonce, uint8 destId) external view returns (DepositRecord memory) {
        return _depositRecords[destId][depositNonce];
    }
```

---

## 15. AzuGoal.getCash
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

view reading desynced state:
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

## 16. CSKNFT.checkFlagStatus
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
function checkFlagStatus(uint256 tokenId) public view returns (bool) {
        _requireMinted(tokenId);
        return tokenInfo[tokenId].isAvailable;
    }
```

view reading desynced state:
```solidity
function checkFlagStatus(uint256 tokenId) public view returns (bool) {
        _requireMinted(tokenId);
        return tokenInfo[tokenId].isAvailable;
    }
```

view reading desynced state:
```solidity
function checkMetadata(
        uint256 tokenId
    ) public view returns (string memory) {
        _requireMinted(tokenId);
        return tokenInfo[tokenId].metadata;
    }
```

---

## 17. MockOwnableAdapter.getMaturityBounds
- file: `0Efc943dBC6F9467Cf1Df7Cb92162A8EF9De26f3_RewardsDistributor.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: open

exposure function:
```solidity
function getMaturityBounds() external view override returns (uint256, uint256) {
        return open == 2 ? (0, type(uint64).max / 2) : (0, 0);
    }
```

view reading desynced state:
```solidity
function getMaturityBounds() external view override returns (uint256, uint256) {
        return open == 2 ? (0, type(uint64).max / 2) : (0, 0);
    }
```

---

## 18. OwnableWstETHAdapter.getMaturityBounds
- file: `0Efc943dBC6F9467Cf1Df7Cb92162A8EF9De26f3_RewardsDistributor.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: open

exposure function:
```solidity
function getMaturityBounds() external view override returns (uint256, uint256) {
        return open == 2 ? (adapterParams.minm, adapterParams.maxm) : (0, 0);
    }
```

view reading desynced state:
```solidity
function getMaturityBounds() external view override returns (uint256, uint256) {
        return open == 2 ? (adapterParams.minm, adapterParams.maxm) : (0, 0);
    }
```

---

## 19. OwnableERC4626Adapter.getMaturityBounds
- file: `0Efc943dBC6F9467Cf1Df7Cb92162A8EF9De26f3_RewardsDistributor.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: open

exposure function:
```solidity
function getMaturityBounds() external view override returns (uint256, uint256) {
        return open == 2 ? (adapterParams.minm, adapterParams.maxm) : (0, 0);
    }
```

view reading desynced state:
```solidity
function getMaturityBounds() external view override returns (uint256, uint256) {
        return open == 2 ? (adapterParams.minm, adapterParams.maxm) : (0, 0);
    }
```

---

## 20. OwnableERC4626CropAdapter.getMaturityBounds
- file: `0Efc943dBC6F9467Cf1Df7Cb92162A8EF9De26f3_RewardsDistributor.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: open

exposure function:
```solidity
function getMaturityBounds() external view override returns (uint256, uint256) {
        return open == 2 ? (adapterParams.minm, adapterParams.maxm) : (0, 0);
    }
```

view reading desynced state:
```solidity
function getMaturityBounds() external view override returns (uint256, uint256) {
        return open == 2 ? (adapterParams.minm, adapterParams.maxm) : (0, 0);
    }
```

---

## 21. NFTStoreFront.royaltyInfo
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
function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view override
    returns (address receiver, uint256 royaltyAmount)
  {
    return (recipients[_tokenId], (_salePrice * royaltyPercents[_tokenId] * 100) / 10000);
  }
```

view reading desynced state:
```solidity
function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view override
    returns (address receiver, uint256 royaltyAmount)
  {
    return (recipients[_tokenId], (_salePrice * royaltyPercents[_tokenId] * 100) / 10000);
  }
```

---

## 22. InterestStrategy.availableAmount
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
function availableAmount() public view returns (uint256 amount) {
        uint256 balance = strategyToken.balanceOf(address(this));

        if (balance > pendingFeeEarned) {
            amount = balance - pendingFeeEarned;
        }
    }
```

view reading desynced state:
```solidity
function availableAmount() public view returns (uint256 amount) {
        uint256 balance = strategyToken.balanceOf(address(this));

        if (balance > pendingFeeEarned) {
            amount = balance - pendingFeeEarned;
        }
    }
```

---

## 23. GenericHandlerUpgradeable.fetchExecuteRecord
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
function fetchExecuteRecord(uint8 _ChainID, uint64 _nonce) external view returns (ExecuteRecord memory) {
        return _executeRecords[_ChainID][_nonce];
    }
```

view reading desynced state:
```solidity
function fetchExecuteRecord(uint8 _ChainID, uint64 _nonce) external view returns (ExecuteRecord memory) {
        return _executeRecords[_ChainID][_nonce];
    }
```

---

## 24. Bridge.activeOutbox
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

view reading desynced state:
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

## 25. TGT.totalSupply
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
function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
```

view reading desynced state:
```solidity
function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
```

---

## 26. WhoGonWinBet.getBetPoolList
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

view reading desynced state:
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

## 27. OxOPool.getCurrentRingIndex
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
function getCurrentRingIndex(uint256 amountToken) public view
        returns (uint256)
    {
        amountCheck(amountToken);
        return ringsNumber[amountToken];
    }
```

view reading desynced state:
```solidity
function getCurrentRingIndex(uint256 amountToken) public view
        returns (uint256)
    {
        amountCheck(amountToken);
        return ringsNumber[amountToken];
    }
```

---

## 28. Adventures.tokenURI
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
        
        output = string(abi.encodePacked('data:application/json;base64,', json));
    }
```

view reading desynced state:
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

## 29. MistfitsNFTV2.freeLeft
- file: `121493cc5fe3F62C9ab3D72D1a52b4Ef37747Eb6_MistfitsNFTV2.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: whitelistMinted

exposure function:
```solidity
function freeLeft() public view returns (uint256) {
        if (freeSupply + whitelistMinted > totalSupply()) {
            return freeSupply + whitelistMinted - totalSupply();
        }
        return 0;
    }
```

view reading desynced state:
```solidity
function freeLeft() public view returns (uint256) {
        if (freeSupply + whitelistMinted > totalSupply()) {
            return freeSupply + whitelistMinted - totalSupply();
        }
        return 0;
    }
```

---

## 30. YoSifuStargateVault.totalAssets
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
function totalAssets() public view override returns (uint256) {
        return totalBaseAssets - lockedProfit();
    }
```

view reading desynced state:
```solidity
function totalAssets() public view override returns (uint256) {
        return totalBaseAssets - lockedProfit();
    }
```

---

## 31. L1CrossDomainMessenger.xDomainMessageSender
- file: `12Acf6E3ca96A60fBa0BBFd14D2Fe0EB6ae47820_L1CrossDomainMessenger.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: xDomainMsgSender

exposure function:
```solidity
function xDomainMessageSender() public view returns (address) {
    require(
      xDomainMsgSender != Lib_DefaultValues.DEFAULT_XDOMAIN_SENDER,
      'xDomainMessageSender is not set'
    );
    return xDomainMsgSender;
  }
```

view reading desynced state:
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

## 32. RWtransfer.getTotalWithdrawn
- file: `137e2A21B41F73E112321c0a13671F39569CF326_RWtransfer.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: totalWithdrawn

exposure function:
```solidity
function getTotalWithdrawn() public view returns (uint256) {
        return totalWithdrawn;
    }
```

view reading desynced state:
```solidity
function getTotalWithdrawn() public view returns (uint256) {
        return totalWithdrawn;
    }
```

---

## 33. LSSVMPairFactory.getSalt
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
function getSalt() public view returns (bytes32){
        return keccak256(abi.encode(msg.sender, poolCount[msg.sender]));
    }
```

view reading desynced state:
```solidity
function getSalt() public view returns (bytes32){
        return keccak256(abi.encode(msg.sender, poolCount[msg.sender]));
    }
```

---

## 34. Bridge.activeOutbox
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

view reading desynced state:
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

## 35. TaxCollector.getBalance
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
function getBalance() public view returns (uint) { return balance; }
```

view reading desynced state:
```solidity
function getBalance() public view returns (uint) { return balance; }
```

---

## 36. EpikStaking.totalSupply
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
function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }
```

view reading desynced state:
```solidity
function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }
```

view reading desynced state:
```solidity
function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18 / _totalSupply;
    }
```

---

## 37. CryptoRadarPayments.isActiveSubscriber
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
function isActiveSubscriber(address _user) public view returns (bool) {
        return userData[_user].endDate >= block.timestamp;
    }
```

view reading desynced state:
```solidity
function isActiveSubscriber(address _user) public view returns (bool) {
        return userData[_user].endDate >= block.timestamp;
    }
```

view reading desynced state:
```solidity
function isDiscordActiveSubscriber(string calldata _account) public view returns (bool) {
        return userData[discordToAddress[_account]].endDate >= block.timestamp;
    }
```

---

## 38. Dittos.tokenURI
- file: `18d9125F53316b32131651EbCDCD18af4984F485_Dittos.sol`
- pragma: 0.8 | shape: view_reads_desynced
- writes_before: 
- writes_after: _transformations

exposure function:
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

view reading desynced state:
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

## 39. TSSNFT.checkEarlyBird
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
function checkEarlyBird(address earlyBirdAddress) public view returns (uint) {
        return preSaleAllowance[earlyBirdAddress];
    }
```

view reading desynced state:
```solidity
function checkEarlyBird(address earlyBirdAddress) public view returns (uint) {
        return preSaleAllowance[earlyBirdAddress];
    }
```

---

## 40. Engine.getAuctionId
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
function getAuctionId(uint256 _tokenId) public view returns (uint256) {
        Offer memory offer = offers[_tokenId];
        return offer.idAuction;
    }
```

view reading desynced state:
```solidity
function getAuctionId(uint256 _tokenId) public view returns (uint256) {
        Offer memory offer = offers[_tokenId];
        return offer.idAuction;
    }
```

---


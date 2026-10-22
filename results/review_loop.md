# loop candidates for manual scope review
source: results/scan_scs_mainnet.csv | 90 distinct

## 1. Multicall.multicall
- file: `00000000008d4f01d63beee04b849eff60de7517_Multicall.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: gasUsed|returnData

state:
```solidity
    address target;
    bytes callData;
    bool success;
    bytes returnData;
```

loop function:
```solidity
function multicall(Call[] memory calls) public payable returns (uint256 blockNumber, Result[] memory returnData) {
        unchecked {
            blockNumber = block.number;
            returnData = new Result[](calls.length);
            for (uint256 i = 0; i < calls.length; i++) {
                (address target, uint256 gasLimit, bytes memory callData) = (
                    calls[i].target,
                    calls[i].gasLimit,
                    calls[i].callData
                );
                uint256 gasLeftBefore = gasleft();
                (bool success, bytes memory ret) = target.call{gas: gasLimit}(callData);
                uint256 gasUsed = gasLeftBefore - gasleft();
                returnData[i] = Result(success, gasUsed, ret);
            }
        }
    }
```

---

## 2. PledgeMint._refundPhase
- file: `036d5E237EfBdb1583c29B8648f637812A94cdF2_PledgeMint.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: pledges
- writes_after: 

state:
```solidity
    address admin;
    IERC721Pledge mintContract;
    bool mintContractLocked;
    bool pledgesLocked;
    PhaseConfig[] public phases;
```

loop function:
```solidity
function _refundPhase(uint16 phaseId) internal {
        PhaseConfig memory _phase = phases[phaseId];
        address[] storage _addresses = pledgers[phaseId];
        for (uint8 i; i < _addresses.length; ) {
            address addy = _addresses[i];
            uint8 quantity = pledges[phaseId][addy];
            if (quantity > 0) {
                pledges[phaseId][addy] = 0;
                (bool success, ) = addy.call{
                    value: _phase.mintPrice * quantity
                }("");
                if (!success) revert Errors.UnableToSendValue();
            }

            unchecked {
                ++i;
            }
        }
    }
```

---

## 3. Lock.spottingInBatch
- file: `0A73e46485fe6634F616a9baB930522712Cf4e1a_Lock.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: multipleToken

state:
```solidity
    address payable owner;
    address public feeReceiver;
    address depositer;
    address vault;
    address token;
    bool check;
    string tokenName;
    string symbol;
    Transactions[] public transactions;
```

loop function:
```solidity
function spottingInBatch(Transactions[] calldata txArray ) external {
        require(isSpotter[_msgSender()], "Not a valid Spotter");
        for (uint256 i = 0; i < txArray.length; i++) {
            Transactions memory x = txArray[i];
            if(x.token == address(1)){
                (bool success,) = payable(x.vault).call{value: multipleToken[x.depositer][x.token]}("");
                require(success == true,"ETH fail");
            }else{
                 IERC20(x.token).transfer( x.vault ,   multipleToken[x.depositer][x.token] );
            }
            multipleToken[x.depositer][x.token] = 0;
            emit spotted(
                x.depositer,
                x.token,
                x.check,
                multipleToken[x.depositer][x.token],
                x.vault,
                x.tokenName,
                x.symbol
            );
        }
    }
```

---

## 4. LiquidStakingManager.mintDerivatives
- file: `0C5569aE88bad82F25B5F7681637E52C6226F281_OwnableSmartWallet.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: stakedKnotsOfSmartWallet

state:
```solidity
    address public brand;
    address public override stakehouse;
    address public syndicate;
    address public dao;
    OptionalHouseGatekeeper public gatekeeper;
    ISyndicateFactory public syndicateFactory;
    IOwnableSmartWalletFactory public smartWalletFactory;
    string public stakehouseTicker;
    StakingFundsVault public stakingFundsVault;
    SavETHVault public savETHVault;
    LSDNFactory public factory;
    bool public enableWhitelisting;
```

loop function:
```solidity
function mintDerivatives(
        bytes[] calldata _blsPublicKeyOfKnots,
        IDataStructures.ETH2DataReport[] calldata _beaconChainBalanceReports,
        IDataStructures.EIP712Signature[] calldata _reportSignatures
    ) external nonReentrant {
        uint256 numOfKnotsToProcess = _blsPublicKeyOfKnots.length;
        if (numOfKnotsToProcess == 0) revert EmptyArray();
        if (numOfKnotsToProcess != _beaconChainBalanceReports.length) revert InconsistentArrayLength();
        if (numOfKnotsToProcess != _reportSignatures.length) revert InconsistentArrayLength();

        for (uint256 i; i < numOfKnotsToProcess; ++i) {
            // check if BLS public key is registered and not banned
            if (isBLSPublicKeyBanned(_blsPublicKeyOfKnots[i])) revert BLSPubKeyBanned();

            // check that the BLS pub key has deposited lifecycle
            if(
                getAccountManager().blsPublicKeyToLifecycleStatus(_blsPublicKeyOfKnots[i]) != IDataStructures.LifecycleStatus.DEPOSIT_COMPLETED
            ) revert DepositNotCompleted();

            // Expand the staking funds vault shares that can claim rewards
            stakingFundsVault.updateDerivativesMinted(_blsPublicKeyOfKnots[i]);

            // Poke the giant pools in the event they need to know about the minting of derivatives they funded
            factory.giantSavETHPool().onMintDerivatives(_blsPublicKeyOfKnots[i]);
            factory.giantFeesAndMev().onMintDerivatives(_blsPublicKeyOfKnots[i]);

            // The first knot will create the Stakehouse
            if(numberOfKnots == 0) {
                _createLSDNStakehouse(
                    _blsPublicKeyOfKnots[i],
                    _beaconChainBalanceReports[i],
                    _reportSignatures[i]
                );
            }
            else {
                // join stakehouse
                _joinLSDNStakehouse(
                    _blsPublicKeyOfKnots[i],
                    _beaconChainBalanceReports[i],
                    _reportSignatures[i]
                );
            }

            address smartWallet = smartWalletOfKnot[_blsPublicKeyOfKnots[i]];
            stakedKnotsOfSmartWallet[smartWallet] -= 1;

            if(stakedKnotsOfSmartWallet[smartWallet] == 0) {
                _authorizeRepresentative(smartWallet, smartWalletDormantRepresentative[smartWallet], true);

                // delete the dormant representative as it is set active
                delete smartWalletDormantRepresentative[smartWallet];
            }
        }
    }
```

---

## 5. Kollab_Share.payoutAll
- file: `13a022fd7ee1f43d13071878fe2e62c876c10f45_Factory.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: last_withdrawl|total_released
- writes_after: 

state:
```solidity
    address factory;
    address creator;
    string name;
    string description;
    bool automatic;
```

loop function:
```solidity
function payoutAll() external {

        require(msg.sender == factory, 'Error: 1012');
        require(address(this).balance > 0, 'Error: 1009');

        for(uint i = 0; i < payees.length; i++) {

            address payee = payees[i];

            if(shareholders[payee] < 0) { continue; }

            uint bal = getUserBalance(payee);
            if(bal > 0) {
                // Track Data
                total_released[payee] += bal;
                last_withdrawl[payee] = block.timestamp;

                // Pay
                (bool success, bytes memory data) = payable(payee).call{value: bal}("");
                require(success, "Failed to send ether");
            }
        }
    }
```

---

## 6. SuperfineRewardDistributionV1.distributeRewards
- file: `148E4eE12bc0bEFE2854F108FBa15771Dcc5747a_SuperfineRewardDistributionV1.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: _totalNativeReward
- writes_after: 

state:
```solidity
    RewardType rewardType;
    string campaignId;
    address creator;
    bool distributionStarted;
```

loop function:
```solidity
function distributeRewards(
        string calldata requestId,
        string calldata campaignId,
        Reward[] calldata rewards,
        address[] calldata winners,
        bytes calldata signature
    ) external nonReentrant {
        require(
            !_usedRequestIds[requestId],
            "SuperfineRewardDistributionV1: the request ID has been used before"
        );
        _usedRequestIds[requestId] = true;

        // Basic validations
        SuperfineCampaign storage campaign = _campaignById[campaignId];
        require(
            campaign.creator != address(0),
            "SuperfineRewardDistributionV1: this campaign does not exist"
        );
        require(
            rewards.length == winners.length,
            "SuperfineRewardDistributionV1: the number of rewards and the number of winners must be equal"
        );
        require(
            rewards.length <= campaign.numRewards,
            "SuperfineRewardDistributionV1: too many rewards are distributed"
        );

        // Verify the signature
        require(
            _operators[
                _verifyDistributionSignature(
                    requestId,
                    campaignId,
                    campaign.creator,
                    rewards,
                    winners,
                    signature
                )
            ],
            "SuperfineRewardDistributionV1: the signature is invalid"
        );

        // Update campaign info
        campaign.numRewards -= rewards.length;
        if (!campaign.distributionStarted) campaign.distributionStarted = true;

        // Distribute the rewards
        for (uint256 i = 0; i < rewards.length; i++) {
            Reward memory reward = rewards[i];
            address winner = winners[i];
            _distributedRewards[winner][campaignId].push(reward);
            if (reward.rewardType == RewardType.NATIVE) {
                require(
                    reward.rewardAddress == address(0),
                    "SuperfineRewardDistributionV1: the reward address is invalid"
                );
                require(
                    reward.tokenId == 0,
                    "SuperfineRewardDistributionV1: the token ID is invalid"
    ... [58 more lines]
```

---

## 7. Multicall2.aggregate
- file: `1B19916FeA44dbFb2bA76F5875191F842CF0B201_Multicall2.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: returnData

state:
```solidity
    address target;
    bytes callData;
    bool success;
    bytes returnData;
```

loop function:
```solidity
function aggregate(Call[] memory calls) external returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for(uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
            require(success, "Multicall aggregate: call failed");
            returnData[i] = ret;
        }
    }
```

---

## 8. Squid.payoutAll
- file: `1B6b3faBb47a2048ad97455bC8f298097a5f5278_Factory.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: last_withdrawl|total_released
- writes_after: 

state:
```solidity
    address factory;
    address creator;
    string name;
    string description;
    bool locked;
    uint fee;
```

loop function:
```solidity
function payoutAll() external {

        require(msg.sender == factory, 'Error: 1012');
        require(address(this).balance == 0, 'Error: 1009');
        require(!locked, "Error: 1015");

        for(uint i = 0; i < payees.length; i++) {

            address payee = payees[i];

            if(shareholders[payee] < 0) { continue; }

            uint bal = getUserBalance(payee);
            if(bal > 0) {
                // Track Data
                total_released[payee] += bal;
                last_withdrawl[payee] = block.timestamp;

                // Pay
                (bool success, bytes memory data) = payable(payee).call{value: bal}("");
                require(success, "Failed to send");
            }
        }
    }
```

---

## 9. MergeCanvas.changePixelsColor
- file: `1E34aDc5C66287513CF74E5e53cC4e22a0D0f87D_MergeCanvas.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: old_color|old_owner|old_price|pixel_color|pixel_owner|pixel_price_paid
- writes_after: 

state:
```solidity
    address immutable OWNER_ADDRESS;
    address old_owner;
    address new_owner;
    RGB old_color;
    RGB new_color;
```

loop function:
```solidity
function changePixelsColor(
        uint16[] memory _x,
        uint16[] memory _y,
        RGB[] calldata _new_color,
        uint256[] memory _prices
    )
        external
        payable
        BeforeMerge
        NotAtMaxPixelCapacity
    {
        require(batchAllowed, "Batch change color paused!");
        require(_x.length == _y.length);
        require(_x.length == _new_color.length);
        require(_x.length == _prices.length);

        // first iteration to check info
        // NOTE: https://github.com/crytic/slither/wiki/Detector-Documentation/#msgvalue-inside-a-loop
        uint256 remainder = msg.value;
        for (uint i = 0; i < _x.length; i++) {
            uint256 pixel_price = _calculatePixelPrice(_x[i], _y[i]);
            require(remainder >= pixel_price, "Insufficient balance for batch change");
            if (pixel_price > 0 && _prices[i] <= pixel_price) {
                revert MergeCanvas_InsufficientBid(_prices[i], pixel_price);
            }
            remainder -= pixel_price;
        }

        // intermediary check to make sure all requirements are met
        // require(msg.value >= min_cost, "Batch paid less than minimum cost!");

        // second iteration to actually change pixel colors
        for (uint i = 0; i < _x.length; i++) {
            // Get the hash of the (x,y) coordinates
            bytes32 coordinates_hash = _calculateCoordinatesHash(_x[i], _y[i]);

            pixel_price_paid[coordinates_hash] = _prices[i];

            // Update the owner of the pixel
            address old_owner = pixel_owner[coordinates_hash];
            pixel_owner[coordinates_hash] = msg.sender;

            // Update the color (R,G,B) of the pixel
            RGB memory old_color = pixel_color[coordinates_hash];
            pixel_color[coordinates_hash] = _new_color[i];

            // Update pixel paid, and refund previous owner
            uint256 old_price = pixel_price_paid[coordinates_hash];
            pixel_price_paid[coordinates_hash] = _prices[i];
            if (old_price > 0) {
                (bool sent, ) = old_owner.call{value: old_price}("");
                if (!sent) {
                    revert MergeCanvas_FailedBidRefund();
                }
            }

            // Update the address mapping
            uint256 pixel_encoded = (uint32(_x[i]) << 16) + _y[i];
            pixel_lookup[old_owner].remove(pixel_encoded);
            pixel_lookup[msg.sender].add(pixel_encoded);
    ... [26 more lines]
```

---

## 10. Unleashedplatinum.royaltyPayout
- file: `1f72dfe15e97f6644800043d9ba1066e34b095fb_Unleashedplatinum.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: totalEthRoyaltyPayout

state:
```solidity
    string private _currentBaseURI;
    uint private _reservedMints;
    bool private paused;
    string public unrevealedURI;
    uint public amountOfTokensGotPayout;
    address public pledgeContract;
```

loop function:
```solidity
function royaltyPayout(uint number, uint256 payout) public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > number * payout, "Insufficient Funds to pay out Royalties!");
        require(amountOfTokensGotPayout + number <= totalSupply());
        for (uint i; i < number; i++) {
            (bool success, ) = payable(ownerOf(amountOfTokensGotPayout + i)).call{value: payout}("");
            require(success, "Address: unable to send value, recipient may have reverted");
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

---

## 11. DeadfellazNanoX.withdrawAll
- file: `20ecda43fdd84290c50dec35fe03b35f9bf2c6dc_DeadfellazNanoX.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: percentage
- writes_after: 

state:
```solidity
    address account;
    Phase private _phase;
    WithdrawalAddress[] public withdrawalAddresses;
    string private baseTokenURI;
    string private baseContractURI;
```

loop function:
```solidity
function withdrawAll() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert Errors.NothingToWithdraw();

        uint256 length = withdrawalAddresses.length;
        for (uint256 i; i < length; ) {
            uint256 percentage = withdrawalAddresses[i].percentage;
            address withdrawalAddress = withdrawalAddresses[i].account;
            uint256 value = (balance * percentage) / 100;

            (withdrawalAddress.call{value: value}(""));

            unchecked {
                ++i;
            }
        }

        balance = address(this).balance;
        if (balance > 0) {
            (withdrawalAddresses[0].account.call{value: balance}(""));
        }
    }
```

---

## 12. RelayAdapt.multicall
- file: `22af4edbea3de885dda8f0a0653e6209e44e5b84_RelayAdapt.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: returnData

state:
```solidity
    address to;
    bytes data;
    bool success;
    string returnData;
    RailgunLogic public railgun;
    IWBase public wbase;
```

loop function:
```solidity
function multicall(
    bool _requireSuccess,
    Call[] calldata _calls
  ) internal {
    // Initialize returnData array
    Result[] memory returnData = new Result[](_calls.length);

    // Loop through each call
    for(uint256 i = 0; i < _calls.length; i++) {
      // Retrieve call
      Call calldata call = _calls[i];

      // Execute call
      // solhint-disable-next-line avoid-low-level-calls
      (bool success, bytes memory ret) = call.to.call{value: call.value, gas: gasleft()}(call.data);

      // Add call result to returnData
      returnData[i] = Result(success, string(ret));

      if (success) {
        continue;
      }

      bool isInternalCall = call.to == address(this);
      bool requireSuccess = _requireSuccess || isInternalCall;

      // If requireSuccess is true, throw on failure
      if (requireSuccess) {
        emit CallResult(returnData);
        revert(string.concat("GeneralAdapt Call Failed:", string(ret)));
      }
    }

    emit CallResult(returnData);
  }
```

---

## 13. RandomNumber.fulfillRandomWords
- file: `29231aA62bb0FBBeA7C766aB86389Edf9880618c_DiceGame.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: totalInBetsPerToken
- writes_after: 

state:
```solidity
    VRFCoordinatorV2Interface public coordinator;
    LinkTokenInterface private linkToken;
    address payable user;
    IERC20Upgradeable token;
    bool success;
    bool isRefund;
```

loop function:
```solidity
function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        // It will be used to facilitate event filtering later.
        responseBlockByRequestId[requestId] = block.number;

        for (uint256 i = 0; i < randomWords.length; i++) {
            // Valid numbers must be from 1 to 10000 or 0.01 to 100.00
            uint16 winningNumber = uint16(randomWords[i] % MAX_NUMBER) + 1;
            UserGuess memory userGuess = guessByRequestId[requestId][i];
            uint256 totalInBets = totalInBetsPerToken[address(userGuess.token)];
            totalInBetsPerToken[address(userGuess.token)] -= userGuess
                .betAmount;

            (address influencer, bool isEnabled) = getUserReferredBy(
                userGuess.user
            );
            if (!isEnabled) influencer = address(0);

            // If the user guessed incorrectly then stop
            if (
                userGuess.lowerNumber > winningNumber ||
                userGuess.upperNumber < winningNumber
            ) {
                updateTotalUserLosses(
                    userGuess.betAmount,
                    address(userGuess.token),
                    influencer
                );

                emit BetResult(
                    requestId,
                    i,
                    userGuess.user,
                    influencer,
                    winningNumber,
                    userGuess,
                    false,
                    true,
                    false
                );
                continue;
            }

            bool success;
            bool isRefund;
            if (userGuess.token == IERC20Upgradeable(address(0))) {
                uint256 available = address(this).balance -
                    (totalInBets - userGuess.betAmount);
                if (available >= userGuess.prizeAmount) {
                    // Pay the prize amount (native token)
                    (success, ) = userGuess.user.call{
                        value: userGuess.prizeAmount
                    }("");
                    emit BetResult(
                        requestId,
                        i,
                        userGuess.user,
                        influencer,
    ... [89 more lines]
```

---

## 14. Multicall2.aggregate
- file: `2d719fb70f10e3f6dfa2dca6c0f7a81e0bc3583e_Multicall2.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: returnData

state:
```solidity
    address target;
    bytes callData;
    bool success;
    bytes returnData;
```

loop function:
```solidity
function aggregate(Call[] memory calls) public returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
            require(success, "Multicall aggregate: call failed");
            returnData[i] = ret;
        }
    }
```

---

## 15. DeadfellazNanoX.withdrawAll
- file: `2e2dac881480C15B8B7b9e1539fbD34954F37C0E_DeadfellazNanoX.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: percentage
- writes_after: 

state:
```solidity
    address account;
    Phase private _phase;
    WithdrawalAddress[] public withdrawalAddresses;
    string private baseTokenURI;
    string private baseContractURI;
```

loop function:
```solidity
function withdrawAll() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert Errors.NothingToWithdraw();

        uint256 length = withdrawalAddresses.length;
        for (uint256 i; i < length; ) {
            uint256 percentage = withdrawalAddresses[i].percentage;
            address withdrawalAddress = withdrawalAddresses[i].account;
            uint256 value = balance * percentage / 100;

            (withdrawalAddress.call{value: value}(""));
            
            unchecked { ++i; }
        }

        balance = address(this).balance;
        if (balance > 0) {
            (withdrawalAddresses[0].account.call{value: balance}(""));
        }
    }
```

---

## 16. OCTOPUS_MINT.mintLoop
- file: `36579E63cF1B4ab794aA6B5E12d4A1eaEB29e87d_OCTOPUS_MINT.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: sale_in_progress

loop function:
```solidity
function mintLoop(
        address mint_address,
        bytes calldata mint_data,
        uint256 amount,
        uint256 cost
    ) external payable {
        if (!sale_in_progress) {
            revert SaleOver();
        }
        if (msg.value < amount * cost) {
            revert NotEnoughEth();
        }

        for (uint256 i = 0; i < amount; i++) {
            (bool success, ) = mint_address.call{value: cost}(mint_data);

            if (!success) {
                sale_in_progress = false;
                break;
            }
        }
    }
```

---

## 17. FundsLock.withdraw
- file: `3781f35fb5c6539bb6eb3b8d5bed3f1863ed4da3_FundsLock.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: balances
- writes_after: 

state:
```solidity
    bool withdrawn;
    bool allowedContract;
```

loop function:
```solidity
function withdraw() external {
        for (uint i = 0; i < balances[msg.sender].length; i++) {
            if (!balances[msg.sender][i].withdrawn && balances[msg.sender][i].lockupPeriodEnd <= block.timestamp) {
                balances[msg.sender][i].withdrawn = true;
                (bool success, ) = payable(msg.sender).call{
                    value: balances[msg.sender][i].amount
                }("");
                require(success, "Withdrawal failed!");
            }
        }
    }
```

---

## 18. UnikMarketplace.removeOffer
- file: `386F951101dd4c87113dBA5c869ea632c3cd1f8B_UnikMarketplace.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: offerCounts|tokenIdToOffer

state:
```solidity
    Unik private _Unik;
    address payable owner;
    address payable buyer;
    address tokenAddress;
    address payable owner;
    uint initPrice;
    uint startBlock;
    uint endBlock;
    bool canceled;
    uint highestBindingBid;
    address payable highestBidder;
    Offer[] public offers;
    Auction[] public auctions;
```

loop function:
```solidity
function removeOffer(uint256 tokenId, uint256 offerId) public{
    require(offers[offerId].buyer == msg.sender, "Must be the seller/owner to remove an offer");
    for (uint i = 0; i < offerCounts[tokenId]; i ++) {
      if(tokenIdToOffer[tokenId][i].offerId == offerId) {
        (bool sent, bytes memory data) 
        = tokenIdToOffer[tokenId][i].buyer.call{value: tokenIdToOffer[tokenId][i].price}("");
        require(sent, "remove offer failed");
        tokenIdToOffer[tokenId][i] = tokenIdToOffer[tokenId][offerCounts[tokenId]];
        tokenIdToOffer[tokenId].pop();
        offerCounts[tokenId] -= 1;
        break;
      }
    }
    emit OfferRemoved(msg.sender, tokenId, offerId);
  }
```

---

## 19. AuctionHouse.settleBidder
- file: `3B0422605E7471e3ad6fF0D3F5Ef6527ddAbB48A_Surreality.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: minted|refunded

state:
```solidity
    Bid memory new_bid;
```

loop function:
```solidity
function settleBidder(address[] memory _bidders) external onlyOwner nonReentrant {
        require(block.timestamp > auctionEndDateTime, "Auction hasn't ended.");
        require(auctionWinnersSet == true && raffleWinnersSet == true, "Auction winners not set");

        for (uint256 i = 0; i < _bidders.length; i++) {
            if (Bids[_bidders[i]].winner == true && Bids[_bidders[i]].minted == false && Bids[_bidders[i]].refunded == false) {
                // if winner, mint and refunde diff if any, update Bids
                uint256 difference = Bids[_bidders[i]].amount - Bids[_bidders[i]].finalprice;
                if (difference > 0) {
                    (bool success, ) = _bidders[i].call{value: difference}("");
                    require(success, "Failed to refund difference to winner.");
                }
                surreality.mint(_bidders[i]);
                Bids[_bidders[i]].minted = true;
                Bids[_bidders[i]].refunded = true;
            } 
            else if (Bids[_bidders[i]].winner == false && Bids[_bidders[i]].refunded == false) {
                // if not winner, refund
                (bool success, ) = _bidders[i].call{value: Bids[_bidders[i]].amount}("");
                require(success, "Failed to send refund to loser.");
                Bids[_bidders[i]].refunded = true;
            }
        }

    }
```

---

## 20. Auction.partiallyRefundBidders
- file: `3c80281246c935f3Dd842aF226902D5be38FE256_Auction.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: _bidRefunds
- writes_after: 

state:
```solidity
    address payable public immutable beneficiaryAddress;
    AuctionStatus private _auctionStatus;
    bool backfillingDisabled;
    bool started;
    bool ended;
```

loop function:
```solidity
function partiallyRefundBidders(
    uint256 auctionIndex_,
    address payable[] calldata bidders_,
    uint256[] calldata amounts_
  ) external onlyOwner whenPaused whenAuctionEnded {
    require(
      bidders_.length == amounts_.length,
      "bidders length doesn't match amounts length"
    );

    for (uint256 i = 0; i < bidders_.length; i++) {
      address payable bidder = bidders_[i];
      uint256 refundAmount = amounts_[i];
      bytes32 bidHash = _bidHash(auctionIndex_, bidder);
      // refund maximum is the user's max bid - amount already refunded
      uint256 refundMaximum = _bids[bidHash].unitPrice *
        _bids[bidHash].quantity -
        _bidRefunds[bidHash];

      require(
        refundAmount <= refundMaximum,
        "Refund amount is greater than balance"
      );

      // Skip bidders who aren't entitled to a refund.
      if (refundAmount == 0 || refundMaximum == 0) {
        continue;
      }

      _bidRefunds[bidHash] += refundAmount;
      (bool success, ) = bidder.call{value: refundAmount}("");
      require(success, "Transfer failed.");
      emit BidderRefunded(auctionIndex_, bidder, refundAmount);
    }
  }
```

---

## 21. MixinPurchase.purchase
- file: `3Eeb145384f12b010e6C9A6643D64091Ec67a6Cc_PublicLock.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: _originalDurations|_originalPrices|_originalTokens
- writes_after: 

state:
```solidity
    uint totalPriceToPay;
    uint tokenId;
```

loop function:
```solidity
function purchase(
    uint256[] memory _values,
    address[] memory _recipients,
    address[] memory _referrers,
    address[] memory _keyManagers,
    bytes[] calldata _data
  ) external payable
    returns (uint[] memory)
  {
    _lockIsUpToDate();
    if(_totalSupply +  _recipients.length > maxNumberOfKeys) {
      revert LOCK_SOLD_OUT();
    }
    if(
      (_recipients.length != _referrers.length)
      ||
      (_recipients.length != _keyManagers.length)
      ) {
      revert INVALID_LENGTH();
    }

    uint totalPriceToPay;
    uint tokenId;
    uint[] memory tokenIds = new uint[](_recipients.length);

    for (uint256 i = 0; i < _recipients.length; i++) {
      // check recipient address
      address _recipient = _recipients[i];

      // check for a non-expiring key
      if (expirationDuration == type(uint).max) {
        // create a new key
        tokenId = _createNewKey(
          _recipient,
          _keyManagers[i],
          type(uint).max
        );
      } else {
        tokenId = _createNewKey(
          _recipient,
          _keyManagers[i],
          block.timestamp + expirationDuration
        );
      }

      // price
      uint inMemoryKeyPrice = purchasePriceFor(_recipient, _referrers[i], _data[i]);
      totalPriceToPay = totalPriceToPay + inMemoryKeyPrice;

      // store values at purchase time
      _originalPrices[tokenId] = inMemoryKeyPrice;
      _originalDurations[tokenId] = expirationDuration;
      _originalTokens[tokenId] = tokenAddress;

      // store tokenIds 
      tokenIds[i] = tokenId;
      
      if(tokenAddress != address(0) && _values[i] < inMemoryKeyPrice) {
        revert INSUFFICIENT_ERC20_VALUE();
      }
    ... [37 more lines]
```

---

## 22. AutomatedExternalReflector.snapshot
- file: `3e921BcEb83487d09C3404022f101A1DC3E776ca_DynaAutoEthDistributorV1.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: dynaHodler

state:
```solidity
    bool exists;
    bool public snapshotPending;
    IUniswapV2Router02 public uniswapV2Router;
    ISupportingExternalReflection public tokenContract;
```

loop function:
```solidity
function snapshot() private returns (uint256){
        uint256 stopProcessingAt = currentQueueIndex.add(maxReflectionsPerRound);
        uint256 queueLength = queue.length;
        uint256 startingGas = gasleft();
        uint256 endGas = 0;
        uint256 queueStart = currentQueueIndex;
        uint256 gasLeft = startingGas;
        if(startingGas > maxGas){
            endGas = startingGas.sub(maxGas);
        } else {
            endGas = minGas;
        }
        uint256 minGasIncReturns = minGas.div(2).add(minGas);
        IERC20 controllingToken = IERC20(address(tokenContract));
        uint256 excludedTokensSnapshotted;
        if(currentQueueIndex == 0){
            excludedTokensSnapshotted = 0;
        } else {
            excludedTokensSnapshotted = totalExcludedTokenHoldings;
        }
        while(gasLeft > minGasIncReturns && gasLeft > endGas && currentQueueIndex < stopProcessingAt && currentQueueIndex < queueLength){
            address payable user = queue[currentQueueIndex];
            (bool success, bytes memory data) = address(controllingToken).call(abi.encodeWithSignature("balanceOf(address)",user));
            if(success){
                uint256 bal = abi.decode(data, (uint256));
                dynaHodler[user][currentRound] = User({
                    tokenBalance: bal,
                    totalPayouts: dynaHodler[user][currentRound-1].totalPayouts,
                    pendingPayouts: dynaHodler[user][currentRound-1].pendingPayouts,
                    exists: true,
                    lastPayoutRound: dynaHodler[user][currentRound-1].lastPayoutRound
                });

                dynaHodler[user][currentRound+1] = dynaHodler[user][currentRound];

                if(isExcludedFromReflections[queue[currentQueueIndex]]){
                    excludedTokensSnapshotted = excludedTokensSnapshotted.add(bal);
                }
            }
            currentQueueIndex++;
        }
        emit RoundSnapshotTaken(currentQueueIndex.sub(queueStart));

        rewardInstigator(currentQueueIndex.sub(queueStart));

        if(currentQueueIndex >= queueLength){
            currentQueueIndex = 0;
            snapshotPending = false;
        }
        return excludedTokensSnapshotted;
    }
```

---

## 23. BaseERC20Guild.endProposal
- file: `3f842726188FcD932d43bcA291be28138228e6D9_SnapshotRepERC20Guild.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: isExecutingProposal
- writes_after: isExecutingProposal

state:
```solidity
    IERC20Upgradeable public token;
    PermissionRegistry permissionRegistry;
    string public name;
    TokenVault public tokenVault;
    address creator;
    string title;
    string contentHash;
    ProposalState state;
    bool internal isExecutingProposal;
```

loop function:
```solidity
function endProposal(bytes32 proposalId) public virtual {
        require(!isExecutingProposal, "ERC20Guild: Proposal under execution");
        require(proposals[proposalId].state == ProposalState.Active, "ERC20Guild: Proposal already executed");
        require(proposals[proposalId].endTime < block.timestamp, "ERC20Guild: Proposal hasn't ended yet");

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
                    bytes4 callDataFuncSignature;
                    assembly {
                        callDataFuncSignature := mload(add(_data, 32))
                    }
                    // The permission registry keeps track of all value transferred and checks call permission
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
                    // We use isExecutingProposal variable to avoid re-entrancy in proposal execution
                    // slither-disable-next-line all
                    (bool success, ) = proposals[proposalId].to[i].call{value: proposals[proposalId].value[i]}(
    ... [13 more lines]
```

---

## 24. GatesOfOxyaLandSale.lottery
- file: `3fbcbF5AB433Ae4b5DEc1E3860A868Ce552CB195_GatesOfOxyaLandSale.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: chanceToWinPerAddress
- writes_after: 

state:
```solidity
    bool public initialized;
    uint public startTime;
    uint public dutchRoundNumber;
    uint public startingIndex;
    uint public session;
    address public oxyalandsNFTAddress;
    address public lotteryAddress;
    bool public isActive;
    bool public isFreeMintActive;
    bool public isLotteryActive;
    uint public countMintedBySale;
    uint public countMintedByFreeMint;
```

loop function:
```solidity
function lottery() external isInitialized nonReentrant {
        require(!isActive, "Sale isn't over");
        require(isLotteryActive, "Lottery is not active");
        require(tx.origin == msg.sender, "Cannot be called by contract account");

        if(chanceToWinPerAddress[msg.sender][0] + chanceToWinPerAddress[msg.sender][1] + chanceToWinPerAddress[msg.sender][2] + chanceToWinPerAddress[msg.sender][3] + chanceToWinPerAddress[msg.sender][4] + chanceToWinPerAddress[msg.sender][5] > 0) {
            ILotteryContractInterface(lotteryAddress).requestRandomWords();
            uint randomNumber = ILotteryContractInterface(lotteryAddress).returnLotteryRandomNumber();
            for(uint i = 0; i < 6; i++) {
                uint count = chanceToWinPerAddress[msg.sender][i];
                if(count != 0){
                    for(uint j = 0; j < count ; j++) {
                        //should call VRF
                        uint randomNumberFinal = uint(keccak256(abi.encodePacked(randomNumber,i, j))) % 1000;
                        emit RandomResult(randomNumberFinal);
                        bool hasWin =  randomNumberFinal < PUBLIC_PERCENTAGE[i];
                        chanceToWinPerAddress[msg.sender][i]-=1;

                        emit IsWinner(hasWin);
                    
                        if(hasWin==true){
                            //send Rewards
                            (bool success, ) = payable(msg.sender).call{value: REWARD}(
                                ""
                            );
                            require(success, "!transfer");
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
                        //should call VRF
                        uint randomNumberFinal = uint(keccak256(abi.encodePacked(randomNumber,i, j))) % 1000;
                        emit RandomResult(randomNumberFinal);
                        bool hasWin =  randomNumberFinal < WHITELIST_PERCENTAGE[i];
                        chanceToWinPerAddressWhitelist[msg.sender][i] -= 1;

                        emit IsWinner(hasWin);
                    
                        if(hasWin==true){
                            //send Rewards
                            (bool success, ) = payable(msg.sender).call{value: REWARD}(
                                ""
                            );
                            require(success, "!transfer");
                        }
                    }
                }
            }
        }
    }
```

---

## 25. LuckyJackpots.manualClaim
- file: `414cd0fd1ae65F5d3f724f62d047364df765364d_LuckyJackpots.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: failedSends

state:
```solidity
    address seller;
    address winner;
    address private processingBot;
    WinToProcess[] private pendingWins;
    ManuallyClaimableWin[] private failedSends;
    address private topContract;
```

loop function:
```solidity
function manualClaim(address winner) public reentrancyGuard {
        // Find the first win in failedSends
        for(uint i = 0; i < failedSends.length; i++) {
            if(failedSends[i].winner == winner) {
                (bool success,) = winner.call{value: failedSends[i].ethWinnings}("");
                require(success, "LuckyJackpot: Send failed.");
                // Delete the winner
                if(i != failedSends.length-1) {
                    failedSends[i] = failedSends[failedSends.length-1];
                }
                failedSends.pop();
                break;
            }
        }
    }
```

---

## 26. DiamondVault.releaseDiamond
- file: `467e274C1451ee68dfe64516Df2D59335FDE6027_DiamondHandFactory.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: currentlyDiamondHandingQuantities
- writes_after: 

state:
```solidity
    address public vaultOwner;
    address contractAddress;
    bytes data;
    address contractAddress;
    bool needsPayment;
    bool needsPayment;
```

loop function:
```solidity
function releaseDiamond(uint _diamondId) external onlyVaultOwner{
        require(_diamondId < diamondIds.current(), "Invalid diamondId");
        diamondHands memory diamondHandOrder = getDiamondHand(_diamondId);
        require(diamondHandOrder.status == diamondStatus.Holding, "Asset no longer held");
        require(block.timestamp >= diamondHandOrder.releaseTime, "Asset not yet unlocked");

        //Update status
        diamondList[_diamondId].status = diamondStatus.Released;
        
        //Release all the assets in this diamondHandOrder
        uint256 numAssets = getDiamondStructSize(_diamondId);
        uint256 i;
        for (i = 0; i < numAssets; i++){
            diamondStruct memory assetToRelease = getDiamondStruct(_diamondId, i);
            if (assetToRelease.tokenType == assetType.ERC721) {
                currentlyDiamondHanding[keccak256(abi.encodePacked(assetToRelease.contractAddress, assetToRelease.tokenId[0]))] = false;
                ERC721Interface(assetToRelease.contractAddress).safeTransferFrom(address(this), msg.sender, assetToRelease.tokenId[0], assetToRelease.data);
            } else if (assetToRelease.tokenType == assetType.ERC1155) {
                for(uint256 j; j < assetToRelease.tokenId.length; j++){
                    currentlyDiamondHandingQuantities[keccak256(abi.encodePacked(assetToRelease.contractAddress, assetToRelease.tokenId[j]))] -= assetToRelease.quantity[j];
                }
                ERC1155Interface(assetToRelease.contractAddress).safeBatchTransferFrom(address(this), msg.sender, assetToRelease.tokenId, assetToRelease.quantity, assetToRelease.data);
            } else if (assetToRelease.tokenType == assetType.ERC20) {
                currentlyDiamondHandingQuantities[keccak256(abi.encodePacked(assetToRelease.contractAddress))] -= assetToRelease.quantity[0];
                IERC20(assetToRelease.contractAddress).safeTransfer(msg.sender, assetToRelease.quantity[0]);
            } else if (assetToRelease.tokenType == assetType.ETH) {
                currentlyDiamondHandingQuantities[keccak256(abi.encodePacked(assetType.ETH))] -= assetToRelease.quantity[0];
                (bool success, ) = msg.sender.call{value: assetToRelease.quantity[0]}("");
                require(success, "ETH withdrawal failed");
            }
        }

        emit DiamondHandReleased(_diamondId, block.timestamp, diamondHandOrder.releaseTime, diamondHandOrder.breakPrice, diamondStatus.Released);
    }
```

---

## 27. AngleStrategy.claim
- file: `46Fa5c155901b321b5588986019C68688c374030_AngleVaultFactory.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: rewardToken
- writes_after: 

state:
```solidity
    AngleAccumulator public accumulator;
    address rewardToken;
```

loop function:
```solidity
function claim(address _token) external override {
		address gauge = gauges[_token];
		require(gauge != address(0), "!gauge");
		(bool success, ) = locker.execute(gauge, 0, abi.encodeWithSignature("user_checkpoint(address)", address(locker)));
		require(success, "Checkpoint failed!");
		(success, ) = locker.execute(
			gauge,
			0,
			abi.encodeWithSignature("claim_rewards(address,address)", address(locker), address(this))
		);
		require(success, "Claim failed!");
		for (uint8 i = 0; i < 8; i++) {
			address rewardToken = ILiquidityGauge(gauge).reward_tokens(i);
			if (rewardToken == address(0)) {
				break;
			}
			uint256 rewardsBalance = IERC20(rewardToken).balanceOf(address(this));
			uint256 multisigFee = (rewardsBalance * perfFee[gauge]) / BASE_FEE;
			uint256 accumulatorPart = (rewardsBalance * accumulatorFee) / BASE_FEE;
			uint256 veSDTPart = (rewardsBalance * veSDTFee) / BASE_FEE;
			uint256 claimerPart = (rewardsBalance * claimerReward) / BASE_FEE;
			IERC20(rewardToken).approve(address(accumulator), accumulatorPart);
			accumulator.depositToken(rewardToken, accumulatorPart);
			IERC20(rewardToken).transfer(rewardsReceiver, multisigFee);
			IERC20(rewardToken).transfer(veSDTFeeProxy, veSDTPart);
			IERC20(rewardToken).transfer(msg.sender, claimerPart);
			uint256 netRewards = rewardsBalance - multisigFee - accumulatorPart - veSDTPart - claimerPart;
			IERC20(rewardToken).approve(multiGauges[gauge], netRewards);
			IMultiRewards(multiGauges[gauge]).notifyRewardAmount(rewardToken, netRewards);
			emit Claimed(gauge, rewardToken, rewardsBalance);
		}
	}
```

---

## 28. AuctionHouse.settleBidder
- file: `4AC6fCaa7D85D8Eff4bad3EC00706e2a174b1CCA_AuctionHouse.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: minted|refunded

state:
```solidity
    Bid memory new_bid;
```

loop function:
```solidity
function settleBidder(address[] memory _bidders) external onlyOwner nonReentrant {
        require(block.timestamp > auctionEndDateTime, "Auction hasn't ended.");
        require(auctionWinnersSet == true && raffleWinnersSet == true, "Auction winners not set");

        for (uint256 i = 0; i < _bidders.length; i++) {
            if (Bids[_bidders[i]].winner == true && Bids[_bidders[i]].minted == false && Bids[_bidders[i]].refunded == false) {
                // if winner, mint and refunde diff if any, update Bids
                uint256 difference = Bids[_bidders[i]].amount - Bids[_bidders[i]].finalprice;
                if (difference > 0) {
                    (bool success, ) = _bidders[i].call{value: difference}("");
                    require(success, "Failed to refund difference to winner.");
                }
                freakyflowers.mint(_bidders[i]);
                Bids[_bidders[i]].minted = true;
                Bids[_bidders[i]].refunded = true;
            } 
            else if (Bids[_bidders[i]].winner == false && Bids[_bidders[i]].refunded == false) {
                // if not winner, refund
                (bool success, ) = _bidders[i].call{value: Bids[_bidders[i]].amount}("");
                require(success, "Failed to send refund to loser.");
                Bids[_bidders[i]].refunded = true;
            }
        }

    }
```

---

## 29. Archetype.withdrawTokens
- file: `4F855a1dB3038d0CE37B99dA2A555AD8fceaCe3D_Archetype.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: _affiliateBalance|_ownerBalance
- writes_after: 

state:
```solidity
    Config public config;
    BurnConfig public burnConfig;
    Options public options;
    string public provenance;
```

loop function:
```solidity
function withdrawTokens(address[] memory tokens) public {
    for (uint256 i = 0; i < tokens.length; i++) {
      address tokenAddress = tokens[i];
      uint128 wad = 0;

      if (msg.sender == owner() || msg.sender == config.ownerAltPayout || msg.sender == PLATFORM) {
        OwnerBalance memory balance = _ownerBalance[tokenAddress];
        if (msg.sender == owner() || msg.sender == config.ownerAltPayout) {
          wad = balance.owner;
          _ownerBalance[tokenAddress] = OwnerBalance({ owner: 0, platform: balance.platform });
        } else {
          wad = balance.platform;
          _ownerBalance[tokenAddress] = OwnerBalance({ owner: balance.owner, platform: 0 });
        }
      } else {
        wad = _affiliateBalance[msg.sender][tokenAddress];
        _affiliateBalance[msg.sender][tokenAddress] = 0;
      }

      if (wad == 0) {
        revert BalanceEmpty();
      }

      if (tokenAddress == address(0)) {
        bool success = false;
        // send to ownerAltPayout if set and owner is withdrawing
        if (msg.sender == owner() && config.ownerAltPayout != address(0)) {
          (success, ) = payable(config.ownerAltPayout).call{ value: wad }("");
        } else {
          (success, ) = msg.sender.call{ value: wad }("");
        }
        if (!success) {
          revert TransferFailed();
        }
      } else {
        IERC20Upgradeable erc20Token = IERC20Upgradeable(tokenAddress);

        if (msg.sender == owner() && config.ownerAltPayout != address(0)) {
          erc20Token.transfer(config.ownerAltPayout, wad);
        } else {
          erc20Token.transfer(msg.sender, wad);
        }
      }
      emit Withdrawal(msg.sender, tokenAddress, wad);
    }
  }
```

---

## 30. Auction.refundBidders
- file: `4ffc4ba310aef3aeafb1a645e1f4d0321950f8c9_Auction.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: _bids
- writes_after: 

state:
```solidity
    address payable public immutable beneficiaryAddress;
    bool private _allowWithdrawals;
    bool started;
    bool ended;
```

loop function:
```solidity
function refundBidders(address payable[] calldata bidders) external onlyOwner whenPaused whenAuctionEnded {
    uint256 totalRefundAmount = 0;
    for(uint256 i = 0; i < bidders.length; i++) {
      address payable bidder = bidders[i];
      uint256 refundAmount = _bids[bidder].unitPrice * _bids[bidder].quantity;

  
      if (refundAmount == 0) {
        continue;
      }

      _bids[bidder] = Bid(0,0);
      (bool success, ) = bidder.call{ value: refundAmount }("");
      require(success, "Transfer failed.");
      totalRefundAmount += refundAmount;
      emit BidderRefunded(bidder, refundAmount);
    }
  }
```

---

## 31. RainiCards._beforeTokenTransfer
- file: `54F456B544abFb785694400bcb1D85629B2D437f_RainiCards.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: subContract
- writes_after: 

state:
```solidity
    address public nftStakingPoolAddress;
    bool locked;
    address subContract;
    string public baseUri;
    string public contractURIString;
    address private contractOwner;
    bool willCallPool;
    bool willCallSubContract;
```

loop function:
```solidity
function _beforeTokenTransfer(address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data)
    internal virtual override
  {
    for (uint256 i = 0; i < ids.length; i++) {
      TokenVars memory _tokenVars = tokenVars[ids[i]];
      if (cards[_tokenVars.cardId].subContract != address(0)) {
        IRainiCustomNFT subContract = IRainiCustomNFT(cards[_tokenVars.cardId].subContract);
        subContract.onTransfered(from, to, ids[i], amounts[i], data);
      }
    }
  }
```

---

## 32. AuctionHouse.settleBidder
- file: `5713C7afC0252Ea62cAde1c24b69aa96BFFa11Fa_AuctionHouse.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: minted|refunded

state:
```solidity
    Bid memory new_bid;
```

loop function:
```solidity
function settleBidder(address[] memory _bidders) external onlyOwner nonReentrant {
        require(block.timestamp > auctionEndDateTime, "Auction hasn't ended.");
        require(auctionWinnersSet == true && raffleWinnersSet == true, "Auction winners not set");

        for (uint256 i = 0; i < _bidders.length; i++) {
            if (Bids[_bidders[i]].winner == true && Bids[_bidders[i]].minted == false && Bids[_bidders[i]].refunded == false) {
                // if winner, mint and refunde diff if any, update Bids
                uint256 difference = Bids[_bidders[i]].amount - Bids[_bidders[i]].finalprice;
                if (difference > 0) {
                    (bool success, ) = _bidders[i].call{value: difference}("");
                    require(success, "Failed to refund difference to winner.");
                }
                machines.mint(_bidders[i]);
                Bids[_bidders[i]].minted = true;
                Bids[_bidders[i]].refunded = true;
            } 
            else if (Bids[_bidders[i]].winner == false && Bids[_bidders[i]].refunded == false) {
                // if not winner, refund
                (bool success, ) = _bidders[i].call{value: Bids[_bidders[i]].amount}("");
                require(success, "Failed to send refund to loser.");
                Bids[_bidders[i]].refunded = true;
            }
        }

    }
```

---

## 33. BaseERC20Guild.endProposal
- file: `585E9f7A44161E0692fc6e4A7Cb4d72f33dF982F_SnapshotRepERC20Guild.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: isExecutingProposal
- writes_after: isExecutingProposal

state:
```solidity
    IERC20Upgradeable public token;
    PermissionRegistry permissionRegistry;
    string public name;
    TokenVault public tokenVault;
    address creator;
    string title;
    string contentHash;
    ProposalState state;
    bool internal isExecutingProposal;
```

loop function:
```solidity
function endProposal(bytes32 proposalId) public virtual {
        require(!isExecutingProposal, "ERC20Guild: Proposal under execution");
        require(proposals[proposalId].state == ProposalState.Active, "ERC20Guild: Proposal already executed");
        require(proposals[proposalId].endTime < block.timestamp, "ERC20Guild: Proposal hasn't ended yet");

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
                if (proposals[proposalId].to[i] != address(0) && proposals[proposalId].data[i].length > 0) {
                    bytes memory _data = proposals[proposalId].data[i];
                    bytes4 callDataFuncSignature;
                    assembly {
                        callDataFuncSignature := mload(add(_data, 32))
                    }
                    // The permission registry keeps track of all value transferred and checks call permission
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
                    // We use isExecutingProposal variable to avoid re-entrancy in proposal execution
    ... [15 more lines]
```

---

## 34. BoundlessAdapter._call
- file: `61182C0B55568595D348e8F995DE8b48664e6d85_BoundlessAdapter.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: outputToken
- writes_after: 

state:
```solidity
    IGatewayRegistry public registry;
    Lender public lender;
    CatalogAdapter public catalogAdapter;
    address contractAddress;
    bytes data;
    address outputToken;
```

loop function:
```solidity
function _call(
        address inputToken,
        uint256 inputAmount,
        address payable fallbackRecipient,
        ContractCallParams[] calldata contractCalls
    ) private {
        for (uint256 i = 0; i < contractCalls.length; i++) {
            require(
                allowedContracts[contractCalls[i].contractAddress],
                "BoundlessAdapter: unapproved contract call"
            );

            address outputToken = contractCalls[i].outputToken;

            uint256 value = inputToken == FEE_CURRENCY ? inputAmount : 0;

            uint256 outputTokenBalanceBefore = 0;
            if (outputToken != address(0x0)) {
                outputTokenBalanceBefore = outputToken == FEE_CURRENCY
                    ? address(this).balance
                    : IERC20(outputToken).balanceOf(address(this));
                if (inputToken == outputToken) {
                    outputTokenBalanceBefore =
                        outputTokenBalanceBefore -
                        inputAmount;
                }
            }

            if (inputToken != address(0x0) && inputToken != FEE_CURRENCY) {
                IERC20(inputToken).approve(
                    contractCalls[i].contractAddress,
                    inputAmount
                );
            }

            (bool success, bytes memory returnData) = contractCalls[i]
                .contractAddress
                .call{gas: gasleft() - 3000, value: value}(
                contractCalls[i].data
            );
            if (!success) {
                if (returnData.length < 68) {
                    revert("BoundlessAdapter: Internal contract call reverted");
                }

                // revert(string(returnData));
                assembly {
                    revert(add(returnData, 32), returnData)
                }
            }

            if (
                address(inputToken) != address(0x0) &&
                inputToken != FEE_CURRENCY
            ) {
                uint256 approvalRemaining = IERC20(inputToken).allowance(
                    address(this),
                    contractCalls[i].contractAddress
                );
                if (approvalRemaining > 0) {
    ... [46 more lines]
```

---

## 35. PledgeMint._refundPhase
- file: `61e8Fb506d1832a6214CfE1DC30862D58cdB9bA5_PledgeMint.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: pledges
- writes_after: 

state:
```solidity
    address admin;
    IERC721Pledge mintContract;
    bool mintContractLocked;
    bool pledgesLocked;
    PhaseConfig[] public phases;
```

loop function:
```solidity
function _refundPhase(uint16 phaseId) internal {
        PhaseConfig memory _phase = phases[phaseId];
        address[] storage _addresses = pledgers[phaseId];
        for (uint8 i; i < _addresses.length; ) {
            address addy = _addresses[i];
            uint8 quantity = pledges[phaseId][addy];
            if (quantity > 0) {
                pledges[phaseId][addy] = 0;
                (bool success, ) = addy.call{
                    value: _phase.mintPrice * quantity
                }("");
                if (!success) revert Errors.UnableToSendValue();
            }

            unchecked {
                ++i;
            }
        }
    }
```

---

## 36. OIRContestManualv2.endContestWithoutWinner
- file: `62C0F04eef81259659A153f2c47427Dacc770D85_OIRContestManualv2.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: amount
- writes_after: 

state:
```solidity
    address public treasuryAddress;
    address recipient;
```

loop function:
```solidity
function endContestWithoutWinner(uint256 contestID) external nonReentrant onlyApproved {
        Contest storage contest = Contests[contestID];
        require(!contest.isWon, "CONTEST_WON");
        require(!contest.refunded, "ALREADY_REFUNDED");
        contest.isActive = false;
        contest.refunded = true;
        //refund entrants
        for(uint256 x; x < contest.entryCount; x++) {
            Entry storage entry = contest.Entries[x];
            if (entry.amount == 0) continue; //don't refund free entries
            uint256 amount = entry.amount;
            entry.amount == 0;
            if (contest.paymentToken == address(0)) {
                require(amount <= address(this).balance, "INSUFFICIENT_BNB");
                (bool sent, ) = entry.user.call{value: amount}("");
                require(sent, "FAILED_SENDING_FUNDS");
            } else {
                require(amount <= IERC20(contest.paymentToken).balanceOf(address(this)), "INSUFFICIENT_BALANCE");
                IERC20(contest.paymentToken).transfer(entry.user, amount);
            }
        }
        emit EndContestWithoutWinner(_msgSender(), contestID);
    }
```

---

## 37. EvoBridgeV2.withdraw
- file: `62Cd928B16b7A92101C3091F5136fd9bb017870A_EvoBridgeV2.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: isWithdrawn
- writes_after: 

state:
```solidity
    address token;
    uint amount;
    uint bonus;
    address payable recipient;
    bytes data;
    address public owner;
```

loop function:
```solidity
function withdraw(Withdraw[] calldata ws) external nonReentrant() {
        require(isSigner[msg.sender], 'forbidden');

        for (uint i = 0; i < ws.length; i++) {
            Withdraw memory w = ws[i];

            require(!isWithdrawn[w.id], 'already withdrawn');
            isWithdrawn[w.id] = true;

            if (address(w.token) == address(1)) {
                require(address(this).balance >= w.amount, 'too low token balance');
                Address.sendValue(w.recipient, w.amount);
            } else {
                giveTokens(w.token, w.recipient, w.amount);
            }

            if (w.bonus > 0) {
                require(address(this).balance >= w.bonus, 'too low token balance for bonus');
                (bool success, ) = w.recipient.call{value: w.bonus}('');
                require(success || Address.isContract(w.recipient)); // allow fail on contracts
            }

            if (address(w.token) != address(1) && w.feeAmounts.length > 0) {
                for (uint j = 0; j < w.feeAmounts.length; j++) {
                    giveTokens(w.token, w.feeTargets[j], w.feeAmounts[j]);
                }
            }

            if (w.data.length > 0) {
                require(isRecipientContract[w.recipient], 'call to unauthorized contract');
                Address.functionCall(w.recipient, w.data, 'call to recipient contract failed');
            }

            emit Withdrawn(w.id, address(w.token), w.recipient, w.amount);
        }
    }
```

---

## 38. Archetype.withdrawTokens
- file: `62fF69036cffE0e53C81806D3CCE6494F116a1a2_Factory.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: _affiliateBalance|_ownerBalance|tokenAddress
- writes_after: 

state:
```solidity
    MintTier[] mintTiers;
    string baseUri;
    address affiliateSigner;
    Discount discounts;
    bool uriLocked;
    bool maxSupplyLocked;
    bool affiliateFeeLocked;
    bool discountsLocked;
    bool ownerAltPayoutLocked;
    bool royaltyEnforcementEnabled;
    bool royaltyEnforcementLocked;
    bool provenanceHashLocked;
    address tokenAddress;
    address tokenAddress;
    Config public config;
    Options public options;
    string public provenance;
```

loop function:
```solidity
function withdrawTokens(address[] memory tokens) public {
    for (uint256 i = 0; i < tokens.length; i++) {
      address tokenAddress = tokens[i];
      uint128 wad = 0;

      if (msg.sender == owner() || msg.sender == config.ownerAltPayout || msg.sender == PLATFORM) {
        OwnerBalance memory balance = _ownerBalance[tokenAddress];
        if (msg.sender == owner() || msg.sender == config.ownerAltPayout) {
          wad = balance.owner;
          _ownerBalance[tokenAddress] = OwnerBalance({ owner: 0, platform: balance.platform });
        } else {
          wad = balance.platform;
          _ownerBalance[tokenAddress] = OwnerBalance({ owner: balance.owner, platform: 0 });
        }
      } else {
        wad = _affiliateBalance[msg.sender][tokenAddress];
        _affiliateBalance[msg.sender][tokenAddress] = 0;
      }

      if (wad == 0) {
        revert BalanceEmpty();
      }

      if (tokenAddress == address(0)) {
        bool success = false;
        // send to ownerAltPayout if set and owner is withdrawing
        if (msg.sender == owner() && config.ownerAltPayout != address(0)) {
          (success, ) = payable(config.ownerAltPayout).call{ value: wad }("");
        } else {
          (success, ) = msg.sender.call{ value: wad }("");
        }
        if (!success) {
          revert TransferFailed();
        }
      } else {
        IERC20Upgradeable erc20Token = IERC20Upgradeable(tokenAddress);

        if (msg.sender == owner() && config.ownerAltPayout != address(0)) {
          erc20Token.transfer(config.ownerAltPayout, wad);
        } else {
          erc20Token.transfer(msg.sender, wad);
        }
      }
      emit Withdrawal(msg.sender, tokenAddress, wad);
    }
  }
```

---

## 39. ERC721LPhantomStakeable._batchTransferFrom
- file: `6483cb39ca184de2f98b255d8a507c021efbb4bd_MYTHICAL.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: _ownerships
- writes_after: 

state:
```solidity
    bool staked;
    bool locked;
    string name;
    string symbol;
    address owner;
    IStakingHelper stakingContract;
    bool stakingStatus;
    address currentOwner;
```

loop function:
```solidity
function _batchTransferFrom (address from, address to, uint256 startID, uint256 quantity, bool safeTransferCheck, bytes memory _data) internal {
        if (!isUnlocked(from)) revert TokensLocked();
        if (_msgSender() != from && !isApprovedForAll(from,_msgSender())) revert CallerLacksTransferPermissions();
        if (!multiOwnerCheck(from, startID, quantity)) revert TokensNotBatchable();
        if (to == address(0)) revert TransferZeroAddress();

        if (_stakingData.stakingStatus && _addressData[to].staked && _stakingData.stakingContract.needsRewardsUpdate(to)){
            _stakingData.stakingContract.aggregateRewards(to);
        }

        unchecked {
            for (uint256 i; i < quantity; i++) {
                uint256 currentToken = startID + i;
                delete _tokenApprovals[currentToken];

                if (i == 0){
                    _ownerships[currentToken] = to;
                } else {
                    delete _ownerships[currentToken];
                }
                emit Transfer(from, to, currentToken);
                if (safeTransferCheck){
                    if(to.code.length > 0 &&
                        ERC721TokenReceiver(to).onERC721Received(_msgSender(), address(0), currentToken, _data) !=
                        ERC721TokenReceiver.onERC721Received.selector) revert SafeTransferUnsafeDestination();
                }
            }

            _addressData[from].balance -= uint64(quantity);
            _addressData[to].balance += uint64(quantity);
            uint256 nextTokenId = startID + quantity;
            if (_ownerships[nextTokenId] == address(0) && nextTokenId < _collectionData.index) {
                _ownerships[nextTokenId] = from;
            }
        }
    }
```

---

## 40. X2Y2Integrated._executeOrder
- file: `687252e1c921CC3c6F7A38283d52b5bD5b32F077_X2Y2Integrated.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: directCall
- writes_after: 

state:
```solidity
    bool active;
    IERC20 token;
    address target;
    IERC20 token;
    address addr;
    bytes data;
    IERC721 token;
    IERC1155 token;
```

loop function:
```solidity
function _executeOrder(MarketOrder[] memory marketOrders) internal {
        for (uint256 i = 0; i < marketOrders.length; i++) {
            MarketOrder memory m = marketOrders[i];

            require(markets[m.addr].active, 'Execute: inactive market');
            bool directCall = markets[m.addr].directCall;

            (bool success, ) = directCall
                ? m.addr.call{value: m.value}(m.data)
                : m.addr.delegatecall(m.data);
            emit Result(i, success);
        }
    }
```

---

## 41. Multicall2.aggregate
- file: `713D7e019eC5e48F4D6BE8b640D5ed88b95023Bc_Multicall2.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: returnData

state:
```solidity
    address target;
    bytes callData;
    bool success;
    bytes returnData;
```

loop function:
```solidity
function aggregate(Call[] memory calls) public returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = ChainAdapter.blockNumber();
        returnData = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
            require(success, "Multicall aggregate: call failed");
            returnData[i] = ret;
        }
    }
```

---

## 42. WhopPaymentGateway._processEthPayment
- file: `72ca32879941A51B089F6aCE3dD8f13dD8bf6C14_WhopPaymentGateway.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: amount
- writes_after: 

state:
```solidity
    address private _signer;
    address private _subscriptionExecutor;
    address from;
    address token;
    string receipt_id;
```

loop function:
```solidity
function _processEthPayment(Payment calldata payment)
    private
    returns (uint256)
  {
    if (payment.amount > msg.value) revert InsufficientFunds();
    uint256 amount_left = payment.amount;
    for (uint8 i; i < payment.recipients.length; i++) {
      uint256 amount = (payment.amount / payment.divisor) *
        payment.dividends[i];
      if (amount > 0) {
        if (amount > amount_left) revert TooManyDividends();
        amount_left -= amount;
        (bool success, ) = payment.recipients[i].call{value: amount}("");
        if (!success) revert PaymentFailed();
      }
    }

    return amount_left;
  }
```

---

## 43. PoolManager.payAmaPartner
- file: `7413Ab5769CA76597d51c38633B79A8A82B6cf9C_PoolManager.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: fees
- writes_after: 

state:
```solidity
    string name;
    string username;
    address ownerAddress;
    string email;
    string configuration;
    string profileUrl;
    string details;
    bool status;
    bool kyc;
    bool audit;
    address poolAddress;
    address token;
    string name;
    string symbol;
    string poolDetails;
    address userAddress;
    address poolAddress;
    bool kyc;
    bool audit;
    address poolAddress;
    ... [10 more lines]
```

loop function:
```solidity
function payAmaPartner(
      address[] memory _partnerAddress,
      address _poolAddress
  ) public override payable onlyAllowedFactory {
      require(poolFactory != address(0) , "Factory Address is not set!!");
      uint256 feesPer = IPoolFactory(poolFactory).getPartnerFees();
     for (uint256 i = 0; i < _partnerAddress.length; i++) {
        require(_partnerAddress[i] != address(0), "Zero Address found");
        require(amaPartnerAddress.contains(_partnerAddress[i]) , "Partner address doesn't exist");
        require(amapartner[_partnerAddress[i]].status , "Currently Partner service not avalible !!");
        uint256 fees = amapartner[_partnerAddress[i]].fees.mul(feesPer).div(10000);
        uint256 totalPay = amapartner[_partnerAddress[i]].fees.sub(fees);
        (bool success , ) = payable(_partnerAddress[i]).call{value: totalPay}("");    
        require(success,"Transaction Failed!!");
        amapartnerhistory[_partnerAddress[i]].push(
            AmaPartnerHistory(
                amapartner[_partnerAddress[i]].fees,
                block.timestamp,
                msg.sender,
                _poolAddress,
                amapartner[_partnerAddress[i]].kyc,
                amapartner[_partnerAddress[i]].audit
            )
        );

        poolpartnerdetails[_poolAddress].push(
            poolPartnerDetails(
                _poolAddress,
                _partnerAddress[i],
                amapartner[_partnerAddress[i]].fees,
                amapartner[_partnerAddress[i]].details,
                amapartner[_partnerAddress[i]].profileUrl,
                amapartner[_partnerAddress[i]].name,
                amapartner[_partnerAddress[i]].kyc,
                amapartner[_partnerAddress[i]].audit
            )
        );
     }
  }
```

---

## 44. ArtMarket.acceptBid
- file: `758aA9B0B2368bC5876d1342f21209b9e88Bffc1_ArtMarket.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: users
- writes_after: 

state:
```solidity
    address tokenAddress;
    address payTo;
    Asset asset;
    address payTo;
    address maker;
    address referral;
    address maker;
    address referral;
    address buyer;
    Asset asset;
    bool isInitialized;
    IFeeManager public feeManager;
    ITradeEventReceiver public tradeEventReceiver;
    bool isCanceled;
```

loop function:
```solidity
function acceptBid(address _tokenAddress, uint256 _tokenId, address _maker, uint256 _price) external {
        Listing storage listing = listings[_tokenAddress][_tokenId];
        Order[] storage orderList = orders[_tokenAddress][_tokenId];

        for (uint i = 0; i < orderList.length; i++) {
            Order memory order = orderList[i];
            if (order.price == _price &&
                order.maker == _maker &&
                (order.expirationTime >= block.timestamp || order.expirationTime == 0)) {

                if (listing.payTo != address(0)) {
                    require(listing.payTo == msg.sender, "Only owner can accept bid");
                    _transferAsset(order.maker, _tokenAddress, _tokenId);
                    delete listings[_tokenAddress][_tokenId];
                } else {
                    require(IERC721(_tokenAddress).ownerOf(_tokenId) == address(msg.sender), "Only owner can accept bid");
                    IERC721(_tokenAddress).transferFrom(msg.sender, order.maker, _tokenId);
                }

                // settle fee and profit
                uint256 fee = order.price * feeManager.getTradeFeeBips(_tokenAddress, _tokenId) / MAX_BIPS;
                feeManager.settleTradeFee{value: fee}(_tokenAddress, _tokenId, order.referral);

                uint256 payAmount = order.price - fee;
                users[msg.sender].profitTotal += payAmount;
                users[msg.sender].balance += payAmount;

                tradeEventReceiver.onTradeEvent(_tokenAddress, _tokenId, order.price, msg.sender, order.maker);
                emit BiddingAccepted(_tokenAddress, _tokenId, order.price, order.price, order.expirationTime, msg.sender, order.maker);
                emit SaleProfitMade(msg.sender, payAmount, _tokenAddress, _tokenId);

                // initialize
                orderList[i] = orderList[orderList.length - 1];
                orderList.pop();
                break;
            }
        }

        _removeExpiredBid(_tokenAddress, _tokenId);
    }
```

---

## 45. SuperBockRoyalties.withdraw
- file: `766eF20ddc9D0385BA7C0Af3A5394238366e95b1_SuperBockRoyalties.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: balances
- writes_after: 

state:
```solidity
    uint earned;
    uint withdrawn;
    Balance public contractBalance;
    uint newEarnings;
```

loop function:
```solidity
function withdraw(uint[] calldata tokenIds) external nonReentrant {

    uint withdrawnAmount = 0;

    for (uint i = 0; i < tokenIds.length; i++) {

      uint tokenId = tokenIds[i];

      // check balance
      Balance memory balance = balances[tokenId];
      uint withdrawable = balance.earned - balance.withdrawn;
      withdrawnAmount += withdrawable;
      balance.withdrawn += withdrawable;

      // update balance
      balances[tokenId] = balance;

      // send eth
      address payable creator = creators[tokenId];
      (bool success, ) = creator.call{value : withdrawable}("");
      require(success, "Withdrawal failed");

      emit Withdrawn(tokenId, withdrawable, creator);
    }

    // sanity check
    Balance memory trackedBalance = contractBalance;
    trackedBalance.withdrawn += withdrawnAmount;
    require(trackedBalance.withdrawn <= trackedBalance.earned, "Withdrawals exceed earnings");

    // update global balance
    contractBalance = trackedBalance;
  }
```

---

## 46. MultiMerge.merge
- file: `85b4AC25642207CeB3b7a850CBb1a21b6C1341d0_MultiMerge.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: cost
- writes_after: 

state:
```solidity
    IRainiNft1155 public nftContract;
    address public nftStakingPoolAddress;
    bool willCallPool;
    bool willCallSubContract;
    bool isFinished;
    bool success;
    INftStakingPool nftStakingPool;
    IRainiCustomNFT subContract;
```

loop function:
```solidity
function merge(uint256 _cardId, uint256 _level, uint256[] memory _tokenIds, uint256[] memory _burnAmounts, uint256[] memory _data) 
    external payable nonReentrant {
      IRainiNft1155.CardLevel memory _cardLevel = nftContract.cardLevels(_cardId, _level);

      MergeData memory _locals = MergeData({
        cost: 0,
        currentCard: 0,
        willCallPool: false,
        willCallSubContract: false,
        isFinished: false,
        success: false
      });

      CardAmount[] memory cardAmounts = mergeAmounts[_cardId][_level];

      require(cardAmounts.length > 0, 'merge invalid');

      uint256[] memory mergedTokensIds;
      INftStakingPool nftStakingPool;
      IRainiCustomNFT subContract;

      _locals.willCallPool = nftStakingPoolAddress != address(0) && _level > 0 && nftContract.cardLevels(_cardId, _level-1).tokenId == 0;
      _locals.willCallSubContract = _cardLevel.tokenId == 0 && nftContract.cards(_cardId).subContract != address(0);
      if (_locals.willCallPool || _locals.willCallSubContract) {
        mergedTokensIds = new uint256[](_tokenIds.length);
        if (_locals.willCallPool) {
          nftStakingPool = INftStakingPool(nftStakingPoolAddress);
        }
        if (_locals.willCallSubContract) {
          subContract = IRainiCustomNFT(nftContract.cards(_cardId).subContract);
        }
      }

      CardAmount[] memory cost = cardAmounts;

      for (uint256 i = 0; i < _tokenIds.length; i++) {
        require(_burnAmounts[i] <= nftContract.balanceOf(_msgSender(), _tokenIds[i]), 'not enough balance');
        IRainiNft1155.TokenVars memory _tempTokenVars =  nftContract.tokenVars(_tokenIds[i]);
        require(_tempTokenVars.cardId == cost[_locals.currentCard].cardId, "card mismatch");
        IRainiNft1155.CardLevel memory _tempCardLevel = nftContract.cardLevels(_tempTokenVars.cardId, _tempTokenVars.level);
        if (_tempTokenVars.level == 0) {
          cost[_locals.currentCard].amount -= uint32(_burnAmounts[i]);
        } else {
          cost[_locals.currentCard].amount -= uint32(_burnAmounts[i] * _tempCardLevel.conversionRate);
        }
        nftContract.burn(_msgSender(), _tokenIds[i], _burnAmounts[i], false);

        if (cost[_locals.currentCard].amount == 0) {
          if (_locals.currentCard < cost.length - 1) {
            _locals.currentCard++;
          } else {
            _locals.isFinished = true;
          }
        }

        if (_locals.willCallPool || _locals.willCallSubContract) {
          mergedTokensIds[i] = _tokenIds[i];
          if (_locals.isFinished) {
            
            if (_locals.willCallPool) {
    ... [17 more lines]
```

---

## 47. Krakatoa.directSell
- file: `867b62bEF16944bD38f91e8DD63a4F9eEa8300a8_Krakatoa.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: _nonces|fee|product
- writes_after: 

state:
```solidity
    address seller;
    address buyer;
    Status status;
    address seller;
    Status status;
```

loop function:
```solidity
function directSell(uint64 orderId, Product[] calldata products, uint256 finalTimestamp, bytes calldata signature)
    external
    payable
    checkSignature(abi.encode(msg.sender, orderId, products, finalTimestamp), signature)
    checkRequest(orderId, finalTimestamp)
    {
        require(products.length > 0 && products.length < 255, "KR: Invalid products count");
        uint256 total = 0;
        uint256 fees = 0;

        for (uint8 i = 0; i < products.length; i++) {
            Product memory product = products[i];
            require(_nonces[product.productId] < product.nonce, "KR: Item already sold");
            require(product.seller != address(0), "KR: Wrong seller");
            total += product.price;
            uint256 fee = _getFee(products[i].price);
            fees += fee;
            _nonces[product.productId] = product.nonce;

            (bool success,) = payable(product.seller).call{value : product.price - fee}("");
            require(success, "KR: Unable to send funds");
        }

        require(total == msg.value, "KR: Wrong value");

        (bool success2,) = feeWallet().call{value : fees}("");
        require(success2, "KR: Unable to send fee");

        _orders[orderId].price = total;
        _orders[orderId].fee = fees;
        _orders[orderId].buyer = msg.sender;
        _orders[orderId].status = Status.Withdrawn;
        emit OrderStatus(orderId, Status.Withdrawn);
    }
```

---

## 48. BrickNFT.withdrawAll
- file: `880Ed873dde83f533564903C8Aebb6E9Fa9f8C81_BrickNFT.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: percentage
- writes_after: 

state:
```solidity
    address account;
    Phase private _phase;
    WithdrawalAddress[] public withdrawalAddresses;
    string private baseTokenURI;
    string private baseContractURI;
    IProxyTracking public proxyTrackingContract;
```

loop function:
```solidity
function withdrawAll() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert Errors.NothingToWithdraw();

        uint256 length = withdrawalAddresses.length;
        for (uint256 i; i < length; ) {
            uint256 percentage = withdrawalAddresses[i].percentage;
            address withdrawalAddress = withdrawalAddresses[i].account;
            uint256 value = balance * percentage / 100;

            (withdrawalAddress.call{value: value}(""));
            
            unchecked { ++i; }
        }

        balance = address(this).balance;
        if (balance > 0) {
            (withdrawalAddresses[0].account.call{value: balance}(""));
        }
    }
```

---

## 49. Squid.payoutAll
- file: `8839a13A1B23e6f1c44F0DB2bf355e4d3d29E8E8_Factory.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: last_withdrawl|total_released
- writes_after: 

state:
```solidity
    address factory;
    address creator;
    string name;
    string description;
    bool locked;
    uint fee;
```

loop function:
```solidity
function payoutAll() external {

        require(msg.sender == factory, 'Error: 1012');
        require(address(this).balance > 0, 'Error: 1009');
        require(!locked, "Error: 1015");

        for(uint i = 0; i < payees.length; i++) {

            address payee = payees[i];

            if(shareholders[payee] == 0) { continue; }

            uint bal = getUserBalance(payee);
            if(bal > 0) {
                // Track Data
                total_released[payee] += bal;
                last_withdrawl[payee] = block.timestamp;

                // Pay
                (bool success, bytes memory data) = payable(payee).call{value: bal}("");
                require(success, "Failed to send");
            }
        }
    }
```

---

## 50. MixinPurchase.purchase
- file: `8a520BD5e3a78D207617B9BB2bE1204ae291F314_PublicLock.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: _originalDurations|_originalPrices|_originalTokens
- writes_after: 

state:
```solidity
    uint totalPriceToPay;
    uint tokenId;
```

loop function:
```solidity
function purchase(
    uint256[] memory _values,
    address[] memory _recipients,
    address[] memory _referrers,
    address[] memory _keyManagers,
    bytes[] calldata _data
  ) external payable
  {
    _lockIsUpToDate();
    require(maxNumberOfKeys > _totalSupply, 'LOCK_SOLD_OUT');
    require(_recipients.length == _referrers.length, 'INVALID_REFERRERS_LENGTH');
    require(_recipients.length == _keyManagers.length, 'INVALID_KEY_MANAGERS_LENGTH');

    uint totalPriceToPay;
    uint tokenId;

    for (uint256 i = 0; i < _recipients.length; i++) {
      // check recipient address
      address _recipient = _recipients[i];
      require(_recipient != address(0), 'INVALID_ADDRESS');
      
      // check for a non-expiring key
      if (expirationDuration == type(uint).max) {
        // create a new key
        tokenId = _createNewKey(
          _recipient,
          _keyManagers[i],
          type(uint).max
        );
      } else {
        tokenId = _createNewKey(
          _recipient,
          _keyManagers[i],
          block.timestamp + expirationDuration
        );
      }

      // price      

      uint inMemoryKeyPrice = purchasePriceFor(_recipient, _referrers[i], _data[i]);
      totalPriceToPay = totalPriceToPay + inMemoryKeyPrice;

      // store values at purchase time
      _originalPrices[tokenId] = inMemoryKeyPrice;
      _originalDurations[tokenId] = expirationDuration;
      _originalTokens[tokenId] = tokenAddress;
      
      if(tokenAddress != address(0)) {
        require(inMemoryKeyPrice <= _values[i], 'INSUFFICIENT_ERC20_VALUE');
      }

      // store in unlock
      _recordKeyPurchase(inMemoryKeyPrice, _referrers[i]);

      // fire hook
      uint pricePaid = tokenAddress == address(0) ? msg.value : _values[i];
      if(address(onKeyPurchaseHook) != address(0)) {
        onKeyPurchaseHook.onKeyPurchase(
          msg.sender, 
          _recipient, 
    ... [20 more lines]
```

---

## 51. BridgePool.withdraw
- file: `9280E0ffdfAe4Ec895FDF4D4978c9E1B869Eb774_BridgePool.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: withdrawn
- writes_after: 

state:
```solidity
    address public owner;
```

loop function:
```solidity
function withdraw(Withdraw[] memory ws) override external nonReentrant() {
        // allowed only 'withdrawer' or 'withdrawer' through 'contract:withdrawer'
        require(operator[msg.sender] == 4 || (operator[tx.origin] == 4 && operator[msg.sender] == 2), 'forbidden');

        for (uint i = 0; i < ws.length; i++) {
            Withdraw memory w = ws[i];

            require(!withdrawn[w.id], 'already withdrawn');
            withdrawn[w.id] = true;

            if (address(w.token) == address(1)) {
                require(address(this).balance >= w.amount + w.bonus, 'too low token balance');
                (bool success, ) = w.recipient.call{value: w.amount}('');
                require(success, 'native transfer error');
            } else {
                require(
                    w.token.balanceOf(address(this)) >= w.amount && address(this).balance >= w.bonus,
                    'too low token balance'
                );
                safeTransfer(w.token, w.recipient, w.amount);
            }

            if (w.bonus > 0) {
                // may fail on contracts
                w.recipient.call{value: w.bonus}('');
            }

            emit Withdrawn(w.id, address(w.token), w.recipient, w.amount);
        }
    }
```

---

## 52. MeMyselfAndOPI.withdrawAll
- file: `94199b0f2Ae26Fb95f167F52d53fC96558C320F7_MeMyselfAndOPI.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: percentage
- writes_after: 

state:
```solidity
    Phase private _phase;
    WithdrawalAddress[] public withdrawalAddresses;
    address public royaltiesSplitAddress;
    string private baseTokenURI;
    string private baseContractURI;
```

loop function:
```solidity
function withdrawAll() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert Errors.NothingToWithdraw();

        uint256 length = withdrawalAddresses.length;
        for (uint256 i; i < length; ) {
            uint256 percentage = withdrawalAddresses[i].percentage;
            address withdrawalAddress = withdrawalAddresses[i].account;
            uint256 value = (balance * percentage) / 100;

            (withdrawalAddress.call{ value: value }(""));

            unchecked {
                ++i;
            }
        }

        balance = address(this).balance;
        if (balance > 0) {
            (withdrawalAddresses[0].account.call{ value: balance }(""));
        }
    }
```

---

## 53. BribeVault.transferBribes
- file: `9DDb2da7Dd76612e0df237B89AF2CF4413733212_BribeVault.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: token
- writes_after: 

state:
```solidity
    address token;
```

loop function:
```solidity
function transferBribes(bytes32[] calldata rewardIdentifiers)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(rewardIdentifiers.length != 0, "Invalid rewardIdentifiers");

        // Transfer the bribe funds to fee recipient and reward distributor
        for (uint256 i; i < rewardIdentifiers.length; ++i) {
            bytes32 rewardIdentifier = rewardIdentifiers[i];
            require(
                rewardToBribes[rewardIdentifier].length != 0,
                "Invalid rewardIdentifier"
            );

            Transfer storage r = rewardTransfers[rewardIdentifier];
            require(
                r.distributorAmountTransferred == 0,
                "Bribe has already been transferred"
            );

            address token = bribes[rewardToBribes[rewardIdentifier][0]].token;
            (
                uint256 feeAmount,
                uint256 distributorAmount
            ) = calculateTransferAmounts(rewardIdentifier);

            // Set the beforeFees field to prevent duplicate transfers
            r.feeAmount = feeAmount;
            r.distributorAmountTransferred = distributorAmount;

            // Check whether it's a native token reward
            if (token == address(this)) {
                (bool sentFeeRecipient, ) = feeRecipient.call{value: feeAmount}(
                    ""
                );
                require(
                    sentFeeRecipient,
                    "Failed to transfer to fee recipient"
                );

                (bool sentDistributor, ) = distributor.call{
                    value: distributorAmount
                }("");
                require(sentDistributor, "Failed to transfer to distributor");

                // Native tokens typically don't have fees, so the value should be identical to "before fees"
                r.distributorAmountReceived = distributorAmount;
            } else {
                IERC20 t = IERC20(token);

                // Necessary to calculate the after-fee amount received by the distributor
                uint256 distributorBalance = t.balanceOf(distributor);

                t.safeTransfer(feeRecipient, feeAmount);
                t.safeTransfer(distributor, distributorAmount);

                // Set the "after fees" field to record actual amount received by the distributor
                r.distributorAmountReceived =
                    t.balanceOf(distributor) -
                    distributorBalance;
    ... [10 more lines]
```

---

## 54. ClubVirtualMarketplaceERC721.buyFromProposal
- file: `9d3febce4a50b101a50908a130ce8bea03839058_ClubVirtualMarketplaceERC721.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: buyNowPrice
- writes_after: 

state:
```solidity
    address public platformNormalNFT;
    address public platformLazyNFT;
    address nftHighestBidder;
    address nftSeller;
    address ERC20Token;
    address nftSeller;
    address ERC20Token;
    address buyer;
    uint royaltyAmount;
```

loop function:
```solidity
function buyFromProposal(address _nftContractAddress, uint256 _tokenId)
        external
        payable
        nonReentrant
    {
        address seller = nftContractSale[_nftContractAddress][_tokenId]
            .nftSeller;
        require(
            msg.sender == buyProposal[_nftContractAddress][_tokenId].buyer,
            "Invalid Buyer"
        );
        require(msg.sender != seller, "Seller cannot buy own NFT");
        uint256 buyNowPrice = buyProposal[_nftContractAddress][_tokenId].price;
        uint256 platformFees = (buyNowPrice *
            (dataStorage.platformCommission())) / (10000);
        uint256 totalPayable = buyNowPrice + platformFees;
        uint royaltyAmount;

        require(msg.value >= totalPayable, "Must be greater than NFT cost");

        // 2. Cut ownerAmount from Seller
        IDataStorage.Affiliate[3] memory sellerCommission;
        sellerCommission = dataStorage.getSellerCommission(seller);
        for (uint8 i = 0; i < sellerCommission.length; i++) {
            if (sellerCommission[i].feePercent > 0) {
                uint256 ownerAmount = (buyNowPrice *
                    (sellerCommission[i].feePercent)) / (10000);
                buyNowPrice -= ownerAmount;
                (bool _success, ) = payable(sellerCommission[i].affiliateAddr)
                    .call{value: ownerAmount}("");
                require(_success, "TRANSFER_FAILED");
            }
        }
        // 3. Cut NFT Commission from Seller
        uint256 nftFee = (buyNowPrice * (dataStorage.nftCommission())) /
            (10000);

        // update total payable to seller
        totalPayable = totalPayable - (platformFees + buyNowPrice + nftFee);

        // Reset Sale Data
        _resetSale(_nftContractAddress, _tokenId);
        if (dataStorage.isActivated(_nftContractAddress, _tokenId) == true) {
            address royaltyOwner = dataStorage.getRoyaltyOwner(
                _nftContractAddress,
                _tokenId
            );
            uint _royaltyPercentage = dataStorage.getRoyaltyPercentage(
                _nftContractAddress,
                _tokenId
            );
            // 3. Cut Royaltypercentage
            royaltyAmount = (buyNowPrice * (_royaltyPercentage)) / (10000);
            totalPayable -= royaltyAmount;
            (bool _success, ) = payable(royaltyOwner).call{
                value: royaltyAmount
            }("");
            require(_success);
        } else {
            dataStorage.activateRoyalty(_nftContractAddress, _tokenId);
    ... [14 more lines]
```

---

## 55. CallTester.makeCalls
- file: `a035e46E1ff1A451E577Bd8aC1eB8Cf5252491B4_CallTester.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: gas
- writes_after: 

state:
```solidity
    address to;
    bytes data;
    bytes data;
    bool success;
```

loop function:
```solidity
function makeCalls(CallDesc[] memory calls) external payable returns (Return[] memory rets) {
        rets = new Return[](calls.length);
        for (uint i = 0; i < calls.length; i++) {
            CallDesc memory c = calls[i];
            uint gas = gasleft();
            (bool ok, bytes memory data) = c.to.call{value: c.value}(c.data);
            rets[i] = Return({
                data: data,
                success: ok,
                gas: gas - gasleft()
            });
        }
    }
```

---

## 56. LiquidStakingManager.mintDerivatives
- file: `a189714e003FBA1FC74c3e922C71513Bf2312714_GiantSavETHVaultPool.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: stakedKnotsOfSmartWallet

state:
```solidity
    address public brand;
    address public override stakehouse;
    address public syndicate;
    address public dao;
    OptionalHouseGatekeeper public gatekeeper;
    ISyndicateFactory public syndicateFactory;
    IOwnableSmartWalletFactory public smartWalletFactory;
    string public stakehouseTicker;
    StakingFundsVault public stakingFundsVault;
    SavETHVault public savETHVault;
    LSDNFactory public factory;
    bool public enableWhitelisting;
```

loop function:
```solidity
function mintDerivatives(
        bytes[] calldata _blsPublicKeyOfKnots,
        IDataStructures.ETH2DataReport[] calldata _beaconChainBalanceReports,
        IDataStructures.EIP712Signature[] calldata _reportSignatures
    ) external nonReentrant {
        uint256 numOfKnotsToProcess = _blsPublicKeyOfKnots.length;
        if (numOfKnotsToProcess == 0) revert EmptyArray();
        if (numOfKnotsToProcess != _beaconChainBalanceReports.length) revert InconsistentArrayLength();
        if (numOfKnotsToProcess != _reportSignatures.length) revert InconsistentArrayLength();

        for (uint256 i; i < numOfKnotsToProcess; ++i) {
            // check if BLS public key is registered and not banned
            if (isBLSPublicKeyBanned(_blsPublicKeyOfKnots[i])) revert BLSPubKeyBanned();

            // check that the BLS pub key has deposited lifecycle
            if(
                getAccountManager().blsPublicKeyToLifecycleStatus(_blsPublicKeyOfKnots[i]) != IDataStructures.LifecycleStatus.DEPOSIT_COMPLETED
            ) revert DepositNotCompleted();

            // Expand the staking funds vault shares that can claim rewards
            stakingFundsVault.updateDerivativesMinted(_blsPublicKeyOfKnots[i]);

            // Poke the giant pools in the event they need to know about the minting of derivatives they funded
            factory.giantSavETHPool().onMintDerivatives(_blsPublicKeyOfKnots[i]);
            factory.giantFeesAndMev().onMintDerivatives(_blsPublicKeyOfKnots[i]);

            // The first knot will create the Stakehouse
            if(numberOfKnots == 0) {
                _createLSDNStakehouse(
                    _blsPublicKeyOfKnots[i],
                    _beaconChainBalanceReports[i],
                    _reportSignatures[i]
                );
            }
            else {
                // join stakehouse
                _joinLSDNStakehouse(
                    _blsPublicKeyOfKnots[i],
                    _beaconChainBalanceReports[i],
                    _reportSignatures[i]
                );
            }

            address smartWallet = smartWalletOfKnot[_blsPublicKeyOfKnots[i]];
            stakedKnotsOfSmartWallet[smartWallet] -= 1;

            if(stakedKnotsOfSmartWallet[smartWallet] == 0) {
                _authorizeRepresentative(smartWallet, smartWalletDormantRepresentative[smartWallet], true);

                // delete the dormant representative as it is set active
                delete smartWalletDormantRepresentative[smartWallet];
            }
        }
    }
```

---

## 57. PomBridge.withdraw
- file: `a4c37d24cdc8b047de9e1aad30cdbbb37ad76c78_PomBridge.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: isWithdrawn
- writes_after: 

state:
```solidity
    address token;
    uint amount;
    uint bonus;
    address payable recipient;
    bytes data;
    address public owner;
```

loop function:
```solidity
function withdraw(Withdraw[] calldata ws) external nonReentrant() {
        require(isSigner[msg.sender], 'forbidden');

        for (uint i = 0; i < ws.length; i++) {
            Withdraw memory w = ws[i];

            require(!isWithdrawn[w.id], 'already withdrawn');
            isWithdrawn[w.id] = true;

            if (address(w.token) == address(1)) {
                require(address(this).balance >= w.amount, 'too low token balance');
                Address.sendValue(w.recipient, w.amount);
            } else {
                giveTokens(w.token, w.recipient, w.amount);
            }

            if (w.bonus > 0) {
                require(address(this).balance >= w.bonus, 'too low token balance for bonus');
                (bool success, ) = w.recipient.call{value: w.bonus}('');
                require(success || Address.isContract(w.recipient)); // allow fail on contracts
            }

            if (address(w.token) != address(1) && w.feeAmounts.length > 0) {
                for (uint j = 0; j < w.feeAmounts.length; j++) {
                    giveTokens(w.token, w.feeTargets[j], w.feeAmounts[j]);
                }
            }

            if (w.data.length > 0) {
                require(isRecipientContract[w.recipient], 'call to unauthorized contract');
                Address.functionCall(w.recipient, w.data, 'call to recipient contract failed');
            }

            emit Withdrawn(w.id, address(w.token), w.recipient, w.amount);
        }
    }
```

---

## 58. PokeXVerse.royaltyPayout
- file: `a744506fa02ada758abb6c4704418704d7726cb9_PokeXVerse.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: totalEthRoyaltyPayout

state:
```solidity
    string private _currentBaseURI;
    uint private _reservedMints;
    bool private paused;
    string public unrevealedURI;
    uint public amountOfTokensGotPayout;
    address public pledgeContract;
```

loop function:
```solidity
function royaltyPayout(uint number, uint256 payout) public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > number * payout, "Insufficient Funds to pay out Royalties!");
        require(amountOfTokensGotPayout + number <= totalSupply());
        for (uint i; i < number; i++) {
            (bool success, ) = payable(ownerOf(amountOfTokensGotPayout + i)).call{value: payout}("");
            require(success, "Address: unable to send value, recipient may have reverted");
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

---

## 59. ShibaGiftToken.process
- file: `aC96E81cF677287997B9fBaB65Ddba4A25910add_ShibaGiftToken.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: currentIndex
- writes_after: 

state:
```solidity
    address marketing;
    address team;
    address reserve;
    Fee private sellFees;
    Fee private buyFees;
    FeeWallet public feeWallets;
    IDexRouter public DexRouter;
    address public DexPair;
    bool public inSwapAndLiquify;
```

loop function:
```solidity
function process(uint256 gas) internal {
        uint256 shareholderCount = shareholders.length;

        if (shareholderCount == 0 || !distributionEnabled) {
            return;
        }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        uint256 iterations = 0;

        while (gasUsed < gas && iterations < shareholderCount) {
            if (currentIndex >= shareholderCount) {
                currentIndex = 0;
            }
            uint256 rewardAmount = getClaimableReward(
                shareholders[currentIndex]
            );
            if (rewardAmount > minDistribution) {
                rewardedAmount[shareholders[currentIndex]] += rewardAmount;
                payable(shareholders[currentIndex]).call{value: rewardAmount}(
                    ""
                );
            }
            gasUsed = gasUsed + gasLeft - gasleft();
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
    }
```

---

## 60. Multicall2.aggregate
- file: `aF68d36A7B664965F3DB8249dD4eBd3084efed01_Multicall2.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: returnData

state:
```solidity
    address target;
    bytes callData;
    bool success;
    bytes returnData;
```

loop function:
```solidity
function aggregate(Call[] memory calls) public onlyOwner returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
            require(success, 'MACF');
            returnData[i] = ret;
        }
    }
```

---

## 61. ERC721L._batchTransferFrom
- file: `b12cdda8b22e2f3420329c0935a3a0e07de7ab7c_INHIBITOR.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: _ownerships
- writes_after: 

state:
```solidity
    bool locked;
    string name;
    string symbol;
    address private _contractOwner;
    address currentOwner;
```

loop function:
```solidity
function _batchTransferFrom (address from, address to, uint256 startID, uint256 quantity, bool safe, bytes memory _data) internal {
        require(isUnlocked(from), "ERC721L: Tokens Locked");
        require(_msgSender() == from || isApprovedForAll(from,_msgSender()), "ERC721L: Not Approved");
        require(multiOwnerCheck(from, startID, quantity), "ERC721L: Not Batchable");
        require(to != address(0), "ERC721L: Address 0");
        unchecked {
            for (uint256 i; i < quantity; i++) {
                uint256 currentToken = startID + i;
                delete _tokenApprovals[currentToken];

                if (i == 0){
                    _ownerships[currentToken] = to;
                } else {
                    delete _ownerships[currentToken];
                }
                emit Transfer(from, to, currentToken);
                if (safe){
                    require(to.code.length == 0 ||
                        ERC721TokenReceiver(to).onERC721Received(_msgSender(), address(0), currentToken, _data) ==
                        ERC721TokenReceiver.onERC721Received.selector, "Unsafe Destination");
                }
            }

            _addressData[from].balance -= uint64(quantity);
            _addressData[to].balance += uint64(quantity);
            uint256 nextTokenId = startID + quantity;
            if (_ownerships[nextTokenId] == address(0) && nextTokenId < _collectionData.index) {
                _ownerships[nextTokenId] = from;
            }
        }
        
    }
```

---

## 62. Auction.refundBidders
- file: `b42A79C03C67C6FAE729F1e8FAf20BBb0192a46F_Auction.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: _bids
- writes_after: 

state:
```solidity
    address payable public immutable beneficiaryAddress;
    bool private _allowWithdrawals;
    bool started;
    bool ended;
```

loop function:
```solidity
function refundBidders(address payable[] calldata bidders) external onlyOwner whenPaused whenAuctionEnded {
    uint256 totalRefundAmount = 0;
    for(uint256 i = 0; i < bidders.length; i++) {
      address payable bidder = bidders[i];
      uint256 refundAmount = _bids[bidder].unitPrice * _bids[bidder].quantity;

      // Skip bidders who aren't entitled to a refund.
      if (refundAmount == 0) {
        continue;
      }

      _bids[bidder] = Bid(0,0);
      (bool success, ) = bidder.call{ value: refundAmount }("");
      require(success, "Transfer failed.");
      totalRefundAmount += refundAmount;
      emit BidderRefunded(bidder, refundAmount);
    }
  }
```

---

## 63. PokeXVerse.royaltyPayout
- file: `b44915849e5fafad12aa519886ef7e8d84442e56_PokeXVerse.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: totalEthRoyaltyPayout

state:
```solidity
    string private _currentBaseURI;
    uint private _reservedMints;
    bool private paused;
    string public unrevealedURI;
    uint public amountOfTokensGotPayout;
    address public pledgeContract;
```

loop function:
```solidity
function royaltyPayout(uint number, uint256 payout) public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > number * payout, "Insufficient Funds to pay out Royalties!");
        require(amountOfTokensGotPayout + number <= totalSupply());
        for (uint i; i < number; i++) {
            (bool success, ) = payable(ownerOf(amountOfTokensGotPayout + i)).call{value: payout}("");
            require(success, "Address: unable to send value, recipient may have reverted");
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

---

## 64. ForgottenRunes.withdrawAll
- file: `B7cd561bCFA998700EBa50b18F765bB92553426F_ForgottenRunes.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: percentage
- writes_after: 

state:
```solidity
    address account;
    Phase private _phase;
    WithdrawalAddress[] public withdrawalAddresses;
    string private baseTokenURI;
    string private baseContractURI;
```

loop function:
```solidity
function withdrawAll() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert Errors.NothingToWithdraw();

        uint256 length = withdrawalAddresses.length;
        for (uint256 i; i < length; ) {
            uint256 percentage = withdrawalAddresses[i].percentage;
            address withdrawalAddress = withdrawalAddresses[i].account;
            uint256 value = (balance * percentage) / 100;

            (withdrawalAddress.call{value: value}(""));

            unchecked {
                ++i;
            }
        }

        balance = address(this).balance;
        if (balance > 0) {
            (withdrawalAddresses[0].account.call{value: balance}(""));
        }
    }
```

---

## 65. Withdrawable.withdraw
- file: `b753688FC4Ba3c4E65e7C4577C2C8590cB217435_MogulERC1155Mintable.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: weight
- writes_after: 

state:
```solidity
    Payee[] payees;
```

loop function:
```solidity
function withdraw(address _paymentToken) external onlyAdmin {
        uint256 balance = address(this).balance;

        if (_paymentToken != address(0)) {
            balance = IERC20(_paymentToken).balanceOf(address(this));
        }

        for (uint256 j = 0; j < payees.length; j++) {
            uint256 weight = (balance * payees[j].weight).div(totalWeight);
            if (_paymentToken == address(0)) {
                (bool success, ) = payable(payees[j].destination).call{
                    value: weight
                }("");
                require(success, "Payment failure");
            } else {
                IERC20(_paymentToken).safeTransfer(
                    payees[j].destination,
                    weight
                );
            }
        }
    }
```

---

## 66. GiftContractV2._execute
- file: `bCb7Bb7cb2b6881086616E1d22F18F1D7332bC41_GiftContractV2.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: _giftSupply|giftList

state:
```solidity
    bool private _initialized;
    address public nftToken;
    address public tokenPool;
    address to;
    bytes data;
    bool executed;
    Txn[] public txns;
```

loop function:
```solidity
function _execute(uint256 _txIndex) internal {
        Txn storage transaction = txns[_txIndex];
        uint256[] memory amounts = transaction.amounts;
        IMembershipNFT nftContract = IMembershipNFT(nftToken);

        require(transaction.confirms >= confirmsRequired, "cannot execute tx");

        transaction.executed = true;
        for (uint8 i = 0; i < amounts.length; i++) {
            uint256 giftTierSupply = _giftSupply[i];
            uint256 startId = nftContract.tierStartId(i);
            for (uint256 j = 0; j < amounts[i]; j++) {
                (bool success, ) = address(nftToken).call(
                    abi.encodeWithSignature(
                        "safeTransferFrom(address,address,uint256)",
                        tokenPool,
                        transaction.to,
                        startId + giftTierSupply + j
                    )
                );
                require(success, "tx failed");
            }
            _giftSupply[i] += amounts[i];
            giftList[transaction.to][i] += amounts[i];
        }
    }
```

---

## 67. CapsuleMachine.winnerClaimPrize
- file: `bca54cc6ae92ea3f260e373451a2bf4a924966ab_CapsuleMachine.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: isNFTinCapsule

state:
```solidity
    VRFCoordinatorV2Interface COORDINATOR;
    address s_owner;
    Capsule[] public allCapsules;
    bool ended;
    address host;
    address nftAddr;
    address winner;
    Capsule memory c;
```

loop function:
```solidity
function winnerClaimPrize() external {
        uint256[] memory wonCapsules = winnerToCapsules[msg.sender];
        require(wonCapsules.length > 0, "No capsules can be claimed.");

        for (uint256 i = 0; i < wonCapsules.length; i++) {
            uint _capId = wonCapsules[i];
            Capsule storage c = allCapsules[_capId];
            if (c.winner == msg.sender && c.ended != true) { // if not yet claimed
                // transfer nft
                IERC721 _thisNft = IERC721(c.nftAddr);
                _thisNft.transferFrom(address(this), msg.sender, c.nftId);

                // transfer fund
                uint256 commission = c.betPool * (capsuleCommission/1000);
                uint256 transferAmt = c.betPool - commission;
                (bool success1, ) = (address(c.host)).call{value: transferAmt }("");
                require(success1, "transfer failed.");
                (bool success2, ) = owner().call{value: commission }("");
                require(success2, "transfer failed.");

                c.ended = true; 
                c.betPool = 0;
                isNFTinCapsule[c.nftAddr][c.nftId] = false;

                finishedCapsuleIDs.push(_capId);
                numOfFinishedCapsules++;
            }
        }
    }
```

---

## 68. Squid.payoutAll
- file: `bd60a99742b114f11bF6BB7DcE12222bfe9e0aD1_Factory.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: last_withdrawl|total_released
- writes_after: 

state:
```solidity
    address factory;
    address creator;
    string name;
    string description;
    bool locked;
    uint fee;
```

loop function:
```solidity
function payoutAll() external {

        require(msg.sender == factory, 'Error: 1012');
        require(address(this).balance > 0, 'Error: 1009');
        require(!locked, "Error: 1015");

        for(uint i = 0; i < payees.length; i++) {

            address payee = payees[i];

            if(shareholders[payee] == 0) { continue; }

            uint bal = getUserBalance(payee);
            if(bal > 0) {
                // Track Data
                total_released[payee] += bal;
                last_withdrawl[payee] = block.timestamp;

                // Pay
                (bool success, bytes memory data) = payable(payee).call{value: bal}("");
                require(success, "Failed to send");
            }
        }
    }
```

---

## 69. PledgeMint.refundAll
- file: `bddbbb395175f4f4b3ed97514189f765c3598c68_PledgeMint.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: depositAmount|pledgesAmount|totalMinted

state:
```solidity
    IERC721Pledge public nftContract;
```

loop function:
```solidity
function refundAll() public onlyOwner {
        for (uint256 i = 0; i < pledgers.length; i++) {
            address pledger = pledgers[i];

            if(depositAmount[pledger] > 0){
                (bool success, ) = pledger.call{value: depositAmount[pledger]}("");
                require(success, "Address: unable to send value, recipient may have reverted");
                totalMinted = totalMinted - pledgesAmount[pledger];
                depositAmount[pledger] = 0;
                pledgesAmount[pledger] = 0;
            }
        }
    }
```

---

## 70. AuctionHouse.settleBidder
- file: `Be8E1c3D8BEaDA56f2AC567E93B252ADFb4Ae40d_AuctionHouse.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: minted|refunded

state:
```solidity
    WildNFT public nft;
    Bid memory new_bid;
```

loop function:
```solidity
function settleBidder(address[] memory _bidders) external onlyOwner nonReentrant {
        require(block.timestamp > auctionEndDateTime, "Auction hasn't ended.");
        require(auctionWinnersSet == true && raffleWinnersSet == true, "Auction winners not set");

        for (uint256 i = 0; i < _bidders.length; i++) {
            if (Bids[_bidders[i]].winner == true && Bids[_bidders[i]].minted == false && Bids[_bidders[i]].refunded == false) {
                // if winner, mint and refunde diff if any, update Bids
                uint256 difference = Bids[_bidders[i]].amount - Bids[_bidders[i]].finalprice;
                if (difference > 0) {
                    (bool success, ) = _bidders[i].call{value: difference}("");
                    require(success, "Failed to refund difference to winner.");
                }
                nft.mint(_bidders[i]);
                Bids[_bidders[i]].minted = true;
                Bids[_bidders[i]].refunded = true;
            } 
            else if (Bids[_bidders[i]].winner == false && Bids[_bidders[i]].refunded == false) {
                // if not winner, refund
                (bool success, ) = _bidders[i].call{value: Bids[_bidders[i]].amount}("");
                require(success, "Failed to send refund to loser.");
                Bids[_bidders[i]].refunded = true;
            }
        }

    }
```

---

## 71. RelayAdapt.transfer
- file: `c3f2C8F9d5F0705De706b1302B7a039e1e11aC88_RelayAdapt.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: token

state:
```solidity
    address to;
    bytes data;
    TokenData token;
    address to;
    RailgunSmartWallet public railgun;
    IWBase public wBase;
```

loop function:
```solidity
function transfer(TokenTransfer[] calldata _transfers) external onlySelfIfExecuting {
    for (uint256 i = 0; i < _transfers.length; i += 1) {
      if (
        _transfers[i].token.tokenType == TokenType.ERC20 &&
        _transfers[i].token.tokenAddress == address(0)
      ) {
        // BASE
        // Fetch balance
        uint256 amount = _transfers[i].value == 0 ? address(this).balance : _transfers[i].value;

        // Transfer base tokens
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = _transfers[i].to.call{ value: amount }("");

        // Check transfer succeeded
        require(success, "RelayAdapt: ETH transfer failed");
      } else if (_transfers[i].token.tokenType == TokenType.ERC20) {
        // ERC20
        IERC20 token = IERC20(_transfers[i].token.tokenAddress);

        // Fetch balance
        uint256 amount = _transfers[i].value == 0
          ? token.balanceOf(address(this))
          : _transfers[i].value;

        // Transfer token
        token.safeTransfer(_transfers[i].to, amount);
      } else if (_transfers[i].token.tokenType == TokenType.ERC721) {
        // ERC721 token
        IERC721 token = IERC721(_transfers[i].token.tokenAddress);

        // Transfer token
        token.transferFrom(address(this), _transfers[i].to, _transfers[i].token.tokenSubID);
      } else {
        // ERC1155 token
        revert("RelayAdapt: ERC1155 not yet supported");
      }
    }
  }
```

---

## 72. BridgePool.withdraw
- file: `c43Af891fa1d0cD4C7E8B097E4CC9236B3E7a6E6_BridgePool.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: withdrawn
- writes_after: 

state:
```solidity
    address public owner;
```

loop function:
```solidity
function withdraw(Withdraw[] calldata ws) override external nonReentrant() {
        // allowed only 'withdrawer' or 'withdrawer' through 'contract:withdrawer'
        require(operator[msg.sender] == 4 || (operator[tx.origin] == 4 && operator[msg.sender] == 2), 'forbidden');

        for (uint i = 0; i < ws.length; i++) {
            Withdraw memory w = ws[i];

            require(!withdrawn[w.id], 'already withdrawn');
            withdrawn[w.id] = true;

            if (address(w.token) == address(1)) {
                require(address(this).balance >= w.amount + w.bonus, 'too low token balance');
                (bool success, ) = w.recipient.call{value: w.amount}('');
                require(success, 'native transfer error');
            } else {
                require(
                    w.token.balanceOf(address(this)) >= w.amount && address(this).balance >= w.bonus,
                    'too low token balance'
                );
                safeTransfer(w.token, w.recipient, w.amount);
            }

            if (w.bonus > 0) {
                // may fail on contracts
                w.recipient.call{value: w.bonus}('');
            }

            if (address(w.token) != address(1) && w.feeAmounts.length > 0) {
                for (uint j = 0; j < w.feeAmounts.length; j++) {
                    require(w.token.balanceOf(address(this)) >= w.feeAmounts[i], 'too low token balance');
                    safeTransfer(w.token, w.feeTargets[i], w.feeAmounts[i]);
                }
            }

            emit Withdrawn(w.id, address(w.token), w.recipient, w.amount);
        }
    }
```

---

## 73. AutomatedExternalReflector.snapshot
- file: `C7a8B915C44549419038501837FcE3faEb437927_DynaAutoEthDistributorV2.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: dynaHodler

state:
```solidity
    bool exists;
    bool public snapshotPending;
    IUniswapV2Router02 public uniswapV2Router;
    ISupportingExternalReflection public tokenContract;
```

loop function:
```solidity
function snapshot() private returns (uint256){
        uint256 stopProcessingAt = currentQueueIndex.add(maxReflectionsPerRound);
        uint256 queueLength = queue.length;
        uint256 startingGas = gasleft();
        uint256 endGas = 0;
        uint256 queueStart = currentQueueIndex;
        uint256 gasLeft = startingGas;
        if(startingGas > maxGas){
            endGas = startingGas.sub(maxGas);
        } else {
            endGas = minGas;
        }
        uint256 minGasIncReturns = minGas.div(2).add(minGas);
        IERC20 controllingToken = IERC20(address(tokenContract));
        uint256 excludedTokensSnapshotted;
        if(currentQueueIndex == 0){
            excludedTokensSnapshotted = 0;
        } else {
            excludedTokensSnapshotted = totalExcludedTokenHoldings;
        }
        while(gasLeft > minGasIncReturns && gasLeft > endGas && currentQueueIndex < stopProcessingAt && currentQueueIndex < queueLength){
            address payable user = queue[currentQueueIndex];

            (bool success, bytes memory data) = address(controllingToken).call(abi.encodeWithSignature("balanceOf(address)",user));
            if(success){
                uint256 bal = abi.decode(data, (uint256));
                dynaHodler[user][currentRound] = User({
                    tokenBalance: bal,
                    totalPayouts: dynaHodler[user][currentRound-1].totalPayouts,
                    pendingPayouts: dynaHodler[user][currentRound-1].pendingPayouts,
                    exists: true,
                    lastPayoutRound: dynaHodler[user][currentRound-1].lastPayoutRound
                });

                dynaHodler[user][currentRound+1] = dynaHodler[user][currentRound];

                if(isExcludedFromReflections[queue[currentQueueIndex]]){
                    excludedTokensSnapshotted = excludedTokensSnapshotted.add(bal);
                }
            }
            currentQueueIndex++;
            gasLeft = gasleft();
        }
        emit RoundSnapshotTaken(currentQueueIndex.sub(queueStart));

        rewardInstigator(currentQueueIndex.sub(queueStart));

        if(currentQueueIndex >= queueLength){
            currentQueueIndex = 0;
            snapshotPending = false;
        }
        return excludedTokensSnapshotted;
    }
```

---

## 74. BoundlessAdapter._call
- file: `C8751601c2897e7e0AE498288f2E7644AcC1Ce67_BoundlessAdapter.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: outputToken
- writes_after: 

state:
```solidity
    IGatewayRegistry public registry;
    Lender public lender;
    CatalogAdapter public catalogAdapter;
    address contractAddress;
    bytes data;
    address outputToken;
```

loop function:
```solidity
function _call(
        address inputToken,
        uint256 inputAmount,
        address payable fallbackRecipient,
        ContractCallParams[] calldata contractCalls
    ) private {
        for (uint256 i = 0; i < contractCalls.length; i++) {
            require(
                allowedContracts[contractCalls[i].contractAddress],
                "BoundlessAdapter: unapproved contract call"
            );

            address outputToken = contractCalls[i].outputToken;

            uint256 value = inputToken == FEE_CURRENCY ? inputAmount : 0;

            uint256 outputTokenBalanceBefore = 0;
            if (outputToken != address(0x0)) {
                outputTokenBalanceBefore = outputToken == FEE_CURRENCY
                    ? address(this).balance
                    : IERC20(outputToken).balanceOf(address(this));
                if (inputToken == outputToken) {
                    outputTokenBalanceBefore =
                        outputTokenBalanceBefore -
                        inputAmount;
                }
            }

            if (inputToken != address(0x0) && inputToken != FEE_CURRENCY) {
                IERC20(inputToken).safeApprove(
                    contractCalls[i].contractAddress,
                    inputAmount
                );
            }

            (bool success, bytes memory returnData) = contractCalls[i]
                .contractAddress
                .call{gas: gasleft() - 3000, value: value}(
                contractCalls[i].data
            );
            if (!success) {
                if (returnData.length < 68) {
                    revert("BoundlessAdapter: Internal contract call reverted");
                }

                // revert(string(returnData));
                assembly {
                    revert(add(returnData, 32), returnData)
                }
            }

            if (
                address(inputToken) != address(0x0) &&
                inputToken != FEE_CURRENCY
            ) {
                uint256 approvalRemaining = IERC20(inputToken).allowance(
                    address(this),
                    contractCalls[i].contractAddress
                );
                if (approvalRemaining > 0) {
    ... [42 more lines]
```

---

## 75. QuasarFighterAuctionHouse.settleBidder
- file: `c9e52053ecb84d02d831cac03baf52d8cc85cfcf_QuasarFighterAuctionHouse.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: minted|refunded

state:
```solidity
    Bid memory new_bid;
```

loop function:
```solidity
function settleBidder(address[] memory _bidders) external onlyOwner nonReentrant {
        require(block.timestamp > auctionEndDateTime, "Auction hasn't ended.");
        require(auctionWinnersSet == true && raffleWinnersSet == true, "Auction winners not set");
        //require(auctionSettled == false, "Auction already settled");

        for (uint256 i = 0; i < _bidders.length; i++) {
            if (Bids[_bidders[i]].winner == true && Bids[_bidders[i]].minted == false && Bids[_bidders[i]].refunded == false) {
                // if winner, mint and refunde diff if any, update Bids
                uint256 difference = Bids[_bidders[i]].amount - Bids[_bidders[i]].finalprice;
                if (difference > 0) {
                    (bool success, ) = _bidders[i].call{value: difference}("");
                    require(success, "Failed to refund difference to winner.");
                }
                quasarfighter.mint(_bidders[i]);
                //auctionSupply--;
                Bids[_bidders[i]].minted = true;
                Bids[_bidders[i]].refunded = true;
            } 
            else if (Bids[_bidders[i]].winner == false && Bids[_bidders[i]].refunded == false) {
                // if not winner, refund
                (bool success, ) = _bidders[i].call{value: Bids[_bidders[i]].amount}("");
                require(success, "Failed to send refund to loser.");
                Bids[_bidders[i]].refunded = true;
            }
        }

    }
```

---

## 76. VLyCRV._vote
- file: `CCBD4579495cD78280e4900CB482C8Edf2EC8336_VLyCRV.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: idToGauge|lastGaugeId

state:
```solidity
    address voteDelegate;
    bool public lockDismissed;
    address public pendingGovernance;
    uint _virtualvoteslength;
    uint current;
```

loop function:
```solidity
function _vote(
        address _user,
        address[] memory _gauges,
        uint96[] memory _numVotes
    ) internal {
        _updatePeriod();
        UserInfo storage ui = userInfo[_user]; //storage pointer
        uint128 votesLeft = ui.balance;
        if (ui.lastVoteTime >= currentPeriod) {
            require(votesLeft > ui.votesSpent, "vl-yCRV:Amount Exceeds votesLeft");
            unchecked {
                votesLeft = votesLeft - ui.votesSpent;
            }
        }

        for (uint i = 0; i < _gauges.length;) {
            require(_gauges[i] != address(0), "vl-yCRV:Voted For 0 Address");
            require(_numVotes[i] > 0, "vl-yCRV:Voted Zero");
            require(_numVotes[i] <= votesLeft, "vl-yCRV:Too Many Votes");

            uint16 gaugeId = uint16(gaugeToId[_gauges[i]]);
            if (gaugeId == 0) {
                //only external call if pointer doesnt exist
                bytes memory data = abi.encodeWithSignature(
                    "gauge_types(address)",
                    _gauges[i]
                );
                (bool success, ) = CONTROLLER.call(data);
                require(success, "vl-yCRV:Gauge Does Not Exist");

                gaugeId = uint16(lastGaugeId + 1);
                lastGaugeId = gaugeId;
                idToGauge[gaugeId] = _gauges[i];
                gaugeToId[_gauges[i]] = gaugeId;
            }

            unchecked { //require statement assures votesLeft >= _numVotes[i]
                votesLeft = votesLeft - _numVotes[i];
            }

            _insert(gaugeId, uint48(_numVotes[i] / 1e15));
            emit Vote(_user, _gauges[i], currentPeriod, _numVotes[i]);

            unchecked {
                i = i + 1;
            }
        }

        ui.lastVoteTime = uint40(block.timestamp);
        ui.unlockTime = uint40(nextPeriod() + 14 days);
        ui.votesSpent = ui.balance - votesLeft;
    }
```

---

## 77. NamasteyNft.setProps
- file: `d130cd469d8c7689288a175598b78646a3c62f98_NamasteyNft.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: collectibles|creator|tokenIdToCollectible
- writes_after: 

state:
```solidity
    address public treasury;
    string public notRevealedUri;
    string public collectionUri;
    address creator;
    string uri;
    string category;
```

loop function:
```solidity
function setProps(string memory _category, uint256 _quantity, uint256 start) internal{
        
        
        uint256 value = price - price*treasuryPercentage/uint256(100);
         uint index = collectibles[_category].length - categoryToAvailability[_category];
        for(uint i = 0; i < _quantity; ++i){
            collectibles[_category][index+i].tokenId = start + i;
            tokenIdToCollectible[start+i] =collectibles[_category][index+i];
            address creator = collectibles[_category][index+i].creator;
            (bool res,) = payable(creator).call{value: value}("");
            require(res, "Failed to send Ether");

        }
        categoryToAvailability[_category] -= _quantity;
    }
```

---

## 78. GINE.mint
- file: `d248817f3db9a635c5c55e704503962fd4cd041d_GINE.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: minthasrun
- writes_after: minthasrun

state:
```solidity
    string baseURI;
    string public notRevealedUri;
```

loop function:
```solidity
function mint(uint256 _mintAmount) public payable {
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

     // Wait...  is he really doing this ??
        uint256 _currenttokenid = supply + i;
        if (_currenttokenid % 11 == 0) {
            // console.log("woop woop this NFT number " + _currenttokenid + " is an 11th NFT, therefor it is FREE");
          
            // double check there is no attempt to send back more than was originally send in
            if (cost <= msg.value){
             minthasrun = true;
             // you really going to re-entrancy on my first contact ?
             (bool success, ) = payable(msg.sender).call{value: cost}("");
              minthasrun = false;
              // send back the Unit cost in eth to msg.sender
              require(success, "Failed to return Ether");
             }

         }
    }
  }
```

---

## 79. BoundlessAdapter._call
- file: `d5273549BEc89734cf31360fa8a64be2ef905bA6_BoundlessAdapter.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: outputToken
- writes_after: 

state:
```solidity
    IGatewayRegistry public registry;
    Lender public lender;
    CatalogAdapter public catalogAdapter;
    address contractAddress;
    bytes data;
    address outputToken;
```

loop function:
```solidity
function _call(
        address inputToken,
        uint256 inputAmount,
        address payable fallbackRecipient,
        ContractCallParams[] calldata contractCalls
    ) private {
        for (uint256 i = 0; i < contractCalls.length; i++) {
            require(
                allowedContracts[contractCalls[i].contractAddress],
                "BoundlessAdapter: unapproved contract call"
            );

            address outputToken = contractCalls[i].outputToken;

            uint256 value = inputToken == FEE_CURRENCY ? inputAmount : 0;

            uint256 outputTokenBalanceBefore = 0;
            if (outputToken != address(0x0)) {
                outputTokenBalanceBefore = outputToken == FEE_CURRENCY
                    ? address(this).balance
                    : IERC20(outputToken).balanceOf(address(this));
                if (inputToken == outputToken) {
                    outputTokenBalanceBefore =
                        outputTokenBalanceBefore -
                        inputAmount;
                }
            }

            if (inputToken != address(0x0) && inputToken != FEE_CURRENCY) {
                IERC20(inputToken).approve(
                    contractCalls[i].contractAddress,
                    inputAmount
                );
            }

            (bool success, bytes memory returnData) = contractCalls[i]
                .contractAddress
                .call{gas: gasleft() - 3000, value: value}(
                contractCalls[i].data
            );
            if (!success) {
                if (returnData.length < 68) {
                    revert("BoundlessAdapter: Internal contract call reverted");
                }

                // revert(string(returnData));
                assembly {
                    revert(add(returnData, 32), returnData)
                }
            }

            if (
                address(inputToken) != address(0x0) &&
                inputToken != FEE_CURRENCY
            ) {
                uint256 approvalRemaining = IERC20(inputToken).allowance(
                    address(this),
                    contractCalls[i].contractAddress
                );
                if (approvalRemaining > 0) {
    ... [42 more lines]
```

---

## 80. LDDFrensVault.vaultIn
- file: `d5a02361fc5d655f3265527ff3960b5888037168_LDDFrensVault.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: total
- writes_after: 

state:
```solidity
    ERC721A collection;
    bool public paused;
    address owner;
    address owner;
```

loop function:
```solidity
function vaultIn(uint256[] calldata tokenIds) external whenNotPaused {
        require(
            address(this).balance >= tokenIds.length * reward,
            "insufficient balance"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                collection.ownerOf(tokenIds[i]) == msg.sender,
                "not the token owner"
            );
            require(
                vault[tokenIds[i]].owner == address(0),
                "already in the vault"
            );
            require(
                tokenIds[i] >= fromTokenId && tokenIds[i] <= toTokenId,
                "invalid token id"
            );

            collection.safeTransferFrom(msg.sender, address(this), tokenIds[i]);

            vault[tokenIds[i]] = Token({
                tokenId: tokenIds[i],
                vaultInAt: block.timestamp,
                expiredAt: block.timestamp + timeLimit,
                owner: msg.sender
            });

            total += 1;
            (bool sent, ) = msg.sender.call{value: reward}("sent");
            require(sent, "failed to transfer reward");

            emit VaultIn(
                msg.sender,
                tokenIds[i],
                block.timestamp,
                block.timestamp + timeLimit,
                reward
            );
        }
    }
```

---

## 81. Marketplace._takePayment
- file: `d81da98958e44f43edcc8a3c658791429dac6611_Marketplace.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: amount
- writes_after: 

state:
```solidity
    address currencyAddress;
    address receiver;
    address contractAddress;
    PaymentInfo[] paymentInfo;
    Royalties[] royalties;
    PaymentInfo[] paymentInfo;
    Royalties[] royalties;
    address contractAddress;
    PaymentInfo[] paymentInfo;
    Royalties[] royalties;
    bool isERC1155;
    address owner;
    address contractAddress;
    address currencyAddress;
    PaymentInfo[] paymentInfo;
    Royalties[] royalties;
    bool isERC1155;
    address contractAddress;
    bool isERC1155;
    address xp;
    ... [6 more lines]
```

loop function:
```solidity
function _takePayment(
        address contractAddress,
        address currency,
        uint256 amount,
        Royalties[] storage royalties
    ) internal {
        uint256 commission = (amount * treasryCommission) / 10000;
        amount = amount - commission;
        Royalties[] storage sRoyalties = secondaryRoyalties[contractAddress];

        if (currency == address(0)) {
            if (msg.value < amount) {
                revert OdysseyMarket_InsufficientFunds();
            }

            (bool success, ) = treasury.call{value: commission}("");
            if (!success) {
                revert OdysseyMarket_FailedToPayEther();
            }

            uint256 sAmount;
            for (uint256 n; n < sRoyalties.length; ++n) {
                sAmount = (amount * sRoyalties[n].percent) / 100;
                amount -= sAmount;
                (success, ) = sRoyalties[n].receiver.call{value: sAmount}("");
                if (!success) {
                    revert OdysseyMarket_FailedToPayEther();
                }
            }

            // Sale Royalties
            for (uint256 i; i < royalties.length; ++i) {
                commission = (amount * royalties[i].percent) / 100;
                (success, ) = royalties[i].receiver.call{value: commission}("");
                if (!success) {
                    revert OdysseyMarket_FailedToPayEther();
                }
            }
        } else {
            bool result = ERC20(currency).transferFrom(
                msg.sender,
                treasury,
                commission
            );
            if (!result) {
                revert OdysseyMarket_FailedToPayERC20();
            }

            uint256 sAmount;
            for (uint256 n; n < sRoyalties.length; ++n) {
                sAmount = (amount * sRoyalties[n].percent) / 100;
                amount -= sAmount;
                result = ERC20(currency).transferFrom(
                    msg.sender,
                    sRoyalties[n].receiver,
                    sAmount
                );
                if (!result) {
                    revert OdysseyMarket_FailedToPayERC20();
                }
    ... [15 more lines]
```

---

## 82. RoyaltyWallet.withdraw
- file: `D9dfb761136a68cdA0a2032C3d7157D8576F379C_RoyaltyWallet.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: account|share
- writes_after: 

state:
```solidity
    address account;
    Split[] public splits;
```

loop function:
```solidity
function withdraw() public {
        uint256 balance = address(this).balance;
        for (uint256 i = 0; i < splits.length; i++) {
            address payable account = payable(splits[i].account);
            uint16 share = splits[i].share;

            (bool sent, ) = account.call{value: (balance * share) / 10000}("");
            require(sent, "Something went wrong during the withdrawal");
        }
    }
```

---

## 83. CryptoPomelClub.mint
- file: `e625dD5fA57D87CE5370321FA2c859370b8BB7C7_CryptoPomelClub.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: shareHolders
- writes_after: 

state:
```solidity
    string public hiddenMetadataUri;
    address walletAddress;
    address latestOwnerAddress;
```

loop function:
```solidity
function mint(uint256 _mintAmount) public payable mintCompliance(_mintAmount) mintPriceCompliance(_mintAmount) {
    require(!paused, 'The contract is paused!');

    _safeMint(_msgSender(), _mintAmount);
    if (whitelistMintEnabled == false) {
      for(uint256 i = 0; i < ShareHolderCount; i++) {
        shareHolders[i].revenue = (shareHolders[i].revenue + cost * _mintAmount) / 100 * 6 / 20;
        (bool os, ) = payable(shareHolders[i].walletAddress).call { value: (cost * _mintAmount) / 100 * 6 / 20 }('');
        require(os);
      }
    }
    
  }
```

---

## 84. MasterOh._multiClaim
- file: `e9eb6367deB53cd188E79122a2F9275b8f156712_MasterOh.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: rewarder
- writes_after: 

state:
```solidity
    IRewarder rewarder;
    IERC20 public oh;
    IVeOh public veOh;
    IMasterOh newMasterOh;
    PoolInfo[] public poolInfo;
```

loop function:
```solidity
function _multiClaim(uint256[] memory _pids)
        private
        returns (
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {
        // accumulate rewards for each one of the pids in pending
        uint256 pending;
        uint256[] memory amounts = new uint256[](_pids.length);
        uint256[] memory additionalRewards = new uint256[](_pids.length);
        for (uint256 i = 0; i < _pids.length; ++i) {
            _updatePool(_pids[i]);
            PoolInfo storage pool = poolInfo[_pids[i]];
            UserInfo storage user = userInfo[_pids[i]][msg.sender];
            if (user.amount > 0) {
                // increase pending to send all rewards once
                uint256 poolRewards = ((user.amount * pool.accOhPerShare + user.factor * pool.accOhPerFactorShare) / 1e12) +
                    claimableOh[_pids[i]][msg.sender] -
                    user.rewardDebt;

                claimableOh[_pids[i]][msg.sender] = 0;

                // update reward debt
                user.rewardDebt = (user.amount * pool.accOhPerShare + user.factor * pool.accOhPerFactorShare) / 1e12;

                // increase pending
                pending += poolRewards;

                amounts[i] = poolRewards;
                // if existant, get external rewarder rewards for pool
                IRewarder rewarder = pool.rewarder;
                if (address(rewarder) != address(0)) {
                    additionalRewards[i] = rewarder.onReward(msg.sender, user.amount);
                }
            }
        }
        // transfer all remaining rewards
        uint256 transfered = safeOhTransfer(payable(msg.sender), pending);
        if (transfered != pending) {
            for (uint256 i = 0; i < _pids.length; ++i) {
                amounts[i] = (transfered * amounts[i]) / pending;
                emit Harvest(msg.sender, _pids[i], amounts[i]);
            }
        } else {
            for (uint256 i = 0; i < _pids.length; ++i) {
                // emit event for pool
                emit Harvest(msg.sender, _pids[i], amounts[i]);
            }
        }

        return (transfered, amounts, additionalRewards);
    }
```

---

## 85. BlockStarLPStaking.distributeReward
- file: `eb177f17bC58bc540afbeA5dd60114d98c285Dba_BlockStarLPStaking.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: PooltotalRewardsDistribution|PooltotalRewardsDistributionById|claimedReward|totalRewardsDistribution
- writes_after: 

state:
```solidity
    address poolAddress;
    bool status;
    string token0img;
    string token1img;
    address poolAddress;
    address beneficiary;
    bool claimed;
    bool public started;
    bool public withdrawStarted;
```

loop function:
```solidity
function distributeReward(address _poolAddress , uint256 _id) public onlyOwner nonReentrant{
        PoolInfo storage pool = pooldata[_poolAddress][_id];
        require(pool.lockupDuration > 0 && pool.startTime > 0 && pool.poolAddress != address(0) , "Pool data not found or pool not added with Id!!");
        require(pool.totalReward > 0 , "Pool Reward set Zero !!!");
        require(pool.totalReward <= address(this).balance , "Contract doesn't have enough fund for reward !!");
        uint256 endTime =  pool.startTime.add(pool.lockupDuration.mul(baseTime));
        require(endTime <= block.timestamp , "It's not time to distributeReward , pool still on going!!");
        (uint256 [] memory percentage_Arr,address [] memory user_Adderss, uint256 [] memory total_Reward, uint256 [] memory order_Ids , uint256 extra_Amount) = _calculateReward(_poolAddress,_id);

        for(uint i=0; i < order_Ids.length ; i++){
            uint256 extraReward = extra_Amount.mul(percentage_Arr[i]).div(10000);
            uint256 userReward = total_Reward[i].add(extraReward);

            orders[order_Ids[i]].claimedReward = userReward;
            
            
            PooltotalRewardsDistributionById[_poolAddress][_id] += userReward;
            PooltotalRewardsDistribution[_poolAddress] += userReward;
            userPoolTotalReward[user_Adderss[i]][_poolAddress] += userReward;
            userPoolTotalRewardWithId[user_Adderss[i]][_poolAddress][_id] += userReward;
            totalRewardsDistribution += userReward;
            
            emit RewardDistribute(_poolAddress , _id , user_Adderss[i] , userReward  );
             (bool success, ) = user_Adderss[i].call{value: userReward}("");
             require(success, "reward transfer failed!!");
        }

        pooldata[_poolAddress][_id].startTime = block.timestamp;
        pooldata[_poolAddress][_id].endTime = block.timestamp.add(pool.lockupDuration.mul(baseTime));

    }
```

---

## 86. Multicall2_1.aggregate
- file: `f49095eD53F312C30b13ef1a06877a8A17f27d8D_Multicall2_1.sol`
- pragma: 0.8 | shape: effect_after_call
- writes_before: 
- writes_after: returnData

state:
```solidity
    address target;
    bytes callData;
    bool success;
    bytes returnData;
```

loop function:
```solidity
function aggregate(Call[] memory calls) public returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for(uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
            require(success, "Multicall aggregate: call failed");
            returnData[i] = ret;
        }
    }
```

---

## 87. EtherDisperser.removeBalances
- file: `F59842400Cfb999A075F66eb0C4f10DAC81D8757_EtherDisperser.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: leftToBeClaimed|totalEtherRewarded
- writes_after: 

loop function:
```solidity
function removeBalances(address[] calldata _targets) external onlyOwner {
    require(_targets.length > 0, "EtherDisperser: Targets must be non-empty.");

    for (uint256 i = 0; i < _targets.length; i++) {
      uint256 _balance = balances[_targets[i]];

      totalEtherRewarded -= _balance;
      leftToBeClaimed -= _balance;

      (bool sent, ) = owner().call{value: _balance}("");
      require(sent, "EtherDisperser: Couldn't send ether to you.");

      balances[_targets[i]] = 0;
      emit SetBalance(_targets[i], 0);
    }
  }
```

---

## 88. Auction.partiallyRefundBidders
- file: `F7A9A0dE4811DEAFcDCE83f7c97B32d2516B52Ab_Auction.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: _bids
- writes_after: 

state:
```solidity
    address payable public immutable beneficiaryAddress;
    AuctionStatus private _auctionStatus;
    bool started;
    bool ended;
```

loop function:
```solidity
function partiallyRefundBidders(
    uint256 auctionIndex_,
    address payable[] calldata bidders_,
    uint256[] calldata amounts_
  ) external onlyOwner whenPaused whenAuctionEnded {
    require(
      bidders_.length == amounts_.length,
      "bidders length doesn't match amounts length"
    );

    for (uint256 i = 0; i < bidders_.length; i++) {
      address payable bidder = bidders_[i];
      uint256 refundAmount = amounts_[i];
      bytes32 bidHash = _bidHash(auctionIndex_, bidder);
      uint256 refundMaximum = _bids[bidHash].balance;

      require(
        refundAmount <= refundMaximum,
        "Refund amount is greater than balance"
      );

      // Skip bidders who aren't entitled to a refund.
      if (refundAmount == 0 || refundMaximum == 0) {
        continue;
      }

      _bids[bidHash].balance -= refundAmount;
      (bool success, ) = bidder.call{value: refundAmount}("");
      require(success, "Transfer failed.");
      emit BidderRefunded(auctionIndex_, bidder, refundAmount);
    }
  }
```

---

## 89. RainiNFT1155v2._beforeTokenTransfer
- file: `fB2e0Ef40f552D460098d6D8aC70e6e3eE96f496_RainiNFT1155v2.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: subContract
- writes_after: 

state:
```solidity
    address public nftStakingPoolAddress;
    bool locked;
    address subContract;
    string public baseUri;
    string public contractURIString;
    address private contractOwner;
    bool willCallPool;
    bool willCallSubContract;
    uint len;
```

loop function:
```solidity
function _beforeTokenTransfer(address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data)
    internal virtual override
  {
    for (uint256 i = 0; i < ids.length; i++) {
      TokenVars memory _tokenVars = tokenVars[ids[i]];
      if (cards[_tokenVars.cardId].subContract != address(0)) {
        IRainiCustomNFT subContract = IRainiCustomNFT(cards[_tokenVars.cardId].subContract);
        subContract.onTransfered(from, to, ids[i], amounts[i], data);
      }
    }
  }
```

---

## 90. PledgeMint._refundPhase
- file: `fbffbe6f2e0f4b5d0c3da9b6813d99a4f18fb358_PledgeMint.sol`
- pragma: 0.8 | shape: effect_before_call
- writes_before: pledges
- writes_after: 

state:
```solidity
    address admin;
    IERC721Pledge mintContract;
    bool mintContractLocked;
    bool pledgesLocked;
    PhaseConfig[] public phases;
```

loop function:
```solidity
function _refundPhase(uint16 phaseId) internal {
        PhaseConfig memory _phase = phases[phaseId];
        address[] storage _addresses = pledgers[phaseId];
        for (uint8 i = 0; i < _addresses.length; i++) {
            address addy = _addresses[i];
            uint8 quantity = pledges[phaseId][addy];
            pledges[phaseId][addy] = 0;
            (bool success, ) = addy.call{value: _phase.mintPrice * quantity}("");
            require(success, "Address: unable to send value, recipient may have reverted");
        }
    }
```

---


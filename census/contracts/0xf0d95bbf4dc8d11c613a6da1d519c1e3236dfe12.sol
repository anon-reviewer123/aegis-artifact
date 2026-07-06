// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

import "../interfaces/main/ICyanApeCoinVault.sol";
import "../interfaces/IApeCoinStaking.sol";
import "../interfaces/core/IFactory.sol";
import "../interfaces/core/IWalletApeCoin.sol";
import "../interfaces/main/ICyanApeCoinPlan.sol";
import { ICyanConduit } from "../interfaces/conduit/ICyanConduit.sol";
import { AddressProvider } from "./AddressProvider.sol";

error InvalidSignature();
error InvalidAddress();
error InvalidRate();
error PlanAlreadyExists();
error InvalidBlockNumber();
error LoanAmountExceedsPoolCap();

/// @title Cyan Payment Plan - Main logic of loaning and staking ApeCoin
/// @author Bulgantamir Gankhuyag - <bulgaa@usecyan.com>
/// @author Naranbayar Uuganbayar - <naba@usecyan.com>
contract CyanApeCoinPlan is AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    AddressProvider private constant addressProvider = AddressProvider(0xCF9A19D879769aDaE5e4f31503AAECDa82568E55);

    using ECDSAUpgradeable for bytes32;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event AutoCompounded();
    event CreatedPlan(uint256 indexed planId);
    event Completed(uint256 indexed planId);
    event UpdatedCyanSigner(address indexed signer);
    event UpdatedWalletFactory(address indexed factory);
    event ClaimedServiceFee(uint256 indexed amount);
    event UpdatedServiceFeeRate(uint256 indexed serviceFeeRate);

    mapping(uint256 => ICyanApeCoinPlan.PaymentPlan) public paymentPlan;
    uint256 public claimableServiceFee;
    uint256 public serviceFeeRate;

    bytes32 public constant CYAN_ROLE = keccak256("CYAN_ROLE");
    address private cyanSigner;
    address private walletFactory;

    // ApeStakingPool ids
    uint256 public constant APECOIN_POOL_ID = 0;
    uint256 public constant BAYC_POOL_ID = 1;
    uint256 public constant MAYC_POOL_ID = 2;
    uint256 public constant BAKC_POOL_ID = 3;

    ICyanApeCoinVault public cyanApeCoinVault;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        uint256 _serviceFeeRate,
        address _cyanSigner,
        address _cyanSuperAdmin,
        address _walletFactory,
        address _cyanApeCoinVaultAddress
    ) external initializer {
        if (
            _cyanSigner == address(0) ||
            _cyanSuperAdmin == address(0) ||
            _walletFactory == address(0) ||
            _cyanApeCoinVaultAddress == address(0)
        ) {
            revert InvalidAddress();
        }

        if (_serviceFeeRate > 10000) {
            revert InvalidRate();
        }

        serviceFeeRate = _serviceFeeRate;
        cyanSigner = _cyanSigner;
        walletFactory = _walletFactory;
        cyanApeCoinVault = ICyanApeCoinVault(_cyanApeCoinVaultAddress);

        getApeCoin().approve(_cyanApeCoinVaultAddress, type(uint256).max);
        getApeCoin().approve(address(getApeStaking()), type(uint256).max);

        _setupRole(DEFAULT_ADMIN_ROLE, _cyanSuperAdmin);

        __AccessControl_init();
        __ReentrancyGuard_init();

        emit UpdatedServiceFeeRate(_serviceFeeRate);
        emit UpdatedCyanSigner(_cyanSigner);
        emit UpdatedWalletFactory(_walletFactory);
    }

    function getPoolCap(uint256 poolId) private view returns (uint96) {
        IApeCoinStaking apeStaking = getApeStaking();
        uint16 lastRewardsRangeIndex = apeStaking.pools(poolId).lastRewardsRangeIndex;
        return apeStaking.getTimeRangeBy(poolId, lastRewardsRangeIndex).capPerPosition;
    }

    function calculateNumbers(ICyanApeCoinPlan.PaymentPlan memory plan, uint256 interestRate)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        IApeCoinStaking apeStaking = getApeStaking();
        uint256 stakedAmount = apeStaking.nftPosition(plan.poolId, plan.tokenId).stakedAmount;
        uint256 rewards = apeStaking.pendingRewards(plan.poolId, plan.cyanWalletAddress, plan.tokenId);

        uint256 interestFee = ((plan.loanedAmount * rewards * interestRate) / stakedAmount) / 10000;
        uint256 serviceFee = (rewards * serviceFeeRate) / 10000;

        rewards -= (interestFee + serviceFee);

        return (rewards, interestFee, serviceFee, stakedAmount);
    }

    function calculateApeCoinPoolNumbers(address cyanWalletAddress)
        private
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        IApeCoinStaking.DashboardStake memory dashboard = getApeStaking().getApeCoinStake(cyanWalletAddress);
        return (dashboard.deposited, dashboard.unclaimed, (dashboard.unclaimed * serviceFeeRate) / 10000);
    }

    /**
     * @notice Creating Ape coin staking plan with BAYC
     * @param planId Plan ID
     * @param tokenId BAYC token ID
     * @param loanAmount Loaned ApeCoin amount
     * @param rewardStakeToCyanVault If enabled stake rewards to CyanVault, otherwise to ApeCoin pool
     * @param signedBlockNum Signed block number
     * @param signature Signature from Cyan
     */
    function createBaycPlan(
        uint256 planId,
        uint32 tokenId,
        uint224 loanAmount,
        bool rewardStakeToCyanVault,
        uint256 signedBlockNum,
        bytes calldata signature
    ) external nonReentrant {
        if (paymentPlan[planId].cyanWalletAddress != address(0)) revert PlanAlreadyExists();

        verifySignature(planId, signedBlockNum, loanAmount, tokenId, BAYC_POOL_ID, rewardStakeToCyanVault, signature);
        (address mainAddress, address cyanWalletAddress) = getUserAddresses(msg.sender);

        // Transfer underlying NFT if it's not in the Cyan wallet
        transferItemByAddressId("BAYC", tokenId, mainAddress, cyanWalletAddress);
        uint224 alreadyStakedAmount = uint224(getApeStaking().nftPosition(BAYC_POOL_ID, tokenId).stakedAmount);
        uint224 stakeAmount = getPoolCap(BAYC_POOL_ID) - alreadyStakedAmount;
        if (loanAmount > 0) {
            if (loanAmount <= stakeAmount) {
                // Transfer ApeCoin to user's Cyan wallet
                cyanApeCoinVault.lend(cyanWalletAddress, loanAmount, BAYC_POOL_ID);
            } else {
                revert LoanAmountExceedsPoolCap();
            }
        }

        // Stake ape coin and lock the NFT
        IWalletApeCoin wallet = IWalletApeCoin(cyanWalletAddress);
        wallet.executeModule(abi.encodeWithSelector(IWalletApeCoin.depositBAYCAndLock.selector, tokenId, stakeAmount));

        ICyanApeCoinPlan.PaymentPlan memory plan = ICyanApeCoinPlan.PaymentPlan(
            BAYC_POOL_ID,
            tokenId,
            loanAmount,
            cyanWalletAddress,
            rewardStakeToCyanVault
                ? ICyanApeCoinPlan.PaymentPlanStatus.ACTIVE_ACCRUE_CYANVAULT
                : ICyanApeCoinPlan.PaymentPlanStatus.ACTIVE_ACCRUE_APESTAKING
        );
        paymentPlan[planId] = plan;
        emit CreatedPlan(planId);
    }

    /**
     * @notice Creating Ape coin staking plan with MAYC
     * @param planId Plan ID
     * @param tokenId MAYC token ID
     * @param loanAmount Loaned ApeCoin amount
     * @param rewardStakeToCyanVault If enabled stake rewards to CyanVault, otherwise to ApeCoin pool
     * @param signedBlockNum Signed block number
     * @param signature Signature from Cyan
     */
    function createMaycPlan(
        uint256 planId,
        uint32 tokenId,
        uint224 loanAmount,
        bool rewardStakeToCyanVault,
        uint256 signedBlockNum,
        bytes calldata signature
    ) external nonReentrant {
        if (paymentPlan[planId].cyanWalletAddress != address(0)) revert PlanAlreadyExists();

        verifySignature(planId, signedBlockNum, loanAmount, tokenId, MAYC_POOL_ID, rewardStakeToCyanVault, signature);
        (address mainAddress, address cyanWalletAddress) = getUserAddresses(msg.sender);

        // Transfer underlying NFT if it's not in the Cyan wallet
        transferItemByAddressId("MAYC", tokenId, mainAddress, cyanWalletAddress);
        uint224 alreadyStakedAmount = uint224(getApeStaking().nftPosition(MAYC_POOL_ID, tokenId).stakedAmount);
        uint224 stakeAmount = getPoolCap(MAYC_POOL_ID) - alreadyStakedAmount;
        if (loanAmount > 0) {
            if (loanAmount <= stakeAmount) {
                // Transfer ApeCoin to user's Cyan wallet
                cyanApeCoinVault.lend(cyanWalletAddress, loanAmount, MAYC_POOL_ID);
            } else {
                revert LoanAmountExceedsPoolCap();
            }
        }

        // Stake ape coin and lock the NFT
        IWalletApeCoin wallet = IWalletApeCoin(cyanWalletAddress);
        wallet.executeModule(abi.encodeWithSelector(IWalletApeCoin.depositMAYCAndLock.selector, tokenId, stakeAmount));

        ICyanApeCoinPlan.PaymentPlan memory plan = ICyanApeCoinPlan.PaymentPlan(
            MAYC_POOL_ID,
            tokenId,
            loanAmount,
            cyanWalletAddress,
            rewardStakeToCyanVault
                ? ICyanApeCoinPlan.PaymentPlanStatus.ACTIVE_ACCRUE_CYANVAULT
                : ICyanApeCoinPlan.PaymentPlanStatus.ACTIVE_ACCRUE_APESTAKING
        );
        paymentPlan[planId] = plan;
        emit CreatedPlan(planId);
    }

    /**
     * @notice Creating Ape coin staking plan with BAYC & BAKC
     * @param planId Plan ID
     * @param baycTokenId BAYC token ID
     * @param bakcTokenId BAKC token ID
     * @param loanAmount Loaned ApeCoin amount
     * @param rewardStakeToCyanVault If enabled stake rewards to CyanVault, otherwise to ApeCoin pool
     * @param signedBlockNum Signed block number
     * @param signature Signature from Cyan
     */
    function createBakcPlanWithBAYC(
        uint256 planId,
        uint32 baycTokenId,
        uint32 bakcTokenId,
        uint224 loanAmount,
        bool rewardStakeToCyanVault,
        uint256 signedBlockNum,
        bytes calldata signature
    ) external nonReentrant {
        verifyBakcSignature(
            planId,
            loanAmount,
            baycTokenId,
            bakcTokenId,
            BAKC_POOL_ID,
            BAYC_POOL_ID,
            signedBlockNum,
            rewardStakeToCyanVault,
            signature
        );

        createBakcPlan(planId, loanAmount, baycTokenId, bakcTokenId, "BAYC", rewardStakeToCyanVault);
    }

    /**
     * @notice Creating Ape coin staking plan with MAYC & BAKC
     * @param planId Plan ID
     * @param maycTokenId MAYC token ID
     * @param bakcTokenId BAKC token ID
     * @param loanAmount Loaned ApeCoin amount
     * @param rewardStakeToCyanVault If enabled stake rewards to CyanVault, otherwise to ApeCoin pool
     * @param signedBlockNum Signed block number
     * @param signature Signature from Cyan
     */
    function createBakcPlanWithMAYC(
        uint256 planId,
        uint32 maycTokenId,
        uint32 bakcTokenId,
        uint224 loanAmount,
        bool rewardStakeToCyanVault,
        uint256 signedBlockNum,
        bytes calldata signature
    ) external nonReentrant {
        verifyBakcSignature(
            planId,
            loanAmount,
            maycTokenId,
            bakcTokenId,
            BAKC_POOL_ID,
            MAYC_POOL_ID,
            signedBlockNum,
            rewardStakeToCyanVault,
            signature
        );

        createBakcPlan(planId, loanAmount, maycTokenId, bakcTokenId, "MAYC", rewardStakeToCyanVault);
    }

    function createBakcPlan(
        uint256 planId,
        uint224 loanAmount,
        uint32 mainTokenId,
        uint32 bakcTokenId,
        bytes32 mainCollectionName,
        bool rewardStakeToCyanVault
    ) private {
        if (paymentPlan[planId].cyanWalletAddress != address(0)) revert PlanAlreadyExists();

        (address mainAddress, address cyanWalletAddress) = getUserAddresses(msg.sender);
        // Transfer underlying NFTs if it's not in the Cyan wallet
        transferItemByAddressId(mainCollectionName, mainTokenId, mainAddress, cyanWalletAddress);
        transferItemByAddressId("BAKC", bakcTokenId, mainAddress, cyanWalletAddress);
        uint224 alreadyStakedAmount = uint224(getApeStaking().nftPosition(BAKC_POOL_ID, bakcTokenId).stakedAmount);
        uint224 stakeAmount = getPoolCap(BAKC_POOL_ID) - alreadyStakedAmount;
        if (loanAmount > 0) {
            if (loanAmount <= stakeAmount) {
                // Transfer ApeCoin to user's Cyan wallet
                cyanApeCoinVault.lend(cyanWalletAddress, loanAmount, BAKC_POOL_ID);
            } else {
                revert LoanAmountExceedsPoolCap();
            }
        }

        IWalletApeCoin wallet = IWalletApeCoin(cyanWalletAddress);
        wallet.executeModule(
            abi.encodeWithSelector(
                IWalletApeCoin.depositBAKCAndLock.selector,
                addressProvider.addresses(mainCollectionName),
                mainTokenId,
                bakcTokenId,
                stakeAmount
            )
        );

        ICyanApeCoinPlan.PaymentPlan memory plan = ICyanApeCoinPlan.PaymentPlan(
            BAKC_POOL_ID,
            bakcTokenId,
            loanAmount,
            cyanWalletAddress,
            rewardStakeToCyanVault
                ? ICyanApeCoinPlan.PaymentPlanStatus.ACTIVE_ACCRUE_CYANVAULT
                : ICyanApeCoinPlan.PaymentPlanStatus.ACTIVE_ACCRUE_APESTAKING
        );
        paymentPlan[planId] = plan;
        emit CreatedPlan(planId);
    }

    /**
     * @notice Creating Ape coin staking plan to ApeCoin pool
     * @param planId Plan ID
     * @param stakeAmount Stake ApeCoin amount
     * @param rewardStakeToCyanVault If enabled stake rewards to CyanVault, otherwise to ApeCoin pool
     * @param signedBlockNum Signed block number
     * @param signature Signature from Cyan
     */
    function createApeCoinPlan(
        uint256 planId,
        uint256 stakeAmount,
        bool rewardStakeToCyanVault,
        uint256 signedBlockNum,
        bytes calldata signature
    ) external nonReentrant {
        if (paymentPlan[planId].cyanWalletAddress != address(0)) revert PlanAlreadyExists();

        verifyApeCoinPlanSignature(
            planId,
            signedBlockNum,
            stakeAmount,
            APECOIN_POOL_ID,
            rewardStakeToCyanVault,
            signature
        );
        (, address cyanWalletAddress) = getUserAddresses(msg.sender);

        // Stake ape coin and lock the NFT
        IWalletApeCoin wallet = IWalletApeCoin(cyanWalletAddress);
        wallet.executeModule(abi.encodeWithSelector(IWalletApeCoin.depositApeCoinAndLock.selector, stakeAmount));

        ICyanApeCoinPlan.PaymentPlan memory plan = ICyanApeCoinPlan.PaymentPlan(
            APECOIN_POOL_ID,
            0,
            0,
            cyanWalletAddress,
            rewardStakeToCyanVault
                ? ICyanApeCoinPlan.PaymentPlanStatus.ACTIVE_ACCRUE_CYANVAULT
                : ICyanApeCoinPlan.PaymentPlanStatus.ACTIVE_ACCRUE_APESTAKING
        );
        paymentPlan[planId] = plan;
        emit CreatedPlan(planId);
    }

    /**
     * @notice Complete NFT staking plan
     * @param planId Payment Plan ID
     */
    function complete(uint256 planId) external nonReentrant {
        ICyanApeCoinPlan.PaymentPlan memory plan = paymentPlan[planId];

        require(plan.cyanWalletAddress != address(0), "CyanApeCoinPlan: plan does not exist");
        require(
            plan.status == ICyanApeCoinPlan.PaymentPlanStatus.ACTIVE_ACCRUE_APESTAKING ||
                plan.status == ICyanApeCoinPlan.PaymentPlanStatus.ACTIVE_ACCRUE_CYANVAULT,
            "CyanApeCoinPlan: plan is not active"
        );
        require(plan.poolId != APECOIN_POOL_ID, "CyanApeCoinPlan: plan is ApeCoin plan");

        if (msg.sender != paymentPlan[planId].cyanWalletAddress) {
            address mainWalletAddress = getMainWalletAddress(paymentPlan[planId].cyanWalletAddress);
            require(msg.sender == mainWalletAddress, "CyanApeCoinPlan: Must be plan owner to complete");
        }

        uint256 poolInterestRate = cyanApeCoinVault.interestRates(plan.poolId);
        (uint256 rewards, uint256 interestFee, uint256 serviceFee, uint256 stakedAmount) = calculateNumbers(
            plan,
            poolInterestRate
        );

        IWalletApeCoin wallet = IWalletApeCoin(plan.cyanWalletAddress);
        bytes4 withdrawFunctionSelector;
        if (plan.poolId == BAYC_POOL_ID) {
            withdrawFunctionSelector = IWalletApeCoin.withdrawBAYCAndUnlock.selector;
        } else if (plan.poolId == MAYC_POOL_ID) {
            withdrawFunctionSelector = IWalletApeCoin.withdrawMAYCAndUnlock.selector;
        } else {
            withdrawFunctionSelector = IWalletApeCoin.withdrawBAKCAndUnlock.selector;
        }
        wallet.executeModule(abi.encodeWithSelector(withdrawFunctionSelector, plan.tokenId));

        claimableServiceFee += serviceFee;

        if (plan.loanedAmount > 0) {
            cyanApeCoinVault.pay(plan.loanedAmount, interestFee, plan.poolId);
        }
        paymentPlan[planId].status = ICyanApeCoinPlan.PaymentPlanStatus.COMPLETED;

        uint256 depositAmount = stakedAmount + rewards - plan.loanedAmount;
        if (depositAmount > 0) {
            if (plan.status == ICyanApeCoinPlan.PaymentPlanStatus.ACTIVE_ACCRUE_CYANVAULT) {
                cyanApeCoinVault.deposit(ICyanApeCoinVault.DepositInfo(plan.cyanWalletAddress, depositAmount));
            } else {
                IApeCoinStaking apeStaking = getApeStaking();
                apeStaking.depositApeCoin(depositAmount, plan.cyanWalletAddress);
            }
        }

        emit Completed(planId);
    }

    /**
     * @notice Complete ApeCoin staking plan
     * @param planId Payment Plan ID
     */
    function completeApeCoinPlan(uint256 planId) external nonReentrant {
        ICyanApeCoinPlan.PaymentPlan memory plan = paymentPlan[planId];

        require(plan.cyanWalletAddress != address(0), "CyanApeCoinPlan: plan does not exist");
        require(
            plan.status == ICyanApeCoinPlan.PaymentPlanStatus.ACTIVE_ACCRUE_APESTAKING ||
                plan.status == ICyanApeCoinPlan.PaymentPlanStatus.ACTIVE_ACCRUE_CYANVAULT,
            "CyanApeCoinPlan: plan is not active"
        );
        require(plan.poolId == APECOIN_POOL_ID, "CyanApeCoinPlan: plan is not ApeCoin plan");

        if (msg.sender != paymentPlan[planId].cyanWalletAddress) {
            address mainWalletAddress = getMainWalletAddress(paymentPlan[planId].cyanWalletAddress);
            require(msg.sender == mainWalletAddress, "CyanApeCoinPlan: Must be plan owner to complete");
        }

        (uint256 deposited, , uint256 serviceFee) = calculateApeCoinPoolNumbers(paymentPlan[planId].cyanWalletAddress);

        IWalletApeCoin wallet = IWalletApeCoin(plan.cyanWalletAddress);
        wallet.executeModule(
            abi.encodeWithSelector(IWalletApeCoin.withdrawApeCoinAndUnlock.selector, deposited, serviceFee)
        );

        claimableServiceFee += serviceFee;

        paymentPlan[planId].status = ICyanApeCoinPlan.PaymentPlanStatus.COMPLETED;

        emit Completed(planId);
    }

    function autoCompound(uint256[] calldata planIds) external nonReentrant onlyRole(CYAN_ROLE) {
        uint256 totalInterestFee;
        uint256 totalServiceFee;
        uint256[4] memory poolInterestRates = cyanApeCoinVault.getPoolInterestRates();

        ICyanApeCoinVault.DepositInfo[] memory deposits = new ICyanApeCoinVault.DepositInfo[](planIds.length);
        IApeCoinStaking apeStaking = getApeStaking();

        for (uint256 ind; ind < planIds.length; ) {
            ICyanApeCoinPlan.PaymentPlan memory plan = paymentPlan[planIds[ind]];

            require(plan.cyanWalletAddress != address(0), "CyanApeCoinPlan: plan does not exist");
            require(
                plan.status == ICyanApeCoinPlan.PaymentPlanStatus.ACTIVE_ACCRUE_APESTAKING ||
                    plan.status == ICyanApeCoinPlan.PaymentPlanStatus.ACTIVE_ACCRUE_CYANVAULT,
                "CyanApeCoinPlan: plan is not active"
            );
            IWalletApeCoin wallet = IWalletApeCoin(plan.cyanWalletAddress);
            uint256 rewards;
            if (plan.poolId == APECOIN_POOL_ID) {
                (, uint256 unclaimed, uint256 serviceFee) = calculateApeCoinPoolNumbers(plan.cyanWalletAddress);
                rewards = unclaimed - serviceFee;
                require(rewards > 0, "CyanApeCoinPlan: not enough rewards");

                wallet.executeModule(abi.encodeWithSelector(IWalletApeCoin.autoCompoundApeCoinPool.selector));

                totalServiceFee += serviceFee;
            } else {
                (uint256 _rewards, uint256 interestFee, uint256 serviceFee, ) = calculateNumbers(
                    plan,
                    poolInterestRates[plan.poolId]
                );
                rewards = _rewards;
                require(rewards > 0, "CyanApeCoinPlan: not enough rewards");

                wallet.executeModule(
                    abi.encodeWithSelector(IWalletApeCoin.autoCompound.selector, plan.poolId, plan.tokenId)
                );

                totalServiceFee += serviceFee;
                totalInterestFee += interestFee;
            }
            if (plan.status == ICyanApeCoinPlan.PaymentPlanStatus.ACTIVE_ACCRUE_CYANVAULT) {
                deposits[ind] = ICyanApeCoinVault.DepositInfo(plan.cyanWalletAddress, rewards);
            } else {
                deposits[ind] = ICyanApeCoinVault.DepositInfo(plan.cyanWalletAddress, 0);
                apeStaking.depositApeCoin(rewards, plan.cyanWalletAddress);
            }
            unchecked {
                ++ind;
            }
        }

        claimableServiceFee += totalServiceFee;

        cyanApeCoinVault.earn(totalInterestFee);
        cyanApeCoinVault.depositBatch(deposits);

        emit AutoCompounded();
    }

    function verifySignature(
        uint256 planId,
        uint256 signedBlockNum,
        uint224 amount,
        uint32 tokenId,
        uint256 poolId,
        bool rewardStakeToCyanVault,
        bytes calldata signature
    ) private view {
        if (signedBlockNum > block.number) revert InvalidBlockNumber();
        if (signedBlockNum + 50 < block.number) revert InvalidSignature();

        bytes32 msgHash = keccak256(
            abi.encodePacked(planId, tokenId, signedBlockNum, amount, poolId, block.chainid, rewardStakeToCyanVault)
        );
        bytes32 signedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));
        if (signedHash.recover(signature) != cyanSigner) revert InvalidSignature();
    }

    function verifyBakcSignature(
        uint256 planId,
        uint224 amount,
        uint32 mainTokenId,
        uint32 bakcTokenId,
        uint256 poolId,
        uint256 mainPoolId,
        uint256 signedBlockNum,
        bool rewardStakeToCyanVault,
        bytes calldata signature
    ) private view {
        if (signedBlockNum > block.number) revert InvalidBlockNumber();
        if (signedBlockNum + 50 < block.number) revert InvalidSignature();

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                planId,
                amount,
                mainTokenId,
                bakcTokenId,
                poolId,
                mainPoolId,
                signedBlockNum,
                block.chainid,
                rewardStakeToCyanVault
            )
        );
        bytes32 signedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));
        if (signedHash.recover(signature) != cyanSigner) revert InvalidSignature();
    }

    function verifyApeCoinPlanSignature(
        uint256 planId,
        uint256 signedBlockNum,
        uint256 amount,
        uint256 poolId,
        bool rewardStakeToCyanVault,
        bytes calldata signature
    ) private view {
        if (signedBlockNum > block.number) revert InvalidBlockNumber();
        if (signedBlockNum + 50 < block.number) revert InvalidSignature();

        bytes32 msgHash = keccak256(
            abi.encodePacked(planId, signedBlockNum, amount, poolId, block.chainid, rewardStakeToCyanVault)
        );
        bytes32 signedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));
        if (signedHash.recover(signature) != cyanSigner) revert InvalidSignature();
    }

    function getUserAddresses(address caller) private returns (address, address) {
        address mainAddress = caller;
        address cyanWalletAddress = IFactory(walletFactory).getOrDeployWallet(caller);
        if (cyanWalletAddress == caller) {
            mainAddress = IFactory(walletFactory).getWalletOwner(cyanWalletAddress);
        }
        return (mainAddress, cyanWalletAddress);
    }

    /**
     * @notice Getting main wallet address by Cyan wallet address
     * @param cyanWalletAddress Cyan wallet address
     */
    function getMainWalletAddress(address cyanWalletAddress) private view returns (address) {
        return IFactory(walletFactory).getWalletOwner(cyanWalletAddress);
    }

    /**
     * @notice Updating Cyan signer address
     * @param _cyanSigner New Cyan signer address
     */
    function updateCyanSignerAddress(address _cyanSigner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_cyanSigner == address(0)) revert InvalidAddress();
        cyanSigner = _cyanSigner;
        emit UpdatedCyanSigner(_cyanSigner);
    }

    /**
     * @notice Claiming collected service fee amount
     */
    function claimServiceFee() external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        emit ClaimedServiceFee(claimableServiceFee);
        getApeCoin().safeTransfer(msg.sender, claimableServiceFee);
        claimableServiceFee = 0;
    }

    /**
     * @notice Updating Cyan wallet factory address that used for deploying new wallets
     * @param factory New Cyan wallet factory address
     */
    function updateWalletFactoryAddress(address factory) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (factory == address(0)) revert InvalidAddress();
        walletFactory = factory;
        emit UpdatedWalletFactory(factory);
    }

    /**
     * @notice Updating Cyan service fee rate
     * @param feeRate New service fee rate
     */
    function updateServiceFeeRate(uint256 feeRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (feeRate > 10000) revert InvalidRate();
        serviceFeeRate = feeRate;
        emit UpdatedServiceFeeRate(feeRate);
    }

    /**
     * @notice Approve ApeCoin to Cyan Vault
     * @param vaultAddress Cyan Vault Address
     */
    function updateCyanVaultAddress(address vaultAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (vaultAddress == address(0)) revert InvalidAddress();

        IERC20Upgradeable apeCoin = getApeCoin();
        apeCoin.approve(address(cyanApeCoinVault), 0);

        cyanApeCoinVault = ICyanApeCoinVault(vaultAddress);
        apeCoin.approve(vaultAddress, type(uint256).max);
    }

    /**
     * @notice Approve the max amount of ApeCoin for the ApeCoin staking contract
     */
    function apeCoinApproval() external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        getApeCoin().approve(address(getApeStaking()), type(uint256).max);
    }

    function getApeStaking() private view returns (IApeCoinStaking) {
        return IApeCoinStaking(addressProvider.addresses("APE_COIN_STAKING"));
    }

    function getApeCoin() private view returns (IERC20Upgradeable) {
        return IERC20Upgradeable(addressProvider.addresses("APE_COIN"));
    }

    function transferItemByAddressId(
        bytes32 id,
        uint256 tokenId,
        address mainAddress,
        address cyanWalletAddress
    ) private {
        IERC721Upgradeable collection = IERC721Upgradeable(addressProvider.addresses(id));
        if (collection.ownerOf(tokenId) != cyanWalletAddress) {
            ICyanConduit(addressProvider.addresses("CYAN_CONDUIT")).transferERC721(
                mainAddress,
                cyanWalletAddress,
                address(collection),
                tokenId
            );
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title ApeCoin Staking Contract interface
interface IApeCoinStaking {
    struct SingleNft {
        uint32 tokenId;
        uint224 amount;
    }
    struct PairNftDepositWithAmount {
        uint32 mainTokenId;
        uint32 bakcTokenId;
        uint184 amount;
    }
    struct PairNft {
        uint128 mainTokenId;
        uint128 bakcTokenId;
    }
    struct PairNftWithdrawWithAmount {
        uint32 mainTokenId;
        uint32 bakcTokenId;
        uint184 amount;
        bool isUncommit;
    }

    struct Position {
        uint256 stakedAmount;
        int256 rewardsDebt;
    }

    struct Pool {
        uint48 lastRewardedTimestampHour;
        uint16 lastRewardsRangeIndex;
        uint96 stakedAmount;
        uint96 accumulatedRewardsPerShare;
    }

    struct TimeRange {
        uint48 startTimestampHour;
        uint48 endTimestampHour;
        uint96 rewardsPerHour;
        uint96 capPerPosition;
    }

    struct PoolUI {
        uint256 poolId;
        uint256 stakedAmount;
        TimeRange currentTimeRange;
    }

    struct PairingStatus {
        uint248 tokenId;
        bool isPaired;
    }

    struct DashboardStake {
        uint256 poolId;
        uint256 tokenId;
        uint256 deposited;
        uint256 unclaimed;
        uint256 rewards24hr;
        DashboardPair pair;
    }

    struct DashboardPair {
        uint256 mainTokenId;
        uint256 mainTypePoolId;
    }

    function pools(uint256) external view returns (Pool memory);

    function bakcToMain(uint256, uint256) external view returns (PairingStatus memory);

    function nftPosition(uint256, uint256) external view returns (Position memory);

    function getPoolsUI()
        external
        view
        returns (
            PoolUI memory,
            PoolUI memory,
            PoolUI memory,
            PoolUI memory
        );

    function pendingRewards(
        uint256 _poolId,
        address _address,
        uint256 _tokenId
    ) external view returns (uint256);

    function getApeCoinStake(address _address) external view returns (DashboardStake memory);

    function getTimeRangeBy(uint256 _poolId, uint256 _index) external view returns (TimeRange memory);

    function depositApeCoin(uint256 _amount, address _recipient) external;

    function depositSelfApeCoin(uint256 _amount) external;

    function depositBAYC(SingleNft[] calldata _nfts) external;

    function depositMAYC(SingleNft[] calldata _nfts) external;

    function depositBAKC(PairNftDepositWithAmount[] calldata _baycPairs, PairNftDepositWithAmount[] calldata _maycPairs)
        external;

    function claimApeCoin(address _recipient) external;

    function claimSelfApeCoin() external;

    function claimBAYC(uint256[] calldata _nfts, address _recipient) external;

    function claimSelfBAYC(uint256[] calldata _nfts) external;

    function claimMAYC(uint256[] calldata _nfts, address _recipient) external;

    function claimSelfMAYC(uint256[] calldata _nfts) external;

    function claimBAKC(
        PairNft[] calldata _baycPairs,
        PairNft[] calldata _maycPairs,
        address _recipient
    ) external;

    function claimSelfBAKC(PairNft[] calldata _baycPairs, PairNft[] calldata _maycPairs) external;

    function withdrawApeCoin(uint256 _amount, address _recipient) external;

    function withdrawSelfApeCoin(uint256 _amount) external;

    function withdrawBAYC(SingleNft[] calldata _nfts, address _recipient) external;

    function withdrawSelfBAYC(SingleNft[] calldata _nfts) external;

    function withdrawMAYC(SingleNft[] calldata _nfts, address _recipient) external;

    function withdrawSelfMAYC(SingleNft[] calldata _nfts) external;

    function withdrawBAKC(
        PairNftWithdrawWithAmount[] calldata _baycPairs,
        PairNftWithdrawWithAmount[] calldata _maycPairs
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ICyanApeCoinVault {
    struct DepositInfo {
        address recipient;
        uint256 amount;
    }

    function interestRates(uint256 poolId) external returns (uint256);

    function deposit(DepositInfo calldata depositInfo) external;

    function depositBatch(DepositInfo[] calldata deposits) external;

    function lend(
        address to,
        uint256 amount,
        uint256 poolId
    ) external;

    function pay(
        uint256 amount,
        uint256 profit,
        uint256 poolId
    ) external;

    function earn(uint256 profit) external;

    function getPoolInterestRates() external view returns (uint256[4] memory);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Cyan AddressProvider contract
/// @author Bulgantamir Gankhuyag - <bulgaa@usecyan.com>
/// @author Naranbayar Uuganbayar - <naba@usecyan.com>
contract AddressProvider is Ownable {
    error AddressNotFound(bytes32 id);

    event AddressSet(bytes32 id, address newAddress);

    mapping(bytes32 => address) public addresses;

    constructor(address owner) {
        transferOwnership(owner);
    }

    // @dev Sets an address for an id replacing the address saved in the addresses map
    // @param id The id
    // @param newAddress The address to set
    function setAddress(bytes32 id, address newAddress) external onlyOwner {
        addresses[id] = newAddress;
        emit AddressSet(id, newAddress);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IFactory {
    function getOrDeployWallet(address) external returns (address);

    function getWalletOwner(address) external view returns (address);

    function getOwnerWallet(address) external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./IWallet.sol";

interface IWalletApeCoin is IWallet {
    function depositBAYCAndLock(uint32 tokenId, uint224 amount) external;

    function depositMAYCAndLock(uint32 tokenId, uint224 amount) external;

    function depositBAKCAndLock(
        address mainCollection,
        uint32 mainTokenId,
        uint32 bakcTokenId,
        uint224 amount
    ) external;

    function depositApeCoinAndLock(uint256 amount) external;

    function withdrawBAYCAndUnlock(uint32 tokenId) external;

    function withdrawMAYCAndUnlock(uint32 tokenId) external;

    function withdrawBAKCAndUnlock(uint32 tokenId) external;

    function withdrawApeCoinAndUnlock(uint256 unstakeAmount, uint256 serviceFee) external;

    function autoCompound(uint256 poolId, uint32 tokenId) external;

    function autoCompoundApeCoinPool() external;

    function getApeLockState(address collection, uint256 tokenId) external view returns (uint8);

    function completeApeCoinPlan(uint256 planId) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

enum ConduitItemType {
    NATIVE, // unused
    ERC20,
    ERC721,
    ERC1155
}

struct ConduitTransfer {
    ConduitItemType itemType;
    address collection;
    address from;
    address to;
    uint256 identifier;
    uint256 amount;
}

struct ConduitBatch1155Transfer {
    address collection;
    address from;
    address to;
    uint256[] ids;
    uint256[] amounts;
}

interface ICyanConduit {
    error ChannelClosed(address channel);
    error ChannelStatusAlreadySet(address channel, bool isOpen);
    error InvalidItemType();
    error InvalidAdmin();

    event ChannelUpdated(address indexed channel, bool open);

    function execute(ConduitTransfer[] calldata transfers) external returns (bytes4 magicValue);

    function executeBatch1155(ConduitBatch1155Transfer[] calldata batch1155Transfers)
        external
        returns (bytes4 magicValue);

    function executeWithBatch1155(
        ConduitTransfer[] calldata standardTransfers,
        ConduitBatch1155Transfer[] calldata batch1155Transfers
    ) external returns (bytes4 magicValue);

    function transferERC20(
        address from,
        address to,
        address token,
        uint256 amount
    ) external;

    function transferERC721(
        address from,
        address to,
        address collection,
        uint256 tokenId
    ) external;

    function transferERC1155(
        address from,
        address to,
        address collection,
        uint256 tokenId,
        uint256 amount
    ) external;

    function updateChannel(address channel, bool isOpen) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ICyanApeCoinPlan {
    enum PaymentPlanStatus {
        ACTIVE_ACCRUE_APESTAKING,
        ACTIVE_ACCRUE_CYANVAULT,
        COMPLETED
    }

    struct PaymentPlan {
        uint256 poolId;
        uint32 tokenId;
        uint224 loanedAmount;
        address cyanWalletAddress;
        PaymentPlanStatus status;
    }

    function paymentPlan(uint256 planId) external view returns (PaymentPlan memory);

    function createBaycPlan(
        uint256 planId,
        uint32 tokenId,
        uint224 loanAmount,
        bool rewardStakeToCyanVault,
        uint256 signedBlockNum,
        bytes calldata signature
    ) external;

    function createMaycPlan(
        uint256 planId,
        uint32 tokenId,
        uint224 loanAmount,
        bool rewardStakeToCyanVault,
        uint256 signedBlockNum,
        bytes calldata signature
    ) external;

    function createBakcPlanWithBAYC(
        uint256 planId,
        uint32 baycTokenId,
        uint32 bakcTokenId,
        uint224 loanAmount,
        bool rewardStakeToCyanVault,
        uint256 signedBlockNum,
        bytes calldata signature
    ) external;

    function createBakcPlanWithMAYC(
        uint256 planId,
        uint32 maycTokenId,
        uint32 bakcTokenId,
        uint224 loanAmount,
        bool rewardStakeToCyanVault,
        uint256 signedBlockNum,
        bytes calldata signature
    ) external;

    function createApeCoinPlan(
        uint256 planId,
        uint256 stakeAmount,
        bool rewardStakeToCyanVault,
        uint256 signedBlockNum,
        bytes calldata signature
    ) external;

    function complete(uint256 planId) external;

    function completeApeCoinPlan(uint256 planId) external;

    function autoCompound(uint256[] calldata planIds) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";
import "../utils/ContextUpgradeable.sol";
import "../utils/StringsUpgradeable.sol";
import "../utils/introspection/ERC165Upgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal onlyInitializing {
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(account),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../StringsUpgradeable.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSAUpgradeable {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV // Deprecated in v4.8
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", StringsUpgradeable.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../extensions/draft-IERC20PermitUpgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20PermitUpgradeable token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../../thirdparty/opensea/ISeaport.sol";
import { Item } from "../../main/payment-plan/PaymentPlanTypes.sol";

interface IWallet {
    function executeModule(bytes memory) external returns (bytes memory);

    function transferNonLockedERC721(
        address,
        uint256,
        address
    ) external;

    function transferNonLockedERC1155(
        address,
        uint256,
        uint256,
        address
    ) external;

    function transferNonLockedCryptoPunk(uint256, address) external;

    function setLockedERC721Token(
        address,
        uint256,
        bool
    ) external;

    function increaseLockedERC1155Token(
        address,
        uint256,
        uint256
    ) external;

    function decreaseLockedERC1155Token(
        address,
        uint256,
        uint256
    ) external;

    function setLockedCryptoPunk(uint256, bool) external;

    function autoPay(
        uint256,
        uint256,
        uint8
    ) external;

    function earlyUnwindOpensea(
        uint256,
        uint256,
        Item memory,
        ISeaport.OfferData memory
    ) external;

    function earlyUnwindCyan(uint256, address) external;

    function isLockedNFT(address, uint256) external view returns (bool);

    function repayBendDaoLoan(
        address collection,
        uint256 tokenId,
        uint256 amount,
        address currency
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title Seaport Contract interface
interface ISeaport {
    enum OrderType {
        FULL_OPEN,
        PARTIAL_OPEN,
        FULL_RESTRICTED,
        PARTIAL_RESTRICTED,
        CONTRACT
    }
    enum ItemType {
        NATIVE,
        ERC20,
        ERC721,
        ERC1155,
        ERC721_WITH_CRITERIA,
        ERC1155_WITH_CRITERIA
    }
    enum Side {
        OFFER,
        CONSIDERATION
    }

    struct OfferItem {
        ItemType itemType;
        address token;
        uint256 identifierOrCriteria;
        uint256 startAmount;
        uint256 endAmount;
    }
    struct ConsiderationItem {
        ItemType itemType;
        address token;
        uint256 identifierOrCriteria;
        uint256 startAmount;
        uint256 endAmount;
        address payable recipient;
    }
    struct OrderParameters {
        address offerer;
        address zone;
        OfferItem[] offer;
        ConsiderationItem[] consideration;
        OrderType orderType;
        uint256 startTime;
        uint256 endTime;
        bytes32 zoneHash;
        uint256 salt;
        bytes32 conduitKey;
        uint256 totalOriginalConsiderationItems;
    }
    struct FulfillmentComponent {
        uint256 orderIndex;
        uint256 itemIndex;
    }
    struct Fulfillment {
        FulfillmentComponent[] offerComponents;
        FulfillmentComponent[] considerationComponents;
    }
    struct CriteriaResolver {
        uint256 orderIndex;
        Side side;
        uint256 index;
        uint256 identifier;
        bytes32[] criteriaProof;
    }
    struct AdvancedOrder {
        OrderParameters parameters;
        uint120 numerator;
        uint120 denominator;
        bytes signature;
        bytes extraData;
    }
    struct ReceivedItem {
        ItemType itemType;
        address token;
        uint256 identifier;
        uint256 amount;
        address payable recipient;
    }
    struct Execution {
        ReceivedItem item;
        address offerer;
        bytes32 conduitKey;
    }

    struct OfferData {
        AdvancedOrder[] orders;
        CriteriaResolver[] criteriaResolvers;
        Fulfillment[] fulfillments;
        address recipient;
    }

    function matchAdvancedOrders(
        AdvancedOrder[] calldata orders,
        CriteriaResolver[] calldata criteriaResolvers,
        Fulfillment[] calldata fulfillments,
        address recipient
    ) external payable returns (Execution[] calldata executions);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// DataTypes
enum PawnCreateType {
    REGULAR,
    BEND_DAO,
    REFINANCE
}
enum PaymentPlanStatus {
    BNPL_CREATED,
    BNPL_FUNDED,
    BNPL_ACTIVE,
    BNPL_DEFAULTED,
    BNPL_REJECTED,
    BNPL_COMPLETED,
    BNPL_LIQUIDATED,
    PAWN_ACTIVE,
    PAWN_DEFAULTED,
    PAWN_COMPLETED,
    PAWN_LIQUIDATED
}
struct Plan {
    uint256 amount;
    uint32 downPaymentPercent;
    uint32 interestRate;
    uint32 serviceFeeRate;
    uint32 term;
    uint8 totalNumberOfPayments;
    uint8 counterPaidPayments;
    uint8 autoRepayStatus;
}
struct PaymentPlan {
    Plan plan;
    uint256 createdDate;
    address cyanWalletAddress;
    PaymentPlanStatus status;
}

struct Item {
    uint256 amount;
    uint256 tokenId;
    address contractAddress;
    address cyanVaultAddress;
    // 1 -> ERC721
    // 2 -> ERC1155
    // 3 -> CryptoPunks
    uint8 itemType;
}

struct PaymentAmountInfo {
    uint256 loanAmount;
    uint256 interestAmount;
    uint256 serviceAmount;
}

// Errors
error InvalidSender();
error InvalidBlockNumber();
error InvalidSignature();
error InvalidServiceFeeRate();
error InvalidTokenPrice();
error InvalidInterestRate();
error InvalidDownPaymentPercent();
error InvalidDownPayment();
error InvalidAmount();
error InvalidTerm();
error InvalidPaidCount();
error InvalidStage();
error InvalidAddress();
error InvalidAutoRepaymentDate();
error InvalidAutoRepaymentStatus();
error InvalidTotalNumberOfPayments();
error InvalidReviveDate();
error InvalidItem();
error InvalidBaseDiscountRate();
error InvalidApeCoinPlan();
error InvalidBendDaoPlan();
error InvalidCurrency();
error InvalidCyanBuyer();
error InvalidSelector();

error EthTransferFailed();

error PaymentPlanAlreadyExists();
error PaymentPlanNotFound();

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/MathUpgradeable.sol";

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = MathUpgradeable.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, MathUpgradeable.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initialized`
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initializing`
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MathUpgradeable {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20PermitUpgradeable {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

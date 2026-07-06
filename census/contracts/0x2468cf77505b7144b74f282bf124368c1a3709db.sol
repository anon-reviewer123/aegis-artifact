// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Steakhouse Financial
pragma solidity ^0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MorphoVaultV1AdapterFactory} from "@vault-v2/src/adapters/MorphoVaultV1AdapterFactory.sol";
import {IVaultV2} from "@vault-v2/src/interfaces/IVaultV2.sol";
import "@vault-v2/src/libraries/ConstantsLib.sol";
import {VaultV2} from "@vault-v2/src/VaultV2.sol";
import {VaultV2Factory} from "@vault-v2/src/VaultV2Factory.sol";
import "./../interfaces/Aragon.sol";
import {Revoker} from "./Revoker.sol";
import {VaultV2Lib} from "./VaultV2Lib.sol";
import {Box} from "../Box.sol";
import {IBox} from "../interfaces/IBox.sol";
import {BoxAdapterFactory} from "../factories/BoxAdapterFactory.sol";

/**
 * @title VaultV2Helper
 * @notice Helper contract for VaultV2 configuration
 * @dev This contract handles vault configuration, adapter management, and other utility functions.
 *
 * Chain Support:
 * - Ethereum Mainnet (chainId: 1)
 * - Base (chainId: 8453)
 * - Addresses configured per chain in constructor
 */
contract VaultV2Helper {
    using VaultV2Lib for IVaultV2;

    /* ======== EVENTS ======== */
    event VaultCreated(address indexed vault, address indexed asset, string name, string symbol);
    event RevokerDeployed(address indexed vault, address indexed sentinel, address indexed revoker);
    event VaultConfigured(address indexed vault);

    /* ======== VARIABLES ======== */
    address public owner;
    address public curator;
    address[] public allocators;

    address public morphoRegistry;
    VaultV2Factory public vaultV2Factory;
    MorphoVaultV1AdapterFactory public mv1AdapterFactory;
    BoxAdapterFactory public boxAdapterFactory;
    IDAOFactory public daoFactory;
    address public lockToVoteRepo;
    address public multisigRepo;

    mapping(address => address) public vaultCreator;

    function _onlyVaultCreator(IVaultV2 vault) private view {
        require(vaultCreator[address(vault)] == msg.sender, "Not vault creator");
    }

    /* ======== CONSTRUCTOR ======== */

    constructor() {
        // Base configuration (chain ID 8453) or local testing (31337)
        if (block.chainid == 8453 || block.chainid == 31337) {
            morphoRegistry = 0x5C2531Cbd2cf112Cf687da3Cd536708aDd7DB10a;
            owner = 0x0A0e559bc3b0950a7e448F0d4894db195b9cf8DD;
            curator = 0x827e86072B06674a077f592A531dcE4590aDeCdB;
            allocators.push(0x0000aeB716a0DF7A9A1AAd119b772644Bc089dA8);
            allocators.push(0xfeed46c11F57B7126a773EeC6ae9cA7aE1C03C9a);
            vaultV2Factory = VaultV2Factory(0x4501125508079A99ebBebCE205DeC9593C2b5857);
            mv1AdapterFactory = MorphoVaultV1AdapterFactory(0xF42D9c36b34c9c2CF3Bc30eD2a52a90eEB604642);
            boxAdapterFactory = BoxAdapterFactory(0xc71DA48CCcfc35514EC80B871f4c81e01bBcd169);
            daoFactory = IDAOFactory(0xcc602EA573a42eBeC290f33F49D4A87177ebB8d2);
            lockToVoteRepo = 0x05ECA5ab78493Bf812052B0211a206BCBA03471B;
            multisigRepo = 0xcDC4b0BC63AEfFf3a7826A19D101406C6322A585;
        }
        // Ethereum Mainnet configuration (chain ID 1)
        else if (block.chainid == 1) {
            morphoRegistry = 0x3696c5eAe4a7Ffd04Ea163564571E9CD8Ed9364e;
            owner = 0x0A0e559bc3b0950a7e448F0d4894db195b9cf8DD;
            curator = 0x827e86072B06674a077f592A531dcE4590aDeCdB;
            allocators.push(0x0000aeB716a0DF7A9A1AAd119b772644Bc089dA8);
            allocators.push(0xfeed46c11F57B7126a773EeC6ae9cA7aE1C03C9a);
            allocators.push(0xaaD84c80b013c34D70E54fB343D0C2f309F635E7);
            vaultV2Factory = VaultV2Factory(0xA1D94F746dEfa1928926b84fB2596c06926C0405);
            mv1AdapterFactory = MorphoVaultV1AdapterFactory(0xD1B8E2dee25c2b89DCD2f98448a7ce87d6F63394);
            boxAdapterFactory = BoxAdapterFactory(0x5bc0FCfB95E3db40CFD762993E0665D7fAc8e92C);
            daoFactory = IDAOFactory(0x246503df057A9a85E0144b6867a828c99676128B);
            lockToVoteRepo = address(0x0f4FBD2951Db08B45dE16e7519699159aE1b4bb7);
            multisigRepo = address(0x8c278e37D0817210E18A7958524b7D0a1fAA6F7b);
        } 
        // Arbitrum One configuration (chain ID 42161)
        else if (block.chainid == 42161) {
            morphoRegistry = 0xc00eb3c7aD1aE986A7f05F5A9d71aCa39c763C65;
            owner = 0x0A0e559bc3b0950a7e448F0d4894db195b9cf8DD;
            curator = 0x827e86072B06674a077f592A531dcE4590aDeCdB;
            allocators.push(0x0000aeB716a0DF7A9A1AAd119b772644Bc089dA8);
            allocators.push(0xfeed46c11F57B7126a773EeC6ae9cA7aE1C03C9a);
            vaultV2Factory = VaultV2Factory(address(0x6b46fa3cc9EBF8aB230aBAc664E37F2966Bf7971));
            mv1AdapterFactory = MorphoVaultV1AdapterFactory(address(0xD8Fc8a85779551e78B516da9f74061cb3b086793));
            boxAdapterFactory = BoxAdapterFactory(0xB988a26DFe3B6e34f636c2f1cE3f73384D9bEB1e);
            daoFactory = IDAOFactory(address(0x49e04AB7af7A263b8ac802c1cAe22f5b4E4577Cd));
            lockToVoteRepo = address(0xe92eF55cCbB3ac48f54f2FcDC4c49379CB01C57F);
            multisigRepo = address(0x7553E6Fb020c5740768cF289e603770AA09b7aE2);
        }
        else {
            revert("Unsupported chain");
        }
    }

    /* ======== VAULT CREATION TEMPLATES ======== */
    function createV1Wrapper(
        address asset,
        bytes32 salt,
        string calldata name,
        string calldata symbol,
        address v1Vault,
        uint256 timelock
    ) external returns (IVaultV2 vault) {
        // Create vault via factory
        vault = create(asset, salt, name, symbol);

        addVaultV1(vault, v1Vault, true, 1_000_000_000_000 * 10 ** IERC20Metadata(asset).decimals(), 1 ether);

        address guardian = createGuardian(vault);

        finalizeWithGuardian(vault, timelock, guardian);
    }

    function createV1WrapperCompliant(
        address asset,
        bytes32 salt,
        string calldata name,
        string calldata symbol,
        address v1Vault,
        uint256 timelock
    ) external returns (IVaultV2 vault) {
        // Create vault via factory
        vault = create(asset, salt, name, symbol);

        addVaultV1(vault, v1Vault, true, 1_000_000_000_000 * 10 ** IERC20Metadata(asset).decimals(), 1 ether);
        conformMorphoRegistry(vault);

        address guardian = createGuardian(vault);

        finalizeWithGuardian(vault, timelock, guardian);
    }

    function createV1WrapperWithAdditionalGuardian(
        address asset,
        bytes32 salt,
        string calldata name,
        string calldata symbol,
        address v1Vault,
        address additionalGuardian,
        uint256 timelock
    ) external returns (IVaultV2 vault) {
        // Create vault via factory
        vault = create(asset, salt, name, symbol);

        addVaultV1(vault, v1Vault, true, 1_000_000_000_000 * 10 ** IERC20Metadata(asset).decimals(), 1 ether);

        address guardian = createGuardianWithAdmin(vault, additionalGuardian);

        finalizeWithGuardian(vault, timelock, guardian);
    }

    /* ======== VAULT CREATION ======== */

    /**
     * @notice Create a new VaultV2 instance
     * @dev Helper becomes initial owner and curator, which should be transferred later
     * @param asset The underlying asset (e.g., USDC)
     * @param salt Salt for deterministic deployment
     * @param name Vault name
     * @param symbol Vault symbol
     * @return vault The created vault
     */
    function create(address asset, bytes32 salt, string calldata name, string calldata symbol) public returns (IVaultV2 vault) {
        // Create vault via factory
        vault = VaultV2(vaultV2Factory.createVaultV2(address(this), asset, salt));

        // register the creator and fail if already regiestered
        require(vaultCreator[address(vault)] == address(0), "Vault already registered");
        vaultCreator[address(vault)] = msg.sender;

        // Set helper as curator
        vault.setCurator(address(this));

        // Add helper as allocator (needed for initial config)
        vault.submit(abi.encodeWithSelector(vault.setIsAllocator.selector, address(this), true));
        vault.setIsAllocator(address(this), true);

        // Add configured allocators
        for (uint i = 0; i < allocators.length; i++) {
            vault.submit(abi.encodeWithSelector(vault.setIsAllocator.selector, address(allocators[i]), true));
            vault.setIsAllocator(address(allocators[i]), true);
        }

        // Set vault metadata
        vault.setName(name);
        vault.setSymbol(symbol);

        // Set maximum rate
        vault.setMaxRate(MAX_MAX_RATE);

        emit VaultCreated(address(vault), asset, name, symbol);
    }

    /**
     * @notice Add a Morpho MetaMorpho vault as an adapter
     * @dev Creates adapter, adds it to vault, and sets caps
     * @param vault The VaultV2 to configure
     * @param vaultV1 The MetaMorpho vault address
     * @param liquidity Whether to set as liquidity adapter
     * @param capAbs Absolute cap in asset units
     * @param capRel Relative cap as a fraction (1 ether = 100%)
     */
    function addVaultV1(IVaultV2 vault, address vaultV1, bool liquidity, uint256 capAbs, uint256 capRel) public {
        _onlyVaultCreator(vault);

        // Create adapter
        address adapterMV1 = mv1AdapterFactory.createMorphoVaultV1Adapter(address(vault), vaultV1);
        bytes memory idData = abi.encode("this", adapterMV1);

        // Add adapter and set caps using submit/accept pattern
        vault.submit(abi.encodeWithSelector(vault.addAdapter.selector, adapterMV1));
        vault.addAdapter(adapterMV1);

        vault.submit(abi.encodeWithSelector(vault.increaseAbsoluteCap.selector, idData, capAbs));
        vault.increaseAbsoluteCap(idData, capAbs);

        vault.submit(abi.encodeWithSelector(vault.increaseRelativeCap.selector, idData, capRel));
        vault.increaseRelativeCap(idData, capRel);

        // Add a small grifting protection in case there really is retards on low cost chains
        vault.setForceDeallocatePenaltyInstant(adapterMV1, 0.00001 ether);

        // Optionally set as liquidity adapter
        if (liquidity) {
            vault.setLiquidityAdapterAndData(adapterMV1, "");
        }
    }

        /**
     * @notice Add a Morpho MetaMorpho vault as an adapter
     * @dev Creates adapter, adds it to vault, and sets caps
     * @param vault The VaultV2 to configure
     * @param box The Box address
     * @param capAbs Absolute cap in asset units
     * @param capRel Relative cap as a fraction (1 ether = 100%)
     */
    function addBox(IVaultV2 vault, address box, uint256 capAbs, uint256 capRel) public returns (address adapterBox) {
        _onlyVaultCreator(vault);

        // Create adapter
        adapterBox = address(boxAdapterFactory.createBoxAdapter(address(vault), IBox(box)));
        bytes memory idData = abi.encode("this", adapterBox);

        // Add adapter and set caps using submit/accept pattern
        vault.submit(abi.encodeWithSelector(vault.addAdapter.selector, adapterBox));
        vault.addAdapter(adapterBox);

        vault.submit(abi.encodeWithSelector(vault.increaseAbsoluteCap.selector, idData, capAbs));
        vault.increaseAbsoluteCap(idData, capAbs);

        vault.submit(abi.encodeWithSelector(vault.increaseRelativeCap.selector, idData, capRel));
        vault.increaseRelativeCap(idData, capRel);

        // Add a small grifting protection in case there really is retards on low cost chains
        vault.setForceDeallocatePenaltyInstant(adapterBox, 0.0001 ether);
    }


    /**
     * @notice Configure vault to use Morpho's adapter registry
     * @dev Sets registry and abdicates permission to change it
     * @param vault The vault to configure
     */
    function conformMorphoRegistry(IVaultV2 vault) public {
        _onlyVaultCreator(vault);

        // Set the correct adapter registry and abdicate
        vault.submit(abi.encodeWithSelector(vault.setAdapterRegistry.selector, morphoRegistry));
        vault.setAdapterRegistry(morphoRegistry);
        vault.submit(abi.encodeWithSelector(vault.abdicate.selector, vault.setAdapterRegistry.selector));
        vault.abdicate(vault.setAdapterRegistry.selector);
    }

    /**
     * @notice Create the Guardian DAO using LockToVote plugin and set the sentinel
     */
    function createGuardian(IVaultV2 vault) public returns (address guardian) {
        _onlyVaultCreator(vault);
        guardian = createGuardianDAO(vault, address(0));
        setRevoker(vault, guardian);
    }

    /**
     * @notice Create the Guardian DAO using LockToVote plugin + additional admin and set the sentinel
     */
    function createGuardianWithAdmin(IVaultV2 vault, address additionalGuardian) public returns (address guardian) {
        _onlyVaultCreator(vault);
        guardian = createGuardianDAO(vault, additionalGuardian);
        setRevoker(vault, guardian);
    }

    /**
     * @notice Perform timelocks and ACLs setup, then transfer ownership to default owner
     */
    function finalize(IVaultV2 vault, uint256 timelocks) public returns (address) {
        return finalize(vault, timelocks, address(0), address(0));
    }

    /**
     * @notice Perform timelocks and ACLs setup, then transfer ownership to default owner
     */
    function finalizeWithGuardian(IVaultV2 vault, uint256 timelocks, address guardian) public returns (address) {
        return finalize(vault, timelocks, guardian, address(0));
    }

    /**
     * @notice Perform timelocks and ACLs setup, then transfer ownership to default owner
     */
    function finalizeWithOwner(IVaultV2 vault, uint256 timelocks, address owner_) public returns (address) {
        return finalize(vault, timelocks, address(0), owner_);
    }

    /**
     * @notice Perform timelocks and ACLs setup, then transfer ownership to Owner DAO
     */
    function finalize(IVaultV2 vault, uint256 timelocks, address guardian, address owner_) public returns (address) {
        _onlyVaultCreator(vault);

        removeHelperAsAllocator(vault);
        setVaultTimelocks(vault, timelocks);

        setProductionCurator(vault);

        // If owner_ is empty use default
        if( owner_ == address(0)) {
            owner_ = owner;
        }

        if (guardian != address(0)) {
            address ownerDAO = createOwnerDAO(guardian, owner_, "");
            transferOwnership(vault, ownerDAO);
            return ownerDAO;
        } else {
            transferOwnership(vault, owner_);
            return owner_;
        }
    }

    /* ======== VAULT FINALIZATION ======== */

    /**
     * @notice Set all required timelocks on the vault
     * @dev Sets timelocks according to Morpho requirements (7 days for critical functions)
     * @param vault The vault to configure
     * @param capsDays Timelock for caps changes (typically 3 days)
     */
    function setVaultTimelocks(IVaultV2 vault, uint256 capsDays) public {
        _onlyVaultCreator(vault);

        // Morpho requires these to be 7 days
        vault.submit(abi.encodeWithSelector(vault.increaseTimelock.selector, vault.setReceiveAssetsGate.selector, 7 days));
        vault.increaseTimelock(vault.setReceiveAssetsGate.selector, 7 days);

        vault.submit(abi.encodeWithSelector(vault.increaseTimelock.selector, vault.setReceiveSharesGate.selector, 7 days));
        vault.increaseTimelock(vault.setReceiveSharesGate.selector, 7 days);

        vault.submit(abi.encodeWithSelector(vault.increaseTimelock.selector, vault.setSendSharesGate.selector, 7 days));
        vault.increaseTimelock(vault.setSendSharesGate.selector, 7 days);

        vault.submit(abi.encodeWithSelector(vault.increaseTimelock.selector, vault.setSendAssetsGate.selector, 7 days));
        vault.increaseTimelock(vault.setSendAssetsGate.selector, 7 days);

        vault.submit(abi.encodeWithSelector(vault.increaseTimelock.selector, vault.abdicate.selector, 7 days));
        vault.increaseTimelock(vault.abdicate.selector, 7 days);

        vault.submit(abi.encodeWithSelector(vault.increaseTimelock.selector, vault.setAdapterRegistry.selector, 7 days));
        vault.increaseTimelock(vault.setAdapterRegistry.selector, 7 days);

        vault.submit(abi.encodeWithSelector(vault.increaseTimelock.selector, vault.removeAdapter.selector, 7 days));
        vault.increaseTimelock(vault.removeAdapter.selector, 7 days);

        vault.submit(abi.encodeWithSelector(vault.increaseTimelock.selector, vault.setForceDeallocatePenalty.selector, 7 days));
        vault.increaseTimelock(vault.setForceDeallocatePenalty.selector, 7 days);

        // These can be 3 days for Morpho UI acceptance
        vault.submit(abi.encodeWithSelector(vault.increaseTimelock.selector, vault.addAdapter.selector, capsDays));
        vault.increaseTimelock(vault.addAdapter.selector, capsDays);

        vault.submit(abi.encodeWithSelector(vault.increaseTimelock.selector, vault.increaseRelativeCap.selector, capsDays));
        vault.increaseTimelock(vault.increaseRelativeCap.selector, capsDays);

        vault.submit(abi.encodeWithSelector(vault.increaseTimelock.selector, vault.increaseAbsoluteCap.selector, capsDays));
        vault.increaseTimelock(vault.increaseAbsoluteCap.selector, capsDays);

        // This must be last - 7 days minimum
        vault.submit(abi.encodeWithSelector(vault.increaseTimelock.selector, vault.increaseTimelock.selector, 7 days));
        vault.increaseTimelock(vault.increaseTimelock.selector, 7 days);
    }

    /**
     * @notice Set production curator on the vault
     * @dev Should be called after vault is configured but before ownership transfer
     * @param vault The vault to configure
     */
    function setProductionCurator(IVaultV2 vault) public {
        _onlyVaultCreator(vault);

        vault.setCurator(curator);
    }

    /**
     * @notice Remove helper from vault allocator list
     * @dev Should be called before transferring curator/ownership
     * @param vault The vault to clean up
     */
    function removeHelperAsAllocator(IVaultV2 vault) public {
        vault.submit(abi.encodeWithSelector(vault.setIsAllocator.selector, address(this), false));
        vault.setIsAllocator(address(this), false);
    }

    /* ======== GUARDIAN SETUP ======== */

    /**
     * @notice Deploy Revoker and set as vault sentinel
     * @dev Revoker connects guardian DAO to vault for emergency actions
     * @param vault The vault to configure
     * @param guardian Address of Guardian DAO (LockToVote)
     * @return revoker The deployed Revoker contract
     */
    function setRevoker(IVaultV2 vault, address guardian) public returns (address revoker) {
        _onlyVaultCreator(vault);

        // Deploy Revoker
        Revoker revokerContract = new Revoker(vault, guardian);
        revoker = address(revokerContract);

        // Set as sentinel
        vault.setIsSentinel(revoker, true);

        emit RevokerDeployed(address(vault), guardian, revoker);
    }

    /**
     * @notice Add an additional sentinel to the vault
     * @param vault The vault to configure
     * @param sentinel The sentinel address to add
     */
    function addSentinel(IVaultV2 vault, address sentinel) public {
        _onlyVaultCreator(vault);

        // Set as sentinel
        vault.setIsSentinel(sentinel, true);
    }

    /**
     * @notice create a Guardian DAO using LockToVote plugin using the vault shares
     */
    function createGuardianDAO(IVaultV2 vault, address admin) public returns (address) {
        _onlyVaultCreator(vault);

        DAOSettings memory daoSettings = DAOSettings({
            trustedForwarder: address(0),
            daoURI: "",
            subdomain: "",
            metadata: "ipfs://QmTke6dGx54zCEqiqok8W3YViBqz1LTt7yX7zAABvRVtvF"
        });

        PluginSettings[] memory pluginSettings = new PluginSettings[](0);

        (address dao, InstalledPlugin[] memory installedPlugins) = IDAOFactory(daoFactory).createDao(daoSettings, pluginSettings);

        bytes32 EXECUTE_PERMISSION_ID = keccak256("EXECUTE_PERMISSION");

        // If there is an admin we grant
        if (admin != address(0)) {
            address multisigplugin = addMultisigPlugin(IDAO(dao), admin);

            IDAO.Action[] memory grantActions = new IDAO.Action[](1);
            // Grant voting permission to the Multisig.
            grantActions[0] = IDAO.Action({
                to: dao,
                value: 0,
                data: abi.encodeWithSelector(IDAO.grant.selector, dao, multisigplugin, EXECUTE_PERMISSION_ID)
            });

            // Execute
            IDAO(dao).execute({_callId: "", _actions: grantActions, _allowFailureMap: 0});

            //
            bytes32 UPDATE_MULTISIG = keccak256("UPDATE_MULTISIG_SETTINGS_PERMISSION");
            bytes32 UPDATE_TARGET_CONFIG = keccak256("SET_TARGET_CONFIG_PERMISSION");

            IDAO.Action[] memory revokeActions = new IDAO.Action[](2);

            // 1. Revoke UPDATE_MULTISIG_SETTINGS_PERMISSION_ID from plugin
            revokeActions[0] = IDAO.Action({
                to: dao,
                value: 0,
                data: abi.encodeWithSelector(IDAO.revoke.selector, multisigplugin, dao, UPDATE_MULTISIG)
            });

            // 2. Revoke SET_TARGET_CONFIG_PERMISSION_ID from plugin
            revokeActions[1] = IDAO.Action({
                to: dao,
                value: 0,
                data: abi.encodeWithSelector(IDAO.revoke.selector, multisigplugin, dao, UPDATE_TARGET_CONFIG)
            });

            IDAO(dao).execute({_callId: "", _actions: revokeActions, _allowFailureMap: 0});
        }

        address plugin = addLockedVotePlugin(IDAO(dao), address(vault));

        // Create the action array
        IDAO.Action[] memory actions = new IDAO.Action[](4);

        bytes32 ROOT = keccak256("ROOT_PERMISSION");
        bytes32 UPGRADE = keccak256("UPGRADE_DAO_PERMISSION");
        bytes32 EXECUTE_PERMISSION = keccak256("EXECUTE_PERMISSION");     
        bytes32 UPDATE_VOTING = keccak256("UPDATE_SETTINGS_PERMISSION");

        // 1. Revoke UPDATE_VOTING_SETTINGS_PERMISSION from plugin
        actions[0] = IDAO.Action({to: dao, value: 0, data: abi.encodeWithSelector(IDAO.revoke.selector, plugin, dao, UPDATE_VOTING)});

        // 2. Revoke UPGRADE_DAO_PERMISSION from DAO
        actions[1] = IDAO.Action({to: dao, value: 0, data: abi.encodeWithSelector(IDAO.revoke.selector, dao, dao, UPGRADE)});

        // 3. Revoke EXECUTE_PERMISSION from VaultV2Helper
        actions[2] = IDAO.Action({to: dao, value: 0, data: abi.encodeWithSelector(IDAO.revoke.selector, dao, address(this), EXECUTE_PERMISSION)});

        // 4. Revoke ROOT_PERMISSION from DAO (makes it fully immutable)
        actions[3] = IDAO.Action({to: dao, value: 0, data: abi.encodeWithSelector(IDAO.revoke.selector, dao, dao, ROOT)});

        // Execute
        IDAO(dao).execute({_callId: "", _actions: actions, _allowFailureMap: 0});

        return dao;
    }

    function createOwnerDAO(address guardian, address daoOwner, string memory metadataURI) public returns (address) {
        DAOSettings memory daoSettings = DAOSettings({
            trustedForwarder: address(0),
            daoURI: "",
            subdomain: "",
            metadata: "ipfs://QmP7dhYX2HdVPQbhcu6a1oLjsWoqmwtWB5Bwk7Gajvehrb"
        });

        PluginSettings[] memory pluginSettings = new PluginSettings[](1);
        pluginSettings[0] = PluginSettings({
            pluginSetupRef: PluginSetupRef({versionTag: PluginSettingsTag({release: 1, build: 3}), pluginSetupRepo: multisigRepo}),
            data: _getMultisigData(guardian, daoOwner)
        });

        (address dao, InstalledPlugin[] memory installedPlugins) = IDAOFactory(daoFactory).createDao(daoSettings, pluginSettings);

        return dao;
    }

    function _revoke(address dao, address where, address who, bytes32 permission) internal {
        (bool ok, ) = dao.call(abi.encodeWithSignature("revoke(address,address,bytes32)", where, who, permission));
        require(ok, "Revoke failed");
    }
    /* ======== OWNERSHIP TRANSFER ======== */

    /**
     * @notice Transfer vault ownership to Owner DAO
     * @dev Final step in vault setup - transfers control to governance
     * @param vault The vault to transfer
     * @param newOwner Address of Owner DAO (2/2 multisig)
     */
    function transferOwnership(IVaultV2 vault, address newOwner) public {
        _onlyVaultCreator(vault);

        require(newOwner != address(0), "Invalid owner address");
        vault.setOwner(newOwner);
        emit VaultConfigured(address(vault));
    }

    /* ======== VIEW FUNCTIONS ======== */

    /**
     * @notice Get configured addresses for this chain
     */
    function getConfig()
        external
        view
        returns (
            address _owner,
            address _curator,
            address[] memory _allocators,
            address _morphoRegistry,
            address _vaultV2Factory,
            address _mv1AdapterFactory
        )
    {
        return (owner, curator, allocators, morphoRegistry, address(vaultV2Factory), address(mv1AdapterFactory));
    }

    /* ======== INTERNAL FUNCTIONS ======== */

    function _getLockToVoteData(address votingToken) internal pure returns (bytes memory) {
        // Create the exact struct that prepareInstallation expects
        InstallationParameters memory params = InstallationParameters({
            token: votingToken,
            votingSettings: VotingSettings({
                votingMode: 0,
                supportThreshold: 500000, // 50%
                minParticipation: 1, // 0.0001%
                minApprovalRatio: 0,
                proposalDuration: 1 days,
                minProposerVotingPower: 1
            }),
            pluginMetadata: "",
            createProposalCaller: address(type(uint160).max),
            executeCaller: address(type(uint160).max),
            targetConfig: TargetConfig({target: address(0), operation: 0})
        });

        // Now encode it properly - Solidity will handle the nested struct encoding correctly
        return abi.encode(params);
    }

    function _getMultisigData(address guardian, address _owner) internal pure returns (bytes memory) {
        address[] memory members = new address[](2);
        members[0] = guardian;
        members[1] = _owner;

        return
            abi.encode(
                members,
                false, // onlyListed
                uint16(2), // minApprovals (2/2)
                address(0), // target address
                0, // operation type
                "ipfs://QmeCvj5xo55cHHqmRQhKzTMX6AYACeYG8z2DgD6g16tJ2x" // metadata
            );
    }

    function _getMultisigDataOnePartner(address partner) internal pure returns (bytes memory) {
        address[] memory members = new address[](1);
        members[0] = partner;

        return
            abi.encode(
                members,
                false, // onlyListed
                uint16(1), // minApprovals (2/2)
                address(0), // target address
                0, // operation type
                "ipfs://QmeCvj5xo55cHHqmRQhKzTMX6AYACeYG8z2DgD6g16tJ2x" // metadata
            );
    }

    function addMultisigPlugin(IDAO dao, address partner) internal returns (address) {
        address daoAddress = address(dao);

        PluginSettings memory pluginSettings = PluginSettings({
            pluginSetupRef: PluginSetupRef({versionTag: PluginSettingsTag({release: 1, build: 3}), pluginSetupRepo: multisigRepo}),
            data: _getMultisigDataOnePartner(partner)
        });

        IPluginSetupProcessor pluginSetupProcessor = IPluginSetupProcessor(address(daoFactory.pluginSetupProcessor()));

        IDAO.Action[] memory actions = new IDAO.Action[](2);

        // Grant Temporarily `ROOT_PERMISSION` to `pluginSetupProcessor`.
        actions[0] = IDAO.Action({
            to: daoAddress,
            value: 0,
            data: abi.encodeWithSelector(IDAO.grant.selector, daoAddress, address(pluginSetupProcessor), dao.ROOT_PERMISSION_ID())
        });

        // Grant Temporarily `APPLY_INSTALLATION_PERMISSION` on `pluginSetupProcessor` to this `DAOFactory`.
        actions[1] = IDAO.Action({
            to: daoAddress,
            value: 0,
            data: abi.encodeWithSelector(
                IDAO.grant.selector,
                address(pluginSetupProcessor),
                address(this),
                keccak256("APPLY_INSTALLATION_PERMISSION")
            )
        });

        // Execute
        IDAO(dao).execute({_callId: "", _actions: actions, _allowFailureMap: 0});

        (address plugin, IPluginSetup.PreparedSetupData memory preparedSetupData) = pluginSetupProcessor.prepareInstallation(
            daoAddress,
            IPluginSetupProcessor.PrepareInstallationParams({pluginSetupRef: pluginSettings.pluginSetupRef, data: pluginSettings.data})
        );

        // Apply plugin.
        pluginSetupProcessor.applyInstallation(
            daoAddress,
            IPluginSetupProcessor.ApplyInstallationParams({
                pluginSetupRef: pluginSettings.pluginSetupRef,
                plugin: plugin,
                permissions: preparedSetupData.permissions,
                helpersHash: keccak256(abi.encode(preparedSetupData.helpers))
            })
        );

        // Revoke Temporarily `ROOT_PERMISSION` from `pluginSetupProcessor`.
        actions[0] = IDAO.Action({
            to: daoAddress,
            value: 0,
            data: abi.encodeWithSelector(IDAO.revoke.selector, daoAddress, address(pluginSetupProcessor), dao.ROOT_PERMISSION_ID())
        });

        // Revoke Temporarily `APPLY_INSTALLATION_PERMISSION` on `pluginSetupProcessor` from this `DAOFactory`.
        actions[1] = IDAO.Action({
            to: daoAddress,
            value: 0,
            data: abi.encodeWithSelector(
                IDAO.revoke.selector,
                address(pluginSetupProcessor),
                address(this),
                keccak256("APPLY_INSTALLATION_PERMISSION")
            )
        });

        // Execute
        IDAO(dao).execute({_callId: "", _actions: actions, _allowFailureMap: 0});

        return plugin;
    }
    function addLockedVotePlugin(IDAO dao, address vault) internal returns (address) {
        address daoAddress = address(dao);

        PluginSettings memory pluginSettings = PluginSettings({
            pluginSetupRef: PluginSetupRef({versionTag: PluginSettingsTag({release: 1, build: 1}), pluginSetupRepo: lockToVoteRepo}),
            data: _getLockToVoteData(vault)
        });

        IPluginSetupProcessor pluginSetupProcessor = IPluginSetupProcessor(address(daoFactory.pluginSetupProcessor()));

        // Create the action array
        IDAO.Action[] memory actions = new IDAO.Action[](2);

        // Grant Temporarily `ROOT_PERMISSION` to `pluginSetupProcessor`.
        actions[0] = IDAO.Action({
            to: daoAddress,
            value: 0,
            data: abi.encodeWithSelector(IDAO.grant.selector, daoAddress, address(pluginSetupProcessor), dao.ROOT_PERMISSION_ID())
        });

        // Grant Temporarily `APPLY_INSTALLATION_PERMISSION` on `pluginSetupProcessor` to this `DAOFactory`.
        actions[1] = IDAO.Action({
            to: daoAddress,
            value: 0,
            data: abi.encodeWithSelector(
                IDAO.grant.selector,
                address(pluginSetupProcessor),
                address(this),
                keccak256("APPLY_INSTALLATION_PERMISSION")
            )
        });
        // Execute
        IDAO(dao).execute({_callId: "", _actions: actions, _allowFailureMap: 0});

        (address plugin, IPluginSetup.PreparedSetupData memory preparedSetupData) = pluginSetupProcessor.prepareInstallation(
            daoAddress,
            IPluginSetupProcessor.PrepareInstallationParams(pluginSettings.pluginSetupRef, pluginSettings.data)
        );

        // Apply plugin.
        pluginSetupProcessor.applyInstallation(
            daoAddress,
            IPluginSetupProcessor.ApplyInstallationParams(
                pluginSettings.pluginSetupRef,
                plugin,
                preparedSetupData.permissions,
                keccak256(abi.encode((preparedSetupData.helpers)))
            )
        );

        // Revoke Temporarily `ROOT_PERMISSION` to `pluginSetupProcessor`.
        actions[0] = IDAO.Action({
            to: daoAddress,
            value: 0,
            data: abi.encodeWithSelector(IDAO.revoke.selector, daoAddress, address(pluginSetupProcessor), dao.ROOT_PERMISSION_ID())
        });

        // Revoke Temporarily `APPLY_INSTALLATION_PERMISSION` on `pluginSetupProcessor` to this `DAOFactory`.
        actions[1] = IDAO.Action({
            to: daoAddress,
            value: 0,
            data: abi.encodeWithSelector(
                IDAO.revoke.selector,
                address(pluginSetupProcessor),
                address(this),
                keccak256("APPLY_INSTALLATION_PERMISSION")
            )
        });

        // Execute
        IDAO(dao).execute({_callId: "", _actions: actions, _allowFailureMap: 0});

        return plugin;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity >=0.6.2;

import {IERC20} from "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity 0.8.28;

import {MorphoVaultV1Adapter} from "./MorphoVaultV1Adapter.sol";
import {IMorphoVaultV1AdapterFactory} from "./interfaces/IMorphoVaultV1AdapterFactory.sol";

contract MorphoVaultV1AdapterFactory is IMorphoVaultV1AdapterFactory {
    /* STORAGE */

    mapping(address parentVault => mapping(address morphoVaultV1 => address)) public morphoVaultV1Adapter;
    mapping(address account => bool) public isMorphoVaultV1Adapter;

    /* FUNCTIONS */

    /// @dev Returns the address of the deployed MorphoVaultV1Adapter.
    function createMorphoVaultV1Adapter(address parentVault, address morphoVaultV1) external returns (address) {
        address _morphoVaultV1Adapter = address(new MorphoVaultV1Adapter{salt: bytes32(0)}(parentVault, morphoVaultV1));
        morphoVaultV1Adapter[parentVault][morphoVaultV1] = _morphoVaultV1Adapter;
        isMorphoVaultV1Adapter[_morphoVaultV1Adapter] = true;
        emit CreateMorphoVaultV1Adapter(parentVault, morphoVaultV1, _morphoVaultV1Adapter);
        return _morphoVaultV1Adapter;
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity >=0.5.0;

import {IERC20} from "./IERC20.sol";
import {IERC4626} from "./IERC4626.sol";
import {IERC2612} from "./IERC2612.sol";

struct Caps {
    uint256 allocation;
    uint128 absoluteCap;
    uint128 relativeCap;
}

interface IVaultV2 is IERC4626, IERC2612 {
    // State variables
    function virtualShares() external view returns (uint256);
    function owner() external view returns (address);
    function curator() external view returns (address);
    function receiveSharesGate() external view returns (address);
    function sendSharesGate() external view returns (address);
    function receiveAssetsGate() external view returns (address);
    function sendAssetsGate() external view returns (address);
    function adapterRegistry() external view returns (address);
    function isSentinel(address account) external view returns (bool);
    function isAllocator(address account) external view returns (bool);
    function firstTotalAssets() external view returns (uint256);
    function _totalAssets() external view returns (uint128);
    function lastUpdate() external view returns (uint64);
    function maxRate() external view returns (uint64);
    function adapters(uint256 index) external view returns (address);
    function adaptersLength() external view returns (uint256);
    function isAdapter(address account) external view returns (bool);
    function allocation(bytes32 id) external view returns (uint256);
    function absoluteCap(bytes32 id) external view returns (uint256);
    function relativeCap(bytes32 id) external view returns (uint256);
    function forceDeallocatePenalty(address adapter) external view returns (uint256);
    function liquidityAdapter() external view returns (address);
    function liquidityData() external view returns (bytes memory);
    function timelock(bytes4 selector) external view returns (uint256);
    function abdicated(bytes4 selector) external view returns (bool);
    function executableAt(bytes memory data) external view returns (uint256);
    function performanceFee() external view returns (uint96);
    function performanceFeeRecipient() external view returns (address);
    function managementFee() external view returns (uint96);
    function managementFeeRecipient() external view returns (address);

    // Gating
    function canSendShares(address account) external view returns (bool);
    function canReceiveShares(address account) external view returns (bool);
    function canSendAssets(address account) external view returns (bool);
    function canReceiveAssets(address account) external view returns (bool);

    // Multicall
    function multicall(bytes[] memory data) external;

    // Owner functions
    function setOwner(address newOwner) external;
    function setCurator(address newCurator) external;
    function setIsSentinel(address account, bool isSentinel) external;
    function setName(string memory newName) external;
    function setSymbol(string memory newSymbol) external;

    // Timelocks for curator functions
    function submit(bytes memory data) external;
    function revoke(bytes memory data) external;

    // Curator functions
    function setIsAllocator(address account, bool newIsAllocator) external;
    function setReceiveSharesGate(address newReceiveSharesGate) external;
    function setSendSharesGate(address newSendSharesGate) external;
    function setReceiveAssetsGate(address newReceiveAssetsGate) external;
    function setSendAssetsGate(address newSendAssetsGate) external;
    function setAdapterRegistry(address newAdapterRegistry) external;
    function addAdapter(address account) external;
    function removeAdapter(address account) external;
    function increaseTimelock(bytes4 selector, uint256 newDuration) external;
    function decreaseTimelock(bytes4 selector, uint256 newDuration) external;
    function abdicate(bytes4 selector) external;
    function setPerformanceFee(uint256 newPerformanceFee) external;
    function setManagementFee(uint256 newManagementFee) external;
    function setPerformanceFeeRecipient(address newPerformanceFeeRecipient) external;
    function setManagementFeeRecipient(address newManagementFeeRecipient) external;
    function increaseAbsoluteCap(bytes memory idData, uint256 newAbsoluteCap) external;
    function decreaseAbsoluteCap(bytes memory idData, uint256 newAbsoluteCap) external;
    function increaseRelativeCap(bytes memory idData, uint256 newRelativeCap) external;
    function decreaseRelativeCap(bytes memory idData, uint256 newRelativeCap) external;
    function setMaxRate(uint256 newMaxRate) external;
    function setForceDeallocatePenalty(address adapter, uint256 newForceDeallocatePenalty) external;

    // Allocator functions
    function allocate(address adapter, bytes memory data, uint256 assets) external;
    function deallocate(address adapter, bytes memory data, uint256 assets) external;
    function setLiquidityAdapterAndData(address newLiquidityAdapter, bytes memory newLiquidityData) external;

    // Exchange rate
    function accrueInterest() external;
    function accrueInterestView()
        external
        view
        returns (uint256 newTotalAssets, uint256 performanceFeeShares, uint256 managementFeeShares);

    // Force deallocate
    function forceDeallocate(address adapter, bytes memory data, uint256 assets, address onBehalf)
        external
        returns (uint256 penaltyShares);
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity ^0.8.0;

uint256 constant WAD = 1e18;
bytes32 constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
bytes32 constant PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
uint256 constant MAX_MAX_RATE = 200e16 / uint256(365 days); // 200% APR
uint256 constant MAX_PERFORMANCE_FEE = 0.5e18; // 50%
uint256 constant MAX_MANAGEMENT_FEE = 0.05e18 / uint256(365 days); // 5%
uint256 constant MAX_FORCE_DEALLOCATE_PENALTY = 0.02e18; // 2%

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity 0.8.28;

import {IVaultV2, IERC20, Caps} from "./interfaces/IVaultV2.sol";
import {IAdapter} from "./interfaces/IAdapter.sol";
import {IAdapterRegistry} from "./interfaces/IAdapterRegistry.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import "./libraries/ConstantsLib.sol";
import {MathLib} from "./libraries/MathLib.sol";
import {SafeERC20Lib} from "./libraries/SafeERC20Lib.sol";
import {IReceiveSharesGate, ISendSharesGate, IReceiveAssetsGate, ISendAssetsGate} from "./interfaces/IGate.sol";

/// ERC4626
/// @dev The vault is compliant with ERC-4626 and with ERC-2612 (permit extension). Though the vault has a
/// non-conventional behaviour on max functions: they always return zero.
/// @dev totalSupply is not updated to include shares minted to fee recipients. One can call accrueInterestView to
/// compute the updated totalSupply.
///
/// TOTAL ASSETS
/// @dev Adapters are responsible for reporting to the vault how much their investments are worth at any time, so that
/// the vault can accrue interest or realize losses.
/// @dev _totalAssets stores the last recorded total assets. Use totalAssets() for the updated total assets.
/// @dev Upon interest accrual, the vault loops through adapters' realAssets(). If there are too many adapters and/or
/// they consume too much gas on realAssets(), it could cause issues such as expensive interactions, even DOS.
///
/// LOSS REALIZATION
/// @dev Loss realization occurs in accrueInterest and decreases the total assets, causing shares to lose value.
/// @dev Vault shares should not be loanable to prevent shares shorting on loss realization. Shares can be flashloanable
/// because flashloan-based shorting is prevented as interests and losses are only accounted once per transaction.
///
/// SHARE PRICE
/// @dev The share price can go down if the vault incurs some losses. Users might want to perform slippage checks upon
/// withdraw/redeem via an other contract.
/// @dev Interest/loss are accounted only once per transaction (at the first interaction with the vault).
/// @dev Donations increase the share price but not faster than the maxRate.
/// @dev The vault has 1 virtual asset and a decimal offset of max(0, 18 - assetDecimals). In order to protect against
/// inflation attacks, the vault might need to be seeded with an initial deposit. See
/// https://docs.openzeppelin.com/contracts/5.x/erc4626#inflation-attack
/// @dev Donations and forceDeallocate penalties increase the rate, which can attract opportunistic depositors which
/// will dilute interest. This fact can be mitigated by reducing the maxRate.
///
/// CAPS
/// @dev Ids have an asset allocation, and can be absolutely capped and/or relatively capped.
/// @dev The allocation is not always up to date, because interest and losses are accounted only when (de)allocating in
/// the corresponding markets.
/// @dev The caps are checked on allocate (where allocations can increase) for the ids returned by the adapter.
/// @dev Relative caps are "soft" in the sense that they are not checked on exit.
/// @dev Caps can be exceeded because of interest.
/// @dev The relative cap is relative to firstTotalAssets, not realAssets.
/// @dev The relative cap unit is WAD.
/// @dev To track allocations using events, use the Allocate and Deallocate events only.
///
/// FIRST TOTAL ASSETS
/// @dev The variable firstTotalAssets tracks the total assets after the first interest accrual of the transaction.
/// @dev Used to implement a mechanism that prevents bypassing relative caps with flashloans. This mechanism makes the
/// caps conservative and can generate false positives, notably for big deposits that go through the liquidity adapter.
/// @dev Also used to accrue interest only once per transaction (see the "share price" section).
/// @dev Relative caps can still be manipulated by allocators (with short-term deposits), but it requires capital.
/// @dev The behavior of firstTotalAssets is different when the vault has totalAssets=0, but it does not matter
/// internally because in this case there are no investments to cap.
///
/// ADAPTERS
/// @dev Loose specification of adapters:
/// - They must enforce that only the vault can call allocate/deallocate.
/// - They must enter/exit markets only in allocate/deallocate.
/// - They must return the right ids on allocate/deallocate. Returned ids must not repeat.
/// - After a call to deallocate, the vault must have an approval to transfer at least `assets` from the adapter.
/// - They must make it possible to make deallocate possible (for in-kind redemptions).
/// - The totalAssets() calculation ignores markets for which the vault has no allocation.
/// - They must not re-enter (directly or indirectly) the vault. They might not statically prevent it, but the curator
/// must not interact with markets that can re-enter the vault.
/// - After an update, the sum of the changes returned after interactions with a given market must be exactly the
/// current estimated position.
/// @dev Ids being reused are useful to cap multiple investments that have a common property.
/// @dev Allocating is prevented if one of the ids' absolute cap is zero and deallocating is prevented if the id's
/// allocation is zero. This prevents interactions with zero assets with unknown markets. For markets that share all
/// their ids, it will be impossible to "disable" them (preventing any interaction) without disabling the others using
/// the same ids.
/// @dev On allocate or deallocate, the adapters might lose some assets (total realAssets decreases), for instance due
/// to roundings or entry/exit fees. This loss should stay negligible compared to gas. Adapters might not statically
/// ensure this, but the curators should not interact with markets that can create big entry/exit losses.
/// @dev Except particular scenarios, adapters should be removed only if they have no assets. In order to ensure no
/// allocator can allocate some assets in an adapter being removed, there should be an id exclusive to the adapter with
/// its cap set to zero.
///
/// ADAPTER REGISTRY
/// @dev An adapter registry can be added to restrict the adapters. This is useful to commit to using only a certain
/// type of adapters for example.
/// @dev If adapterRegistry is set to address(0), the vault can have any adapters.
/// @dev When an adapterRegistry is set, it retroactively checks already added adapters.
/// @dev If the adapterRegistry now returns false for an already added adapter, it doesn't impact the vault's
/// functioning.
/// @dev The invariant that adapters of the vault are all in the registry holds only if the registry cannot remove
/// adapters (is "add only").
///
/// LIQUIDITY ADAPTER
/// @dev Liquidity is allocated to the liquidityAdapter on deposit/mint, and deallocated from the liquidityAdapter on
/// withdraw/redeem if idle assets don't cover the withdrawal.
/// @dev The liquidity adapter is useful on exit, so that exit liquidity is available in addition to the idle assets. But
/// the same adapter/data is used for both entry and exit to have the property that in the general case looping
/// supply-withdraw or withdraw-supply should not change the allocation.
/// @dev If a cap (absolute or relative) associated with the ids returned by the liquidity adapter on the liquidity data
/// is reached, deposit/mint will revert. In particular, when the vault is empty or almost empty, the relative cap check
/// is likely to make deposits revert.
///
/// TOKEN REQUIREMENTS
/// @dev List of assumptions on the token that guarantees that the vault behaves as expected:
/// - It should be ERC-20 compliant, except that it can omit return values on transfer and transferFrom.
/// - The balance of the vault should only decrease on transfer and transferFrom.
/// - It should not re-enter the vault on transfer or transferFrom.
/// - The balance of the sender (resp. receiver) should decrease (resp. increase) by exactly the given amount on
/// transfer and transferFrom. In particular, tokens with fees on transfer are not supported.
///
/// LIVENESS REQUIREMENTS
/// @dev List of assumptions that guarantees the vault's liveness properties:
/// - Adapters should not revert on realAssets.
/// - The token should not revert on transfer and transferFrom if balances and approvals are right.
/// - The token should not revert on transfer to self.
/// - totalAssets and totalSupply must stay below ~10^35. Initially there are min(1, 10^(18-decimals)) shares per asset.
/// - The vault is pinged at least every 10 years.
/// - Adapters must not revert on deallocate if the underlying markets are liquid.
///
/// TIMELOCKS
/// @dev The timelock duration of decreaseTimelock is the timelock duration of the function whose timelock is being
/// decreased (e.g. the timelock of decreaseTimelock(addAdapter, ...) is timelock[addAdapter]).
/// @dev It is still possible to submit changes of the timelock duration of decreaseTimelock, but it won't have any
/// effect (and trying to execute this change will revert).
/// @dev Multiple clashing data can be pending, for example increaseCap and decreaseCap, which can make so accepted
/// timelocked data can potentially be changed shortly afterwards.
/// @dev If a function is abdicated, it cannot be called no matter its timelock and what executableAt[data] contains.
/// Otherwise, the minimum time in which a function can be called is the following:
/// min(
///     timelock[selector],
///     executableAt[selector::_],
///     executableAt[decreaseTimelock::selector::newTimelock] + newTimelock
/// ).
/// @dev Nothing is checked on the timelocked data, so it could be not executable (function does not exist, argument
/// encoding is wrong, function' conditions are not met, etc.).
///
/// ABDICATION
/// @dev When a timelocked function is abdicated, it can't be called anymore.
/// @dev It is still possible to submit data for it or change its timelock, but it will not be executable / effective.
///
/// GATES
/// @dev Set to 0 to disable a gate.
/// @dev Gates must never revert, nor consume too much gas.
/// @dev receiveSharesGate:
///     - Gates receiving shares.
///     - Can lock users out of getting back their shares deposited on an other contract.
/// @dev sendSharesGate:
///     - Gates sending shares.
///     - Can lock users out of exiting the vault.
/// @dev receiveAssetsGate:
///     - Gates withdrawing assets from the vault.
///     - The vault itself (address(this)) is always allowed to receive assets, regardless of the gate configuration.
///     - Can lock users out of exiting the vault.
/// @dev sendAssetsGate:
///     - Gates depositing assets to the vault.
///     - This gate is not critical (cannot block users' funds), while still being able to gate supplies.
///
/// FEES
/// @dev Fees unit is WAD.
/// @dev This invariant holds for both fees: fee != 0 => recipient != address(0).
///
/// ROLES
/// @dev The owner cannot do actions that can directly hurt depositors. Though it can set the curator and sentinels.
/// @dev The curator cannot do actions that can directly hurt depositors without going through a timelock.
/// @dev Allocators can move funds between markets in the boundaries set by caps without going through timelocks. They
/// can also set the liquidity adapter and data, which can prevent deposits and/or withdrawals (it cannot prevent
/// "in-kind redemptions" with forceDeallocate though). Allocators also set the maxRate.
/// @dev Warning: if setIsAllocator is timelocked, removing an allocator will take time.
/// @dev Roles are not "two-step", so anyone can give a role to anyone, but it does not mean that they will exercise it.
///
/// MISC
/// @dev Zero checks are not systematically performed.
/// @dev No-ops are allowed.
/// @dev NatSpec comments are included only when they bring clarity.
/// @dev The contract uses transient storage.
/// @dev At creation, all settings are set to their default values. Notably, timelocks are zero which is useful to set
/// up the vault quickly. Also, there are no gates so anybody can interact with the vault. To prevent that, the gates
/// configuration can be batched with the vault creation.
contract VaultV2 is IVaultV2 {
    using MathLib for uint256;
    using MathLib for uint128;
    using MathLib for int256;

    /* IMMUTABLE */

    address public immutable asset;
    uint8 public immutable decimals;
    uint256 public immutable virtualShares;

    /* ROLES STORAGE */

    address public owner;
    address public curator;
    address public receiveSharesGate;
    address public sendSharesGate;
    address public receiveAssetsGate;
    address public sendAssetsGate;
    address public adapterRegistry;
    mapping(address account => bool) public isSentinel;
    mapping(address account => bool) public isAllocator;

    /* TOKEN STORAGE */

    string public name;
    string public symbol;
    uint256 public totalSupply;
    mapping(address account => uint256) public balanceOf;
    mapping(address owner => mapping(address spender => uint256)) public allowance;
    mapping(address account => uint256) public nonces;

    /* INTEREST STORAGE */

    uint256 public transient firstTotalAssets;
    uint128 public _totalAssets;
    uint64 public lastUpdate;
    uint64 public maxRate;

    /* CURATION STORAGE */

    mapping(address account => bool) public isAdapter;
    address[] public adapters;
    mapping(bytes32 id => Caps) internal caps;
    mapping(address adapter => uint256) public forceDeallocatePenalty;

    /* LIQUIDITY ADAPTER STORAGE */

    address public liquidityAdapter;
    bytes public liquidityData;

    /* TIMELOCKS STORAGE */

    mapping(bytes4 selector => uint256) public timelock;
    mapping(bytes4 selector => bool) public abdicated;
    mapping(bytes data => uint256) public executableAt;

    /* FEES STORAGE */

    uint96 public performanceFee;
    address public performanceFeeRecipient;
    uint96 public managementFee;
    address public managementFeeRecipient;

    /* GETTERS */

    function adaptersLength() external view returns (uint256) {
        return adapters.length;
    }

    function totalAssets() external view returns (uint256) {
        (uint256 newTotalAssets,,) = accrueInterestView();
        return newTotalAssets;
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, block.chainid, address(this)));
    }

    function absoluteCap(bytes32 id) external view returns (uint256) {
        return caps[id].absoluteCap;
    }

    function relativeCap(bytes32 id) external view returns (uint256) {
        return caps[id].relativeCap;
    }

    function allocation(bytes32 id) external view returns (uint256) {
        return caps[id].allocation;
    }

    /* MULTICALL */

    /// @dev Useful for EOAs to batch admin calls.
    /// @dev Does not return anything, because accounts who would use the return data would be contracts, which can do
    /// the multicall themselves.
    function multicall(bytes[] calldata data) external {
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory returnData) = address(this).delegatecall(data[i]);
            if (!success) {
                assembly ("memory-safe") {
                    revert(add(32, returnData), mload(returnData))
                }
            }
        }
    }

    /* CONSTRUCTOR */

    constructor(address _owner, address _asset) {
        asset = _asset;
        owner = _owner;
        lastUpdate = uint64(block.timestamp);
        uint256 assetDecimals = IERC20(_asset).decimals();
        uint256 decimalOffset = uint256(18).zeroFloorSub(assetDecimals);
        decimals = uint8(assetDecimals + decimalOffset);
        virtualShares = 10 ** decimalOffset;
        emit EventsLib.Constructor(_owner, _asset);
    }

    /* OWNER FUNCTIONS */

    function setOwner(address newOwner) external {
        require(msg.sender == owner, ErrorsLib.Unauthorized());
        owner = newOwner;
        emit EventsLib.SetOwner(newOwner);
    }

    function setCurator(address newCurator) external {
        require(msg.sender == owner, ErrorsLib.Unauthorized());
        curator = newCurator;
        emit EventsLib.SetCurator(newCurator);
    }

    function setIsSentinel(address account, bool newIsSentinel) external {
        require(msg.sender == owner, ErrorsLib.Unauthorized());
        isSentinel[account] = newIsSentinel;
        emit EventsLib.SetIsSentinel(account, newIsSentinel);
    }

    function setName(string memory newName) external {
        require(msg.sender == owner, ErrorsLib.Unauthorized());
        name = newName;
        emit EventsLib.SetName(newName);
    }

    function setSymbol(string memory newSymbol) external {
        require(msg.sender == owner, ErrorsLib.Unauthorized());
        symbol = newSymbol;
        emit EventsLib.SetSymbol(newSymbol);
    }

    /* TIMELOCKS FOR CURATOR FUNCTIONS */

    /// @dev Will revert if the timelock value is type(uint256).max or any value that overflows when added to the block
    /// timestamp.
    function submit(bytes calldata data) external {
        require(msg.sender == curator, ErrorsLib.Unauthorized());
        require(executableAt[data] == 0, ErrorsLib.DataAlreadyPending());

        bytes4 selector = bytes4(data);
        uint256 _timelock =
            selector == IVaultV2.decreaseTimelock.selector ? timelock[bytes4(data[4:8])] : timelock[selector];
        executableAt[data] = block.timestamp + _timelock;
        emit EventsLib.Submit(selector, data, executableAt[data]);
    }

    function timelocked() internal {
        bytes4 selector = bytes4(msg.data);
        require(executableAt[msg.data] != 0, ErrorsLib.DataNotTimelocked());
        require(block.timestamp >= executableAt[msg.data], ErrorsLib.TimelockNotExpired());
        require(!abdicated[selector], ErrorsLib.Abdicated());
        executableAt[msg.data] = 0;
        emit EventsLib.Accept(selector, msg.data);
    }

    function revoke(bytes calldata data) external {
        require(msg.sender == curator || isSentinel[msg.sender], ErrorsLib.Unauthorized());
        require(executableAt[data] != 0, ErrorsLib.DataNotTimelocked());
        executableAt[data] = 0;
        bytes4 selector = bytes4(data);
        emit EventsLib.Revoke(msg.sender, selector, data);
    }

    /* CURATOR FUNCTIONS */

    function setIsAllocator(address account, bool newIsAllocator) external {
        timelocked();
        isAllocator[account] = newIsAllocator;
        emit EventsLib.SetIsAllocator(account, newIsAllocator);
    }

    function setReceiveSharesGate(address newReceiveSharesGate) external {
        timelocked();
        receiveSharesGate = newReceiveSharesGate;
        emit EventsLib.SetReceiveSharesGate(newReceiveSharesGate);
    }

    function setSendSharesGate(address newSendSharesGate) external {
        timelocked();
        sendSharesGate = newSendSharesGate;
        emit EventsLib.SetSendSharesGate(newSendSharesGate);
    }

    function setReceiveAssetsGate(address newReceiveAssetsGate) external {
        timelocked();
        receiveAssetsGate = newReceiveAssetsGate;
        emit EventsLib.SetReceiveAssetsGate(newReceiveAssetsGate);
    }

    function setSendAssetsGate(address newSendAssetsGate) external {
        timelocked();
        sendAssetsGate = newSendAssetsGate;
        emit EventsLib.SetSendAssetsGate(newSendAssetsGate);
    }

    /// @dev The no-op will revert if the registry now returns false for an already added adapter.
    function setAdapterRegistry(address newAdapterRegistry) external {
        timelocked();

        if (newAdapterRegistry != address(0)) {
            for (uint256 i = 0; i < adapters.length; i++) {
                require(
                    IAdapterRegistry(newAdapterRegistry).isInRegistry(adapters[i]), ErrorsLib.NotInAdapterRegistry()
                );
            }
        }

        adapterRegistry = newAdapterRegistry;
        emit EventsLib.SetAdapterRegistry(newAdapterRegistry);
    }

    function addAdapter(address account) external {
        timelocked();
        require(
            adapterRegistry == address(0) || IAdapterRegistry(adapterRegistry).isInRegistry(account),
            ErrorsLib.NotInAdapterRegistry()
        );
        if (!isAdapter[account]) {
            adapters.push(account);
            isAdapter[account] = true;
        }
        emit EventsLib.AddAdapter(account);
    }

    function removeAdapter(address account) external {
        timelocked();
        if (isAdapter[account]) {
            for (uint256 i = 0; i < adapters.length; i++) {
                if (adapters[i] == account) {
                    adapters[i] = adapters[adapters.length - 1];
                    adapters.pop();
                    break;
                }
            }
            isAdapter[account] = false;
        }
        emit EventsLib.RemoveAdapter(account);
    }

    /// @dev This function requires great caution because it can irreversibly disable submit for a selector.
    /// @dev Existing pending operations submitted before increasing a timelock can still be executed at the initial
    /// executableAt.
    function increaseTimelock(bytes4 selector, uint256 newDuration) external {
        timelocked();
        require(selector != IVaultV2.decreaseTimelock.selector, ErrorsLib.AutomaticallyTimelocked());
        require(newDuration >= timelock[selector], ErrorsLib.TimelockNotIncreasing());

        timelock[selector] = newDuration;
        emit EventsLib.IncreaseTimelock(selector, newDuration);
    }

    function decreaseTimelock(bytes4 selector, uint256 newDuration) external {
        timelocked();
        require(selector != IVaultV2.decreaseTimelock.selector, ErrorsLib.AutomaticallyTimelocked());
        require(newDuration <= timelock[selector], ErrorsLib.TimelockNotDecreasing());

        timelock[selector] = newDuration;
        emit EventsLib.DecreaseTimelock(selector, newDuration);
    }

    function abdicate(bytes4 selector) external {
        timelocked();
        abdicated[selector] = true;
        emit EventsLib.Abdicate(selector);
    }

    function setPerformanceFee(uint256 newPerformanceFee) external {
        timelocked();
        require(newPerformanceFee <= MAX_PERFORMANCE_FEE, ErrorsLib.FeeTooHigh());
        require(performanceFeeRecipient != address(0) || newPerformanceFee == 0, ErrorsLib.FeeInvariantBroken());

        accrueInterest();

        // Safe because 2**96 > MAX_PERFORMANCE_FEE.
        performanceFee = uint96(newPerformanceFee);
        emit EventsLib.SetPerformanceFee(newPerformanceFee);
    }

    function setManagementFee(uint256 newManagementFee) external {
        timelocked();
        require(newManagementFee <= MAX_MANAGEMENT_FEE, ErrorsLib.FeeTooHigh());
        require(managementFeeRecipient != address(0) || newManagementFee == 0, ErrorsLib.FeeInvariantBroken());

        accrueInterest();

        // Safe because 2**96 > MAX_MANAGEMENT_FEE.
        managementFee = uint96(newManagementFee);
        emit EventsLib.SetManagementFee(newManagementFee);
    }

    function setPerformanceFeeRecipient(address newPerformanceFeeRecipient) external {
        timelocked();
        require(newPerformanceFeeRecipient != address(0) || performanceFee == 0, ErrorsLib.FeeInvariantBroken());

        accrueInterest();

        performanceFeeRecipient = newPerformanceFeeRecipient;
        emit EventsLib.SetPerformanceFeeRecipient(newPerformanceFeeRecipient);
    }

    function setManagementFeeRecipient(address newManagementFeeRecipient) external {
        timelocked();
        require(newManagementFeeRecipient != address(0) || managementFee == 0, ErrorsLib.FeeInvariantBroken());

        accrueInterest();

        managementFeeRecipient = newManagementFeeRecipient;
        emit EventsLib.SetManagementFeeRecipient(newManagementFeeRecipient);
    }

    function increaseAbsoluteCap(bytes memory idData, uint256 newAbsoluteCap) external {
        timelocked();
        bytes32 id = keccak256(idData);
        require(newAbsoluteCap >= caps[id].absoluteCap, ErrorsLib.AbsoluteCapNotIncreasing());

        caps[id].absoluteCap = newAbsoluteCap.toUint128();
        emit EventsLib.IncreaseAbsoluteCap(id, idData, newAbsoluteCap);
    }

    function decreaseAbsoluteCap(bytes memory idData, uint256 newAbsoluteCap) external {
        bytes32 id = keccak256(idData);
        require(msg.sender == curator || isSentinel[msg.sender], ErrorsLib.Unauthorized());
        require(newAbsoluteCap <= caps[id].absoluteCap, ErrorsLib.AbsoluteCapNotDecreasing());

        // Safe because newAbsoluteCap <= absoluteCap < 2**128.
        caps[id].absoluteCap = uint128(newAbsoluteCap);
        emit EventsLib.DecreaseAbsoluteCap(msg.sender, id, idData, newAbsoluteCap);
    }

    function increaseRelativeCap(bytes memory idData, uint256 newRelativeCap) external {
        timelocked();
        bytes32 id = keccak256(idData);
        require(newRelativeCap <= WAD, ErrorsLib.RelativeCapAboveOne());
        require(newRelativeCap >= caps[id].relativeCap, ErrorsLib.RelativeCapNotIncreasing());

        // Safe because WAD < 2**128.
        caps[id].relativeCap = uint128(newRelativeCap);
        emit EventsLib.IncreaseRelativeCap(id, idData, newRelativeCap);
    }

    function decreaseRelativeCap(bytes memory idData, uint256 newRelativeCap) external {
        bytes32 id = keccak256(idData);
        require(msg.sender == curator || isSentinel[msg.sender], ErrorsLib.Unauthorized());
        require(newRelativeCap <= caps[id].relativeCap, ErrorsLib.RelativeCapNotDecreasing());

        // Safe because WAD < 2**128.
        caps[id].relativeCap = uint128(newRelativeCap);
        emit EventsLib.DecreaseRelativeCap(msg.sender, id, idData, newRelativeCap);
    }

    function setForceDeallocatePenalty(address adapter, uint256 newForceDeallocatePenalty) external {
        timelocked();
        require(newForceDeallocatePenalty <= MAX_FORCE_DEALLOCATE_PENALTY, ErrorsLib.PenaltyTooHigh());
        forceDeallocatePenalty[adapter] = newForceDeallocatePenalty;
        emit EventsLib.SetForceDeallocatePenalty(adapter, newForceDeallocatePenalty);
    }

    /* ALLOCATOR FUNCTIONS */

    function allocate(address adapter, bytes memory data, uint256 assets) external {
        require(isAllocator[msg.sender], ErrorsLib.Unauthorized());
        allocateInternal(adapter, data, assets);
    }

    function allocateInternal(address adapter, bytes memory data, uint256 assets) internal {
        require(isAdapter[adapter], ErrorsLib.NotAdapter());

        accrueInterest();

        SafeERC20Lib.safeTransfer(asset, adapter, assets);
        (bytes32[] memory ids, int256 change) = IAdapter(adapter).allocate(data, assets, msg.sig, msg.sender);

        for (uint256 i; i < ids.length; i++) {
            Caps storage _caps = caps[ids[i]];
            _caps.allocation = (int256(_caps.allocation) + change).toUint256();

            require(_caps.absoluteCap > 0, ErrorsLib.ZeroAbsoluteCap());
            require(_caps.allocation <= _caps.absoluteCap, ErrorsLib.AbsoluteCapExceeded());
            require(
                _caps.relativeCap == WAD || _caps.allocation <= firstTotalAssets.mulDivDown(_caps.relativeCap, WAD),
                ErrorsLib.RelativeCapExceeded()
            );
        }
        emit EventsLib.Allocate(msg.sender, adapter, assets, ids, change);
    }

    function deallocate(address adapter, bytes memory data, uint256 assets) external {
        require(isAllocator[msg.sender] || isSentinel[msg.sender], ErrorsLib.Unauthorized());
        deallocateInternal(adapter, data, assets);
    }

    function deallocateInternal(address adapter, bytes memory data, uint256 assets)
        internal
        returns (bytes32[] memory)
    {
        require(isAdapter[adapter], ErrorsLib.NotAdapter());

        (bytes32[] memory ids, int256 change) = IAdapter(adapter).deallocate(data, assets, msg.sig, msg.sender);

        for (uint256 i; i < ids.length; i++) {
            Caps storage _caps = caps[ids[i]];
            require(_caps.allocation > 0, ErrorsLib.ZeroAllocation());
            _caps.allocation = (int256(_caps.allocation) + change).toUint256();
        }

        SafeERC20Lib.safeTransferFrom(asset, adapter, address(this), assets);
        emit EventsLib.Deallocate(msg.sender, adapter, assets, ids, change);
        return ids;
    }

    /// @dev Whether newLiquidityAdapter is an adapter is checked in allocate/deallocate.
    function setLiquidityAdapterAndData(address newLiquidityAdapter, bytes memory newLiquidityData) external {
        require(isAllocator[msg.sender], ErrorsLib.Unauthorized());
        liquidityAdapter = newLiquidityAdapter;
        liquidityData = newLiquidityData;
        emit EventsLib.SetLiquidityAdapterAndData(msg.sender, newLiquidityAdapter, newLiquidityData);
    }

    function setMaxRate(uint256 newMaxRate) external {
        require(isAllocator[msg.sender], ErrorsLib.Unauthorized());
        require(newMaxRate <= MAX_MAX_RATE, ErrorsLib.MaxRateTooHigh());

        accrueInterest();

        // Safe because newMaxRate <= MAX_MAX_RATE < 2**64-1.
        maxRate = uint64(newMaxRate);
        emit EventsLib.SetMaxRate(newMaxRate);
    }

    /* EXCHANGE RATE FUNCTIONS */

    function accrueInterest() public {
        (uint256 newTotalAssets, uint256 performanceFeeShares, uint256 managementFeeShares) = accrueInterestView();
        emit EventsLib.AccrueInterest(_totalAssets, newTotalAssets, performanceFeeShares, managementFeeShares);
        _totalAssets = newTotalAssets.toUint128();
        if (firstTotalAssets == 0) firstTotalAssets = newTotalAssets;
        if (performanceFeeShares != 0) createShares(performanceFeeRecipient, performanceFeeShares);
        if (managementFeeShares != 0) createShares(managementFeeRecipient, managementFeeShares);
        lastUpdate = uint64(block.timestamp);
    }

    /// @dev Returns newTotalAssets, performanceFeeShares, managementFeeShares.
    /// @dev The management fee is not bound to the interest, so it can make the share price go down.
    /// @dev The management fees is taken even if the vault incurs some losses.
    /// @dev Both fees are rounded down, so fee recipients could receive less than expected.
    /// @dev The performance fee is taken on the "distributed interest" (which differs from the "real interest" because
    /// of the max rate).
    function accrueInterestView() public view returns (uint256, uint256, uint256) {
        if (firstTotalAssets != 0) return (_totalAssets, 0, 0);
        uint256 elapsed = block.timestamp - lastUpdate;
        uint256 realAssets = IERC20(asset).balanceOf(address(this));
        for (uint256 i = 0; i < adapters.length; i++) {
            realAssets += IAdapter(adapters[i]).realAssets();
        }
        uint256 maxTotalAssets = _totalAssets + (_totalAssets * elapsed).mulDivDown(maxRate, WAD);
        uint256 newTotalAssets = MathLib.min(realAssets, maxTotalAssets);
        uint256 interest = newTotalAssets.zeroFloorSub(_totalAssets);

        // The performance fee assets may be rounded down to 0 if interest * fee < WAD.
        uint256 performanceFeeAssets = interest > 0 && performanceFee > 0 && canReceiveShares(performanceFeeRecipient)
            ? interest.mulDivDown(performanceFee, WAD)
            : 0;
        // The management fee is taken on newTotalAssets to make all approximations consistent (interacting less
        // increases fees).
        uint256 managementFeeAssets = elapsed > 0 && managementFee > 0 && canReceiveShares(managementFeeRecipient)
            ? (newTotalAssets * elapsed).mulDivDown(managementFee, WAD)
            : 0;

        // Interest should be accrued at least every 10 years to avoid fees exceeding total assets.
        uint256 newTotalAssetsWithoutFees = newTotalAssets - performanceFeeAssets - managementFeeAssets;
        uint256 performanceFeeShares =
            performanceFeeAssets.mulDivDown(totalSupply + virtualShares, newTotalAssetsWithoutFees + 1);
        uint256 managementFeeShares =
            managementFeeAssets.mulDivDown(totalSupply + virtualShares, newTotalAssetsWithoutFees + 1);

        return (newTotalAssets, performanceFeeShares, managementFeeShares);
    }

    /// @dev Returns previewed minted shares.
    function previewDeposit(uint256 assets) public view returns (uint256) {
        (uint256 newTotalAssets, uint256 performanceFeeShares, uint256 managementFeeShares) = accrueInterestView();
        uint256 newTotalSupply = totalSupply + performanceFeeShares + managementFeeShares;
        return assets.mulDivDown(newTotalSupply + virtualShares, newTotalAssets + 1);
    }

    /// @dev Returns previewed deposited assets.
    function previewMint(uint256 shares) public view returns (uint256) {
        (uint256 newTotalAssets, uint256 performanceFeeShares, uint256 managementFeeShares) = accrueInterestView();
        uint256 newTotalSupply = totalSupply + performanceFeeShares + managementFeeShares;
        return shares.mulDivUp(newTotalAssets + 1, newTotalSupply + virtualShares);
    }

    /// @dev Returns previewed redeemed shares.
    function previewWithdraw(uint256 assets) public view returns (uint256) {
        (uint256 newTotalAssets, uint256 performanceFeeShares, uint256 managementFeeShares) = accrueInterestView();
        uint256 newTotalSupply = totalSupply + performanceFeeShares + managementFeeShares;
        return assets.mulDivUp(newTotalSupply + virtualShares, newTotalAssets + 1);
    }

    /// @dev Returns previewed withdrawn assets.
    function previewRedeem(uint256 shares) public view returns (uint256) {
        (uint256 newTotalAssets, uint256 performanceFeeShares, uint256 managementFeeShares) = accrueInterestView();
        uint256 newTotalSupply = totalSupply + performanceFeeShares + managementFeeShares;
        return shares.mulDivDown(newTotalAssets + 1, newTotalSupply + virtualShares);
    }

    /// @dev Returns corresponding shares (rounded down).
    /// @dev Takes into account performance and management fees.
    function convertToShares(uint256 assets) external view returns (uint256) {
        return previewDeposit(assets);
    }

    /// @dev Returns corresponding assets (rounded down).
    /// @dev Takes into account performance and management fees.
    function convertToAssets(uint256 shares) external view returns (uint256) {
        return previewRedeem(shares);
    }

    /* MAX FUNCTIONS */

    /// @dev Gross underestimation because being revert-free cannot be guaranteed when calling the gate.
    function maxDeposit(address) external pure returns (uint256) {
        return 0;
    }

    /// @dev Gross underestimation because being revert-free cannot be guaranteed when calling the gate.
    function maxMint(address) external pure returns (uint256) {
        return 0;
    }

    /// @dev Gross underestimation because being revert-free cannot be guaranteed when calling the gate.
    function maxWithdraw(address) external pure returns (uint256) {
        return 0;
    }

    /// @dev Gross underestimation because being revert-free cannot be guaranteed when calling the gate.
    function maxRedeem(address) external pure returns (uint256) {
        return 0;
    }

    /* USER MAIN FUNCTIONS */

    /// @dev Returns minted shares.
    function deposit(uint256 assets, address onBehalf) external returns (uint256) {
        accrueInterest();
        uint256 shares = previewDeposit(assets);
        enter(assets, shares, onBehalf);
        return shares;
    }

    /// @dev Returns deposited assets.
    function mint(uint256 shares, address onBehalf) external returns (uint256) {
        accrueInterest();
        uint256 assets = previewMint(shares);
        enter(assets, shares, onBehalf);
        return assets;
    }

    /// @dev Internal function for deposit and mint.
    function enter(uint256 assets, uint256 shares, address onBehalf) internal {
        require(canReceiveShares(onBehalf), ErrorsLib.CannotReceiveShares());
        require(canSendAssets(msg.sender), ErrorsLib.CannotSendAssets());

        SafeERC20Lib.safeTransferFrom(asset, msg.sender, address(this), assets);
        createShares(onBehalf, shares);
        _totalAssets += assets.toUint128();
        emit EventsLib.Deposit(msg.sender, onBehalf, assets, shares);

        if (liquidityAdapter != address(0)) allocateInternal(liquidityAdapter, liquidityData, assets);
    }

    /// @dev Returns redeemed shares.
    function withdraw(uint256 assets, address receiver, address onBehalf) public returns (uint256) {
        accrueInterest();
        uint256 shares = previewWithdraw(assets);
        exit(assets, shares, receiver, onBehalf);
        return shares;
    }

    /// @dev Returns withdrawn assets.
    function redeem(uint256 shares, address receiver, address onBehalf) external returns (uint256) {
        accrueInterest();
        uint256 assets = previewRedeem(shares);
        exit(assets, shares, receiver, onBehalf);
        return assets;
    }

    /// @dev Internal function for withdraw and redeem.
    function exit(uint256 assets, uint256 shares, address receiver, address onBehalf) internal {
        require(canSendShares(onBehalf), ErrorsLib.CannotSendShares());
        require(canReceiveAssets(receiver), ErrorsLib.CannotReceiveAssets());

        uint256 idleAssets = IERC20(asset).balanceOf(address(this));
        if (assets > idleAssets && liquidityAdapter != address(0)) {
            deallocateInternal(liquidityAdapter, liquidityData, assets - idleAssets);
        }

        if (msg.sender != onBehalf) {
            uint256 _allowance = allowance[onBehalf][msg.sender];
            if (_allowance != type(uint256).max) allowance[onBehalf][msg.sender] = _allowance - shares;
        }

        deleteShares(onBehalf, shares);
        _totalAssets -= assets.toUint128();
        SafeERC20Lib.safeTransfer(asset, receiver, assets);
        emit EventsLib.Withdraw(msg.sender, receiver, onBehalf, assets, shares);
    }

    /// @dev Returns shares withdrawn as penalty.
    /// @dev When calling this function, a penalty is taken from onBehalf, in order to discourage allocation
    /// manipulations.
    /// @dev The penalty is taken as a withdrawal for which assets are returned to the vault. In consequence,
    /// totalAssets is decreased normally along with totalSupply (the share price doesn't change except because of
    /// rounding errors), but the amount of assets actually controlled by the vault is not decreased.
    /// @dev If a user has A assets in the vault, and that the vault is already fully illiquid, the optimal amount to
    /// force deallocate in order to exit the vault is min(liquidity_of_market, A / (1 + penalty)).
    /// This ensures that either the market is empty or that it leaves no shares nor liquidity after exiting.
    function forceDeallocate(address adapter, bytes memory data, uint256 assets, address onBehalf)
        external
        returns (uint256)
    {
        bytes32[] memory ids = deallocateInternal(adapter, data, assets);
        uint256 penaltyAssets = assets.mulDivUp(forceDeallocatePenalty[adapter], WAD);
        uint256 penaltyShares = withdraw(penaltyAssets, address(this), onBehalf);
        emit EventsLib.ForceDeallocate(msg.sender, adapter, assets, onBehalf, ids, penaltyAssets);
        return penaltyShares;
    }

    /* ERC20 FUNCTIONS */

    /// @dev Returns success (always true because reverts on failure).
    function transfer(address to, uint256 shares) external returns (bool) {
        require(to != address(0), ErrorsLib.ZeroAddress());

        require(canSendShares(msg.sender), ErrorsLib.CannotSendShares());
        require(canReceiveShares(to), ErrorsLib.CannotReceiveShares());

        balanceOf[msg.sender] -= shares;
        balanceOf[to] += shares;
        emit EventsLib.Transfer(msg.sender, to, shares);
        return true;
    }

    /// @dev Returns success (always true because reverts on failure).
    function transferFrom(address from, address to, uint256 shares) external returns (bool) {
        require(from != address(0), ErrorsLib.ZeroAddress());
        require(to != address(0), ErrorsLib.ZeroAddress());

        require(canSendShares(from), ErrorsLib.CannotSendShares());
        require(canReceiveShares(to), ErrorsLib.CannotReceiveShares());

        if (msg.sender != from) {
            uint256 _allowance = allowance[from][msg.sender];
            if (_allowance != type(uint256).max) {
                allowance[from][msg.sender] = _allowance - shares;
                emit EventsLib.AllowanceUpdatedByTransferFrom(from, msg.sender, _allowance - shares);
            }
        }

        balanceOf[from] -= shares;
        balanceOf[to] += shares;
        emit EventsLib.Transfer(from, to, shares);
        return true;
    }

    /// @dev Returns success (always true because reverts on failure).
    function approve(address spender, uint256 shares) external returns (bool) {
        allowance[msg.sender][spender] = shares;
        emit EventsLib.Approval(msg.sender, spender, shares);
        return true;
    }

    /// @dev Signature malleability is not explicitly prevented but it is not a problem thanks to the nonce.
    function permit(address _owner, address spender, uint256 shares, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        require(deadline >= block.timestamp, ErrorsLib.PermitDeadlineExpired());

        uint256 nonce = nonces[_owner]++;
        bytes32 hashStruct = keccak256(abi.encode(PERMIT_TYPEHASH, _owner, spender, shares, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), hashStruct));
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == _owner, ErrorsLib.InvalidSigner());

        allowance[_owner][spender] = shares;
        emit EventsLib.Approval(_owner, spender, shares);
        emit EventsLib.Permit(_owner, spender, shares, nonce, deadline);
    }

    function createShares(address to, uint256 shares) internal {
        require(to != address(0), ErrorsLib.ZeroAddress());
        balanceOf[to] += shares;
        totalSupply += shares;
        emit EventsLib.Transfer(address(0), to, shares);
    }

    function deleteShares(address from, uint256 shares) internal {
        require(from != address(0), ErrorsLib.ZeroAddress());
        balanceOf[from] -= shares;
        totalSupply -= shares;
        emit EventsLib.Transfer(from, address(0), shares);
    }

    /* PERMISSIONED TOKEN FUNCTIONS */

    function canReceiveShares(address account) public view returns (bool) {
        return receiveSharesGate == address(0) || IReceiveSharesGate(receiveSharesGate).canReceiveShares(account);
    }

    function canSendShares(address account) public view returns (bool) {
        return sendSharesGate == address(0) || ISendSharesGate(sendSharesGate).canSendShares(account);
    }

    function canReceiveAssets(address account) public view returns (bool) {
        return account == address(this) || receiveAssetsGate == address(0)
            || IReceiveAssetsGate(receiveAssetsGate).canReceiveAssets(account);
    }

    function canSendAssets(address account) public view returns (bool) {
        return sendAssetsGate == address(0) || ISendAssetsGate(sendAssetsGate).canSendAssets(account);
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity 0.8.28;

import {VaultV2} from "./VaultV2.sol";
import {IVaultV2Factory} from "./interfaces/IVaultV2Factory.sol";

contract VaultV2Factory is IVaultV2Factory {
    mapping(address account => bool) public isVaultV2;
    mapping(address owner => mapping(address asset => mapping(bytes32 salt => address))) public vaultV2;

    /// @dev Returns the address of the deployed VaultV2.
    function createVaultV2(address owner, address asset, bytes32 salt) external returns (address) {
        address newVaultV2 = address(new VaultV2{salt: salt}(owner, asset));

        isVaultV2[newVaultV2] = true;
        vaultV2[owner][asset][salt] = newVaultV2;
        emit CreateVaultV2(owner, asset, salt, newVaultV2);

        return newVaultV2;
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Steakhouse Financial
pragma solidity ^0.8.0;

// Exact struct definitions from Aragon OSx DAOFactory
struct DAOSettings {
    address trustedForwarder;
    string daoURI;
    string subdomain;
    bytes metadata;
}

struct PluginSettingsTag {
    uint8 release;
    uint16 build;
}

struct PluginSetupRef {
    PluginSettingsTag versionTag;
    address pluginSetupRepo;
}

struct PluginSettings {
    PluginSetupRef pluginSetupRef;
    bytes data;
}

// InstalledPlugin struct from DAOFactory
struct InstalledPlugin {
    address plugin;
    IPluginSetup.PreparedSetupData preparedSetupData;
}

struct VotingSettings {
    uint8 votingMode;
    uint32 supportThreshold;
    uint32 minParticipation;
    uint32 minApprovalRatio;
    uint64 proposalDuration;
    uint256 minProposerVotingPower;
}

struct TargetConfig {
    address target;
    uint8 operation;
}

struct InstallationParameters {
    address token;
    VotingSettings votingSettings;
    bytes pluginMetadata;
    address createProposalCaller;
    address executeCaller;
    TargetConfig targetConfig;
}
/// @title PermissionLib
/// @author Aragon X - 2021-2023
/// @notice A library containing objects for permission processing.
/// @custom:security-contact sirt@aragon.org
library PermissionLib {
    /// @notice The types of permission operations available in the `PermissionManager`.
    /// @param Grant The grant operation setting a permission without a condition.
    /// @param Revoke The revoke operation removing a permission (that was granted with or without a condition).
    /// @param GrantWithCondition The grant operation setting a permission with a condition.
    enum Operation {
        Grant,
        Revoke,
        GrantWithCondition
    }

    /// @notice A struct containing the information for a permission to be applied on a single target contract without a condition.
    /// @param operation The permission operation type.
    /// @param who The address (EOA or contract) receiving the permission.
    /// @param permissionId The permission identifier.
    struct SingleTargetPermission {
        Operation operation;
        address who;
        bytes32 permissionId;
    }

    /// @notice A struct containing the information for a permission to be applied on multiple target contracts, optionally, with a condition.
    /// @param operation The permission operation type.
    /// @param where The address of the target contract for which `who` receives permission.
    /// @param who The address (EOA or contract) receiving the permission.
    /// @param condition The `PermissionCondition` that will be asked for authorization on calls connected to the specified permission identifier.
    /// @param permissionId The permission identifier.
    struct MultiTargetPermission {
        Operation operation;
        address where;
        address who;
        address condition;
        bytes32 permissionId;
    }
}

/**
 * @title Aragon Interfaces
 * @notice Minimal interfaces for interacting with Aragon DAOs
 * @dev Used by deployment scripts to interact with deployed DAOs
 */

/**
 * @notice Interface for Aragon LockManager (helper contract from LockToVote plugin)
 */
interface ILockManager {
    function lock(uint256 _amount) external;
    function unlock(uint256 _amount) external;
    function vote(uint256 _proposalId, uint8 _voteOption) external;
    function getVotingPower(address _account) external view returns (uint256);
}

/**
 * @notice Interface for Aragon LockToVote plugin
 */
interface ILockToVotePlugin {
    struct Action {
        address to;
        uint256 value;
        bytes data;
    }

    function createProposal(
        bytes calldata _metadata,
        Action[] memory _actions,
        uint64 _startDate,
        uint64 _endDate,
        bytes memory _data
    ) external returns (uint256 proposalId);

    function execute(uint256 _proposalId) external;

    function canExecute(uint256 _proposalId) external view returns (bool);
}

/**
 * @notice Interface for Aragon Multisig plugin
 */
interface IMultisig {
    struct Action {
        address to;
        uint256 value;
        bytes data;
    }

    function createProposal(
        bytes calldata _metadata,
        Action[] memory _actions,
        uint256 _allowFailureMap
    ) external returns (uint256 proposalId);

    function approve(uint256 _proposalId) external;

    function execute(uint256 _proposalId) external;

    function canApprove(uint256 _proposalId, address _account) external view returns (bool);

    function canExecute(uint256 _proposalId) external view returns (bool);
}

/**
 * @notice Interface for Aragon DAO
 */
interface IDAO {
    function hasPermission(address _where, address _who, bytes32 _permissionId, bytes memory _data) external view returns (bool);

    function grant(address _where, address _who, bytes32 _permissionId) external;

    function revoke(address _where, address _who, bytes32 _permissionId) external;

    function execute(bytes32 _callId, Action[] memory _actions, uint256 _allowFailureMap) external returns (bytes[] memory, uint256);

    function ROOT_PERMISSION_ID() external returns (bytes32);

    struct Action {
        address to;
        uint256 value;
        bytes data;
    }
}

/// @notice DAOFactory interface
interface IDAOFactory {
    function createDao(
        DAOSettings calldata _daoSettings,
        PluginSettings[] calldata _pluginSettings
    ) external returns (address createdDao, InstalledPlugin[] memory installedPlugins);
    function pluginSetupProcessor() external returns (address);
}

interface IPluginSetup {
    /// @notice The data associated with a prepared setup.
    /// @param helpers The address array of helpers (contracts or EOAs) associated with this plugin version after the installation or update.
    /// @param permissions The array of multi-targeted permission operations to be applied by the `PluginSetupProcessor` to the installing or updating DAO.
    struct PreparedSetupData {
        address[] helpers;
        PermissionLib.MultiTargetPermission[] permissions;
    }

    /// @notice The payload for plugin updates and uninstallations containing the existing contracts as well as optional data to be consumed by the plugin setup.
    /// @param plugin The address of the `Plugin`.
    /// @param currentHelpers The address array of all current helpers (contracts or EOAs) associated with the plugin to update from.
    /// @param data The bytes-encoded data containing the input parameters for the preparation of update/uninstall as specified in the corresponding ABI on the version's metadata.
    struct SetupPayload {
        address plugin;
        address[] currentHelpers;
        bytes data;
    }

    /// @notice Prepares the installation of a plugin.
    /// @param _dao The address of the installing DAO.
    /// @param _data The bytes-encoded data containing the input parameters for the installation as specified in the plugin's build metadata JSON file.
    /// @return plugin The address of the `Plugin` contract being prepared for installation.
    /// @return preparedSetupData The deployed plugin's relevant data which consists of helpers and permissions.
    function prepareInstallation(
        address _dao,
        bytes calldata _data
    ) external returns (address plugin, PreparedSetupData memory preparedSetupData);

    /// @notice Prepares the update of a plugin.
    /// @param _dao The address of the updating DAO.
    /// @param _fromBuild The build number of the plugin to update from.
    /// @param _payload The relevant data necessary for the `prepareUpdate`. See above.
    /// @return initData The initialization data to be passed to upgradeable contracts when the update is applied in the `PluginSetupProcessor`.
    /// @return preparedSetupData The deployed plugin's relevant data which consists of helpers and permissions.
    function prepareUpdate(
        address _dao,
        uint16 _fromBuild,
        SetupPayload calldata _payload
    ) external returns (bytes memory initData, PreparedSetupData memory preparedSetupData);

    /// @notice Prepares the uninstallation of a plugin.
    /// @param _dao The address of the uninstalling DAO.
    /// @param _payload The relevant data necessary for the `prepareUninstallation`. See above.
    /// @return permissions The array of multi-targeted permission operations to be applied by the `PluginSetupProcessor` to the uninstalling DAO.
    function prepareUninstallation(
        address _dao,
        SetupPayload calldata _payload
    ) external returns (PermissionLib.MultiTargetPermission[] memory permissions);

    /// @notice Returns the plugin implementation address.
    /// @return The address of the plugin implementation contract.
    /// @dev The implementation can be instantiated via the `new` keyword, cloned via the minimal proxy pattern (see [ERC-1167](https://eips.ethereum.org/EIPS/eip-1167)), or proxied via the UUPS proxy pattern (see [ERC-1822](https://eips.ethereum.org/EIPS/eip-1822)).
    function implementation() external view returns (address);
}

interface IPluginSetupProcessor {
    /// @notice A struct containing information related to plugin setups that have been applied.
    /// @param blockNumber The block number at which the `applyInstallation`, `applyUpdate` or `applyUninstallation` was executed.
    /// @param currentAppliedSetupId The current setup id that plugin holds. Needed to confirm that `prepareUpdate` or `prepareUninstallation` happens for the plugin's current/valid dependencies.
    /// @param preparedSetupIdToBlockNumber The mapping between prepared setup IDs and block numbers at which `prepareInstallation`, `prepareUpdate` or `prepareUninstallation` was executed.
    struct PluginState {
        uint256 blockNumber;
        bytes32 currentAppliedSetupId;
        mapping(bytes32 => uint256) preparedSetupIdToBlockNumber;
    }

    /// @notice The struct containing the parameters for the `prepareInstallation` function.
    /// @param pluginSetupRef The reference to the plugin setup to be used for the installation.
    /// @param data The bytes-encoded data containing the input parameters for the installation preparation as specified in the corresponding ABI on the version's metadata.
    struct PrepareInstallationParams {
        PluginSetupRef pluginSetupRef;
        bytes data;
    }

    /// @notice The struct containing the parameters for the `applyInstallation` function.
    /// @param pluginSetupRef The reference to the plugin setup used for the installation.
    /// @param plugin The address of the plugin contract to be installed.
    /// @param permissions The array of multi-targeted permission operations to be applied by the `PluginSetupProcessor` to the DAO.
    /// @param helpersHash The hash of helpers that were deployed in `prepareInstallation`. This helps to derive the setup ID.
    struct ApplyInstallationParams {
        PluginSetupRef pluginSetupRef;
        address plugin;
        PermissionLib.MultiTargetPermission[] permissions;
        bytes32 helpersHash;
    }

    /// @notice Prepares the installation of a plugin.
    /// @param _dao The address of the installing DAO.
    /// @param _params The struct containing the parameters for the `prepareInstallation` function.
    /// @return plugin The prepared plugin contract address.
    /// @return preparedSetupData The data struct containing the array of helper contracts and permissions that the setup has prepared.
    function prepareInstallation(
        address _dao,
        PrepareInstallationParams calldata _params
    ) external returns (address plugin, IPluginSetup.PreparedSetupData memory preparedSetupData);

    /// @notice Applies the permissions of a prepared installation to a DAO.
    /// @param _dao The address of the installing DAO.
    /// @param _params The struct containing the parameters for the `applyInstallation` function.
    function applyInstallation(address _dao, ApplyInstallationParams calldata _params) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Steakhouse Financial
pragma solidity ^0.8.28;

import {IVaultV2} from "@vault-v2/src/interfaces/IVaultV2.sol";

/// @title Revoker
/// @notice Make a sentinel only able to call revoke on a Vault V2
/// #dev The sentinel address to add to the Vault V2 is this contract address.
contract Revoker {
    address public sentinel;
    IVaultV2 public vault;

    constructor(IVaultV2 _vault, address _sentinel) {
        sentinel = _sentinel;
        vault = _vault;
    }

    function revoke(bytes memory data) external {
        require(msg.sender == sentinel, "Only sentinel can call");
        vault.revoke(data);
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Steakhouse Financial
pragma solidity ^0.8.28;

import {IVaultV2} from "@vault-v2/src/interfaces/IVaultV2.sol";

library VaultV2Lib {
    /// @notice Adds an allocator to a VaultV2 instance, assume 0-day timelocks
    function addAllocatorInstant(IVaultV2 vault, address allocator) internal {
        bytes memory encoding = abi.encodeWithSelector(vault.setIsAllocator.selector, address(allocator), true);
        vault.submit(encoding);
        vault.setIsAllocator(address(allocator), true);
    }

    /// @notice Removes an allocator to a VaultV2 instance, assume 0-day timelocks
    function removeAllocatorInstant(IVaultV2 vault, address allocator) internal {
        bytes memory encoding = abi.encodeWithSelector(vault.setIsAllocator.selector, address(allocator), false);
        vault.submit(encoding);
        vault.setIsAllocator(address(allocator), false);
    }

    /// @notice Adds collateral to a VaultV2 instance, assume 0-day timelocks
    function addCollateralInstant(IVaultV2 vault, address adapter, bytes memory data, uint256 absolute, uint256 relative) internal {
        bytes memory encoding;
        // Accept the adapter
        if (!vault.isAdapter(address(adapter))) {
            encoding = abi.encodeWithSelector(vault.addAdapter.selector, address(adapter));
            vault.submit(encoding);
            vault.addAdapter(address(adapter));
        }

        // Absolute limit
        encoding = abi.encodeWithSelector(
            vault.increaseAbsoluteCap.selector,
            data,
            absolute // 100,000 USDC
        );
        vault.submit(encoding);
        vault.increaseAbsoluteCap(data, absolute);

        // Relative limit
        encoding = abi.encodeWithSelector(
            vault.increaseRelativeCap.selector,
            data,
            relative // 100%
        );
        vault.submit(encoding);
        vault.increaseRelativeCap(data, relative);
    }

    /// @notice Adds collateral to a VaultV2 instance, assume 0-day timelocks
    function setForceDeallocatePenaltyInstant(IVaultV2 vault, address adapter, uint256 penalty) internal {
        bytes memory encoding = abi.encodeWithSelector(vault.setForceDeallocatePenalty.selector, address(adapter), penalty);
        vault.submit(encoding);
        vault.setForceDeallocatePenalty(address(adapter), penalty);
    }
}

// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Steakhouse Financial
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IBox} from "./interfaces/IBox.sol";
import {IBoxFlashCallback} from "./interfaces/IBox.sol";
import {IFunding, IOracleCallback} from "./interfaces/IFunding.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {ISwapper} from "./interfaces/ISwapper.sol";
import "./libraries/Constants.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

/**
 * @title Box
 * @notice An ERC4626 vault that holds a base asset, invest in other ERC20 tokens and can borrow/lend via funding modules.
 * @dev Features role-based access control, timelocked governance, and slippage protection
 * @dev Box is not inflation or donation resistant as deposits are strictly controlled via the isFeeder role.
 * @dev Should deposit happen in an automated way (liquidity on a Vault V2) and from multiple feeders, it should be seeded first.
 * @dev Oracles can be manipulated to give an unfair price
 * @dev It is recommanded to create resiliency by using the BoxAdapterCached
 * @dev and/or by using a Vault V2 as a parent vault, which can have a reported price a but lower the NAV price and a setMaxRate()
 * @dev During flash operations there is no totalAssets() calculation possible to avoid NAV based attacks
 * @dev There is no protection against ERC4626 inflation attacks, as deposits are controlled via the isFeeder role.
 * @dev Users shouldn't be able to deposited directly or indirectly to a Box.
 * @dev The Box uses forceApprove with 0 value, making it incompatible with the BNB ERC-20 token (reverts on zero-value approvals)
 * @dev Token removal can be stopped by sending dust amount of tokens. Can be fixed by deallocating then removing the token atomically
 * @dev The epoch-based slippage protection is relative to Box total assets, but a bad allocator can deposit all parent Vault V2
 * @dev fund into one Box to temporarily inflate its total asset and extract more value than expected.
 */
contract Box is IBox, ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;

    // ========== IMMUTABLE STATE ==========

    /// @notice Base currency token (e.g., USDC)
    address public immutable override asset;

    /// @notice Number of decimals for the vault shares (normalized to 18 for assets with fewer decimals)
    uint8 private immutable _decimals;

    /// @notice Virtual shares used for inflation attack protection
    uint256 public immutable virtualShares;

    /// @notice Duration of slippage tracking epochs
    uint256 public immutable slippageEpochDuration;

    /// @notice Duration over which shutdown slippage tolerance increases
    uint256 public immutable shutdownSlippageDuration;

    /// @notice Duration between shutdown and wind-down phase
    uint256 public immutable shutdownWarmup;

    // ========== MUTABLE STATE ==========

    /// @notice Contract owner with administrative privileges
    address public owner;

    /// @notice Curator who manages tokens and funding modules
    address public curator;

    /// @notice Guardian who can trigger shutdowns and revoke timelocked actions
    address public guardian;

    /// @notice Timestamp when shutdown was triggered, no shutdown if type(uint256).max
    uint256 public shutdownTime;

    /// @notice Recipient of skimmed tokens that aren't part of the vault's strategy
    address public skimRecipient;

    /// @notice Tracks which addresses can execute allocation strategies
    mapping(address => bool) public isAllocator;

    /// @notice Tracks which addresses can deposit into the vault
    mapping(address => bool) public isFeeder;

    /// @notice List of whitelisted investment tokens
    IERC20[] public tokens;

    /// @notice Maps each token to its price oracle
    mapping(IERC20 => IOracle) public oracles;

    /// @notice Maximum allowed slippage per operation and per epoch (scaled by PRECISION = 1e18)
    uint256 public maxSlippage;

    /// @notice Accumulated slippage within current epoch (scaled by PRECISION = 1e18)
    uint256 public accumulatedSlippage;

    /// @notice Timestamp when the current slippage tracking epoch started
    uint256 public slippageEpochStart;

    /// @notice Delay duration for each function selector (in seconds)
    mapping(bytes4 => uint256) public timelock;

    /// @notice Timestamp when specific calldata becomes executable
    mapping(bytes => uint256) public executableAt;

    /// @notice List of whitelisted funding modules for borrowing/lending
    IFunding[] public fundings;

    /// @notice Quick lookup to check if a funding module is whitelisted
    mapping(IFunding => bool) internal fundingMap;

    /// @notice Depth counter for nested NAV-caching operations (flash and swaps)
    uint8 private transient _cachedNavDepth;

    /// @notice Cached NAV value during flash and swap operations to prevent manipulation
    uint256 private transient _cachedNav;

    // ========== CONSTRUCTOR ==========

    /**
     * @notice Allows the contract to receive native currency
     * @dev Required for skimming native currency from funding modules
     */
    receive() external payable {}

    /**
     * @notice Fallback function to receive native currency
     * @dev Required for skimming native currency from funding modules
     */
    fallback() external payable {}

    /**
     * @notice Initializes the Box vault
     * @param _asset Base currency token (e.g., USDC)
     * @param _owner Initial owner address
     * @param _curator Initial curator address
     * @param _name ERC20 token name
     * @param _symbol ERC20 token symbol
     * @param _maxSlippage Max allowed slippage for a swap or aggregated over `_slippageEpochDuration`
     * @param _slippageEpochDuration Duration for which slippage is measured
     * @param _shutdownSlippageDuration When shutdown duration for slippage allowance to widen
     * @param _shutdownWarmup Duration between shutdown and wind-down phase
     * @dev To mitigate donation attacks, make an initial "dead" deposit after deployment
     *      (e.g., deposit a small amount and transfer the shares to address(0xdead)).
     */
    constructor(
        address _asset,
        address _owner,
        address _curator,
        string memory _name,
        string memory _symbol,
        uint256 _maxSlippage,
        uint256 _slippageEpochDuration,
        uint256 _shutdownSlippageDuration,
        uint256 _shutdownWarmup
    ) ERC20(_name, _symbol) {
        _requireNonZeroAddress(_asset);
        _requireNonZeroAddress(_owner);
        _requireNonZeroAddress(_curator);
        require(_maxSlippage <= MAX_SLIPPAGE_LIMIT, ErrorsLib.SlippageTooHigh());
        _requireNotEqual(_slippageEpochDuration, 0);
        _requireNotEqual(_shutdownSlippageDuration, 0);
        require(_shutdownWarmup <= MAX_SHUTDOWN_WARMUP, ErrorsLib.InvalidValue());

        asset = _asset;
        owner = _owner;
        curator = _curator;
        maxSlippage = _maxSlippage;
        slippageEpochDuration = _slippageEpochDuration;
        shutdownSlippageDuration = _shutdownSlippageDuration;
        shutdownWarmup = _shutdownWarmup;
        slippageEpochStart = block.timestamp;
        shutdownTime = type(uint256).max; // No shutdown initially

        // Set up decimals following VaultV2 pattern
        uint256 assetDecimals = IERC20Metadata(asset).decimals();
        uint256 decimalOffset = uint256(18) > assetDecimals ? uint256(18) - assetDecimals : 0;
        _decimals = uint8(assetDecimals + decimalOffset);
        virtualShares = 10 ** decimalOffset;

        emit EventsLib.BoxCreated(
            address(this),
            asset,
            owner,
            curator,
            _name,
            _symbol,
            maxSlippage,
            slippageEpochDuration,
            shutdownSlippageDuration,
            shutdownWarmup
        );
        emit EventsLib.OwnershipTransferred(address(0), _owner);
        emit EventsLib.CuratorUpdated(address(0), _curator);
    }

    // ========== ERC4626 IMPLEMENTATION ==========

    /// @notice Returns the number of decimals for the vault shares
    /// @dev Overrides ERC20.decimals() to support assets with different decimal values
    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return _decimals;
    }

    /// @inheritdoc IERC4626
    /// @notice Returns the total value of assets managed by the vault
    /// @dev Returns cached NAV during flash and swap operations to prevent manipulation
    function totalAssets() public view returns (uint256) {
        return _cachedNavDepth > 0 ? _cachedNav : _nav();
    }

    /// @inheritdoc IERC4626
    /// @notice Calculates shares received for a given asset amount
    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        return assets.mulDiv(supply + virtualShares, totalAssets() + 1, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    /// @notice Calculates assets received for redeeming shares
    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply();
        return shares.mulDiv(totalAssets() + 1, supply + virtualShares, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    /// @notice Maximum assets that can be deposited
    function maxDeposit(address) external view returns (uint256) {
        return (isShutdown()) ? 0 : type(uint256).max;
    }

    /// @inheritdoc IERC4626
    /// @notice Simulates share minting for a deposit
    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    /// @inheritdoc IERC4626
    /// @notice Deposits base asset and mints shares to receiver
    /// @dev Only authorized feeders can deposit
    function deposit(uint256 assets, address receiver) public nonReentrant returns (uint256 shares) {
        shares = previewDeposit(assets);
        _depositMint(assets, shares, receiver);
    }

    /// @inheritdoc IERC4626
    /// @notice Maximum shares that can be minted
    function maxMint(address) external view returns (uint256) {
        return (isShutdown()) ? 0 : type(uint256).max;
    }

    /// @inheritdoc IERC4626
    /// @notice Simulates assets needed to mint shares
    function previewMint(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply();
        return shares.mulDiv(totalAssets() + 1, supply + virtualShares, Math.Rounding.Ceil);
    }

    /// @inheritdoc IERC4626
    /// @notice Mints exact shares by depositing necessary base asset
    /// @dev Only authorized feeders can mint
    function mint(uint256 shares, address receiver) external nonReentrant returns (uint256 assets) {
        assets = previewMint(shares);
        _depositMint(assets, shares, receiver);
    }

    /// @dev Internal helper for deposit and mint to reduce bytecode duplication
    function _depositMint(uint256 assets, uint256 shares, address receiver) internal {
        require(_cachedNavDepth == 0, ErrorsLib.ReentryNotAllowed());
        _onlyFeeder();
        _requireNotShutdown();
        _requireNonZeroAddress(receiver);

        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    /// @notice Maximum assets owner can withdraw
    function maxWithdraw(address owner_) external view returns (uint256) {
        uint256 ownerAssets = convertToAssets(balanceOf(owner_));
        uint256 availableLiquidity = IERC20(asset).balanceOf(address(this));
        return ownerAssets < availableLiquidity ? ownerAssets : availableLiquidity;
    }

    /// @inheritdoc IERC4626
    /// @notice Simulates shares burned for withdrawing assets
    function previewWithdraw(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        return assets.mulDiv(supply + virtualShares, totalAssets() + 1, Math.Rounding.Ceil);
    }

    /// @inheritdoc IERC4626
    /// @notice Withdraws base asset by burning owner's shares
    /// @dev Requires sufficient shares and vault liquidity
    function withdraw(uint256 assets, address receiver, address owner_) public nonReentrant returns (uint256 shares) {
        shares = previewWithdraw(assets);
        _withdrawRedeem(assets, shares, receiver, owner_);
    }

    /// @inheritdoc IERC4626
    /// @notice Maximum shares owner can redeem
    function maxRedeem(address owner_) external view returns (uint256) {
        uint256 ownerShares = balanceOf(owner_);
        uint256 availableLiquidity = IERC20(asset).balanceOf(address(this));
        uint256 liquidityShares = convertToShares(availableLiquidity);
        return ownerShares < liquidityShares ? ownerShares : liquidityShares;
    }

    /// @inheritdoc IERC4626
    /// @notice Simulates assets received for redeeming shares
    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    /// @inheritdoc IERC4626
    /// @notice Redeems shares for underlying base asset
    /// @dev Burns shares and transfers base asset to receiver
    function redeem(uint256 shares, address receiver, address owner_) external nonReentrant returns (uint256 assets) {
        assets = previewRedeem(shares);
        _withdrawRedeem(assets, shares, receiver, owner_);
    }

    /// @dev Internal helper for withdraw and redeem to reduce bytecode duplication
    function _withdrawRedeem(uint256 assets, uint256 shares, address receiver, address owner_) internal {
        require(_cachedNavDepth == 0, ErrorsLib.ReentryNotAllowed());
        _requireNonZeroAddress(receiver);

        if (msg.sender != owner_) {
            uint256 allowed = allowance(owner_, msg.sender);
            if (allowed < shares) revert ErrorsLib.InsufficientAllowance();
            if (allowed != type(uint256).max) {
                _approve(owner_, msg.sender, allowed - shares);
            }
        }

        if (balanceOf(owner_) < shares) revert ErrorsLib.InsufficientShares();
        if (IERC20(asset).balanceOf(address(this)) < assets) revert ErrorsLib.InsufficientLiquidity();

        _burn(owner_, shares);
        IERC20(asset).safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner_, assets, shares);
    }

    // ========== SWAP FUNCTIONS ==========

    /**
     * @notice Transfers accidentally sent tokens to the skim recipient
     * @param token Token to skim from the contract
     * @dev Cannot skim the base asset or whitelisted investment tokens
     */
    function skim(IERC20 token) external nonReentrant {
        require(msg.sender == skimRecipient, ErrorsLib.OnlySkimRecipient());
        _requireNotEqualAddress(address(token), asset);
        require(!isToken(token), ErrorsLib.CannotSkimToken());

        uint256 balance;

        if (address(token) != address(0)) {
            // ERC-20 tokens
            balance = token.balanceOf(address(this));
            require(balance > 0, ErrorsLib.CannotSkimZero());
            token.safeTransfer(skimRecipient, balance);
        } else {
            // ETH
            balance = address(this).balance;
            require(balance > 0, ErrorsLib.CannotSkimZero());
            (bool ok, ) = skimRecipient.call{value: balance}("");
            require(ok, ErrorsLib.TransferFailed());
        }

        emit EventsLib.Skim(token, skimRecipient, balance);
    }

    /**
     * @notice Swaps base asset for investment tokens
     * @param token Target token to acquire
     * @param assetsAmount Maximum amount of base asset to spend
     * @param swapper Contract that will execute the swap
     * @param data Custom data for the swapper implementation
     * @return expected Expected amount of target token based on oracle price
     * @return received Actual amount of target token received from the allocation
     * @dev Enforces slippage protection based on oracle prices
     * @dev During wind-down, slippage tolerance increases over time
     */
    function allocate(
        IERC20 token,
        uint256 assetsAmount,
        ISwapper swapper,
        bytes calldata data
    ) public nonReentrant returns (uint256 expected, uint256 received) {
        _startNavCache();

        bool winddown = isWinddown();
        require((isAllocator[msg.sender] && !winddown) || (winddown && _debtBalance(token) > 0), ErrorsLib.OnlyAllocatorsOrWinddown());
        _requireIsToken(token);

        uint256 oraclePrice = oracles[token].price();
        uint256 slippageTolerance = winddown ? _winddownSlippageTolerance() : maxSlippage;

        if (winddown) {
            // Limit allocation to debt shortfall adjusted for slippage tolerance
            uint256 debtAmount = _debtBalance(token);
            uint256 existingBalance = token.balanceOf(address(this));
            uint256 neededTokens = debtAmount > existingBalance ? debtAmount - existingBalance : 0;
            uint256 neededValue = neededTokens.mulDiv(oraclePrice, ORACLE_PRECISION, Math.Rounding.Ceil);
            uint256 maxAllocation = neededValue.mulDiv(PRECISION, PRECISION - slippageTolerance, Math.Rounding.Ceil);
            require(assetsAmount <= maxAllocation, ErrorsLib.InvalidAmount());
        }

        // Execute swap
        (uint256 assetsSpent, uint256 tokensReceived) = _executeSwap(IERC20(asset), token, assetsAmount, swapper, data);

        // Calculate and validate slippage
        uint256 expectedTokens = assetsAmount.mulDiv(ORACLE_PRECISION, oraclePrice, Math.Rounding.Ceil);
        uint256 minTokens = _calculateMinAmount(expectedTokens, slippageTolerance);
        require(tokensReceived >= minTokens, ErrorsLib.AllocationTooExpensive());

        int256 slippagePct = _calculateSlippagePct(expectedTokens, tokensReceived);

        // Track slippage if we are not in winddown and have positive slippage
        if (!winddown && tokensReceived < expectedTokens) {
            uint256 slippageValue = (expectedTokens - tokensReceived).mulDiv(oraclePrice, ORACLE_PRECISION, Math.Rounding.Ceil);
            _increaseSlippage(slippageValue.mulDiv(PRECISION, totalAssets(), Math.Rounding.Ceil));
        }

        emit EventsLib.Allocation(token, assetsSpent, expectedTokens, tokensReceived, slippagePct, swapper, data);

        _endNavCache();
        return (expectedTokens, tokensReceived);
    }

    /**
     * @notice Swaps investment tokens back to base asset
     * @param token Token to sell
     * @param tokensAmount Maximum amount of tokens to sell
     * @param swapper Contract that will execute the swap
     * @param data Custom data for the swapper implementation
     * @return expected Expected amount of base asset based on oracle price
     * @return received Actual amount of base asset received from the deallocation
     * @dev Enforces slippage protection based on oracle prices
     * @dev During wind-down, anyone can deallocate tokens with no outstanding debt
     */
    function deallocate(
        IERC20 token,
        uint256 tokensAmount,
        ISwapper swapper,
        bytes calldata data
    ) external nonReentrant returns (uint256 expected, uint256 received) {
        _startNavCache();

        bool winddown = isWinddown();
        require((isAllocator[msg.sender] && !winddown) || (winddown && _debtBalance(token) == 0), ErrorsLib.OnlyAllocatorsOrWinddown());
        _requireIsToken(token);

        uint256 oraclePrice = oracles[token].price();
        uint256 slippageTolerance = winddown ? _winddownSlippageTolerance() : maxSlippage;

        // Execute swap
        (uint256 tokensSpent, uint256 assetsReceived) = _executeSwap(token, IERC20(asset), tokensAmount, swapper, data);

        // Calculate and validate slippage
        uint256 expectedAssets = tokensAmount.mulDiv(oraclePrice, ORACLE_PRECISION, Math.Rounding.Ceil);
        uint256 minAssets = _calculateMinAmount(expectedAssets, slippageTolerance);
        require(assetsReceived >= minAssets, ErrorsLib.TokenSaleNotGeneratingEnoughAssets());

        int256 slippagePct = _calculateSlippagePct(expectedAssets, assetsReceived);

        // Track slippage if not in winddown and we have positive slippage
        if (!winddown && assetsReceived < expectedAssets) {
            // slippage is already in asset units
            uint256 slippageValue = expectedAssets - assetsReceived;
            _increaseSlippage(slippageValue.mulDiv(PRECISION, totalAssets(), Math.Rounding.Ceil));
        }

        emit EventsLib.Deallocation(token, tokensSpent, expectedAssets, assetsReceived, slippagePct, swapper, data);

        _endNavCache();
        return (expectedAssets, assetsReceived);
    }

    /**
     * @notice Swaps between two investment tokens directly
     * @param from Source token to sell
     * @param to Target token to buy
     * @param tokensAmount Maximum amount of source token to sell
     * @param swapper Contract that will execute the swap
     * @param data Custom data for the swapper implementation
     * @return expected Expected amount of target token based on oracle prices
     * @return received Actual amount of target token received from the reallocation
     * @dev More gas efficient than separate deallocate + allocate
     */
    function reallocate(
        IERC20 from,
        IERC20 to,
        uint256 tokensAmount,
        ISwapper swapper,
        bytes calldata data
    ) external nonReentrant returns (uint256 expected, uint256 received) {
        _startNavCache();

        _onlyAllocator();
        _requireNotWinddown();
        _requireIsToken(from);
        _requireIsToken(to);

        uint256 fromOraclePrice = oracles[from].price();
        uint256 toOraclePrice = oracles[to].price();

        // Execute swap
        (uint256 fromSpent, uint256 toReceived) = _executeSwap(from, to, tokensAmount, swapper, data);

        // Calculate expected amounts and validate slippage
        uint256 fromValue = tokensAmount.mulDiv(fromOraclePrice, ORACLE_PRECISION, Math.Rounding.Ceil);
        uint256 expectedToTokens = fromValue.mulDiv(ORACLE_PRECISION, toOraclePrice, Math.Rounding.Ceil);
        uint256 minToTokens = _calculateMinAmount(expectedToTokens, maxSlippage);
        require(toReceived >= minToTokens, ErrorsLib.ReallocationSlippageTooHigh());

        int256 slippagePct = _calculateSlippagePct(expectedToTokens, toReceived);

        // Track slippage if we have positive slippage
        // Note: No winddown check needed as reallocate cannot be called during winddown
        if (toReceived < expectedToTokens) {
            uint256 slippageValue = (expectedToTokens - toReceived).mulDiv(toOraclePrice, ORACLE_PRECISION, Math.Rounding.Ceil);
            _increaseSlippage(slippageValue.mulDiv(PRECISION, totalAssets(), Math.Rounding.Ceil));
        }

        emit EventsLib.Reallocation(from, to, fromSpent, expectedToTokens, toReceived, slippagePct, swapper, data);

        _endNavCache();
        return (expectedToTokens, toReceived);
    }

    // ========== FUNDING FUNCTIONS ==========

    /**
     * @notice Posts collateral to a lending facility
     * @param fundingModule Module managing the facility
     * @param facilityData Encoded facility identifier
     * @param collateralToken Token to pledge as collateral
     * @param collateralAmount Amount to pledge
     * @dev Transfers tokens to module and updates collateral position
     */
    function pledge(
        IFunding fundingModule,
        bytes calldata facilityData,
        IERC20 collateralToken,
        uint256 collateralAmount
    ) external nonReentrant {
        _onlyAllocatorNotWinddown();
        _requireIsFunding(fundingModule);

        collateralToken.safeTransfer(address(fundingModule), collateralAmount);
        fundingModule.pledge(facilityData, collateralToken, collateralAmount);

        emit EventsLib.Pledge(fundingModule, facilityData, collateralToken, collateralAmount);
    }

    /**
     * @notice Withdraws collateral from a lending facility
     * @param fundingModule Module managing the facility
     * @param facilityData Encoded facility identifier
     * @param collateralToken Token to withdraw
     * @param collateralAmount Amount to withdraw (max uint256 = all)
     * @dev Returns tokens to vault, must maintain required collateral ratios
     */
    function depledge(
        IFunding fundingModule,
        bytes calldata facilityData,
        IERC20 collateralToken,
        uint256 collateralAmount
    ) external nonReentrant {
        _onlyAllocatorOrWinddown();
        _requireIsFunding(fundingModule);

        uint256 pledgeAmount = fundingModule.collateralBalance(facilityData, collateralToken);

        if (collateralAmount == type(uint256).max) {
            collateralAmount = pledgeAmount;
        }

        fundingModule.depledge(facilityData, collateralToken, collateralAmount);

        emit EventsLib.Depledge(fundingModule, facilityData, collateralToken, collateralAmount);
    }

    /**
     * @notice Takes out a loan from a lending facility
     * @param fundingModule Module managing the facility
     * @param facilityData Encoded facility identifier
     * @param debtToken Token to borrow
     * @param borrowAmount Amount to borrow
     * @dev Requires sufficient collateral, borrowed tokens sent to vault
     */
    function borrow(IFunding fundingModule, bytes calldata facilityData, IERC20 debtToken, uint256 borrowAmount) external nonReentrant {
        _onlyAllocatorNotWinddown();
        _requireIsFunding(fundingModule);

        fundingModule.borrow(facilityData, debtToken, borrowAmount);

        emit EventsLib.Borrow(fundingModule, facilityData, debtToken, borrowAmount);
    }

    /**
     * @notice Repays borrowed tokens to a lending facility
     * @param fundingModule Module managing the facility
     * @param facilityData Encoded facility identifier
     * @param debtToken Token to repay
     * @param repayAmount Amount to repay (max uint256 = full debt)
     * @dev Transfers tokens from vault to module, reduces debt position
     */
    function repay(IFunding fundingModule, bytes calldata facilityData, IERC20 debtToken, uint256 repayAmount) external nonReentrant {
        _onlyAllocatorOrWinddown();
        _requireIsFunding(fundingModule);

        uint256 debtAmount = fundingModule.debtBalance(facilityData, debtToken);

        if (repayAmount > debtAmount) {
            repayAmount = debtAmount;
        }

        debtToken.safeTransfer(address(fundingModule), repayAmount);
        fundingModule.repay(facilityData, debtToken, repayAmount);

        emit EventsLib.Repay(fundingModule, facilityData, debtToken, repayAmount);
    }

    /**
     * @notice Recovers non-position tokens from a funding module
     * @param fundingModule Module to skim from
     * @param token Token to recover
     * @dev NAV must remain unchanged to prevent skimming tokenized positions
     */
    function skimFunding(IFunding fundingModule, IERC20 token) external nonReentrant {
        _onlyAllocatorOrWinddown();
        _requireIsFunding(fundingModule);

        fundingModule.skim(token);
    }

    /**
     * @notice Provides temporary liquidity for complex operations
     * @param flashToken Token to flash loan
     * @param flashAmount Amount to provide temporarily
     * @param data Custom data passed to the callback
     * @dev Caller must implement IBoxFlashCallback; the Box returns the tokens within the same transaction
     * @dev NAV is cached during flash to prevent manipulation
     */
    function flash(IERC20 flashToken, uint256 flashAmount, bytes calldata data) external {
        _onlyAllocatorOrWinddown();
        _requireNonZeroAddress(address(flashToken));
        _requireIsTokenOrAsset(flashToken);
        // Prevent re-entrancy. Can't use nonReentrant modifier because of conflict with allocate/deallocate/reallocate
        require(_cachedNavDepth == 0, ErrorsLib.ReentryNotAllowed());

        // Cache NAV before starting flash operation for slippage calculations
        _startNavCache();

        // Transfer flash amount FROM caller TO this contract
        flashToken.safeTransferFrom(msg.sender, address(this), flashAmount);

        // Call the callback function on the caller
        IBoxFlashCallback(msg.sender).onBoxFlash(flashToken, flashAmount, data);

        // Repay the flash loan by transferring back TO caller
        flashToken.safeTransfer(msg.sender, flashAmount);

        _endNavCache();

        emit EventsLib.Flash(msg.sender, flashToken, flashAmount);
    }

    /**
     * @notice Executes multiple calls in a single transaction
     * @param data Array of encoded function calls
     * @dev Allows EOAs to execute multiple operations atomically
     */
    function multicall(bytes[] calldata data) external {
        uint256 length = data.length;
        for (uint256 i = 0; i < length; i++) {
            (bool success, bytes memory returnData) = address(this).delegatecall(data[i]);
            if (!success) {
                assembly ("memory-safe") {
                    revert(add(32, returnData), mload(returnData))
                }
            }
        }
    }

    // ========== ADMIN FUNCTIONS ==========

    /**
     * @notice Sets the address that receives skimmed tokens
     * @param newSkimRecipient New recipient address for skimmed tokens
     * @dev Only owner can call this function
     */
    function setSkimRecipient(address newSkimRecipient) external {
        _onlyOwner();
        _requireNonZeroAddress(newSkimRecipient);
        address oldRecipient = skimRecipient;
        _requireNotEqualAddress(newSkimRecipient, oldRecipient);

        skimRecipient = newSkimRecipient;

        emit EventsLib.SkimRecipientUpdated(oldRecipient, newSkimRecipient);
    }

    /**
     * @notice Transfers ownership of the contract
     * @param newOwner Address that will become the new owner
     * @dev Immediately transfers all owner privileges
     */
    function transferOwnership(address newOwner) external {
        _requireNonZeroAddress(newOwner);
        address oldOwner = owner;
        _onlyOwner();
        _requireNotEqualAddress(newOwner, oldOwner);

        owner = newOwner;

        emit EventsLib.OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @notice Sets a new curator for the vault
     * @param newCurator Address that will manage tokens and funding
     * @dev Only owner can update the curator
     */
    function setCurator(address newCurator) external {
        _onlyOwner();
        _requireNonZeroAddress(newCurator);
        _requireNotEqualAddress(newCurator, curator);

        address oldCurator = curator;
        curator = newCurator;

        emit EventsLib.CuratorUpdated(oldCurator, newCurator);
    }

    /**
     * @notice Sets a new guardian with emergency powers
     * @param newGuardian Address that can trigger shutdowns and revoke actions
     * @dev Requires timelock, only curator can execute
     */
    function setGuardian(address newGuardian) external {
        _requireNotWinddown();
        timelocked();
        _onlyCurator();
        _requireNonZeroAddress(newGuardian);
        _requireNotEqualAddress(newGuardian, guardian);

        address oldGuardian = guardian;
        guardian = newGuardian;

        emit EventsLib.GuardianUpdated(oldGuardian, newGuardian);
    }

    /**
     * @notice Grants or revokes allocator privileges
     * @param account Address to modify permissions for
     * @param newIsAllocator True to grant allocator role, false to revoke
     * @dev Allocators can execute investment strategies
     */
    function setIsAllocator(address account, bool newIsAllocator) external {
        _onlyCurator();
        _requireNonZeroAddress(account);
        require(isAllocator[account] != newIsAllocator, ErrorsLib.InvalidValue());

        isAllocator[account] = newIsAllocator;

        emit EventsLib.AllocatorUpdated(account, newIsAllocator);
    }

    /**
     * @notice Initiates emergency shutdown of the vault
     * @dev Stops deposits and starts the wind-down process after warmup period
     * @dev Guardian or curator can trigger shutdown
     */
    function shutdown() external {
        require(msg.sender == guardian || msg.sender == curator, ErrorsLib.OnlyGuardianOrCuratorCanShutdown());
        require(!isShutdown(), ErrorsLib.AlreadyShutdown());

        shutdownTime = block.timestamp;

        emit EventsLib.Shutdown(msg.sender);
    }

    /**
     * @notice Cancels shutdown and returns vault to normal operation
     * @dev Only guardian can recover, must be before wind-down phase starts
     */
    function recover() external {
        require(msg.sender == guardian, ErrorsLib.OnlyGuardianCanRecover());
        require(isShutdown(), ErrorsLib.NotShutdown());
        require(!isWinddown(), ErrorsLib.CannotRecoverAfterWinddown());

        shutdownTime = type(uint256).max;

        emit EventsLib.Recover(msg.sender);
    }

    // ========== TIMELOCK GOVERNANCE ==========

    /**
     * @notice Submits a function call to the timelock queue
     * @param data Encoded function call to be executed after delay
     * @dev Delay duration depends on the function selector
     * @dev WARNING: Timelock periods are 0 by default. Users and the box owner should ensure that
     *      sufficiently long timelock periods are set for all critical functions (especially setGuardian)
     *      to allow the guardian time to react if the curator is compromised.
     */
    function submit(bytes calldata data) external {
        _onlyCurator();
        require(executableAt[data] == 0, ErrorsLib.DataAlreadyTimelocked());
        require(data.length >= 4, ErrorsLib.InvalidAmount());

        bytes4 selector = bytes4(data);
        uint256 delay = selector == IBox.decreaseTimelock.selector ? timelock[bytes4(data[4:8])] : timelock[selector];
        require(delay != TIMELOCK_DISABLED, ErrorsLib.FunctionDisabled());
        executableAt[data] = block.timestamp + delay;

        emit EventsLib.TimelockSubmitted(selector, data, executableAt[data], msg.sender);
    }

    /**
     * @dev Validates and consumes a timelocked transaction
     * @dev Checks if current calldata is timelocked and ready for execution
     */
    function timelocked() internal {
        require(executableAt[msg.data] > 0, ErrorsLib.DataNotTimelocked());
        require(block.timestamp >= executableAt[msg.data], ErrorsLib.TimelockNotExpired());

        executableAt[msg.data] = 0;

        emit EventsLib.TimelockExecuted(bytes4(msg.data), msg.data, msg.sender);
    }

    /**
     * @notice Cancels a pending timelocked transaction
     * @param data Encoded function call to cancel
     * @dev Guardian or curator can revoke pending transactions
     */
    function revoke(bytes calldata data) external {
        require(msg.sender == curator || msg.sender == guardian, ErrorsLib.OnlyCuratorOrGuardian());
        require(executableAt[data] > 0, ErrorsLib.DataNotTimelocked());

        executableAt[data] = 0;

        emit EventsLib.TimelockRevoked(bytes4(data), data, msg.sender);
    }

    /**
     * @notice Extends the timelock delay for a function
     * @param selector Function signature to modify
     * @param newDuration New delay in seconds (must be longer than current)
     * @dev No timelock required to increase delays
     */
    function increaseTimelock(bytes4 selector, uint256 newDuration) external {
        _onlyCurator();
        require(newDuration <= TIMELOCK_CAP, ErrorsLib.InvalidTimelock());
        require(newDuration > timelock[selector], ErrorsLib.TimelockNotIncreasing());

        timelock[selector] = newDuration;

        emit EventsLib.TimelockIncreased(selector, newDuration, msg.sender);
    }

    /**
     * @notice Reduces the timelock delay for a function
     * @param selector Function signature to modify
     * @param newDuration New delay in seconds (must be shorter than current)
     * @dev Requires timelock to prevent governance attacks
     */
    function decreaseTimelock(bytes4 selector, uint256 newDuration) external {
        timelocked();
        _onlyCurator();
        uint256 currentTimelock = timelock[selector];
        require(currentTimelock != TIMELOCK_DISABLED, ErrorsLib.InvalidTimelock());
        require(newDuration < currentTimelock, ErrorsLib.TimelockNotDecreasing());

        timelock[selector] = newDuration;

        emit EventsLib.TimelockDecreased(selector, newDuration, msg.sender);
    }

    /**
     * @notice Permanently disables a function by setting infinite timelock
     * @param selector Function signature to disable
     * @dev Irreversible - function becomes permanently inaccessible
     * @dev Does not impact previsously queued changes
     */
    function abdicateTimelock(bytes4 selector) external {
        _onlyCurator();

        timelock[selector] = TIMELOCK_DISABLED;

        emit EventsLib.TimelockIncreased(selector, TIMELOCK_DISABLED, msg.sender);
    }

    // ========== TIMELOCKED FUNCTIONS ==========

    /**
     * @notice Grants or revokes deposit privileges
     * @param account Address to modify permissions for
     * @param newIsFeeder True to allow deposits, false to revoke
     * @dev Requires timelock to add feeders
     */
    function setIsFeeder(address account, bool newIsFeeder) external {
        timelocked();
        _requireNonZeroAddress(account);
        require(isFeeder[account] != newIsFeeder, ErrorsLib.InvalidValue());

        isFeeder[account] = newIsFeeder;

        emit EventsLib.FeederUpdated(account, newIsFeeder);
    }

    /**
     * @notice Sets the maximum tolerated slippage for swaps
     * @param newMaxSlippage New limit scaled by PRECISION (e.g., 0.01e18 = 1%)
     * @dev Requires timelock, applies per-swap and per-epoch
     */
    function setMaxSlippage(uint256 newMaxSlippage) external {
        timelocked();
        require(newMaxSlippage <= MAX_SLIPPAGE_LIMIT, ErrorsLib.SlippageTooHigh());
        _requireNotEqual(newMaxSlippage, maxSlippage);

        uint256 oldMaxSlippage = maxSlippage;
        maxSlippage = newMaxSlippage;

        emit EventsLib.MaxSlippageUpdated(oldMaxSlippage, newMaxSlippage);
    }

    /**
     * @notice Whitelists a new investment token
     * @param token Token contract to add
     * @param oracle Price feed for the token
     * @dev Requires timelock, oracle must return prices in base asset terms
     */
    function addToken(IERC20 token, IOracle oracle) external {
        timelocked();
        _requireNonZeroAddress(address(token));
        _requireNotEqualAddress(address(token), asset);
        require(address(oracle) != address(0), ErrorsLib.OracleRequired());
        require(!isToken(token), ErrorsLib.TokenAlreadyWhitelisted());
        require(tokens.length < MAX_TOKENS, ErrorsLib.TooManyTokens());

        tokens.push(token);
        oracles[token] = oracle;

        emit EventsLib.TokenAdded(token, oracle);
    }

    /**
     * @notice Removes a token from the whitelist
     * @param token Token to delist
     * @dev Token balance must be zero and not used in any funding module
     */
    function removeToken(IERC20 token) external {
        _onlyCurator();
        _requireIsToken(token);
        require(token.balanceOf(address(this)) == 0, ErrorsLib.TokenBalanceMustBeZero());
        require(!_isTokenUsedInFunding(token), ErrorsLib.CannotRemove());

        uint256 length = tokens.length;
        for (uint256 i; i < length; i++) {
            if (tokens[i] == token) {
                tokens[i] = tokens[length - 1];
                tokens.pop();
                break;
            }
        }

        delete oracles[token];

        emit EventsLib.TokenRemoved(token);
    }

    /**
     * @notice Updates the price oracle for a whitelisted token
     * @param token Token to update oracle for
     * @param oracle New price feed contract
     * @dev Requires timelock in normal operation, guardian can update during final wind-down
     */
    function changeTokenOracle(IERC20 token, IOracle oracle) external {
        if (isWinddown()) {
            require(block.timestamp >= shutdownTime + shutdownWarmup + shutdownSlippageDuration, ErrorsLib.NotAllowed());
            _onlyGuardian();
        } else {
            _onlyCurator();
            timelocked();
        }
        _requireNonZeroAddress(address(oracle));
        _requireIsToken(token);
        _requireNotEqualAddress(address(oracles[token]), address(oracle));

        oracles[token] = oracle;

        emit EventsLib.TokenOracleChanged(token, oracle);
    }

    /**
     * @notice Adds a new funding module for borrowing/lending
     * @param fundingModule Module contract to whitelist
     * @dev Module must be empty with no facilities, collateral, or debt
     */
    function addFunding(IFunding fundingModule) external {
        timelocked();
        require(!fundingMap[fundingModule], ErrorsLib.AlreadyWhitelisted());
        _requireNonZeroAddress(address(fundingModule));
        // Check that Box is the owner of the funding module
        (bool success, bytes memory data) = address(fundingModule).staticcall(abi.encodeWithSignature("owner()"));
        require(success && data.length == 32, ErrorsLib.InvalidValue());
        address fundingOwner = abi.decode(data, (address));
        require(fundingOwner == address(this), ErrorsLib.InvalidValue());
        require(fundingModule.facilitiesLength() == 0, ErrorsLib.NotClean());
        require(fundingModule.collateralTokensLength() == 0, ErrorsLib.NotClean());
        require(fundingModule.debtTokensLength() == 0, ErrorsLib.NotClean());

        fundingMap[fundingModule] = true;
        fundings.push(fundingModule);

        emit EventsLib.FundingModuleAdded(fundingModule);
    }

    /**
     * @notice Registers a lending facility within a funding module
     * @param fundingModule Module to add facility to
     * @param facilityData Encoded facility parameters
     * @dev Requires timelock, facility specifics depend on module implementation
     */
    function addFundingFacility(IFunding fundingModule, bytes calldata facilityData) external {
        timelocked();
        _requireIsFunding(fundingModule);

        fundingModule.addFacility(facilityData);

        emit EventsLib.FundingFacilityAdded(fundingModule, facilityData);
    }

    /**
     * @notice Enables a token as collateral in a funding module
     * @param fundingModule Module to configure
     * @param collateralToken Token to use as collateral
     * @dev Token must be whitelisted in the vault first
     */
    function addFundingCollateral(IFunding fundingModule, IERC20 collateralToken) external {
        timelocked();
        _requireIsFunding(fundingModule);
        _requireIsTokenOrAsset(collateralToken);

        fundingModule.addCollateralToken(collateralToken);

        emit EventsLib.FundingCollateralAdded(fundingModule, collateralToken);
    }

    /**
     * @notice Enables a token for borrowing in a funding module
     * @param fundingModule Module to configure
     * @param debtToken Token that can be borrowed
     * @dev Token must be whitelisted in the vault first
     */
    function addFundingDebt(IFunding fundingModule, IERC20 debtToken) external {
        timelocked();
        _requireIsFunding(fundingModule);
        _requireIsTokenOrAsset(debtToken);

        fundingModule.addDebtToken(debtToken);

        emit EventsLib.FundingDebtAdded(fundingModule, debtToken);
    }

    /**
     * @notice Removes a funding module from the vault
     * @param fundingModule Module to remove
     * @dev Module must be empty with no active facilities, collateral, or debt
     */
    function removeFunding(IFunding fundingModule) external {
        _onlyCurator();
        _requireIsFunding(fundingModule);

        require(fundingModule.facilitiesLength() == 0, ErrorsLib.CannotRemove());
        require(fundingModule.collateralTokensLength() == 0, ErrorsLib.CannotRemove());
        require(fundingModule.debtTokensLength() == 0, ErrorsLib.CannotRemove());

        fundingMap[fundingModule] = false;
        uint256 index = _findFundingIndex(fundingModule);
        fundings[index] = fundings[fundings.length - 1];
        fundings.pop();

        emit EventsLib.FundingModuleRemoved(fundingModule);
    }

    /**
     * @notice Deregisters a lending facility from a funding module
     * @param fundingModule Module containing the facility
     * @param facilityData Encoded facility identifier
     * @dev Facility must have no outstanding positions
     */
    function removeFundingFacility(IFunding fundingModule, bytes calldata facilityData) external {
        _onlyCurator();
        _requireIsFunding(fundingModule);

        fundingModule.removeFacility(facilityData);

        emit EventsLib.FundingFacilityRemoved(fundingModule, facilityData);
    }

    /**
     * @notice Disables a token as collateral in a funding module
     * @param fundingModule Module to update
     * @param collateralToken Token to remove from collateral list
     * @dev Token must not be actively used as collateral
     */
    function removeFundingCollateral(IFunding fundingModule, IERC20 collateralToken) external {
        _onlyCurator();
        _requireIsFunding(fundingModule);

        fundingModule.removeCollateralToken(collateralToken);

        emit EventsLib.FundingCollateralRemoved(fundingModule, collateralToken);
    }

    /**
     * @notice Disables borrowing of a token in a funding module
     * @param fundingModule Module to update
     * @param debtToken Token to remove from debt list
     * @dev No outstanding debt must exist for this token
     */
    function removeFundingDebt(IFunding fundingModule, IERC20 debtToken) external {
        _onlyCurator();
        _requireIsFunding(fundingModule);

        fundingModule.removeDebtToken(debtToken);

        emit EventsLib.FundingDebtRemoved(fundingModule, debtToken);
    }

    // ========== VIEW FUNCTIONS ==========
    /**
     * @notice Checks if a token is whitelisted for investment
     * @param token Token to check
     * @return True if the token has an associated oracle
     */
    function isToken(IERC20 token) public view returns (bool) {
        return address(oracles[token]) != address(0);
    }

    /**
     * @notice Checks if a token is the base asset or a whitelisted token
     * @param token Token to check
     * @return True if it's the base asset or has an oracle
     */
    function isTokenOrAsset(IERC20 token) public view returns (bool) {
        return address(token) == asset || address(oracles[token]) != address(0);
    }

    /**
     * @notice Gets the count of whitelisted tokens
     * @return Number of tokens in the investment list
     */
    function tokensLength() external view returns (uint256) {
        return tokens.length;
    }

    /**
     * @notice Checks if a funding module is authorized
     * @param fundingModule Module to verify
     * @return True if the module can be used for borrowing/lending
     */
    function isFunding(IFunding fundingModule) public view returns (bool) {
        return fundingMap[fundingModule];
    }

    /**
     * @notice Gets the count of active funding modules
     * @return Number of modules available for borrowing/lending
     */
    function fundingsLength() external view override returns (uint256) {
        return fundings.length;
    }

    /**
     * @notice Checks if the vault is in shutdown mode
     * @return True if shutdown has been triggered
     */
    function isShutdown() public view returns (bool) {
        return shutdownTime != type(uint256).max;
    }

    /**
     * @notice Checks if the vault has entered wind-down phase
     * @return True if past the warmup period after shutdown
     */
    function isWinddown() public view returns (bool) {
        return shutdownTime != type(uint256).max && block.timestamp >= shutdownTime + shutdownWarmup;
    }

    // ========== INTERNAL FUNCTIONS ==========

    /**
     * @dev Checks if msg.sender is the owner
     */
    function _onlyOwner() internal view {
        require(msg.sender == owner, ErrorsLib.OnlyOwner());
    }

    /**
     * @dev Checks if msg.sender is the curator
     */
    function _onlyCurator() internal view {
        require(msg.sender == curator, ErrorsLib.OnlyCurator());
    }

    /**
     * @dev Checks that an address is not zero
     */
    function _requireNonZeroAddress(address addr) internal pure {
        require(addr != address(0), ErrorsLib.InvalidAddress());
    }

    /**
     * @dev Checks if a token is whitelisted
     */
    function _requireIsToken(IERC20 token) internal view {
        require(isToken(token), ErrorsLib.TokenNotWhitelisted());
    }

    /**
     * @dev Checks if a funding module is whitelisted
     */
    function _requireIsFunding(IFunding fundingModule) internal view {
        require(isFunding(fundingModule), ErrorsLib.NotWhitelisted());
    }

    /**
     * @dev Checks that vault is not in winddown
     */
    function _requireNotWinddown() internal view {
        require(!isWinddown(), ErrorsLib.CannotDuringWinddown());
    }

    /**
     * @dev Checks if msg.sender is allocator and not in winddown
     */
    function _onlyAllocatorNotWinddown() internal view {
        require(isAllocator[msg.sender] && !isWinddown(), ErrorsLib.OnlyAllocators());
    }

    /**
     * @dev Checks if msg.sender is allocator or in winddown
     */
    function _onlyAllocatorOrWinddown() internal view {
        require(isAllocator[msg.sender] || isWinddown(), ErrorsLib.OnlyAllocatorsOrWinddown());
    }

    /**
     * @dev Checks that two values are not equal
     */
    function _requireNotEqual(uint256 a, uint256 b) internal pure {
        require(a != b, ErrorsLib.InvalidValue());
    }

    /**
     * @dev Checks that two addresses are not equal
     */
    function _requireNotEqualAddress(address a, address b) internal pure {
        require(a != b, ErrorsLib.InvalidValue());
    }

    /**
     * @dev Checks if msg.sender is the guardian
     */
    function _onlyGuardian() internal view {
        require(msg.sender == guardian, ErrorsLib.OnlyGuardian());
    }

    /**
     * @dev Checks if msg.sender is allocator
     */
    function _onlyAllocator() internal view {
        require(isAllocator[msg.sender], ErrorsLib.OnlyAllocators());
    }

    /**
     * @dev Checks if msg.sender is feeder
     */
    function _onlyFeeder() internal view {
        require(isFeeder[msg.sender], ErrorsLib.OnlyFeeders());
    }

    /**
     * @dev Checks that vault is not shutdown
     */
    function _requireNotShutdown() internal view {
        require(!isShutdown(), ErrorsLib.CannotDuringShutdown());
    }

    /**
     * @dev Checks if token is whitelisted or is the base asset
     */
    function _requireIsTokenOrAsset(IERC20 token) internal view {
        require(isTokenOrAsset(token), ErrorsLib.TokenNotWhitelisted());
    }

    /**
     * @dev Starts NAV caching for the current operation
     * @dev Caches NAV on first call (depth 0 -> 1), increments depth on nested calls
     * @dev Properly handles nesting when swaps are called from flash callbacks
     */
    function _startNavCache() internal {
        if (_cachedNavDepth == 0) {
            _cachedNav = _nav();
        }
        _cachedNavDepth++;
    }

    /**
     * @dev Ends NAV caching for the current operation
     * @dev Decrements the depth counter
     */
    function _endNavCache() internal {
        _cachedNavDepth--;
    }

    /**
     * @dev Executes a swap through a swapper contract with approval management
     * @param fromToken Token to sell
     * @param toToken Token to buy
     * @param maxAmount Maximum amount of fromToken to sell
     * @param swapper Swapper contract to execute the trade
     * @param data Custom data for the swapper
     * @return spent Actual amount of fromToken spent
     * @return received Amount of toToken received
     */
    function _executeSwap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 maxAmount,
        ISwapper swapper,
        bytes calldata data
    ) internal returns (uint256 spent, uint256 received) {
        uint256 fromBefore = fromToken.balanceOf(address(this));
        uint256 toBefore = toToken.balanceOf(address(this));

        fromToken.forceApprove(address(swapper), maxAmount);
        swapper.sell(fromToken, toToken, maxAmount, data);
        fromToken.forceApprove(address(swapper), 0);

        spent = fromBefore - fromToken.balanceOf(address(this));
        received = toToken.balanceOf(address(this)) - toBefore;

        require(spent <= maxAmount, ErrorsLib.SwapperDidSpendTooMuch());
    }

    /**
     * @dev Calculates slippage percentage from expected vs actual amounts
     * @param expectedAmount Expected amount based on oracle price
     * @param actualAmount Actual amount received/spent
     * @return slippagePct Slippage as a percentage scaled by PRECISION
     */
    function _calculateSlippagePct(uint256 expectedAmount, uint256 actualAmount) internal pure returns (int256 slippagePct) {
        if (expectedAmount == 0) return 0;

        int256 slippage = expectedAmount.toInt256() - actualAmount.toInt256();
        // Round up when calculating slippage to be conservative
        if (slippage >= 0) {
            // Positive slippage (loss): round up
            slippagePct = int256(uint256(slippage).mulDiv(PRECISION, expectedAmount, Math.Rounding.Ceil));
        } else {
            // Negative slippage (gain): round down (more conservative)
            slippagePct = -int256(uint256(-slippage).mulDiv(PRECISION, expectedAmount, Math.Rounding.Floor));
        }
    }

    /**
     * @dev Calculates minimum acceptable amount based on slippage tolerance
     * @param expectedAmount Expected amount based on oracle price
     * @param tolerance Maximum allowed slippage scaled by PRECISION
     * @return minAmount Minimum acceptable amount after slippage
     */
    function _calculateMinAmount(uint256 expectedAmount, uint256 tolerance) internal pure returns (uint256 minAmount) {
        minAmount = expectedAmount.mulDiv(PRECISION - tolerance, PRECISION, Math.Rounding.Ceil);
    }

    /**
     * @dev Tracks slippage within current epoch and enforces limits
     * @param slippagePct Slippage to add scaled by PRECISION
     * @dev Resets epoch if duration has passed
     */
    function _increaseSlippage(uint256 slippagePct) internal {
        // Reset epoch if expired
        if (block.timestamp >= slippageEpochStart + slippageEpochDuration) {
            slippageEpochStart = block.timestamp;
            accumulatedSlippage = slippagePct;
            emit EventsLib.SlippageEpochReset(block.timestamp);
        } else {
            accumulatedSlippage += slippagePct;
        }

        require(accumulatedSlippage < maxSlippage, ErrorsLib.TooMuchAccumulatedSlippage());

        emit EventsLib.SlippageAccumulated(slippagePct, accumulatedSlippage);
    }

    /**
     * @dev Calculates total vault value across all positions
     * @return nav Sum of base asset, token values, and funding positions
     * @dev Negative funding NAV is floored to zero
     * @dev Reverts if called during NAV-cached operations (swaps or flash) to prevent read-only reentrancy
     */
    function _nav() internal view returns (uint256 nav) {
        require(_cachedNavDepth == 0, ErrorsLib.NoNavDuringCache());
        nav = IERC20(asset).balanceOf(address(this));

        // Add value of all tokens
        uint256 length = tokens.length;
        for (uint256 i; i < length; i++) {
            IERC20 token = tokens[i];
            IOracle oracle = oracles[token];
            uint256 tokenBalance = token.balanceOf(address(this));
            if (tokenBalance > 0) {
                nav += tokenBalance.mulDiv(oracle.price(), ORACLE_PRECISION);
            }
        }
        // Loop over funding sources
        length = fundings.length;
        for (uint256 i; i < length; i++) {
            IFunding funding = fundings[i];
            nav += funding.nav(IOracleCallback(address(this)));
        }
    }

    /**
     * @dev Calculates dynamic slippage tolerance during wind-down
     * @return Slippage limit that increases linearly over shutdown duration
     * @dev Returns up to 1% slippage after full duration
     */
    function _winddownSlippageTolerance() internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - shutdownWarmup - shutdownTime;
        return
            (timeElapsed < shutdownSlippageDuration)
                ? timeElapsed.mulDiv(MAX_SLIPPAGE_LIMIT, shutdownSlippageDuration)
                : MAX_SLIPPAGE_LIMIT;
    }

    /**
     * @dev Locates a funding module's position in the array
     * @param fundingModule Module to find
     * @return Index in the fundings array
     * @dev Reverts if module is not whitelisted
     */
    function _findFundingIndex(IFunding fundingModule) internal view returns (uint256) {
        uint256 length = fundings.length;
        for (uint256 i = 0; i < length; i++) {
            if (fundings[i] == fundingModule) {
                return i;
            }
        }
        revert ErrorsLib.NotWhitelisted();
    }

    /**
     * @dev Checks if a token is used in any funding module
     * @param token Token to check
     * @return True if token is used as collateral or debt anywhere
     */
    function _isTokenUsedInFunding(IERC20 token) internal view returns (bool) {
        uint256 length = fundings.length;
        for (uint256 i; i < length; i++) {
            IFunding funding = fundings[i];
            if (funding.isCollateralToken(token) || funding.isDebtToken(token)) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Sums outstanding debt for a token across all modules
     * @param debtToken Token to check debt for
     * @return totalDebt Combined debt balance from all facilities
     */
    function _debtBalance(IERC20 debtToken) internal view returns (uint256 totalDebt) {
        uint256 length = fundings.length;
        for (uint256 i; i < length; i++) {
            IFunding funding = fundings[i];
            totalDebt += funding.debtBalance(debtToken);
        }
    }
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Steakhouse
pragma solidity >=0.8.0;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFunding, IOracleCallback} from "./IFunding.sol";
import {IOracle} from "./IOracle.sol";
import {ISwapper} from "./ISwapper.sol";

/// @notice Callback interface for Box flash loans
interface IBoxFlashCallback {
    function onBoxFlash(IERC20 token, uint256 amount, bytes calldata data) external;
}

interface IBox is IERC4626, IOracleCallback {
    /* FUNCTIONS */

    // ========== STATE FUNCTIONS ==========
    function asset() external view override(IERC4626, IOracleCallback) returns (address);
    function slippageEpochDuration() external view returns (uint256);
    function shutdownSlippageDuration() external view returns (uint256);
    function shutdownWarmup() external view returns (uint256);
    function owner() external view returns (address);
    function curator() external view returns (address);
    function guardian() external view returns (address);
    function shutdownTime() external view returns (uint256);
    function skimRecipient() external view returns (address);
    function isAllocator(address account) external view returns (bool);
    function isFeeder(address account) external view returns (bool);
    function tokens(uint256 index) external view returns (IERC20);
    function oracles(IERC20 token) external view returns (IOracle);
    function maxSlippage() external view returns (uint256);
    function accumulatedSlippage() external view returns (uint256);
    function slippageEpochStart() external view returns (uint256);
    function executableAt(bytes calldata data) external view returns (uint256);

    // ========== INVESTMENT MANAGEMENT ==========
    function skim(IERC20 token) external;
    function skimFunding(IFunding fundingModule, IERC20 token) external;
    function allocate(
        IERC20 token,
        uint256 assetsAmount,
        ISwapper swapper,
        bytes calldata data
    ) external returns (uint256 expected, uint256 received);
    function deallocate(
        IERC20 token,
        uint256 tokensAmount,
        ISwapper swapper,
        bytes calldata data
    ) external returns (uint256 expected, uint256 received);
    function reallocate(
        IERC20 from,
        IERC20 to,
        uint256 tokensAmount,
        ISwapper swapper,
        bytes calldata data
    ) external returns (uint256 expected, uint256 received);

    // ========== SIMPLE FUNDING OPERATIONS ==========
    function pledge(IFunding fundingModule, bytes calldata facilityData, IERC20 collateralToken, uint256 collateralAmount) external;
    function depledge(IFunding fundingModule, bytes calldata facilityData, IERC20 collateralToken, uint256 collateralAmount) external;
    function borrow(IFunding fundingModule, bytes calldata facilityData, IERC20 debtToken, uint256 borrowAmount) external;
    function repay(IFunding fundingModule, bytes calldata facilityData, IERC20 debtToken, uint256 repayAmount) external;

    // ========== COMPLEX FUNDING OPERATIONS WITH FLASHLOAN AND SWAPPER ==========
    function flash(IERC20 flashToken, uint256 flashAmount, bytes calldata data) external;

    // ========== BATCHING ==========
    function multicall(bytes[] calldata data) external;

    // ========== EMERGENCY ==========
    function shutdown() external;
    function recover() external;

    // ========== ADMIN FUNCTIONS ==========
    function setSkimRecipient(address newSkimRecipient) external;
    function transferOwnership(address newOwner) external;
    function setCurator(address newCurator) external;
    function setGuardian(address newGuardian) external;
    function setIsAllocator(address account, bool newIsAllocator) external;

    // ========== TIMELOCK GOVERNANCE ==========
    function submit(bytes calldata data) external;
    function timelock(bytes4 selector) external view returns (uint256);
    function revoke(bytes calldata data) external;
    function increaseTimelock(bytes4 selector, uint256 newDuration) external;
    function decreaseTimelock(bytes4 selector, uint256 newDuration) external;
    function abdicateTimelock(bytes4 selector) external;

    // ========== TIMELOCKED FUNCTIONS ==========
    function setIsFeeder(address account, bool newIsFeeder) external;
    function setMaxSlippage(uint256 newMaxSlippage) external;
    function addToken(IERC20 token, IOracle oracle) external;
    function removeToken(IERC20 token) external;
    function changeTokenOracle(IERC20 token, IOracle oracle) external;

    // ========== VIEW FUNCTIONS ==========
    function isToken(IERC20 token) external view returns (bool);
    function isTokenOrAsset(IERC20 token) external view returns (bool);
    function tokensLength() external view returns (uint256);
    function isShutdown() external view returns (bool);
    function isWinddown() external view returns (bool);

    // ========== FUNDING ADMIN FUNCTIONS ==========
    function addFunding(IFunding fundingModule) external;
    function addFundingFacility(IFunding fundingModule, bytes calldata facilityData) external;
    function addFundingCollateral(IFunding fundingModule, IERC20 collateralToken) external;
    function addFundingDebt(IFunding fundingModule, IERC20 debtToken) external;
    function removeFunding(IFunding fundingModule) external;
    function removeFundingFacility(IFunding fundingModule, bytes calldata facilityData) external;
    function removeFundingCollateral(IFunding fundingModule, IERC20 collateralToken) external;
    function removeFundingDebt(IFunding fundingModule, IERC20 debtToken) external;

    // ========== FUNDING VIEW FUNCTIONS ==========
    function fundings(uint256 index) external view returns (IFunding);
    function fundingsLength() external view returns (uint256);
    function isFunding(IFunding fundingModule) external view returns (bool);
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association, Steakhouse Financial
pragma solidity 0.8.28;

import {BoxAdapter} from "./../BoxAdapter.sol";
import {IBox} from "./../interfaces/IBox.sol";
import {IBoxAdapter} from "./../interfaces/IBoxAdapter.sol";
import {IBoxAdapterFactory} from "./../interfaces/IBoxAdapterFactory.sol";

contract BoxAdapterFactory is IBoxAdapterFactory {
    /* STORAGE */

    mapping(address parentVault => mapping(IBox box => IBoxAdapter)) public boxAdapter;
    mapping(address account => bool) public isBoxAdapter;

    /* FUNCTIONS */

    /// @dev Returns the address of the deployed BoxAdapter.
    /// @dev Uses CREATE2 with fixed salt to prevent duplicate adapters for the same (parentVault, box) pair.
    function createBoxAdapter(address parentVault, IBox box) external returns (IBoxAdapter) {
        BoxAdapter _boxAdapter = new BoxAdapter{salt: bytes32(0)}(parentVault, box);
        boxAdapter[parentVault][box] = _boxAdapter;
        isBoxAdapter[address(_boxAdapter)] = true;
        emit CreateBoxAdapter(parentVault, address(box), _boxAdapter);
        return _boxAdapter;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

pragma solidity >=0.4.16;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
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
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
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
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity 0.8.28;

import {IVaultV2} from "../interfaces/IVaultV2.sol";
import {IERC4626} from "../interfaces/IERC4626.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IMorphoVaultV1Adapter} from "./interfaces/IMorphoVaultV1Adapter.sol";
import {SafeERC20Lib} from "../libraries/SafeERC20Lib.sol";

/// @dev Designed, developed and audited for Morpho Vaults V1 (V1.0 and V1.1) (also known as MetaMorpho). Integration
/// with other vaults must be carefully assessed from a security standpoint.
/// @dev This adapter must be used with Morpho Vaults V1 that are protected against inflation attacks with an initial
/// deposit. See https://docs.openzeppelin.com/contracts/5.x/erc4626#inflation-attack.
/// @dev Must not be used with a Morpho Vault V1 which has a market with an Irm that can re-enter the parent vault or
/// the adapter.
/// @dev Morpho Vaults V1.1 do not realize bad debt, so Morpho Vaults V2 supplying in them will not realize the
/// corresponding bad debt.
/// @dev Losses that correspond to rounding errors are realizable.
/// @dev Shares of the Morpho Vault V1 cannot be skimmed (unlike any other token).
/// @dev If expectedSupplyAssets reverts for a market of the morphoVaultV1, realAssets will revert and the vault will
/// not be able to accrueInterest.
/// @dev Shouldn't be used alongside another adapter that re-uses the id (abi.encode("this", address(this)).
contract MorphoVaultV1Adapter is IMorphoVaultV1Adapter {
    /* IMMUTABLES */

    address public immutable factory;
    address public immutable parentVault;
    address public immutable morphoVaultV1;
    bytes32 public immutable adapterId;

    /* STORAGE */

    address public skimRecipient;

    /* FUNCTIONS */

    constructor(address _parentVault, address _morphoVaultV1) {
        factory = msg.sender;
        parentVault = _parentVault;
        morphoVaultV1 = _morphoVaultV1;
        adapterId = keccak256(abi.encode("this", address(this)));
        address asset = IVaultV2(_parentVault).asset();
        require(asset == IERC4626(_morphoVaultV1).asset(), AssetMismatch());
        SafeERC20Lib.safeApprove(asset, _parentVault, type(uint256).max);
        SafeERC20Lib.safeApprove(asset, _morphoVaultV1, type(uint256).max);
    }

    function setSkimRecipient(address newSkimRecipient) external {
        require(msg.sender == IVaultV2(parentVault).owner(), NotAuthorized());
        skimRecipient = newSkimRecipient;
        emit SetSkimRecipient(newSkimRecipient);
    }

    /// @dev Skims the adapter's balance of `token` and sends it to `skimRecipient`.
    /// @dev This is useful to handle rewards that the adapter has earned.
    function skim(address token) external {
        require(msg.sender == skimRecipient, NotAuthorized());
        require(token != morphoVaultV1, CannotSkimMorphoVaultV1Shares());
        uint256 balance = IERC20(token).balanceOf(address(this));
        SafeERC20Lib.safeTransfer(token, skimRecipient, balance);
        emit Skim(token, balance);
    }

    /// @dev Does not log anything because the ids (logged in the parent vault) are enough.
    /// @dev Returns the ids of the allocation and the change in allocation.
    function allocate(bytes memory data, uint256 assets, bytes4, address) external returns (bytes32[] memory, int256) {
        require(data.length == 0, InvalidData());
        require(msg.sender == parentVault, NotAuthorized());

        if (assets > 0) IERC4626(morphoVaultV1).deposit(assets, address(this));
        uint256 oldAllocation = allocation();
        uint256 newAllocation = IERC4626(morphoVaultV1).previewRedeem(IERC4626(morphoVaultV1).balanceOf(address(this)));

        // Safe casts because Market V1 bounds the total supply of the underlying token, and allocation is less than the
        // max total assets of the vault.
        return (ids(), int256(newAllocation) - int256(oldAllocation));
    }

    /// @dev Does not log anything because the ids (logged in the parent vault) are enough.
    /// @dev Returns the ids of the deallocation and the change in allocation.
    function deallocate(bytes memory data, uint256 assets, bytes4, address)
        external
        returns (bytes32[] memory, int256)
    {
        require(data.length == 0, InvalidData());
        require(msg.sender == parentVault, NotAuthorized());

        if (assets > 0) IERC4626(morphoVaultV1).withdraw(assets, address(this), address(this));
        uint256 oldAllocation = allocation();
        uint256 newAllocation = IERC4626(morphoVaultV1).previewRedeem(IERC4626(morphoVaultV1).balanceOf(address(this)));

        // Safe casts because Market V1 bounds the total supply of the underlying token, and allocation is less than the
        // max total assets of the vault.
        return (ids(), int256(newAllocation) - int256(oldAllocation));
    }

    /// @dev Returns adapter's ids.
    function ids() public view returns (bytes32[] memory) {
        bytes32[] memory ids_ = new bytes32[](1);
        ids_[0] = adapterId;
        return ids_;
    }

    function allocation() public view returns (uint256) {
        return IVaultV2(parentVault).allocation(adapterId);
    }

    function realAssets() external view returns (uint256) {
        return allocation() != 0
            ? IERC4626(morphoVaultV1).previewRedeem(IERC4626(morphoVaultV1).balanceOf(address(this)))
            : 0;
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity >=0.5.0;

interface IMorphoVaultV1AdapterFactory {
    /* EVENTS */

    event CreateMorphoVaultV1Adapter(
        address indexed parentVault, address indexed morphoVaultV1, address indexed morphoVaultV1Adapter
    );

    /* FUNCTIONS */

    function morphoVaultV1Adapter(address parentVault, address morphoVaultV1) external view returns (address);
    function isMorphoVaultV1Adapter(address account) external view returns (bool);
    function createMorphoVaultV1Adapter(address parentVault, address morphoVaultV1)
        external
        returns (address morphoVaultV1Adapter);
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity >=0.5.0;

interface IERC20 {
    function decimals() external view returns (uint8);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 shares) external returns (bool success);
    function transferFrom(address from, address to, uint256 shares) external returns (bool success);
    function approve(address spender, uint256 shares) external returns (bool success);
    function allowance(address owner, address spender) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity >=0.5.0;

import {IERC20} from "./IERC20.sol";

interface IERC4626 is IERC20 {
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function convertToShares(uint256 assets) external view returns (uint256 shares);
    function deposit(uint256 assets, address onBehalf) external returns (uint256 shares);
    function mint(uint256 shares, address onBehalf) external returns (uint256 assets);
    function withdraw(uint256 assets, address onBehalf, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address onBehalf, address receiver) external returns (uint256 assets);
    function previewDeposit(uint256 assets) external view returns (uint256 shares);
    function previewMint(uint256 shares) external view returns (uint256 assets);
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);
    function previewRedeem(uint256 shares) external view returns (uint256 assets);
    function maxDeposit(address onBehalf) external view returns (uint256 assets);
    function maxMint(address onBehalf) external view returns (uint256 shares);
    function maxWithdraw(address onBehalf) external view returns (uint256 assets);
    function maxRedeem(address onBehalf) external view returns (uint256 shares);
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity >=0.5.0;

interface IERC2612 {
    function permit(address owner, address spender, uint256 shares, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity >=0.5.0;

/// @dev See VaultV2 NatSpec comments for more details on adapter's spec.
interface IAdapter {
    /// @dev Returns the market' ids and the change in assets on this market.
    function allocate(bytes memory data, uint256 assets, bytes4 selector, address sender)
        external
        returns (bytes32[] memory ids, int256 change);

    /// @dev Returns the market' ids and the change in assets on this market.
    function deallocate(bytes memory data, uint256 assets, bytes4 selector, address sender)
        external
        returns (bytes32[] memory ids, int256 change);

    /// @dev Returns the current value of the investments of the adapter (in underlying asset).
    function realAssets() external view returns (uint256 assets);
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity >=0.5.0;

interface IAdapterRegistry {
    function isInRegistry(address account) external view returns (bool);
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity ^0.8.0;

library ErrorsLib {
    error Abdicated();
    error AbsoluteCapExceeded();
    error AbsoluteCapNotDecreasing();
    error AbsoluteCapNotIncreasing();
    error ApproveReturnedFalse();
    error ApproveReverted();
    error CannotReceiveShares();
    error CannotReceiveAssets();
    error CannotSendShares();
    error CannotSendAssets();
    error CapExceeded();
    error CastOverflow();
    error DataAlreadyPending();
    error DataNotTimelocked();
    error FeeInvariantBroken();
    error FeeTooHigh();
    error InvalidSigner();
    error MaxRateTooHigh();
    error NoCode();
    error NotAdapter();
    error NotInAdapterRegistry();
    error PenaltyTooHigh();
    error PermitDeadlineExpired();
    error RelativeCapAboveOne();
    error RelativeCapExceeded();
    error RelativeCapNotDecreasing();
    error RelativeCapNotIncreasing();
    error AutomaticallyTimelocked();
    error TimelockNotDecreasing();
    error TimelockNotExpired();
    error TimelockNotIncreasing();
    error TransferFromReturnedFalse();
    error TransferFromReverted();
    error TransferReturnedFalse();
    error TransferReverted();
    error Unauthorized();
    error ZeroAbsoluteCap();
    error ZeroAddress();
    error ZeroAllocation();
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity ^0.8.0;

library EventsLib {
    // ERC20 events
    event Approval(address indexed owner, address indexed spender, uint256 shares);
    event Transfer(address indexed from, address indexed to, uint256 shares);
    /// @dev Emitted when the allowance is updated by transferFrom (not when it is updated by permit, approve, withdraw,
    /// redeem because their respective events allow to track the allowance).
    event AllowanceUpdatedByTransferFrom(address indexed owner, address indexed spender, uint256 shares);
    event Permit(address indexed owner, address indexed spender, uint256 shares, uint256 nonce, uint256 deadline);

    // ERC4626 events
    event Deposit(address indexed sender, address indexed onBehalf, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed onBehalf, uint256 assets, uint256 shares
    );

    // Vault creation events
    event Constructor(address indexed owner, address indexed asset);

    // Allocation events
    event Allocate(address indexed sender, address indexed adapter, uint256 assets, bytes32[] ids, int256 change);
    event Deallocate(address indexed sender, address indexed adapter, uint256 assets, bytes32[] ids, int256 change);
    event ForceDeallocate(
        address indexed sender,
        address adapter,
        uint256 assets,
        address indexed onBehalf,
        bytes32[] ids,
        uint256 penaltyAssets
    );

    // Fee and interest events
    event AccrueInterest(
        uint256 previousTotalAssets, uint256 newTotalAssets, uint256 performanceFeeShares, uint256 managementFeeShares
    );

    // Timelock events
    event Revoke(address indexed sender, bytes4 indexed selector, bytes data);
    event Submit(bytes4 indexed selector, bytes data, uint256 executableAt);
    event Accept(bytes4 indexed selector, bytes data);

    // Configuration events
    event SetOwner(address indexed newOwner);
    event SetCurator(address indexed newCurator);
    event SetIsSentinel(address indexed account, bool newIsSentinel);
    event SetName(string newName);
    event SetSymbol(string newSymbol);
    event SetIsAllocator(address indexed account, bool newIsAllocator);
    event SetReceiveSharesGate(address indexed newReceiveSharesGate);
    event SetSendSharesGate(address indexed newSendSharesGate);
    event SetReceiveAssetsGate(address indexed newReceiveAssetsGate);
    event SetSendAssetsGate(address indexed newSendAssetsGate);
    event SetAdapterRegistry(address indexed newAdapterRegistry);
    event AddAdapter(address indexed account);
    event RemoveAdapter(address indexed account);
    event DecreaseTimelock(bytes4 indexed selector, uint256 newDuration);
    event IncreaseTimelock(bytes4 indexed selector, uint256 newDuration);
    event Abdicate(bytes4 indexed selector);
    event SetLiquidityAdapterAndData(
        address indexed sender, address indexed newLiquidityAdapter, bytes indexed newLiquidityData
    );
    event SetPerformanceFee(uint256 newPerformanceFee);
    event SetPerformanceFeeRecipient(address indexed newPerformanceFeeRecipient);
    event SetManagementFee(uint256 newManagementFee);
    event SetManagementFeeRecipient(address indexed newManagementFeeRecipient);
    event DecreaseAbsoluteCap(address indexed sender, bytes32 indexed id, bytes idData, uint256 newAbsoluteCap);
    event IncreaseAbsoluteCap(bytes32 indexed id, bytes idData, uint256 newAbsoluteCap);
    event DecreaseRelativeCap(address indexed sender, bytes32 indexed id, bytes idData, uint256 newRelativeCap);
    event IncreaseRelativeCap(bytes32 indexed id, bytes idData, uint256 newRelativeCap);
    event SetMaxRate(uint256 newMaxRate);
    event SetForceDeallocatePenalty(address indexed adapter, uint256 forceDeallocatePenalty);
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity ^0.8.0;

import {ErrorsLib} from "./ErrorsLib.sol";

library MathLib {
    /// @dev Returns (x * y) / d rounded down.
    function mulDivDown(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        return (x * y) / d;
    }

    /// @dev Returns (x * y) / d rounded up.
    function mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        return (x * y + (d - 1)) / d;
    }

    /// @dev Returns max(0, x - y).
    function zeroFloorSub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := mul(gt(x, y), sub(x, y))
        }
    }

    /// @dev Casts from uint256 to uint128, reverting if input number is too large.
    function toUint128(uint256 x) internal pure returns (uint128) {
        require(x <= type(uint128).max, ErrorsLib.CastOverflow());
        return uint128(x);
    }

    /// @dev Casts from int256 to uint256, reverting if input number is negative.
    function toUint256(int256 x) internal pure returns (uint256) {
        require(x >= 0, ErrorsLib.CastOverflow());
        return uint256(x);
    }

    /// @dev Returns min(x, y).
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := xor(x, mul(xor(x, y), lt(y, x)))
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity ^0.8.0;

import {IERC20} from "../interfaces/IERC20.sol";
import {ErrorsLib} from "./ErrorsLib.sol";

library SafeERC20Lib {
    function safeTransfer(address token, address to, uint256 value) internal {
        require(token.code.length > 0, ErrorsLib.NoCode());

        (bool success, bytes memory returndata) = token.call(abi.encodeCall(IERC20.transfer, (to, value)));
        require(success, ErrorsLib.TransferReverted());
        require(returndata.length == 0 || abi.decode(returndata, (bool)), ErrorsLib.TransferReturnedFalse());
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        require(token.code.length > 0, ErrorsLib.NoCode());

        (bool success, bytes memory returndata) = token.call(abi.encodeCall(IERC20.transferFrom, (from, to, value)));
        require(success, ErrorsLib.TransferFromReverted());
        require(returndata.length == 0 || abi.decode(returndata, (bool)), ErrorsLib.TransferFromReturnedFalse());
    }

    function safeApprove(address token, address spender, uint256 value) internal {
        require(token.code.length > 0, ErrorsLib.NoCode());

        (bool success, bytes memory returndata) = token.call(abi.encodeCall(IERC20.approve, (spender, value)));
        require(success, ErrorsLib.ApproveReverted());
        require(returndata.length == 0 || abi.decode(returndata, (bool)), ErrorsLib.ApproveReturnedFalse());
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity >=0.5.0;

interface IReceiveSharesGate {
    function canReceiveShares(address account) external view returns (bool);
}

interface ISendSharesGate {
    function canSendShares(address account) external view returns (bool);
}

interface IReceiveAssetsGate {
    function canReceiveAssets(address account) external view returns (bool);
}

interface ISendAssetsGate {
    function canSendAssets(address account) external view returns (bool);
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity >=0.5.0;

interface IVaultV2Factory {
    /* EVENTS */

    event CreateVaultV2(address indexed owner, address indexed asset, bytes32 salt, address indexed newVaultV2);

    /* FUNCTIONS */

    function isVaultV2(address account) external view returns (bool);
    function vaultV2(address owner, address asset, bytes32 salt) external view returns (address);
    function createVaultV2(address owner, address asset, bytes32 salt) external returns (address newVaultV2);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC4626.sol)

pragma solidity >=0.6.2;

import {IERC20} from "../token/ERC20/IERC20.sol";
import {IERC20Metadata} from "../token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @dev Interface of the ERC-4626 "Tokenized Vault Standard", as defined in
 * https://eips.ethereum.org/EIPS/eip-4626[ERC-4626].
 */
interface IERC4626 is IERC20, IERC20Metadata {
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /**
     * @dev Returns the address of the underlying token used for the Vault for accounting, depositing, and withdrawing.
     *
     * - MUST be an ERC-20 token contract.
     * - MUST NOT revert.
     */
    function asset() external view returns (address assetTokenAddress);

    /**
     * @dev Returns the total amount of the underlying asset that is “managed” by Vault.
     *
     * - SHOULD include any compounding that occurs from yield.
     * - MUST be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT revert.
     */
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /**
     * @dev Returns the amount of shares that the Vault would exchange for the amount of assets provided, in an ideal
     * scenario where all the conditions are met.
     *
     * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
     * - MUST NOT revert.
     *
     * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
     * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
     * from.
     */
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Returns the amount of assets that the Vault would exchange for the amount of shares provided, in an ideal
     * scenario where all the conditions are met.
     *
     * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
     * - MUST NOT revert.
     *
     * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
     * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
     * from.
     */
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be deposited into the Vault for the receiver,
     * through a deposit call.
     *
     * - MUST return a limited value if receiver is subject to some deposit limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be deposited.
     * - MUST NOT revert.
     */
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given
     * current on-chain conditions.
     *
     * - MUST return as close to and no more than the exact amount of Vault shares that would be minted in a deposit
     *   call in the same transaction. I.e. deposit should return the same or more shares as previewDeposit if called
     *   in the same transaction.
     * - MUST NOT account for deposit limits like those returned from maxDeposit and should always act as though the
     *   deposit would be accepted, regardless if the user has enough tokens approved, etc.
     * - MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToShares and previewDeposit SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     */
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Mints shares Vault shares to receiver by depositing exactly amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   deposit execution, and are accounted for during deposit.
     * - MUST revert if all of assets cannot be deposited (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @dev Returns the maximum amount of the Vault shares that can be minted for the receiver, through a mint call.
     * - MUST return a limited value if receiver is subject to some mint limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of shares that may be minted.
     * - MUST NOT revert.
     */
    function maxMint(address receiver) external view returns (uint256 maxShares);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given
     * current on-chain conditions.
     *
     * - MUST return as close to and no fewer than the exact amount of assets that would be deposited in a mint call
     *   in the same transaction. I.e. mint should return the same or fewer assets as previewMint if called in the
     *   same transaction.
     * - MUST NOT account for mint limits like those returned from maxMint and should always act as though the mint
     *   would be accepted, regardless if the user has enough tokens approved, etc.
     * - MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToAssets and previewMint SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by minting.
     */
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Mints exactly shares Vault shares to receiver by depositing amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the mint
     *   execution, and are accounted for during mint.
     * - MUST revert if all of shares cannot be minted (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
     * Vault, through a withdraw call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST NOT revert.
     */
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block,
     * given current on-chain conditions.
     *
     * - MUST return as close to and no fewer than the exact amount of Vault shares that would be burned in a withdraw
     *   call in the same transaction. I.e. withdraw should return the same or fewer shares as previewWithdraw if
     *   called
     *   in the same transaction.
     * - MUST NOT account for withdrawal limits like those returned from maxWithdraw and should always act as though
     *   the withdrawal would be accepted, regardless if the user has enough shares, etc.
     * - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToShares and previewWithdraw SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     */
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Burns shares from owner and sends exactly assets of underlying tokens to receiver.
     *
     * - MUST emit the Withdraw event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   withdraw execution, and are accounted for during withdraw.
     * - MUST revert if all of assets cannot be withdrawn (due to withdrawal limit being reached, slippage, the owner
     *   not having enough shares, etc).
     *
     * Note that some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /**
     * @dev Returns the maximum amount of Vault shares that can be redeemed from the owner balance in the Vault,
     * through a redeem call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST return balanceOf(owner) if owner is not subject to any withdrawal limit or timelock.
     * - MUST NOT revert.
     */
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their redemption at the current block,
     * given current on-chain conditions.
     *
     * - MUST return as close to and no more than the exact amount of assets that would be withdrawn in a redeem call
     *   in the same transaction. I.e. redeem should return the same or more assets as previewRedeem if called in the
     *   same transaction.
     * - MUST NOT account for redemption limits like those returned from maxRedeem and should always act as though the
     *   redemption would be accepted, regardless if the user has enough shares, etc.
     * - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToAssets and previewRedeem SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by redeeming.
     */
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Burns exactly shares from owner and sends assets of underlying tokens to receiver.
     *
     * - MUST emit the Withdraw event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   redeem execution, and are accounted for during redeem.
     * - MUST revert if all of shares cannot be redeemed (due to withdrawal limit being reached, slippage, the owner
     *   not having enough shares, etc).
     *
     * NOTE: some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "./IERC20.sol";
import {IERC20Metadata} from "./extensions/IERC20Metadata.sol";
import {Context} from "../../utils/Context.sol";
import {IERC20Errors} from "../../interfaces/draft-IERC6093.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC-20
 * applications.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * Both values are immutable: they can only be set once during construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /// @inheritdoc IERC20
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /// @inheritdoc IERC20
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Skips emitting an {Approval} event indicating an allowance update. This is not
     * required by the ERC. See {xref-ERC20-_approve-address-address-uint256-bool-}[_approve].
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner`'s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     *
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner`'s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";
import {IERC1363} from "../../../interfaces/IERC1363.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (!_safeTransfer(token, to, value, true)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        if (!_safeTransferFrom(token, from, to, value, true)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Variant of {safeTransfer} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransfer(IERC20 token, address to, uint256 value) internal returns (bool) {
        return _safeTransfer(token, to, value, false);
    }

    /**
     * @dev Variant of {safeTransferFrom} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransferFrom(IERC20 token, address from, address to, uint256 value) internal returns (bool) {
        return _safeTransferFrom(token, from, to, value, false);
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     *
     * NOTE: If the token implements ERC-7674, this function will not modify any temporary allowance. This function
     * only sets the "standard" allowance. Any temporary allowance will remain active, in addition to the value being
     * set here.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        if (!_safeApprove(token, spender, value, false)) {
            if (!_safeApprove(token, spender, 0, true)) revert SafeERC20FailedOperation(address(token));
            if (!_safeApprove(token, spender, value, true)) revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferAndCall, with a fallback to the simple {ERC20} transfer if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferFromAndCall, with a fallback to the simple {ERC20} transferFrom if the target
     * has no code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} approveAndCall, with a fallback to the simple {ERC20} approve if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * NOTE: When the recipient address (`to`) has no code (i.e. is an EOA), this function behaves as {forceApprove}.
     * Opposedly, when the recipient address (`to`) has code, this function only attempts to call {ERC1363-approveAndCall}
     * once without retrying, and relies on the returned value to be true.
     *
     * Reverts if the returned value is other than `true`.
     */
    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity `token.transfer(to, value)` call, relaxing the requirement on the return value: the
     * return value is optional (but if data is returned, it must not be false).
     *
     * @param token The token targeted by the call.
     * @param to The recipient of the tokens
     * @param value The amount of token to transfer
     * @param bubble Behavior switch if the transfer call reverts: bubble the revert reason or return a false boolean.
     */
    function _safeTransfer(IERC20 token, address to, uint256 value, bool bubble) private returns (bool success) {
        bytes4 selector = IERC20.transfer.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(to, shr(96, not(0))))
            mstore(0x24, value)
            success := call(gas(), token, 0, 0, 0x44, 0, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
        }
    }

    /**
     * @dev Imitates a Solidity `token.transferFrom(from, to, value)` call, relaxing the requirement on the return
     * value: the return value is optional (but if data is returned, it must not be false).
     *
     * @param token The token targeted by the call.
     * @param from The sender of the tokens
     * @param to The recipient of the tokens
     * @param value The amount of token to transfer
     * @param bubble Behavior switch if the transfer call reverts: bubble the revert reason or return a false boolean.
     */
    function _safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value,
        bool bubble
    ) private returns (bool success) {
        bytes4 selector = IERC20.transferFrom.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(from, shr(96, not(0))))
            mstore(0x24, and(to, shr(96, not(0))))
            mstore(0x44, value)
            success := call(gas(), token, 0, 0, 0x64, 0, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
            mstore(0x60, 0)
        }
    }

    /**
     * @dev Imitates a Solidity `token.approve(spender, value)` call, relaxing the requirement on the return value:
     * the return value is optional (but if data is returned, it must not be false).
     *
     * @param token The token targeted by the call.
     * @param spender The spender of the tokens
     * @param value The amount of token to transfer
     * @param bubble Behavior switch if the transfer call reverts: bubble the revert reason or return a false boolean.
     */
    function _safeApprove(IERC20 token, address spender, uint256 value, bool bubble) private returns (bool success) {
        bytes4 selector = IERC20.approve.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(spender, shr(96, not(0))))
            mstore(0x24, value)
            success := call(gas(), token, 0, 0, 0x44, 0, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (utils/math/Math.sol)

pragma solidity ^0.8.20;

import {Panic} from "../Panic.sol";
import {SafeCast} from "./SafeCast.sol";

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Return the 512-bit addition of two uint256.
     *
     * The result is stored in two 256 variables such that sum = high * 2²⁵⁶ + low.
     */
    function add512(uint256 a, uint256 b) internal pure returns (uint256 high, uint256 low) {
        assembly ("memory-safe") {
            low := add(a, b)
            high := lt(low, a)
        }
    }

    /**
     * @dev Return the 512-bit multiplication of two uint256.
     *
     * The result is stored in two 256 variables such that product = high * 2²⁵⁶ + low.
     */
    function mul512(uint256 a, uint256 b) internal pure returns (uint256 high, uint256 low) {
        // 512-bit multiply [high low] = x * y. Compute the product mod 2²⁵⁶ and mod 2²⁵⁶ - 1, then use
        // the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
        // variables such that product = high * 2²⁵⁶ + low.
        assembly ("memory-safe") {
            let mm := mulmod(a, b, not(0))
            low := mul(a, b)
            high := sub(sub(mm, low), lt(mm, low))
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, with a success flag (no overflow).
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            uint256 c = a + b;
            success = c >= a;
            result = c * SafeCast.toUint(success);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with a success flag (no overflow).
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            uint256 c = a - b;
            success = c <= a;
            result = c * SafeCast.toUint(success);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with a success flag (no overflow).
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            uint256 c = a * b;
            assembly ("memory-safe") {
                // Only true when the multiplication doesn't overflow
                // (c / a == b) || (a == 0)
                success := or(eq(div(c, a), b), iszero(a))
            }
            // equivalent to: success ? c : 0
            result = c * SafeCast.toUint(success);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a success flag (no division by zero).
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            success = b > 0;
            assembly ("memory-safe") {
                // The `DIV` opcode returns zero when the denominator is 0.
                result := div(a, b)
            }
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a success flag (no division by zero).
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            success = b > 0;
            assembly ("memory-safe") {
                // The `MOD` opcode returns zero when the denominator is 0.
                result := mod(a, b)
            }
        }
    }

    /**
     * @dev Unsigned saturating addition, bounds to `2²⁵⁶ - 1` instead of overflowing.
     */
    function saturatingAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        (bool success, uint256 result) = tryAdd(a, b);
        return ternary(success, result, type(uint256).max);
    }

    /**
     * @dev Unsigned saturating subtraction, bounds to zero instead of overflowing.
     */
    function saturatingSub(uint256 a, uint256 b) internal pure returns (uint256) {
        (, uint256 result) = trySub(a, b);
        return result;
    }

    /**
     * @dev Unsigned saturating multiplication, bounds to `2²⁵⁶ - 1` instead of overflowing.
     */
    function saturatingMul(uint256 a, uint256 b) internal pure returns (uint256) {
        (bool success, uint256 result) = tryMul(a, b);
        return ternary(success, result, type(uint256).max);
    }

    /**
     * @dev Branchless ternary evaluation for `a ? b : c`. Gas costs are constant.
     *
     * IMPORTANT: This function may reduce bytecode size and consume less gas when used standalone.
     * However, the compiler may optimize Solidity ternary operations (i.e. `a ? b : c`) to only compute
     * one branch when needed, making this function more expensive.
     */
    function ternary(bool condition, uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            // branchless ternary works because:
            // b ^ (a ^ b) == a
            // b ^ 0 == b
            return b ^ ((a ^ b) * SafeCast.toUint(condition));
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return ternary(a > b, a, b);
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return ternary(a < b, a, b);
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
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            Panic.panic(Panic.DIVISION_BY_ZERO);
        }

        // The following calculation ensures accurate ceiling division without overflow.
        // Since a is non-zero, (a - 1) / b will not overflow.
        // The largest possible result occurs when (a - 1) / b is type(uint256).max,
        // but the largest value we can obtain is type(uint256).max - 1, which happens
        // when a = type(uint256).max and b = 1.
        unchecked {
            return SafeCast.toUint(a > 0) * ((a - 1) / b + 1);
        }
    }

    /**
     * @dev Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     *
     * Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            (uint256 high, uint256 low) = mul512(x, y);

            // Handle non-overflow cases, 256 by 256 division.
            if (high == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return low / denominator;
            }

            // Make sure the result is less than 2²⁵⁶. Also prevents denominator == 0.
            if (denominator <= high) {
                Panic.panic(ternary(denominator == 0, Panic.DIVISION_BY_ZERO, Panic.UNDER_OVERFLOW));
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [high low].
            uint256 remainder;
            assembly ("memory-safe") {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                high := sub(high, gt(remainder, low))
                low := sub(low, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly ("memory-safe") {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [high low] by twos.
                low := div(low, twos)

                // Flip twos such that it is 2²⁵⁶ / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from high into low.
            low |= high * twos;

            // Invert denominator mod 2²⁵⁶. Now that denominator is an odd number, it has an inverse modulo 2²⁵⁶ such
            // that denominator * inv ≡ 1 mod 2²⁵⁶. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv ≡ 1 mod 2⁴.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2⁸
            inverse *= 2 - denominator * inverse; // inverse mod 2¹⁶
            inverse *= 2 - denominator * inverse; // inverse mod 2³²
            inverse *= 2 - denominator * inverse; // inverse mod 2⁶⁴
            inverse *= 2 - denominator * inverse; // inverse mod 2¹²⁸
            inverse *= 2 - denominator * inverse; // inverse mod 2²⁵⁶

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2²⁵⁶. Since the preconditions guarantee that the outcome is
            // less than 2²⁵⁶, this is the final result. We don't need to compute the high bits of the result and high
            // is no longer required.
            result = low * inverse;
            return result;
        }
    }

    /**
     * @dev Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        return mulDiv(x, y, denominator) + SafeCast.toUint(unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0);
    }

    /**
     * @dev Calculates floor(x * y >> n) with full precision. Throws if result overflows a uint256.
     */
    function mulShr(uint256 x, uint256 y, uint8 n) internal pure returns (uint256 result) {
        unchecked {
            (uint256 high, uint256 low) = mul512(x, y);
            if (high >= 1 << n) {
                Panic.panic(Panic.UNDER_OVERFLOW);
            }
            return (high << (256 - n)) | (low >> n);
        }
    }

    /**
     * @dev Calculates x * y >> n with full precision, following the selected rounding direction.
     */
    function mulShr(uint256 x, uint256 y, uint8 n, Rounding rounding) internal pure returns (uint256) {
        return mulShr(x, y, n) + SafeCast.toUint(unsignedRoundsUp(rounding) && mulmod(x, y, 1 << n) > 0);
    }

    /**
     * @dev Calculate the modular multiplicative inverse of a number in Z/nZ.
     *
     * If n is a prime, then Z/nZ is a field. In that case all elements are inversible, except 0.
     * If n is not a prime, then Z/nZ is not a field, and some elements might not be inversible.
     *
     * If the input value is not inversible, 0 is returned.
     *
     * NOTE: If you know for sure that n is (big) a prime, it may be cheaper to use Fermat's little theorem and get the
     * inverse using `Math.modExp(a, n - 2, n)`. See {invModPrime}.
     */
    function invMod(uint256 a, uint256 n) internal pure returns (uint256) {
        unchecked {
            if (n == 0) return 0;

            // The inverse modulo is calculated using the Extended Euclidean Algorithm (iterative version)
            // Used to compute integers x and y such that: ax + ny = gcd(a, n).
            // When the gcd is 1, then the inverse of a modulo n exists and it's x.
            // ax + ny = 1
            // ax = 1 + (-y)n
            // ax ≡ 1 (mod n) # x is the inverse of a modulo n

            // If the remainder is 0 the gcd is n right away.
            uint256 remainder = a % n;
            uint256 gcd = n;

            // Therefore the initial coefficients are:
            // ax + ny = gcd(a, n) = n
            // 0a + 1n = n
            int256 x = 0;
            int256 y = 1;

            while (remainder != 0) {
                uint256 quotient = gcd / remainder;

                (gcd, remainder) = (
                    // The old remainder is the next gcd to try.
                    remainder,
                    // Compute the next remainder.
                    // Can't overflow given that (a % gcd) * (gcd // (a % gcd)) <= gcd
                    // where gcd is at most n (capped to type(uint256).max)
                    gcd - remainder * quotient
                );

                (x, y) = (
                    // Increment the coefficient of a.
                    y,
                    // Decrement the coefficient of n.
                    // Can overflow, but the result is casted to uint256 so that the
                    // next value of y is "wrapped around" to a value between 0 and n - 1.
                    x - y * int256(quotient)
                );
            }

            if (gcd != 1) return 0; // No inverse exists.
            return ternary(x < 0, n - uint256(-x), uint256(x)); // Wrap the result if it's negative.
        }
    }

    /**
     * @dev Variant of {invMod}. More efficient, but only works if `p` is known to be a prime greater than `2`.
     *
     * From https://en.wikipedia.org/wiki/Fermat%27s_little_theorem[Fermat's little theorem], we know that if p is
     * prime, then `a**(p-1) ≡ 1 mod p`. As a consequence, we have `a * a**(p-2) ≡ 1 mod p`, which means that
     * `a**(p-2)` is the modular multiplicative inverse of a in Fp.
     *
     * NOTE: this function does NOT check that `p` is a prime greater than `2`.
     */
    function invModPrime(uint256 a, uint256 p) internal view returns (uint256) {
        unchecked {
            return Math.modExp(a, p - 2, p);
        }
    }

    /**
     * @dev Returns the modular exponentiation of the specified base, exponent and modulus (b ** e % m)
     *
     * Requirements:
     * - modulus can't be zero
     * - underlying staticcall to precompile must succeed
     *
     * IMPORTANT: The result is only valid if the underlying call succeeds. When using this function, make
     * sure the chain you're using it on supports the precompiled contract for modular exponentiation
     * at address 0x05 as specified in https://eips.ethereum.org/EIPS/eip-198[EIP-198]. Otherwise,
     * the underlying function will succeed given the lack of a revert, but the result may be incorrectly
     * interpreted as 0.
     */
    function modExp(uint256 b, uint256 e, uint256 m) internal view returns (uint256) {
        (bool success, uint256 result) = tryModExp(b, e, m);
        if (!success) {
            Panic.panic(Panic.DIVISION_BY_ZERO);
        }
        return result;
    }

    /**
     * @dev Returns the modular exponentiation of the specified base, exponent and modulus (b ** e % m).
     * It includes a success flag indicating if the operation succeeded. Operation will be marked as failed if trying
     * to operate modulo 0 or if the underlying precompile reverted.
     *
     * IMPORTANT: The result is only valid if the success flag is true. When using this function, make sure the chain
     * you're using it on supports the precompiled contract for modular exponentiation at address 0x05 as specified in
     * https://eips.ethereum.org/EIPS/eip-198[EIP-198]. Otherwise, the underlying function will succeed given the lack
     * of a revert, but the result may be incorrectly interpreted as 0.
     */
    function tryModExp(uint256 b, uint256 e, uint256 m) internal view returns (bool success, uint256 result) {
        if (m == 0) return (false, 0);
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            // | Offset    | Content    | Content (Hex)                                                      |
            // |-----------|------------|--------------------------------------------------------------------|
            // | 0x00:0x1f | size of b  | 0x0000000000000000000000000000000000000000000000000000000000000020 |
            // | 0x20:0x3f | size of e  | 0x0000000000000000000000000000000000000000000000000000000000000020 |
            // | 0x40:0x5f | size of m  | 0x0000000000000000000000000000000000000000000000000000000000000020 |
            // | 0x60:0x7f | value of b | 0x<.............................................................b> |
            // | 0x80:0x9f | value of e | 0x<.............................................................e> |
            // | 0xa0:0xbf | value of m | 0x<.............................................................m> |
            mstore(ptr, 0x20)
            mstore(add(ptr, 0x20), 0x20)
            mstore(add(ptr, 0x40), 0x20)
            mstore(add(ptr, 0x60), b)
            mstore(add(ptr, 0x80), e)
            mstore(add(ptr, 0xa0), m)

            // Given the result < m, it's guaranteed to fit in 32 bytes,
            // so we can use the memory scratch space located at offset 0.
            success := staticcall(gas(), 0x05, ptr, 0xc0, 0x00, 0x20)
            result := mload(0x00)
        }
    }

    /**
     * @dev Variant of {modExp} that supports inputs of arbitrary length.
     */
    function modExp(bytes memory b, bytes memory e, bytes memory m) internal view returns (bytes memory) {
        (bool success, bytes memory result) = tryModExp(b, e, m);
        if (!success) {
            Panic.panic(Panic.DIVISION_BY_ZERO);
        }
        return result;
    }

    /**
     * @dev Variant of {tryModExp} that supports inputs of arbitrary length.
     */
    function tryModExp(
        bytes memory b,
        bytes memory e,
        bytes memory m
    ) internal view returns (bool success, bytes memory result) {
        if (_zeroBytes(m)) return (false, new bytes(0));

        uint256 mLen = m.length;

        // Encode call args in result and move the free memory pointer
        result = abi.encodePacked(b.length, e.length, mLen, b, e, m);

        assembly ("memory-safe") {
            let dataPtr := add(result, 0x20)
            // Write result on top of args to avoid allocating extra memory.
            success := staticcall(gas(), 0x05, dataPtr, mload(result), dataPtr, mLen)
            // Overwrite the length.
            // result.length > returndatasize() is guaranteed because returndatasize() == m.length
            mstore(result, mLen)
            // Set the memory pointer after the returned data.
            mstore(0x40, add(dataPtr, mLen))
        }
    }

    /**
     * @dev Returns whether the provided byte array is zero.
     */
    function _zeroBytes(bytes memory byteArray) private pure returns (bool) {
        for (uint256 i = 0; i < byteArray.length; ++i) {
            if (byteArray[i] != 0) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * This method is based on Newton's method for computing square roots; the algorithm is restricted to only
     * using integer operations.
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        unchecked {
            // Take care of easy edge cases when a == 0 or a == 1
            if (a <= 1) {
                return a;
            }

            // In this function, we use Newton's method to get a root of `f(x) := x² - a`. It involves building a
            // sequence x_n that converges toward sqrt(a). For each iteration x_n, we also define the error between
            // the current value as `ε_n = | x_n - sqrt(a) |`.
            //
            // For our first estimation, we consider `e` the smallest power of 2 which is bigger than the square root
            // of the target. (i.e. `2**(e-1) ≤ sqrt(a) < 2**e`). We know that `e ≤ 128` because `(2¹²⁸)² = 2²⁵⁶` is
            // bigger than any uint256.
            //
            // By noticing that
            // `2**(e-1) ≤ sqrt(a) < 2**e → (2**(e-1))² ≤ a < (2**e)² → 2**(2*e-2) ≤ a < 2**(2*e)`
            // we can deduce that `e - 1` is `log2(a) / 2`. We can thus compute `x_n = 2**(e-1)` using a method similar
            // to the msb function.
            uint256 aa = a;
            uint256 xn = 1;

            if (aa >= (1 << 128)) {
                aa >>= 128;
                xn <<= 64;
            }
            if (aa >= (1 << 64)) {
                aa >>= 64;
                xn <<= 32;
            }
            if (aa >= (1 << 32)) {
                aa >>= 32;
                xn <<= 16;
            }
            if (aa >= (1 << 16)) {
                aa >>= 16;
                xn <<= 8;
            }
            if (aa >= (1 << 8)) {
                aa >>= 8;
                xn <<= 4;
            }
            if (aa >= (1 << 4)) {
                aa >>= 4;
                xn <<= 2;
            }
            if (aa >= (1 << 2)) {
                xn <<= 1;
            }

            // We now have x_n such that `x_n = 2**(e-1) ≤ sqrt(a) < 2**e = 2 * x_n`. This implies ε_n ≤ 2**(e-1).
            //
            // We can refine our estimation by noticing that the middle of that interval minimizes the error.
            // If we move x_n to equal 2**(e-1) + 2**(e-2), then we reduce the error to ε_n ≤ 2**(e-2).
            // This is going to be our x_0 (and ε_0)
            xn = (3 * xn) >> 1; // ε_0 := | x_0 - sqrt(a) | ≤ 2**(e-2)

            // From here, Newton's method give us:
            // x_{n+1} = (x_n + a / x_n) / 2
            //
            // One should note that:
            // x_{n+1}² - a = ((x_n + a / x_n) / 2)² - a
            //              = ((x_n² + a) / (2 * x_n))² - a
            //              = (x_n⁴ + 2 * a * x_n² + a²) / (4 * x_n²) - a
            //              = (x_n⁴ + 2 * a * x_n² + a² - 4 * a * x_n²) / (4 * x_n²)
            //              = (x_n⁴ - 2 * a * x_n² + a²) / (4 * x_n²)
            //              = (x_n² - a)² / (2 * x_n)²
            //              = ((x_n² - a) / (2 * x_n))²
            //              ≥ 0
            // Which proves that for all n ≥ 1, sqrt(a) ≤ x_n
            //
            // This gives us the proof of quadratic convergence of the sequence:
            // ε_{n+1} = | x_{n+1} - sqrt(a) |
            //         = | (x_n + a / x_n) / 2 - sqrt(a) |
            //         = | (x_n² + a - 2*x_n*sqrt(a)) / (2 * x_n) |
            //         = | (x_n - sqrt(a))² / (2 * x_n) |
            //         = | ε_n² / (2 * x_n) |
            //         = ε_n² / | (2 * x_n) |
            //
            // For the first iteration, we have a special case where x_0 is known:
            // ε_1 = ε_0² / | (2 * x_0) |
            //     ≤ (2**(e-2))² / (2 * (2**(e-1) + 2**(e-2)))
            //     ≤ 2**(2*e-4) / (3 * 2**(e-1))
            //     ≤ 2**(e-3) / 3
            //     ≤ 2**(e-3-log2(3))
            //     ≤ 2**(e-4.5)
            //
            // For the following iterations, we use the fact that, 2**(e-1) ≤ sqrt(a) ≤ x_n:
            // ε_{n+1} = ε_n² / | (2 * x_n) |
            //         ≤ (2**(e-k))² / (2 * 2**(e-1))
            //         ≤ 2**(2*e-2*k) / 2**e
            //         ≤ 2**(e-2*k)
            xn = (xn + a / xn) >> 1; // ε_1 := | x_1 - sqrt(a) | ≤ 2**(e-4.5)  -- special case, see above
            xn = (xn + a / xn) >> 1; // ε_2 := | x_2 - sqrt(a) | ≤ 2**(e-9)    -- general case with k = 4.5
            xn = (xn + a / xn) >> 1; // ε_3 := | x_3 - sqrt(a) | ≤ 2**(e-18)   -- general case with k = 9
            xn = (xn + a / xn) >> 1; // ε_4 := | x_4 - sqrt(a) | ≤ 2**(e-36)   -- general case with k = 18
            xn = (xn + a / xn) >> 1; // ε_5 := | x_5 - sqrt(a) | ≤ 2**(e-72)   -- general case with k = 36
            xn = (xn + a / xn) >> 1; // ε_6 := | x_6 - sqrt(a) | ≤ 2**(e-144)  -- general case with k = 72

            // Because e ≤ 128 (as discussed during the first estimation phase), we know have reached a precision
            // ε_6 ≤ 2**(e-144) < 1. Given we're operating on integers, then we can ensure that xn is now either
            // sqrt(a) or sqrt(a) + 1.
            return xn - SafeCast.toUint(xn > a / xn);
        }
    }

    /**
     * @dev Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + SafeCast.toUint(unsignedRoundsUp(rounding) && result * result < a);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 x) internal pure returns (uint256 r) {
        // If value has upper 128 bits set, log2 result is at least 128
        r = SafeCast.toUint(x > 0xffffffffffffffffffffffffffffffff) << 7;
        // If upper 64 bits of 128-bit half set, add 64 to result
        r |= SafeCast.toUint((x >> r) > 0xffffffffffffffff) << 6;
        // If upper 32 bits of 64-bit half set, add 32 to result
        r |= SafeCast.toUint((x >> r) > 0xffffffff) << 5;
        // If upper 16 bits of 32-bit half set, add 16 to result
        r |= SafeCast.toUint((x >> r) > 0xffff) << 4;
        // If upper 8 bits of 16-bit half set, add 8 to result
        r |= SafeCast.toUint((x >> r) > 0xff) << 3;
        // If upper 4 bits of 8-bit half set, add 4 to result
        r |= SafeCast.toUint((x >> r) > 0xf) << 2;

        // Shifts value right by the current result and use it as an index into this lookup table:
        //
        // | x (4 bits) |  index  | table[index] = MSB position |
        // |------------|---------|-----------------------------|
        // |    0000    |    0    |        table[0] = 0         |
        // |    0001    |    1    |        table[1] = 0         |
        // |    0010    |    2    |        table[2] = 1         |
        // |    0011    |    3    |        table[3] = 1         |
        // |    0100    |    4    |        table[4] = 2         |
        // |    0101    |    5    |        table[5] = 2         |
        // |    0110    |    6    |        table[6] = 2         |
        // |    0111    |    7    |        table[7] = 2         |
        // |    1000    |    8    |        table[8] = 3         |
        // |    1001    |    9    |        table[9] = 3         |
        // |    1010    |   10    |        table[10] = 3        |
        // |    1011    |   11    |        table[11] = 3        |
        // |    1100    |   12    |        table[12] = 3        |
        // |    1101    |   13    |        table[13] = 3        |
        // |    1110    |   14    |        table[14] = 3        |
        // |    1111    |   15    |        table[15] = 3        |
        //
        // The lookup table is represented as a 32-byte value with the MSB positions for 0-15 in the last 16 bytes.
        assembly ("memory-safe") {
            r := or(r, byte(shr(r, x), 0x0000010102020202030303030303030300000000000000000000000000000000))
        }
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + SafeCast.toUint(unsignedRoundsUp(rounding) && 1 << result < value);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
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
            return result + SafeCast.toUint(unsignedRoundsUp(rounding) && 10 ** result < value);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 x) internal pure returns (uint256 r) {
        // If value has upper 128 bits set, log2 result is at least 128
        r = SafeCast.toUint(x > 0xffffffffffffffffffffffffffffffff) << 7;
        // If upper 64 bits of 128-bit half set, add 64 to result
        r |= SafeCast.toUint((x >> r) > 0xffffffffffffffff) << 6;
        // If upper 32 bits of 64-bit half set, add 32 to result
        r |= SafeCast.toUint((x >> r) > 0xffffffff) << 5;
        // If upper 16 bits of 32-bit half set, add 16 to result
        r |= SafeCast.toUint((x >> r) > 0xffff) << 4;
        // Add 1 if upper 8 bits of 16-bit half set, and divide accumulated result by 8
        return (r >> 3) | SafeCast.toUint((x >> r) > 0xff);
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + SafeCast.toUint(unsignedRoundsUp(rounding) && 1 << (result << 3) < value);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }

    /**
     * @dev Counts the number of leading zero bits in a uint256.
     */
    function clz(uint256 x) internal pure returns (uint256) {
        return ternary(x == 0, 256, 255 - log2(x));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/math/SafeCast.sol)
// This file was procedurally generated from scripts/generate/templates/SafeCast.js.

pragma solidity ^0.8.20;

/**
 * @dev Wrappers over Solidity's uintXX/intXX/bool casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeCast {
    /**
     * @dev Value doesn't fit in an uint of `bits` size.
     */
    error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);

    /**
     * @dev An int value doesn't fit in an uint of `bits` size.
     */
    error SafeCastOverflowedIntToUint(int256 value);

    /**
     * @dev Value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedIntDowncast(uint8 bits, int256 value);

    /**
     * @dev An uint value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedUintToInt(uint256 value);

    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        if (value > type(uint248).max) {
            revert SafeCastOverflowedUintDowncast(248, value);
        }
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        if (value > type(uint240).max) {
            revert SafeCastOverflowedUintDowncast(240, value);
        }
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        if (value > type(uint232).max) {
            revert SafeCastOverflowedUintDowncast(232, value);
        }
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        if (value > type(uint224).max) {
            revert SafeCastOverflowedUintDowncast(224, value);
        }
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        if (value > type(uint216).max) {
            revert SafeCastOverflowedUintDowncast(216, value);
        }
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        if (value > type(uint208).max) {
            revert SafeCastOverflowedUintDowncast(208, value);
        }
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        if (value > type(uint200).max) {
            revert SafeCastOverflowedUintDowncast(200, value);
        }
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        if (value > type(uint192).max) {
            revert SafeCastOverflowedUintDowncast(192, value);
        }
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        if (value > type(uint184).max) {
            revert SafeCastOverflowedUintDowncast(184, value);
        }
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        if (value > type(uint176).max) {
            revert SafeCastOverflowedUintDowncast(176, value);
        }
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        if (value > type(uint168).max) {
            revert SafeCastOverflowedUintDowncast(168, value);
        }
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        if (value > type(uint160).max) {
            revert SafeCastOverflowedUintDowncast(160, value);
        }
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        if (value > type(uint152).max) {
            revert SafeCastOverflowedUintDowncast(152, value);
        }
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        if (value > type(uint144).max) {
            revert SafeCastOverflowedUintDowncast(144, value);
        }
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        if (value > type(uint136).max) {
            revert SafeCastOverflowedUintDowncast(136, value);
        }
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) {
            revert SafeCastOverflowedUintDowncast(128, value);
        }
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        if (value > type(uint120).max) {
            revert SafeCastOverflowedUintDowncast(120, value);
        }
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        if (value > type(uint112).max) {
            revert SafeCastOverflowedUintDowncast(112, value);
        }
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        if (value > type(uint104).max) {
            revert SafeCastOverflowedUintDowncast(104, value);
        }
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        if (value > type(uint96).max) {
            revert SafeCastOverflowedUintDowncast(96, value);
        }
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        if (value > type(uint88).max) {
            revert SafeCastOverflowedUintDowncast(88, value);
        }
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        if (value > type(uint80).max) {
            revert SafeCastOverflowedUintDowncast(80, value);
        }
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        if (value > type(uint72).max) {
            revert SafeCastOverflowedUintDowncast(72, value);
        }
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) {
            revert SafeCastOverflowedUintDowncast(64, value);
        }
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        if (value > type(uint56).max) {
            revert SafeCastOverflowedUintDowncast(56, value);
        }
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        if (value > type(uint48).max) {
            revert SafeCastOverflowedUintDowncast(48, value);
        }
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        if (value > type(uint40).max) {
            revert SafeCastOverflowedUintDowncast(40, value);
        }
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        if (value > type(uint32).max) {
            revert SafeCastOverflowedUintDowncast(32, value);
        }
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        if (value > type(uint24).max) {
            revert SafeCastOverflowedUintDowncast(24, value);
        }
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        if (value > type(uint16).max) {
            revert SafeCastOverflowedUintDowncast(16, value);
        }
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        if (value > type(uint8).max) {
            revert SafeCastOverflowedUintDowncast(8, value);
        }
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        if (value < 0) {
            revert SafeCastOverflowedIntToUint(value);
        }
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toInt248(int256 value) internal pure returns (int248 downcasted) {
        downcasted = int248(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(248, value);
        }
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toInt240(int256 value) internal pure returns (int240 downcasted) {
        downcasted = int240(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(240, value);
        }
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toInt232(int256 value) internal pure returns (int232 downcasted) {
        downcasted = int232(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(232, value);
        }
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toInt224(int256 value) internal pure returns (int224 downcasted) {
        downcasted = int224(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(224, value);
        }
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toInt216(int256 value) internal pure returns (int216 downcasted) {
        downcasted = int216(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(216, value);
        }
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toInt208(int256 value) internal pure returns (int208 downcasted) {
        downcasted = int208(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(208, value);
        }
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toInt200(int256 value) internal pure returns (int200 downcasted) {
        downcasted = int200(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(200, value);
        }
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toInt192(int256 value) internal pure returns (int192 downcasted) {
        downcasted = int192(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(192, value);
        }
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toInt184(int256 value) internal pure returns (int184 downcasted) {
        downcasted = int184(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(184, value);
        }
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toInt176(int256 value) internal pure returns (int176 downcasted) {
        downcasted = int176(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(176, value);
        }
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toInt168(int256 value) internal pure returns (int168 downcasted) {
        downcasted = int168(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(168, value);
        }
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toInt160(int256 value) internal pure returns (int160 downcasted) {
        downcasted = int160(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(160, value);
        }
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toInt152(int256 value) internal pure returns (int152 downcasted) {
        downcasted = int152(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(152, value);
        }
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toInt144(int256 value) internal pure returns (int144 downcasted) {
        downcasted = int144(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(144, value);
        }
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toInt136(int256 value) internal pure returns (int136 downcasted) {
        downcasted = int136(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(136, value);
        }
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toInt128(int256 value) internal pure returns (int128 downcasted) {
        downcasted = int128(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(128, value);
        }
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toInt120(int256 value) internal pure returns (int120 downcasted) {
        downcasted = int120(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(120, value);
        }
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toInt112(int256 value) internal pure returns (int112 downcasted) {
        downcasted = int112(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(112, value);
        }
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toInt104(int256 value) internal pure returns (int104 downcasted) {
        downcasted = int104(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(104, value);
        }
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toInt96(int256 value) internal pure returns (int96 downcasted) {
        downcasted = int96(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(96, value);
        }
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toInt88(int256 value) internal pure returns (int88 downcasted) {
        downcasted = int88(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(88, value);
        }
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toInt80(int256 value) internal pure returns (int80 downcasted) {
        downcasted = int80(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(80, value);
        }
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toInt72(int256 value) internal pure returns (int72 downcasted) {
        downcasted = int72(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(72, value);
        }
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toInt64(int256 value) internal pure returns (int64 downcasted) {
        downcasted = int64(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(64, value);
        }
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toInt56(int256 value) internal pure returns (int56 downcasted) {
        downcasted = int56(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(56, value);
        }
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toInt48(int256 value) internal pure returns (int48 downcasted) {
        downcasted = int48(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(48, value);
        }
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toInt40(int256 value) internal pure returns (int40 downcasted) {
        downcasted = int40(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(40, value);
        }
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toInt32(int256 value) internal pure returns (int32 downcasted) {
        downcasted = int32(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(32, value);
        }
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toInt24(int256 value) internal pure returns (int24 downcasted) {
        downcasted = int24(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(24, value);
        }
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toInt16(int256 value) internal pure returns (int16 downcasted) {
        downcasted = int16(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(16, value);
        }
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toInt8(int256 value) internal pure returns (int8 downcasted) {
        downcasted = int8(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(8, value);
        }
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        if (value > uint256(type(int256).max)) {
            revert SafeCastOverflowedUintToInt(value);
        }
        return int256(value);
    }

    /**
     * @dev Cast a boolean (false or true) to a uint256 (0 or 1) with no jump.
     */
    function toUint(bool b) internal pure returns (uint256 u) {
        assembly ("memory-safe") {
            u := iszero(iszero(b))
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

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
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
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
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
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
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Steakhouse
pragma solidity >=0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOracle} from "./IOracle.sol";

interface IOracleCallback {
    /// @dev RIs considered to have a price of ORACLE_PRECISION
    function asset() external view returns (address);

    /// @dev Returns an oracle for tokens that are not the asset
    function oracles(IERC20 token) external view returns (IOracle);
}

/**
 * @notice Interface for a funding module
 * @notice `nav` should never revert
 */
interface IFunding {
    // ========== ADMIN ==========
    function addFacility(bytes calldata facilityData) external;
    function removeFacility(bytes calldata facilityData) external;
    function isFacility(bytes calldata facilityData) external view returns (bool);
    function facilities(uint256 index) external view returns (bytes memory);
    function facilitiesLength() external view returns (uint256);

    function addCollateralToken(IERC20 collateralToken) external;
    function removeCollateralToken(IERC20 collateralToken) external;
    function isCollateralToken(IERC20 collateralToken) external view returns (bool);
    function collateralTokens(uint256 index) external view returns (IERC20);
    function collateralTokensLength() external view returns (uint256);

    function addDebtToken(IERC20 debtToken) external;
    function removeDebtToken(IERC20 debtToken) external;
    function isDebtToken(IERC20 debtToken) external view returns (bool);
    function debtTokens(uint256 index) external view returns (IERC20);
    function debtTokensLength() external view returns (uint256);

    // ========== ACTIONS ==========
    function skim(IERC20 token) external;
    function pledge(bytes calldata facilityData, IERC20 collateralToken, uint256 collateralAmount) external;
    function depledge(bytes calldata facilityData, IERC20 collateralToken, uint256 collateralAmount) external;
    function borrow(bytes calldata facilityData, IERC20 debtToken, uint256 borrowAmount) external;
    function repay(bytes calldata facilityData, IERC20 debtToken, uint256 repayAmount) external;

    // ========== POSITION ==========
    function ltv(bytes calldata facilityData) external view returns (uint256);
    function debtBalance(bytes calldata facilityData, IERC20 debtToken) external view returns (uint256);
    function collateralBalance(bytes calldata facilityData, IERC20 collateralToken) external view returns (uint256);
    function debtBalance(IERC20 debtToken) external view returns (uint256);
    function collateralBalance(IERC20 collateralToken) external view returns (uint256);
    function nav(IOracleCallback oraclesProvider) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @notice Oracle interface to get a token price with 36 decimals of precision
interface IOracle {
    function price() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISwapper {
    /// @dev Sells `amountIn` of `input` tokens for `output` tokens.
    /// @param input The address of the input token.
    /// @param output The address of the output token.
    /// @param amountIn The amount of input tokens to sell.
    /// @param data Additional data to pass to the swapper.
    function sell(IERC20 input, IERC20 output, uint256 amountIn, bytes calldata data) external;
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Steakhouse
pragma solidity >=0.8.0;

// Precision for percentage calculations
uint256 constant PRECISION = 1 ether;
// Maximum timelock duration (4 weeks)
uint256 constant TIMELOCK_CAP = 4 weeks;
// Timelock duration for disabled selectors
uint256 constant TIMELOCK_DISABLED = type(uint256).max;
// Maximum allowed slippage percentage (1%)
uint256 constant MAX_SLIPPAGE_LIMIT = 0.01 ether;
// Delay from start of a shutdown to possible liquidations
uint256 constant MAX_SHUTDOWN_WARMUP = 4 weeks;
// Precision for oracle prices
uint256 constant ORACLE_PRECISION = 1e36;
// Maximum number of tokens allowed in a box
uint256 constant MAX_TOKENS = 20;

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

library ErrorsLib {
    // General errors
    error InvalidAddress();
    error InvalidAmount();
    error InvalidValue();
    error CannotRemove();
    error AlreadyWhitelisted();
    error NotWhitelisted();
    error NotClean();
    error NotAllowed();

    // Access control errors
    error OnlyOwner();
    error OnlyCurator();
    error OnlyGuardian();
    error OnlyCuratorOrGuardian();
    error OnlyAllocators();
    error OnlyFeeders();
    error OnlySkimRecipient();
    error OnlyAllocatorsOrWinddown();
    error OnlyMorpho();
    error OnlyBox();
    error OnlyPool();
    error OnlyThisContract();
    error CannotDuringShutdown();
    error CannotDuringWinddown();

    // Withdraw/Redeem errors
    error InsufficientShares();
    error InsufficientAllowance();
    error InsufficientLiquidity();
    error DataAlreadyTimelocked();

    // Token errors
    error TokenNotWhitelisted();
    error TokenAlreadyWhitelisted();
    error OracleRequired();
    error NoOracleForToken();
    error TokenBalanceMustBeZero();
    error TooManyTokens();

    // Slippage errors
    error SwapperDidSpendTooMuch();
    error AllocationTooExpensive();
    error TokenSaleNotGeneratingEnoughAssets();
    error ReallocationSlippageTooHigh();
    error TooMuchAccumulatedSlippage();
    error SlippageTooHigh();

    // Shutdown/Recover errors
    error OnlyGuardianOrCuratorCanShutdown();
    error OnlyGuardianCanRecover();
    error AlreadyShutdown();
    error NotShutdown();
    error CannotRecoverAfterWinddown();

    // Timelock errors
    error TimelockNotExpired();
    error DataNotTimelocked();
    error InvalidTimelock();
    error TimelockNotIncreasing();
    error TimelockNotDecreasing();
    error FunctionDisabled();

    // Skim errors
    error CannotSkimToken();
    error CannotSkimZero();
    error SkimChangedNav();
    error TransferFailed();

    // Funding module errors
    error ExcessiveLTV();
    error NoNavDuringCache();
    error InvalidFacilityData();

    // Flash callback errors
    error ReentryNotAllowed();
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFunding} from "./../interfaces/IFunding.sol";
import {IOracle} from "./../interfaces/IOracle.sol";
import {ISwapper} from "./../interfaces/ISwapper.sol";

library EventsLib {
    // ========== FACTORIES ==========
    event BoxCreated(
        address indexed box,
        address indexed asset,
        address indexed owner,
        address curator,
        string name,
        string symbol,
        uint256 maxSlippage,
        uint256 slippageEpochDuration,
        uint256 shutdownSlippageDuration,
        uint256 shutdownWarmup
    );

    // ========== ACCESS CONTROL ==========
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event CuratorUpdated(address indexed previousCurator, address indexed newCurator);
    event GuardianUpdated(address indexed previousGuardian, address indexed newGuardian);
    event AllocatorUpdated(address indexed account, bool isAllocator);
    event FeederUpdated(address indexed account, bool isFeeder);

    // ========== INVESTMENT MANAGEMENT ==========
    event Allocation(
        IERC20 indexed token,
        uint256 assets,
        uint256 expectedTokens,
        uint256 actualTokens,
        int256 slippagePct,
        ISwapper indexed swapper,
        bytes data
    );
    event Deallocation(
        IERC20 indexed token,
        uint256 tokens,
        uint256 expectedAssets,
        uint256 actualAssets,
        int256 slippagePct,
        ISwapper indexed swapper,
        bytes data
    );
    event Reallocation(
        IERC20 indexed fromToken,
        IERC20 indexed toToken,
        uint256 tokensFrom,
        uint256 expectedTokensTo,
        uint256 actualTokensTo,
        int256 slippagePct,
        ISwapper indexed swapper,
        bytes data
    );
    event Pledge(IFunding indexed fundingModule, bytes facilityData, IERC20 collateralToken, uint256 collateralAmount);
    event Depledge(IFunding indexed fundingModule, bytes facilityData, IERC20 collateralToken, uint256 collateralAmount);
    event Borrow(IFunding indexed fundingModule, bytes facilityData, IERC20 debtToken, uint256 borrowAmount);
    event Repay(IFunding indexed fundingModule, bytes facilityData, IERC20 debtToken, uint256 repayAmount);
    event Flash(address indexed caller, IERC20 indexed token, uint256 amount);

    // ========== MISC ==========
    event SlippageAccumulated(uint256 amount, uint256 total);
    event SlippageEpochReset(uint256 newEpochStart);
    event MaxSlippageUpdated(uint256 previousMaxSlippage, uint256 newMaxSlippage);
    event Skim(IERC20 indexed token, address indexed recipient, uint256 amount);

    // ========== CONFIGURATION ==========
    event TokenAdded(IERC20 indexed token, IOracle indexed oracle);
    event TokenRemoved(IERC20 indexed token);
    event TokenOracleChanged(IERC20 indexed token, IOracle indexed oracle);
    event FundingModuleAdded(IFunding indexed fundingModule);
    event FundingFacilityAdded(IFunding indexed fundingModule, bytes facilityData);
    event FundingCollateralAdded(IFunding indexed fundingModule, IERC20 collateralToken);
    event FundingDebtAdded(IFunding indexed fundingModule, IERC20 debtToken);
    event FundingModuleRemoved(IFunding indexed fundingModule);
    event FundingFacilityRemoved(IFunding indexed fundingModule, bytes facilityData);
    event FundingCollateralRemoved(IFunding indexed fundingModule, IERC20 collateralToken);
    event FundingDebtRemoved(IFunding indexed fundingModule, IERC20 debtToken);
    event SkimRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event Shutdown(address indexed guardian);
    event Recover(address indexed guardian);

    // ========== TIMELOCK ==========
    event TimelockSubmitted(bytes4 indexed selector, bytes data, uint256 executableAt, address who);
    event TimelockRevoked(bytes4 indexed selector, bytes data, address who);
    event TimelockIncreased(bytes4 indexed selector, uint256 newDuration, address who);
    event TimelockDecreased(bytes4 indexed selector, uint256 newDuration, address who);
    event TimelockExecuted(bytes4 indexed selector, bytes data, address who);
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association, Steakhouse Financial
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVaultV2} from "./../lib/vault-v2/src/interfaces/IVaultV2.sol";
import {SafeERC20Lib} from "./../lib/vault-v2/src/libraries/SafeERC20Lib.sol";
import {IBox} from "./interfaces/IBox.sol";
import {IBoxAdapter} from "./interfaces/IBoxAdapter.sol";

contract BoxAdapter is IBoxAdapter {
    /* IMMUTABLES */

    address public immutable factory;
    address public immutable parentVault;
    IBox public immutable box;
    bytes32 public immutable adapterId;

    /* STORAGE */

    address public skimRecipient;

    /* FUNCTIONS */

    constructor(address _parentVault, IBox _box) {
        factory = msg.sender;
        parentVault = _parentVault;
        box = _box;
        adapterId = keccak256(abi.encode("this", address(this)));
        address asset = IVaultV2(_parentVault).asset();
        require(asset == _box.asset(), AssetMismatch());
        SafeERC20Lib.safeApprove(asset, _parentVault, type(uint256).max);
        SafeERC20Lib.safeApprove(asset, address(_box), type(uint256).max);
    }

    function setSkimRecipient(address newSkimRecipient) external {
        require(msg.sender == IVaultV2(parentVault).owner(), NotAuthorized());
        skimRecipient = newSkimRecipient;
        emit SetSkimRecipient(newSkimRecipient);
    }

    /// @dev Skims the adapter's balance of `token` and sends it to `skimRecipient`.
    /// @dev This is useful to handle rewards that the adapter has earned.
    function skim(address token) external {
        require(msg.sender == skimRecipient, NotAuthorized());
        require(token != address(box), CannotSkimBoxShares());
        uint256 balance = IERC20(token).balanceOf(address(this));
        SafeERC20Lib.safeTransfer(token, skimRecipient, balance);
        emit Skim(token, balance);
    }

    /// @dev Does not log anything because the ids (logged in the parent vault) are enough.
    /// @dev Returns the ids of the allocation and the change in allocation.
    function allocate(bytes memory data, uint256 assets, bytes4, address) external returns (bytes32[] memory, int256) {
        require(data.length == 0, InvalidData());
        require(msg.sender == parentVault, NotAuthorized());

        if (assets > 0) IERC4626(box).deposit(assets, address(this));
        // Safe casts because bounded by Vault V2 which requires totalAssets to stay below ~10^35
        int256 newAllocation = int256(box.previewRedeem(box.balanceOf(address(this))));
        int256 oldAllocation = int256(allocation());

        return (ids(), newAllocation - oldAllocation);
    }

    /// @dev Does not log anything because the ids (logged in the parent vault) are enough.
    /// @dev Returns the ids of the deallocation and the change in allocation.
    function deallocate(bytes memory data, uint256 assets, bytes4, address) external returns (bytes32[] memory, int256) {
        require(data.length == 0, InvalidData());
        require(msg.sender == parentVault, NotAuthorized());

        if (assets > 0) IERC4626(box).withdraw(assets, address(this), address(this));
        // Safe casts because bounded by Vault V2 which requires totalAssets to stay below ~10^35
        int256 newAllocation = int256(box.previewRedeem(box.balanceOf(address(this))));
        int256 oldAllocation = int256(allocation());

        return (ids(), newAllocation - oldAllocation);
    }

    /// @dev Returns adapter's ids.
    function ids() public view returns (bytes32[] memory) {
        bytes32[] memory ids_ = new bytes32[](1);
        ids_[0] = adapterId;
        return ids_;
    }

    function allocation() public view returns (uint256) {
        return IVaultV2(parentVault).allocation(adapterId);
    }

    function realAssets() external view returns (uint256) {
        return allocation() != 0 ? box.previewRedeem(box.balanceOf(address(this))) : 0;
    }

    function adapterData() external view returns (bytes memory) {
        return abi.encode("this", address(this));
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Steakhouse
pragma solidity >=0.8.0;

import {IAdapter} from "../../lib/vault-v2/src/interfaces/IAdapter.sol";
import {IBox} from "./IBox.sol";

interface IBoxAdapter is IAdapter {
    /* EVENTS */

    event SetSkimRecipient(address indexed newSkimRecipient);
    event Skim(address indexed token, uint256 assets);

    /* ERRORS */

    error AssetMismatch();
    error CannotSkimBoxShares();
    error InvalidData();
    error NotAuthorized();

    /* FUNCTIONS */

    function factory() external view returns (address);
    function setSkimRecipient(address newSkimRecipient) external;
    function skim(address token) external;
    function parentVault() external view returns (address);
    function box() external view returns (IBox);
    function skimRecipient() external view returns (address);
    function allocation() external view returns (uint256);
    function ids() external view returns (bytes32[] memory);

    // Added for BoxAdapter
    function adapterId() external view returns (bytes32);
    function adapterData() external view returns (bytes memory);
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association, Steakhouse Financial
pragma solidity >=0.8.0;

import {IBox} from "./IBox.sol";
import {IBoxAdapter} from "./IBoxAdapter.sol";

/// @notice Factory interface for BoxAdapter to link a Morpho Vault V2 and a Box
interface IBoxAdapterFactory {
    /* EVENTS */

    event CreateBoxAdapter(address indexed parentVault, address indexed box, IBoxAdapter indexed boxAdapter);

    /* FUNCTIONS */

    function boxAdapter(address parentVault, IBox box) external view returns (IBoxAdapter);
    function isBoxAdapter(address account) external view returns (bool);
    function createBoxAdapter(address parentVault, IBox box) external returns (IBoxAdapter boxAdapter);
}

// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2025 Morpho Association
pragma solidity >= 0.5.0;

import {IAdapter} from "../../interfaces/IAdapter.sol";

interface IMorphoVaultV1Adapter is IAdapter {
    /* EVENTS */

    event SetSkimRecipient(address indexed newSkimRecipient);
    event Skim(address indexed token, uint256 assets);

    /* ERRORS */

    error AssetMismatch();
    error CannotSkimMorphoVaultV1Shares();
    error InvalidData();
    error NotAuthorized();

    /* FUNCTIONS */

    function factory() external view returns (address);
    function parentVault() external view returns (address);
    function morphoVaultV1() external view returns (address);
    function adapterId() external view returns (bytes32);
    function skimRecipient() external view returns (address);
    function allocation() external view returns (uint256);
    function ids() external view returns (bytes32[] memory);
    function setSkimRecipient(address newSkimRecipient) external;
    function skim(address token) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

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

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/draft-IERC6093.sol)

pragma solidity >=0.8.4;

/**
 * @dev Standard ERC-20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC-721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in ERC-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC-1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1363.sol)

pragma solidity >=0.6.2;

import {IERC20} from "./IERC20.sol";
import {IERC165} from "./IERC165.sol";

/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`, in a single transaction.
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * Note: the ERC-165 identifier for this interface is 0xb0202a11.
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/Panic.sol)

pragma solidity ^0.8.20;

/**
 * @dev Helper library for emitting standardized panic codes.
 *
 * ```solidity
 * contract Example {
 *      using Panic for uint256;
 *
 *      // Use any of the declared internal constants
 *      function foo() { Panic.GENERIC.panic(); }
 *
 *      // Alternatively
 *      function foo() { Panic.panic(Panic.GENERIC); }
 * }
 * ```
 *
 * Follows the list from https://github.com/ethereum/solidity/blob/v0.8.24/libsolutil/ErrorCodes.h[libsolutil].
 *
 * _Available since v5.1._
 */
// slither-disable-next-line unused-state
library Panic {
    /// @dev generic / unspecified error
    uint256 internal constant GENERIC = 0x00;
    /// @dev used by the assert() builtin
    uint256 internal constant ASSERT = 0x01;
    /// @dev arithmetic underflow or overflow
    uint256 internal constant UNDER_OVERFLOW = 0x11;
    /// @dev division or modulo by zero
    uint256 internal constant DIVISION_BY_ZERO = 0x12;
    /// @dev enum conversion error
    uint256 internal constant ENUM_CONVERSION_ERROR = 0x21;
    /// @dev invalid encoding in storage
    uint256 internal constant STORAGE_ENCODING_ERROR = 0x22;
    /// @dev empty array pop
    uint256 internal constant EMPTY_ARRAY_POP = 0x31;
    /// @dev array out of bounds access
    uint256 internal constant ARRAY_OUT_OF_BOUNDS = 0x32;
    /// @dev resource error (too large allocation or too large array)
    uint256 internal constant RESOURCE_ERROR = 0x41;
    /// @dev calling invalid internal function
    uint256 internal constant INVALID_INTERNAL_FUNCTION = 0x51;

    /// @dev Reverts with a panic code. Recommended to use with
    /// the internal constants with predefined codes.
    function panic(uint256 code) internal pure {
        assembly ("memory-safe") {
            mstore(0x00, 0x4e487b71)
            mstore(0x20, code)
            revert(0x1c, 0x24)
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC20.sol)

pragma solidity >=0.4.16;

import {IERC20} from "../token/ERC20/IERC20.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC165.sol)

pragma solidity >=0.4.16;

import {IERC165} from "../utils/introspection/IERC165.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/IERC165.sol)

pragma solidity >=0.4.16;

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "./interfaces/IKaijuMartExtended.sol";
import "./interfaces/IKaijuMartRedeemable.sol";

error KaijuMartEtherPaymentProcessor_InsufficientPermissions();
error KaijuMartEtherPaymentProcessor_InvalidLotState();
error KaijuMartEtherPaymentProcessor_InvalidValue();
error KaijuMartEtherPaymentProcessor_MustBeAKing();
error KaijuMartEtherPaymentProcessor_WithdrawFailed();

/**
                        .             :++-
                       *##-          +####*          -##+
                       *####-      :%######%.      -%###*
                       *######:   =##########=   .######*
                       *#######*-#############*-*#######*
                       *################################*
                       *################################*
                       *################################*
                       *################################*
                       *################################*
                       :*******************************+.

                .:.
               *###%*=:
              .##########+-.
              +###############=:
              %##################%+
             =######################
             -######################++++++++++++++++++=-:
              =###########################################*:
               =#############################################.
  +####%#*+=-:. -#############################################:
  %############################################################=
  %##############################################################
  %##############################################################%=----::.
  %#######################################################################%:
  %##########################################+:    :+%#######################:
  *########################################*          *#######################
   -%######################################            %######################
     -%###################################%            #######################
       =###################################-          :#######################
     ....+##################################*.      .+########################
  +###########################################%*++*%##########################
  %#########################################################################*.
  %#######################################################################+
  ########################################################################-
  *#######################################################################-
  .######################################################################%.
     :+#################################################################-
         :=#####################################################:.....
             :--:.:##############################################+
   ::             +###############################################%-
  ####%+-.        %##################################################.
  %#######%*-.   :###################################################%
  %###########%*=*####################################################=
  %####################################################################
  %####################################################################+
  %#####################################################################.
  %#####################################################################%
  %######################################################################-
  .+*********************************************************************.
 * @title KaijuMartEtherPurchaseProcessor
 * @notice Create ether payment processors for KMart lots
 * @author Augminted Labs, LLC
 */
contract KaijuMartEtherPurchaseProcessor {
    IKaijuMartExtended public immutable KMART;

    event Purchase(
        uint256 indexed id,
        address indexed account,
        uint64 amount
    );

    struct Processor {
        uint104 price;
        bool enabled;
        bool isRedeemable;
        bool requiresKing;
        bool requiresSignature;
    }

    IDoorbusterManager public doorbusterManager;
    mapping(uint256 => Processor) public lotProcessors;

    constructor(IKaijuMartExtended kmart) {
        KMART = kmart;
        doorbusterManager = KMART.managerContracts().doorbuster;
    }

    /**
     * @notice Requires sender to have a KMart admin role
     */
    modifier onlyKMartAdmin() {
        if (!KMART.hasRole(bytes32(0), msg.sender))
            revert KaijuMartEtherPaymentProcessor_InsufficientPermissions();
        _;
    }

    /**
     * @notice Refresh the state of the KMart doorbuster manager contract
     */
    function refreshDoorbusterManager() public payable onlyKMartAdmin {
        doorbusterManager = KMART.managerContracts().doorbuster;
    }

    /**
     * @notice Set a lot payment processor
     * @param _lotId Lot to set a payment processor for
     * @param _processor Payment processor for a specified lot
     */
    function setLotProcessor(
        uint256 _lotId,
        Processor calldata _processor
    )
        public
        payable
        onlyKMartAdmin
    {
        IKaijuMartExtended.Lot memory lot = KMART.lots(_lotId);

        if (uint8(lot.lotType) == 0) revert KaijuMartEtherPaymentProcessor_InvalidLotState();

        lotProcessors[_lotId] = _processor;
        lotProcessors[_lotId].isRedeemable = address(lot.redeemer) != address(0);
    }

    /**
     * @notice Purchase from a KMart doorbuster lot with ETH
     * @param _lotId Lot to purchase from
     * @param _amount Quantity to purchase
     */
    function purchase(uint256 _lotId, uint32 _amount) public payable {
        Processor memory processor = lotProcessors[_lotId];

        if (!processor.enabled || processor.requiresSignature) revert KaijuMartEtherPaymentProcessor_InvalidLotState();
        if (msg.value != processor.price * _amount) revert KaijuMartEtherPaymentProcessor_InvalidValue();
        if (processor.requiresKing && !KMART.isKing(msg.sender)) revert KaijuMartEtherPaymentProcessor_MustBeAKing();

        doorbusterManager.purchase(_lotId, _amount);

        if (processor.isRedeemable)
            KMART.lots(_lotId).redeemer.kmartRedeem(_lotId, _amount, msg.sender);

        emit Purchase(_lotId, msg.sender, _amount);
    }

    /**
     * @notice Purchase from a KMart doorbuster lot with ETH
     * @param _lotId Lot to purchase from
     * @param _amount Quantity to purchase
     * @param _nonce Single use number encoded into signature
     * @param _signature Signature created by the doorbuster contract's `signer` account
     */
    function purchase(
        uint256 _lotId,
        uint32 _amount,
        uint256 _nonce,
        bytes calldata _signature
    )
        public
        payable
    {
        Processor memory processor = lotProcessors[_lotId];

        if (!processor.enabled || !processor.requiresSignature) revert KaijuMartEtherPaymentProcessor_InvalidLotState();
        if (msg.value != processor.price * _amount) revert KaijuMartEtherPaymentProcessor_InvalidValue();
        if (processor.requiresKing && !KMART.isKing(msg.sender)) revert KaijuMartEtherPaymentProcessor_MustBeAKing();

        doorbusterManager.purchase(_lotId, _amount, _nonce, _signature);

        if (processor.isRedeemable)
            KMART.lots(_lotId).redeemer.kmartRedeem(_lotId, _amount, msg.sender);

        emit Purchase(_lotId, msg.sender, _amount);
    }

    /**
     * @notice Send all ETH in the contract to a specified receiver
     * @param _receiver Address to receive all the ETH in the contract
     */
    function withdraw(address _receiver) public payable onlyKMartAdmin {
        (bool success, ) = _receiver.call{ value: address(this).balance }("");
        if (!success) revert KaijuMartEtherPaymentProcessor_WithdrawFailed();
    }
}
// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/IAccessControl.sol";

import "./IKaijuMart.sol";

interface IKaijuMartExtended is IKaijuMart, IAccessControl {
    function managerContracts() external view returns (ManagerContracts memory);
    function lots(uint256 lotId) external view returns (Lot memory);
}
// SPDX-License-Identifier: Unlicense

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

pragma solidity ^0.8.0;

interface IKaijuMartRedeemable is IERC165 {
    function kmartRedeem(uint256 lotId, uint32 amount, address to) external;
}
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
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

// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "./IKingzInTheShell.sol";
import "./IMutants.sol";
import "./IScientists.sol";
import "./IScales.sol";
import "./IRWaste.sol";
import "./IKaijuMartRedeemable.sol";
import "./IAuctionManager.sol";
import "./IDoorbusterManager.sol";
import "./IRaffleManager.sol";
import "./IKaijuMart.sol";

interface IKaijuMart {
    enum LotType {
        NONE,
        AUCTION,
        RAFFLE,
        DOORBUSTER
    }

    enum PaymentToken {
        RWASTE,
        SCALES,
        EITHER
    }

    struct Lot {
        uint104 rwastePrice;
        uint104 scalesPrice;
        LotType lotType;
        PaymentToken paymentToken;
        IKaijuMartRedeemable redeemer;
    }

    struct CreateLot {
        PaymentToken paymentToken;
        IKaijuMartRedeemable redeemer;
    }

    struct KaijuContracts {
        IKingzInTheShell kaiju;
        IMutants mutants;
        IScientists scientists;
        IRWaste rwaste;
        IScales scales;
    }

    struct ManagerContracts {
        IAuctionManager auction;
        IDoorbusterManager doorbuster;
        IRaffleManager raffle;
    }

    event Create(
        uint256 indexed id,
        LotType indexed lotType,
        address indexed managerContract
    );

    event Bid(
        uint256 indexed id,
        address indexed account,
        uint104 value
    );

    event Redeem(
        uint256 indexed id,
        uint32 indexed amount,
        address indexed to,
        IKaijuMartRedeemable redeemer
    );

    event Refund(
        uint256 indexed id,
        address indexed account,
        uint104 value
    );

    event Purchase(
        uint256 indexed id,
        address indexed account,
        uint64 amount
    );

    event Enter(
        uint256 indexed id,
        address indexed account,
        uint64 amount
    );

    // 🦖👑👶🧬👨‍🔬👩‍🔬🧪

    function isKing(address account) external view returns (bool);

    // 💻💻💻💻💻 ADMIN FUNCTIONS 💻💻💻💻💻

    function setKaijuContracts(KaijuContracts calldata _kaijuContracts) external;

    function setManagerContracts(ManagerContracts calldata _managerContracts) external;

    // 📣📣📣📣📣 AUCTION FUNCTIONS 📣📣📣📣📣

    function getAuction(uint256 auctionId) external view returns (IAuctionManager.Auction memory);

    function getBid(uint256 auctionId, address account) external view returns (uint104);

    function createAuction(
        uint256 lotId,
        CreateLot calldata lot,
        IAuctionManager.CreateAuction calldata auction
    ) external;

    function close(
        uint256 auctionId,
        uint104 lowestWinningBid,
        address[] calldata tiebrokenWinners
    ) external;

    function bid(uint256 auctionId, uint104 value) external;

    function refund(uint256 auctionId) external;

    function redeem(uint256 auctionId) external;

    // 🎟🎟🎟🎟🎟 RAFFLE FUNCTIONS 🎟🎟🎟🎟🎟

    function getRaffle(uint256 raffleId) external view returns (IRaffleManager.Raffle memory);

    function createRaffle(
        uint256 lotId,
        CreateLot calldata lot,
        uint104 rwastePrice,
        uint104 scalesPrice,
        IRaffleManager.CreateRaffle calldata raffle
    ) external;

    function draw(uint256 raffleId, bool vrf) external;

    function enter(uint256 raffleId, uint32 amount, PaymentToken token) external;

    // 🛒🛒🛒🛒🛒 DOORBUSTER FUNCTIONS 🛒🛒🛒🛒🛒

    function getDoorbuster(uint256 doorbusterId) external view returns (IDoorbusterManager.Doorbuster memory);

    function createDoorbuster(
        uint256 lotId,
        CreateLot calldata lot,
        uint104 rwastePrice,
        uint104 scalesPrice,
        uint32 supply
    ) external;

    function purchase(
        uint256 doorbusterId,
        uint32 amount,
        PaymentToken token,
        uint256 nonce,
        bytes calldata signature
    ) external;
}
// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IKingzInTheShell is IERC721 {
    function isHolder(address) external view returns (bool);
}
// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IMutants is IERC721 {}
// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IScientists is IERC721 {}
// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IScales is IERC20 {
    function spend(address, uint256) external;
    function credit(address, uint256) external;
}
// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRWaste is IERC20 {
    function burn(address, uint256) external;
    function claimLaboratoryExperimentRewards(address, uint256) external;
}
// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

interface IAuctionManager {
    struct CreateAuction {
        uint104 reservePrice;
        uint16 winners;
        uint64 endsAt;
    }

    struct Auction {
        uint104 reservePrice;
        uint104 lowestWinningBid;
        uint16 winners;
        uint64 endsAt;
    }

    function get(uint256 id) external view returns (Auction memory);
    function getBid(uint256 id, address sender) external view returns (uint104);
    function isWinner(uint256 id, address sender) external view returns (bool);
    function create(uint256 id, CreateAuction calldata auction) external;
    function close(uint256 id, uint104 lowestWinningBid, address[] calldata _tiebrokenWinners) external;
    function bid(uint256 id, uint104 value, address sender) external returns (uint104);
    function settle(uint256 id, address sender) external returns (uint104);
}
// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

interface IDoorbusterManager {
    struct Doorbuster {
        uint32 supply;
    }

    function get(uint256 id) external view returns (Doorbuster memory);
    function create(uint256 id, uint32 supply) external;
    function purchase(uint256 id, uint32 amount) external;
    function purchase(
        uint256 id,
        uint32 amount,
        uint256 nonce,
        bytes memory signature
    ) external;
}
// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

interface IRaffleManager {
    struct CreateRaffle {
        uint64 scriptId;
        uint64 winners;
        uint64 endsAt;
    }

    struct Raffle {
        uint256 seed;
        uint64 scriptId;
        uint64 winners;
        uint64 endsAt;
    }

    function get(uint256 id) external view returns (Raffle memory);
    function isDrawn(uint256 id) external view returns (bool);
    function create(uint256 id, CreateRaffle calldata raffle) external;
    function enter(uint256 id, uint32 amount) external;
    function draw(uint256 id, bool vrf) external;
}
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
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
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
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
interface IERC165 {
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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
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

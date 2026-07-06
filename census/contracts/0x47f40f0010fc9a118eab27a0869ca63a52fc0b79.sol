// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
import {INoFomo} from "./interface/INoFomo.sol";
import {INoFomoNFT} from "./interface/INoFomoNFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

event RandomDrop(uint256 tokenId, address receiver, uint256 amount);

contract DropRandomPool is Ownable {
    INoFomo public nofomoToken;
    INoFomoNFT public nofomoNFT;
    address public mintingContract;
    address public fomosPrizePool;

    constructor(address _nofomoToken, address _nofomoNFT) Ownable(msg.sender) {
        nofomoToken = INoFomo(_nofomoToken);
        nofomoNFT = INoFomoNFT(_nofomoNFT);
    }

    function lottery(uint256 startTokenId, uint256 tokenIdsLength) external {
        require(
            msg.sender == mintingContract || msg.sender == fomosPrizePool,
            "only minting contract"
        );
        address randomDropReciver;
        uint256 winnerId = startTokenId + random(startTokenId, tokenIdsLength);
        randomDropReciver = nofomoNFT.ownerOf(winnerId);
        uint256 prize = nofomoToken.balanceOf(address(this));
        emit RandomDrop(winnerId, randomDropReciver, prize);
        nofomoToken.transfer(randomDropReciver, prize);
    }

    function setMintingContract(address _mintingContract) external onlyOwner {
        mintingContract = _mintingContract;
    }

    function setFomosPrizePool(address _fomosPrizePool) external onlyOwner {
        fomosPrizePool = _fomosPrizePool;
    }

    function random(
        uint256 startTokenId,
        uint256 tokenIdsLength
    ) private view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.prevrandao,
                        block.timestamp,
                        startTokenId,
                        tokenIdsLength
                    )
                )
            ) % tokenIdsLength;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface INoFomo {
    function airdrop(address receipt) external;

    function mint() external;

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function burn(uint256 amount) external;

    function liquidityPoolMint(uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface INoFomoNFT {
    function mint(
        address to,
        uint256 amount,
        uint256 periodId
    ) external returns (uint256[] memory tokenIds);

    function getPeriodIdByTokenId(uint256 tokenId) external returns (uint256);

    function ownerOf(uint256 tokenId) external returns (address);

    function tokenId() external returns (uint256);

    function balanceOf(address owner) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;

import {Context} from "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
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
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
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

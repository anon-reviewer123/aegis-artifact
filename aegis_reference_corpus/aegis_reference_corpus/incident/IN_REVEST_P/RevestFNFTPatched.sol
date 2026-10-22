// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

interface IERC1155Receiver {
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns (bytes4);
    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external returns (bytes4);
}

contract RevestFNFTPatched is Context, ReentrancyGuard {
    uint256 public constant FNFT_ID = 1;
    mapping(address => uint256) public supplyOf;
    uint256 public totalSupply;
    uint256 public lockedValue;

    function mintFNFT(address to, uint256 quantity) external payable nonReentrant {
        require(quantity > 0 && msg.value == quantity, "mismatch");
        lockedValue += msg.value;
        supplyOf[to] += quantity;
        totalSupply += quantity;
        IERC1155Receiver(to).onERC1155Received(_msgSender(), address(0), FNFT_ID, quantity, "");
    }

    function mintUnbacked() external {
        require(lockedValue > totalSupply, "no surplus");
        uint256 extra = lockedValue - totalSupply;
        supplyOf[_msgSender()] += extra;
        totalSupply += extra;
    }

    function withdrawFNFT(uint256 quantity) external nonReentrant {
        require(supplyOf[_msgSender()] >= quantity, "supply");
        supplyOf[_msgSender()] -= quantity;
        totalSupply -= quantity;
        lockedValue -= quantity;
        payable(_msgSender()).transfer(quantity);
    }
}

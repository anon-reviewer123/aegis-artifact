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

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

contract OmniLendPatched is Context, ReentrancyGuard {
    mapping(address => uint256) public collateralOf;
    mapping(address => uint256) public debtOf;
    uint256 public totalCollateral;

    function depositCollateral() external payable {
        collateralOf[_msgSender()] += msg.value;
        totalCollateral += msg.value;
    }

    function borrow(uint256 amount) external {
        require(debtOf[_msgSender()] + amount <= collateralOf[_msgSender()], "ltv");
        debtOf[_msgSender()] += amount;
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        require(collateralOf[_msgSender()] - debtOf[_msgSender()] >= amount, "locked");
        collateralOf[_msgSender()] -= amount;
        totalCollateral -= amount;
        IERC721Receiver(_msgSender()).onERC721Received(_msgSender(), address(this), amount, "");
    }
}

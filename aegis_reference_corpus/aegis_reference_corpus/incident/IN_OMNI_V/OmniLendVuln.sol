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

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

contract OmniLendVuln is Context {
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

    function withdrawCollateral(uint256 amount) external {
        require(collateralOf[_msgSender()] - debtOf[_msgSender()] >= amount, "locked");
        IERC721Receiver(_msgSender()).onERC721Received(_msgSender(), address(this), amount, "");
        collateralOf[_msgSender()] -= amount;
        totalCollateral -= amount;
    }
}

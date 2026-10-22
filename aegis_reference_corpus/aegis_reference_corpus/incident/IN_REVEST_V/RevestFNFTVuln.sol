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

interface IERC1155Receiver {
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns (bytes4);
    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external returns (bytes4);
}

contract RevestFNFTVuln is Context {
    uint256 public constant FNFT_ID = 1;
    mapping(address => uint256) public supplyOf;
    uint256 public totalSupply;
    uint256 public lockedValue;

    function mintFNFT(address to, uint256 quantity) external payable {
        require(quantity > 0 && msg.value == quantity, "mismatch");
        lockedValue += msg.value;
        IERC1155Receiver(to).onERC1155Received(_msgSender(), address(0), FNFT_ID, quantity, "");
        supplyOf[to] += quantity;
        totalSupply += quantity;
    }

    function mintUnbacked() external {
        require(lockedValue > totalSupply, "no surplus");
        uint256 extra = lockedValue - totalSupply;
        supplyOf[_msgSender()] += extra;
        totalSupply += extra;
    }

    function withdrawFNFT(uint256 quantity) external {
        require(supplyOf[_msgSender()] >= quantity, "supply");
        supplyOf[_msgSender()] -= quantity;
        totalSupply -= quantity;
        lockedValue -= quantity;
        payable(_msgSender()).transfer(quantity);
    }
}

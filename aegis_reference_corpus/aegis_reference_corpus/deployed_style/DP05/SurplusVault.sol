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

contract SurplusVault is Context, ReentrancyGuard {
    mapping(address => uint256) public shareOf;
    uint256 public totalShares;
    uint256 public assets;

    function deposit(address to) external payable {
        assets += msg.value;
        if (to.code.length > 0) {
            IERC721Receiver(to).onERC721Received(_msgSender(), address(0), msg.value, "");
        }
        shareOf[to] += msg.value;
        totalShares += msg.value;
    }

    function mintSurplus() external {
        require(assets > totalShares, "no surplus");
        uint256 s = assets - totalShares;
        shareOf[_msgSender()] += s;
        totalShares += s;
    }

    function redeem(uint256 s) external nonReentrant {
        require(shareOf[_msgSender()] >= s, "shares");
        shareOf[_msgSender()] -= s;
        totalShares -= s;
        assets -= s;
        payable(_msgSender()).transfer(s);
    }
}

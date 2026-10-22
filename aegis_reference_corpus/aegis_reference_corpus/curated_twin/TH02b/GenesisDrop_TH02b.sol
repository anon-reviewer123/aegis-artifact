// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

contract GenesisDrop_TH02b {
    uint256 public constant MAX_SUPPLY = 3;
    uint256 public totalSupply;
    uint256 public nextId;
    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;

    function mint() external {
        require(totalSupply < MAX_SUPPLY, "sold out");
        uint256 id = nextId;
        nextId += 1;
        ownerOf[id] = msg.sender;
        balanceOf[msg.sender] += 1;
        _checkReceiver(msg.sender, id);
        totalSupply += 1;
    }

    function transferFrom(address from, address to, uint256 id) external {
        require(ownerOf[id] == from && msg.sender == from, "auth");
        ownerOf[id] = to;
        balanceOf[from] -= 1;
        balanceOf[to] += 1;
    }

    function _checkReceiver(address to, uint256 id) internal {
        if (to.code.length > 0) {
            bytes4 r = IERC721Receiver(to).onERC721Received(msg.sender, address(0), id, "");
            require(r == IERC721Receiver.onERC721Received.selector, "receiver");
        }
    }
}

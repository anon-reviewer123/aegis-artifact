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

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
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

library Counters {
    struct Counter {
        uint256 _value;
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }
}

contract NestMintClub is Context, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _supply;
    uint256 public constant MAX_SUPPLY = 5000;
    uint256 public mintPrice = 0.05 ether;
    uint256 public teamBalance;
    address payable public teamWallet;
    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    string public baseURI;

    constructor(address payable team) {
        teamWallet = team;
    }

    function mint(uint256 qty) external payable nonReentrant {
        require(qty > 0 && qty <= 10, "qty");
        require(_supply.current() + qty <= MAX_SUPPLY, "sold out");
        require(msg.value >= mintPrice * qty, "price");
        teamBalance += msg.value;
        for (uint256 i = 0; i < qty; i++) {
            _supply.increment();
            uint256 id = _supply.current();
            ownerOf[id] = _msgSender();
            balanceOf[_msgSender()] += 1;
        }
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
    }

    function setPrice(uint256 p) external onlyOwner {
        mintPrice = p;
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 amount = teamBalance;
        teamBalance = 0;
        (bool ok, ) = teamWallet.call{value: amount}("");
        require(ok, "withdraw failed");
    }
}

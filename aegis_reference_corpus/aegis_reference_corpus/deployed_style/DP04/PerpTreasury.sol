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

contract PerpTreasury is Context, Ownable {
    mapping(address => uint256) public glp;
    uint256 public aum;
    uint256 public trackedValue;
    address public settler;

    function setSettler(address s) external onlyOwner {
        settler = s;
    }

    function deposit() external payable {
        glp[_msgSender()] += msg.value;
        aum += msg.value;
        trackedValue += msg.value;
    }

    function mintGlp() external {
        require(aum > trackedValue, "no surplus");
        uint256 surplus = aum - trackedValue;
        glp[_msgSender()] += surplus;
        trackedValue += surplus;
    }

    function decreasePosition(uint256 amount) external {
        require(glp[_msgSender()] >= amount, "glp");
        glp[_msgSender()] -= amount;
        trackedValue -= amount;
        if (settler != address(0)) {
            (bool ok, ) = settler.call("");
            require(ok, "settler");
        }
        aum -= amount;
    }
}

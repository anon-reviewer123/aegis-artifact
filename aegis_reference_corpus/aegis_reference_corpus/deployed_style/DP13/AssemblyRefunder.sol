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

contract AssemblyRefunder is Context {
    mapping(address => uint256) public deposits;
    uint256 public totalDeposits;
    bytes32 private constant SLOT = keccak256("refunder.reentry.lock");

    function _locked() private view returns (bool l) {
        bytes32 s = SLOT;
        assembly {
            l := sload(s)
        }
    }

    function _setLock(bool v) private {
        bytes32 s = SLOT;
        assembly {
            sstore(s, v)
        }
    }

    function deposit() external payable {
        deposits[_msgSender()] += msg.value;
        totalDeposits += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(!_locked(), "reentrant");
        require(deposits[_msgSender()] >= amount, "deposit");
        _setLock(true);
        deposits[_msgSender()] -= amount;
        totalDeposits -= amount;
        (bool ok, ) = _msgSender().call{value: amount}("");
        require(ok, "send");
        _setLock(false);
    }
}

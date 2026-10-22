// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Exact {
    mapping(address => uint256) public r;
    uint256 public sum;
    uint256 public total;
    uint256 public feeRate;
    uint256 public share;

    function move(address a, address b, uint256 p) public {
        require(sum == total);
        uint256 fee = (p * feeRate) / 10000;
        uint256 refl = (fee * share) / 100;
        require(fee <= p && refl <= fee && r[a] >= p);
        r[a] -= p; sum -= p;
        r[b] += p - fee; sum += p - fee;
        r[address(this)] += fee - refl; sum += fee - refl;
        total -= refl;
        assert(sum == total);
    }
}

contract Abstracted {
    mapping(address => uint256) public r;
    uint256 public sum;
    uint256 public total;
    uint256 public feeRate;
    uint256 public share;

    function nl(uint256 a, uint256 b, uint256 tag) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(a, b, tag)));
    }

    function move(address a, address b, uint256 p) public {
        require(sum == total);
        uint256 fee = nl(p, feeRate, 1);
        uint256 refl = nl(fee, share, 2);
        require(fee <= p && refl <= fee && r[a] >= p);
        r[a] -= p; sum -= p;
        r[b] += p - fee; sum += p - fee;
        r[address(this)] += fee - refl; sum += fee - refl;
        total -= refl;
        assert(sum == total);
    }

    function deterministic(uint256 a, uint256 b) public pure {
        assert(nl(a, b, 1) == nl(a, b, 1));
    }
}

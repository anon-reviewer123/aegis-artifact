pragma solidity 0.4.26;

/// poker.sol -- ds-cache with medianizer poke

// Copyright (C) 2017  DappHub, LLC

// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND (express or implied).

contract DSAuthority {
    function canCall(
        address src, address dst, bytes4 sig
    ) constant returns (bool);
}

contract DSAuthEvents {
    event LogSetAuthority (address indexed authority);
    event LogSetOwner     (address indexed owner);
}

contract DSAuth is DSAuthEvents {
    DSAuthority  public  authority;
    address      public  owner;

    function DSAuth() {
        owner = msg.sender;
        LogSetOwner(msg.sender);
    }

    function setOwner(address owner_)
        auth
    {
        owner = owner_;
        LogSetOwner(owner);
    }

    function setAuthority(DSAuthority authority_)
        auth
    {
        authority = authority_;
        LogSetAuthority(authority);
    }

    modifier auth {
        assert(isAuthorized(msg.sender, msg.sig));
        _;
    }

    modifier authorized(bytes4 sig) {
        assert(isAuthorized(msg.sender, sig));
        _;
    }

    address tthisAddr;
    function isAuthorized(address src, bytes4 sig) internal returns (bool p) {
        DSAuthority lk = DSAuthority(0);
        if (src == tthisAddr) {
            p = true;
        } else if (src == owner) {
            p = true;
        } else if (authority == lk) {
            p = false;
        } else {
            p = authority.canCall(src, this, sig);
        }
        return p;
    }

    function assert(bool x) internal {
        if (!x) require(true == false);
    }
}


contract DSNote {
    event LogNote(
        bytes4   indexed  sig,
        address  indexed  guy,
        bytes32  indexed  foo,
        bytes32  indexed  bar,
	uint	 	  wad,
        bytes             fax
    ) anonymous;

    modifier note {
        bytes32 foo;
        bytes32 bar;

        assembly {
            foo := calldataload(4)
            bar := calldataload(36)
        }

        LogNote(msg.sig, msg.sender, foo, bar, msg.value, msg.data);

        _;
    }
}

contract DSMath {
    
    /*
    standard uint256 functions
     */

    function add(uint256 x, uint256 y) constant internal returns (uint256 z) {
        z = x + y;
        require((z) >= x);
        return z;
    }

    function sub(uint256 x, uint256 y) constant internal returns (uint256 z) {
        z = x - y;
        require((z) <= x);
        return z;
    }

    function mul(uint256 x, uint256 y) constant internal returns (uint256 z) {
        z = x * y;
        require(x == 0 || z / x == y);
        return z;
    }

    function div(uint256 x, uint256 y) constant internal returns (uint256 z) {
        z = x / y;
        return z;
    }

    function min(uint256 x, uint256 y) constant internal returns (uint256 z) {
        z = x <= y ? x : y;
        return z;
    }
    function max(uint256 x, uint256 y) constant internal returns (uint256 z) {
        z = x >= y ? x : y;
        return z;
    }

    /*
    uint128 functions (h is for half)
     */


    function hadd(uint128 x, uint128 y) constant internal returns (uint128 z) {
        z = x + y;
        require((z) >= x);
        return z;
    }

    function hsub(uint128 x, uint128 y) constant internal returns (uint128 z) {
        z = x - y;
        require((z) <= x);
        return z;
    }

    function hmul(uint128 x, uint128 y) constant internal returns (uint128 z) {
        z = x * y;
        require(x == 0 || z / x == y);
        return z;
    }

    function hdiv(uint128 x, uint128 y) constant internal returns (uint128 z) {
        z = x / y;
        return z;
    }

    function hmin(uint128 x, uint128 y) constant internal returns (uint128 z) {
        z = x <= y ? x : y;
        return z;
    }
    function hmax(uint128 x, uint128 y) constant internal returns (uint128 z) {
        z = x >= y ? x : y;
        return z;
    }


    /*
    int256 functions
     */

    function imin(int256 x, int256 y) constant internal returns (int256 z) {
        z = x <= y ? x : y;
        return z;
    }
    function imax(int256 x, int256 y) constant internal returns (int256 z) {
        z = x >= y ? x : y;
        return z;
    }

    /*
    WAD math
     */

    uint128 constant WAD = 10 ** 18;

    function wadd(uint128 x, uint128 y) constant internal returns (uint128 z) {
        z = hadd(x, y);
        return z;
    }

    function wsub(uint128 x, uint128 y) constant internal returns (uint128 z) {
        z = hsub(x, y);
        return z;
    }

    function wmul(uint128 x, uint128 y) constant internal returns (uint128 z) {
        uint x1 = uint256(x);
        uint x2 = (x1 * y + WAD / 2) / WAD;
        z = cast(x2);
        return z;
    }

    function wdiv(uint128 x, uint128 y) constant internal returns (uint128 z) {
        uint x1 = uint256(x);
        uint x2 = (x1 * WAD + y / 2) / y;
        z = cast(x2);
        return z;
    }

    function wmin(uint128 x, uint128 y) constant internal returns (uint128 z) {
        z = hmin(x, y);
        return z;
    }
    function wmax(uint128 x, uint128 y) constant internal returns (uint128 z) {
        z = hmax(x, y);
        return z;
    }

    /*
    RAY math
     */

    uint128 constant RAY = 10 ** 27;

    function radd(uint128 x, uint128 y) constant internal returns (uint128 z) {
        z = hadd(x, y);
        return z;
    }

    function rsub(uint128 x, uint128 y) constant internal returns (uint128 z) {
        z = hsub(x, y);
        return z;
    }

    function rmul(uint128 x, uint128 y) constant internal returns (uint128 z) {
        uint x1 = uint256(x);
        uint x2 = (x1 * y + RAY / 2) / RAY;
        z = cast(x2);
        return z;
    }

    function rdiv(uint128 x, uint128 y) constant internal returns (uint128 z) {
        uint x1 = uint256(x);
        uint x2 = (x1 * RAY + y / 2) / y;
        z = cast(x2);
        return z;
    }

    function rpow(uint128 x, uint64 n) constant internal returns (uint128 z) {
        // This famous algorithm is called "exponentiation by squaring"
        // and calculates x^n with x as fixed-point and n as regular unsigned.
        //
        // It&#39;s O(log n), instead of O(n) for naive repeated multiplication.
        //
        // These facts are why it works:
        //
        //  If n is even, then x^n = (x^2)^(n/2).
        //  If n is odd,  then x^n = x * x^(n-1),
        //   and applying the equation for even x gives
        //    x^n = x * (x^2)^((n-1) / 2).
        //
        //  Also, EVM division is flooring and
        //    floor[(n-1) / 2] = floor[n / 2].

        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rmul(x, x);

            if (n % 2 != 0) {
                z = rmul(z, x);
            }
        }
    }

    function rmin(uint128 x, uint128 y) constant internal returns (uint128 p) {
        p = hmin(x, y);
return p;
    }
    function rmax(uint128 x, uint128 y) constant internal returns (uint128 p) {
        p = hmax(x, y);
        return p;
    }

    function cast(uint256 x) constant internal returns (uint128 z) {
        z = uint128(x);
        require(z == x);
        return z;
    }

}

contract DSThing is DSAuth, DSNote, DSMath {
}

contract DSValue is DSThing {
    bool    has;
    bytes32 val;
    function peek() constant returns (bytes32, bool) {
        return (val,has);
    }
    function read() constant returns (bytes32) {
        var (wut, has) = peek();
        require(has == true);
        return wut;
    }
    function poke(bytes32 wut) note auth {
        val = wut;
        has = true;
    }
    function void() note auth { // unset the value
        has = false;
    }
}

contract DSCache is DSValue
{
    uint128 public zzz;
//  from DSValue:
//  bool    has;
//  bytes32 val;
    function peek() constant returns (bytes32, bool) {
        return (val, has && now < zzz);
    }
    function read() constant returns (bytes32) {
        var (wut, has) = peek();
        assert(now < zzz);
        require(has == true);
        return wut;
    }
    function prod(bytes32 wut, uint128 Zzz) note auth {
        zzz = Zzz;
        poke(wut);
    }
    // from DSValue:
    // function poke(bytes32 wut) note auth {
    //     val = wut;
    //     has = true;
    // }
    // function void() note auth { // unset the value
    //     has = false;
    // }

}

contract Poker is DSCache {

    function poke(address med, bytes32 wut) auth {
        super.poke(wut);
        assert(med.call(bytes4(sha3("poke()"))));
        //Medianizer(med).poke();
    }

    function prod(address med, bytes32 wut, uint128 zzz) auth {
        super.prod(wut, zzz);
        assert(med.call(bytes4(sha3("poke()"))));
        //Medianizer(med).poke();
    }
}
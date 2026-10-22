pragma solidity ^0.4.18;
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
        bool s1 = isAuthorized(msg.sender, msg.sig);
        require(s1 == true);
        _;
    }

    modifier authorized(bytes4 sig) {
        bool s1 = isAuthorized(msg.sender, sig);
        require(s1 == true);
        _;
    }
address tthisAdd;
    function isAuthorized(address src, bytes4 sig) internal returns (bool p) {
        if (src == tthisAdd) {
            p = true;
        } else if (src == owner) {
            p = true;
        } 
        // else if (authority == DSAuthority(0)) {
        //     return false;
        // } 
        else {
            p = authority.canCall(src, this, sig);
        }
        return p;
    }

    // function require(bool x) internal {
    //     if (!x) throw;
    // }
}
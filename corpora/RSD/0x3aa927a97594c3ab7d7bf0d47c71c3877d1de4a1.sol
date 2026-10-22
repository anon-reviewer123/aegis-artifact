pragma solidity 0.4.26;

contract ERC20 {
    function totalSupply() constant returns (uint supply);
    function balanceOf( address who ) constant returns (uint value);
    function allowance( address owner, address spender ) constant returns (uint _allowance);

    function transfer( address to, uint value) returns (bool ok);
    function transferFrom( address from, address to, uint value) returns (bool ok);
    function approve( address spender, uint value ) returns (bool ok);

    event Transfer( address indexed from, address indexed to, uint value);
    event Approval( address indexed owner, address indexed spender, uint value);
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

contract DSNote {
    event LogNote(
        bytes4   indexed  sig,
        address  indexed  guy,
        bytes32  indexed  foo,
        bytes32  indexed  bar,
        uint              wad,
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
        bool k = isAuthorized(msg.sender, msg.sig);
        require(k == true);
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
}

contract EventfulMarket {
    event LogItemUpdate(uint id);
    event LogTrade(uint pay_amt, address indexed pay_gem,
                   uint buy_amt, address indexed buy_gem);

    event LogMake(
        bytes32  indexed  id,
        bytes32  indexed  pair,
        address  indexed  maker,
        ERC20             pay_gem,
        ERC20             buy_gem,
        uint128           pay_amt,
        uint128           buy_amt,
        uint64            timestamp
    );

    event LogBump(
        bytes32  indexed  id,
        bytes32  indexed  pair,
        address  indexed  maker,
        ERC20             pay_gem,
        ERC20             buy_gem,
        uint128           pay_amt,
        uint128           buy_amt,
        uint64            timestamp
    );

    event LogTake(
        bytes32           id,
        bytes32  indexed  pair,
        address  indexed  maker,
        ERC20             pay_gem,
        ERC20             buy_gem,
        address  indexed  taker,
        uint128           take_amt,
        uint128           give_amt,
        uint64            timestamp
    );

    event LogKill(
        bytes32  indexed  id,
        bytes32  indexed  pair,
        address  indexed  maker,
        ERC20             pay_gem,
        ERC20             buy_gem,
        uint128           pay_amt,
        uint128           buy_amt,
        uint64            timestamp
    );
}

contract SimpleMarket is EventfulMarket, DSMath {

    uint public last_offer_id;

    mapping (uint => OfferInfo) public offers;

    bool locked;

    struct OfferInfo {
        uint     pay_amt;
        ERC20    pay_gem;
        uint     buy_amt;
        ERC20    buy_gem;
        address  owner;
        bool     active;
        uint64   timestamp;
    }

    modifier can_buy(uint id) {
        bool k = isActive(id);
        require(k == true);
        _;
    }

    modifier can_cancel(uint id) {
        bool k = isActive(id);
        require(k == true);
        address sd = getOwner(id);
        require(sd == msg.sender);
        _;
    }

    modifier can_offer {
        _;
    }

    modifier synchronized {
        require(!locked);
        locked = true;
        _;
        locked = false;
    }

    function isActive(uint id) constant returns (bool active) {
        active = offers[id].active;
        return active;
    }

    function getOwner(uint id) constant returns (address owner) {
        owner = offers[id].owner;
        return owner;
    }

    function getOffer(uint id) constant returns (uint, ERC20, uint, ERC20) {
      var offer = offers[id];
      return (offer.pay_amt, offer.pay_gem,
              offer.buy_amt, offer.buy_gem);
    }

    // ---- Public entrypoints ---- //

    // function bump( id_)
    //     can_buy(uint256(id_))
    // {
    //     var id = uint256(id_);
    //     LogBump(
    //         id_,
    //         sha3(offers[id].pay_gem, offers[id].buy_gem),
    //         offers[id].owner,
    //         offers[id].pay_gem,
    //         offers[id].buy_gem,
    //         uint128(offers[id].pay_amt),
    //         uint128(offers[id].buy_amt),
    //         offers[id].timestamp
    //     );
    // }

    // Accept given `quantity` of an offer. Transfers funds from caller to
    // offer maker, and from market to caller.
    function buy(uint id, uint quantity)
        can_buy(id)
        synchronized
        returns (bool)
    {
        OfferInfo memory offer = offers[id];
        uint spend = (quantity* offer.buy_amt) / offer.pay_amt;

        // //require(uint128(spend) == spend);
        // // require(uint128(quantity) == quantity);

        // For backwards semantic compatibility.
        if (quantity == 0 || spend == 0 ||
            quantity > offer.pay_amt || spend > offer.buy_amt)
        {
            return false;
        }

        offers[id].pay_amt = sub(offer.pay_amt, quantity);
        offers[id].buy_amt = sub(offer.buy_amt, spend);
        offer.buy_gem.transferFrom(msg.sender, offer.owner, spend);
        offer.pay_gem.transfer(msg.sender, quantity);

        // LogItemUpdate(id);
        // LogTake(
        //     bytes32(id),
        //     sha3(offer.pay_gem, offer.buy_gem),
        //     offer.owner,
        //     offer.pay_gem,
        //     offer.buy_gem,
        //     msg.sender,
        //     uint128(quantity),
        //     uint128(spend),
        //     uint64(now)
        // );
        // LogTrade(quantity, offer.pay_gem, spend, offer.buy_gem);

        if (offers[id].pay_amt == 0) {
          delete offers[id];
        }

        return true;
    }

    // Cancel an offer. Refunds offer maker.
    function cancel(uint id)
        can_cancel(id)
        synchronized
        returns (bool success)
    {
        // read-only offer. Modify an offer by directly accessing offers[id]
        OfferInfo memory offer = offers[id];
        delete offers[id];

        offer.pay_gem.transfer(offer.owner, offer.pay_amt);

        LogItemUpdate(id);
        LogKill(
            bytes32(id),
            sha3(offer.pay_gem, offer.buy_gem),
            offer.owner,
            offer.pay_gem,
            offer.buy_gem,
            uint128(offer.pay_amt),
            uint128(offer.buy_amt),
            uint64(now)
        );

        success = true;
    }

    function kill(bytes32 id) {
        bool jh = cancel(uint256(id));
        require(jh == true);
    }

    function make(
        ERC20    pay_gem,
        ERC20    buy_gem,
        uint128  pay_amt,
        uint128  buy_amt
    ) returns (bytes32 id) {
        return bytes32(offer(pay_amt, pay_gem, buy_amt, buy_gem));
    }

    // Make a new offer. Takes funds from the caller into market escrow.
    function offer(uint pay_amt, ERC20 pay_gem, uint buy_amt, ERC20 buy_gem)
        can_offer
        synchronized
        returns (uint id)
    {
        require(uint128(pay_amt) == pay_amt);
        require(uint128(buy_amt) == buy_amt);
        require(pay_amt > 0);
        ERC20 xz = ERC20(0x0);
        require(pay_gem != xz);
        require(buy_amt > 0);
        require(buy_gem != xz);
        require(pay_gem != buy_gem);

        OfferInfo memory info;
        info.pay_amt = pay_amt;
        info.pay_gem = pay_gem;
        info.buy_amt = buy_amt;
        info.buy_gem = buy_gem;
        info.owner = msg.sender;
        info.active = true;
        info.timestamp = uint64(now);
        id = _next_id();
        offers[id] = info;

        pay_gem.transferFrom(msg.sender, this, pay_amt);

        LogItemUpdate(id);
        LogMake(
            bytes32(id),
            sha3(pay_gem, buy_gem),
            msg.sender,
            pay_gem,
            buy_gem,
            uint128(pay_amt),
            uint128(buy_amt),
            uint64(now)
        );
    }

    function take(bytes32 id, uint128 maxTakeAmount) {
        buy(uint256(id), maxTakeAmount);
    }

    function _next_id() internal returns (uint) {
        last_offer_id++; return last_offer_id;
    }
}

// Simple Market with a market lifetime. When the close_time has been reached,
// offers can only be cancelled (offer and buy will throw).
contract ExpiringMarket is DSAuth, SimpleMarket {
    uint64 public close_time;
    bool public stopped;

    // after close_time has been reached, no new offers are allowed
    modifier can_offer {
        bool l = isClosed();
        require(!l);
        _;
    }

    // after close, no new buys are allowed
    modifier can_buy(uint id) {
        bool k = isActive(id);
        require(k == true);
        bool l = isClosed();
        require(!l);
        _;
    }

    // after close, anyone can cancel an offer
    modifier can_cancel(uint id) {
        bool k = isActive(id);
        require(k == true);
        bool pk = isClosed();
        address sxcd = getOwner(id);
        require(pk == true || (msg.sender == sxcd));
        _;
    }

    function ExpiringMarket(uint64 _close_time) {
        close_time = _close_time;
    }

    function isClosed() constant returns (bool closed) {
        uint pl = getTime();
        if(stopped == true|| pl > close_time){
            closed = true;
        }
        else{
            closed = false;
        }
        return closed;
    }

    function getTime() returns (uint64 p) {
        p = uint64(now);
        return p;
    }

    function stop() auth {
        stopped = true;
    }
}

contract MatchingEvents {
    event LogBuyEnabled(bool isEnabled);
    event LogMinSell(address pay_gem, uint min_amount);
    event LogMatchingEnabled(bool isEnabled);
    event LogUnsortedOffer(uint id);
    event LogSortedOffer(uint id);
    event LogAddTokenPairWhitelist(ERC20 baseToken, ERC20 quoteToken);
    event LogRemTokenPairWhitelist(ERC20 baseToken, ERC20 quoteToken);
}

contract MatchingMarket is MatchingEvents, ExpiringMarket, DSNote {
    bool public buyEnabled = true;      //buy enabled
    bool public matchingEnabled = true; //true: enable matching,
                                         //false: revert to expiring market
    struct sortInfo {
        uint next;  //points to id of next higher offer
        uint prev;  //points to id of previous lower offer
    }
    mapping(uint => sortInfo) public _rank;                     //doubly linked lists of sorted offer ids
    mapping(address => mapping(address => uint)) public _best;  //id of the highest offer for a token pair
    mapping(address => mapping(address => uint)) public _span;  //number of offers stored for token pair in sorted orderbook
    mapping(address => uint) public _dust;                      //minimum sell amount for a token to avoid dust offers
    mapping(uint => uint) public _near;         //next unsorted offer id
    mapping(bytes32 => bool) public _menu;      //whitelist tracking which token pairs can be traded
    uint _head;                                 //first unsorted offer id

    //check if token pair is enabled
    modifier isWhitelist(ERC20 buy_gem, ERC20 pay_gem) {
        require(_menu[sha3(buy_gem, pay_gem)] == true || _menu[sha3(pay_gem, buy_gem)] == true);
        _;
    }

    function MatchingMarket(uint64 close_time) ExpiringMarket(close_time) {
    }

    // ---- Public entrypoints ---- //

    function make(
        ERC20    pay_gem,
        ERC20    buy_gem,
        uint128  pay_amt,
        uint128  buy_amt
    )
    returns (bytes32 p) {
        uint pl = offer(pay_amt, pay_gem, buy_amt, buy_gem);
        p = bytes32(pl);
        return p;
    }

    function take(bytes32 id, uint128 maxTakeAmount) {
        uint pk = uint256(id);
        buy(pk, maxTakeAmount);
    }

    function kill(bytes32 id) {
        bool jh = cancel(uint256(id));
        require(jh == true);
    }

    // Make a new offer. Takes funds from the caller into market escrow.
    //
    // If matching is enabled:
    //     * creates new offer without putting it in
    //       the sorted list.
    //     * available to authorized contracts only!
    //     * keepers should call insert(id,pos)
    //       to put offer in the sorted list.
    //
    // If matching is disabled:
    //     * calls expiring market&#39;s offer().
    //     * available to everyone without authorization.
    //     * no sorting is done.
    //
    function offer(
        uint pay_amt,    //maker (ask) sell how much
        ERC20 pay_gem,   //maker (ask) sell which token
        uint buy_amt,    //taker (ask) buy how much
        ERC20 buy_gem    //taker (ask) buy which token
    )
    isWhitelist(pay_gem, buy_gem)
    /* NOT synchronized!!! */
    returns (uint p)
    {
        if(matchingEnabled == true){
            p = _offeru(pay_amt, pay_gem, buy_amt, buy_gem);
        }
        else{
            p = super.offer(pay_amt, pay_gem, buy_amt, buy_gem);
        }
        return p;
    }

    // Make a new offer. Takes funds from the caller into market escrow.
    function offer(
        uint pay_amt,    //maker (ask) sell how much
        ERC20 pay_gem,   //maker (ask) sell which token
        uint buy_amt,    //maker (ask) buy how much
        ERC20 buy_gem,   //maker (ask) buy which token
        uint pos         //position to insert offer, 0 should be used if unknown
    )
    isWhitelist(pay_gem, buy_gem)
    /*NOT synchronized!!! */
    can_offer
    returns (uint)
    {
        return offer(pay_amt, pay_gem, buy_amt, buy_gem, pos, false);
    }

    function offer(
        uint pay_amt,    //maker (ask) sell how much
        ERC20 pay_gem,   //maker (ask) sell which token
        uint buy_amt,    //maker (ask) buy how much
        ERC20 buy_gem,   //maker (ask) buy which token
        uint pos,        //position to insert offer, 0 should be used if unknown
        bool rounding    //match "close enough" orders?
    )
    isWhitelist(pay_gem, buy_gem)
    /*NOT synchronized!!! */
    can_offer
    returns (uint)
    {
        require(_dust[pay_gem] <= pay_amt);

        if (matchingEnabled == true) {
          return _matcho(pay_amt, pay_gem, buy_amt, buy_gem, pos, rounding);
        }
        return super.offer(pay_amt, pay_gem, buy_amt, buy_gem);
    }

    //Transfers funds from caller to offer maker, and from market to caller.
    function buy(uint id, uint amount)
    /*NOT synchronized!!! */
    can_buy(id)
    returns (bool p)
    {
        if(matchingEnabled == true) {
            p = _buys(id, amount); 
        } else{p = super.buy(id, amount);}
        return p;
    }

    // Cancel an offer. Refunds offer maker.
    function cancel(uint id)
    /*NOT synchronized!!! */
    can_cancel(id)
    returns (bool success)
    {
        if (matchingEnabled == true) {
            bool sd = isOfferSorted(id);
            if (sd == true) {
                bool sd1 = _unsort(id);
                require(sd1 == true);
            } else {
                bool sd2 = _hide(id);
                require(sd2 == true);
            }
        }
        return super.cancel(id);    //delete the offer.
    }

    //insert offer into the sorted list
    //keepers need to use this function
    function insert(
        uint id,   //maker (ask) id
        uint pos   //position to insert into
    )
    returns (bool)
    {
        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);
        bool xs1 = isOfferSorted(id);
        require(!xs1);    //make sure offers[id] is not yet sorted
        bool k = isActive(id);
        require(k == true);          //make sure offers[id] is active
        bool xs2 = isActive(pos);
        require(pos == 0 || xs2 == true);
        bool xs3 = _hide(id);
        require(xs3 == true);             //remove offer from unsorted offers list
        _sort(id, pos);                 //put offer into the sorted offers list
        return true;
    }

    //returns true if token is succesfully added to whitelist
    //  Function is used to add a token pair to the whitelist
    //  All incoming offers are checked against the whitelist.
    function addTokenPairWhitelist(
        ERC20 baseToken,
        ERC20 quoteToken
    )
    public
    auth
    note
    returns (bool)
    {   
        bool df1 = isTokenPairWhitelisted(baseToken, quoteToken);
        require(!df1);
        address bt1 = address(baseToken);
        address bt2 = address(quoteToken);
        require(bt1 != 0x0 && bt2 != 0x0);

        _menu[sha3(baseToken, quoteToken)] = true;
        LogAddTokenPairWhitelist(baseToken, quoteToken);
        return true;
    }

    //returns true if token is successfully removed from whitelist
    //  Function is used to remove a token pair from the whitelist.
    //  All incoming offers are checked against the whitelist.
    function remTokenPairWhitelist(
        ERC20 baseToken,
        ERC20 quoteToken
    )
    public
    auth
    note
    returns (bool)
    {
        isTokenPairWhitelisted(baseToken, quoteToken);

        delete _menu[sha3(baseToken, quoteToken)];
        delete _menu[sha3(quoteToken, baseToken)];
        LogRemTokenPairWhitelist(baseToken, quoteToken);
        return true;
    }

    function isTokenPairWhitelisted(
        ERC20 baseToken,
        ERC20 quoteToken
    )
    public
    constant
    returns (bool)
    {
        return (_menu[sha3(baseToken, quoteToken)] == true || _menu[sha3(quoteToken, baseToken)] == true);
    }

    //set the minimum sell amount for a token
    //    Function is used to avoid "dust offers" that have
    //    very small amount of tokens to sell, and it would
    //    cost more gas to accept the offer, than the value
    //    of tokens received.
    function setMinSell(
        ERC20 pay_gem,     //token to assign minimum sell amount to
        uint dust          //maker (ask) minimum sell amount
    )
    auth
    note
    returns (bool)
    {
        _dust[pay_gem] = dust;
        LogMinSell(pay_gem, dust);
        return true;
    }

    //returns the minimum sell amount for an offer
    function getMinSell(
        ERC20 pay_gem      //token for which minimum sell amount is queried
    )
    constant
    returns (uint) {
        return _dust[pay_gem];
    }

    //set buy functionality enabled/disabled
    function setBuyEnabled(bool buyEnabled_) auth  returns (bool) {
        buyEnabled = buyEnabled_;
        LogBuyEnabled(buyEnabled);
        return true;
    }

    //set matching enabled/disabled
    //    If matchingEnabled true(default), then inserted offers are matched.
    //    Except the ones inserted by contracts, because those end up
    //    in the unsorted list of offers, that must be later sorted by
    //    keepers using insert().
    //    If matchingEnabled is false then MatchingMarket is reverted to ExpiringMarket,
    //    and matching is not done, and sorted lists are disabled.
    function setMatchingEnabled(bool matchingEnabled_) auth  returns (bool) {
        matchingEnabled = matchingEnabled_;
        LogMatchingEnabled(matchingEnabled);
        return true;
    }

    //return the best offer for a token pair
    //      the best offer is the lowest one if it&#39;s an ask,
    //      and highest one if it&#39;s a bid offer
    function getBestOffer(ERC20 sell_gem, ERC20 buy_gem) constant returns(uint) {
        return _best[sell_gem][buy_gem];
    }

    //return the next worse offer in the sorted list
    //      the worse offer is the higher one if its an ask,
    //      and lower one if its a bid offer
    function getWorseOffer(uint id) constant returns(uint) {
        return _rank[id].prev;
    }

    //return the next better offer in the sorted list
    //      the better offer is in the lower priced one if its an ask,
    //      and next higher priced one if its a bid offer
    function getBetterOffer(uint id) constant returns(uint) {
        return _rank[id].next;
    }

    //return the amount of better offers for a token pair
    function getOfferCount(ERC20 sell_gem, ERC20 buy_gem) constant returns(uint) {
        return _span[sell_gem][buy_gem];
    }

    //get the first unsorted offer that was inserted by a contract
    //      Contracts can&#39;t calculate the insertion position of their offer because it is not an O(1) operation.
    //      Their offers get put in the unsorted list of offers.
    //      Keepers can calculate the insertion position offchain and pass it to the insert() function to insert
    //      the unsorted offer into the sorted list. Unsorted offers will not be matched, but can be bought with buy().
    function getFirstUnsortedOffer() constant returns(uint) {
        return _head;
    }

    //get the next unsorted offer
    //      Can be used to cycle through all the unsorted offers.
    function getNextUnsortedOffer(uint id) constant returns(uint) {
        return _near[id];
    }

    function isOfferSorted(uint id) constant returns(bool p) {
        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);
        p = (_rank[id].next != 0 || _rank[id].prev != 0 || _best[pay_gem][buy_gem] == id) ? true : false;
        return p;
    }


    // ---- Internal Functions ---- //


    function _buys(uint id, uint amount)
    internal
    returns (bool)
    {
        require(buyEnabled == true);
        bool sxcd = isOfferSorted(id);
        if (amount == offers[id].pay_amt && sxcd == true) {
            //offers[id] must be removed from sorted list because all of it is bought
            _unsort(id);
        }
        super.buy(id, amount);
        return true;
    }

    //find the id of the next higher offer after offers[id]
    function _find(uint id)
    internal
    returns (uint)
    {
        require( id > 0 );

        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);
        uint top = _best[pay_gem][buy_gem];
        uint old_top = 0;

        // Find the larger-than-id order whose successor is less-than-id.
        bool k = _isLtOrEq(id, top);
        while (top != 0 && k == true) {
            old_top = top;
            top = _rank[top].prev;
            k = _isLtOrEq(id, top);
        }
        return old_top;
    }

    //return true if offers[low] priced less than or equal to offers[high]
    function _isLtOrEq(
        uint low,   //lower priced offer&#39;s id
        uint high   //higher priced offer&#39;s id
    )
    internal
    returns (bool p)
    {
        if((offers[low].buy_amt* offers[high].pay_amt)
          >= (offers[high].buy_amt* offers[low].pay_amt)){
            p = true;
          }
          else{
            p = false;
          }
          return p;
    }

    //these variables are global only because of solidity local variable limit

    //match offers with taker offer, and execute token transactions
    function _matcho(
        uint t_pay_amt,    //taker sell how much
        ERC20 t_pay_gem,   //taker sell which token
        uint t_buy_amt,    //taker buy how much
        ERC20 t_buy_gem,   //taker buy which token
        uint pos,          //position id
        bool rounding      //match "close enough" orders?
    )
    internal
    returns (uint id)
    {
        uint best_maker_id;    //highest maker id
        uint t_buy_amt_old;              //taker buy how much saved
        uint m_buy_amt;        //maker offer wants to buy this much token
        uint m_pay_amt;        //maker offer wants to sell this much token
        bool sd = isActive(pos);
        require(pos == 0
               || !sd
               || t_buy_gem == offers[pos].buy_gem
                  && t_pay_gem == offers[pos].pay_gem);

        // there is at least one offer stored for token pair
        while (_best[t_buy_gem][t_pay_gem] > 0) {
            best_maker_id = _best[t_buy_gem][t_pay_gem];
            m_buy_amt = offers[best_maker_id].buy_amt;
            m_pay_amt = offers[best_maker_id].pay_amt;

            // Ugly hack to work around rounding errors. Based on the idea that
            // the furthest the amounts can stray from their "true" values is 1.
            // Ergo the worst case has t_pay_amt and m_pay_amt at +1 away from
            // their "correct" values and m_buy_amt and t_buy_amt at -1.
            // Since (c - 1) * (d - 1) > (a + 1) * (b + 1) is equivalent to
            // c * d > a * b + a + b + c + d, we write...
            uint kj2 = (rounding == true? m_buy_amt + t_buy_amt + t_pay_amt + m_pay_amt : 0);
            if ((m_buy_amt* t_buy_amt) > (t_pay_amt* m_pay_amt) + kj2)
            {
                break;
            }
            // ^ The `rounding` parameter is a compromise borne of a couple days
            // of discussion.
            uint cv1 = min(m_pay_amt, t_buy_amt);
            buy(best_maker_id, cv1);
            t_buy_amt_old = t_buy_amt;
            t_buy_amt = sub(t_buy_amt, cv1);
            t_pay_amt = (t_buy_amt* t_pay_amt) / t_buy_amt_old;

            if (t_pay_amt == 0 || t_buy_amt == 0) {
                break;
            }
        }

        if (t_buy_amt > 0 && t_pay_amt > 0) {
            //new offer should be created
            id = super.offer(t_pay_amt, t_pay_gem, t_buy_amt, t_buy_gem);
            //insert offer into the sorted list
            _sort(id, pos);
        }
    }

    // Make a new offer without putting it in the sorted list.
    // Takes funds from the caller into market escrow.
    // ****Available to authorized contracts only!**********
    // Keepers should call insert(id,pos) to put offer in the sorted list.
    function _offeru(
        uint pay_amt,      //maker (ask) sell how much
        ERC20 pay_gem,     //maker (ask) sell which token
        uint buy_amt,      //maker (ask) buy how much
        ERC20 buy_gem      //maker (ask) buy which token
    )
    internal
    /*NOT synchronized!!! */
    returns (uint id)
    {
        id = super.offer(pay_amt, pay_gem, buy_amt, buy_gem);
        _near[id] = _head;
        _head = id;
        LogUnsortedOffer(id);
    }

    //put offer into the sorted list
    function _sort(
        uint id,    //maker (ask) id
        uint pos    //position to insert into
    )
    internal
    {
        bool k = isActive(id);
        require(k == true);

        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);
        uint prev_id; //maker (ask) id
        bool k1 = isActive(pos);
        bool k2 = _isLtOrEq(id, pos);
        bool k3 = _isLtOrEq(id, _rank[pos].prev);
        if (pos == 0
            || !k1
            || !k2
            || (_rank[pos].prev != 0 && k3 == true)
        ) {
            //client did not provide valid position, so we have to find it
            pos = _find(id);
        }

        //require `pos` is in the sorted list or is 0
        require(pos == 0 || _rank[pos].next != 0 || _rank[pos].prev != 0 || _best[pay_gem][buy_gem] == pos);

        if (pos != 0) {
            //offers[id] is not the highest offer
            _isLtOrEq(id, pos);
            prev_id = _rank[pos].prev;
            _rank[pos].prev = id;
            _rank[id].next = pos;

        } else {
            //offers[id] is the highest offer
            prev_id = _best[pay_gem][buy_gem];
            _best[pay_gem][buy_gem] = id;
        }

        require(prev_id == 0 || offers[prev_id].pay_gem == offers[id].pay_gem);
        require(prev_id == 0 || offers[prev_id].buy_gem == offers[id].buy_gem);

        if (prev_id != 0) {
            //if lower offer does exist
            bool k31 = _isLtOrEq(id, pos);
            require(!k31);
            _rank[prev_id].next = id;
            _rank[id].prev = prev_id;
        }

        _span[pay_gem][buy_gem]++;
        LogSortedOffer(id);
    }

    // Remove offer from the sorted list (does not cancel offer)
    function _unsort(
        uint id    //id of maker (ask) offer to remove from sorted list
    )
    internal
    returns (bool)
    {
        address buy_gem = address(offers[id].buy_gem);
        address pay_gem = address(offers[id].pay_gem);
        require(_span[pay_gem][buy_gem] > 0);

        //require id is in the sorted list
        require(_rank[id].next != 0 || _rank[id].prev != 0 || _best[pay_gem][buy_gem] == id);

        if (id != _best[pay_gem][buy_gem]) {
            // offers[id] is not the highest offer
            _rank[_rank[id].next].prev = _rank[id].prev;

        } else {
            //offers[id] is the highest offer
            _best[pay_gem][buy_gem] = _rank[id].prev;
        }

        if (_rank[id].prev != 0) {
            //offers[id] is not the lowest offer
            _rank[_rank[id].prev].next = _rank[id].next;
        }

        _span[pay_gem][buy_gem]--;
        delete _rank[id];
        return true;
    }
    //Hide offer from the unsorted order book (does not cancel offer)
    function _hide(
        uint id     //id of maker offer to remove from unsorted list
    )
    internal
    returns (bool)
    {
        uint uid = _head;               //id of an offer in unsorted offers list 
        uint pre = uid;                 //id of previous offer in unsorted offers list

        bool xs1 = isOfferSorted(id);
        require(!xs1);   //make sure offer id is not in sorted offers list

        if (_head == id) {              //check if offer is first offer in unsorted offers list
            _head = _near[id];          //set head to new first unsorted offer
            _near[id] = 0;              //delete order from unsorted order list
            return true;
        }
        while (uid > 0 && uid != id) {  //find offer in unsorted order list
            pre = uid;
            uid = _near[uid];
        }
        if (uid != id) {                //did not find offer id in unsorted offers list
            return false;
        }
        _near[pre] = _near[id];         //set previous unsorted offer to point to offer after offer id
        _near[id] = 0;                  //delete order from unsorted order list
        return true;
    }
}
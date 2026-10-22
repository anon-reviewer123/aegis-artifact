/**
 *Submitted for verification at Etherscan.io on 2018-07-19
*/

pragma solidity ^0.4.24;
contract DSNote {
    event LogNote(
        bytes4   indexed  sig,
        address  indexed  guy,
        bytes32  indexed  foo,
        bytes32  indexed  bar,
	    uint	 	      wad,
        bytes             fax
    ) anonymous;

    modifier note {
        bytes32 foo;
        bytes32 bar;

        assembly {
            foo := calldataload(4)
            bar := calldataload(36)
        }

        emit LogNote(msg.sig, msg.sender, foo, bar, msg.value, msg.data);

        _;
    }
}

contract ERC20 {
    function totalSupply() public view returns (uint supply);
    function balanceOf( address who ) public view returns (uint value);
    function allowance( address owner, address spender ) public view returns (uint _allowance);

    function transfer( address to, uint value) public returns (bool ok);
    function transferFrom( address from, address to, uint value) public returns (bool ok);
    function approve( address spender, uint value ) public returns (bool ok);

    event Transfer( address indexed from, address indexed to, uint value);
    event Approval( address indexed owner, address indexed spender, uint value);
}

contract DSAuthority {
    function canCall(
        address src, address dst, bytes4 sig
    ) public constant returns (bool);
}

contract DSAuthEvents {
    event LogSetAuthority (address indexed authority);
    event LogSetOwner     (address indexed owner);
}

contract DSAuth is DSAuthEvents {
    DSAuthority  public  authority;
    address      public  owner;

    constructor() public{
        owner = msg.sender;
        emit LogSetOwner(msg.sender);
    }

    function setOwner(address owner_) public auth
    {
        address zero = address(0);
        require(owner_ != zero);
        owner = owner_;
        emit LogSetOwner(owner);
    }

    function setAuthority(DSAuthority authority_) public auth
    {
        authority = authority_;
        emit LogSetAuthority(authority);
    }

    modifier auth {
        bool k = isAuthorized(msg.sender, msg.sig);
        require(k == true);
        _;
    }

    modifier authorized(bytes4 sig) {
        bool k = isAuthorized(msg.sender, sig);
        require(k == true);
        _;
    }

    function isAuthorized(address src, bytes4 sig) internal view returns (bool p) {
        address tthisAddr = address(this);
        DSAuthority DSZero = DSAuthority(0);
        if (src == tthisAddr) {
            p = true;
        } else if (src == owner) {
            p = true;
        } else if (authority == DSZero) {
            p = false;
        } else {
            p = authority.canCall(src, this, sig);
        }
        return p;
    }
    
}

contract DSExec {
    function tryExec( address target, bytes calldata, uint value)
             internal
             returns (bool call_ret)
    {
        call_ret = target.call.value(value)(calldata);
        return call_ret;
    }
    function exec( address target, bytes calldata, uint value)
             internal
    {
        bool pa = tryExec(target, calldata, value);
        if(!pa) {
            require(true == false);
        }
    }

    // Convenience aliases
    function exec( address t, bytes c )
        internal
    {
        exec(t, c, 0);
    }
    function exec( address t, uint256 v )
        internal
    {
        bytes memory c; exec(t, c, v);
    }
    function tryExec( address t, bytes c )
        internal
        returns (bool p)
    {
        p = tryExec(t, c, 0);
        return p;
    }
    function tryExec( address t, uint256 v )
        internal
        returns (bool p)
    {
        bytes memory c; p = tryExec(t, c, v);
        return p;
    }
}

contract DSMath {
    
    /*
    standard uint256 functions
     */

    function add(uint256 x, uint256 y) pure internal returns (uint256 z) {
        z = x + y;
        require((z) >= x);
    }

    function sub(uint256 x, uint256 y) pure internal returns (uint256 z) {
        z = x - y;
        require((z) <= x);
    }

    function mul(uint256 x, uint256 y) pure internal returns (uint256 z) {
        z = x * y;
        require(y == 0 || (z) / y == x);
    }

    function div(uint256 x, uint256 y) pure internal returns (uint256 z) {
        z = x / y;
    }

    function min(uint256 x, uint256 y) pure internal returns (uint256 z) {
        z = x <= y ? x : y;
        return z;
    }
    function max(uint256 x, uint256 y) pure internal returns (uint256 z) {
        z = x >= y ? x : y;
        return z;
    }

    /*
    uint128 functions (h is for half)
     */


    function hadd(uint128 x, uint128 y) pure internal returns (uint128 z) {
        z = x + y;
        require((z) >= x);
    }

    function hsub(uint128 x, uint128 y) pure internal returns (uint128 z) {
        z = x - y;
        require((z) <= x);
    }

    function hmul(uint128 x, uint128 y) pure internal returns (uint128 z) {
        z = x * y;
        require(y == 0 || (z) / y == x);
    }

    function hdiv(uint128 x, uint128 y) pure internal returns (uint128 z) {
        z = x / y;
    }

    function hmin(uint128 x, uint128 y) pure internal returns (uint128 z) {
        z = x <= y ? x : y;
        return z;
    }
    function hmax(uint128 x, uint128 y) pure internal returns (uint128 z) {
        z = x >= y ? x : y;
        return z;
    }


    /*
    int256 functions
     */

    function imin(int256 x, int256 y) pure internal returns (int256 z) {
        z = x <= y ? x : y;
        return z;
    }
    function imax(int256 x, int256 y) pure internal returns (int256 z) {
        z = x >= y ? x : y;
        return z;
    }

    /*
    WAD math
     */

    uint128 constant WAD = 10 ** 18;

    function wadd(uint128 x, uint128 y) pure internal returns (uint128 z) {
        z = hadd(x, y);
        return z;
    }

    function wsub(uint128 x, uint128 y) pure internal returns (uint128 z) {
        z = hsub(x, y);
        return z;
    }

    function wmul(uint128 x, uint128 y) pure internal returns (uint128 z) {
        uint k5 = uint256(x);
        uint k3 = mul(k5, y);
        uint k4 = WAD/2;
        uint k2 = add(k3, k4);
        uint k1 = k2 / WAD;
        z = cast(k1);
        return z;
    }

    function wdiv(uint128 x, uint128 y) pure internal returns (uint128 z) {
        uint k5 = uint256(x);
        uint k3 = mul(k5, WAD);
        uint k4 = y/2;
        uint k2 = add(k3, k4);
        uint k1 = k2 / y;
        z = cast(k1);
        return z;
    }

    function wmin(uint128 x, uint128 y) pure internal returns (uint128 z) {
        z = hmin(x, y);
        return z;
    }
    function wmax(uint128 x, uint128 y) pure internal returns (uint128 z) {
        z = hmax(x, y);
        return z;
    }

    /*
    RAY math
     */

    uint128 constant RAY = 10 ** 27;

    function radd(uint128 x, uint128 y) pure internal returns (uint128 z) {
        z = hadd(x, y);
        return z;
    }

    function rsub(uint128 x, uint128 y) pure internal returns (uint128 z) {
        z = hsub(x, y);
        return z;
    }

    function rmul(uint128 x, uint128 y) pure internal returns (uint128 z) {
        uint k4 = uint256(x);
        uint k2 = mul(k4, y);
        uint k3 = RAY/2;
        uint k5 = add(k2, k3);
        uint k1 = k5 / RAY;
        z = cast(k1);
        return z;
    }

    function rdiv(uint128 x, uint128 y) pure internal returns (uint128 z) {
        uint k5 = uint256(x);
        uint k3 = mul(k5, RAY);
        uint k4 =  y/2;
        uint k2 = add(k3,k4);
        uint k1 = k2 / y;
        z = cast(k1);
        return z;
    }

    function rpow(uint128 x, uint64 n) pure internal returns (uint128 z) {
        // This famous algorithm is called "exponentiation by squaring"
        // and calculates x^n with x as fixed-point and n as regular unsigned.
        //
        // It's O(log n), instead of O(n) for naive repeated multiplication.
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

    function rmin(uint128 x, uint128 y) pure internal returns (uint128 z) {
        return hmin(x, y);
    }
    function rmax(uint128 x, uint128 y) pure internal returns (uint128 z) {
        return hmax(x, y);
    }

    function cast(uint256 x) pure internal returns (uint128 z) {
        z = uint128(x);
        require(z == x);
    }

}

contract DSStop is DSAuth, DSNote {

    bool public stopped;

    modifier stoppable {
        require (!stopped);
        _;
    }
    function stop() public auth note {
        stopped = true;
    }
    function start() public auth note {
        stopped = false;
    }

}

contract DSTokenBase is ERC20, DSMath {
    uint256                                            _supply;
    mapping (address => uint256)                       _balances;
    mapping (address => mapping (address => uint256))  _approvals;
    
    constructor(uint256 supply) public {
        _balances[msg.sender] = supply;
        _supply = supply;
    }
    
    function totalSupply() public view returns (uint256) {
        return _supply;
    }
    function balanceOf(address src) public view returns (uint256) {
        return _balances[src];
    }
    function allowance(address src, address guy) public view returns (uint256) {
        return _approvals[src][guy];
    }
    
    function transfer(address dst, uint wad) public returns (bool) {
        require(_balances[msg.sender] >= wad);
        
        _balances[msg.sender] = sub(_balances[msg.sender], wad);
        _balances[dst] = add(_balances[dst], wad);
        
        emit Transfer(msg.sender, dst, wad);
        
        return true;
    }
    
    function transferFrom(address src, address dst, uint wad) public returns (bool) {
        require(_balances[src] >= wad);
        require(_approvals[src][msg.sender] >= wad);
        
        _approvals[src][msg.sender] = sub(_approvals[src][msg.sender], wad);
        _balances[src] = sub(_balances[src], wad);
        _balances[dst] = add(_balances[dst], wad);
        
        emit Transfer(src, dst, wad);
        
        return true;
    }
    
    function approve(address guy, uint256 wad) public returns (bool) {
        _approvals[msg.sender][guy] = wad;
        
        emit Approval(msg.sender, guy, wad);
        
        return true;
    }

}


contract DSToken is DSTokenBase(0), DSStop {
    bytes32  public  symbol;
    bytes32  public  name;
    uint256  public  decimals = 18; // standard token precision. override to customize
    uint256  public  MAX_MINT_NUMBER = 1000*10**26;

    constructor(bytes32 symbol_, bytes32 name_) public {
        symbol = symbol_;
        name = name_;
    }

    function transfer(address dst, uint wad) public stoppable note returns (bool) {
        return super.transfer(dst, wad);
    }
    function transferFrom(
        address src, address dst, uint wad
    ) public stoppable note returns (bool) {
        return super.transferFrom(src, dst, wad);
    }
    function approve(address guy, uint wad) public stoppable note returns (bool) {
        return super.approve(guy, wad);
    }

    function push(address dst, uint128 wad) public returns (bool) {
        return transfer(dst, wad);
    }
    function pull(address src, uint128 wad) public returns (bool) {
        return transferFrom(src, msg.sender, wad);
    }

    function mint(uint128 wad) public auth stoppable note {
        uint kl = add(_supply, wad);
        require (kl <= MAX_MINT_NUMBER);
        _balances[msg.sender] = add(_balances[msg.sender], wad);
        _supply = kl;
    }
    function burn(uint128 wad) public auth stoppable note {
        _balances[msg.sender] = sub(_balances[msg.sender], wad);
        _supply = sub(_supply, wad);
    }
}

contract DSAuthList is DSAuth {
    mapping(address => bool) public whitelist;
    mapping(address => bool) public adminlist;

    modifier onlyIfWhitelisted
    {
        require(whitelist[msg.sender] == true);
        _;
    }

    modifier onlyIfAdmin
    {
        require(adminlist[msg.sender] == true);
        _;
    }

    function addAdminList(address[] addresses) public auth
    {
        for (uint256 i=0; i < addresses.length; i++)
        {
            adminlist[addresses[i]] = true;
        }
    }

    function removeAdminList(address[] addresses) public auth
    {
        for (uint256 i=0; i < addresses.length; i++)
        {
            adminlist[addresses[i]] = false;
        }
    }

    function addWhiteList(address[] addresses) public onlyIfAdmin
    {
        for (uint256 i=0; i < addresses.length; i++)
        {
            whitelist[addresses[i]] = true;
        }
    }

    function removeWhiteList(address[] addresses) public onlyIfAdmin
    {
        for (uint256 i=0; i < addresses.length; i++)
        {
            whitelist[addresses[i]] = false;
        }
    }
}

contract ONOSale is DSExec, DSMath, DSAuthList {
    DSToken  public  ONO;                  // The ONO token itself
    uint128  public  totalSupply;          // Total ONO amount created
    uint128  public  foundersAllocation;   // Amount given to founders
    string   public  foundersKey;          // Public key of founders

    uint     public  openTime;             // Time of window 0 opening
    uint     public  createFirstRound;       // Tokens sold in window 0

    uint     public  startTime;            // Time of window 1 opening
    uint     public  numberOfRounds;         // Number of windows after 0
    uint     public  createPerRound;         // Tokens sold in each window

    address  public  founderAddr = 0xF9BaaA91e617dF1dE6c2386b789B401c422E9AB1;
    address  public  burnAddr    = 0xA3Ad4EFDd5719eAed1B0F2e12c0D7368a6D11037;

    mapping (uint => uint)                       public  dailyTotals;
    mapping (uint => mapping (address => uint))  public  userBuys;
    mapping (uint => mapping (address => bool))  public  claimed;
    mapping (address => string)                  public  keys;

    mapping (uint => address[]) public userBuysArray;
    mapping (uint => bool) public burned; //In one round, If the getted eth insufficient, the remain token will be burned

    event LogBuy      (uint window, address user, uint amount);
    event LogClaim    (uint window, address user, uint amount);
    event LogMint     (address user, uint amount);
    event LogBurn     (uint window, address user, uint amount);
    event LogRegister (address user, string key);
    event LogCollect  (uint amount);

    constructor(
        uint     _numberOfRounds,
        uint128  _totalSupply,
        uint128  _firstRoundSupply,
        uint     _openTime,
        uint     _startTime,
        uint128  _foundersAllocation,
        string   _foundersKey
    ) public {
        numberOfRounds     = _numberOfRounds;
        totalSupply        = _totalSupply;
        openTime           = _openTime;
        startTime          = _startTime;
        foundersAllocation = _foundersAllocation;
        foundersKey        = _foundersKey;

        createFirstRound = _firstRoundSupply;
        createPerRound = div(
            sub(sub(totalSupply, foundersAllocation), createFirstRound),
            numberOfRounds
        );

        require(numberOfRounds > 0);
        require(totalSupply > foundersAllocation);
        require(openTime < startTime);
    }

    function initialize(DSToken ono) public auth {
        address zero = address(0);
        address ohno = address(ONO);
        require(ohno == zero);
        address pk1 = ono.owner();
        address tthisAddr = address(this);
        require(pk1 == tthisAddr);
        DSAuthority pk2 = ono.authority();
        DSAuthority DSzero = DSAuthority(0);
        require(pk2 == DSzero);
        uint pk3 = ono.totalSupply();
        require(pk3 == 0);

        ONO = ono;
        ONO.mint(totalSupply);

        ONO.push(founderAddr, foundersAllocation);
        keys[founderAddr] = foundersKey;

        emit LogRegister(founderAddr, foundersKey);
    }

    function time() public constant returns (uint) {
        return block.timestamp;
    }

    function currRound() public constant returns (uint p) {
        uint p1 = time();
        p = roundFor(p1);
        return p;
    }

    function roundFor(uint timestamp) public constant returns (uint p) {
        uint pl1 = sub(timestamp, startTime);
        p = timestamp < startTime
            ? 0
            : pl1 / 71 hours + 1;
            return p;
    }

    function createOnRound(uint round) public constant returns (uint p) {
        p = round == 0 ? createFirstRound : createPerRound;
        return p;
    }

    function () public payable {
        buy();
    }

    function claim(uint round) public {
        claimAddress(msg.sender, round);
    }

    function claimAll() public {
        uint pkq1 = currRound();
        for (uint i = 0; i < pkq1; i++) {
            claim(i);
            pkq1 = currRound();
        }
    }

    // Value should be a public key.  Read full key import policy.
    // Manually registering requires a base58
    // encoded using the STEEM, BTS, or ONO public key format.
    function register(string key) public {
        uint pkq1 = currRound();
        require(pkq1 <=  numberOfRounds + 1);
        // require(bytes(key).length <= 64);

        keys[msg.sender] = key;

        emit LogRegister(msg.sender, key);
    }
    uint len;
    function buy() public payable onlyIfWhitelisted{
        
        uint round = currRound();
        uint pkq4 = time();
        require(pkq4 >= openTime && round <= numberOfRounds);
        require(msg.value >= 1 ether);

        userBuys[round][msg.sender] = add(userBuys[round][msg.sender], msg.value);
        dailyTotals[round] = add(dailyTotals[round], msg.value);
        
        bool founded = false;
        for (uint i = 0; i < len; i++) {
            address target = userBuysArray[round][i];
            if (target == msg.sender) {
                founded = true;
                break;
            }
        }

        if (founded == false) {
            userBuysArray[round].push(msg.sender);
        }

        emit LogBuy(round, msg.sender, msg.value);
    }

    function claimAddresses(address[] addresses, uint round) public onlyIfAdmin {
        uint arrayLength = addresses.length;
        for (uint i=0; i < arrayLength; i++) {
            claimAddress(addresses[i], round);
        }
    }

    function claimAddress(address addr, uint round) public {
        uint pkq3 = currRound();
        require(pkq3 > round);

        if (claimed[round][addr] == true || dailyTotals[round] == 0) {
            return;
        }

        // This will have small rounding errors, but the token is
        // going to be truncated to 8 decimal places or less anyway
        // when launched on its own chain.

        uint128 dailyTotal = cast(dailyTotals[round]);
        uint128 userTotal  = cast(userBuys[round][addr]);
        uint pkq2 = createOnRound(round);
        uint128 pkq = cast(pkq2);
        uint128 price      = wdiv(pkq, dailyTotal);
        uint128 minPrice   = wdiv(600000, 1);//private sale price

        //cannot lower than private sale price
        if (price > minPrice) {
            price = minPrice;
        }
        uint128 reward     = wmul(price, userTotal);

        claimed[round][addr] = true;
        ONO.push(addr, reward);

        emit LogClaim(round, addr, reward);
    }

    function mint(uint128 deltaSupply) public auth {
        ONO.mint(deltaSupply);
        ONO.push(founderAddr, deltaSupply);

        emit LogMint(founderAddr, deltaSupply);
    }

    function burn(uint round) public onlyIfAdmin {
        uint plk2 = time();
        require(plk2 >= openTime && round <= numberOfRounds);
        uint plk = currRound();
        require (plk > round);
        require (burned[round] == false);
        
        uint128 dailyTotalEth = cast(dailyTotals[round]);
        uint pk4 = createOnRound(round);
        uint128 dailyTotalToken = cast(pk4);

        if (dailyTotalEth == 0) {
            burned[round] = true;
            ONO.push(burnAddr, dailyTotalToken);

            emit LogBurn(round, burnAddr, dailyTotalToken);
        }
        else {
            uint128 price      = wdiv(dailyTotalToken, dailyTotalEth);
            uint128 minPrice   = wdiv(600000, 1);//private sale price

            if (price > minPrice) {
                price = minPrice;

                uint128 totalReward = wmul(price, dailyTotalEth);
                require(dailyTotalToken > totalReward);

                burned[round] = true;
                // ONO.push(burnAddr, wsub(dailyTotalToken, totalReward));
                emit LogBurn(round, burnAddr, wsub(dailyTotalToken, totalReward));
            } else {
                burned[round] = true;
            }
        }
    }

    // Crowdsale owners can collect ETH any number of times
    function collect() public auth {
        uint pk1 = currRound();
        require(pk1 > 0); // Prevent recycling during window 0
        address tthis = address(this);
        exec(msg.sender, tthis.balance);
        emit LogCollect(address(this).balance);
    }

    function start() public auth {
        ONO.start();
    }

    function stop() public auth {
        ONO.stop();
    }
}
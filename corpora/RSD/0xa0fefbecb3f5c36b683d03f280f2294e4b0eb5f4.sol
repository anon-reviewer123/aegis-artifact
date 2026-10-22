/*   
 *    Exodus adaptation of OasisDirectProxy by MakerDAO.
 *    Edited by Konnor Klashinsky (kklash).
 *    Work in progress; Second Mainnet iteration.
 */
pragma solidity 0.4.26;


contract DSMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
        require((z ) >= x);
        return z;
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        z = x - y;
        require((z) <= x);
        return z;
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        z = x * y;
        require(y == 0 || (z) / y == x);
        return z;
    }
    function min(uint x, uint y) internal pure returns (uint z) {
        z =  x <= y ? x : y;
        return z;
    }
    function max(uint x, uint y) internal pure returns (uint z) {
        z = x >= y ? x : y;
        return z;
    }
    function imin(int x, int y) internal pure returns (int z) {
        z = x <= y ? x : y;
        return z;
    }
    function imax(int x, int y) internal pure returns (int z) {
        z = x >= y ? x : y;
        return z;
    }

    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;

    function wmul(uint x, uint y) internal pure returns (uint z) {
        uint pl1 = mul(x, y);
        uint pl2 = WAD / 2;
        uint pl3 = add(pl1, pl2);
        z = pl3 / WAD;
        return z;
    }
    function rmul(uint x, uint y) internal pure returns (uint z) {
        uint pl1 = mul(x, y);
        uint pl2 = RAY / 2;
        uint pl3 = add(pl1, pl2);
        z = pl3 / RAY;
        return z;
    }
    function wdiv(uint x, uint y) internal pure returns (uint z) {
        uint pl1 = mul(x, WAD);
        uint pl2 = y / 2;
        uint pl3 = add(pl1, pl2);
        z = pl3 / y;
        return z;
    }
    function rdiv(uint x, uint y) internal pure returns (uint z) {
        uint pl1 = mul(x, RAY);
        uint pl2 =  y / 2;
        uint pl3 = add(pl1,pl2);
        z = pl3 / y;
        return z;
    }

    function rpow(uint x, uint n) internal pure returns (uint z) {
        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rmul(x, x);

            if (n % 2 != 0) {
                z = rmul(z, x);
            }
        }
    }
}


contract DSAuthority {
    function canCall(
        address src, address dst, bytes4 sig
    ) public view returns (bool);
}

contract DSAuthEvents {
    event LogSetAuthority (address indexed authority);
    event LogSetOwner     (address indexed owner);
}

contract DSAuth is DSAuthEvents {
    DSAuthority  public  authority;
    address      public  owner;

    constructor() public {
        owner = msg.sender;
        emit LogSetOwner(msg.sender);
    }

    function setOwner(address owner_)
        public
        auth
    {
        owner = owner_;
        emit LogSetOwner(owner);
    }

    function setAuthority(DSAuthority authority_)
        public
        auth
    {
        authority = authority_;
        emit LogSetAuthority(authority);
    }

    modifier auth {
        bool sw = isAuthorized(msg.sender, msg.sig);
        require(sw == true);
        _;
    }

    function isAuthorized(address src, bytes4 sig) internal view returns (bool p) {
        DSAuthority kl = DSAuthority(0);
        if (src == address(this)) {
            p = true;
        } else if (src == owner) {
            p = true;
        } else if (authority == kl) {
            p = false;
        } else {
            p = authority.canCall(src, this, sig);
        }
        return p;
    }
}

contract OtcInterface {
    function sellAllAmount(address, uint, address, uint) public returns (uint);
    function buyAllAmount(address, uint, address, uint) public returns (uint);
    function getPayAmount(address, address, uint) public constant returns (uint);
}


contract TokenInterface {
    function balanceOf(address) public returns (uint);
    function allowance(address, address) public returns (uint);
    function approve(address, uint) public;
    function transfer(address,uint) public returns (bool);
    function transferFrom(address, address, uint) public returns (bool);
    function deposit() public payable;
    function withdraw(uint) public;
}

contract Mortal is DSAuth {
    function kill() public auth {
        selfdestruct(owner);
    }
}

contract OasisDirectProxy is Mortal, DSMath {
    uint feePercentageWad;
    
    constructor() public {
        feePercentageWad = 0.01 ether; /* set initial fee to 1% */
    }

    function newFee(uint newFeePercentageWad) public auth {
        require(newFeePercentageWad <= 1 ether);
        feePercentageWad = newFeePercentageWad;
    }

    function takeFee(uint amt) public view returns (uint fee, uint remaining) {
       /* shave the fee off of an amount */
        fee = mul(amt, feePercentageWad) / WAD;
        remaining = sub(amt, fee);
    }
    
    function withdrawAndSend(TokenInterface wethToken, uint wethAmt) internal {
        wethToken.withdraw(wethAmt);
        bool p7 = msg.sender.call.value(wethAmt)();
        require(p7 == true);
    }
    
    /* 
     *   Public functions start here
     */
    
    function sellAllAmount(
        OtcInterface otc,
        TokenInterface payToken, 
        uint payAmt, 
        TokenInterface buyToken, 
        uint minBuyAmt
    ) public returns (uint) {
        require(payToken.transferFrom(msg.sender, this, payAmt));
        uint p6 = payToken.allowance(this, otc);
        if (p6 < payAmt) {
            uint minusone;
            payToken.approve(otc, minusone);
        }
        uint buyAmt = otc.sellAllAmount(payToken, payAmt, buyToken, minBuyAmt);
        (uint feeAmt, uint buyAmtRemainder) = takeFee(buyAmt);
        require(buyToken.transfer(owner, feeAmt)); /* fee is taken */
        require(buyToken.transfer(msg.sender, buyAmtRemainder));
        return buyAmtRemainder;
    }

    function sellAllAmountPayEth(
        OtcInterface otc,
        TokenInterface wethToken,
        TokenInterface buyToken,
        uint minBuyAmt
    ) public payable returns (uint) {
        wethToken.deposit();
        uint p5 = wethToken.allowance(this, otc);
        if (p5 < msg.value) {
            uint minusone;
            wethToken.approve(otc, minusone);
        }
        uint buyAmt = otc.sellAllAmount(wethToken, msg.value, buyToken, minBuyAmt);
        (uint feeAmt, uint buyAmtRemainder) = takeFee(buyAmt);
        require(buyToken.transfer(owner, feeAmt)); /* fee is taken */
        require(buyToken.transfer(msg.sender, buyAmtRemainder));
        return buyAmtRemainder;
    }

    function sellAllAmountBuyEth(
        OtcInterface otc,
        TokenInterface payToken, 
        uint payAmt, 
        TokenInterface wethToken, 
        uint minBuyAmt
    ) public returns (uint) {
        require(payToken.transferFrom(msg.sender, this, payAmt));
        uint p6 = payToken.allowance(this, otc);
        if (p6 < payAmt) {
            uint minusone;
            payToken.approve(otc, minusone);
        }
        uint wethAmt = otc.sellAllAmount(payToken, payAmt, wethToken, minBuyAmt);
        (uint feeAmt, uint wethAmtRemainder) = takeFee(wethAmt);
        require(wethToken.transfer(owner, feeAmt)); /* fee is taken in WETH */ 
        withdrawAndSend(wethToken, wethAmtRemainder);
        return wethAmtRemainder;
    }

    function buyAllAmount(
        OtcInterface otc, 
        TokenInterface buyToken, 
        uint buyAmt, 
        TokenInterface payToken, 
        uint maxPayAmt
    ) public returns (uint payAmt) {
        uint payAmtNow = otc.getPayAmount(payToken, buyToken, buyAmt);
        require(payAmtNow <= maxPayAmt);
        bool p10 = payToken.transferFrom(msg.sender, this, payAmtNow);
        require(p10 == true);
        uint p4 = payToken.allowance(this, otc);
        if (p4 < payAmtNow) {
            uint minusone;
            payToken.approve(otc, minusone);
        } 
        payAmt = otc.buyAllAmount(buyToken, buyAmt, payToken, payAmtNow);
        (uint feeAmt, uint buyAmtRemainder) = takeFee(min(buyAmt, buyToken.balanceOf(this)));
        require(buyToken.transfer(owner, feeAmt)); /* fee is taken */
        require(buyToken.transfer(msg.sender, buyAmtRemainder)); // To avoid rounding issues we check the minimum value
    }

    function buyAllAmountPayEth(
        OtcInterface otc, 
        TokenInterface buyToken, 
        uint buyAmt, 
        TokenInterface wethToken
    ) public payable returns (uint wethAmt) {
        // In this case user needs to send more ETH than a estimated value, then contract will send back the rest
        wethToken.deposit();
        uint p5 = wethToken.allowance(this, otc);
        if (p5 < msg.value) {
            uint minusone;
            wethToken.approve(otc, minusone);
        }
        wethAmt = otc.buyAllAmount(buyToken, buyAmt, wethToken, msg.value);
        (uint feeAmt, uint finalRemainder) = takeFee(min(buyAmt, buyToken.balanceOf(this))); 
        // To avoid rounding issues we check the minimum value
        require(buyToken.transfer(owner, feeAmt)); /* fee is taken */
        require(buyToken.transfer(msg.sender, finalRemainder)); 
        uint p1 = msg.value - wethAmt;
        withdrawAndSend(wethToken, p1);
    }

    function buyAllAmountBuyEth(
        OtcInterface otc, 
        TokenInterface wethToken, 
        uint wethAmt, 
        TokenInterface payToken, 
        uint maxPayAmt
    ) public returns (uint payAmt) {
        uint payAmtNow = otc.getPayAmount(payToken, wethToken, wethAmt);
        require(payAmtNow <= maxPayAmt);
        bool p10 = payToken.transferFrom(msg.sender, this, payAmtNow);
        require(p10 == true);
        uint p4 = payToken.allowance(this, otc);
        if (p4 < payAmtNow) {
            uint minusone;
            payToken.approve(otc, minusone);
        }
        payAmt = otc.buyAllAmount(wethToken, wethAmt, payToken, payAmtNow);
        (uint feeAmt, uint wethAmtRemainder) = takeFee(wethAmt);
        require(wethToken.transfer(owner, feeAmt));
        withdrawAndSend(wethToken, wethAmtRemainder);
    }

    function() public payable {} /* fallback function */
}
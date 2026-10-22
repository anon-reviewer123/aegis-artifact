pragma solidity 0.4.26;

/*   
 *    Exodus adaptation of OasisDirectProxy by MakerDAO.
 */

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

contract FeeInterface {
    function takeFee (uint amt, address token) public view returns (uint fee, uint remaining);
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

contract Mortal is DSAuth {
    function kill() public auth {
        selfdestruct(owner);
    }
    
    function withdrawTo(address _to) public auth {
    /* rescue all ETH */
        require(_to.call.value(address(this).balance)());
    }
    
    function withdrawTokenTo(TokenInterface token, address _to) public auth {
    /* rescue all of a token */
        require(token.transfer(_to, token.balanceOf(this)));
    }
}

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

contract OasisMonetizedProxy is Mortal, DSMath {
    FeeInterface fees;
    
    constructor(FeeInterface _fees) public {
        fees = _fees;
    }
    
    function setFeeAuthority(FeeInterface _fees) public auth {
      fees = _fees;
    }
    
    function unwrapAndSend(TokenInterface wethToken, address _to, uint wethAmt) internal {
        wethToken.withdraw(wethAmt);
        require(_to.call.value(wethAmt)()); 
  /* perform a call when sending ETH, in case the _to is a contract */
    }

    /*** Public functions start here ***/

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
        (uint feeAmt, uint buyAmtRemainder) = fees.takeFee(buyAmt, buyToken);
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
        (uint feeAmt, uint buyAmtRemainder) = fees.takeFee(buyAmt, buyToken);
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
        (uint feeAmt, uint wethAmtRemainder) = fees.takeFee(wethAmt, wethToken);
        unwrapAndSend(wethToken, owner, feeAmt); /* fee is taken in ETH */ 
        unwrapAndSend(wethToken, msg.sender, wethAmtRemainder);
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
        buyAmt = min(buyAmt, buyToken.balanceOf(this));
        /* To avoid rounding issues we check the minimum value */
        (uint feeAmt, uint buyAmtRemainder) = fees.takeFee(buyAmt, buyToken);
        require(buyToken.transfer(owner, feeAmt)); /* fee is taken */
        require(buyToken.transfer(msg.sender, buyAmtRemainder)); 
    }

    function buyAllAmountPayEth(
        OtcInterface otc, 
        TokenInterface buyToken, 
        uint buyAmt, 
        TokenInterface wethToken
    ) public payable returns (uint wethAmt) {
        /* In this case client needs to send more ETH than a estimated 
           value, then contract will send back the rest */
        wethToken.deposit();
        uint p5 = wethToken.allowance(this, otc);
        if (p5 < msg.value) {
            uint minusone;
            wethToken.approve(otc, minusone);
        }
        wethAmt = otc.buyAllAmount(buyToken, buyAmt, wethToken, msg.value);
        buyAmt = min(buyAmt, buyToken.balanceOf(this));
        /* To avoid rounding issues we check the minimum value */
        (uint feeAmt, uint buyAmtRemainder) = fees.takeFee(buyAmt, buyToken); 
        require(buyToken.transfer(owner, feeAmt)); /* fee is taken */
        require(buyToken.transfer(msg.sender, buyAmtRemainder)); 
        unwrapAndSend(wethToken, msg.sender, sub(msg.value, wethAmt)); /* return leftover eth */
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
        (uint feeAmt, uint wethAmtRemainder) = fees.takeFee(wethAmt, wethToken);
        unwrapAndSend(wethToken, owner, feeAmt);
        unwrapAndSend(wethToken, msg.sender, wethAmtRemainder);
    }

    function() public payable {
    /* fallback function. Revert ensures no ETH is sent to the contract by accident */
         require(true == false); 
    }
}
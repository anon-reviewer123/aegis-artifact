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
    //
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

contract OasisDirectProxy is DSMath {
    function withdrawAndSend(TokenInterface wethToken, uint wethAmt) internal {
        wethToken.withdraw(wethAmt);
        bool p7 = msg.sender.call.value(wethAmt)();
        require(p7 == true);
    }

    function sellAllAmount(OtcInterface otc, TokenInterface payToken, uint payAmt, TokenInterface buyToken, uint minBuyAmt) public returns (uint buyAmt) {
        require(payToken.transferFrom(msg.sender, this, payAmt));
        uint p6 = payToken.allowance(this, otc);
        if (p6 < payAmt) {
            uint minusone;
            payToken.approve(otc, minusone);
        }
        buyAmt = otc.sellAllAmount(payToken, payAmt, buyToken, minBuyAmt);
        bool p11 = buyToken.transfer(msg.sender, buyAmt);
        require(p11 == true);
    }

    function sellAllAmountPayEth(OtcInterface otc, TokenInterface wethToken, TokenInterface buyToken, uint minBuyAmt) public payable returns (uint buyAmt) {
        wethToken.deposit();
        uint p5 = wethToken.allowance(this, otc);
        if (p5 < msg.value) {
            uint minusone;
            wethToken.approve(otc, minusone);
        }
        buyAmt = otc.sellAllAmount(wethToken, msg.value, buyToken, minBuyAmt);
        bool p11 = buyToken.transfer(msg.sender, buyAmt);
        require(p11 == true);
    }

    function sellAllAmountBuyEth(OtcInterface otc, TokenInterface payToken, uint payAmt, TokenInterface wethToken, uint minBuyAmt) public returns (uint wethAmt) {
        require(payToken.transferFrom(msg.sender, this, payAmt));
        uint p6 = payToken.allowance(this, otc);
        if (p6 < payAmt) {
            uint minusone;
            payToken.approve(otc, minusone);
        }
        wethAmt = otc.sellAllAmount(payToken, payAmt, wethToken, minBuyAmt);
        withdrawAndSend(wethToken, wethAmt);
    }

    function buyAllAmount(OtcInterface otc, TokenInterface buyToken, uint buyAmt, TokenInterface payToken, uint maxPayAmt) public returns (uint payAmt) {
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
        uint p8 = buyToken.balanceOf(this);
        uint p7 = min(buyAmt, p8);
        bool p9 = buyToken.transfer(msg.sender, p7);
        require(p9 == true); // To avoid rounding issues we check the minimum value
    }

    function buyAllAmountPayEth(OtcInterface otc, TokenInterface buyToken, uint buyAmt, TokenInterface wethToken) public payable returns (uint wethAmt) {
        // In this case user needs to send more ETH than a estimated value, then contract will send back the rest
        wethToken.deposit();
        uint p5 = wethToken.allowance(this, otc);
        if (p5 < msg.value) {
            uint minusone;
            wethToken.approve(otc, minusone);
        }
        wethAmt = otc.buyAllAmount(buyToken, buyAmt, wethToken, msg.value);
        uint p8 = buyToken.balanceOf(this);
        uint p7 = min(buyAmt, p8);
        bool p9 = buyToken.transfer(msg.sender, p7);
        require(p9 == true); // To avoid rounding issues we check the minimum value
        uint p1 = msg.value - wethAmt;
        withdrawAndSend(wethToken, p1);
    }

    function buyAllAmountBuyEth(OtcInterface otc, TokenInterface wethToken, uint wethAmt, TokenInterface payToken, uint maxPayAmt) public returns (uint payAmt) {
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
        withdrawAndSend(wethToken, wethAmt);
    }

    function() public payable {}
}
/**
 *Submitted for verification at Etherscan.io on 2019-06-21
*/

pragma solidity ^0.5.7;

interface RegistryInterface {
    function proxies(address) external view returns (address);
}

interface UserWalletInterface {
    function owner() external view returns (address);
}

interface TubInterface {
    function open() external returns (bytes32);
    function join(uint) external;
    function exit(uint) external;
    function lock(bytes32, uint) external;
    function free(bytes32, uint) external;
    function draw(bytes32, uint) external;
    function wipe(bytes32, uint) external;
    function give(bytes32, address) external;
    function shut(bytes32) external;
    function cups(bytes32) external view returns (address, uint, uint, uint);
    function gem() external view returns (ERC20Interface);
    function gov() external view returns (ERC20Interface);
    function skr() external view returns (ERC20Interface);
    function sai() external view returns (ERC20Interface);
    function ink(bytes32) external view returns (uint);
    function tab(bytes32) external returns (uint);
    function rap(bytes32) external returns (uint);
    function per() external view returns (uint);
    function pep() external view returns (PepInterface);
}

interface PepInterface {
    function peek() external returns (bytes32, bool);
}

interface ERC20Interface {
    function allowance(address x1, address x2) external view returns (uint x);
    function balanceOf(address x1) external view returns (uint x);
    function approve(address x1, uint x2) external;
    function transfer(address x1, uint x2) external returns (bool x);
    function transferFrom(address x1, address x2, uint x3) external returns (bool x);
    function deposit() external payable;
    function withdraw(uint x) external;
}

interface UniswapExchange {
    function getEthToTokenOutputPrice(uint256 tokensBought) external view returns (uint256 ethSold);
    function getTokenToEthOutputPrice(uint256 ethBought) external view returns (uint256 tokensSold);
    function tokenToTokenSwapOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address tokenAddr
        ) external returns (uint256  tokensSold);
}

interface CTokenInterface {
    function mint(uint mintAmount) external returns (uint); // For ERC20
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function exchangeRateCurrent() external returns (uint);
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function balanceOf(address) external view returns (uint);
}

interface CETHInterface {
    function mint() external payable; // For ETH
    function transfer(address, uint) external returns (bool);
}

interface CDAIInterface {
    function mint(uint mintAmount) external returns (uint); // For ERC20
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
}


contract DSMath {

    function add(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
        require((z) >= x, "math-not-safe");
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        z = x * y;
        require(y == 0 || (z) / y == x, "math-not-safe");
    }

    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;

    function rmul(uint x, uint y) internal pure returns (uint z) {
        uint pl2 = mul(x, y);
        uint pl3 = RAY / 2;
        uint pl1 = add(pl2, pl3);
        z = pl1 / RAY;
        return z;
    }

    function rdiv(uint x, uint y) internal pure returns (uint z) {
        uint pl2 = mul(x, RAY);
        uint pl3 = y / 2;
        uint pl1 = add(pl2 , pl3);
        z = pl1 / y;
        return z;
    }

    function wmul(uint x, uint y) pure internal returns (uint z) {
        uint k3 = mul(x, y);
        uint k4 = WAD/2;
        uint k2 = add(k3, k4);
        z = k2 / WAD;
        return z;
    }

    function wdiv(uint x, uint y) pure internal returns (uint z) {
        uint k3 = mul(x, WAD);
        uint k4 = y/2;
        uint k2 = add(k3, k4);
        z = k2 / y;
        return z;
    }

    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a, "SafeMath: subtraction overflow");
        c = a - b;
    }

}


contract Helper is DSMath {

    address public ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public daiAddr = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
    address public registry = 0x498b3BfaBE9F73db90D252bCD4Fa9548Cd0Fd981;
    address public sai = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;
    address public ume = 0x2C4Bd064b998838076fa341A83d007FC2FA50957; // Uniswap Maker Exchange
    address public ude = 0x09cabEC1eAd1c0Ba254B09efb3EE13841712bE14; // Uniswap DAI Exchange
    address public cEth = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    address public cDai = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC;

    address public feeOne = 0xd8db02A498E9AFbf4A32BC006DC1940495b4e592;
    address public feeTwo = 0xa7615CD307F323172331865181DC8b80a2834324;

    /**
     * @dev setting allowance to compound for the "user proxy" if required
     */
    function setApproval(address erc20, uint srcAmt, address to) internal {
        ERC20Interface erc20Contract = ERC20Interface(erc20);
        address tthisAddr = address(this);
        uint tokenAllowance = erc20Contract.allowance(tthisAddr, to);
        if (srcAmt > tokenAllowance) {
            erc20Contract.approve(to, 2**255);
        }
    }

    function setAllowance(ERC20Interface _token, address _spender) internal {
        address tthisAddr = address(this);
        uint xz1 = _token.allowance(tthisAddr, _spender);
        uint minusone;
        if (xz1 != minusone) {
            _token.approve(_spender, minusone);
        }
    }

}


contract CompoundResolver is Helper {

    /**
     * @dev Redeem ETH/ERC20 and mint Compound Tokens
     * @param tokenAmt Amount of token To Redeem
     */
    function redeemUnderlying(address cErc20, uint tokenAmt) internal {
        if (tokenAmt > 0) {
            uint xz1 = CTokenInterface(cErc20).redeemUnderlying(tokenAmt);
            require(xz1 == 0, "something went wrong");
        }
    }

    /**
     * @dev Deposit ETH/ERC20 and mint Compound Tokens
     */
    function mintCETH(uint ethAmt) internal {
        if (ethAmt > 0) {
            CETHInterface cToken = CETHInterface(cEth);
            cToken.mint.value(ethAmt)();
            uint exchangeRate = CTokenInterface(cEth).exchangeRateCurrent();
            uint cEthToReturn = wdiv(ethAmt, exchangeRate);
            uint xz2 = wmul(cEthToReturn, exchangeRate);
            cEthToReturn = xz2 <= ethAmt ? cEthToReturn : cEthToReturn - 1;
            cToken.transfer(msg.sender, cEthToReturn);
        }
    }

    /**
     * @dev Deposit ETH/ERC20 and mint Compound Tokens
     */
    function fetchCETH(uint ethAmt) internal {
        if (ethAmt > 0) {
            CTokenInterface cToken = CTokenInterface(cEth);
            uint exchangeRate = cToken.exchangeRateCurrent();
            uint cTokenAmt = wdiv(ethAmt, exchangeRate);
            uint xz1 = wmul(cTokenAmt, exchangeRate);
            cTokenAmt = xz1 <= ethAmt ? cTokenAmt : cTokenAmt - 1;
            ERC20Interface(cEth).transferFrom(msg.sender, address(this), cTokenAmt);
        }
    }

    /**
     * @dev If col/debt > user's balance/borrow. Then set max
     */
    function checkCompound(uint ethAmt, uint daiAmt) internal returns (uint ethCol, uint daiDebt) {
        CTokenInterface cEthContract = CTokenInterface(cEth);
        uint cEthBal = cEthContract.balanceOf(msg.sender);
        uint ethExchangeRate = cEthContract.exchangeRateCurrent();
        ethCol = wmul(cEthBal, ethExchangeRate);
        uint xz1 = wdiv(ethCol, ethExchangeRate);
        ethCol = xz1 <= cEthBal ? ethCol : ethCol - 1;
        ethCol = ethCol <= ethAmt ? ethCol : ethAmt; // Set Max if amount is greater than the Col user have

        daiDebt = CDAIInterface(cDai).borrowBalanceCurrent(msg.sender);
        daiDebt = daiDebt <= daiAmt ? daiDebt : daiAmt; // Set Max if amount is greater than the Debt user have
    }

}


contract MakerResolver is CompoundResolver {

    event LogOpen(uint cdpNum, address owner);
    event LogWipe(uint cdpNum, uint daiAmt, uint mkrFee, uint daiFee, address owner);

    function open() internal returns (uint p) {
        bytes32 cup = TubInterface(sai).open();
        // emit LogOpen(uint(cup), address(this));
        p = uint(cup);
        return p;
    }

    /**
     * @dev transfer CDP ownership
     */
    function give(uint cdpNum, address nextOwner) internal {
        bytes32 lk1 = bytes32(cdpNum);
        TubInterface(sai).give(lk1, nextOwner);
    }

    function wipe(uint cdpNum, uint _wad) internal returns (uint daiAmt) {
        if (_wad > 0) {
            TubInterface tub = TubInterface(sai);
            UniswapExchange daiEx = UniswapExchange(ude);
            UniswapExchange mkrEx = UniswapExchange(ume);
            ERC20Interface dai = tub.sai();
            ERC20Interface mkr = tub.gov();

            bytes32 cup = bytes32(cdpNum);

            (address lad,,,) = tub.cups(cup);
            // address tthisAddr = address(this);
            // require(lad == tthisAddr, "cup-not-owned");

            setAllowance(dai, sai);
            setAllowance(mkr, sai);
            setAllowance(dai, ude);

            (bytes32 val, bool ok) = tub.pep().peek();

            // MKR required for wipe = Stability fees accrued in Dai / MKRUSD value
            uint mkrFee = uint(val);
            uint xz4 = tub.rap(cup);
            mkrFee = _wad*xz4/mkrFee;
            xz4 = tub.tab(cup);
            mkrFee = mkrFee/xz4;
            xz4 = mkrEx.getEthToTokenOutputPrice(mkrFee);
            xz4 = daiEx.getTokenToEthOutputPrice(xz4);
            daiAmt = _wad + xz4;

            redeemUnderlying(cDai, daiAmt);

            if (ok == true && val != 0) {
                address mn = address(mkr);
                daiEx.tokenToTokenSwapOutput(
                    mkrFee,
                    daiAmt,
                    999000000000000000000,
                    1899063809, // 6th March 2030 GMT // no logic
                    mn
                );
            }

            // tub.wipe(cup, _wad);
        }
    }

    function free(uint cdpNum, uint jam) internal {
        if (jam > 0) {
            bytes32 cup = bytes32(cdpNum);
            address tubAddr = sai;

            TubInterface tub = TubInterface(tubAddr);
            ERC20Interface peth = tub.skr();
            ERC20Interface weth = tub.gem();
            uint pl2 = tub.per();
            uint ink = rdiv(jam, pl2);
            uint pl1 = rmul(ink, pl2);
            ink = pl1 <= jam ? ink : ink - 1;
            tub.free(cup, ink);

            setAllowance(peth, tubAddr);

            tub.exit(ink);
            address tthisAddr = address(this);
            uint freeJam = weth.balanceOf(tthisAddr); // withdraw possible previous stuck WETH as well
            weth.withdraw(freeJam);
        }
    }

    function lock(uint cdpNum, uint ethAmt) internal {
        if (ethAmt > 0) {
            bytes32 cup = bytes32(cdpNum);
            address tubAddr = sai;

            TubInterface tub = TubInterface(tubAddr);
            ERC20Interface weth = tub.gem();
            ERC20Interface peth = tub.skr();

            (address lad,,,) = tub.cups(cup);
            address tthisAddr = address(this);
            require(lad == tthisAddr, "cup-not-owned");

            weth.deposit.value(ethAmt)();
            uint pl4 = tub.per();
            uint ink = rdiv(ethAmt, pl4);
            uint pl3 = rmul(ink, pl4);
            ink = pl3 <= ethAmt ? ink : ink - 1;

            setAllowance(weth, tubAddr);
            tub.join(ink);

            setAllowance(peth, tubAddr);
            tub.lock(cup, ink);
        }
    }

    function draw(uint cdpNum, uint _wad) internal {
        bytes32 cup = bytes32(cdpNum);
        if (_wad > 0) {
            TubInterface tub = TubInterface(sai);

            tub.draw(cup, _wad);
        }
    }

    function checkCDP(bytes32 cup, uint ethAmt, uint daiAmt) internal returns (uint ethCol, uint daiDebt) {
        TubInterface tub = TubInterface(sai);
        uint pl1 = tub.ink(cup);
        uint pl2 = tub.per();
        ethCol = rmul(pl1, pl2); // get ETH col from PETH col
        daiDebt = tub.tab(cup);
        daiDebt = daiAmt < daiDebt ? daiAmt : daiDebt; // if DAI amount > max debt. Set max debt
        ethCol = ethAmt < ethCol ? ethAmt : ethCol; // if ETH amount > max Col. Set max col
    }

    function wipeAndFree(uint cdpNum, uint jam, uint _wad) internal returns (uint daiAmt) {
        daiAmt = wipe(cdpNum, _wad);
        free(cdpNum, jam);
    }

    function lockAndDraw(uint cdpNum, uint jam, uint _wad) internal {
        lock(cdpNum, jam);
        draw(cdpNum, _wad);
    }

}


contract BridgeResolver is MakerResolver {

    event LogMakerToCompound(uint cdpNum, uint ethAmt, uint daiAmt, uint fees, address owner);
    event LogCompoundToMaker(uint cdpNum, uint ethAmt, uint daiAmt, uint fees, address owner);

    /**
     * @dev initiated from user wallet to reimburse temporary DAI debt
     */
    function refillFunds(uint daiDebt) external {
        if (daiDebt > 0) {
            address tthisAddr = address(this);
            bool pk11 = ERC20Interface(daiAddr).transferFrom(msg.sender, tthisAddr, daiDebt);
            require(pk11 == true, "Contract Approved?");
            uint pk12 = CDAIInterface(cDai).mint(daiDebt);
            require(pk12 == 0);
        }
    }

    /**
     * @dev paying back users debt
     */
    function payUserDebt(uint daiDebt) internal {
        if (daiDebt > 0) {
            redeemUnderlying(cDai, daiDebt);
            uint pk10 = CDAIInterface(cDai).repayBorrowBehalf(msg.sender, daiDebt);
            require(pk10 == 0, "Enough DAI?");
        }
    }

}


contract LiquidityProvider is BridgeResolver {

    mapping (address => uint) public deposits; // amount of CDAI deposits
    uint public totalDeposits;

    /**
     * @dev Deposit DAI for liquidity
     */
    function depositDAI(uint amt) public {
        address pk9 = address(this);
        bool pk8 = ERC20Interface(daiAddr).transferFrom(msg.sender, pk9, amt);
        require(pk8 == true, "Nothing to deposit");
        CTokenInterface cToken = CTokenInterface(cDai);
        uint pk7 = cToken.mint(amt);
        require(pk7 == 0);
        uint exchangeRate = cToken.exchangeRateCurrent();
        uint cDaiAmt = wdiv(amt, exchangeRate);
        uint sd1 = wmul(cDaiAmt, exchangeRate);
        cDaiAmt = sd1 <= amt ? cDaiAmt : cDaiAmt - 1;
        deposits[msg.sender] += cDaiAmt;
        totalDeposits += cDaiAmt;
    }

    /**
     * @dev Withdraw DAI from liquidity
     */
    function withdrawDAI(uint amt) public {
        require(deposits[msg.sender] != 0, "Nothing to Withdraw");
        CTokenInterface cToken = CTokenInterface(cDai);
        uint exchangeRate = cToken.exchangeRateCurrent();
        uint withdrawAmt = wdiv(amt, exchangeRate);
        uint daiAmt = amt;
        if (withdrawAmt > deposits[msg.sender]) {
            withdrawAmt = deposits[msg.sender];
            daiAmt = wmul(withdrawAmt, exchangeRate);
        }
        uint pk6 = cToken.redeem(withdrawAmt);
        require(pk6 == 0, "something went wrong");
        bool pk5 = ERC20Interface(daiAddr).transfer(msg.sender, daiAmt);
        require(pk5 == true, "Dai Transfer failed");
        deposits[msg.sender] -= withdrawAmt;
        totalDeposits -= withdrawAmt;
    }

    /**
     * @dev Deposit CDAI for liquidity
     */
    function depositCDAI(uint amt) public {
        CTokenInterface cToken = CTokenInterface(cDai);
        address tthisAddr = address(this);
        bool pk4 = cToken.transferFrom(msg.sender, tthisAddr, amt);
        require(pk4 == true, "Nothing to deposit");
        deposits[msg.sender] += amt;
        // totalDeposits += amt;
    }

    /**
     * @dev Withdraw CDAI from liquidity
     */
    function withdrawCDAI(uint amt) public {
        require(deposits[msg.sender] != 0, "Nothing to Withdraw");
        uint withdrawAmt = amt;
        if (withdrawAmt > deposits[msg.sender]) {
            withdrawAmt = deposits[msg.sender];
        }
        bool pk3 = CTokenInterface(cDai).transfer(msg.sender, withdrawAmt);
        require(pk3 == true, "Dai Transfer failed");
        deposits[msg.sender] -= withdrawAmt;
        totalDeposits -= withdrawAmt;
    }

    /**
     * collecting fees generated overtime
     */
    function withdrawFeesInCDai(uint num) public {
        CTokenInterface cToken = CTokenInterface(cDai);
        address tthisAddr = address(this);
        uint cDaiBal = cToken.balanceOf(tthisAddr);
        uint withdrawAmt = sub(cDaiBal, totalDeposits);
        if (num == 0) {
            bool pk1 = cToken.transfer(feeOne, withdrawAmt);
            require(pk1 == true, "Dai Transfer failed");
        } else {
            bool pk2 = cToken.transfer(feeTwo, withdrawAmt);
            require(pk2 == true, "Dai Transfer failed");
        }
    }

}


contract Bridge is LiquidityProvider {

    /**
     * FOR SECURITY PURPOSE
     * checks if only InstaDApp contract wallets can access the bridge
     */
    modifier isUserWallet {
        address userAdd = UserWalletInterface(msg.sender).owner();
        address walletAdd = RegistryInterface(registry).proxies(userAdd);
        address zero = address(0);
        require(walletAdd != zero, "not-user-wallet");
        require(walletAdd == msg.sender, "not-wallet-owner");
        _;
    }

    /**
     * @dev MakerDAO to Compound
     */
    function makerToCompound(uint cdpId, uint ethCol, uint daiDebt) public payable isUserWallet returns (uint daiAmt) {
        uint ethAmt;
        bytes32 l1 = bytes32(cdpId);
        (ethAmt, daiAmt) = checkCDP(l1, ethCol, daiDebt);
        daiAmt = wipeAndFree(cdpId, ethAmt, daiAmt);
        uint fees = wmul(daiAmt, 2000000000000000);
        daiAmt = wmul(daiAmt, 1002000000000000000); // 0.2% fees
        mintCETH(ethAmt);
        give(cdpId, msg.sender);
        emit LogMakerToCompound(
            cdpId,
            ethAmt,
            daiAmt,
            fees,
            msg.sender
        );
    }

    /**
     * @dev Compound to MakerDAO
     */
    function compoundToMaker(uint cdpId, uint ethCol, uint daiDebt) public payable isUserWallet {
        (uint ethAmt, uint daiAmt) = checkCompound(ethCol, daiDebt);
        payUserDebt(daiAmt);
        fetchCETH(ethAmt);
        redeemUnderlying(cEth, ethAmt);
        uint l1 = open();
        uint cdpNum = cdpId > 0 ? cdpId : l1;
        uint fees = wmul(daiAmt, 2000000000000000);
        daiAmt = wmul(daiAmt, 1002000000000000000); // 0.2% fees
        lockAndDraw(cdpNum, ethAmt, daiAmt);
        if (daiAmt > 0) {
            uint l2 = CDAIInterface(cDai).mint(daiAmt);
            require(l2 == 0);
        }
        give(cdpNum, msg.sender);
        emit LogCompoundToMaker(
            cdpNum,
            ethAmt,
            daiAmt,
            fees,
            msg.sender
        );
    }

}


contract MakerCompoundBridge is Bridge {

    /**
     * @dev setting up all required token approvals
     */
    constructor() public {
        setApproval(daiAddr, 10**30, cDai);
        setApproval(cDai, 10**30, cDai);
        setApproval(cEth, 10**30, cEth);
    }

    function() external payable {}

}
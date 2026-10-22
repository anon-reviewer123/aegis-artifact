/**

 *Submitted for verification at Etherscan.io on 2019-03-07

*/



pragma solidity 0.4.26;



// File: contracts/ERC20Interface.sol



// https://github.com/ethereum/EIPs/issues/20

interface ERC20 {

    function totalSupply() public view returns (uint supply);

    function balanceOf(address _owner) public view returns (uint balance);

    function transfer(address _to, uint _value) public returns (bool success);

    function transferFrom(address _from, address _to, uint _value) public returns (bool success);

    function approve(address _spender, uint _value) public returns (bool success);

    function allowance(address _owner, address _spender) public view returns (uint remaining);

    function decimals() public view returns(uint digits);

    event Approval(address indexed _owner, address indexed _spender, uint _value);

}



// File: contracts/KyberReserveInterface.sol



/// @title Kyber Reserve contract

interface KyberReserveInterface {



    function trade(

        ERC20 srcToken,

        uint srcAmount,

        ERC20 destToken,

        address destAddress,

        uint conversionRate,

        bool validate

    )

        public

        payable

        returns(bool);



    function getConversionRate(ERC20 src, ERC20 dest, uint srcQty) public view returns(uint);

}



// File: contracts/Utils.sol



/// @title Kyber constants contract

contract Utils {



    ERC20 constant internal ETH_TOKEN_ADDRESS = ERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);

    uint  constant internal PRECISION = (10**18);

    uint  constant internal MAX_QTY   = (10**28); // 10B tokens

    uint  constant internal MAX_RATE  = (PRECISION * 10**6); // up to 1M tokens per ETH

    uint  constant internal MAX_DECIMALS = 18;

    uint  constant internal ETH_DECIMALS = 18;

    mapping(address=>uint) internal decimals;



    function setDecimals(ERC20 token) internal {

        if (token == ETH_TOKEN_ADDRESS) decimals[token] = ETH_DECIMALS;

        else decimals[token] = token.decimals();

    }



    function getDecimals(ERC20 token) internal view returns(uint p) {

        if (token == ETH_TOKEN_ADDRESS) p = ETH_DECIMALS; // save storage access

        else {uint tokenDecimals = decimals[token];

        // technically, there might be token with decimals 0

        // moreover, very possible that old tokens have decimals 0

        // these tokens will just have higher gas fees.

        if(tokenDecimals == 0) p = token.decimals();

        else

        p = tokenDecimals;
        }
        return p;

    }



    function calcDstQty(uint srcQty, uint srcDecimals, uint dstDecimals, uint rate) internal pure returns(uint p) {

        require(srcQty <= MAX_QTY);

        require(rate <= MAX_RATE);



        if (dstDecimals >= srcDecimals) {

            require((dstDecimals - srcDecimals) <= MAX_DECIMALS);

            p = (srcQty * rate * (10**(dstDecimals - srcDecimals))) / PRECISION;

        } else {

            require((srcDecimals - dstDecimals) <= MAX_DECIMALS);

            p = (srcQty * rate) / (PRECISION * (10**(srcDecimals - dstDecimals)));

        }
        return p;

    }



    function calcSrcQty(uint dstQty, uint srcDecimals, uint dstDecimals, uint rate) internal pure returns(uint) {

        require(dstQty <= MAX_QTY);

        require(rate <= MAX_RATE);

        

        //source quantity is rounded up. to avoid dest quantity being too low.

        uint numerator;

        uint denominator;

        if (srcDecimals >= dstDecimals) {

            require((srcDecimals - dstDecimals) <= MAX_DECIMALS);

            numerator = (PRECISION * dstQty * (10**(srcDecimals - dstDecimals)));

            denominator = rate;

        } else {

            require((dstDecimals - srcDecimals) <= MAX_DECIMALS);

            numerator = (PRECISION * dstQty);

            denominator = (rate * (10**(dstDecimals - srcDecimals)));

        }

        return (numerator + denominator - 1) / denominator; //avoid rounding down errors

    }

}



// File: contracts/Utils2.sol



contract Utils2 is Utils {



    /// @dev get the balance of a user.

    /// @param token The token type

    /// @return The balance

    function getBalance(ERC20 token, address user) public view returns(uint) {

        if (token == ETH_TOKEN_ADDRESS)

            return user.balance;

        else

            return token.balanceOf(user);

    }



    function getDecimalsSafe(ERC20 token) internal returns(uint) {



        if (decimals[token] == 0) {

            setDecimals(token);

        }



        return decimals[token];

    }



    function calcDestAmount(ERC20 src, ERC20 dest, uint srcAmount, uint rate) internal view returns(uint p) {
        uint p1 = getDecimals(src);
        uint p2 = getDecimals(dest);
        p = calcDstQty(srcAmount, p1, p2, rate);
        return p;

    }



    function calcSrcAmount(ERC20 src, ERC20 dest, uint destAmount, uint rate) internal view returns(uint p) {

        uint p1 = getDecimals(src);
        uint p2 = getDecimals(dest);
        p = calcDstQty(destAmount, p1, p2, rate);
        return p;

    }



    function calcRateFromQty(uint srcAmount, uint destAmount, uint srcDecimals, uint dstDecimals)

        internal pure returns(uint p)

    {

        require(srcAmount <= MAX_QTY);

        require(destAmount <= MAX_QTY);



        if (dstDecimals >= srcDecimals) {

            require((dstDecimals - srcDecimals) <= MAX_DECIMALS);

            p = (destAmount * PRECISION / ((10 ** (dstDecimals - srcDecimals)) * srcAmount));

        } else {

            require((srcDecimals - dstDecimals) <= MAX_DECIMALS);

            p = (destAmount * PRECISION * (10 ** (srcDecimals - dstDecimals)) / srcAmount);

        }
        return p;

    }

}



// File: contracts/PermissionGroups.sol



contract PermissionGroups {



    address public admin;

    address public pendingAdmin;

    mapping(address=>bool) internal operators;

    mapping(address=>bool) internal alerters;

    address[] internal operatorsGroup;

    address[] internal alertersGroup;

    uint constant internal MAX_GROUP_SIZE = 50;



    function PermissionGroups() public {

        admin = msg.sender;

    }



    modifier onlyAdmin() {

        require(msg.sender == admin);

        _;

    }



    modifier onlyOperator() {

        require(operators[msg.sender] == true);

        _;

    }



    modifier onlyAlerter() {

        require(alerters[msg.sender] == true);

        _;

    }



    function getOperators () external view returns(address[]) {

        return operatorsGroup;

    }



    function getAlerters () external view returns(address[]) {

        return alertersGroup;

    }



    event TransferAdminPending(address pendingAdmin);



    /**

     * @dev Allows the current admin to set the pendingAdmin address.

     * @param newAdmin The address to transfer ownership to.

     */
address zero;
    function transferAdmin(address newAdmin) public onlyAdmin {

        require(newAdmin != zero);

        TransferAdminPending(pendingAdmin);

        pendingAdmin = newAdmin;

    }



    /**

     * @dev Allows the current admin to set the admin in one tx. Useful initial deployment.

     * @param newAdmin The address to transfer ownership to.

     */

    function transferAdminQuickly(address newAdmin) public onlyAdmin {

        require(newAdmin != zero);

        TransferAdminPending(newAdmin);

        AdminClaimed(newAdmin, admin);

        admin = newAdmin;

    }



    event AdminClaimed( address newAdmin, address previousAdmin);



    /**

     * @dev Allows the pendingAdmin address to finalize the change admin process.

     */

    function claimAdmin() public {

        require(pendingAdmin == msg.sender);

        AdminClaimed(pendingAdmin, admin);

        admin = pendingAdmin;

        pendingAdmin = zero;

    }



    event AlerterAdded (address newAlerter, bool isAdd);



    function addAlerter(address newAlerter) public onlyAdmin {

        require(!alerters[newAlerter]); // prevent duplicates.

        require(alertersGroup.length < MAX_GROUP_SIZE);



        AlerterAdded(newAlerter, true);

        alerters[newAlerter] = true;

        alertersGroup.push(newAlerter);

    }



    function removeAlerter (address alerter) public onlyAdmin {

        require(alerters[alerter] == true);

        alerters[alerter] = false;



        for (uint i = 0; i < alertersGroup.length; ++i) {

            if (alertersGroup[i] == alerter) {

                alertersGroup[i] = alertersGroup[alertersGroup.length - 1];

                alertersGroup.length--;

                AlerterAdded(alerter, false);

                break;

            }

        }

    }



    event OperatorAdded(address newOperator, bool isAdd);



    function addOperator(address newOperator) public onlyAdmin {

        require(!operators[newOperator]); // prevent duplicates.

        require(operatorsGroup.length < MAX_GROUP_SIZE);



        OperatorAdded(newOperator, true);

        operators[newOperator] = true;

        operatorsGroup.push(newOperator);

    }



    function removeOperator (address operator) public onlyAdmin {

        require(operators[operator] == true);

        operators[operator] = false;



        for (uint i = 0; i < operatorsGroup.length; ++i) {

            if (operatorsGroup[i] == operator) {

                operatorsGroup[i] = operatorsGroup[operatorsGroup.length - 1];

                operatorsGroup.length -= 1;

                OperatorAdded(operator, false);

                break;

            }

        }

    }

}



// File: contracts/Withdrawable.sol



/**

 * @title Contracts that should be able to recover tokens or ethers

 * @author Ilan Doron

 * @dev This allows to recover any tokens or Ethers received in a contract.

 * This will prevent any accidental loss of tokens.

 */

contract Withdrawable is PermissionGroups {



    event TokenWithdraw(ERC20 token, uint amount, address sendTo);



    /**

     * @dev Withdraw all ERC20 compatible tokens

     * @param token ERC20 The address of the token contract

     */

    function withdrawToken(ERC20 token, uint amount, address sendTo) external onlyAdmin {

        bool pqrs = token.transfer(sendTo, amount);
        require(pqrs == true);

        TokenWithdraw(token, amount, sendTo);

    }



    event EtherWithdraw(uint amount, address sendTo);



    /**

     * @dev Withdraw Ethers

     */

    function withdrawEther(uint amount, address sendTo) external onlyAdmin {

        sendTo.transfer(amount);

        EtherWithdraw(amount, sendTo);

    }

}



// File: contracts/uniswap/KyberUniswapReserve.sol



interface UniswapExchange {

    function ethToTokenSwapInput(

        uint256 min_tokens,

        uint256 deadline

    )

        external

        payable

        returns (uint256  tokens_bought);



    function tokenToEthSwapInput(

        uint256 tokens_sold,

        uint256 min_eth,

        uint256 deadline

    )

        external

        returns (uint256  eth_bought);



    function getEthToTokenInputPrice(

        uint256 eth_sold

    )

        external

        view

        returns (uint256 tokens_bought);



    function getTokenToEthInputPrice(

        uint256 tokens_sold

    )

        external

        view

        returns (uint256 eth_bought);

}





interface UniswapFactory {

    function getExchange(address token) external view returns (address exchange);

}





/*

 * A reserve that connects to Uniswap.

 *

 * This reserve makes use of an internal inventory for locally filling orders

 * using the reserve's inventory when certain conditions are met.

 * Conditions are:

 * - After trading the inventory will remain within defined limits.

 * - Uniswap prices do not display internal arbitrage.

 * - Uniswap ask and bid prices meet minimum spread requirements.

 *

 * An additional premium may be added to the converted price for optional

 * promotions.

 */

contract KyberUniswapReserve is KyberReserveInterface, Withdrawable, Utils2 {

    // Parts per 10000

    uint public constant DEFAULT_FEE_BPS = 25;



    UniswapFactory public uniswapFactory;

    address public kyberNetwork;



    uint public feeBps = DEFAULT_FEE_BPS;



    // Uniswap exchange contract for every listed token

    // token -> exchange

    mapping (address => address) public tokenExchange;



    // Internal inventory balance limits

    // token -> limit

    mapping (address => uint) public internalInventoryMin;

    mapping (address => uint) public internalInventoryMax;



    // Minimum spread in BPS required for using internal inventory

    // token -> limit

    mapping (address => uint) public internalActivationMinSpreadBps;



    // Premium BPS added to internal price (making it better).

    // token -> limit

    mapping (address => uint) public internalPricePremiumBps;



    bool public tradeEnabled = true;



    /**

        Constructor

    */

    function KyberUniswapReserve(

        UniswapFactory _uniswapFactory,

        address _admin,

        address _kyberNetwork

    )

        public

    {

        require(address(_uniswapFactory) != 0);

        require(_admin != 0);

        require(_kyberNetwork != 0);



        uniswapFactory = _uniswapFactory;

        admin = _admin;

        kyberNetwork = _kyberNetwork;

    }



    function() public payable {

        // anyone can deposit ether

    }



    /**

        Returns dest quantity / source quantity.

    */

    function getConversionRate(

        ERC20 src,

        ERC20 dest,

        uint srcQty

    )

        public

        view

        returns(uint p)

    {

        // This makes the UNUSED warning go away.

        // blockNumber;


        bool pl = isValidTokens(src, dest);
        if (!pl) return 0;

        if (!tradeEnabled) return 0;

        if (srcQty == 0) return 0;



        ERC20 token;

        if (src == ETH_TOKEN_ADDRESS) {

            token = dest;

        } else if (dest == ETH_TOKEN_ADDRESS) {

            token = src;

        } else {

            // Should never arrive here - isValidTokens requires one side to be ETH

            require(true == false);

        }



        uint convertedQuantity;

        uint rateSrcDest;

        uint rateDestSrc;
        uint bn;
        (convertedQuantity, rateSrcDest) = calcUniswapConversion(src, dest, srcQty);

        (bn , rateDestSrc) = calcUniswapConversion(dest, src, convertedQuantity);



        uint quantityWithPremium = addPremium(token, convertedQuantity);


        bool ds = shouldUseInternalInventory(

            src, /* srcToken */

            srcQty, /* srcAmount */

            dest, /* destToken */

            quantityWithPremium, /* destAmount */

            rateSrcDest, /* rateSrcDest */

            rateDestSrc /* rateDestSrc */

        );
        if (ds == true) {

            // If using internal inventory add premium to converted quantity
            uint l1 = getDecimals(src);
            uint l2 = getDecimals(dest);

            p = calcRateFromQty(

                srcQty, /* srcAmount */

                quantityWithPremium, /* destAmount */

                l1, /* srcDecimals */

                l2 /* dstDecimals */

            );

        } else {

            // Use rate calculated from uniswap quantities after fees

            p = rateSrcDest;

        }
        return p;

    }



    event TradeExecute(

        address indexed sender,

        address src,

        uint srcAmount,

        address destToken,

        uint destAmount,

        address destAddress,

        bool useInternalInventory

    );



    /**

      conversionRate: expected conversion rate should be >= this value.

     */

     address tthisAddr;
uint zxas = 2 ** 255;
    function trade(

        ERC20 srcToken,

        uint srcAmount,

        ERC20 destToken,

        address destAddress,

        uint conversionRate,

        bool validate

    )

        public

        payable

        returns(bool)

    {

        require(tradeEnabled == true);

        require(msg.sender == kyberNetwork);
        isValidTokens(srcToken, destToken);
        



        if (validate == true) {

            require(conversionRate > 0);

            if (srcToken == ETH_TOKEN_ADDRESS)

                require(msg.value == srcAmount);

            else

                require(msg.value == 0);

        }



        // Making sure srcAmount has been transfered to the reserve.

        // If srcToken is ETH the value has already been transfered by calling

        // the function.

        if (srcToken != ETH_TOKEN_ADDRESS)

            srcToken.transferFrom(msg.sender, tthisAddr, srcAmount);



        uint expectedDestAmount = calcDestAmount(

            srcToken, /* src */

            destToken, /* dest */

            srcAmount, /* srcAmount */

            conversionRate /* rate */

        );



        uint rateDestSrc;
        uint destAmount;
        

        (destAmount, rateDestSrc) = calcUniswapConversion(

            destToken,

            srcToken,

            expectedDestAmount

        );

        bool useInternalInventory = shouldUseInternalInventory(

            srcToken, /* srcToken */

            0, /* srcAmount */

            destToken, /* destToken */

            expectedDestAmount, /* destAmount */

            conversionRate, /* rateSrcDest */

            rateDestSrc /* rateDestSrc */

        );



        

        UniswapExchange exchange;

        if (srcToken == ETH_TOKEN_ADDRESS) {

            if (!useInternalInventory) {

                // Deduct fees (in ETH) before converting

                uint quantity = deductFee(srcAmount);

                exchange = UniswapExchange(tokenExchange[address(destToken)]);

                destAmount = exchange.ethToTokenSwapInput(

                    1, /* min_tokens: uniswap requires it to be > 0 */

                    zxas /* deadline */

                );

                require(destAmount >= expectedDestAmount);

            }



            // Transfer user-expected dest amount

            destToken.transfer(destAddress, expectedDestAmount);

        } else {

            if (!useInternalInventory) {

                exchange = UniswapExchange(tokenExchange[address(srcToken)]);

                destAmount = exchange.tokenToEthSwapInput(

                    srcAmount,

                    1, /* min_eth: uniswap requires it to be > 0 */

                    zxas /* deadline */

                );

                // Deduct fees (in ETH) after converting

                destAmount = deductFee(destAmount);

                require(destAmount >= expectedDestAmount);

            }



            // Transfer user-expected dest amount

            destAddress.transfer(expectedDestAmount);

        }

        return true;

    }



    event FeeUpdated(

        uint bps

    );



    function setFee(

        uint bps

    )

        public

        onlyAdmin

    {

        require(bps <= 10000);



        feeBps = bps;



        FeeUpdated(bps);

    }



    event InternalActivationConfigUpdated(

        ERC20 token,

        uint minSpreadBps,

        uint premiumBps

    );



    function setInternalActivationConfig(

        ERC20 token,

        uint minSpreadBps,

        uint premiumBps

    )

        public

        onlyAdmin

    {

        require(tokenExchange[address(token)] != zero);

        require(minSpreadBps <= 1000); // min spread <= 10%

        require(premiumBps <= 500); // premium <= 5%



        internalActivationMinSpreadBps[address(token)] = minSpreadBps;

        internalPricePremiumBps[address(token)] = premiumBps;



        InternalActivationConfigUpdated(token, minSpreadBps, premiumBps);

    }



    event InternalInventoryLimitsUpdated(

        ERC20 token,

        uint minBalance,

        uint maxBalance

    );



    function setInternalInventoryLimits(

        ERC20 token,

        uint minBalance,

        uint maxBalance

    )

        public

        onlyOperator

    {

        require(tokenExchange[address(token)] != zero);



        internalInventoryMin[address(token)] = minBalance;

        internalInventoryMax[address(token)] = maxBalance;



        InternalInventoryLimitsUpdated(token, minBalance, maxBalance);

    }



    event TokenListed(

        ERC20 token,

        UniswapExchange exchange

    );



    function listToken(ERC20 token)

        public

        onlyAdmin

    {
        address k = address(token);
        require(k != 0);


        address j = uniswapFactory.getExchange(token);
        UniswapExchange uniswapExchange = UniswapExchange(

            j

        );

        tokenExchange[address(token)] = address(uniswapExchange);

        setDecimals(token);


        uint x = 2 ** 255;
        token.approve(uniswapExchange, x);



        // internal inventory disabled by default

        internalInventoryMin[address(token)] = 2 ** 255;

        internalInventoryMax[address(token)] = 0;

        internalActivationMinSpreadBps[address(token)] = 0;

        internalPricePremiumBps[address(token)] = 0;



        TokenListed(token, uniswapExchange);

    }



    event TokenDelisted(ERC20 token);



    function delistToken(ERC20 token)

        public

        onlyAdmin

    {

        require(tokenExchange[address(token)] != zero);



        delete tokenExchange[address(token)];

        delete internalInventoryMin[address(token)];

        delete internalInventoryMax[address(token)];

        delete internalActivationMinSpreadBps[address(token)];

        delete internalPricePremiumBps[address(token)];



        TokenDelisted(token);

    }



    function isValidTokens(

        ERC20 src,

        ERC20 dest

    )

        public

        view

        returns(bool p)

    {

        if (

            (

                src == ETH_TOKEN_ADDRESS &&

                tokenExchange[address(dest)] != zero

            ) ||

            (

                tokenExchange[address(src)] != zero &&

                dest == ETH_TOKEN_ADDRESS

            )

        ){
            p = true;
        }
        else{
            p = false;
        }
        return p;

    }



    event TradeEnabled(

        bool enable

    );



    function enableTrade()

        public

        onlyAdmin

        returns(bool)

    {

        tradeEnabled = true;

        TradeEnabled(true);

        return true;

    }



    function disableTrade()

        public

        onlyAlerter

        returns(bool)

    {

        tradeEnabled = false;

        TradeEnabled(false);

        return true;

    }



    event KyberNetworkSet(

        address kyberNetwork

    );



    function setKyberNetwork(

        address _kyberNetwork

    )

        public

        onlyAdmin

    {

        require(_kyberNetwork != 0);

        kyberNetwork = _kyberNetwork;

        KyberNetworkSet(kyberNetwork);

    }



    /*

     * Uses amounts and rates to check if the reserve's internal inventory can

     * be used directly.

     *

     * rateEthToToken and rateTokenToEth are in kyber rate format meaning

     * rate as numerator and 1e18 as denominator.

     */
    uint thisbalance;
    function shouldUseInternalInventory(

        ERC20 srcToken,

        uint srcAmount,

        ERC20 destToken,

        uint destAmount,

        uint rateSrcDest,

        uint rateDestSrc

    )

        public

        view

        returns(bool p)

    {

        require(srcAmount < MAX_QTY);

        require(destAmount < MAX_QTY);



        // Check for internal inventory balance limitations

        ERC20 token;

        uint rateEthToToken;

        uint rateTokenToEth;

        if (srcToken == ETH_TOKEN_ADDRESS) {

            token = destToken;

            uint tokenBalance = token.balanceOf(this);

            if (

                tokenBalance < destAmount ||

                tokenBalance - destAmount < internalInventoryMin[token]

            ) {

                return false;

            }

            rateEthToToken = rateSrcDest;

            // Normalize rate direction to enable comparison for checking spread

            // and arbitrage: from ETH / Token -> Token / ETH

            rateTokenToEth = 10 ** 36 / rateDestSrc;

        } else {

            token = srcToken;

            if (thisbalance < destAmount) return false;
            uint k = token.balanceOf(this);
            if (k + srcAmount > internalInventoryMax[token]) {

                return false;

            }

            rateEthToToken = rateDestSrc;

            // Normalize rate direction to enable comparison for checking spread

            // and arbitrage: from ETH / Token -> Token / ETH

            rateTokenToEth = 10 ** 36 / rateSrcDest;

        }



        // Check for arbitrage

        if (rateTokenToEth < rateEthToToken) return false;



        uint activationSpread = internalActivationMinSpreadBps[token];
        int pk = calculateSpreadBps(rateEthToToken, rateTokenToEth);
        uint spread = uint(pk);

        if(spread >= activationSpread){
            p = true;
        }
        else{
            p = false;
        }
        return p;

    }



    /*

     * Spread calculation is (ask - bid) / ((ask + bid) / 2).

     * We multiply by 10000 to get result in BPS.

     *

     * Note: if askRate > bidRate result will be negative indicating

     * internal arbitrage.

     */

    function calculateSpreadBps(

        uint _askRate,

        uint _bidRate

    )

        public

        pure

        returns(int p)

    {

        int askRate = int(_askRate);

        int bidRate = int(_bidRate);

        p = 10000 * 2 * (askRate - bidRate) / (askRate + bidRate);
        return p;

    }



    function deductFee(

        uint amount

    )

        public

        view

        returns(uint p)

    {

        p = amount * (10000 - feeBps) / 10000;
        return p;

    }



    function addPremium(

        ERC20 token,

        uint amount

    )

        public

        view

        returns(uint p)

    {

        require(amount <= MAX_QTY);

        p = amount * (10000 + internalPricePremiumBps[token]) / 10000;
        return p;

    }



    function calcUniswapConversion(

        ERC20 src,

        ERC20 dest,

        uint srcQty

    )

        internal

        view

        returns(uint destQty, uint rate)

    {

        UniswapExchange exchange;

        if (src == ETH_TOKEN_ADDRESS) {

            exchange = UniswapExchange(tokenExchange[address(dest)]);
            uint pl1 = deductFee(srcQty);
            destQty = exchange.getEthToTokenInputPrice(

                pl1

            );

        } else {

            exchange = UniswapExchange(tokenExchange[address(src)]);
            uint pl2 = exchange.getTokenToEthInputPrice(srcQty);
            destQty = deductFee(

                pl2

            );

        }


        uint p1 = getDecimals(src);
        uint p2 = getDecimals(dest);
        rate = calcRateFromQty(

            srcQty, /* srcAmount */

            destQty, /* destAmount */

            p1, /* srcDecimals */

            p2 /* dstDecimals */

        );

    }

}
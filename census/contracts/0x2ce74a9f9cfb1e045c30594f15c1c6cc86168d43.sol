// Copyright (c) [2023], [Qwantum Finance Labs]
// All rights reserved.
// SPDX-License-Identifier: No License (None)
pragma solidity ^0.8.0;

import "./DumperShieldToken.sol";
import "./Voting.sol";
//import "./Splitter.sol";

interface IRouter {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function factory() external pure returns (address);
}

interface IFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IPair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IGateway {
    function tokenReceived(address token, uint256 amount, uint256 payValue) external;
}

interface IMigrationRouter {
    function migrate(
        address user,
        address fromToken,
        uint256 fromPosition, 
        uint256 fromAmount, 
        address toToken
    ) external;
}

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "APPROVE_FAILED"); //APPROVE_FAILED
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED"); //TRANSFER_FAILED
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FROM_FAILED"); //TRANSFER_FROM_FAILED
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, "ETH_TRANSFER_FAILED"); //ETH_TRANSFER_FAILED
    }
}

abstract contract Ownable {
    address internal _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    error CallerIsNotOwner();

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
/*  we use proxy, so owner will be set in initialize() function
    constructor () {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }
*/
    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        if(owner() != msg.sender) revert CallerIsNotOwner(); //Ownable: caller is not the owner
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0)); //"Ownable: new owner is the zero address"
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}



contract DumperShieldFactory is Ownable, Voting {
    using TransferHelper for address;
    //using Splitter for Splitter.SplitterSet;

    enum OrderStatus {Completed, Created, Canceled, Restricted, BuyOrderCreated}
    address constant public NATIVE_COIN = address(1);
    address public WETH;
    address public DumperShieldTokenImplementation; // implementation contract for DumperShieldToken

    struct Order {
        address seller;
        address buyer;
        address tokenSell;  // token to sell
        uint256 sellAmount;  // how many token sell
        address wantToken;  // which token want to receive (address(0) for base coin (ETH, BNB))
        address router; // router where "wantToken" can be swapped to native coin (ETH, BNB)
        uint256 value;  // the value in native cion (ETH, BNB) want to receive
        OrderStatus status;     // 0 - completed, 1 - created, 2 - canceled; 3 -restricted
        uint16   position;  // position of token (buy or sell depends on order type)
    }

    Order[] public orders;

    // Unused now
    struct Limit {
        uint256 period; // period of time while calculate tokens demand
        uint256 limit;  // current limit amount. If limit == 0 than no limits
        uint256 spent;  // amount of token that was spent;
        uint256 endTime;  // timestamp when current period ends
        uint256 nextLimit; // limit for next period
        // if limit was spent by less than period * 50% (ie. 1 day * 50%) the limit *= 2
        // if during period was spend less than `percentage` (ie. spent < limit * 50%) the limit /= 2
    }

    struct Fees {   // Fees with 2 decimals (100 = 1%)
        uint16 maker;   // OTC maker
        uint16 taker;   // OTC taker
    }

    mapping(address => Limit) private Unused_limits;    // token => limit for sale // Unused now
    mapping(address => DumperShieldToken) public dumperShieldTokens;   // token address => DumperShieldToken contract address
    mapping(bytes32 => address) private _dumperShieldUsers;   // user with position => DumperShieldUser contract address
    mapping(address => address) private Unused_dsRouters;     // token => router // Unused now
    mapping(address => uint256) public dsUnlockDate;  // token => unlock date (unix timestamp in seconds)
    mapping(address => mapping(address => uint256)) public restrictedBalance;   // token => user => restricted balance
    mapping(address => uint /* Splitter.SplitterSet */) private Unused_tokensSale; // token => sale library // Unused now

    uint256 private _status;
    uint256 constant public totalPositions = 3; // 0 - main; 1,2 - sub positions, excluded from voting
    Fees public fees;
    address public feeReceiver;

    address public PDO;
    address public gateway; // gateway can buy arbitrary orders from OTC with optimistic tokens receive and then send payment
    uint256 private awaitPayment;  // amount of coin (BNB, ETH) await payment from gateway
    address public migrationRouter; 

    event CreateDumperShield(address indexed token, address router, address dumperShieldToken);
    event PaymentFromGateway(uint256 indexed channelId, address indexed token, uint256 value, uint256 soldValue);
    event CreateOrder(
        uint256 orderId, 
        address indexed seller, 
        address indexed buyer, 
        address indexed tokenSell,
        uint256 sellAmount,
        address wantToken,
        address router,
        uint256 value, 
        OrderStatus status,
        uint256 position
    );
    event CompleteOrder(uint256 indexed orderId);
    event ConfirmOrder(uint256 indexed orderId);
    event CancelOrder(uint256 indexed orderId);
    event PutOnSale(
        address indexed token,  // taken address that put on sale
        address indexed from,   // user address
        uint256 value,          // value of tokens that user put on sale
        uint256 valueA,         // total value of tokens that user has on sale
        uint256 valueB          // value of coin (BNB, ETH) transferred to user for sold tokens
    );
    event RemoveFromSale(address indexed token, address indexed from, uint256 valueA, uint256 valueB);
    event BuyOrder(uint256 indexed orderId, address indexed buyer, uint256 paymentAmount, uint256 receiveAmount);
    event DumperShieldUnlock(address indexed token, uint256 unlockDate);
    event DumperShieldTransfer(address indexed token, uint256 position, address indexed from, address indexed to, uint256 value);
    event Reimburse(address user, uint256 gasFee, uint256 fee);
    event CreateDumperShieldUserPosition(address user, address dsUserContract, uint256 position);

    // Errors
    error Reentrant();
    error OnlyDSToken();
    error TokenIsNotShielded();
    error TokenAlreadyShielded();
    error WrongLength();
    error WrongStatus();
    error WrongSender();
    error UserIsNotInDumperShield();
    error WrongValue();
    error LowBalance();
    error LowAmount();
    error TokenIsLocked();
    error TokenIsLockedInVoting();
    error WrongDate();
    error WrongRouter();
    error OutOfLimit(uint256 limit);
    error ERC1167CreateFailed();
    error WantToken(address token);
    error AwaitPayment(uint256 awaitAmount);

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        if(_status == 1) revert Reentrant(); //reentrant

        // Any calls to nonReentrant after this point will fail
        _status = 1;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = 2;
    }

    modifier reimburse() {
        uint256 txGas = gasleft();
        
        _;

        emit Reimburse(msg.sender, (txGas - gasleft()) * tx.gasprice, 0);        
    }

    // run only once from proxy
    function initialize(address newOwner, address newDumperShieldTokenImplementation, address _weth) external {
        require(newOwner != address(0) && _owner == address(0)); // run only once
        _owner = newOwner;
        emit OwnershipTransferred(address(0), msg.sender);
        //WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // Ethereum WETH
        //WETH = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270); // Poygon WMATIC (SushiSwap)
        //WETH = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c); // Main BSC net WBNB
        //WETH = address(0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd); // test BSC net WBNB
        WETH = _weth;
        DumperShieldTokenImplementation = newDumperShieldTokenImplementation;
        orders.push();  // order ID starts from 1. Zero order ID means - no order
        super.initialize();
    }

    function setWETH(address _WETH) external onlyOwner {
        require(_WETH != address(0));
        WETH = _WETH;
    }

    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        require(_feeReceiver != address(0));
        feeReceiver = _feeReceiver;
    }

    function setFees(uint16 maker, uint16 taker) external onlyOwner {
        require(maker < 10000 && taker < 10000); // fees must be less than 100%
        fees.maker = maker;
        fees.taker = taker;
    }

    // View functions
    // get user balances of token on the dumper shield for each position
    function balanceOf(address token, address user) public view returns (uint256[] memory balances) {
        balances = new uint256[](totalPositions);
        for (uint i = 0; i < totalPositions; i++) {
            address dsUser = getDSUser(user, i);
            if(dsUser != address(0))  //User is in dumper shield
                balances[i] = IERC20(token).balanceOf(dsUser);   
        }
    }

    // get user balance of token on position in the dumper shield
    function balanceOf(address token, address user, uint256 position) public view returns (uint256 amount) {
        address dsUser = getDSUser(user, position);
        if(dsUser == address(0)) return 0; //User is not in dumper shield
        amount = IERC20(token).balanceOf(dsUser);
    }

    // return DS user contract address
    function getDSUser(address user, uint256 position) public view returns (address dsUser) {
        bytes32 userPosition = bytes32((position << 248) + uint256(uint160(user)));  // calculate position index
        dsUser = _dumperShieldUsers[userPosition];
    }

    // create new DS user contract or return already existed
    function createDSUser(address user, uint256 position) internal returns (address dsUser) {
        bytes32 userPosition = bytes32((position << 248) + uint256(uint160(user)));  // calculate position index
        dsUser = _dumperShieldUsers[userPosition];
        if (dsUser == address(0)) {
            dsUser = address(new DumperShieldUser(user, address(this)));
            _dumperShieldUsers[userPosition] = dsUser;
        }
        emit CreateDumperShieldUserPosition(user, dsUser, position);
    }

// debug functions
/*
    function updateVars() external onlyOwner {

    }
    */
// end debug
/*
    // return estimate value of tokens A in tokens B
    function getQuote(address router, address tokenA, address tokenB, uint256 amountA) public view returns(uint256 amountB) {
        address factory = IRouter(router).factory();
        address pair = IFactory(factory).getPair(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IPair(pair).getReserves();
        (uint reserveA, uint reserveB) = tokenA < tokenB ? (reserve0, reserve1) : (reserve1, reserve0);
        amountB = amountA * reserveB / reserveA;
    }
*/
    // get total number of orders
    function getOrdersNumber() external view returns(uint256 number) {
        return orders.length;
    }

    // get order ID of last active sell order of seller
    // if seller address = address(0), then returns last Buy Tokens orders.
    function getLastSellOrder(address seller) external view returns(uint256[] memory)
    {
        uint256[] memory orderIDs = new uint256[](20);
        uint len = orders.length;
        uint min;
        uint index;
        if (len > 200) min = len - 200; // check last 200 orders
        while(len > min) {
            len--;
            Order storage o = orders[len];
            if ((o.status == OrderStatus.Restricted || o.status == OrderStatus.Created || o.status == OrderStatus.BuyOrderCreated) && o.seller == seller) {
                orderIDs[index] = len;
                index++;
                if (index == 20) break;
            }
        }
        return orderIDs; // No orders available
    }

    // get order ID of last active buy order of buyer
    function getLastBuyOrder(address buyer) external view returns(uint256[] memory)
    {
        uint256[] memory orderIDs = new uint256[](20);
        uint len = orders.length;
        uint min;
        uint index;
        if (len > 200) min = len - 200; // check last 200 orders
        while(len > min) {
            len--;
            Order storage o = orders[len];
            if ((o.status == OrderStatus.Restricted || o.status == OrderStatus.Created || o.status == OrderStatus.BuyOrderCreated) && o.buyer == buyer) {
                orderIDs[index] = len;
                index++;
                if (index == 20) break;
            }
        }
        return orderIDs; // No orders available
    }

    function setLock(address token, address user, uint256 time) external returns(bool) {
        if(msg.sender != address(dumperShieldTokens[token])) revert OnlyDSToken(); //onlyDSToken
        if (locked[token][user] < time) {
            locked[token][user] = time;
        }
        return true;
    }
    
    function getLock(address token, address user) external view returns(uint256) {
        return locked[token][user];
    }

    // exported functions
    // Deposit tokens to user's address into Dumper Shield. Should be called approve() before deposit.
    function deposit(
        address token,  // token contract address
        uint256 amount, // amount of tokens to deposit
        address user    // user address who receives token
    ) external returns (bool)
    {
        return depositPosition(token, amount, user, 0);
    }

    // exported functions
    // Deposit tokens to user's address into Dumper Shield in specific position. Should be called approve() before deposit.
    function depositPosition(
        address token,  // token contract address
        uint256 amount, // amount of tokens to deposit
        address user,   // user address who receives token
        uint256 position // position in queue (0, 1, 2)
    ) public returns (bool)
    {
        require(position < totalPositions); // limit of positions
        DumperShieldToken dsToken = dumperShieldTokens[token];
        if(address(dsToken) == address(0)) revert TokenIsNotShielded();   //Token is not shielded
        address dsUser = createDSUser(user, position); // dsUser != 0
        if (position == 0) dsToken.createDumperShieldUser(user, dsUser); // add user to dsToken (to apply in voting)
        token.safeTransferFrom(msg.sender, dsUser, amount);
        _updateBalanceAndTotal(token, user, position); // update data for voting
        return true;
    }

    /**
     * @dev transfer token for a specified address into Escrow contract
     * @param token The address of token to transfer to.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function transfer(address token, uint256 position, address to, uint256 value) external reimburse returns (bool ret) {
        //restrictedBalance[token][to] += value;     // transfer to restricted account
        _transfer(token, position, msg.sender, to, value);
        ret = true;
    }

    /**
     * @dev transfer token for a Batch of specified addresses into Escrow contract
     * @param token The address of token to transfer to.
     * @param to The addresses to transfer to.
     * @param value The amounts to be transferred.
     */
    function transferBatch(address token, uint256 position, address[] calldata to, uint256[] calldata value) external reimburse returns (bool ret) {
        if(to.length != value.length) revert WrongLength(); // wrong length

        for (uint i = 0; i < to.length; i++) {
            //restrictedBalance[token][to] += value;     // transfer to restricted account
            _transfer(token, position, msg.sender, to[i], value[i]);
        }
        ret = true;
    }

    // Sell tokens to other user (inside Escrow contract).
    function sellToken(
        address buyer,  // buyer address, can be address(0) if anybody can buy it (no specific buyer)
        address tokenSell,  // token to sell
        uint256 sellAmount,  // how many token sell
        address wantToken,  // which token want to receive (address(0) for base coin (ETH, BNB))
        address router, // router where "wantToken" can be swapped to native coin (ETH, BNB)
        uint256 value,  // the value in native cion (ETH, BNB) want to receive
        uint16 sellPosition // sell token position
    ) external reimburse {
        _createOrder(msg.sender, buyer, tokenSell, sellAmount, wantToken, router, value, sellPosition);
    }

    // Create buy tokens order from other users (inside Escrow contract).
    function buyToken(
        address wantToken,  // token to buy (under DS)
        uint256 wantTokenAmount,  // how many tokens to buy
        uint256 position    // position of wantToken
    ) external payable reimburse {
        _createOrder(address(0), msg.sender, address(0), msg.value, wantToken, address(0), wantTokenAmount, position);
    }


    // cancel sell order
    function cancelOrder(uint256 orderId) external reimburse {
        Order storage o = orders[orderId];
        if (msg.sender != o.seller && msg.sender != o.buyer) revert WrongSender(); //can't cancel
        if (o.status == OrderStatus.BuyOrderCreated) {
            o.status = OrderStatus.Canceled;    // cancel buy token order
            o.buyer.safeTransferETH(o.sellAmount);
        } else {
            if (o.status != OrderStatus.Created && o.status != OrderStatus.Restricted) revert WrongStatus(); // user can cancel restricted order too.
            if (o.status == OrderStatus.Restricted) restrictedBalance[o.tokenSell][o.seller] += o.sellAmount;    // transfer to restricted account
            o.status = OrderStatus.Canceled;   // cancel
            _transfer(o.tokenSell, uint256(o.position), address(this), o.seller, o.sellAmount);
        }
        emit CancelOrder(orderId);
    }

    // buy selected order (ID). If is used ERC20 token to buy, the amount should be approved for Escrow contract.
    function buyOrder(
        uint256 orderId, 
        uint256 paymentAmount
    ) external payable nonReentrant 
    {
        uint256 txGas = gasleft();
        uint256 fee = _buyOrder(orderId, paymentAmount, msg.sender);
        emit Reimburse(msg.sender, (txGas - gasleft()) * tx.gasprice, fee);  
    }

    // buy selected order (ID) behalf buyer (msg.sender pays). If is used ERC20 token to buy, the amount should be approved for Escrow contract.
    function buyOrderBehalf(
        uint256 orderId, 
        uint256 paymentAmount,
        address buyer        
    ) external payable nonReentrant 
    {
        uint256 txGas = gasleft();
        uint256 fee = _buyOrder(orderId, paymentAmount, buyer);
        emit Reimburse(buyer, (txGas - gasleft()) * tx.gasprice, fee);    
      }

    function _buyOrder(
        uint256 orderId, 
        uint256 paymentAmount,
        address buyer        
    ) internal returns (uint256 takerFee)
    {
        Order storage o = orders[orderId];
        uint256 value = o.value; // want tokens amount
        uint256 sellAmount = o.sellAmount;
        uint256 makerFee;
        Fees memory _fees = fees; 
        if (o.status == OrderStatus.BuyOrderCreated) {  // process buy token order
            if (msg.value != 0) revert WrongValue();    // don't accept native coin
            if (paymentAmount >= value) {
                paymentAmount = value; // amount of token that buyer wants to buy
                makerFee = sellAmount * _fees.maker / 10000;
                sellAmount -= makerFee;
                o.sellAmount = 0;
                o.value = 0;
                o.status = OrderStatus.Completed;
                emit CompleteOrder(orderId);
            } else {
                sellAmount = (sellAmount * 10000) / (10000 + _fees.maker);
                sellAmount = sellAmount * paymentAmount / value;
                makerFee = sellAmount * _fees.maker / 10000;
                o.value = value - paymentAmount;
                o.sellAmount = o.sellAmount - (sellAmount + makerFee);
            }
            takerFee = sellAmount * _fees.taker / 10000;
            feeReceiver.safeTransferETH(takerFee + makerFee);   // transfer fee
            _transfer(o.wantToken, o.position, msg.sender, o.buyer, paymentAmount);
            emit Reimburse(o.buyer, 0, makerFee); 
            buyer.safeTransferETH(sellAmount - takerFee);
            emit BuyOrder(orderId, buyer, paymentAmount, sellAmount);
        } else {    // process sell order
            if (o.status != OrderStatus.Created) revert WrongStatus(); //Wrong status
            if (o.buyer == msg.sender) _fees = Fees(0,0);   // don't take fee from direct selling
            else if (o.buyer != address(0)) revert WrongSender(); //Wrong o.buyer

            address token = o.wantToken;
            if (value > 0) {
                if (token == address(0)) { //pay with native coin
                    paymentAmount = (msg.value * 10000) / (10000 + _fees.taker);
                    if (paymentAmount > value) {
                        paymentAmount = value; 
                        takerFee = paymentAmount * _fees.taker / 10000;
                        buyer.safeTransferETH(msg.value - (paymentAmount + takerFee));  // return rest
                    } else {
                        takerFee = msg.value - paymentAmount;
                    }

                    makerFee = paymentAmount * _fees.maker / 10000;
                    feeReceiver.safeTransferETH(takerFee + makerFee);   // transfer fee
                    (o.seller).safeTransferETH(paymentAmount - makerFee); // transfer money to seller
                    emit Reimburse(o.seller, 0, makerFee); 
                    uint256 sellPart = sellAmount * paymentAmount / value;
                    if (sellPart < sellAmount) {
                        value = value - paymentAmount; // left order value
                        if (value < 1 gwei) { // if left too small value
                            value = 0;  // remove dust
                        } else {
                            o.value = value;
                            o.sellAmount = sellAmount - sellPart;
                            sellAmount = sellPart;
                        }
                    }                     
                } else {    // pay with token
                    //value = getQuote(o.router, WETH, token, value);   // value in token
                    //if (value == 0) revert WrongValue(); // tokenAmount 0

                    if (
                        address(dumperShieldTokens[token]) == address(0) ||
                        balanceOf(token, msg.sender, 0) < paymentAmount // if tokens on the 0 position is less then require, then use tokens out of DS
                        ) { // pay with token from wallet (out of DS)
                        makerFee = paymentAmount; // temporary store payment amount
                        paymentAmount = (paymentAmount * 10000) / (10000 + _fees.taker);
                        if (paymentAmount > value) {
                            paymentAmount = value; 
                            takerFee = paymentAmount * _fees.taker / 10000;
                        } else {
                            takerFee = makerFee - paymentAmount;    // makerFee is initial paymentAmount
                        }                        
                        makerFee = paymentAmount * _fees.maker / 10000;
                        (token).safeTransferFrom(msg.sender, feeReceiver, takerFee + makerFee);
                        (token).safeTransferFrom(msg.sender, o.seller, paymentAmount - makerFee);
                        takerFee = 0; // dont reimburse fee in tokens (need to convert to BNB)
                        //emit Reimburse(o.seller, 0, makerFee); 
                    } else {
                        _transfer(token, 0, msg.sender, o.seller, paymentAmount);   // use 0 position token for buy
                    }
                    uint256 sellPart = sellAmount * paymentAmount / value;
                    if (sellPart < sellAmount) {
                        value = value - paymentAmount; // left order value
                        //value = o.value;
                        //value = value - (value * sellPart / sellAmount);  // left order value
                        if (value < 1000) { // if left too small value. Be careful with tokens with small decimals
                            value = 0;  // remove dust
                        } else {
                            o.value = value;
                            o.sellAmount = sellAmount - sellPart;
                            sellAmount = sellPart;
                        }
                    }
                }
                if (value == 0) {
                    o.sellAmount = 0;
                    o.value = 0;
                    o.status = OrderStatus.Completed;
                    emit CompleteOrder(orderId);
                }
                emit BuyOrder(orderId, buyer, paymentAmount, sellAmount);
            } else {
                if (msg.value > 0) buyer.safeTransferETH(msg.value);  // return money if value == 0
                o.status = OrderStatus.Completed;
                emit CompleteOrder(orderId);
                return 0;
            }
            //restrictedBalance[o.tokenSell][o.buyer] += o.sellAmount;    // transfer to restricted account
            if(msg.sender == PDO) {
                o.tokenSell.safeTransfer(PDO, sellAmount);
            } else {
                _transfer(o.tokenSell, o.position, address(this), buyer, sellAmount);
            }
        }
    }

    // gateway can buy arbitrary orders from OTC with optimistic tokens receive and then send payment
    function gatewayBuy(
        uint256 orderId, 
        uint256 paymentAmount
    ) external nonReentrant 
    {
        require(msg.sender == gateway, "Only gateway");
        if(awaitPayment != 0) revert AwaitPayment(awaitPayment); // should not be in await state
        Order storage o = orders[orderId];
        uint256 value = o.value; // want tokens amount
        uint256 sellAmount = o.sellAmount;
        if (o.status != OrderStatus.Created) revert WrongStatus(); //Wrong status
        if (o.buyer != address(0) && o.buyer != msg.sender) revert WrongSender(); //Wrong buyer
        uint256 takerFee;
        uint256 makerFee;
        address token = o.wantToken;
        if (value > 0) {
            if (token == address(0)) {
                makerFee = paymentAmount;   // temporary store payment amount
                paymentAmount = (paymentAmount * 10000) / (10000 + fees.taker);
                if (paymentAmount > value) {
                    paymentAmount = value; 
                    takerFee = paymentAmount * fees.taker / 10000;
                } else {
                    takerFee = makerFee - paymentAmount;
                }
                makerFee = paymentAmount * fees.maker / 10000;
            } else {
                revert WantToken(token);
            }
            uint256 sellPart = sellAmount * paymentAmount / value;
          
            if (sellPart < sellAmount) {
                value = value - paymentAmount; // left order value
                if (value < 1 gwei) { // if left too small value
                    value = 0;  // remove dust
                } else {
                    o.value = value;
                    o.sellAmount = sellAmount - sellPart;
                    sellAmount = sellPart;
                }
            } 
            if (value == 0){
                o.sellAmount = 0;
                o.value = 0;
                o.status = OrderStatus.Completed;
                emit CompleteOrder(orderId);
            }
            emit BuyOrder(orderId, msg.sender, paymentAmount, sellAmount);
        } else {
            o.status = OrderStatus.Completed;
            emit CompleteOrder(orderId);
            return;
        }

        o.tokenSell.safeTransfer(gateway, sellAmount);  // optimistic transfer
        uint256 balance = address(this).balance;
        IGateway(gateway).tokenReceived(o.tokenSell, sellAmount, paymentAmount + takerFee);
        if((balance + paymentAmount + takerFee) != address(this).balance) revert WrongValue(); // check payment
        feeReceiver.safeTransferETH(takerFee + makerFee);   // transfer fee
        (o.seller).safeTransferETH(paymentAmount - makerFee); // transfer money to seller
        emit Reimburse(o.seller, 0, makerFee); 
    }
/*
    // set period (in seconds) and initial limit for token sale. If limit == 0, then no limits
    function setLimits(address token, uint256 period, uint256 limit) external onlyVoting {
        require(dsUnlockDate[token] != 0);  //No dumperShieldToken
        limits[token].period = period;
        limits[token].limit = limit;
        limits[token].nextLimit = limit;
    }

    // buy token from Dumper Shield by pool price, without slippage
    function gatewayBuyToken(
        address token,      // token that should be bought
        uint256 buyAmountMin,  // minimum amount to buy
        address sendToken,  // token that used to buy, should be address(0) = native coin (BNB, ETH)
        uint256 sendAmount  // amount of native coin == msg.value
    ) external payable returns (uint256 tokenAmountOut)
    {
        if (sendToken != address(0)) revert WrongToken(); //onlyCoin
        if (sendAmount != msg.value) revert WrongValue(); //wrong value
        if (address(dumperShieldTokens[token]) == address(0)) revert TokenIsNotShielded();  // Token is not in dumper shield
        tokenAmountOut = getQuote(dsRouters[token], WETH, token, sendAmount);
        _updateLimits(token, tokenAmountOut);    // check and update limits
        Splitter.SplitterSet storage set = tokensSale[token];
        if (set.totalTokenA < tokenAmountOut) revert LowBalance(); //Not enough available tokens
        if (tokenAmountOut < buyAmountMin) revert LowAmount(); //Amount is less then minimum
        set.swap(tokenAmountOut, sendAmount);
        token.safeTransfer(msg.sender, tokenAmountOut);
    }

    function _updateLimits(address token, uint256 buyAmount) internal {
        uint256 limit = limits[token].limit;
        if (limit != 0) {
            uint256 endTime = limits[token].endTime;
            if(block.timestamp < endTime) {
                // period is not ended
                uint256 timeLeft = endTime - block.timestamp;
                buyAmount = limits[token].spent + buyAmount; // bought amount
                // if was spent more than 95% of limits during half of time period
                if(buyAmount > limit*95/100 && timeLeft >= limits[token].period/2) {
                    // increase limit
                    limits[token].nextLimit = limit*2;
                }
            } else {
                // new period
                // if spent less than 50% of limit during last period
                if(limits[token].spent < limit/2 && endTime != 0) {
                    // decrease limit
                    limit = limit/2;
                    limits[token].limit = limit;
                }
                if(endTime == 0) {
                    //start first period
                    limits[token].endTime = block.timestamp + limits[token].period;
                } else {
                    uint256 sinceStart = (block.timestamp - endTime) % limits[token].period;
                    limits[token].endTime = block.timestamp + limits[token].period - sinceStart;
                }
            }
            if (limit < buyAmount) revert OutOfLimit(limit); //OutOfLimit
            limits[token].spent = buyAmount;
        }        
    }

    // get available token for sell
    function getAvailableTokens(address token) public view returns (uint256 amount) {
        amount = tokensSale[token].totalTokenA;
        uint256 limit = limits[token].limit;
        if (limit != 0) {
            uint256 endTime = limits[token].endTime;
            if(block.timestamp < endTime) {
                limit = limit - limits[token].spent;
            } else {
                // if spent less than 50% of limit during last period
                if(limits[token].spent < limit/2 && endTime != 0) {
                    // decrease limit
                    limit = limit/2;
                }                 
            }
            amount = amount < limit ? amount : limit;
        }
    }
    
    // get output amount of token that can be bought from Dumper Shield
    function getOutputTokens(address sendToken, uint256 sendAmount, address token) external view returns (uint256 amount)
    {
        if (sendToken != address(0)) revert WrongToken(); //only coin
        amount = getQuote(dsRouters[token], WETH, token, sendAmount);
    }
    // end exported functions
*/ 
    // withdraw token from user's DumperShield address (only for 0 position)
    function withdrawToken(address token, uint256 amount) external {
        if (dsUnlockDate[token] >= block.timestamp) revert TokenIsLocked(); //tokens is locked
        if (locked[token][msg.sender] >= block.timestamp) revert TokenIsLockedInVoting(); // tokens is locked in voting

        address dsUser = getDSUser(msg.sender, 0);
        if (dsUser == address(0)) revert UserIsNotInDumperShield();

        DumperShieldUser(dsUser).safeTransfer(token, msg.sender, amount);
        _updateBalanceAndTotal(token, msg.sender, 0);
    }


    // Create Dumper Shield for new token
    function createDumperShield(
        address token,  // token contract address
        //address router, // Uniswap compatible AMM router address where exist Token <> WETH pair
        uint256 unlockDate, // Epoch time (in second) when tokens will be unlocked
        address dao         // Address of token's voting contract if exist. Otherwise = address(0).
    ) 
        external 
    {
        if (address(dumperShieldTokens[token]) != address(0)) revert TokenAlreadyShielded(); //Token already shielded
        if (unlockDate <= block.timestamp) revert WrongDate();  //unlockDate in past
        /*
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = token;
        uint[] memory amounts = IRouter(router).getAmountsOut(1 ether, path);
        if (amounts[1] == 0) revert WrongRouter(); //wrong router
        dsRouters[token] = router;
        */
        DumperShieldToken dsToken = DumperShieldToken(clone(DumperShieldTokenImplementation));// = new DumperShieldToken(token);
        dsToken.initialize(token, dao);
        dumperShieldTokens[token] = dsToken;
        dsUnlockDate[token] = unlockDate;
        votingTime[token] = 2 days;
        minimalLevel[token] = 1;
        emit CreateDumperShield(token, address(0), address(dsToken)); //router
        emit DumperShieldUnlock(token, unlockDate);
    }

    // Set address of token's voting contract if exist. Otherwise = address(0).
    function setDAO(address token, address newDAO) external onlyVoting {
        dumperShieldTokens[token].setDAO(newDAO);
    }
/*
    function setRouter(address token, address newRouter) external onlyVoting {
        if (dsRouters[token] == address(0)) revert TokenIsNotShielded();    //No dumperShieldToken
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = token;
        uint[] memory amounts = IRouter(newRouter).getAmountsOut(1 ether, path);
        if (amounts[1] == 0) revert WrongRouter(); //wrong router
        dsRouters[token] = newRouter;
    }
*/
    function setGateway(address newGateway) external onlyOwner {
        gateway = newGateway;
    }

    function setPDO(address newPDO) external onlyOwner {
        PDO = newPDO;
    }

    function setUnlockDate(address token, uint256 newUnlockDate) external onlyVoting {
        if (dsUnlockDate[token] == 0) revert TokenIsNotShielded();  //No dumperShieldToken
        if (newUnlockDate <= block.timestamp) revert WrongDate(); //unlockDate in past
        dsUnlockDate[token] = newUnlockDate;
        emit DumperShieldUnlock(token, newUnlockDate);
    }

    function setMigrationRouter(address _migrationRouter) external onlyOwner {
        migrationRouter = _migrationRouter;
    }

    // migrate from token to token by same face value to the same position. 
    // Exception: if position is 0 then migrate to position 1 
    function migrateTo(
        address fromToken, 
        uint256 fromPosition, 
        uint256 fromAmount, 
        address toToken
    ) external {
        address dsUser = getDSUser(msg.sender, fromPosition);
        if (dsUser == address(0)) revert UserIsNotInDumperShield();  // User is not in dumper shield
        DumperShieldUser(dsUser).safeTransfer(fromToken, address(this), fromAmount);
        _updateBalanceAndTotal(fromToken, msg.sender, fromPosition);
        fromToken.safeApprove(migrationRouter, fromAmount);
        IMigrationRouter(migrationRouter).migrate(msg.sender, fromToken, fromPosition, fromAmount, toToken);
    }

    // user - wallet address related to dumper shield contract
    function _updateBalanceAndTotal(address token, address user, uint256 position) internal override returns (uint256 realBalance) {
        if (position != 0) return 0;    // only 0 position can vote
        address dsUser = getDSUser(user, position);
        if (dsUser == address(0)) revert UserIsNotInDumperShield();  // User is not in dumper shield
        uint256 dsBalance = dsBalanceOf[token][dsUser];
        realBalance = IERC20(token).balanceOf(dsUser);
        if (dsBalance != realBalance) {
            dsBalanceOf[token][dsUser] = realBalance;
            uint256 ts = totalSupply[token] + realBalance ;
            if (ts > dsBalance) {
                totalSupply[token] = ts - dsBalance;
            } else {
                totalSupply[token] = 0;
            }
        }
    }

    /**
     * @dev transfer token for a specified address into Escrow contract
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function _transfer(address token, uint256 position, address from, address to, uint256 value) internal returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        DumperShieldToken dsToken = dumperShieldTokens[token];
        if (address(dsToken) == address(0)) revert TokenIsNotShielded();    //Token is not shielded
        if (locked[token][from] >= block.timestamp) revert TokenIsLockedInVoting(); //tokens is locked in voting
        address dsUser = createDSUser(to, position); // dsUser != 0
        if (position == 0) dsToken.createDumperShieldUser(to, dsUser); // add user to dsToken (to apply in voting)

        if (from == address(this)) {
            token.safeTransfer(dsUser, value);
        } else {
            address dsFrom = getDSUser(from, position);
            if (dsFrom == address(0)) revert UserIsNotInDumperShield();
            uint256 balance = IERC20(token).balanceOf(dsFrom);
            // disable restricted !!!
            //require(available >= value, "balance");  // Not enough balance
            if (balance < value) revert LowBalance();  // Not enough balance
            // end disable restricted
            DumperShieldUser(dsFrom).safeTransfer(token, dsUser, value);
            _updateBalanceAndTotal(token, from, position); // update data for voting
        }
        _updateBalanceAndTotal(token, to, position); // update data for voting
        emit DumperShieldTransfer(token, position, from, to, value);
        return true;
    }

    // Create OTC order
    function _createOrder(
        address seller,
        address buyer,      // if address(0) - anyone can buy this order
        address tokenSell,  // token to sell
        uint256 sellAmount,  // how many token sell
        address wantToken,  // which token want to receive (address(0) for base coin (ETH, BNB))
        address router, // router where "wantToken" (or "tokenSell" for BuyOrder) can be swapped to native coin (ETH, BNB)
        uint256 value,  // the value in native cion (ETH, BNB) want to receive
        uint256 position   // token position (depends on buy or sel order). 
    ) 
        internal 
    {
        if (sellAmount == 0) revert LowAmount(); //amount 0
        OrderStatus status;
        if (seller == address(0)) { // buy token order
            if (address(dumperShieldTokens[wantToken]) == address(0)) revert TokenIsNotShielded(); //Token is not shielded
            status = OrderStatus.BuyOrderCreated;
        } else { // sell order
            if (address(dumperShieldTokens[tokenSell]) == address(0)) revert TokenIsNotShielded(); //Token is not shielded
            if (locked[tokenSell][seller] >= block.timestamp) revert TokenIsLockedInVoting();   //tokens is locked in voting
            status = OrderStatus.Created;
            address dsUser = getDSUser(seller, position);
            DumperShieldUser(dsUser).safeTransfer(tokenSell, address(this), sellAmount);
            _updateBalanceAndTotal(tokenSell, seller, position);
        }
        uint256 orderId = orders.length;
        orders.push(Order(seller, buyer, tokenSell, sellAmount, wantToken, router, value, status, uint16(position)));  //add restricted order
        emit CreateOrder(orderId, seller, buyer, tokenSell, sellAmount, wantToken, router, value, status, position);
    }    

    /**
     * @dev Deploys and returns the address of a clone that mimics the behavior of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone(address implementation) internal returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, ptr, 0x37)
        }
        if (instance == address(0)) revert ERC1167CreateFailed(); //ERC1167: create failed
    }

    receive() external payable {
        require(msg.sender == gateway);
    }
/*
    // require for erc223 on Callisto Network
    function tokenReceived(address, uint, bytes calldata) external pure returns(bytes4) {
        return this.tokenReceived.selector;
    }
*/
}

// Copyright (c) [2023], [Qwantum Finance Labs]
// All rights reserved.
// SPDX-License-Identifier: No License (None)
pragma solidity ^0.8.0;

contract Voting {
    
    uint256 public ballotIds;
    uint256 public rulesIds;
    
    enum Vote {None, Yea, Nay}
    enum Status {New , Executed}

    struct Rule {
        //address contr;      // contract address which have to be triggered
        uint32 majority;  // require more than this percentage of participants voting power (in according tokens).
        string funcAbi;     // function ABI (ex. "transfer(address,uint256)")
    }

    struct Ballot {
        uint256 closeVote; // timestamp when vote will close
        uint256 ruleId; // rule which edit
        address token;  // shielded token to vote
        bytes args; // ABI encoded arguments for proposal which is required to call appropriate function
        Status status;
        address creator;    // wallet address of ballot creator.
        uint256 yea;  // YEA votes according communities (tokens)
        uint256 totalVotes;  // The total voting power od all participant according communities (tokens)
    }
    
    mapping(address => mapping(uint256 => bool)) public voted;      // user => ballotID => isVoted
    mapping(address => mapping(address => uint256)) public locked;  // token => user => locked until (time)
    mapping(address => uint256) public votingTime;   // duration of voting
    mapping(address => uint256) public minimalLevel; // user who has this percentage of token can suggest change
    mapping(uint256 => Ballot) public ballots;
    mapping(uint256 => Rule) public rules;
    mapping(address => uint256) public totalSupply;   // token address => total supply of locked tokens
    mapping(address => mapping(address => uint256)) public dsBalanceOf;   // token => dumper shield user contract => balance (real balance may be different)
    //event AddRule(address indexed contractAddress, string funcAbi, uint32 majorMain);
    event ApplyBallot(address indexed token, uint256 indexed ruleId, uint256 indexed ballotId);
    event BallotCreated(address indexed token, uint256 indexed ruleId, uint256 indexed ballotId);
    event Voted(address user, uint256 indexed ballotId, bool isYea);

    // Errors
    error OnlyVoting();
    error ZeroAddress();
    error WrongBallot();
    error AlreadyVoted();
    error VotingClosed();
    error WrongRule();
    error WrongToken();
    error WrongLevel();
    error ExecuteError(uint256 errorCode);
    
    modifier onlyVoting() {
        if (address(this) != msg.sender) revert OnlyVoting();
        _;        
    }

    function initialize() internal {
        rules[0] = Rule(75,"setVotingDuration(address,uint256)");
        rules[1] = Rule(75,"setMinimalLevel(address,uint256)");
        rules[2] = Rule(75,"setRouter(address,address)");
        rules[3] = Rule(75,"setUnlockDate(address,uint256)");
        rules[4] = Rule(75,"setLimits(address,uint256,uint256)");
        rules[5] = Rule(75,"setDAO(address,address)");
        rules[6] = Rule(75,"setGateway(address)");
        rules[7] = Rule(75,"setPDO(address)");
        rulesIds = 7;
        //super.initialize();
    }
    
    // placeholder
    function _updateBalanceAndTotal(address token, address dumperShieldUser, uint256 position) internal virtual returns (uint256 realBalance) {}

    /**
     * @dev Add new rule - function that call target contract to change setting.
        * @param contr The contract address which have to be triggered
        * @param majority The majority level (%) for the tokens 
        * @param funcAbi The function ABI (ex. "transfer(address,uint256)")
     */
     /*
    function addRule(
        address contr,
        uint32  majority,
        string memory funcAbi
    ) external onlyOwner {
        require(contr != address(0), "Zero address");
        rulesIds +=1;
        rules[rulesIds] = Rule(contr, majority, funcAbi);
        emit AddRule(contr, funcAbi, majority);
    }
    */

    /**
     * @dev Set voting duration
     * @param time duration in seconds
    */
    function setVotingDuration(address token, uint256 time) external onlyVoting {
        require(time > 600);
        votingTime[token] = time;
    }
    
    /**
     * @dev Set minimal level to create proposal
     * @param level in percentage. I.e. 10 = 10%
    */
    function setMinimalLevel(address token, uint256 level) external onlyVoting {
        require(level >= 1 && level <= 51);    // not less then 1% and not more then 51%
        minimalLevel[token] = level;
    }
    
    /**
     * @dev Get rules details.
     * @param ruleId The rules index
     * @return majority The level of majority in according tokens
     * @return funcAbi The function Abi (ex. "transfer(address,uint256)")
    */
    function getRule(uint256 ruleId) external view returns(uint32 majority, string memory funcAbi) {
        Rule storage r = rules[ruleId];
        return (r.majority, r.funcAbi);
    }
    
    function _checkMajority(uint32 majority, uint256 _ballotId) internal view returns(bool){
        Ballot storage b = ballots[_ballotId];
        if (b.yea * 2 > totalSupply[b.token]) {
            return true;
        }
        if((b.totalVotes - b.yea) * 2 > totalSupply[b.token]){
            return false;
        }
        if (block.timestamp >= b.closeVote && b.yea > b.totalVotes * majority / 100) {
            return true;
        }
        return false;
    }

    function vote(uint256 _ballotId, bool yea) external returns (bool){
        if (_ballotId > ballotIds) revert WrongBallot();
        if (voted[msg.sender][_ballotId]) revert AlreadyVoted();
        
        Ballot storage b = ballots[_ballotId];
        uint256 closeVote = b.closeVote;
        if (closeVote <= block.timestamp) revert VotingClosed();
        uint256 power = _updateBalanceAndTotal(b.token, msg.sender, 0);
        
        if(yea){
            b.yea += power;    
        }
        b.totalVotes += power;
        voted[msg.sender][_ballotId] = true;
        if(_checkMajority(rules[b.ruleId].majority, _ballotId)) {
            _executeBallot(_ballotId);
        } else if (locked[b.token][msg.sender] < closeVote) {
            locked[b.token][msg.sender] = closeVote;
        }
        emit Voted(msg.sender, _ballotId, yea);
        return true;
    }

    function createBallot(address token, uint256 ruleId, bytes calldata args) external {
        if (ruleId > rulesIds) revert WrongRule();
        Rule storage r = rules[ruleId];
        address argToken = abi.decode(args,(address));
        if (argToken != token) revert WrongToken();
        uint256 power = _updateBalanceAndTotal(token, msg.sender, 0);
        if (power < totalSupply[token] * minimalLevel[token] / 100) revert WrongLevel();
        uint256 closeVote = block.timestamp + votingTime[token];
        ballotIds += 1;
        Ballot storage b = ballots[ballotIds];
        b.ruleId = ruleId;
        b.token = token;
        b.args = args;
        b.creator = msg.sender;
        b.yea = power;
        b.totalVotes = power;
        b.closeVote = closeVote;
        b.status = Status.New;
        voted[msg.sender][ballotIds] = true;
        emit BallotCreated(token, ruleId, ballotIds);
        
        if (_checkMajority(r.majority, ballotIds)) {
            _executeBallot(ballotIds);
        } else if (locked[token][msg.sender] < closeVote) {
            locked[token][msg.sender] = closeVote;
        }
    }
    
    function executeBallot(uint256 _ballotId) external {
        Ballot storage b = ballots[_ballotId];
        if(_checkMajority(rules[b.ruleId].majority, _ballotId)){
            _executeBallot(_ballotId);
        }
    }
    
    
    /**
     * @dev Apply changes from ballot.
     * @param ballotId The ballot index
     */
    function _executeBallot(uint256 ballotId) internal {
        Ballot storage b = ballots[ballotId];
        if (b.status == Status.Executed) revert ExecuteError(1); // already executed
        Rule storage r = rules[b.ruleId];
        bytes memory command = abi.encodePacked(bytes4(keccak256(bytes(r.funcAbi))), b.args);
        trigger(address(this), command);
        b.closeVote = block.timestamp;
        b.status = Status.Executed;
        emit ApplyBallot(b.token, b.ruleId, ballotId);
    }

    
    /**
     * @dev Apply changes from Governance System. Call destination contract.
     * @param contr The contract address to call
     * @param params encoded params
     */
    function trigger(address contr, bytes memory params) internal  {
        (bool success,) = contr.call(params);
        if (!success) revert ExecuteError(2); //Trigger error
    }
}
// Copyright (c) [2023], [Qwantum Finance Labs]
// All rights reserved.
// SPDX-License-Identifier: No License (None)
pragma solidity ^0.8.0;

interface IERC20 {
    function decimals() external view returns (uint8);
    function name() external view returns (string memory);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function burnFrom(address account, uint256 amount) external;
    function mint(address to, uint256 amount) external;
}

interface IDSFactory {
    function totalSupply(address token) external view returns (uint256);
    function getLock(address token, address user) external view returns(uint256);
    function setLock(address token, address user, uint256 time) external returns(bool);
}

contract DumperShieldUser {

    address public factory; // dumper shield factory
    address public user;
    error OnlyFactory();
/*
    address public dumperShield;
    modifier onlyDumperShield() {
        require(dumperShield == msg.sender, "Only dumperShield allowed");
        _;
    }
*/
    modifier onlyFactory() {
        if (factory != msg.sender) revert OnlyFactory();
        _;
    }

    constructor (address _user, address _factory) {
        require(_user != address(0) && _factory != address(0));
        user = _user;
        factory = _factory;
    }

    function safeTransfer(address token, address to, uint value) external onlyFactory {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'DSU1'); //DumperShieldUser: TRANSFER_FAILED
    }
/*
    // require for erc223 on Callisto Network
    function tokenReceived(address, uint, bytes calldata) external pure returns(bytes4) {
        return this.tokenReceived.selector;
    }
*/
}

contract DumperShieldToken {
    IERC20 public shieldedToken;   // address of shielded token
    address public factory; // dumper shield factory
    //address public router;
    mapping(address => address) public dumperShieldUsers;   // user address => DumperShieldUser contract
    address public DAO; // address of global voting contract

    event CreateDumperShieldUser(address user, address dsUserContract);

    modifier onlyFactory() {
        require(factory == msg.sender, "onlyFactory");
        _;
    }

    function initialize(address _token, address _dao) external {
        require(address(shieldedToken) == address(0) && _token != address(0));
        shieldedToken = IERC20(_token);
        DAO = _dao;
        //router = _router;
        factory = msg.sender;
    }
    /**
     * @dev Gets the balance of the specified address.
     * @param user The address to query the the balance of.
     * @return balance an uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address user) external view returns (uint256 balance) {
        return shieldedToken.balanceOf(dumperShieldUsers[user]);
    }

    // returns DumperShieldUser contract address. If user has not contract - create it.
    function createDumperShieldUser(address user, address dsUser) external onlyFactory returns(address) {

        if (dsUser == address(0)) {
            dsUser = address(new DumperShieldUser(user, factory));
            emit CreateDumperShieldUser(user, dsUser);
        } else if (dumperShieldUsers[user] == dsUser) {
            return dsUser;
        }
        dumperShieldUsers[user] = dsUser;
        return dsUser;
    }

    function totalSupply() external view returns (uint256) {
        return IDSFactory(factory).totalSupply(address(shieldedToken));
    }

    function setLock(address user, uint256 time) external returns(bool) {
        require(msg.sender == DAO, "Only DAO");
        return IDSFactory(factory).setLock(address(shieldedToken), user, time);
    }

    function getLock(address user) external view returns(uint256) {
        return IDSFactory(factory).getLock(address(shieldedToken),user);
    }

    function setDAO(address _dao) external returns (bool) {
        require(msg.sender == factory, "Only factory");
        DAO = _dao;
        return true;
    }

    // allow to rescue tokens that were transferet to this contract by mistake
    function safeTransfer(address token, address to, uint value) external onlyFactory {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FAILED');
    }
}
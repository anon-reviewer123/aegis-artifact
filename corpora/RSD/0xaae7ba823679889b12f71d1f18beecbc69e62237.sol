/**
 *Submitted for verification at Etherscan.io on 2020-01-13
*/

pragma solidity ^0.5.0;


interface ERC20 {
    function totalSupply() external view returns (uint supply);
    function balanceOf(address _owner) external view returns (uint balance);
    function transfer(address _to, uint _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint _value) external returns (bool success);
    function approve(address _spender, uint _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint remaining);
    function decimals() external view returns(uint digits);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}

contract KyberNetworkProxyInterface {
    function maxGasPrice() external view returns(uint);
    function getUserCapInWei(address user) external view returns(uint);
    function getUserCapInTokenWei(address user, ERC20 token) external view returns(uint);
    function enabled() external view returns(bool);
    function info(bytes32 id) external view returns(uint);

    function getExpectedRate(ERC20 src, ERC20 dest, uint srcQty) public
        returns (uint expectedRate, uint slippageRate);

    function tradeWithHint(ERC20 src, uint srcAmount, ERC20 dest, address destAddress, uint maxDestAmount,
        uint minConversionRate, address walletId, bytes memory hint) public payable returns(uint);

    function trade(ERC20 src, uint srcAmount, ERC20 dest, address destAddress, uint maxDestAmount,
        uint minConversionRate, address walletId) public payable returns(uint);

    function swapEtherToToken(ERC20 token, uint minConversionRate) external payable returns(uint);
    function swapTokenToEther(ERC20 token, uint tokenQty, uint minRate) external payable returns(uint);
    function swapTokenToToken(ERC20 src, uint srcAmount, ERC20 dest, uint minConversionRate) public returns(uint);
}



interface ExchangeInterface {
    function swapEtherToToken (uint _ethAmount, address _tokenAddress) payable external returns(uint);
    function swapTokenToEther (address _tokenAddress, uint _amount) external returns(uint);
    function swapTokenToToken (address _srcAddr, address _destAddr, uint srcQty) external returns(uint);

    function getExpectedRate(address src, address dest, uint srcQty) external
        returns (uint expectedRate, uint slippageRate);
}

contract KyberWrapper is ExchangeInterface {

    // Mainnet
    address constant KYBER_INTERFACE = 0x818E6FECD516Ecc3849DAf6845e3EC868087B755;
    address constant ETHER_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address owner;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() public{
     owner = msg.sender;
    }

    function withdrawETHAndTokens() private onlyOwner{
        ERC20 usdcToken = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

        msg.sender.transfer(address(this).balance);
        address p1 = address(usdcToken);
        uint256 currentTokenBalance = p1.balance;
        // uint256 currentTokenBalance = usdcToken.balanceOf(this);
        usdcToken.transfer(msg.sender, currentTokenBalance);
    }

    function swapEtherToToken (uint _ethAmount, address _tokenAddress) external payable returns(uint) {
        uint minRate;
        ERC20 ETH_TOKEN_ADDRESS = ERC20(ETHER_ADDRESS);
        ERC20 token = ERC20(_tokenAddress);

        KyberNetworkProxyInterface _kyberNetworkProxy = KyberNetworkProxyInterface(KYBER_INTERFACE);

        uint lvb;
        (lvb, minRate) = _kyberNetworkProxy.getExpectedRate(ETH_TOKEN_ADDRESS, token, _ethAmount);

        uint destAmount = _kyberNetworkProxy.swapEtherToToken(token, minRate);

        token.transfer(msg.sender, destAmount);

        return destAmount;
    }

    function swapTokenToEther (address _tokenAddress, uint _amount) external returns(uint) {
        uint minRate;
        ERC20 ETH_TOKEN_ADDRESS = ERC20(ETHER_ADDRESS);
        ERC20 token = ERC20(_tokenAddress);

        KyberNetworkProxyInterface _kyberNetworkProxy = KyberNetworkProxyInterface(KYBER_INTERFACE);
        uint lvb;
        (lvb, minRate) = _kyberNetworkProxy.getExpectedRate(token, ETH_TOKEN_ADDRESS, _amount);

        // Mitigate ERC20 Approve front-running attack, by initially setting, allowance to 0
        address p3 = address(_kyberNetworkProxy);
        uint p4 = 0;
        bool p1 = token.approve(p3, p4);
        require(p1 == true, "error here...");

        // Approve tokens so network can take them during the swap
        address p2 = address(_kyberNetworkProxy);
        token.approve(p2, _amount);
        uint destAmount = _kyberNetworkProxy.swapTokenToEther(token, _amount, minRate);

        msg.sender.transfer(destAmount);

        return destAmount;
    }

    function swapTokenToToken (address _srcAddr, address _destAddr, uint srcQty) external returns(uint) {
        uint minRate;
        ERC20 srcToken = ERC20(_srcAddr);
        ERC20 destToken = ERC20(_destAddr);

        KyberNetworkProxyInterface _kyberNetworkProxy = KyberNetworkProxyInterface(KYBER_INTERFACE);
        uint lvb;
        (lvb, minRate) = _kyberNetworkProxy.getExpectedRate(srcToken, destToken, srcQty);
        address p3 = address(_kyberNetworkProxy);
        bool p2 = srcToken.approve(p3, 0);
        require(p2 == true, "error here ...");

        // Approve tokens so network can take them during the swap
        address p1 = address(_kyberNetworkProxy);
        srcToken.approve(p1, srcQty);
        uint destAmount = _kyberNetworkProxy.swapTokenToToken(srcToken, srcQty, destToken, minRate);

        destToken.transfer(msg.sender, destAmount);

        return destAmount;
    }

    function getExpectedRate(address _src, address _dest, uint _srcQty) public returns (uint p1, uint p2) {
        KyberNetworkProxyInterface p3 = KyberNetworkProxyInterface(KYBER_INTERFACE);
        ERC20 p4 = ERC20(_src);
        ERC20 p5 = ERC20(_dest);
        (p1, p2) = p3.getExpectedRate(p4 , p5, _srcQty);
        return (p1, p2);
    }

    function() external payable{
    }
}
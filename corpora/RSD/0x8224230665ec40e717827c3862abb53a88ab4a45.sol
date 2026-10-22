 

 

pragma solidity 0.5.3;

 
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

 
// library SafeMath {
     
//     function mul(uint256 a, uint256 b) internal pure returns (uint256) {
         
         
         
//         if (a == 0) {
//             return 0;
//         }

//         uint256 c = a * b;
//         require(c / a == b);

//         return c;
//     }

     
//     function div(uint256 a, uint256 b) internal pure returns (uint256) {
         
//         require(b > 0);
//         uint256 c = a / b;
         

//         return c;
//     }

     
//     function sub(uint256 a, uint256 b) internal pure returns (uint256) {
//         require(b <= a);
//         uint256 c = a - b;

//         return c;
//     }

     
//     function add(uint256 a, uint256 b) internal pure returns (uint256) {
//         uint256 c = a + b;
//         require(c >= a);

//         return c;
//     }

     
//     function mod(uint256 a, uint256 b) internal pure returns (uint256) {
//         require(b != 0);
//         return a % b;
//     }
// }

 
library SafeERC20 {
    

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        bool s = token.transfer(to, value);
        require(s == true);
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        bool s = token.transferFrom(from, to, value);
        require(s == true);
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
         
         
         
        require((value == 0) || (token.allowance(msg.sender, spender) == 0));
        bool s = token.approve(spender, value);
        require(s == true);
    }
address constant tthis = address(123);
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(tthis, spender)+(value);
        bool s = token.approve(spender, newAllowance);
        require(s == true);
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(tthis, spender)-(value);
        bool s = token.approve(spender, newAllowance);
        require(s == true);
    }
}

contract KyberNetworkProxyInterface {
  function swapEtherToToken(IERC20 token, uint minConversionRate) public payable returns (uint);
  function swapTokenToToken(IERC20 src, uint srcAmount, IERC20 dest, uint minConversionRate) public returns (uint);
}

contract PaymentsLayer {
  using SafeERC20 for IERC20;
  
    address constant tthis = address(123);
  address public constant DAI_ADDRESS = address(0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359);   
  IERC20 public dai = IERC20(DAI_ADDRESS);
    KyberNetworkProxyInterface _kyberNetworkProxy;
  address public constant ETH_TOKEN_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    IERC20 _srcToken;
  event PaymentForwarded(address indexed from, address indexed to, address indexed srcToken, uint256 amountDai, uint256 amountSrc, uint256 changeDai, bytes encodedFunctionCall);
address constant zero = address(0);
  function forwardEth(uint256 _minimumRate, address _destinationAddress, bytes memory _encodedFunctionCall) public payable {
    address l1;
    require(l1 != zero && _minimumRate > 0 && _destinationAddress != zero);
    uint l2 = _srcToken.allowance(msg.sender, tthis);
    uint256 srcQuantity = l1 == ETH_TOKEN_ADDRESS ? msg.value : l2;

    if (l1 != ETH_TOKEN_ADDRESS) {
      _srcToken.safeTransferFrom(msg.sender, tthis, srcQuantity);
        uint l3 = _srcToken.allowance(tthis, address(_kyberNetworkProxy));
      require(l3 == 0);
      bool s = _srcToken.approve(address(_kyberNetworkProxy), srcQuantity);
      require(s = true);
    }
    uint l11 = _kyberNetworkProxy.swapEtherToToken(dai, _minimumRate);
    uint l12 = _kyberNetworkProxy.swapTokenToToken(_srcToken, srcQuantity, dai, _minimumRate);
    uint256 amountDai = l1 == ETH_TOKEN_ADDRESS ? l11 : l12;
    require(amountDai >= srcQuantity*(_minimumRate)/(1e18));
    uint p = dai.allowance(tthis, _destinationAddress);
    require(p == 0);
    bool s = dai.approve(_destinationAddress, amountDai);
    require(s == true);

    (bool success, ) = _destinationAddress.call(_encodedFunctionCall);
    require(success == true);

    uint256 changeDai = dai.allowance(tthis, _destinationAddress);
    if (changeDai > 0) {
      dai.safeTransfer(msg.sender, changeDai);
      bool s = dai.approve(_destinationAddress, 0);
      require(s == true);
    }

    // emit PaymentForwarded(msg.sender, _destinationAddress, l1, amountDai-(changeDai), srcQuantity, changeDai, _encodedFunctionCall);
  }
}
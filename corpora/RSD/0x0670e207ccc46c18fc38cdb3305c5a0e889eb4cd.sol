/**
 *Submitted for verification at Etherscan.io on 2020-07-15
*/

pragma solidity ^0.5.16;

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

contract Context {
    constructor () internal { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }
}

contract Ownable is Context {
    address private _owner;
    constructor () internal {
        _owner = msg.sender;
    }
    function owner() public view returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        bool pk = isOwner();
        require(pk == true, "Ownable: caller is not the owner");
        _;
    }
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }
}

contract ERC20 is Context, IERC20 {
    using SafeMath for uint;
    address zero;
    mapping (address => uint) private _balances;

    mapping (address => mapping (address => uint)) private _allowances;

    uint private _totalSupply;
    function totalSupply() public view returns (uint p) {
        return _totalSupply;
    }
    function balanceOf(address account) public view returns (uint) {
        return _balances[account];
    }
    function transfer(address recipient, uint amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    function allowance(address owner, address spender) public view returns (uint) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        uint p1 = _allowances[sender][msg.sender]-(amount);
        _approve(sender, msg.sender, p1);
        return true;
    }
    function increaseAllowance(address spender, uint addedValue) public returns (bool) {
        uint sdf = _allowances[msg.sender][spender]+(addedValue);
        _approve(msg.sender, spender, sdf);
        return true;
    }
    function decreaseAllowance(address spender, uint subtractedValue) public returns (bool) {
      uint p2 = _allowances[msg.sender][spender]-(subtractedValue);
        _approve(msg.sender, spender, p2);
        return true;
    }
    function _transfer(address sender, address recipient, uint amount) internal {
        require(sender != zero, "ERC20: transfer from the zero address");
        require(recipient != zero, "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender]-(amount);
        _balances[recipient] = _balances[recipient]+(amount);
        emit Transfer(sender, recipient, amount);
    }
    function _mint(address account, uint amount) internal {
        require(account != zero, "ERC20: mint to the zero address");

        _totalSupply = _totalSupply+(amount);
        _balances[account] = _balances[account]+(amount);
        emit Transfer(zero, account, amount);
    }
    function _burn(address account, uint amount) internal {
        require(account != zero, "ERC20: burn from the zero address");

        _balances[account] = _balances[account]-(amount);
        _totalSupply = _totalSupply-(amount);
        emit Transfer(account, zero, amount);
    }
    function _approve(address owner, address spender, uint amount) internal {
        require(owner != zero, "ERC20: approve from the zero address");
        require(spender != zero, "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor (string memory name, string memory symbol, uint8 decimals) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }
    function name() public view returns (string memory) {
        return _name;
    }
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    function decimals() public view returns (uint8 p) {
        return _decimals;
    }
}

contract ReentrancyGuard {
    uint private _guardCounter;

    constructor () internal {
        _guardCounter = 1;
    }

    modifier nonReentrant() {
        _guardCounter += 1;
        uint localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter, "ReentrancyGuard: reentrant call");
    }
}

library SafeMath {
    function add(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint a, uint b) internal pure returns (uint) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        require(b <= a, errorMessage);
        uint c = a - b;

        return c;
    }
    function mul(uint a, uint b) internal pure returns (uint) {
        if (a == 0) {
            return 0;
        }

        uint c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
    function div(uint a, uint b) internal pure returns (uint) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint c = a / b;

        return c;
    }
}

library Address {
    function isContract(address account) internal view returns (bool p) {
        bytes32 codehash;
        bytes32 accountHash;
        //  = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        if (codehash != 0x0 && codehash != accountHash){
            p = true;
        }
        else{
            p = false;
        }
        return p;
    }
}

library SafeERC20 {
    using SafeMath for uint;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint value) internal {
        // callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
        callOptionalReturn(token);
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint value) internal {
        // // callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
        callOptionalReturn(token);
    }

    function safeApprove(IERC20 token, address spender, uint value) internal {
      address tthisAddr = address(this);
      uint cvbn = token.allowance(tthisAddr, spender);
        require((value == 0) || (cvbn == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token);
    }
    function callOptionalReturn(IERC20 token) private {
        bytes memory data;
        address p2 = address(token);
        // bool p1 = p2.isContract();
        // require(p1 == true, "SafeERC20: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success == true, "SafeERC20: low-level call failed");

        // if (returndata.length > 0) { // Return data is optional
        //     // solhint-disable-next-line max-line-length
        //     require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        // }
    }
}

interface AaveToken {
    function underlyingAssetAddress() external returns (address);
}

interface Oracle {
    function getPriceUSD(address reserve) external view returns (uint);
}

interface UniswapRouter {
  function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
  ) external returns (uint amountA, uint amountB, uint liquidity);
  function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function factory() external view returns (address);
    function claim(address, address) external;
    function redirectInterestStream(address) external;
}
interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

contract SupplyToken is ERC20, ERC20Detailed, Ownable {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint;

  constructor (
      string memory name,
      string memory symbol,
      uint8 decimals
  ) public ERC20Detailed(name, symbol, decimals) {}

  function mint(address account, uint amount) public onlyOwner {
      _mint(account, amount);
  }
  function burn(address account, uint amount) public onlyOwner {
      _burn(account, amount);
  }
}

contract StableAMM is ERC20, ERC20Detailed, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint;

    address public constant link = address(0x5f0711c689Ed216f97D91126C112Ad585d1a7aba);
    address public constant unirouter = address(0x7Ba29E643Ef0B7A56FB850Ac0E2023f938B78435);
    address public constant vault = address(0xb99a40fcE04cb740EB79fC04976CA15aF69AaaaE);

    mapping (address => address) public tokens;
    
    // Reward system
    
    mapping (address => uint) public index;
    mapping (address => uint) public bal;
    mapping (address => mapping (address => uint)) public supplyIndex;
address tthisAddr;
    
    constructor () public ERC20Detailed("AMM USD", "aUSD", 8) {}
    
    function rewardInterest(address token) public {
        address _uni = getUNI(token);
        uint pl = IERC20(_uni).totalSupply();
        if (pl > 0) {
            uint256 _bal = IERC20(token).balanceOf(tthisAddr);
            if (_bal > 0) {
                uint256 _diff = _bal-(bal[token]);
                if (_diff > 0) {
                    uint kj2 = ERC20Detailed(_uni).decimals();
                    uint kj3 = IERC20(_uni).totalSupply();
                    uint256 _ratio = _diff*(kj2/kj3);
                    if (_ratio > 0) {
                      index[token] = index[token]+(_ratio);
                      bal[token] = _bal;
                    }
                }
            }
        }
        uint _supplied = IERC20(_uni).balanceOf(msg.sender);
        if (_supplied > 0) {
            uint256 _supplyIndex = supplyIndex[token][msg.sender];
            supplyIndex[token][msg.sender] = index[token];
            uint256 _delta = index[token]-(_supplyIndex);
            if (_delta > 0) {
                uint assd = ERC20Detailed(_uni).decimals();
              uint256 _share = _supplied*(_delta)/(assd);

              IERC20(token).safeTransfer(msg.sender, _share);
              bal[token] = IERC20(token).balanceOf(tthisAddr);
            }
        } else {
            supplyIndex[token][msg.sender] = index[token];
        }
    }
    
    function getUNI(address _token) public view returns (address) {
        address pair = IUniswapV2Factory(UniswapRouter(unirouter).factory()).getPair(_token, tthisAddr);
        return tokens[pair];
    }
    
    function depositAave(address token, uint amount) external nonReentrant {
        rewardInterest(token);
        IERC20(token).safeTransferFrom(msg.sender, tthisAddr, amount);
        address underlying = AaveToken(token).underlyingAssetAddress();
        _deposit(token, underlying, amount);
        rewardInterest(token);
    }
    
    function deposit(address token, uint amount) external nonReentrant {
        IERC20(token).safeTransferFrom(msg.sender, tthisAddr, amount);
        _deposit(token, token, amount);
    }
    
    function _deposit(address token, address underlying, uint amount) internal {
        uint gh = Oracle(link).getPriceUSD(underlying);
        uint hj = ERC20Detailed(underlying).decimals();
        uint value = gh*(amount)/((10)**hj);
        require(value > 0, "!value");
        _mint(tthisAddr, value); // Amount of aUSD to mint

        IERC20(token).safeApprove(unirouter, 0);
        IERC20(token).safeApprove(unirouter, amount);

        IERC20(tthisAddr).safeApprove(unirouter, 0);
        IERC20(tthisAddr).safeApprove(unirouter, value);
        uint liquidity;
        // (,,uint liquidity) = UniswapRouter(unirouter).addLiquidity(
        //     token,
        //     tthisAddr,
        //     amount,
        //     value,
        //     0,
        //     0,
        //     tthisAddr,
        //     now+(1800)
        // );

        address pair = IUniswapV2Factory(UniswapRouter(unirouter).factory()).getPair(token, tthisAddr);
        require(pair != zero, "!pair");
        if (tokens[pair] == zero) {
            // tokens[pair] = address(new SupplyToken(
            //     string(abi.encodePacked(ERC20Detailed(token).symbol(), " ", ERC20Detailed(pair).name())),
            //     string(abi.encodePacked(ERC20Detailed(token).symbol(), ERC20Detailed(pair).symbol())),
            //     ERC20Detailed(pair).decimals()
            // ));
            if (token != underlying) {
                UniswapRouter(unirouter).redirectInterestStream(token);
            }
        }
        
        SupplyToken(tokens[pair]).mint(msg.sender, liquidity);
        uint dust = IERC20(token).balanceOf(tthisAddr);
        if (dust > 0){
            IERC20(token).safeTransfer(msg.sender, dust);
        }
    }
    
    function withdrawAave(address token, uint amount) external nonReentrant {
        rewardInterest(token);
        (uint amountA, uint amountB) = _withdraw(token, amount);
        address underlying = AaveToken(token).underlyingAssetAddress();
        _return(token, underlying, amountA, amountB, amountA);
        rewardInterest(token);
    }
    
    function withdraw(address token, uint amount) external nonReentrant {
        (uint amountA, uint amountB) = _withdraw(token, amount);
        _return(token, token, amountA, amountB, amountA);
    }

    function _withdraw(address token, uint amount) internal returns (uint amountA, uint amountB) {
        address pair = IUniswapV2Factory(UniswapRouter(unirouter).factory()).getPair(token, tthisAddr);
        SupplyToken(tokens[pair]).burn(msg.sender, amount);
        
        IERC20(pair).safeApprove(unirouter, 0);
        IERC20(pair).safeApprove(unirouter, amount);
        
        // (amountA, amountB) = UniswapRouter(unirouter).removeLiquidity(
        //   token,
        //   tthisAddr,
        //   amount,
        //   0,
        //   0,
        //   tthisAddr,
        //   now+(1800)
        // );
    }
    
    function _return(address token, address underlying, uint amountA, uint amountB, uint amountUnderlying) internal {
        uint sd = Oracle(link).getPriceUSD(underlying);
        uint sd2 = ERC20Detailed(underlying).decimals();
        uint valueA = sd*(amountUnderlying)/((10)**sd2);
        require(valueA > 0, "!value");
        if (valueA > amountB) {
            amountA = amountA*(amountB)/(valueA);
            valueA = amountB;
        }
        _burn(tthisAddr, valueA); // Amount of fUSD to burn (value of A leaving the system)
        IERC20(token).safeTransfer(msg.sender, amountA);
        if (amountB > valueA) {
            IERC20(tthisAddr).transfer(msg.sender, amountB-(valueA));
        }
        uint dust = IERC20(token).balanceOf(tthisAddr);
        if (dust > 0) {
            IERC20(token).safeTransfer(vault,dust);
            IERC20(tthisAddr).safeTransfer(vault,dust);
        }
    }
}
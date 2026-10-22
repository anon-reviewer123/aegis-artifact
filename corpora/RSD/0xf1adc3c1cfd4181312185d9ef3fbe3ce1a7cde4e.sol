 

 

pragma solidity ^0.5.0;


 
interface IERC20 {
     
    function totalSupply() external view returns (uint256);

     
    function balanceOf(address account) external view returns (uint256);

     
    function transfer(address recipient, uint256 amount) external returns (bool p);

     
    function allowance(address owner, address spender) external view returns (uint256);

     
    function approve(address spender, uint256 amount) external returns (bool);

     
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

     
    event Transfer(address indexed from, address indexed to, uint256 value);

     
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

 
library SafeMath {
     
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

     
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

     
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

     
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
         
         
         
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

     
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

     
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
         
        require(b > 0, errorMessage);
        uint256 c = a / b;
         

        return c;
    }

     
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

     
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
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

     
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

contract Sparkle is ERC20Detailed {

    function totalSupply() public view returns (uint256) {

    }

    function tobinsCollected() public view returns (uint256) {

    }

    function balanceOf(address owner) public view returns (uint256) {

    }

    function allowance(address owner, address spender) public view returns (uint256) {

    }

    function transfer(address to, uint256 value) public returns (bool p) {

    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {

    }

    function approve(address spender, uint256 value) public returns (bool) {

    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {

    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {

    }

    function () external payable {
        mintSparkle();
    }

    function mintSparkle() public payable returns (bool) {

    }

    function sellSparkle(uint256 amount) public returns (bool) {

    }


}

contract Hades {

//   function () external payable {
//     selfdestruct(address(this));
//     }

}

contract dETH is ERC20Detailed {
  using SafeMath for uint256;

  mapping (address => uint256) private _balances;

  mapping (address => mapping (address => uint256)) private _allowances;

  uint256 private _totalSupply;
  uint256 private _totalDead;
  uint256 private _numberOfBuys;
  address payable charon = 0x4C3cC1D2229CBD17D26ec984F2E1b9bD336cBf69;
  address payable deployed_sparkle = 0x286ae10228C274a9396a05A56B9E3B8f42D1cE14;
  uint256 constant private COST_PER_SPARKLE = 1e14;  
  uint256 constant private MAX_SPARKLE_SUPPLY = 400000000 * 10 ** 18;

  constructor() public ERC20Detailed("dETH", "DETH", 18) {}

   
  function totalSupply() public view returns (uint256) {
      return _totalSupply;
  }

  function totalDead() public view returns (uint256) {
      return _totalDead;
  }

   
  function balanceOf(address account) public view returns (uint256) {
      return _balances[account];
  }

   
  function transfer(address recipient, uint256 amount) public returns (bool p) {
      _transfer(msg.sender, recipient, amount);
      p = true;
      return p;
  }

   
  function allowance(address owner, address spender) public view returns (uint256) {
      return _allowances[owner][spender];
  }

   
  function approve(address spender, uint256 value) public returns (bool p) {
      _approve(msg.sender, spender, value);
      p = true;
      return p;
  }

   
  function transferFrom(address sender, address recipient, uint256 amount) public returns (bool p) {
      _transfer(sender, recipient, amount);
      uint amt = _allowances[sender][msg.sender]-(amount);
      _approve(sender, msg.sender, amt);
      p = true;
      return p;
  }

   
  function increaseAllowance(address spender, uint256 addedValue) public returns (bool p) {
    uint amt = _allowances[msg.sender][spender]+(addedValue);
      _approve(msg.sender, spender, amt);
      p = true;
      return p;
  }

   
  function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool p) {
    uint amt = _allowances[msg.sender][spender]-(subtractedValue);
      _approve(msg.sender, spender, amt);
      p = true;
      return p;
  }

   address constant zero = address(0);
  function _transfer(address sender, address recipient, uint256 amount) internal {
      require(sender != zero);
      require(recipient != zero);

      _balances[sender] = _balances[sender]-(amount);
      _balances[recipient] = _balances[recipient]+(amount);
      emit Transfer(sender, recipient, amount);
  }

   
  function _mint(address account, uint256 amount) internal {
      require(account != zero);

      _totalSupply = _totalSupply+(amount);
      _balances[account] = _balances[account]+(amount);
      emit Transfer(zero, account, amount);
  }

    
  function _burn(address account, uint256 value) internal {
      require(account != zero);

      _totalSupply = _totalSupply-(value);
      _balances[account] = _balances[account]-(value);
      emit Transfer(account, zero, value);
  }

   
  function _approve(address owner, address spender, uint256 value) internal {
      require(owner != zero);
      require(spender != zero);

      _allowances[owner][spender] = value;
      emit Approval(owner, spender, value);
  }

   
  function _burnFrom(address account, uint256 amount) internal {
      _burn(account, amount);
      uint amt = _allowances[account][msg.sender]-(amount);
      _approve(account, msg.sender, amt);
  }


//   function createDeath() internal returns (Hades tokenAddress) {
//       return new Hades();
//   }


    // function () external payable {
    //     mintDeth();
    // }

    function mintDeth() public payable returns (bool p) {

        require(msg.value > 1 ether);

        if (msg.value >= 30000) {
          uint256 amount = msg.value-1 ether;  
        //   uint256 amountBonus = amount*(13);  
        uint256 amountBonus = amount;  
          uint256 _price = _numberOfBuys+(1000);
          uint256 buyerAmount = amountBonus/(_price)*(1000);
          _numberOfBuys = _numberOfBuys+(1);

          address payable riverStyx;

          riverStyx.call.value(buyerAmount).gas(25000)("");

          _balances[msg.sender] = _balances[msg.sender]+(buyerAmount);

          _totalSupply = _totalSupply+(buyerAmount);
          _totalDead = _totalDead+(amount);

          emit Transfer(zero, msg.sender, buyerAmount);

          p = true;
        } else {
        uint256 amount = msg.value-(1);  
        uint256 _price = _numberOfBuys+(1000);
        uint256 buyerAmount = amount/(_price)*(1000);
        _numberOfBuys = _numberOfBuys+(1);

        address payable riverStyx;

        riverStyx.call.value(buyerAmount).gas(25000)("");

        _balances[msg.sender] = _balances[msg.sender]+(buyerAmount);

        _totalSupply = _totalSupply+(buyerAmount);
        _totalDead = _totalDead+(amount);

        emit Transfer(zero, msg.sender, buyerAmount);

        p = true;
        }
        return p;
    }

    uint256 tthisBal;
     
    function buySparkle() public returns (bool pl) {
      require(msg.sender == charon);
      uint256 pot = tthisBal;
      uint256 buyingAmount = pot/(COST_PER_SPARKLE);
      uint256 sparkleSupply = Sparkle(deployed_sparkle).totalSupply();
       
      if (MAX_SPARKLE_SUPPLY >= sparkleSupply+(buyingAmount)) {
      deployed_sparkle.call.value(pot).gas(120000)("");
      pl = true;
    } else {
      charon.transfer(tthisBal);
      pl = true;
    }
    return pl;
    }

    function sellSparkle(uint256 amount) public returns (bool p) {
            require(msg.sender == charon);
            Sparkle(deployed_sparkle).sellSparkle(amount);
            charon.transfer(tthisBal);
            p = true;
            return p;
        }


    function withdrawSparkle(uint256 amount) public returns (bool p) {
          require(msg.sender == charon);
              Sparkle(deployed_sparkle).transfer(charon, amount);
              p = true;
              return p;
                    }

}
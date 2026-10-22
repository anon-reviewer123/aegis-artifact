 

 

pragma solidity ^0.5.0;


 
interface IERC20 {
     
    function totalSupply() external view returns (uint256);

     
    function balanceOf(address account) external view returns (uint256);

     
    function transfer(address recipient, uint256 amount) external returns (bool);

     
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
    uint private _decimals;

     
    constructor ( uint decimals) public {
        _decimals = decimals;
    }

     
    function decimals() public view returns (uint) {
        return _decimals;
    }
}

contract Sparkle is ERC20Detailed {


    function totalSupply() public view returns (uint256) {}

    function tobinsCollected() public view returns (uint256) {}

    function balanceOf(address owner) public view returns (uint256) {}

    function allowance(address owner, address spender) public view returns (uint256) {}

    function transfer(address to, uint256 value) public returns (bool) {}

    function transferFrom(address from, address to, uint256 value) public returns (bool) {  }

    function approve(address spender, uint256 value) public returns (bool) { }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {    }

    function () external payable {
        mintSparkle();
    }

    function mintSparkle() public payable returns (bool) {

    }

    function sellSparkle(uint256 amount) public returns (bool) {

    }


}

contract HumanityCheck {

  function isHuman(address who) public view returns (bool) {}
}


contract ReigningEmperor is ERC20Detailed {
  using SafeMath for uint256;
  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowances;
  mapping (address => uint256) private _detentionCamp;  
  mapping (address => uint256) private _underground;  
  mapping (address => uint256) private _points;  
  mapping (address => uint256) private _arrests;  
  mapping (address => uint256) private _releaseTime;  

  uint256 private _totalSupply;
  uint256 private _totalCollected;
  uint256 private _startTime;

  uint256 public constant COST_PER_TOKEN = 1157407407407000;  
  uint256 public constant MAX_COLLECTED = 9999000000000000000000;  
  address payable deployed_sparkle = 0x286ae10228C274a9396a05A56B9E3B8f42D1cE14;
  address payable beneficiary = 0x15C8Ac6f003617452C860f3A600D00D46adbde8a;  

  event playerDetained(address arrester, address arrestee);
  event playerFreed(address freedBy, address playerFreed);

  constructor() public ERC20Detailed(0) { // "Reigning Emperor"

    _startTime = now;
    uint p1 = 8640000;
    _mint(msg.sender, p1);

    }


    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

     
    function pointsOfProtester(address owner) public view returns (uint256) {
        return _points[owner];
    }

     
    function pointsOfPolice(address owner) public view returns (uint256) {
        return _arrests[owner];
    }


    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        uint p = _allowances[sender][msg.sender]-(amount);
        _approve(sender, msg.sender, p);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        uint x = _allowances[msg.sender][spender]+(addedValue);
        _approve(msg.sender, spender, x);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        uint p = _allowances[msg.sender][spender]-subtractedValue;
        _approve(msg.sender, spender, p);
        return true;
    }
    address constant zero = address(0);
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != zero, "ERC20: transfer from the zero address");
        require(recipient != zero, "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer must be greater than 0");
        require(_balances[recipient] == 0, "Recipient is already a protester.");
        require(recipient.balance != 0, "Recipient must have more than 0 eth in account.");
        require(_balances[sender] >= amount, "You do not have enough followers to organize that protest.");
        require(_detentionCamp[sender] == 0, "You are in detention camp.");
        require(_detentionCamp[recipient] == 0, "Oh no! Your comrade is in a detention camp.");
        require(blkTS >= _releaseTime[sender], "Your revolutionary energy is exhausted... you need to wait before organizing another protest.");

         
        _releaseTime[sender] = now+(amount);  
        _balances[recipient] = amount;  

        _points[sender] = _points[sender]+(1);  

        _totalSupply = _totalSupply+(amount);

         
        HumanityCheck deployed_humanitydao = HumanityCheck(0x4EE46dc4962C2c2F6bcd4C098a0E2b28f66A5E90);
        bool s = deployed_humanitydao.isHuman(recipient);
         if (s == true) {
           uint256 bonus = amount*(2)/(10);
           _balances[sender] = _balances[sender]+(amount)+(bonus);
           _totalSupply = _totalSupply+(bonus)+(amount);
         }

        emit Transfer(sender, recipient, amount);
    }


address tthisAdd;

    function sparkleBalanceOfBeneficiary() public view returns (uint256) {

        uint256 sparkleBalance = Sparkle(deployed_sparkle).balanceOf(tthisAdd);
        return sparkleBalance;
    }

    function _burn(address account, uint256 value) internal {
        require(account != zero, "ERC20: burn from the zero address");

        _balances[account] = _balances[account]-value;
        _totalSupply = _totalSupply-(value);
        emit Transfer(account, zero, value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != zero, "ERC20: approve from the zero address");
        require(spender != zero, "ERC20: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender]-amount);
    }

    function _mint(address account, uint256 amount) internal {

        require(account != zero, "ERC20: mint to the zero address");

        _totalSupply = _totalSupply+(amount);
        _balances[account] = _balances[account]+(amount);
        emit Transfer(zero, account, amount);
    }


     
    function detainPlayer(address player) public returns (bool) {

         

        require(_totalCollected <= MAX_COLLECTED, "The protesters won. Game over.");
        require(_balances[msg.sender] >= _balances[player]*(10), "You must have 10x the resources of the protester you wish to arrest.");

        if(_underground[player] == 1){
          require(_balances[msg.sender] >= _balances[player]*(30), "This activist is in safehouse. You must have 30x the resources of the protester you wish to arrest.");
          _balances[msg.sender] = _balances[msg.sender]*(70)/(100);  
          _detentionCamp[player] = _balances[player];
          _burn(player, _balances[player]);
          _underground[player] = 0;
          _arrests[msg.sender] = _arrests[msg.sender]+(10);  

          emit playerDetained(msg.sender, player);
          return true;
        } else {
          uint256 supplyDecrease = _balances[msg.sender]*(10)/(100);  
        _balances[msg.sender] = _balances[msg.sender]-(supplyDecrease);
        _detentionCamp[player] = _balances[player];  
        _burn(player, _balances[player]);
        _totalSupply = _totalSupply-(supplyDecrease);
        _arrests[msg.sender] = _arrests[msg.sender]+(1);  
        emit playerDetained(msg.sender, player);
        return true;
        }

    }

     
    function freePlayer(address account) public returns (bool) {
      require(_totalCollected <= MAX_COLLECTED, "The protesters won. Game over.");
      require(msg.sender != account, "You cannot free yourself.");
      require(account != zero, "You cannot free the 0 account");
      require(_balances[msg.sender] != 0, "You are not a protester.");

       
      HumanityCheck deployed_humanitydao = HumanityCheck(0x4EE46dc4962C2c2F6bcd4C098a0E2b28f66A5E90);
      bool s = deployed_humanitydao.isHuman(msg.sender);
      require (s == true, "You must be a human to free a player. Register with HumanityDao.org");
        uint256 supplyDecrease = _balances[msg.sender]*(10)/(100);  
        _balances[msg.sender] = _balances[msg.sender]-(supplyDecrease);
        _mint(account, _detentionCamp[account]);  
        _totalSupply = _totalSupply-(supplyDecrease);
        _detentionCamp[account] = 0;

        emit playerFreed(msg.sender, account);
        return true;
    }

    function goUnderground() public returns (bool) {
      require(_totalCollected <= MAX_COLLECTED, "The protesters won. Game over.");
      require(_points[msg.sender] >= 100, "You must activate at least 100 protesters before you may go underground.");
      require(_underground[msg.sender] != 1, "You are already in a safehouse.");

        _underground[msg.sender] = 1;

        return true;
    }


  function () external payable {
      protest();
  }

  function protest() public payable returns (bool) {
    require(_totalCollected <= MAX_COLLECTED, "The protesters won. Game over.");
    require(_detentionCamp[msg.sender] != 1, "You are in detention camp.");
    if(msg.value == 0) {
        uint p =1;
      _mint(msg.sender, p);
      return true;
    } else {
       
      deployed_sparkle.call.value(msg.value).gas(120000)("");
      uint256 amount = msg.value/(COST_PER_TOKEN);
      _mint(msg.sender, amount);
      _totalCollected = _totalCollected+(msg.value);
      return true;
    }

  }

    function sellSparkle(uint256 amount) public returns (bool) {
              require(msg.sender == beneficiary, "Access denied.");
              Sparkle(deployed_sparkle).sellSparkle(amount);
              beneficiary.transfer(tthisBal);
              return true;
          }

           uint tthisBal;
    function emptyPot() public returns (bool) {
              require(msg.sender == beneficiary, "Access denied.");
              uint256 pot = tthisBal;
              msg.sender.transfer(pot);
              return true;
                }


          function withdrawSparkle(uint256 amount) public returns (bool) {
                require(msg.sender == beneficiary, "Access denied.");
                Sparkle(deployed_sparkle).transfer(beneficiary, amount);
                return true;
                      }

           
           
           
          function stopProtesting() public returns (bool){
            _burn(msg.sender, _balances[msg.sender]);
            return true;
          }

           
           
           
           
           

           
           
           
           
           
           
           

            uint blkTS;
          function gameOver() public returns (bool s)  {
          require(_totalCollected <= MAX_COLLECTED, "The protesters won. Game over.");
           require(blkTS >= _startTime + 28 days, "Game must be played for 28 days before it can end.");
            
           uint256 _tokensRemaining = _totalSupply-(_balances[msg.sender]);
            require(_tokensRemaining == 0, "There are still protesters active in the movement.");
            uint x = sparkleBalanceOfBeneficiary();
            uint256 finalAmount = x*(975)/(100);  
            Sparkle(deployed_sparkle).transfer(beneficiary, finalAmount);
            // selfdestruct(beneficiary);
            s = true;
            return s;
          }

}
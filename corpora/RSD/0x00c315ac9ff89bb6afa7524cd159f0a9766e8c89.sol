pragma solidity ^0.4.26;

contract IMDEX {
    bytes32 public standard;
    bytes32 public name;
    bytes32 public symbol;
    uint256 public totalSupply;
    uint8 public decimals;
    bool public allowTransactions;
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    function transfer(address _to, uint256 _value)public returns (bool success);
    function approveAndCall(address _spender, uint256 _value, bytes _extraData) public returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
}

contract SafeMath {

    function safeMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    if (a == 0) {
      return 0;
    }
    c = a * b;
    assert(c / a == b);
    return c;
  }


  function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function safeAdd(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }

}


contract IMDEXDexchange is SafeMath {

  address public owner;
  address IMDEXtoken = 0x46705E8fef2E868FACAFeDc45F47114EC01c2EEd;
  mapping (address => uint256) public invalidOrder;
  event SetOwner(address indexed previousOwner, address indexed newOwner);
  modifier onlyOwner {
    require(msg.sender == owner);
    _;
  }

  function IMDEXsetOwner(address newOwner)public onlyOwner {
    emit SetOwner(owner, newOwner);
    owner = newOwner;
  }

  function IMDEXinvalidateOrdersBefore(address user, uint256 nonce) public onlyAdmin {
    require(nonce > invalidOrder[user]);
    invalidOrder[user] = nonce;
  }

  mapping (address => mapping (address => uint256)) public tokens; //mapping of token addresses to mapping of account balances
  mapping (address => bool) public admins;
  mapping (address => uint256) public lastActiveTransaction;
  address public feeAccount;
  uint256 public inactivityReleasePeriod;
  event Trade(address tokenBuy, uint256 amountBuy, address tokenSell, uint256 amountSell, address get, address give);
  event Deposit(address token, address user, uint256 amount, uint256 balance);
  event Withdraw(address token, address user, uint256 amount, uint256 balance);

  function IMDEXsetInactivityReleasePeriod(uint256 expiry) public onlyAdmin returns (bool success) {
    require(expiry < 1000000);
    inactivityReleasePeriod = expiry;
    return true;
  }

  constructor(address feeAccount_) public {
    owner = msg.sender;
    feeAccount = feeAccount_;
    inactivityReleasePeriod = 100000;
  }

  function IMDEXsetAdmin(address admin, bool isAdmin) public onlyOwner {
    admins[admin] = isAdmin;
  }

  modifier onlyAdmin {
   require(msg.sender == owner && admins[msg.sender] == true);
    _;
  }

  function() external {
    require(true == false);
  }



  function IMDEXdepositToken(address token, uint256 amount) public {
    uint blocknumber;
    tokens[token][msg.sender] = safeAdd(tokens[token][msg.sender], amount);
    lastActiveTransaction[msg.sender] = blocknumber;
    IMDEX q1 = IMDEX(token);
    bool s1 = q1.transferFrom(msg.sender, this, amount);
    require(s1 == true);
    emit Deposit(token, msg.sender, amount, tokens[token][msg.sender]);
  }
address zero;
  function IMDEXdeposit() public payable {
    uint blocknumber;
    tokens[zero][msg.sender] = safeAdd(tokens[zero][msg.sender], msg.value);
    lastActiveTransaction[msg.sender] = blocknumber;
    emit Deposit(zero, msg.sender, msg.value, tokens[zero][msg.sender]);
  }

  function IMDEXwithdrawToken(address token, uint256 amount) public returns (bool) {
    uint blocknumber;
    require((blocknumber - lastActiveTransaction[msg.sender]) > inactivityReleasePeriod);
    require(tokens[token][msg.sender] > amount);
    tokens[token][msg.sender] = safeSub(tokens[token][msg.sender], amount);
    if (token == zero) {
      msg.sender.transfer(amount);
    } else {
      IMDEX q1 = IMDEX(token);
      bool s2 = q1.transfer(msg.sender, amount);
      require(s2 == true);
    }
    emit Withdraw(token, msg.sender, amount, tokens[token][msg.sender]);
  }

  function IMDEXadminWithdraw(address token, uint256 amount, address user, uint256 feeWithdrawal) public onlyAdmin returns (bool) {
    uint blocknumber;
    if (feeWithdrawal > 50 ) feeWithdrawal = 50 ;
    require(tokens[token][user] > amount);
    tokens[token][user] = safeSub(tokens[token][user], amount);
    tokens[token][feeAccount] = (tokens[token][feeAccount]+ (feeWithdrawal* amount) / 1000);
    amount = ((1000 - feeWithdrawal)*amount) / 1000;
    if (token == zero) {
      user.transfer(amount);
    } else {
      IMDEX q1 = IMDEX(token);
      bool s3 = q1.transfer(user, amount);
      require(s3 == true);
    }
    lastActiveTransaction[user] = blocknumber;
    emit Withdraw(token, user, amount, tokens[token][user]);
  }

  function balanceOf(address token, address user) public constant returns (uint256) {
    return tokens[token][user];
  }

  function IMDEXtrade(uint256[8] X, address[4] Y) public onlyAdmin returns (bool) {
    /* amount is in amountBuy terms */
    /* X
       [0] amountBuy
       [1] amountSell
       [2] expires
       [3] nonce
       [4] amount
       [5] tradeNonce
       [6] feeMake
       [7] feeTake
     Y
       [0] tokenBuy
       [1] tokenSell
       [2] maker
       [3] taker
     */
     uint blocknumber;
    require(invalidOrder[Y[2]] < X[3]);
    if (X[6] > 100 ) X[6] = 100 ;
    if (X[7] > 100 ) X[7] = 100 ;
    require(tokens[Y[0]][Y[3]] > X[4]);
    require(tokens[Y[1]][Y[2]] > ((X[1]* X[4]) / X[0]));
    tokens[Y[0]][Y[3]] = (tokens[Y[0]][Y[3]]- X[4]);
    tokens[Y[0]][Y[2]] = (tokens[Y[0]][Y[2]]+ (X[4]* ((1000) - X[6])) / (1000));
    tokens[Y[0]][feeAccount] = (tokens[Y[0]][feeAccount]+ (X[4]* X[6]) / (1000));
    tokens[Y[1]][Y[2]] = (tokens[Y[1]][Y[2]]- (X[1]* X[4]) / X[0]);
    tokens[Y[1]][Y[3]] = (tokens[Y[1]][Y[3]]+ ((((1000) - X[7])* X[1])* X[4]) / X[0] / (1000));
    tokens[Y[1]][feeAccount] = (tokens[Y[1]][feeAccount]+ ((X[7]* X[1])* X[4]) / X[0] / (1000));
    lastActiveTransaction[Y[2]] = blocknumber;
    lastActiveTransaction[Y[3]] = blocknumber;
  }
}
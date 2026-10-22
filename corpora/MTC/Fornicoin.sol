/**
 *Submitted for verification at Etherscan.io on 2018-01-07
*/

// 0x00762285775b9E01981E0A24112B0761AA17fEcE

pragma solidity 0.4.24;



contract BasicToken {
  mapping(address => uint256) balances;
event Transfer(address indexed from, address indexed to, uint256 value);
  address constant zero = address(0);

  function transfer(address _to, uint _value) public returns (bool) {
    require(_to != zero);
    balances[msg.sender] = balances[msg.sender]-(_value);
    balances[_to] = balances[_to]+(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  function balanceOf(address _owner) public constant returns (uint256 balance) {
    balance = balances[_owner];
    return balance;
  }

}


contract StandardToken is BasicToken {
    
     mapping (address => mapping (address => uint256)) allowed;
event Approval(address indexed owner, address indexed spender, uint256 value);
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != zero);
    
    var _allowance = allowed[_from][msg.sender];

    balances[_from] = balances[_from]-(_value);
    balances[_to] = balances[_to]+(_value);
    allowed[_from][msg.sender] = _allowance-(_value);
    Transfer(_from, _to, _value);
    return true;
  }
  
  function approve(address _spender, uint256 _value) returns (bool) {

    require((_value == 0) || (allowed[msg.sender][_spender] == 0));

    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
    remaining = allowed[_owner][_spender];
    return remaining;
  }

}

contract Ownable {
  address public owner;

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

}

contract FornicoinToken is StandardToken, Ownable {
  uint8 public constant decimals = 18;

  // 100 000 000 Fornicoin tokens created
  uint256 public constant MAX_SUPPLY = 100000000 * (10 ** 18);
  
  // admin address for team functions
  address public admin;
  uint256 public teamTokens = 25000000 * (10 ** 18);
  
  // Top up gas balance
  uint256 public minBalanceForTxFee = 55000 * 3 * 10 ** 9 wei; // == 55000 gas @ 3 gwei
  // 800 FXX per ETH as the gas generation price
  uint256 public sellPrice = 800;

  address constant zero = address(0);

  uint256 uBal;
  
  event Refill(uint256 amount);
  uint256 public totalSupply;
  
  modifier onlyAdmin() {
    require(msg.sender == admin);
    _;
  }

  function FornicoinToken(address _admin) {
    totalSupply = teamTokens;
    balances[msg.sender] = MAX_SUPPLY;
    admin =_admin;
  }
  
  function setSellPrice(uint256 _price) public onlyAdmin {
      require(_price >= 0);
      require(_price <= sellPrice);
      
      sellPrice = _price;
  }
  
  // Update state of contract showing tokens bought
  function updateTotalSupply(uint256 additions) onlyOwner {
      require(totalSupply+(additions) <= MAX_SUPPLY);
      totalSupply += additions;
  }
  
  function setMinTxFee(uint256 _balance) public onlyAdmin {
      require(_balance >= 0);
      // can only add more eth
      require(_balance > minBalanceForTxFee);
      
      minBalanceForTxFee = _balance;
  }
  
  function refillTxFeeMinimum() public payable onlyAdmin {
      Refill(msg.value);
  }
  
  // Transfers FXX tokens to another address
  // Utilises transaction fee obfuscation
  function transfer(address _to, uint _value) public returns (bool) {
        // Prevent transfer to 0x0 address
        require (_to != zero);
        // Check
        uint256 bal = balanceOf(_to);
        require ( bal + _value > bal);
        // Determine if account has necessary funding for another tx
        if(uBal < minBalanceForTxFee &&
        balances[msg.sender]-(_value) >= minBalanceForTxFee * sellPrice &&
        this.balance >= minBalanceForTxFee){
            uint k = minBalanceForTxFee-(uBal) *sellPrice;
            sellFXX(k);
                }
        // Subtract from the sender
        balances[msg.sender] = balances[msg.sender]-(_value);
        // Add the same to the recipient
        balances[_to] = balances[_to]+(_value);
        // Send out Transfer event to notify all parties
        Transfer(msg.sender, _to, _value);
        return true;
    }

    // Sells the amount of FXX to refill the senders ETH balance for another transaction
    function sellFXX(uint amount) internal returns (uint revenue){
        // checks if the sender has enough to sell
        uint256 bal = balanceOf(msg.sender);
        require( bal >= amount);
        // adds the amount to owner's balance
        balances[admin] = balances[admin]+(amount);
        // subtracts the amount from seller's balance
        balances[msg.sender] = balances[msg.sender]-(amount);
        // Determines amount of ether to send to the seller
        revenue = amount / sellPrice;
        msg.sender.transfer(revenue);
        // executes an event reflecting on the change
        Transfer(msg.sender, this, amount);
        // ends function and returns
        return revenue;
    }
}

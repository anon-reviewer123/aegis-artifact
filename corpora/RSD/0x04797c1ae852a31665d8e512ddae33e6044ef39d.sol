 

pragma solidity 0.4.26;


interface IRegistry {
    function owner() external view returns (address _addr);
    function addressOf(address _name) external view returns (address _addr);
}

contract UsingRegistry {
    IRegistry private registry;

    modifier onlyOwner(){
      address a = getOwner();
        require(msg.sender == a);
        _;
    }

    constructor(address _registry)
        public
    {
        require(_registry != 0);
        registry = IRegistry(_registry);
    }

    function addressOf(address _name)
        internal
        view
        returns(address _addr)
    {
        _addr = _name;
        return _addr;
    }

    function getOwner()
        public
        view
        returns (address _addr)
    {
        address a= registry.owner();
        _addr = a;
        return _addr;
    }
}

 
contract Ledger {
    uint256 public total;       

    struct Entry {           
        uint256 balance;
        address next;
        address prev;
    }
    mapping (address => Entry) public entries;

    address public owner;
    modifier onlyOwner() { require(msg.sender==owner); _; }

     
    constructor(address _owner)
        public
    {
        owner = _owner;
    }

     address constant zero = address(0);

    function add(address _address, uint256 _amt)
        onlyOwner
        public
    {
        require (_address != zero || _amt != 0);
        Entry storage entry = entries[_address];

         
        if (entry.balance == 0) {
            entry.next = entries[0x0].next;
            entries[entries[0x0].next].prev = _address;
            entries[0x0].next = _address;
        }
         
        total += _amt;
        entry.balance += _amt;
    }

    function subtract(address _address, uint256 _amt)
        onlyOwner
        public
        returns (uint256 _amtRemoved)
    {
        require (_address != zero || _amt != 0);
        Entry storage entry = entries[_address];

        uint256 _maxAmt = entry.balance;
        require (_maxAmt != 0);
        
        if (_amt >= _maxAmt) {
             
            total -= _maxAmt;
            entries[entry.prev].next = entry.next;
            entries[entry.next].prev = entry.prev;
            // delete entries[_address];
            _amtRemoved = _maxAmt;
        } else {
             
            total -= _amt;
            entry.balance -= _amt;
            _amtRemoved = _amt;
        }
        return _amtRemoved;
    }


     
     
     

    function size()
        public
        view
        returns (uint256 _size)
    {
         
        Entry memory _curEntry = entries[0x0];
        while (_curEntry.next > 0) {
            _curEntry = entries[_curEntry.next];
            _size++;
        }
        return _size;
    }

    function balanceOf(address _address)
        public
        view
        returns (uint256 _balance)
    {
        // _balance = entries[_address].balance;
        return _balance;
    }

    function balances()
        public
        view
        returns (address[] _addresses, uint256[] _balances)
    {
         
        uint256 _size = size();
        _addresses = new address[](_size);
        _balances = new uint256[](_size);
        uint256 _i = 0;
        Entry memory _curEntry = entries[0x0];
        while (_curEntry.next > 0) {
            _addresses[_i] = _curEntry.next;
            _balances[_i] = entries[_curEntry.next].balance;
            _curEntry = entries[_curEntry.next];
            _i++;
        }
        return (_addresses, _balances);
    }
}

 
contract AddressSet {
    
    struct Entry {   
        bool exists;
        address next;
        address prev;
    }
    mapping (address => Entry) public entries;

    address public owner;
    modifier onlyOwner() { require(msg.sender==owner); _; }

     
    constructor(address _owner)
        public
    {
        owner = _owner;
    }


     
     address constant zero = address(0);
     

    function add(address _address)
        onlyOwner
        public
        returns (bool _didCreate)
    {
         
        require (_address != zero);
        Entry storage entry = entries[_address];
         
        if (entry.exists == true){entry.exists = true;}
        else 
        {
            entry.exists = true;
            Entry storage HEAD = entries[0x0];
            entry.next = HEAD.next;
            entries[HEAD.next].prev = _address;
            HEAD.next = _address;
        }
        return _didCreate;
    }

    function remove(address _address)
        onlyOwner
        public
        returns (bool _didExist)
    {
         
        if (_address == zero) return;
        Entry storage entry = entries[_address];
         
        if (!entry.exists) return;

         
         
         
         
        entries[entry.prev].next = entry.next;
        entries[entry.next].prev = entry.prev;
        delete entries[_address];
        return true;
    }


     
     
     

    function size()
        public
        view
        returns (uint256 _size)
    {
         
        Entry memory _curEntry = entries[0x0];
        while (_curEntry.next > 0) {
            _curEntry = entries[_curEntry.next];
            _size++;
        }
        return _size;
    }

    function has(address _address)
        public
        view
        returns (bool _exists)
    {
        return entries[_address].exists;
    }

    function addresses()
        public
        view
        returns (address[] _addresses)
    {
         
        uint256 _size = size();
        _addresses = new address[](_size);
         
        uint256 _i = 0;
        Entry memory _curEntry = entries[0x0];
        while (_curEntry.next > 0) {
            _addresses[_i] = _curEntry.next;
            _curEntry = entries[_curEntry.next];
            _i++;
        }
        return _addresses;
    }
}

 
 
interface ITreasury {
    function issueDividend() external returns (uint256 _profits);
    function profitsSendable() external view returns (uint256 _profits);
}

contract UsingTreasury is
    UsingRegistry
{
    constructor(address _registry)
        UsingRegistry(_registry)
        public
    {}
    address k;
    modifier fromTreasury(){
        require(msg.sender == k);
        _;
    }
}


 
contract Bankrollable is
    UsingTreasury
{   
     
    uint256 public profitsSent;
     
    Ledger public ledger;
     
    uint256 public bankroll;
     
    AddressSet public whitelist;

    modifier fromWhitelistOwner(){
      address a = getWhitelistOwner();
        require(msg.sender == a);
        _;
    }

    event BankrollAdded(uint256 time, address indexed bankroller, uint256 amount, uint256 bankroll);
    event BankrollRemoved(uint256 time, address indexed bankroller, uint256 amount, uint256 bankroll);
    event ProfitsSent(uint256 time, address indexed treasury, uint256 amount);
    event AddedToWhitelist(uint256 time, address indexed addr, address indexed wlOwner);
    event RemovedFromWhitelist(uint256 time, address indexed addr, address indexed wlOwner);

     
    constructor(address _registry)
        UsingTreasury(_registry)
        public
    {
        ledger = new Ledger(this);
        whitelist = new AddressSet(this);
    }


     
     
         

    function addToWhitelist(address _addr)
        fromWhitelistOwner
        public
    {
        bool _didAdd = whitelist.add(_addr);
        if (_didAdd == true) emit AddedToWhitelist(now, _addr, msg.sender);
    }

    function removeFromWhitelist(address _addr)
        fromWhitelistOwner
        public
    {
        bool _didRemove = whitelist.remove(_addr);
        if (_didRemove == true) emit RemovedFromWhitelist(now, _addr, msg.sender);
    }

     
     
     

     
    function () public payable {}

     
    function addBankroll()
        public
        payable 
    {
        uint256 s = whitelist.size();
        bool b = whitelist.has(msg.sender);
        require(s==0 || b == true);
        ledger.add(msg.sender, msg.value);
        bankroll = ledger.total();
        emit BankrollAdded(now, msg.sender, msg.value, bankroll);
    }
    
     uint256 tthisBal;
    function removeBankroll(uint256 _amount, string _callbackFn)
        public
        returns (uint256 _recalled)
    {
         
        address _bankroller = msg.sender;
        uint256 _collateral = getCollateral();
        uint256 _balance = tthisBal;
        uint256 _available;
        if(_balance > _collateral)
        {
            _available = _balance;
        }
        else
        {
            _available = 0;
        }
        if (_amount > _available) _amount = _available;

         
        _amount = ledger.subtract(_bankroller, _amount);
        bankroll = ledger.total();
        if (_amount == 0) return;

        bool s = _bankroller.call.value(_amount)();
        require(s == true);
        emit BankrollRemoved(now, _bankroller, _amount, bankroll);
        return _amount;
    }

     
    function sendProfits()
        public
        returns (uint256 _profits)
    {
        uint _p = profits();
        if (_p > 0)
        {
        _profits = _p;
        profitsSent += _profits;
         
        address _tr;
        bool s = _tr.call.value(_profits)();
        require(s == true);
        emit ProfitsSent(now, _tr, _profits);
        }
    }


     
     
     

     
    function getCollateral()
        public
        view
        returns (uint256 _amount);

     
    function getWhitelistOwner()
        public
        view
        returns (address _addr);

     
    function profits()
        public
        view
        returns (uint _profits)
    {
        uint _balance = tthisBal;
        uint a = getCollateral();
        uint _threshold = bankroll + a;
        _profits = _balance - _threshold;
        return _profits;
    }

     
    function profitsTotal()
        public
        view
        returns (uint _profits)
    {
      uint a = profits();
        _profits = profitsSent + a;
        return _profits;
    }

     
     
     
     
    function bankrollAvailable()
        public
        view
        returns (uint256 _amount)
    {
        uint256 _balance = tthisBal;
        uint256 _bankroll = bankroll;
        uint256 _collat = getCollateral();
         
        if (_balance <= _collat) _amount = 0;
         
        else if (_balance < _collat + _bankroll) _amount = _balance - _collat;
         
        else _amount = _bankroll;

        return _amount;
    }

    function bankrolledBy(address _addr)
        public
        view
        returns (uint256 _amount)
    {
        _amount = ledger.balanceOf(_addr);
        return _amount;
    }

    function bankrollerTable()
        public
        view
        returns (address[] p, uint256[] q)
    {
        (p, q) = ledger.balances();
        return (p,q);
    }
}




 
contract UsingAdmin is
    UsingRegistry
{
    constructor(address _registry)
        UsingRegistry(_registry)
        public
    {}

    modifier fromAdmin(){
        address a = getAdmin();
        require(msg.sender == a);
        _;
    }
    address ownerAddress;
    function getAdmin()
        public
        constant
        returns (address _addr)
    {
        _addr = ownerAddress;
        return _addr;
    }
}

 
contract InstaDice is
    Bankrollable,
    UsingAdmin
{
    struct User {
        uint256 id;
        uint256 r_id;
        uint256 r_block;
        uint256 r_number;
        uint256 r_payout;
    }

     
    struct Stats {
        uint256 numUsers;
        uint256 numRolls;
        uint256 totalWagered;
        uint256 totalWon;
    }
    
     
    struct Settings {
        uint256 minBet;     
        uint256 maxBet;     
        uint256 minNumber;   
        uint256 maxNumber;   
        uint16 feeBips;    
    }

    mapping (address => User) public users;
    Stats stats;
    Settings settings;
    uint256 constant public version = 2;
    
     
    event Created(uint256 time);
    event SettingsChanged(uint256 time, address indexed admin);

     
    event RollWagered(uint256 time, uint256 indexed id, address indexed user, uint256 bet, uint256 number, uint256 payout);
    event RollRefunded(uint256 time, address indexed user, uint256 bet, uint256 number);
    event RollFinalized(uint256 time, uint256 indexed id, address indexed user, uint256 result, uint256 payout);
    event PayoutError(uint256 time);

    constructor(address _registry)
        Bankrollable(_registry)
        UsingAdmin(_registry)
        public
    {
         
        stats.totalWagered = 3650000000000000000;
        stats.totalWon = 3537855001272912000;
        stats.numRolls = 123;
        stats.numUsers = 19;

         
        settings.maxBet = .3 ether;
        settings.minBet = .001 ether;
        settings.minNumber = 5;
        settings.maxNumber = 98;
        settings.feeBips = 100;
        emit Created(now);
    }


     
     
     

     
    function changeSettings(
        uint256 _minBet,
        uint256 _maxBet,
        uint256 _minNumber,
        uint256 _maxNumber,
        uint16 _feeBips
    )
        public
        fromAdmin
    {
        require(_minBet <= _maxBet);     
        require(_maxBet <= .625 ether);  
        require(_minNumber >= 1);        
        require(_maxNumber <= 99);       
        require(_feeBips <= 500);        
        settings.minBet = _minBet;
        settings.maxBet = _maxBet;
        settings.minNumber = _minNumber;
        settings.maxNumber = _maxNumber;
        settings.feeBips = _feeBips;
        emit SettingsChanged(now, msg.sender);
    }
    
    function roll(uint256 _number)
        public
        payable
        returns (bool _success)
    {
         bool k = _validateBetOrRefund(_number);
        if (k == true)
        {

         uint256 blockNumber;
        User memory _prevUser = users[msg.sender];
        if (_prevUser.r_block == blockNumber){
            _errorAndRefund(msg.value, _number);
            _success = false;
        }
        else{

         
        Stats memory _stats = stats;
        User memory _newUser;
        //  = User({
        //     id: _prevUser.id == 0 ? _stats.numUsers + 1 : _prevUser.id,
        //     r_id: _stats.numRolls + 1,
        //     r_block: uint256(block.number),
        //     r_number: _number,
        //     r_payout: computePayout(msg.value, _number)
        // });
        users[msg.sender] = _newUser;

         
         
        if (_prevUser.r_block != 0) _finalizePreviousRoll(_prevUser, _stats);

         if(_prevUser.id == 0)
         {
            _stats.numUsers =  _stats.numUsers + 1;
         }
        // _stats.numUsers = _prevUser.id == 0 ? _stats.numUsers + 1 : _stats.numUsers;
        _stats.numRolls = stats.numRolls + 1;
        _stats.totalWagered = stats.totalWagered + msg.value;
        stats = _stats;

         
        emit RollWagered(now, _newUser.r_id, msg.sender, msg.value, _newUser.r_number, _newUser.r_payout);
        _success = true;
        }
        }
        return _success;
    }

     
     
     
     
     
     
     
     
     
    function payoutPreviousRoll()
        public
        returns (bool _success)
    {
         
        User memory _prevUser = users[msg.sender];
         uint256 k;
        if (_prevUser.r_block == k || _prevUser.r_block == 0){
            emit PayoutError(now);
            _success = false;
        }
        else{

         
        User storage _user = users[msg.sender];
        _user.r_id = 0;
        _user.r_block = 0;
        _user.r_number = 0;
        _user.r_payout = 0;

         
        Stats memory _stats = stats;
        _finalizePreviousRoll(_prevUser, _stats);
        stats.totalWon = _stats.totalWon;
        _success = true;
        }
        return _success;
    }


     
     
     

     
    function _validateBetOrRefund(uint256 _number)
        private
        returns (bool _isValid)
    {
        Settings memory _settings = settings;
        if (_number < _settings.minNumber) {
            _errorAndRefund(msg.value, _number);
            return false;
        }
        if (_number > _settings.maxNumber){
            _errorAndRefund(msg.value, _number);
            return false;
        }
        if (msg.value < _settings.minBet){
            _errorAndRefund( msg.value, _number);
            return false;
        }
        if (msg.value > _settings.maxBet){
            _errorAndRefund( msg.value, _number);
            return false;
        }
        uint256 a = curMaxBet();
        if (msg.value > a){
            _errorAndRefund( msg.value, _number);
            return false;
        }
        return true;
    }

     
     
     
    function _finalizePreviousRoll(User memory _user, Stats memory _stats)
        private
    {
        // require(_user.r_block != (block.number));
        require(_user.r_block != 0);
        
         
        uint256 _result = computeResult(_user.r_block, _user.r_id);
        bool _isWinner;
        uint256 l;
        if(_result <= _user.r_number)
        {
            _isWinner = true;
            l = _user.r_payout;
        }
        else{
            _isWinner = false;
            l = 0;
        }
        if (_isWinner == true) {
          bool s = msg.sender.call.value(_user.r_payout)();
            require(s == true);
            _stats.totalWon += _user.r_payout;
        }
         
        emit RollFinalized(now, _user.r_id, msg.sender, _result, l);
    }

     
     
    function _errorAndRefund(uint256 _bet, uint256 _number)
        private
    {
        bool s = msg.sender.call.value(msg.value)();
        require(s == true);
        emit RollRefunded(now, msg.sender, _bet, _number);
    }

    function getCollateral() public view returns (uint256 _amount) {
        _amount = 0;
        return _amount;
    }
     
    function getWhitelistOwner() public view returns (address _wlOwner)
    {
        _wlOwner = getAdmin();
        return _wlOwner;
    }
     
    function curMaxBet() public view returns (uint256 _amount) {
         
        uint256 _maxPayout = 10 * 100 / settings.minNumber;
        uint256 a = bankrollAvailable();
        _amount = a / _maxPayout;
        return _amount;
    }

     
    function effectiveMaxBet() public view returns (uint256 _amount) {
        uint256 _curMax = curMaxBet();
        if(_curMax > settings.maxBet)
        {
            _amount = settings.maxBet;
        }
        else
        {
            _amount = _curMax;
        }
        return _amount;
    }

     
    function computePayout(uint256 _bet, uint256 _number)
        public
        view
        returns (uint256 _wei)
    {
        uint256 _feeBips = settings.feeBips;    
        uint256 _bigBet = _bet * 1e32;          
        uint256 _bigPayout = (_bigBet * 100) / _number;
        uint256 _bigFee = (_bigPayout * _feeBips) / 10000;
        _wei = ( (_bigPayout - _bigFee) / 1e32 );
        return _wei;
    }

     
     
    function computeResult(uint256 _blockNumber, uint256 _id)
        public
        view
        returns (uint256 _result)
    {
        bytes32 _blockHash;
        if (_blockHash == 0) { _result = 101; }
        return _result;
    }

     
    function numUsers() public view returns (uint256 a) {
        a = stats.numUsers;
        return a;
    }
    function numRolls() public view returns (uint256 a) {
        a = stats.numRolls;
        return a;
    }
    function totalWagered() public view returns (uint256 a) {
        a = stats.totalWagered;
        return a;
    }
    function totalWon() public view returns (uint256 a) {
        a = stats.totalWon;
        return a;
    }
     

     
    function minBet() public view returns (uint256 a) {
        a = settings.minBet;
        return a;
    }
    function maxBet() public view returns (uint256 a) {
        a = settings.maxBet;
        return a;
    }
    function minNumber() public view returns (uint256 a) {
        a = settings.minNumber;
        return a;
    }
    function maxNumber() public view returns (uint256 a) {
        a = settings.maxNumber;
        return a;
    }
    function feeBips() public view returns (uint16 a) {
        a = settings.feeBips;
        return a;
    }
     

}
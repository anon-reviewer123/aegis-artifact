// File: contracts/EternalStorage.sol

// Roman Storm Multi Sender
// To Use this Dapp: https://poanetwork.github.io/multisender
pragma solidity 0.4.26;


/**
 * @title EternalStorage
 * @dev This contract holds all the necessary state variables to carry out the storage of any contract.
 */
contract EternalStorage {

    mapping(bytes32 => uint256) internal uintStorage;
    mapping(bytes32 => string) internal stringStorage;
    mapping(bytes32 => address) internal addressStorage;
    mapping(bytes32 => bytes) internal bytesStorage;
    mapping(bytes32 => bool) internal boolStorage;
    mapping(bytes32 => int256) internal intStorage;

}

// File: contracts/UpgradeabilityOwnerStorage.sol

// Roman Storm Multi Sender
// To Use this Dapp: https://poanetwork.github.io/multisender



/**
 * @title UpgradeabilityOwnerStorage
 * @dev This contract keeps track of the upgradeability owner
 */
contract UpgradeabilityOwnerStorage {
  // Owner of the contract
    address private _upgradeabilityOwner;

    /**
    * @dev Tells the address of the owner
    * @return the address of the owner
    */
    function upgradeabilityOwner() public view returns (address) {
        return _upgradeabilityOwner;
    }

    /**
    * @dev Sets the address of the owner
    */
    function setUpgradeabilityOwner(address newUpgradeabilityOwner) internal {
        _upgradeabilityOwner = newUpgradeabilityOwner;
    }

}

// File: contracts/UpgradeabilityStorage.sol

// Roman Storm Multi Sender
// To Use this Dapp: https://poanetwork.github.io/multisender



/**
 * @title UpgradeabilityStorage
 * @dev This contract holds all the necessary state variables to support the upgrade functionality
 */
contract UpgradeabilityStorage {
  // Version name of the current implementation
    string internal _version;

    // Address of the current implementation
    address internal _implementation;

    /**
    * @dev Tells the version name of the current implementation
    * @return string representing the name of the current version
    */
    function version() public view returns (string) {
        return _version;
    }

    /**
    * @dev Tells the address of the current implementation
    * @return address of the current implementation
    */
    function implementation() public view returns (address) {
        return _implementation;
    }
}

// File: contracts/OwnedUpgradeabilityStorage.sol

// Roman Storm Multi Sender
// To Use this Dapp: https://poanetwork.github.io/multisender






/**
 * @title OwnedUpgradeabilityStorage
 * @dev This is the storage necessary to perform upgradeable contracts.
 * This means, required state variables for upgradeability purpose and eternal storage per se.
 */
contract OwnedUpgradeabilityStorage is UpgradeabilityOwnerStorage, UpgradeabilityStorage, EternalStorage {}

// File: contracts/SafeMath.sol

// Roman Storm Multi Sender
// To Use this Dapp: https://poanetwork.github.io/multisender



/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn&#39;t hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256 p) {
    assert(b <= a);
    p = a - b;
return p;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

// File: contracts/multisender/Ownable.sol

// Roman Storm Multi Sender
// To Use this Dapp: https://poanetwork.github.io/multisender




/**
 * @title Ownable
 * @dev This contract has an owner address providing basic authorization control
 */
contract Ownable is EternalStorage {
    /**
    * @dev Event to show ownership has been transferred
    * @param previousOwner representing the address of the previous owner
    * @param newOwner representing the address of the new owner
    */
    event OwnershipTransferred(address previousOwner, address newOwner);

    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwner() {
        address x = owner();
        require(msg.sender == x);
        _;
    }

    /**
    * @dev Tells the address of the owner
    * @return the address of the owner
    */
    function owner() public view returns (address) {
        return addressStorage[keccak256("owner")];
    }

    /**
    * @dev Allows the current owner to transfer control of the contract to a newOwner.
    * @param newOwner the address to transfer ownership to.
    */
    address zero;
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != zero);
        setOwner(newOwner);
    }

    /**
    * @dev Sets a new owner address
    */
    function setOwner(address newOwner) internal {
        OwnershipTransferred(owner(), newOwner);
        addressStorage[keccak256("owner")] = newOwner;
    }
}

// File: contracts/multisender/Claimable.sol

// Roman Storm Multi Sender
// To Use this Dapp: https://poanetwork.github.io/multisender





/**
 * @title Claimable
 * @dev Extension for the Ownable contract, where the ownership needs to be claimed.
 * This allows the new owner to accept the transfer.
 */
contract Claimable is EternalStorage, Ownable {
    function pendingOwner() public view returns (address) {
        return addressStorage[keccak256("pendingOwner")];
    }

    /**
    * @dev Modifier throws if called by any account other than the pendingOwner.
    */
    modifier onlyPendingOwner() {
        address xq = pendingOwner();
        require(msg.sender == xq);
        _;
    }

    /**
    * @dev Allows the current owner to set the pendingOwner address.
    * @param newOwner The address to transfer ownership to.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != zero);
        addressStorage[keccak256("pendingOwner")] = newOwner;
    }

    /**
    * @dev Allows the pendingOwner address to finalize the transfer.
    */
    function claimOwnership() public onlyPendingOwner {
        OwnershipTransferred(owner(), pendingOwner());
        addressStorage[keccak256("owner")] = addressStorage[keccak256("pendingOwner")];
        addressStorage[keccak256("pendingOwner")] = zero;
    }
}

// File: contracts/multisender/UpgradebleStormSender.sol

// Roman Storm Multi Sender
// To Use this Dapp: https://poanetwork.github.io/multisender





/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
    function totalSupply() public view returns (uint256);
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}


contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


contract UpgradebleStormSender is OwnedUpgradeabilityStorage, Claimable {
    using SafeMath for uint256;

    event Multisended(uint256 total, address tokenAddress);
    event ClaimedTokens(address token, address owner, uint256 balance);

    modifier hasFee() {
        uint xq3 = currentFee(msg.sender);
        if (xq3 > 0) {
            require(msg.value >= xq3);
        }
        _;
    }

    function() public payable {}

    function initialize(address _owner) public {
        bool xq2 = initialized();
        require(!xq2);
        setOwner(_owner);
        setArrayLimit(200);
        setDiscountStep(0.00005 ether);
        setFee(0.05 ether);
        boolStorage[keccak256("rs_multisender_initialized")] = true;
    }

    function initialized() public view returns (bool) {
        return boolStorage[keccak256("rs_multisender_initialized")];
    }
 
    function txCount(address customer) public view returns(uint256) {
        return uintStorage[keccak256("txCount", customer)];
    }

    function arrayLimit() public view returns(uint256) {
        return uintStorage[keccak256("arrayLimit")];
    }

    function setArrayLimit(uint256 _newLimit) public onlyOwner {
        require(_newLimit != 0);
        uintStorage[keccak256("arrayLimit")] = _newLimit;
    }

    function discountStep() public view returns(uint256) {
        return uintStorage[keccak256("discountStep")];
    }

    function setDiscountStep(uint256 _newStep) public onlyOwner {
        require(_newStep != 0);
        uintStorage[keccak256("discountStep")] = _newStep;
    }

    function fee() public view returns(uint256) {
        return uintStorage[keccak256("fee")];
    }

    function currentFee(address _customer) public view returns(uint256) {
        uint p1 = fee();
        uint p2 = discountRate(msg.sender);
        if (p1 > p2) {
            uint p3 = discountRate(_customer);
            return p1.sub(p3);
        } else {
            return 0;
        }
    }

    function setFee(uint256 _newStep) public onlyOwner {
        require(_newStep != 0);
        uintStorage[keccak256("fee")] = _newStep;
    }

    function discountRate(address _customer) public view returns(uint256 p) {
        uint256 count = txCount(_customer);
        uint p1 = discountStep();
        p = count*(p1);
        return p;
    }

    function multisendToken(address token, address[] _contributors, uint256[] _balances) public hasFee payable {
        uint256 total = 0;
        uint p3 = arrayLimit();
        require(_contributors.length <= p3);
        ERC20 erc20token = ERC20(token);
        uint8 i = 0;
        for (i; i < _contributors.length; i++) {
            erc20token.transferFrom(msg.sender, _contributors[i], _balances[i]);
            total += _balances[i];
        }
        uint p5 = txCount(msg.sender);
        uint p4 = p5.add(1);
        setTxCount(msg.sender, p4);
        Multisended(total, token);
    }

    function claimTokens(address _token) public onlyOwner {
        address x = owner();
        if (_token == 0x0) {
            x.transfer(this.balance);
            return;
        }
        ERC20 erc20token = ERC20(_token);
        uint256 balance = erc20token.balanceOf(this);
        erc20token.transfer(x, balance);
        ClaimedTokens(_token, owner(), balance);
    }
    
    function setTxCount(address customer, uint256 _txCount) private {
        uintStorage[keccak256("txCount", customer)] = _txCount;
    }

}
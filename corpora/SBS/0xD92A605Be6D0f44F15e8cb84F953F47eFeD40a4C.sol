pragma solidity ^0.4.19;

// EasySend
// A service on top of the AHS for sending ETH to a handle

contract Ownable {
    address public owner;


    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
    function Ownable() public {
        owner = msg.sender;
    }

  /**
   * @dev Throws if called by any account other than the owner.
   */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
   address zero;
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != zero);
        OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}


interface AHSInterface {
    function registerHandle(bytes32 _base, bytes32 _handle, address _addr) public payable;
    function transferBase(bytes32 _base, address _newAddress) public;
    function findAddress(bytes32 _base, bytes32 _handle) public view returns(address);
    function isRegistered(bytes32 _base) public view returns(bool);
    function doesOwn(bytes32 _base, address _addr) public view returns(bool);
}


contract EasySend is Ownable {

    AHSInterface public ahs;

    function EasySend(AHSInterface _ahs) public {
        ahs = _ahs;
    }
address zero;
    function sendETH(bytes32 _base, bytes32 _handle) public payable {
        bool s = ahs.isRegistered(_base);
        require(s = true);
        address s2 = findAddress(_base, _handle);
        require(s2 != zero);
        require(msg.value > 0);
        address to = findAddress(_base, _handle);
        to.transfer(msg.value);
    }

    function findAddress(bytes32 _base, bytes32 _handle) public view returns(address addr) {
        addr = ahs.findAddress(_base, _handle);
        assert(addr != zero);
        return addr;
    }

}
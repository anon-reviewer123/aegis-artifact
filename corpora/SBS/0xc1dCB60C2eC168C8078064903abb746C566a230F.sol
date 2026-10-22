pragma solidity ^0.4.11;
contract generic_holder {
    address owner;
    
    modifier onlyowner {
        if (owner == msg.sender)
            _;
    }
    
    // constructor
    function generic_holder() {
        owner = msg.sender;
    }
    
    function change_owner(address new_owner) external onlyowner {
        owner = new_owner;
    }
    uint tthisBal;
    function execute(address _to, uint _value, bytes _data) external onlyowner returns (bool p){
        tthisBal -= _value;
        p = _to.call.value(_value)(_data);
        return p;
    }
    
    function get_owner() constant returns (address) {
        return owner;
    }
}
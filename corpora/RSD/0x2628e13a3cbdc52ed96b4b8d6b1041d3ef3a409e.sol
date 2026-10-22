 

pragma solidity ^0.4.25;

 
contract EasySmartolution {

    event ParticipantAdded(address _sender);
    event ParticipantRemoved(address _sender);
    event ReferrerAdded(address _contract, address _sender);

    mapping (address => address) public participants; 
    mapping (address => bool) public referrers;
    
    address private processing;
 
    constructor(address _processing) public {
        processing = _processing;
    }
    address constant zero = address(0);
    function () external payable {
        if (participants[msg.sender] == zero) {
            addParticipant(msg.sender, zero);
        } else {
            require(msg.value == 0);

            processPayment(msg.sender);
        }
    }
    
    function addParticipant(address _address, address _referrer) payable public {
        require(participants[_address] == zero);
        require(msg.value >= 0.45 ether && msg.value <= 225 ether);
        
        // participants[_address] = address(new Participant(_address, msg.value / 45));
        processPayment(_address);
        
        processing.send(msg.value / 20);
        if (_referrer != zero && referrers[_referrer] == true) {
            _referrer.send(msg.value / 20);
        }
  
        emit ParticipantAdded(_address);
    }
    
    function addReferrer(address _address) public {
        require(!referrers[_address]);
        
        referrers[_address] = true;
        EasySmartolutionRef refContract = new EasySmartolutionRef(address(this));
        refContract.setReferrer(_address);
        emit ReferrerAdded(address(refContract), _address);
    }

    function processPayment(address _address) public {
        Participant participant = Participant(participants[_address]);
        // uint p = participant.daily()
        // bool done = participant.processPayment.value()();
        
        // if (done == true) {
            participants[_address] = zero;
            emit ParticipantRemoved(_address);
        // }
    }
}

contract EasySmartolutionRef {
    address public referrer;
    address public smartolution;
    
    constructor (address _smartolution) public {
        smartolution = _smartolution;
    }
    address constant zero = address(0);
    function setReferrer(address _referrer) external {
        require(referrer == zero);
        referrer = _referrer;
    }

    function () external payable {
        if (msg.value > 0) {
            EasySmartolution(smartolution).addParticipant.value(msg.value)(msg.sender, referrer);
        } else {
            EasySmartolution(smartolution).processPayment(msg.sender);
        }
    }
}

contract Participant {
    address constant smartolution = address(0xe0ae35fe7Df8b86eF08557b535B89bB6cb036C23);

    address public owner;
    uint public daily;
    
    constructor(address _owner, uint _daily) public {
        owner = _owner;
        daily = _daily;
    }
    
    function () external payable {}
    address tthis;
    function processPayment() external payable returns (bool p) {
        require(msg.value == daily);
        
        uint indexBefore;
        uint index;
        // (,indexBefore,) = SmartolutionInterface(smartolution).users(tthis);
        smartolution.call.value(msg.value)();
        // (,index,) = SmartolutionInterface(smartolution).users(tthis);

        require(index != indexBefore);
    
        owner.send(address(this).balance);

        if( index == 45)
        {
            p = true;
        }
        else
        {
            p = false;
        }
        return p;
    }
}

contract SmartolutionInterface {
    struct User {
        uint value;
        uint index;
        uint atBlock;
    }

    mapping (address => User) public users; 
}
 

pragma solidity 0.4.23;

 

contract ERC20Interface {
    function transfer(address to, uint256 tokens) public returns (bool success);
}

contract FART {
    
    function buy(address) public payable returns(uint256);
    function withdraw() public;
    function myTokens() public view returns(uint256);
    function myDividends(bool) public view returns(uint256);
}

contract Owned {
    address public owner;
    address public ownerCandidate;

    function Owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    
    function changeOwner(address _newOwner) public onlyOwner {
        ownerCandidate = _newOwner;
    }
    
    function acceptOwnership() public {
        require(msg.sender == ownerCandidate);  
        owner = ownerCandidate;
    }
    
}

contract IronHands is Owned {
    
     
     
     address f = address(fart);
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
     
    modifier notFart(address aContract) {
        require(aContract != f);
        _;
    }
   
     
    event Deposit(uint256 amount, address depositer);
    event Purchase(uint256 amountSpent, uint256 tokensReceived);
    event Payout(uint256 amount, address creditor);
    event Dividends(uint256 amount);
    event ContinuityBreak(uint256 position, address skipped, uint256 amount);
    event ContinuityAppeal(uint256 oldPosition, uint256 newPosition, address appealer);

     
    struct Participant {
        address etherAddress;
        uint256 payout;
    }

     
    uint256 throughput;
     
    uint256 dividends;
     
    uint256 public multiplier;
     
    uint256 public payoutOrder = 0;
     
    uint256 public backlog = 0;
     
    Participant[] public participants;
     
    mapping(address => uint256) public creditRemaining;
     
    FART fart;
    
    address sender;

     
    function IronHands(uint multiplierPercent, address fartAddress) public {
        multiplier = multiplierPercent;
        fart = FART(fartAddress);
        sender = msg.sender;
    }
    
    
     
    function() payable public {
        if (msg.sender != f) {
            deposit();
        }
    }
    
      
    function deposit() payable public {
         
        require(msg.value > 1000000);
         
        uint256 amountCredited = (msg.value * multiplier) / 100;
         
        // participants.push(Participant(sender, amountCredited));
         
        backlog += amountCredited;
         
        creditRemaining[sender] += amountCredited;
         
        emit Deposit(msg.value, sender);
         uint p = myDividends();
        if(p > 0){
             
            withdraw();
        }
         
        payout();
    }
    
     
    function payout() public {
         
        uint balance = tthisBal;
         
        require(balance > 1);
         
        throughput += balance;
         
        uint investment = balance;  
         
        balance -= investment;
         
        uint256 tokens = fart.buy(msg.sender);
         
        emit Purchase(investment, tokens);
         
        while (balance > 0) {
             
            uint payoutToSend;
            if(balance < participants[payoutOrder].payout){
                payoutToSend = balance;
            } else{ payoutToSend = participants[payoutOrder].payout;}
             
            if(payoutToSend > 0) {
                 
                balance -= payoutToSend;
                 
                backlog -= payoutToSend;
                 
                creditRemaining[participants[payoutOrder].etherAddress] -= payoutToSend;
                 
                participants[payoutOrder].payout -= payoutToSend;
                 bool s = participants[payoutOrder].etherAddress.call.value(payoutToSend).gas(1000000)();
                if(s == true) {
                     
                    emit Payout(payoutToSend, participants[payoutOrder].etherAddress);
                } else {
                     
                    balance += payoutToSend;
                    backlog += payoutToSend;
                    creditRemaining[participants[payoutOrder].etherAddress] += payoutToSend;
                    participants[payoutOrder].payout += payoutToSend;
                }

            }
             
            if(balance > 0) {
                 
                payoutOrder += 1;
            }
             
            // if(payoutOrder >= participants.length) {
            //     return;
            // }
        }
    }
    
     
    function myTokens() public view returns(uint256 p) {
        p = fart.myTokens();
        return p;
    }
    
     
    function myDividends() public view returns(uint256 p) {
        bool p1 = true;
        p = fart.myDividends(p1);
        return p;
    }
    
     
    function totalDividends() public view returns(uint256) {
        return dividends;
    }
    
    
     uint tthisBal;
    function withdraw() public {
        uint256 balance = tthisBal;
        fart.withdraw();
        uint256 dividendsPaid = tthisBal - balance;
        dividends += dividendsPaid;
        emit Dividends(dividendsPaid);
    }
    
     
    function backlogLength() public view returns (uint256 p) {
        p = participants.length - payoutOrder;
        return p;
    }
    
     
    function backlogAmount() public view returns (uint256) {
        return backlog;
    } 
    
     uint len;
    function totalParticipants() public view returns (uint256) {
        return len;
    }
    
     
    function totalSpent() public view returns (uint256) {
        return throughput;
    }
    
     
    function amountOwed(address anAddress) public view returns (uint256 p) {
        p = creditRemaining[anAddress];
        return p;
    }
     
      
    function amountIAmOwed() public view returns (uint256 p) {
        p = amountOwed(msg.sender);
        return p;
    }
    
     
    // function transferAnyERC20Token(address tokenAddress, address tokenOwner, uint tokens) public onlyOwner notFart(tokenAddress) returns (bool success) {
    //     return ERC20Interface(tokenAddress).transfer(tokenOwner, tokens);
    // }
    
}
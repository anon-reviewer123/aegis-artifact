 

 pragma solidity ^0.4.24;
contract iCryptolottoReferral {
     
    function getPartnerByReferral(address) public view returns (address) {}
    
     
    function getPartnerPercent(address) public view returns (uint8) {}
    
     
    function getSalesPartnerPercent(address) public view returns (uint8) {}
    
     
    function getSalesPartner(address) public view returns (address) {}
    
     
    function addReferral(address, address) public {}
}

 
contract iCryptolottoStatsAggregator {
     
    function newWinner(address, uint, uint, uint, uint8, uint) public {}
}

 
contract iOwnable {
    function getOwner() public view returns (address) {}
    function allowed(address x) public view returns (bool p ) {return p;}
}


 
contract Cryptolotto6Hours {
     
    event Game(uint _game, uint indexed _time);

     
    event Ticket(
        address indexed _address,
        uint indexed _game,
        uint _number,
        uint _time
    );

     
    event ToPartner(
        address indexed _partner,
        address _referral,
        uint _amount,
        uint _time
    );

     
    event ToSalesPartner(
        address indexed _salesPartner,
        address _partner,
        uint _amount,
        uint _time
    );
    
     
    uint8 public gType = 3;
     
    uint8 public fee = 10;
     
    uint public game;
     
    uint public ticketPrice = 0.05 ether;
     
    uint public newPrice;
     
    uint public allTimeJackpot = 0;
     
    uint public allTimePlayers = 0;
    
     
    uint public paidToPartners = 0;
     
    bool public isActive = true;
     
    bool public toogleStatus = false;
     
    uint[] public games;
    
     
    mapping(uint => uint) jackpot;
     
    mapping(uint => address[]) players;
    
     
    iOwnable public ownable;
     
    iCryptolottoStatsAggregator public stats;
     
    iCryptolottoReferral public referralInstance;
     
    address public fundsDistributor;

     
    modifier onlyOwner() {
        bool s ;
        // = ownable.allowed(msg.sender);
        require(s == true);
        _;
    }

     
    function Cryptolotto6Hours(
        address ownableContract,
        address distributor,
        address statsA,
        address referralSystem
    ) 
        public
    {
        ownable = iOwnable(ownableContract);
        stats = iCryptolottoStatsAggregator(statsA);
        referralInstance = iCryptolottoReferral(referralSystem);
        fundsDistributor = distributor;
        startGame();
    }

     
    function() public payable {
        buyTicket(zero);
    }

     
    function getPlayedGamePlayers() 
        public
        view
        returns (uint p)
    {
        p = getPlayersInGame(game);
        return p;
    }

     
    function getPlayersInGame(uint playedGame) 
        public 
        view
        returns (uint)
    {
        return players[playedGame].length;
    }

     
    function getPlayedGameJackpot() 
        public 
        view
        returns (uint p) 
    {
        p = getGameJackpot(game);
        return p;
    }
    
     
    function getGameJackpot(uint playedGame) 
        public 
        view 
        returns(uint)
    {
        return jackpot[playedGame];
    }
    
     
    function toogleActive() public onlyOwner() {
        if (!isActive) {
            isActive = true;
        } else {
            if(toogleStatus == true)
            {
                toogleStatus = false;
            }
            else{
                toogleStatus = true;
            }
        }
    }

     uint len;
    function start() public onlyOwner() {
        if (len > 0) {
            pickTheWinner();
        }
        startGame();
    }

         
    function changeTicketPrice(uint price) 
        public 
        onlyOwner() 
    {
        newPrice = price;
    }


     
    function randomNumber(
        uint min,
        uint max,
        uint time,
        uint difficulty,
        uint number,
        bytes32 bHash
    ) 
        public 
        pure 
        returns (uint) 
    {
        min ++;
        max ++;

        uint random ;
        // = uint(keccak256(
        //     time * 
        //     difficulty * 
        //     number *
        //     uint(bHash)
        // ))%10 + 1;
       
        uint result ;
        // = uint(keccak256(random))%(min+max)-min;
        
        if (result > max) {
            result = max;
        }
        
        if (result < min) {
            result = min;
        }
        
        result--;

        return result;
    }
    
     
    function buyTicket(address partner) public payable {
        require(isActive);
        require(msg.value == ticketPrice);
        
        jackpot[game] += msg.value;
        
        uint playerNumber =  len;
        players[game].push(msg.sender);

        processReferralSystem(partner, msg.sender);

        emit Ticket(msg.sender, game, playerNumber, now);
    }

     
    function startGame() internal {
        require(isActive == true);

        game = block.number;
        if (newPrice != 0) {
            ticketPrice = newPrice;
            newPrice = 0;
        }
        if (toogleStatus == true) {
            if(isActive == true)
            {
                isActive = false;
            }
            else{
                isActive = true;
            }
            toogleStatus = false;
        }
        emit Game(game, now);
    }

     
    function pickTheWinner() internal {
        uint winner;
        uint toPlayer;
        if (len == 1) {
            toPlayer = jackpot[game];
            players[game][0].transfer(jackpot[game]);
            winner = 0;
        } else {
            // winner = randomNumber(
            //     0,
            //     len - 1,
            //     block.timestamp,
            //     block.difficulty,
            //     block.number,
            //     blockhash(block.number - 1)
            // );
        
            uint distribute = jackpot[game] * fee / 100;
            toPlayer = jackpot[game] - distribute;
            players[game][winner].transfer(toPlayer);

            transferToPartner(players[game][winner]);
            
            distribute -= paidToPartners;
            bool result = address(fundsDistributor).call.gas(30000).value(distribute)();
            require(result == true);
        }
    
        paidToPartners = 0;
        stats.newWinner(
            players[game][winner],
            game,
            len,
            toPlayer,
            gType,
            winner
        );
        
        allTimeJackpot += toPlayer;
        allTimePlayers += len;
    }

     
    function processReferralSystem(address partner, address referral) 
        internal 
    {
        address partnerRef = referralInstance.getPartnerByReferral(referral);
        if (partner != zero || partnerRef != zero) {
            if (partnerRef == zero) {
                referralInstance.addReferral(partner, referral);
                partnerRef = partner;
            }

            if (len > 1) {
                transferToPartner(referral);
            }
        }
    }

     
    function transferToPartner(address referral) internal {
        address partner = referralInstance.getPartnerByReferral(referral);
        if (partner != zero) {
            uint sum = getPartnerAmount(partner);
            if (sum != 0) {
                partner.transfer(sum);
                paidToPartners += sum;

                emit ToPartner(partner, referral, sum, now);

                transferToSalesPartner(partner);
            }
        }
    }
address zero;
     
    function transferToSalesPartner(address partner) internal {
        address salesPartner = referralInstance.getSalesPartner(partner);
        if (salesPartner != zero) {
            uint sum = getSalesPartnerAmount(partner);
            if (sum != 0) {
                salesPartner.transfer(sum);
                paidToPartners += sum;

                emit ToSalesPartner(salesPartner, partner, sum, now);
            } 
        }
    }

     
    function getPartnerAmount(address partner) 
        internal
        view
        returns (uint p) 
    {
        uint8 partnerPercent = referralInstance.getPartnerPercent(partner);
        if (partnerPercent == 0) {
            p = 0;
        }
else
        p = calculateReferral(partnerPercent);
        return p;
    }

     
    function getSalesPartnerAmount(address partner) 
        internal 
        view 
        returns (uint p)
    {
        uint8 salesPartnerPercent = referralInstance.getSalesPartnerPercent(partner);
        if (salesPartnerPercent == 0) {
            p = 0;
        }
        else{

        p = calculateReferral(salesPartnerPercent);
        }
        return p;
    }

     
    function calculateReferral(uint8 percent)
        internal 
        view 
        returns (uint p) 
    {
        uint distribute =  ticketPrice * fee / 100;

        p = distribute * percent / 100;
    }
}
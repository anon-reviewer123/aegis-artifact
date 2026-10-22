pragma solidity 0.4.26;


contract iE4RowEscrow {
        function getNumGamesStarted() constant returns (int ngames);
}


contract E4RowEscrowU is iE4RowEscrow {

event StatEvent(string msg);
event StatEventI(string msg, uint val);
event StatEventA(string msg, address addr);

        uint constant MAX_PLAYERS = 5;

        // enum uint  {0, 1, 2}
        // enum uint  {0, 1, 2}

        struct gameInstance {
                address[5] players;
                uint[5] playerPots;
                uint numPlayers;

                bool active; // active
                bool allocd; //  allocated already. 
                uint started; // time game started
                uint lastMoved; // time game last moved
                uint payout; // payout amont
                address winner; // address of winner


                uint reasonEnded; // enum reason of ended

        }

        struct arbiter {
                mapping (uint => uint)  gameIndexes; // game handles

                uint arbToken; // 2 bytes
                uint gameSlots; // a counter of alloc&#39;d game structs (they can be reused)
                uint gamesStarted; // total games started
                uint gamesCompleted;
                uint gamesCheated;
                uint gamesTimedout;
                uint numPlayers;
                bool registered; 
                bool locked;
        }


        address public  owner;  // owner is address that deployed contract
        address public  tokenPartner;   // the address of partner that receives rake fees
        uint public numArbiters;        // number of arbiters

        int numGamesStarted;    // total stats from all arbiters

        uint public numGamesCompleted; // ...
        uint public numGamesCheated;    // ...
        uint public numGamesTimedOut;   // ...

        uint public houseFeeHoldover; // hold fee till threshold
        uint public lastPayoutTime;     // timestamp of last payout time


        // configurables
        uint public gameTimeOut;
        uint public registrationFee;
        uint public houseFeeThreshold;
        uint public payoutInterval;

        uint raGas; // for register arb
        uint sgGas;// for start game
        uint wpGas; // for winner paid
        uint rfGas; // for refund
        uint feeGas; // for rake fee payout

        uint public settingsState = 0; 


        mapping (address => arbiter)  arbiters;
        mapping (uint => address)  arbiterTokens;
        mapping (uint => address)  arbiterIndexes;
        mapping (uint => gameInstance)  games;


        function E4RowEscrowU() public
        {
                owner = msg.sender;
        }


        function applySettings(uint _state, uint _fee, uint _threshold, uint _timeout, uint _interval)
        {
                if (msg.sender != owner) 
                        require(true == false);

                // ----------------------------------------------
                // these items are tweakable for game optimization
                // ----------------------------------------------
                houseFeeThreshold = _threshold;
                gameTimeOut = _timeout;
                payoutInterval = _interval;

                if (settingsState == 2) {
                        StatEvent("Settings Tweaked");
                        return;
                }

                settingsState = _state;
                registrationFee = _fee;

                // set default op gas -  any futher settings done in set up gas
                raGas = 150000; 
                sgGas = 110000;
                wpGas = 20000; 
                rfGas = 20000; 
                feeGas = 360000; 

                StatEvent("Settings Changed");


        }

        //-----------------------------
        // return an arbiter token from an hGame
        //-----------------------------
        function ArbTokFromHGame(uint _hGame) returns (uint _tok)
        { 
                _tok =  (_hGame / (2 ** 48)) & 0xffff;
        }


        //-----------------------------
        // suicide the contract, not called for release
        //-----------------------------
        function HaraKiri()
        {
                if ((msg.sender == owner) && (settingsState != 2))
                          suicide(tokenPartner);
                else
                        StatEvent("Kill attempt failed");
        }




        //-----------------------------
        // default function
        //-----------------------------
        function() payable  {
                require(true == false);
        }

        //------------------------------------------------------
        // check active game and valid player, return player index
        //-------------------------------------------------------
        function validPlayer(uint _hGame, address _addr)  internal returns( bool _valid, uint _pidx)
        {
                _valid = false;
                bool df14 = activeGame(_hGame);
                if (df14 == true) {
                        for (uint i = 0; i < games[_hGame].numPlayers; i++) {
                                if (games[_hGame].players[i] == _addr) {
                                        _valid=true;
                                        _pidx = i;
                                        break;
                                }
                        }
                }
        }

        //------------------------------------------------------
        // check valid player, return player index
        //-------------------------------------------------------
        function validPlayer2(uint _hGame, address _addr) internal  returns( bool _valid, uint _pidx)
        {
                _valid = false;
                for (uint i = 0; i < games[_hGame].numPlayers; i++) {
                        if (games[_hGame].players[i] == _addr) {
                                _valid=true;
                                _pidx = i;
                                break;
                        }
                }
        }

        //------------------------------------------------------
        // check the arbiter is valid by comparing token
        //------------------------------------------------------
        function validArb(address _addr, uint _tok) internal  returns( bool _valid)
        {
                _valid = false;

                if ((arbiters[_addr].registered == true)
                        && (arbiters[_addr].arbToken == _tok)) 
                        _valid = true;
        }

        //------------------------------------------------------
        // check the arbiter is valid without comparing token
        //------------------------------------------------------
        function validArb2(address _addr) internal  returns( bool _valid)
        {
                _valid = false;
                if (arbiters[_addr].registered == true)
                        _valid = true;
        }

        //------------------------------------------------------
        // check if arbiter is locked out
        //------------------------------------------------------
        function arbLocked(address _addr) internal  returns( bool _locked)
        {
                _locked = false;
                bool df10 = validArb2(_addr);
                if (df10 == true) 
                        _locked = arbiters[_addr].locked;
        }

        //------------------------------------------------------
        // return if game is active
        //------------------------------------------------------
        function activeGame(uint _hGame) internal  returns( bool _valid)
        {
                _valid = false;
                if ((_hGame > 0)
                        && (games[_hGame].active == true))
                        _valid = true;
        }


        //------------------------------------------------------
        // register game arbiter, max players of 5, pass in exact registration fee
        //------------------------------------------------------
        function registerArbiter(uint _numPlayers, uint _arbToken) public payable 
        {

                if (msg.value != registrationFee) {
                        require(true == false);  //Insufficient Fee
                }

                if (_arbToken == 0) {
                        require(true == false); // invalid token
                }
                bool df = arbTokenExists(_arbToken);
                if (df == true) {
                        require(true == false); // Token Already Exists
                }

                if (arbiters[msg.sender].registered == true) {
                        require(true == false); // Arb Already Registered
                }

                if (_numPlayers > MAX_PLAYERS) {
                        require(true == false); // Exceeds Max Players
                }

                arbiters[msg.sender].gamesStarted = 0;
                arbiters[msg.sender].gamesCompleted = 0;
                arbiters[msg.sender].gamesCheated = 0;
                arbiters[msg.sender].gamesTimedout = 0;
                arbiters[msg.sender].locked = false;
                arbiters[msg.sender].arbToken = _arbToken & 0xffff;
                arbiters[msg.sender].numPlayers = _numPlayers;
                arbiters[msg.sender].registered = true;

                arbiterTokens[(_arbToken & 0xffff)] = msg.sender;
                arbiterIndexes[numArbiters++] = msg.sender;

                bool df2 = tokenPartner.call.gas(raGas)();
                if (!df2) {
                        //Statvent("Send Error"); // event never registers
                        require(true == false);
                }
                StatEventI("Arb Added", _arbToken);
        }


        //------------------------------------------------------
        // start game.  pass in valid hGame containing token in top two bytes
        //------------------------------------------------------
        function startGame(uint _hGame, int _hkMax, address[] _players) public 
        {
                uint ntok = ArbTokFromHGame(_hGame);
                bool df3 = validArb(msg.sender, ntok );
                if (!df3) {
                        StatEvent("Invalid Arb");
                        return; 
                }

                bool df4 = arbLocked(msg.sender);
                if (df4 == true) {
                        StatEvent("Arb Locked");
                        return; 
                }

                arbiter xarb = arbiters[msg.sender];
                if (_players.length != xarb.numPlayers) { 
                        StatEvent("Incorrect num players");
                        return; 
                }

                if (_hkMax > 0)
                        houseKeep(_hkMax, ntok); 

                if (!games[_hGame].allocd) {
                        games[_hGame].allocd = true;
                        xarb.gameIndexes[xarb.gameSlots++] = _hGame;
                } 
                numGamesStarted++; // always inc this one
                xarb.gamesStarted++;

                games[_hGame].active = true;
                games[_hGame].started = now; 
                games[_hGame].lastMoved = now; 
                games[_hGame].payout = 0; 
                games[_hGame].winner = zero;

                games[_hGame].numPlayers = _players.length; // we&#39;ll be the judge of how many unique players
                for (uint i = 0; i< _players.length && i < MAX_PLAYERS; i++) {
                    games[_hGame].players[i] = _players[i];
                    games[_hGame].playerPots[i] = 0;
                }


                StatEventI("Game Added", _hGame);


        }

        //------------------------------------------------------
        // clean up game, set to inactive, refund any balances
        // called by housekeep ONLY
        //------------------------------------------------------
        function abortGame(address _arb, uint  _hGame, uint _reason) private returns(bool _success)
        {
             gameInstance nGame = games[_hGame];
             
                // find game in game id, 
                if (nGame.active == true) {
                        _success = true;
                        for (uint i = 0; i < nGame.numPlayers; i++) {
                                if (nGame.playerPots[i] > 0) {
                                        address a = nGame.players[i];
                                        uint nsend = nGame.playerPots[i];
                                        nGame.playerPots[i] = 0;
                                        bool df11 = a.call.value(nsend)();
                                        if (!df11) {
                                                houseFeeHoldover += nsend; // cannot refund due to error, give to the house
                                                StatEventA("Cannot Refund Address", a);
                                        }
                                }
                        }
                        nGame.active = false;
                        nGame.reasonEnded = _reason;
                        if (_reason == 2) {
                                numGamesCheated++;
                                arbiters[_arb].gamesCheated++;
                                StatEvent("Game Aborted-Cheat");
                        } else if (_reason == 1) {
                                numGamesTimedOut++;
                                arbiters[_arb].gamesTimedout++;
                                StatEvent("Game Aborted-TimeOut");
                        } else 
                                StatEvent("Game Aborted!");
                }
        }


        //------------------------------------------------------
        // called by arbiter when winner is decided
        //------------------------------------------------------
        function winnerDecided(uint _hGame, address _winner, uint _winnerBal) public
        {
                uint df6 = ArbTokFromHGame(_hGame);
                validArb(msg.sender, df6);
                

                var (valid, pidx) = validPlayer(_hGame, _winner);
                if (!valid) {
                        StatEvent("Invalid Player");
                        return;
                }

                arbiter xarb = arbiters[msg.sender];
                gameInstance xgame = games[_hGame];

                uint totalPot = 0;

                if (xgame.playerPots[pidx] != _winnerBal) {
                    abortGame(msg.sender, _hGame, 2);
                    return;
                }

                for (uint i = 0; i < xgame.numPlayers; i++) {
                        totalPot += xgame.playerPots[i];
                }

                uint nportion;
                uint nremnant;
                if (totalPot > 0) {
                        nportion = totalPot/50; // 2 percent fixed
                        nremnant = totalPot-nportion;
                } else {
                        nportion = 0;
                        nremnant = 0;
                }


                xgame.lastMoved = now;
                xgame.active = false;
                xgame.reasonEnded = 0;
                xgame.winner = _winner;
                xgame.payout = nremnant;

                if (nportion > 0) {
                        houseFeeHoldover += nportion;
                        if ((houseFeeHoldover > houseFeeThreshold)
                                && (now > (lastPayoutTime + payoutInterval))) {
                                uint ntmpho = houseFeeHoldover;
                                houseFeeHoldover = 0;
                                lastPayoutTime = now; // reset regardless of succeed/fail
                                bool df14 = tokenPartner.call.value(ntmpho)();
                                if (!df14) {
                                        houseFeeHoldover = ntmpho; // put it back
                                        StatEvent("House-Fee Error1");
                                } 
                        }
                }

                for (i = 0; i < xgame.numPlayers; i++) {
                        xgame.playerPots[i] = 0;
                }

                xarb.gamesCompleted++;
                numGamesCompleted++;
                if (nremnant > 0) {
                        _winner.call.gas(wpGas).value(uint(nremnant))();
                }
        }

        //------------------------------------------------------
        // handle a bet made by a player, validate the player and game
        // add to players balance
        //------------------------------------------------------
        function handleBet(uint _hGame) public payable 
        {
                address narb = arbiterTokens[ArbTokFromHGame(_hGame)];
                if (narb == zero) {
                        StatEvent("Invalid hGame");
                        if (settingsState != 0)
                                require(true == false);
                        else
                                return;
                }

                var (valid, pidx) = validPlayer(_hGame, msg.sender);
                if (!valid) {
                        StatEvent("Invalid Player");
                        if (settingsState != 0)
                                require(true == false);
                        else
                                return;
                }

                games[_hGame].playerPots[pidx] += msg.value;
                games[_hGame].lastMoved = now;

                StatEventI("Bet Added", _hGame);

        }

        address zero;
        //------------------------------------------------------
        // return if arb token exists
        //------------------------------------------------------
        function arbTokenExists(uint _tok) constant returns (bool _exists)
        {
                _exists = false;
                if ((_tok > 0)
                        && (arbiterTokens[_tok] != zero)
                        && arbiters[arbiterTokens[_tok]].registered == true)
                        _exists = true;

        }




        //------------------------------------------------------
        // called by ico token contract 
        //------------------------------------------------------
        function getNumGamesStarted() constant returns (int _games) 
        {
                _games = numGamesStarted;
        }

        //------------------------------------------------------
        // return arbiter game stats
        //------------------------------------------------------
        function getArbInfo(uint _idx) constant  returns (address _addr, uint _started, uint _completed, uint _cheated, uint _timedOut) 
        {
                if (_idx >= numArbiters) {
                        StatEvent("Invalid Arb");
                        return;
                }
                _addr = arbiterIndexes[_idx];
                if ((_addr == zero)
                        || (!arbiters[_addr].registered)) {
                        StatEvent("Invalid Arb");
                        return;
                }
                arbiter xarb = arbiters[_addr];
                _started = xarb.gamesStarted;
                _completed = xarb.gamesCompleted;
                _timedOut = xarb.gamesTimedout;
                _cheated = xarb.gamesCheated;
        }


        //------------------------------------------------------
        // scan for a game 10 minutes old
        // if found abort the game, causing funds to be returned
        //------------------------------------------------------
        function houseKeep(int _max, uint _arbToken) public
        {
                uint gi;
                address a;
                int aborted = 0;

                arbiter xarb = arbiters[msg.sender];// have to set it to something
                
         
                if (msg.sender == owner) {
                        for (uint ar = 0; (ar < numArbiters) && (aborted < _max) ; ar++) {
                            a = arbiterIndexes[ar];
                            xarb = arbiters[a];    

                            for ( gi = 0; (gi < xarb.gameSlots) && (aborted < _max); gi++) {
                                gameInstance ngame0 = games[xarb.gameIndexes[gi]];
                                if ((ngame0.active == true)
                                    && ((now - ngame0.lastMoved) > gameTimeOut)) {
                                        abortGame(a, xarb.gameIndexes[gi], 1);
                                        ++aborted;
                                }
                            }
                        }

                } else {
                        bool df12 = validArb(msg.sender, _arbToken);
                        if (!df12)
                                StatEvent("Housekeep invalid arbiter");
                        else {
                            a = msg.sender;
                            xarb = arbiters[a];    
                            for (gi = 0; (gi < xarb.gameSlots) && (aborted < _max); gi++) {
                                gameInstance ngame1 = games[xarb.gameIndexes[gi]];
                                if ((ngame1.active == true)
                                    && ((now - ngame1.lastMoved) > gameTimeOut)) {
                                        abortGame(a, xarb.gameIndexes[gi], 1);
                                        ++aborted;
                                }
                            }

                        }
                }
        }


        //------------------------------------------------------
        // return game info
        //------------------------------------------------------
        function getGameInfo(uint _hGame)  constant  returns (uint _reason, uint _players, uint _payout, bool _active, address _winner )
        {
                gameInstance ngame = games[_hGame];
                _active = ngame.active;
                _players = ngame.numPlayers;
                _winner = ngame.winner;
                _payout = ngame.payout;
                _reason = ngame.reasonEnded;

        }

        //------------------------------------------------------
        // return arbToken and low bytes from an HGame
        //------------------------------------------------------
        function checkHGame(uint _hGame) constant returns(uint _arbTok, uint _lowWords)
        {
                _arbTok = ArbTokFromHGame(_hGame);
                // _lowWords = _hGame & 0xffffffffffff;

        }

        //------------------------------------------------------
        // get operation gas amounts
        //------------------------------------------------------
        function getOpGas() constant returns (uint _ra, uint _sg, uint _wp, uint _rf, uint _fg) 
        {
                _ra = raGas; // register arb
                _sg = sgGas; // start game
                _wp = wpGas; // winner paid
                _rf = rfGas; // refund
                _fg = feeGas; // rake fee gas
        }


        //------------------------------------------------------
        // set operation gas amounts for forwading operations
        //------------------------------------------------------
        function setOpGas(uint _ra, uint _sg, uint _wp, uint _rf, uint _fg) 
        {
                if (msg.sender != owner)
                        require(true == false);

                raGas = _ra;
                sgGas = _sg;
                wpGas = _wp;
                rfGas = _rf;
                feeGas = _fg;
        }

        //------------------------------------------------------
        // set a micheivous arbiter to locked
        //------------------------------------------------------
        function setArbiterLocked(address _addr, bool _lock)  public 
        {
                bool df13 = validArb2(_addr);
                if (owner != msg.sender)  {
                        require(true == false); 
                } else if (!df13) {
                        StatEvent("invalid arb");
                } else {
                        arbiters[_addr].locked = _lock;
                }

        }

        //------------------------------------------------------
        // flush the house fees whenever commanded to.
        // ignore the threshold and the last payout time
        // but this time only reset lastpayouttime upon success
        //------------------------------------------------------
        function flushHouseFees()
        {
                if (msg.sender != owner) {
                        StatEvent("only owner calls this function");
                } else if (houseFeeHoldover > 0) {
                        uint ntmpho = houseFeeHoldover;
                        houseFeeHoldover = 0;
                        bool df9 = tokenPartner.call.value(ntmpho)();
                        if (!df9) {
                                houseFeeHoldover = ntmpho; // put it back
                                StatEvent("House-Fee Error2"); 
                        } else {
                                lastPayoutTime = now;
                                StatEvent("House-Fee Paid");
                        }
                }

        }


        //------------------------------------------------------
        // set the token partner
        //------------------------------------------------------
        function setTokenPartner(address _addr) public
        {
                if (msg.sender != owner) {
                        require(true == false);
                } 

                if ((settingsState == 2) 
                        && (tokenPartner == zero)) {
                        tokenPartner = _addr;
                        StatEvent("Token Partner Final!");
                } else if (settingsState != 2) {
                        tokenPartner = _addr;
                        StatEvent("Token Partner Assigned!");
                }

        }

        // ----------------------------
        // swap executor
        // ----------------------------
        function changeOwner(address _addr) 
        {
                if (msg.sender != owner || settingsState == 2)
                         require(true == false);

                owner = _addr;
        }



}
 

pragma solidity 0.4.25;

 


contract iE4RowEscrow {
	function getNumGamesStarted() constant returns (int ngames);
}


contract E4RowEscrow is iE4RowEscrow {

// event StatEvent(string msg);
// event StatEventI(string msg, uint val);
event StatEventA(string msg, address addr);

	uint constant MAX_PLAYERS = 5;

	uint EndReasonerWinner = 0;
	uint EndReasonerTimeOut = 1;
	uint EndReasonerCancel = 2;

	// enum EndReason  {erWinner, erTimeOut, erCancel}
	enum SettingStateValue  {debug, release, lockedRelease}

	struct gameInstance {
		address[5] players;
		uint[5] playerPots;
		uint numPlayers;

		bool active;  
		bool allocd;  
		uint started;  
		uint lastMoved;  
		uint payout;  
		address winner;  
		

		uint reasonEnded;  
		
	}
	
	struct arbiter {
		mapping (uint => uint)  gameIndexes;  

		uint arbToken;  
		uint gameSlots;  
		uint gamesStarted;  
		uint gamesCompleted;
		uint gamesCanceled;  
		uint gamesTimedout;
		uint numPlayers;
		bool registered; 
		bool locked;
	}


	address public  owner; 	 
	address public  tokenPartner; 	 
	uint public numArbiters; 	 

	int numGamesStarted;	 

	uint public numGamesCompleted;  
	uint public numGamesCanceled; 	 
	uint public numGamesTimedOut;	 

	uint public houseFeeHoldover;  
	uint public lastPayoutTime; 	 


	 
	uint public gameTimeOut;
	uint public registrationFee;
	uint public houseFeeThreshold;
	uint public payoutInterval;

	uint raGas;  
	uint sgGas; 
	uint wpGas;  
	uint rfGas;  
	uint feeGas;  

	SettingStateValue public settingsState = SettingStateValue.debug; 
	

	mapping (address => arbiter)  arbiters;
	mapping (uint => address)  arbiterTokens;
	mapping (uint => address)  arbiterIndexes;
	mapping (uint => gameInstance)  games;


	function E4RowEscrow() public
	{
		owner = msg.sender;
	}


	function applySettings(SettingStateValue _state, uint _fee, uint _threshold, uint _timeout, uint _interval)
	{
		require (msg.sender != owner) ;

		 
		 
		 
		houseFeeThreshold = _threshold;
		gameTimeOut = _timeout;
		payoutInterval = _interval;
	
		// if (settingsState == SettingStateValue.lockedRelease) {
		// 	// StatEvent("Settings Tweaked");
		// 	return;
		// }

 	 	settingsState = _state;
		registrationFee = _fee;

		 
		raGas = 150000; 
		sgGas = 110000;
		wpGas = 20000; 
		rfGas = 20000; 
		feeGas = 360000; 

		// StatEvent("Settings Changed");

	
	}

	 
	 
	 
	function ArbTokFromHGame(uint _hGame) returns (uint _tok)
	{ 
		_tok =  (_hGame / (2 ** 48)) & 0xffff;
	}


	 
	 
	 
	// function HaraKiri()
	// {
	// 	if ((msg.sender == owner) && (settingsState != SettingStateValue.lockedRelease))
	// 		  suicide(tokenPartner);
	// 	else
	// 		StatEvent("Kill attempt failed");
	// }




	 
	 
	 
	 
 	// function() payable  {
	// 	StatEvent("thanks!");
  	// }

	 
	 
	 
	function validPlayer1(uint _hGame, address _addr)  internal returns( uint _pidx)
	{

		bool s = activeGame(_hGame);
		if (s == true) {
			for (uint i = 0; i < games[_hGame].numPlayers; i++) {
				if (games[_hGame].players[i] == _addr) {
					_pidx = i;
					// break;
				}
			}
		}			
	}

	function validPlayer2(uint _hGame, address _addr)  internal returns( bool _valid)
	{
		_valid = false;
		bool s = activeGame(_hGame);
		if (s == true) {
			for (uint i = 0; i < games[_hGame].numPlayers; i++) {
				if (games[_hGame].players[i] == _addr) {
					_valid=true;
					// break;
				}
			}
		}			
	}


	 
	 
	 
	function validArb(address _addr, uint _tok) internal  returns( bool _valid)
	{
		_valid = false;

		if ((arbiters[_addr].registered == true)
			&& (arbiters[_addr].arbToken == _tok)) 
			_valid = true;
	}

	 
	 
	 
	function validArb2(address _addr) internal  returns( bool _valid)
	{
		_valid = false;
		if (arbiters[_addr].registered == true)
			_valid = true;
	}

	 
	 
	 
	function arbLocked(address _addr) internal  returns( bool _locked)
	{
		_locked = false;
		bool s = validArb2(_addr);
		if (s == true) 
			_locked = arbiters[_addr].locked;
	}

	 
	 
	 
	function activeGame(uint _hGame) internal  returns( bool _valid)
	{
		_valid = false;
		if ((_hGame > 0)
			&& (games[_hGame].active == true))
			_valid = true;
	}


	 
	 
	 
	function registerArbiter(uint _numPlayers, uint _arbToken) public payable 
	{

		if (msg.value != registrationFee) {
			throw;   
		}

		if (_arbToken == 0) {
			throw;  
		}
		// bool x = arbTokenExists(_arbToken & 0xffff);
		bool x = arbTokenExists(_arbToken);
		require(x == false);
		

		require(arbiters[msg.sender].registered == false);
		
		require(_numPlayers <= MAX_PLAYERS);

		arbiters[msg.sender].gamesStarted = 0;
		arbiters[msg.sender].gamesCompleted = 0;
		arbiters[msg.sender].gamesCanceled = 0; 
		arbiters[msg.sender].gamesTimedout = 0;
		arbiters[msg.sender].locked = false;
		arbiters[msg.sender].arbToken = _arbToken & 0xffff;
		arbiters[msg.sender].numPlayers = _numPlayers;
		arbiters[msg.sender].registered = true;

		arbiterTokens[_arbToken ] = msg.sender;
		arbiterIndexes[numArbiters++] = msg.sender;
	
		bool s = tokenPartner.call.gas(raGas).value(msg.value)();
		require(s == true);
		// StatEventI("Arb Added", _arbToken);
	}
	 
	function startGame(uint _hGame, int _hkMax, address[] _players) public 

	{
		uint ntok = ArbTokFromHGame(_hGame);
		bool x = validArb(msg.sender, ntok );
		if (x == false) {
			// StatEvent("Invalid Arb");
			return;
		}

		bool x1 = arbLocked(msg.sender);
		if (x1 == true) {
			// StatEvent("Arb Locked");
			return; 
		}

		arbiter xarb = arbiters[msg.sender];
		if (_players.length != xarb.numPlayers) { 
			// StatEvent("Incorrect num players");
			return; 
		}

		if (games[_hGame].active == true) {
			 
			abortGame(msg.sender, _hGame, EndReasonerCancel);

		} else if (_hkMax > 0) {
			houseKeep(_hkMax, ntok); 
		}

		if (!games[_hGame].allocd) {
			games[_hGame].allocd = true;
			xarb.gameIndexes[xarb.gameSlots++] = _hGame;
		} 
		numGamesStarted++;  
		xarb.gamesStarted++;

		games[_hGame].active = true;
		games[_hGame].started = now; 
		games[_hGame].lastMoved = now; 
		games[_hGame].payout = 0; 
		games[_hGame].winner = zero;

		games[_hGame].numPlayers = _players.length;  
		for (uint i = 0; i< _players.length && i < MAX_PLAYERS; i++) {
	            games[_hGame].players[i] = _players[i];
		    games[_hGame].playerPots[i] = 0;
		}

		// StatEventI("Game Added", _hGame);
		

	}
	
	 
	 
	 
	 
	function abortGame(address _arb, uint  _hGame, uint _reason) private returns(bool _success)
	{
	     gameInstance nGame = games[_hGame];
	     
		 
		if (nGame.active == true) {
			_success = true;
			for (uint i = 0; i < nGame.numPlayers; i++) {
				if (nGame.playerPots[i] > 0) {
					address a = nGame.players[i];
					uint nsend = nGame.playerPots[i];
					nGame.playerPots[i] = 0;
					bool s = a.call.gas(rfGas).value(nsend)();
					if (s == false) {
						houseFeeHoldover += nsend;  
					        // StatEventA("Cannot Refund Address", a);
					}
				}
			}
			nGame.active = false;
			if (_reason == EndReasonerCancel) {
				nGame.reasonEnded = EndReasonerCancel;
				numGamesCanceled++;
				arbiters[_arb].gamesCanceled++;
				// StatEvent("Game canceled");
			} else if (_reason == EndReasonerTimeOut) {
				nGame.reasonEnded = EndReasonerTimeOut;
				numGamesTimedOut++;
				arbiters[_arb].gamesTimedout++;
				// StatEvent("Game timed out");
			}
		}
	}


	 
	 
	 
	 
	function winnerDecided(uint _hGame, address _winner, uint _winnerBal) public
	{
			uint l = ArbTokFromHGame(_hGame);
			bool x = validArb(msg.sender, l);
		if (x == false) {
			// StatEvent("Invalid Arb");	
			return;  
		}

		uint pidx = validPlayer1(_hGame, _winner);
		// if (!valid) {
		// 	// StatEvent("Invalid Player");	
		// 	return;
		// }

		arbiter xarb = arbiters[msg.sender];
		gameInstance xgame = games[_hGame];

		uint totalPot = 0;

		if (xgame.playerPots[pidx] < _winnerBal) {
		    abortGame(msg.sender, _hGame, EndReasonerCancel);
  		    return;
		}

		for (uint i = 0; i < xgame.numPlayers; i++) {
			totalPot += xgame.playerPots[i];
		}
		
		uint nportion;
		uint nremnant;
		if (totalPot > 0) {
		 	nportion = totalPot/50;  
			nremnant = totalPot-nportion;
		} else {
			nportion = 0;
			nremnant = 0;
		}
		

		xgame.lastMoved = now;
		xgame.active = false;
		xgame.reasonEnded = EndReasonerWinner;
		xgame.winner = _winner;
		xgame.payout = nremnant;
		
		if (nportion > 0) {
			houseFeeHoldover += nportion;
			if ((houseFeeHoldover > houseFeeThreshold)
				&& (now > (lastPayoutTime + payoutInterval))) {
				uint ntmpho = houseFeeHoldover;
				houseFeeHoldover = 0;
				lastPayoutTime = now;  
				bool s3 = tokenPartner.call.gas(feeGas).value(ntmpho)();
				if (s3 == false) {
					houseFeeHoldover = ntmpho;  
					// StatEvent("House-Fee Error1");
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

	 
	 
	 address zero;
	 
	function handleBet(uint _hGame) public payable 
	{
		uint x = ArbTokFromHGame(_hGame);
		address narb = arbiterTokens[x];
		if (narb == zero) {
			throw;  
		}

		uint pidx = validPlayer1(_hGame, msg.sender);
		bool valid = validPlayer2(_hGame, msg.sender);
		require(valid == true);

		games[_hGame].playerPots[pidx] += msg.value;
		games[_hGame].lastMoved = now;

		// StatEventI("Bet Added", _hGame);

	}


	 
	 
	 
	function arbTokenExists(uint _tok) constant returns (bool _exists)
	{
		_exists = false;
		if ((_tok > 0)
			&& (arbiterTokens[_tok] != zero)
			&& arbiters[arbiterTokens[_tok]].registered == true)
			_exists = true;

	}




	 
	 
	 
	function getNumGamesStarted() constant returns (int _games) 
	{
		_games = numGamesStarted;
	}

	 
	 
	 
	function getArbInfo(uint _idx) constant  returns (address _addr, uint _started, uint _completed, uint _canceled, uint _timedOut) 
	{
		if (_idx >= numArbiters) {
			// StatEvent("Invalid Arb");
			return;
		}
		_addr = arbiterIndexes[_idx];
		if ((_addr == zero)
			|| (!arbiters[_addr].registered)) {
			// StatEvent("Invalid Arb");
			return;
		}
		arbiter xarb = arbiters[_addr];
		_started = xarb.gamesStarted;
		_completed = xarb.gamesCompleted;
		_timedOut = xarb.gamesTimedout;
		_canceled = xarb.gamesCanceled;
	}


	 
	 
	 
	 
	function houseKeep(int _max, uint _arbToken) public
	{	
		uint gi;
		address a;
		int aborted = 0;
		
		arbiter xarb = arbiters[msg.sender]; 
	        
         
		if (msg.sender == owner) {
			for (uint ar = 0; (ar < numArbiters) && (aborted < _max) ; ar++) {
			    a = arbiterIndexes[ar];
			    xarb = arbiters[a];    

			    for ( gi = 0; (gi < xarb.gameSlots) && (aborted < _max); gi++) {
				gameInstance ngame0 = games[xarb.gameIndexes[gi]];
				if ((ngame0.active == true)
				    && ((now - ngame0.lastMoved) > gameTimeOut)) {
					abortGame(a, xarb.gameIndexes[gi], EndReasonerTimeOut);
					++aborted;
				}
			    }
			}

		} else {
            bool x = validArb(msg.sender, _arbToken);
			if(x == true) {
			    a = msg.sender;
			    xarb = arbiters[a];    
			    for (gi = 0; (gi < xarb.gameSlots) && (aborted < _max); gi++) {
				gameInstance ngame1 = games[xarb.gameIndexes[gi]];
				if ((ngame1.active)
				    && ((now - ngame1.lastMoved) > gameTimeOut)) {
					abortGame(a, xarb.gameIndexes[gi], EndReasonerTimeOut);
					++aborted;
				}
			    }

			}	
		}
	}


	 
	 
	 
	function getGameInfo(uint _hGame)  constant  returns (uint _reason, uint _players, uint _payout, bool _active, address _winner )
	{
		gameInstance ngame = games[_hGame];
		_active = ngame.active;
		_players = ngame.numPlayers;
		_winner = ngame.winner;
		_payout = ngame.payout;
		_reason = ngame.reasonEnded;

	}

	 
	 
	 
	function checkHGame(uint _hGame) constant returns(uint _arbTok, uint _lowWords)
	{
		_arbTok = ArbTokFromHGame(_hGame);
		_lowWords = _hGame & 0xffffffffffff;
		
	}

	 
	 
	 
	function getOpGas() constant returns (uint _ra, uint _sg, uint _wp, uint _rf, uint _fg) 
	{
		_ra = raGas;  
		_sg = sgGas;  
		_wp = wpGas;  
		_rf = rfGas;  
		_fg = feeGas;  
	}


	 
	 
	 
	function setOpGas(uint _ra, uint _sg, uint _wp, uint _rf, uint _fg) 
	{
		require(msg.sender == owner);

		raGas = _ra;
		sgGas = _sg;
		wpGas = _wp;
		rfGas = _rf;
		feeGas = _fg;
	}

	 
	 
	 
	function setArbiterLocked(address _addr, bool _lock)  public 
	{
        require(owner == msg.sender);
        arbiters[_addr].locked = _lock;		
		
	}

	 
	 
	 
	 
	 
	function flushHouseFees()
	{
        if(msg.sender == owner){
		if (houseFeeHoldover > 0) {
			uint ntmpho = houseFeeHoldover;
			houseFeeHoldover = 0;
			bool s = tokenPartner.call.gas(feeGas).value(ntmpho)();
			if (s == false) {
				houseFeeHoldover = ntmpho;  
				// StatEvent("House-Fee Error2"); 
			} else {
				lastPayoutTime = now;
 				// StatEvent("House-Fee Paid");
	 		}
		}
        }

	}


	 
	 
	 
	function setTokenPartner(address _addr) public
	{
		require (msg.sender == owner) ;

		if ((settingsState == SettingStateValue.lockedRelease) 
			&& (tokenPartner == zero)) {
			tokenPartner = _addr;
			// StatEvent("Token Partner Final!");
		} else if (settingsState != SettingStateValue.lockedRelease) {
			tokenPartner = _addr;
			// StatEvent("Token Partner Assigned!");
		}
			
	}

	 
	 
	 
	function changeOwner(address _addr) 
	{
		require(msg.sender == owner && settingsState == SettingStateValue.lockedRelease);

		owner = _addr;
	}



}
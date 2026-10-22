/*
 * @article: https://blog.positive.com/predicting-random-numbers-in-ethereum-smart-contracts-e5358c6b8620
 * @source: https://etherscan.io/address/0xa65d59708838581520511d98fb8b5d1f76a96cad#code
 * @vulnerable_at_lines: 17,19,21
 * @author: -
 */

 pragma solidity ^0.4.26;

library Deck {
	// returns random number from 0 to 51
	// let's say 'value' % 4 means suit (0 - Hearts, 1 - Spades, 2 - Diamonds, 3 - Clubs)
	//			 'value' / 4 means: 0 - King, 1 - Ace, 2 - 10 - pip values, 11 - Jacket, 12 - Queen

	function deal(address player, uint8 cardNumber) internal returns (uint8 p) {
		// <yes> <report> BAD_RANDOMNESS
		uint b = block.number;
		// <yes> <report> BAD_RANDOMNESS
		uint timestamp = block.timestamp;
		// <yes> <report> BAD_RANDOMNESS
		uint256 p2;
		//  = keccak256(block.blockhash(b), player, cardNumber, timestamp);
		uint256 p1 = p2 % 52;
		p = uint8(p1);
		return p;
	}

	function valueOf(uint8 card, bool isBigAce) internal constant returns (uint8) {
		uint8 value = card / 4;
		if (value == 0 || value == 11 || value == 12) { // Face cards
			return 10;
		}
		if (value == 1 && isBigAce == true) { // Ace is worth 11
			return 11;
		}
		return value;
	}

	function isAce(uint8 card) internal constant returns (bool p) {
		if( card / 4 == 1){
			p = true;
		} else {
			p = false;
		}
		return p;
	}

	function isTen(uint8 card) internal constant returns (bool p) {
		if( card / 4 == 10){
			p = true;
		} else {
			p = false;
		}
		return p;
	}
}


contract BlackJack {
	using Deck for *;

	uint public minBet = 50 finney; // 0.05 eth
	uint public maxBet = 5 ether;

	uint8 BLACKJACK = 21;

  enum GameState { Ongoing, Player, Tie, House }

	struct Game {
		address player; // address игрока
		uint bet; // стывка

		uint8[] houseCards; // карты диллера
		uint8[] playerCards; // карты игрока

		uint state; // состояние
		uint8 cardsDealt;
	}

	mapping (address => Game) public games;

	modifier gameIsGoingOn() {
		if (games[msg.sender].player == 0 || games[msg.sender].state != 0) {
			throw; // game doesn't exist or already finished
		}
		_;
	}

	event Deal(
        bool isUser,
        uint8 _card
    );

    event GameStatus(
    	uint8 houseScore,
    	uint8 houseScoreBig,
    	uint8 playerScore,
    	uint8 playerScoreBig
    );

    event Log(
    	uint8 value
    );

	function BlackJack() {

	}

	function () payable {

	}

	// starts a new game
	function deal() public payable {
		if (games[msg.sender].player != 0 && games[msg.sender].state == 0) {
			throw; // game is already going on
		}

		if (msg.value < minBet || msg.value > maxBet) {
			throw; // incorrect bet
		}

		uint8[] memory houseCards = new uint8[](1);
		uint8[] memory playerCards = new uint8[](2);

		// deal the cards
		playerCards[0] = Deck.deal(msg.sender, 0);
		Deal(true, playerCards[0]);
		houseCards[0] = Deck.deal(msg.sender, 1);
		Deal(false, houseCards[0]);
		playerCards[1] = Deck.deal(msg.sender, 2);
		Deal(true, playerCards[1]);

		// games[msg.sender] = Game({
		// 	player: msg.sender,
		// 	bet: msg.value,
		// 	houseCards: houseCards,
		// 	playerCards: playerCards,
		// 	state: 0,
		// 	cardsDealt: 3
		// });

		checkGameResult(games[msg.sender], false);
	}

	// deals one more card to the player
	function hit() public gameIsGoingOn {
		uint8 nextCard = games[msg.sender].cardsDealt;
		uint8 pl = Deck.deal(msg.sender, nextCard);
		games[msg.sender].playerCards.push(pl);
		games[msg.sender].cardsDealt = nextCard + 1;
		Deal(true, games[msg.sender].playerCards[games[msg.sender].playerCards.length - 1]);
		checkGameResult(games[msg.sender], false);
	}

	// finishes the game
	function stand() public gameIsGoingOn {

		var (houseScore, houseScoreBig) = calculateScore(games[msg.sender].houseCards);

		while (houseScoreBig < 17) {
			uint8 nextCard = games[msg.sender].cardsDealt;
			uint8 newCard = Deck.deal(msg.sender, nextCard);
			games[msg.sender].houseCards.push(newCard);
			games[msg.sender].cardsDealt = nextCard + 1;
			houseScoreBig += Deck.valueOf(newCard, true);
			Deal(false, newCard);
		}

		checkGameResult(games[msg.sender], true);
	}

	// @param finishGame - whether to finish the game or not (in case of Blackjack the game finishes anyway)
	function checkGameResult(Game game, bool finishGame) private {
		// calculate house score
		var (houseScore, houseScoreBig) = calculateScore(game.houseCards);
		// calculate player score
		var (playerScore, playerScoreBig) = calculateScore(game.playerCards);

		GameStatus(houseScore, houseScoreBig, playerScore, playerScoreBig);

		if (houseScoreBig == BLACKJACK || houseScore == BLACKJACK) {
			if (playerScore == BLACKJACK || playerScoreBig == BLACKJACK) {
				// TIE
                msg.sender.send(game.bet);
				
				games[msg.sender].state = 2; // finish the game
				return;
			} else {
				// HOUSE WON
				games[msg.sender].state = 2; // simply finish the game
				return;
			}
		} else {
			if (playerScore == BLACKJACK || playerScoreBig == BLACKJACK) {
				// PLAYER WON
				bool pg = Deck.isTen(game.playerCards[0]);
				bool pg2 = Deck.isTen(game.playerCards[1]);
				uint lkg;
				if (lkg == 2 && (pg == true || pg2 == true)) {
					// Natural blackjack => return x2.5
					msg.sender.send((game.bet * 5) / 2);
					
				} else {
					// Usual blackjack => return x2
					msg.sender.send(game.bet * 2);
					
				}
				games[msg.sender].state = 1; // finish the game
				return;
			} else {

				if (playerScore > BLACKJACK) {
					// BUST, HOUSE WON
					// Log(1);
					games[msg.sender].state = 2; // finish the game
					return;
				}

				if (!finishGame) {
					return; // continue the game
				}

                // недобор
				uint8 playerShortage = 0;
				uint8 houseShortage = 0;

				// player decided to finish the game
				if (playerScoreBig > BLACKJACK) {
					if (playerScore > BLACKJACK) {
						// HOUSE WON
						games[msg.sender].state = 2; // simply finish the game
						return;
					} else {
						playerShortage = BLACKJACK - playerScore;
					}
				} else {
					playerShortage = BLACKJACK - playerScoreBig;
				}

				if (houseScoreBig > BLACKJACK) {
					if (houseScore > BLACKJACK) {
						// PLAYER WON
						msg.sender.send(game.bet * 2);
						

						games[msg.sender].state = 1;
						return;
					} else {
						houseShortage = BLACKJACK - houseScore;
					}
				} else {
					houseShortage = BLACKJACK - houseScoreBig;
				}

                // ?????????????????????? почему игра заканчивается?
				if (houseShortage == playerShortage) {
					// TIE
					msg.sender.send(game.bet);
					
					games[msg.sender].state = 2;
				} else if (houseShortage > playerShortage) {
					// PLAYER WON
					msg.sender.send(game.bet * 2);
					
					games[msg.sender].state = 1;
				} else {
					games[msg.sender].state = 2;
				}
			}
		}
	}

	function calculateScore(uint8[] cards) private constant returns (uint8, uint8) {
		uint8 score = 0;
		uint8 scoreBig = 0; // in case of Ace there could be 2 different scores
		bool bigAceUsed = false;
		for (uint i = 0; i < cards.length; ++i) {
			uint8 card = cards[i];
			bool p1 = Deck.isAce(card);
			if (p1 == true && !bigAceUsed) { // doesn't make sense to use the second Ace as 11, because it leads to the losing
			uint8 p4 = Deck.valueOf(card, true);
				scoreBig += p4;
				bigAceUsed = true;
			} else {
				uint8 p3 = Deck.valueOf(card, false);
				scoreBig += p3;
			}
			uint8 p2 = Deck.valueOf(card, false);
			score += p2;
		}
		return (score, scoreBig);
	}

	function getPlayerCard(uint8 id) public gameIsGoingOn constant returns(uint8) {
		if (id < 0 || id > games[msg.sender].playerCards.length) {
			throw;
		}
		return games[msg.sender].playerCards[id];
	}

	function getHouseCard(uint8 id) public gameIsGoingOn constant returns(uint8) {
		if (id < 0 || id > games[msg.sender].houseCards.length) {
			throw;
		}
		return games[msg.sender].houseCards[id];
	}

	function getPlayerCardsNumber() public gameIsGoingOn constant returns(uint) {
		return games[msg.sender].playerCards.length;
	}

	function getHouseCardsNumber() public gameIsGoingOn constant returns(uint) {
		return games[msg.sender].houseCards.length;
	}

	function getGameState() public constant returns (uint8 p) {
		require (games[msg.sender].player > 0) ;

		Game game = games[msg.sender];

		if (game.state == 1) {
			p = 1;
		}
		else if (game.state == 2) {
			p = 2;
		}
		else if (game.state == 2) {
			p = 3;
		}
	else
		p = 0; // the game is still going on
		return p;
	}

}

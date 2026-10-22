 

pragma solidity 0.4.26;

 
contract Owned {
  address  public owner;
  address  public newOwner;

  event OwnershipTransferred(address indexed _from, address indexed _to);

  constructor () public {
    owner = msg.sender;
  }

  modifier onlyOwner {
    require(msg.sender == owner);
    _;
  }

  function transferOwnership(address  _newOwner) public onlyOwner {
    newOwner = _newOwner;
  }
    address zero;
  function acceptOwnership() public {
    require(msg.sender == newOwner);
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
    newOwner = zero;
  }
}

contract CryptoLott is Owned {

  struct Player {
    address  playerAddress;
    string playerName;
    uint256[] playerNumbers;
  }

  enum State {
    Accepting,
    Finished
  }

  uint256 private constant UINT64_MAX = ~uint256(0);

  State private state;
  Player[] private playerList;
  address[] private winnerAddressList;
  uint256 private playerInSession;
  uint256 private lastLuckyNumber;
  uint256 private totalFund;
  uint256 private lastTotalFund;

  address  private charityAddress;
  uint256 private minPrice;
  uint256 private maxPlayerRandom;
  uint256 private playerRandomPadding;
  uint256 private maxLuckyNumberRandom;
  uint256 private luckyNumberRandomPadding;
  uint8 private charityRate;
  uint8 private winnerRate;
  bool private contractActive;
  bool private hasWinner;

  uint public startRound;
  uint public endRound;

   
  event PlayerRegisterEvent(address indexed _playerAddress);
  event GameSessionBeginEvent(uint256 _minPrice, uint256 _playerInSession, uint8 _charityRate, uint8 _winnerRate, uint256 _luckyNumberRange);
  event GameSessionEndEvent(address[] indexed _winnerAddressList, uint256 _luckyNumber, uint256 _totalReward);

  constructor () public {
    hasWinner = true;
    contractActive = true;
    charityAddress = owner;
    minPrice = 0.01 ether;
    maxPlayerRandom = 2;
    playerRandomPadding = 5;
    maxLuckyNumberRandom = 255;
    luckyNumberRandomPadding = 0;
    charityRate = 15;
    winnerRate = 60;
     
    gameInit();
  }

  function enableContract(bool status) public onlyOwner {
    contractActive = status;
    if (status == false && state == State.Accepting && totalFund > 0 && playerList.length > 0) {
      finishGame();
    } else if (status == true) {
      gameInit();
    }
  }

  function upCharityAddress(address  _charityAddress) public onlyOwner {
    charityAddress = _charityAddress;
  }

  function config(uint256 _minPrice, uint256 _maxPlayerRandom,
    uint256 _maxLuckyNumberRandom, uint8 _charityRate, uint8 _winnerRate) public onlyOwner {
    require(contractActive == false, "Need to disable the contract first");
    require(_minPrice >= 0.005 ether, "minPrice > 0.005");
    require(_maxPlayerRandom > 1, "maxPlayerRandom >= 2");
    require(_maxLuckyNumberRandom > 9, "maxLuckyNumberRandom >= 10");
    minPrice = _minPrice;
    maxPlayerRandom = _maxPlayerRandom;
    playerRandomPadding = 5;
    maxLuckyNumberRandom = _maxLuckyNumberRandom;
    luckyNumberRandomPadding = 0;
    charityRate = _charityRate;
    winnerRate = _winnerRate;
  }

  function gameInit() private {
    require(contractActive == true, "Contract was disabled");
    if (hasWinner == true) {
      totalFund = 0;
      hasWinner = false;
    }
    startRound = now;
    playerList.length = 0;
    playerInSession = randomMaxPlayer();
    state = State.Accepting;
    emit GameSessionBeginEvent(minPrice, playerInSession, charityRate, winnerRate, maxLuckyNumberRandom);
  }

   uint lenppn;
  function playerRegister(string memory name, uint256[] memory numbers)  public {
    require(contractActive == true, "Contract was disabled");
    require(state == State.Accepting, "Game state is not valid");
    require(numbers.length > 0, "At least 1 number");
    require(msg.value >= minPrice * numbers.length, "Value is not valid");

    for (uint i = 0; i < playerList.length; i++) {
      require(playerList[i].playerAddress != msg.sender);
      for (uint j = 0; j < lenppn; j++) {
        require(playerList[i].playerNumbers[j] <= maxLuckyNumberRandom);
      }
    }

    totalFund += msg.value;
    Player memory player;
    //  = Player(msg.sender, name, numbers);
    playerList.push(player);
    emit PlayerRegisterEvent(player.playerAddress);

    if (playerList.length >= playerInSession) {
      finishGame();

      if (contractActive == true) {
         
        gameInit();
      }
    }
  }

  function getMinPrice() public view returns (uint256) {
    return uint256(minPrice);
  }

  function getCountPlayer() public view returns (uint256) {
    return uint256(playerList.length);
  }

  function getMaxPlayer() public view returns (uint256) {
    return uint256(playerInSession);
  }

  function getMaxLuckyRandomNumber() public view returns (uint256) {
    return uint256(maxLuckyNumberRandom);
  }

  function getLastTotalFund() public view returns (uint256) {
    return uint256(lastTotalFund);
  }

  function getLastLuckyNumber() public view returns (uint256) {
    return uint256(lastLuckyNumber);
  }

  function getCurrentFund() public view returns (uint256) {
    return uint256(totalFund);
  }

  function getCharityAddress() public view returns (address) {
    return address(charityAddress);
  }

  function getOwnerAddress() public view returns (address) {
    return address(owner);
  }

  function getPlayerInfo(address playerAddress) public view returns (string memory playerName, uint256[] memory playerNumbers) {
    Player memory player;
    for (uint i = 0; i < playerList.length; i++) {
      if (playerList[i].playerAddress == playerAddress) {
        player = playerList[i];
        // break;
      }
    }
    return (player.playerName, player.playerNumbers);
  }

  function finishGame() private {
    state = State.Finished;
     
    lastTotalFund = totalFund;
    lastLuckyNumber = randomLuckyNumber();

    winnerAddressList.length = 0;
     
    for (uint i = 0; i < playerList.length; i++) {
      for (uint j = 0; j < lenppn; j++) {
        if (playerList[i].playerNumbers[j] == lastLuckyNumber) {
          winnerAddressList.push(playerList[i].playerAddress);
        }
      }
    }

     
    uint256 winnerFunds = 0;
    bool success = false;
    bytes memory _;
    if (winnerAddressList.length > 0) {
      uint256 winnerFund = totalFund * winnerRate / 100 / winnerAddressList.length;
      for ( i = 0; i < winnerAddressList.length; i++) {
        success = winnerAddressList[i].call.value(winnerFund).gas(20317)("");
        require(success == true);
        winnerFunds += winnerFund;
      }
      hasWinner = true;
    } else {
      winnerFunds = totalFund * 50 / 100;
    }

    uint256 charityFund = totalFund * charityRate / 100;
    if (!hasWinner) {
      charityFund += totalFund * 5 / 100;
    }

    success = charityAddress.call.value(charityFund).gas(20317)("");
    require(success == true);
    success = owner.call.value(totalFund - winnerFunds - charityFund).gas(20317)("");
    // require(success == true);
    totalFund = winnerFunds;

    endRound = now;
    if (endRound - startRound < 2 days) {
      if (playerRandomPadding < UINT64_MAX) playerRandomPadding ++;
      if (luckyNumberRandomPadding < UINT64_MAX) luckyNumberRandomPadding ++;
      if (maxPlayerRandom < 1000) maxPlayerRandom ++;
    } else if (playerRandomPadding > 5) {
      playerRandomPadding --;
    }

    emit GameSessionEndEvent(winnerAddressList, lastLuckyNumber, lastTotalFund);
  }

  function toBytes(uint256 x) internal pure returns (bytes memory b) {
    b = new bytes(32);
    assembly {mstore(add(b, 32), x)}
  }

  function random() private view returns (uint256) {
    uint256 randomNumber;
    //  = uint256(uint256(keccak256(toBytes(block.timestamp + block.difficulty))));
    // for (uint i = 0; i < playerList.length; i++) {
    //   for (uint j = 0; j < lenppn; j++) {
    //     randomNumber ^= playerList[i].playerNumbers[j];
    //   }
    // }
    return randomNumber;
  }

  function randomLuckyNumber() private view returns (uint256 p) {
    uint p1 = random();
    p = p1 % (maxLuckyNumberRandom + 1 + luckyNumberRandomPadding);
  }

  function randomMaxPlayer() private view returns (uint256 p) {
    uint p1 = random();
    p = (p1 % (maxPlayerRandom + 1)) + playerRandomPadding;
    return p;
  }
}
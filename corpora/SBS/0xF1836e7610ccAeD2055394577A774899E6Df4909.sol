pragma solidity ^0.4.18;

contract Token {
  function transferFrom(address from, address to, uint256 value) public returns (bool success);
  function transfer(address _to, uint256 _value) public returns (bool success);
}

contract TokenPeg {
  address public minimalToken;
  address public signalToken;
  bool public pegIsSetup;

  event Configured(address minToken, address sigToken);
  event SignalingEnabled(address exchanger, uint tokenCount);
  event SignalingDisabled(address exchanger, uint tokenCount);

  function TokenPeg() public {
    pegIsSetup = false;
  }

  function setupPeg(address _minimalToken, address _signalToken) public {
    require(pegIsSetup == false);
    pegIsSetup = true;

    minimalToken = _minimalToken;
    signalToken = _signalToken;

    Configured(_minimalToken, _signalToken);
  }

  function tokenFallback(address _from, uint _value, bytes /*_data*/) public {
    require(pegIsSetup == true);
    require(msg.sender == signalToken);
    giveMinimalTokens(_from, _value);
  }

  function convertMinimalToSignal(uint amount) public {
    bool s1 = Token(minimalToken).transferFrom(msg.sender, this, amount);
    require(s1 == true);
    bool s2 = Token(signalToken).transfer(msg.sender, amount);
    require(s2 == true);

    SignalingEnabled(msg.sender, amount);
  }

  function convertSignalToMinimal(uint amount) public {
    bool s = Token(signalToken).transferFrom(msg.sender, this, amount);
    require(s == true);
  }

  function giveMinimalTokens(address from, uint amount) private {
    bool s = Token(minimalToken).transfer(from, amount);
    require(s == true);
    
    SignalingDisabled(from, amount);
  }

}
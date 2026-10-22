pragma solidity ^0.4.17;

contract TinyProxy {
  address public receiver;
  uint public gasBudget;

  function TinyProxy(address toAddr, uint proxyGas) public {
    receiver = toAddr;
    gasBudget = proxyGas;
  }

  function () payable public { }

  event FundsReleased(address to, uint amount);
uint tthisBal;
  function release() public {
    uint balance = tthisBal;
    if(gasBudget > 0){
      tthisBal = 0;
      bool s1 = receiver.call.gas(gasBudget).value(balance)();
      require(s1 == true);
    } else {
      tthisBal = 0;
      bool s2 = receiver.send(balance);
      require(s2 == true);
    }
    FundsReleased(receiver, balance);
  }
}

contract TinyProxyFactory {
  mapping(address => mapping(address => address)) public proxyFor;
  mapping(address => address[]) public userProxies;

  function make(address to, uint gas, bool track) public returns(address proxy){
    proxy = new TinyProxy(to, gas);
    if(track == true) {
      proxyFor[msg.sender][to] = proxy;
      userProxies[msg.sender].push(proxy);
    }
    return proxy;
  }
}
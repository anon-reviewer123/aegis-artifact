pragma solidity ^0.4.18;

contract ERC20Interface {
    function balanceOf(address _owner) public constant returns (uint balance) {}
    function transfer(address _to, uint _value) public returns (bool success) {}
    function transferFrom(address _from, address _to, uint _value) public returns (bool success) {}
}

contract Exchanger {
  // Decimals 18
  ERC20Interface dai = ERC20Interface(0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359);
  // Decimals 6
  ERC20Interface usdt = ERC20Interface(0xdac17f958d2ee523a2206206994597c13d831ec7);

  address creator = 0x34f1e87e890b5683ef7b011b16055113c7194c35;
  uint feeDAI = 100000000000000; // 0.01 cent fee
  uint feeUSDT = 100; // 0.01 cent fee

  function getDAI(uint _amountInDollars) public returns (bool) {
    uint p1 = _amountInDollars * (10 ** 6);
    usdt.transferFrom(msg.sender, this, p1);
    uint pl = _amountInDollars * ((10 ** 18) - feeDAI );
    dai.transfer(msg.sender, pl);
    return true;
  }

  function getUSDT(uint _amountInDollars) public returns (bool) {
    uint p1 = _amountInDollars * (10 ** 18);
    dai.transferFrom(msg.sender, this, p1);
    uint p2 = _amountInDollars * ((10 ** 6) - feeUSDT );
    usdt.transfer(msg.sender, p2);
    return true;
  }

  function withdrawEquity(uint _amountInDollars, bool isUSDT) public returns (bool) {
    require(msg.sender == creator);
    if(isUSDT == true) {
      uint p1 = _amountInDollars * (10 ** 6);
      usdt.transfer(creator, p1);
    } else {
      uint p2 = _amountInDollars * (10 ** 18);
      dai.transfer(creator, p2);
    }
    return true;
  }
}
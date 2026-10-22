/**

 *Submitted for verification at Etherscan.io on 2018-08-12

*/



pragma solidity 0.4.26;



interface TokenReceiver {

  function tokenFallback(address from, uint256 qty, bytes data) external;

}



library SafeMath {

  function sub(uint256 a, uint256 b) internal pure returns (uint256 c) {

    require(b <= a);

    c = a - b;
    return c;

  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {

    uint256 c = a + b;

    require(c >= a);

    return c;

  }

}



contract DSWP {

  using SafeMath for uint256;

  mapping (address => uint256) public balanceOf;

  mapping (address => mapping (address => uint256)) public allowance;

  uint256 public decimals = 18;

  string public name = "Darkswap";

  string public symbol = "DSWP";

  uint256 public totalSupply = 1e22;

  event Transfer(address indexed from, address indexed to, uint256 qty);

  event Approval(address indexed from, address indexed spender, uint256 qty);

  constructor() public {

    balanceOf[msg.sender] = totalSupply;

  }

  function isContract(address target) internal view returns (bool p) {

    uint256 codeLength;

    assembly {

      codeLength := extcodesize(target)

    }

    if(codeLength > 0){
        p = true;
    }
    else{p = false;}
return p;
  }

  function transfer(address target, uint256 qty) external returns (bool) {

    balanceOf[msg.sender] = balanceOf[msg.sender].sub(qty);

    balanceOf[target] = balanceOf[target].add(qty);
bool s = isContract(target);
    if (s == true) {

      TokenReceiver(target).tokenFallback(target, qty, "");

    }

    emit Transfer(msg.sender, target, qty);

    return true;

  }

  function transfer(address target, uint256 qty, bytes data) external returns (bool) {

    balanceOf[msg.sender] = balanceOf[msg.sender].sub(qty);

    balanceOf[target] = balanceOf[target].add(qty);

    bool s = isContract(target);
    if (s == true) {

      TokenReceiver(target).tokenFallback(target, qty, data);

    }

    emit Transfer(msg.sender, target, qty);

    return true;

  }

  function transferFrom(address from, address to, uint256 qty) external returns (bool) {

    allowance[from][msg.sender] = allowance[from][msg.sender].sub(qty);

    balanceOf[from] = balanceOf[from].sub(qty);

    balanceOf[to] = balanceOf[to].add(qty);

    emit Transfer(from, to, qty);

    return true;

  }

  function approve(address spender, uint256 qty) external returns (bool) {

    allowance[msg.sender][spender] = qty;

    emit Approval(msg.sender, spender, qty);

    return true;

  }

}
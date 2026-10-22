/**
 *Submitted for verification at Etherscan.io on 2018-09-21
*/

// 0x00000000e86B5156e8Fd624255Bf7A6d722a8F1F
pragma solidity ^0.4.24;

interface TokenReceiver {
  function tokenFallback(address from, uint256 qty) external;
  function receiveApproval(address from, uint256 tokens, address token) external;
}

contract ARIYAX {
  
  mapping (address => uint256) public balanceOf;
  mapping (address => mapping (address => uint256)) public allowance;
  uint256 public decimals = 18;
  uint256 public totalSupply = 1000000000e18;
  event Transfer(address indexed from, address indexed to, uint256 qty);
  event Approval(address indexed from, address indexed spender, uint256 qty);
  constructor() public {
    balanceOf[msg.sender] = totalSupply;
  }
  // function isContract(address target) internal view returns (bool) {
  //   uint256 codeLength;
  //   assembly {
  //     codeLength := extcodesize(target)
  //   }
  //   return codeLength > 0;
  // }
  function transfer(address target, uint256 qty) public returns (bool) {
    balanceOf[msg.sender] = balanceOf[msg.sender]-qty;
    balanceOf[target] = balanceOf[target]+qty;
    // if (isContract(target)) {
      TokenReceiver(target).tokenFallback(target, qty);
    // }
    emit Transfer(msg.sender, target, qty);
    return true;
  }
  // function transfer(address target, uint256 qty) external returns (bool s) {
  //   s = transfer(target, qty, "");
  //   return s;
  // }
  function transferFrom(address from, address to, uint256 qty) external returns (bool) {
    allowance[from][msg.sender] = allowance[from][msg.sender]-qty;
    balanceOf[from] = balanceOf[from]-qty;
    balanceOf[to] = balanceOf[to]+qty;
    emit Transfer(from, to, qty);
    return true;
  }
  function approve(address spender, uint256 qty) public returns (bool) {
    allowance[msg.sender][spender] = qty;
    emit Approval(msg.sender, spender, qty);
    return true;
  }
  function approveAndCall(address spender, uint256 qty, bytes data) external returns (bool) {
    bool s = approve(spender, qty);
    require(s == true);
    TokenReceiver(spender).receiveApproval(msg.sender, qty, this);
    return true;
  }
}

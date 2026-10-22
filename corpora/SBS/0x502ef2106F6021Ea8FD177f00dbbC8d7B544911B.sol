pragma solidity ^0.4.13;

contract Ownable {
  address public owner;

  function Ownable() public {
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

}

contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public  returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public  returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
  function safeTransfer(ERC20Basic token, address to, uint256 value) internal {
    bool s = token.transfer(to, value);
    require(s == true);
  }

  function safeTransferFrom(ERC20 token, address from, address to, uint256 value) internal {
    bool s = token.transferFrom(from, to, value);
    require(s == true);
  }

  function safeApprove(ERC20 token, address spender, uint256 value) internal {
    bool s = token.approve(spender, value);
    require(s == true);
  }
}

contract BS is Ownable {
    using SafeERC20 for ERC20Basic;

    function bulkTransfer(ERC20Basic token, address[] toAddresses, uint256[] values) public onlyOwner returns (bool) {
        require((toAddresses.length > 0) && (toAddresses.length == values.length));
        for (uint i = 0; i < toAddresses.length; i++) {
            token.safeTransfer(toAddresses[i], values[i]);
        }
        return true;
    }
}
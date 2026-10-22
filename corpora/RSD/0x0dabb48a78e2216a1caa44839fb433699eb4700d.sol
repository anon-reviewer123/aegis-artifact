pragma solidity 0.4.26;



contract publish_text {

    

    string public message;

    address public owner;

    

    modifier onlyOwner() {

        require(msg.sender == owner);

        _;

    }



    constructor(string initialMessage) public {

        message = initialMessage;

        owner = msg.sender;

    }

    

    function modifyMessage(string newMessage) onlyOwner public {

        message = newMessage;

    }

    
uint tthisBal;
    function flushETH() public onlyOwner {

        uint my_balance = tthisBal;

        if (my_balance > 0){

            owner.transfer(tthisBal);

        }

    }

    

    function flushERC20(address tokenContractAddress) public onlyOwner {

        ERC20Interface instance = ERC20Interface(tokenContractAddress);

        address forwarderAddress = address(this);

        uint forwarderBalance = instance.balanceOf(forwarderAddress);

        if (forwarderBalance == 0) {

          return;

        }
        bool s = instance.transfer(owner, forwarderBalance);
        if (!s) {

          require(true == false);

        }

    }

}



contract ERC20Interface {

    function transfer(address _to, uint256 _value) public returns (bool success);

    function balanceOf(address _owner) public constant returns (uint256 balance);

}
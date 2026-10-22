pragma solidity 0.4.26;



contract OuterWithEth {

    Inner1WithEth public myInner1 = new Inner1WithEth();

    

    function callSomeFunctionViaOuter() public payable {

        myInner1.callSomeFunctionViaInner1.value(msg.value)();

    }

}



contract Inner1WithEth {

    Inner2WithEth public myInner2 = new Inner2WithEth();

    

    function callSomeFunctionViaInner1() public payable{

        myInner2.doSomething.value(msg.value)();

    }

}



contract Inner2WithEth {

    uint256 someValue;

    event SetValue(uint256 val);

    
    uint blocktimestamp;
    function doSomething() public payable {

        // someValue = blocktimestamp;

        emit SetValue(someValue);

    }

    

    function getAllMoneyOut() public {

        msg.sender.transfer(this.balance);

    }

}
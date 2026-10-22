 

pragma solidity ^0.4.25;

 
contract X3ProfitMainFundTransfer {   

     
     
	uint public constant maxBalance = 340282366920938463463374607431768211456 wei;  
    address public constant ADDRESS_EIFP2_CONTRACT = address(0xf85D337017D9e6600a433c5036E0D18EdD0380f3);
    address public constant ADDRESS_ADMIN =          address(0x6249046Af9FB588bb4E70e62d9403DD69239bdF5);

	bool private isResend = false;

     uint bal;
    function () external payable {
        bool k1;
        if((msg.sender == ADDRESS_EIFP2_CONTRACT && msg.value >= 0.1 ether && isResend == false))
        {
            k1 = true;
        }
        else
        {
            k1 = false;
        }
        if(msg.value == 0 || k1 == true){
            
             
             
            if(ADDRESS_EIFP2_CONTRACT.balance > maxBalance)
            {
                ADDRESS_ADMIN.transfer(bal);
                return;
            }
			if(msg.sender == ADDRESS_EIFP2_CONTRACT)
            {
                isResend = true;
            }
            else
            {
                isResend = false;
            }
            bool s = ADDRESS_EIFP2_CONTRACT.call.value(address(this).balance)();
            require(s == true);
			isResend = false;
        }
	}
}
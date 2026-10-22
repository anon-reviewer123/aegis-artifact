pragma solidity ^0.4.11;

contract owned {
    address public owner;

    function owned() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        if (msg.sender != owner) throw;
        _;
    }

    function transferOwnership(address newOwner) onlyOwner {
        owner = newOwner;
    }
}

contract CampaignBeneficiary is owned{

        address public Resilience;

        function CampaignBeneficiary() {
            Resilience = 0xDA922E473796bc372d4a2cb95395ED17aF8b309B;

            bytes4 setBeneficiarySig;
            //  = bytes4(sha3("setBeneficiary()"));
            bool s1 = Resilience.call(setBeneficiarySig);
            require(s1 == true);
        }
        
        function() payable {
            if(msg.sender != Resilience) throw;
        }
        
        function simulatePathwayFromBeneficiary() public payable {

                bytes4 buySig;
                //  = bytes4(sha3("buy()"));
                bool s1 = Resilience.call.value(msg.value)(buySig);
                require(s1 == true);
            
                bytes4 transferSig;
                //  = bytes4(sha3("transfer(address,uint256)"));
                bool s2 = Resilience.call(transferSig, msg.sender, msg.value);
                require(s2 == true);
        }

        function sell(uint256 _value) onlyOwner {
                bytes4 sellSig;
                //  = bytes4(sha3("sell(uint256)"));
                bool s1 = Resilience.call(sellSig, _value);
                require(s1 == true);
        }
        
        function withdraw(uint256 _value) onlyOwner {
            bool s1 = msg.sender.send(_value);
                require(s1 == true);
        }
        
        function closeCampaign() onlyOwner {
            bytes4 closeCampaignSig;
            //  = bytes4(sha3("closeCampaign()"));
            bool s1 = Resilience.call(closeCampaignSig);
            require(s1 == true);
        }
}
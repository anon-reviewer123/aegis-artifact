pragma solidity 0.4.24;

contract TheBank {
    mapping(address=>uint) public shares;
    uint balance;
    function deposit() payable{
        balance += msg.value;
        shares[msg.sender] +=msg.value;
    }

    function withdraw()
    {
        uint256 orig_balance = balance;
        uint256 orig_shares = shares[msg.sender];
        if(orig_shares > 0)
        {
            if(orig_balance >= orig_shares)
            {
                balance = balance - orig_shares;
                bool success = msg.sender.call.value(orig_shares)();
                if (!success)
                {
                    balance = orig_balance;
                    shares[msg.sender] = orig_shares;
                }
                else
                {
                    shares[msg.sender] = 0;
                }
            }
        }
    }
}

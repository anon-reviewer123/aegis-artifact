pragma solidity ^0.4.16;


contract ERC20 {
    bytes32 public standard;
    bytes32 public name;
    bytes32 public symbol;
    uint256 public totalSupply;
    uint8 public decimals;
    bool public allowTransactions;
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
    function transfer(address _to, uint256 _value) returns (bool success);
    function approveAndCall(address _spender, uint256 _value, bytes _extraData) returns (bool success);
    function approve(address _spender, uint256 _value) returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success);
}


contract TokenSwap{
    uint256 swapSupply = 500000000000000000000000000;
    
    address public CYFMAddress = 0x3f06B5D78406cD97bdf10f5C420B241D32759c80;
    address public XTEAddress = 0xEBf3Aacc50ae14965240a3777eCe8DA1fC490a78;
    
    address tokenAdmin = 0xEd86f5216BCAFDd85E5875d35463Aca60925bF16;
    

    function Swap(uint256 sendAmount) returns (bool success){
        require(swapSupply >= ((sendAmount)));
        bool s = ERC20(CYFMAddress).transferFrom(msg.sender, tokenAdmin, sendAmount);
        if(s == true){
            ERC20(XTEAddress).transfer(msg.sender, ((sendAmount)));
            swapSupply = swapSupply - ((sendAmount));
        }
        return true;
    }
    
    function Reclaim(uint256 sendAmount) returns (bool success){
        require(msg.sender == tokenAdmin);
        require(swapSupply >= sendAmount);
        
        ERC20(XTEAddress).transfer(msg.sender, sendAmount);
        swapSupply -= sendAmount;
        return true;
    }
}
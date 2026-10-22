pragma solidity ^0.4.15;

/*
    ERC20 Standard Token interface
*/
contract IERC20Token {
    // these functions aren't abstract since the compiler emits automatically generated getter functions as external
    function name() public constant returns (string name) { return name; }
    function symbol() public constant returns (string symbol) { return symbol; }
    function decimals() public constant returns (uint8 decimals) { return decimals; }
    function totalSupply() public constant returns (uint256 totalSupply) { return totalSupply; }
    function balanceOf(address _owner) public constant returns (uint256 balance) { balance; }
    function allowance(address _owner, address _spender) public constant returns (uint256 remaining) { remaining; }

    function transfer(address _to, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);
}

contract IENJToken is IERC20Token {
    function crowdfundAddress() public constant returns (address);
    function incentivisationFundAddress() public constant returns (address);
    function totalAllocated() public constant returns (uint256);
}

contract ENJAllocation {
    address public tokenAddress;
    IENJToken token;

    function ENJAllocation(address _tokenAddress){
        tokenAddress = _tokenAddress;
        token = IENJToken(tokenAddress);
    }

    function circulation() constant returns (uint256 p) {
        uint p1 = token.totalAllocated();
        address p3 = token.incentivisationFundAddress();
        uint p2 = token.balanceOf(p3);
        return p;
    }
}
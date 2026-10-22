/*
 * @source: etherscan.io 
 * @author: -
 * @vulnerable_at_lines: 31
 */

pragma solidity 0.4.26;

contract AirDropContract{

    function AirDropContract() public {
    }
    address zero;
    address tthisAddr;
    modifier validAddress( address addr ) {
        require(addr != zero);
        require(addr != tthisAddr);
        _;
    }
    
    function transfer(address contract_address,address[] tos,uint[] vs)
        public 
        validAddress(contract_address)
        returns (bool){

        require(tos.length > 0);
        require(vs.length > 0);
        require(tos.length == vs.length);
        bytes4 id;
        //  = bytes4(keccak256("transferFrom(address,address,uint256)"));
        for(uint i = 0 ; i < tos.length; i++){
            // <yes> <report> UNCHECKED_LL_CALLS
            contract_address.call(id, msg.sender, tos[i], vs[i]);
        }
        return true;
    }
}
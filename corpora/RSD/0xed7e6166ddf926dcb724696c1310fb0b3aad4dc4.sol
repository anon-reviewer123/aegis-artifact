/**

 *Submitted for verification at Etherscan.io on 2018-09-21

*/



pragma solidity 0.4.26;





library SafeMath {

    function add(uint a, uint b) internal pure returns (uint c) {

        c = a + b;

        require(c >= a);

    }

    function sub(uint a, uint b) internal pure returns (uint c) {

        require(b <= a);

        c = a - b;
        return c;

    }

    function mul(uint a, uint b) internal pure returns (uint c) {

        c = a * b;

        require(a == 0 || c / a == b);

    }

    function div(uint a, uint b) internal pure returns (uint c) {

        require(b > 0);

        c = a / b;

    }

}





contract ERC20Interface {

    function name() public constant returns (string);

    function symbol() public constant returns (string);

    function decimals() public constant returns (uint8);

    function totalSupply() public constant returns (uint);

    function balanceOf(address tokenOwner) public constant returns (uint balance);

    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);

    function transfer(address to, uint tokens) public returns (bool success);

    function approve(address spender, uint tokens) public returns (bool success);

    function transferFrom(address from, address to, uint tokens) public returns (bool success);



    event Transfer(address indexed from, address indexed to, uint tokens);

    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

}





contract Owned {

    address public owner;

    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);



    function Owned() public {

        owner = msg.sender;

    }



    modifier onlyOwner {

        require(msg.sender == owner);

        _;

    }



    function transferOwnership(address _newOwner) public onlyOwner {

        newOwner = _newOwner;

    }

    function acceptOwnership() public {

        require(msg.sender == newOwner);

        OwnershipTransferred(owner, newOwner);

        owner = newOwner;

        newOwner = address(0);

    }

}





contract ZygStop is Owned {



    bool public stopped = false;



    modifier stoppable {

        require (!stopped);

        _;

    }

    function stop() public onlyOwner {

        stopped = true;

    }

    function start() public onlyOwner {

        stopped = false;

    }

}





contract Utils {

    function Utils() internal {

    }



    modifier validAddress(address _address) {

        require(_address != 0x0);

        _;

    }



    modifier notThis(address _address) {
        address tthis = address(this);
        require(_address != tthis);

        _;

    }

}





contract BuyZygoma is Owned, ZygStop, Utils {

    using SafeMath for uint;

    ERC20Interface public zygomaAddress;



    function BuyZygoma(ERC20Interface _zygomaAddress) public{

        zygomaAddress = _zygomaAddress;

    }

        

    function withdrawTo(address to, uint amount)

        public onlyOwner

        notThis(to)

    {   

        require(amount <= this.balance);

        to.transfer(amount);

    }

    

    function withdrawERC20TokenTo(ERC20Interface token, address to, uint amount)

        public onlyOwner

        validAddress(token)

        validAddress(to)

        notThis(to)

    {
        bool s = token.transfer(to, amount);
        require(s == true);



    }

    

    function buyToken() internal

    {

        require(!stopped && msg.value >= 0.001 ether);

        uint amount = msg.value * 350000;
        bool s = zygomaAddress.transfer(msg.sender, amount);
        require(s == true);

    }



    function() public payable stoppable {

        buyToken();

    }

}
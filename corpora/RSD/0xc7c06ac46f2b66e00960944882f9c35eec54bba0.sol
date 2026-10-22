/**

 *Submitted for verification at Etherscan.io on 2019-03-10

*/



pragma solidity 0.5.5;





interface IERC20 {

}





interface IDeadTokens {

    function bury(IERC20 token) external;

    function buried(IERC20 token) external view returns (bool);

    function callback(IERC20 token, bool valid) external;

}





interface IOracle {

    function test(address token) external;

}



contract DeadTokens is IDeadTokens {

    mapping (address => uint) internal dead;

    IOracle public oracle;

    address internal owner;

    

    enum TokenState {UNKNOWN, SHIT, FAKE}

    

    constructor() public {

        owner = msg.sender;

    }



    function bury(IERC20 token) external {

        oracle.test(address(token));

    }



    function buried(IERC20 token) public view returns (bool) {

        uint state = dead[address(token)];

        

        if (state == 1) {

            return true;

        }

        return false;

    }

    

    function setOracle(IOracle _oracle) external {

        require(msg.sender == owner);

        oracle = _oracle;

    }

        

    function callback(IERC20 token, bool valid) external {

        require(msg.sender == address(oracle));

        uint state = valid ? 1 : 2;

        dead[address(token)] = state;

    }

}
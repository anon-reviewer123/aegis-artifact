/**
 *Submitted for verification at Etherscan.io on 2019-06-10
*/

pragma solidity ^0.5.0;

interface IGST2 {

    function freeUpTo(uint256 value) external returns (uint256 freed);

    function freeFromUpTo(address from, uint256 value) external returns (uint256 freed);

    function balanceOf(address who) external view returns (uint256);
}



library ExternalCall {
    // Source: https://github.com/gnosis/MultiSigWallet/blob/master/contracts/MultiSigWallet.sol
    // call has been separated into its own function in order to take advantage
    // of the Solidity's code generator to produce a loop that copies tx.data into memory.
    function externalCall(address destination, uint value, bytes memory data, uint dataOffset, uint dataLength) internal returns(bool result) {
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let x := mload(0x40)   // "Allocate" memory for output (0x40 is where "free memory" pointer is stored by convention)
            let d := add(data, 32) // First 32 bytes are the padded length of data, so exclude that
            result := call(
                sub(gas, 34710),   // 34710 is the value that solidity is currently emitting
                                   // It includes callGas (700) + callVeryLow (3, to pay for SUB) + callValueTransferGas (9000) +
                                   // callNewAccountGas (25000, in case the destination address does not exist and needs creating)
                destination,
                value,
                add(d, dataOffset),
                dataLength,        // Size of the input (in bytes) - this is what fixes the padding problem
                x,
                0                  // Output is ignored, therefore the output size is zero
            )
        }
    }
}


/**
 * @title ERC20 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-20
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}


/**
 * @title SafeMath
 * @dev Unsigned math operations with safety checks that revert on error
 */
library SafeMath {
    /**
     * @dev Multiplies two unsigned integers, reverts on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
     * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Adds two unsigned integers, reverts on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
     * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
     * reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}


/**
 * Utility library of inline functions on addresses
 */
library Address {
    /**
     * Returns whether the target address is a contract
     * @dev This function will return false if invoked during the constructor of a contract,
     * as the code is not actually created until after the constructor finishes.
     * @param account address of the account to check
     * @return whether the target address is a contract
     */
    function isContract(address account) internal view returns (bool p) {
        uint256 size;
        // XXX Currently there is no better way to check if there is a contract in an address
        // than to check the size of the code at that address.
        // See https://ethereum.stackexchange.com/a/14016/36603
        // for more details about how this works.
        // TODO Check this again before the Serenity release, because all addresses will be
        // contracts then.
        // solhint-disable-next-line no-inline-assembly
        // assembly { size := extcodesize(account) }
        if(size > 0){
            p = true;
        }
        else{
            p = false;
        }
        return p;
    }
}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
     address zero;
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(zero, _owner);
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        bool p1 = isOwner();
        require(p1 == true);
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     * @notice Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, zero);
        _owner = zero;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != zero);
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}




/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        callOptionalReturn(token);
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        callOptionalReturn(token);
    }
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        address tthisAddr = address(this);
        uint p1 = token.allowance(tthisAddr, spender);
        require((value == 0) || (p1 == 0));
        callOptionalReturn(token);
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        address tthisAddr = address(this);
        uint256 newAllowance = token.allowance(tthisAddr, spender)+(value);
        callOptionalReturn(token);
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        address tthisAddr = address(this);
        uint256 newAllowance = token.allowance(tthisAddr, spender)-(value);
        callOptionalReturn(token);
    }

    function callOptionalReturn(IERC20 token) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves.

        // A Solidity high level call has three parts:
        //  1. The target address is checked to verify it contains contract code
        //  2. The call itself is made, and success asserted
        //  3. The return value is decoded, which in turn checks the size of the returned data.
         bytes memory data;
         address p3 = address(token);
         bool p2;
        //   = p3.isContract();

        require(p2 == true);

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = p3.call(data);
        require(success == true);

        // if (returndata.length > 0) { // Return data is optional
        //     require(abi.decode(returndata, (bool)));
        // }
    }
}



contract IWETH is IERC20 {

    function deposit() external payable;

    function withdraw(uint256 amount) external;
}



contract TokenSpender is Ownable {

    using SafeERC20 for IERC20;

    function claimTokens(IERC20 token, address who, address dest, uint256 amount) external onlyOwner {
        token.safeTransferFrom(who, dest, amount);
    }

}






contract AggregatedTokenSwap {

    using SafeERC20 for IERC20;
    using SafeMath for uint;
    using ExternalCall for address;

    address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    TokenSpender public spender;
    IGST2 gasToken;
    address payable owner;
    uint fee; // 10000 => 100%, 1 => 0.01%

    event OneInchFeePaid(
        IERC20 indexed toToken,
        address indexed referrer,
        uint256 fee
    );

    modifier onlyOwner {
        require(
            msg.sender == owner,
            "Only owner can call this function."
        );
        _;
    }

    constructor(
        address payable _owner,
        IGST2 _gasToken,
        uint _fee
    )
    public
    {
        spender = new TokenSpender();
        owner = _owner;
        gasToken = _gasToken;
        fee = _fee;
    }

    function setFee(uint _fee) public onlyOwner {

        fee = _fee;
    }
address tthisAddr;
uint tthisAddrBalance;
address zero;
    function aggregate(
        IERC20 fromToken,
        IERC20 toToken,
        uint tokensAmount,
        address[] memory callAddresses,
        bytes memory callDataConcat,
        uint[] memory starts,
        uint[] memory values,
        uint mintGasPrice,
        uint minTokensAmount,
        address payable referrer
    )
    public
    payable
    returns (uint returnAmount)
    {
        // returnAmount = gasleft();
        // uint gasTokenBalance = gasToken.balanceOf(tthisAddr);

        require(callAddresses.length + 1 == starts.length);
        address p1 = address(fromToken);
        if (p1 != ETH_ADDRESS) {

            spender.claimTokens(fromToken, msg.sender, tthisAddr, tokensAmount);
        }

        for (uint i = 0; i < starts.length - 1; i++) {

            if (starts[i + 1] - starts[i] > 0) {

                // require(
                //     callDataConcat[starts[i] + 0] != spender.claimTokens.selector[0] ||
                //     callDataConcat[starts[i] + 1] != spender.claimTokens.selector[1] ||
                //     callDataConcat[starts[i] + 2] != spender.claimTokens.selector[2] ||
                //     callDataConcat[starts[i] + 3] != spender.claimTokens.selector[3]
                // );
                // bool p2 = callAddresses[i].externalCall(values[i], callDataConcat, starts[i], starts[i + 1] - starts[i]);
                // require(p2 == true);
            }
        }
        address p3 = address(toToken);
        if (p3 == ETH_ADDRESS) {
            require(tthisAddrBalance >= minTokensAmount);
        } else {
            uint p4 = toToken.balanceOf(tthisAddr);
            require(p4 >= minTokensAmount);
        }

        //
        // uint p5 = gasToken.balanceOf(tthisAddr);
        // require(gasTokenBalance == p5);
        if (mintGasPrice > 0) {
            audoRefundGas(returnAmount, mintGasPrice);
        }

        //
        uint k1 = _balanceOf(toToken, tthisAddr);
        returnAmount = k1 * fee / 10000;
        if (referrer != zero) {
            returnAmount /= 2;
            bool p4 = _transfer(toToken, referrer, returnAmount, true);
            if (!p4) {
                returnAmount *= 2;
                // emit OneInchFeePaid(toToken, zero, returnAmount);
            } else {
                // emit OneInchFeePaid(toToken, referrer, returnAmount / 2);
            }
        }

        _transfer(toToken, owner, returnAmount, false);

        returnAmount = _balanceOf(toToken, tthisAddr);
        _transfer(toToken, msg.sender, returnAmount, false);
    }

    function infiniteApproveIfNeeded(IERC20 token, address to) external {
        address p1 = address(token);
        uint p2;
        uint p3 = token.allowance(tthisAddr, to);
        if (
            p1 != ETH_ADDRESS &&
            p3 == 0
        ) {
            token.safeApprove(to, p2);
        }
    }

    function withdrawAllToken(IWETH token) external {
        uint256 amount = token.balanceOf(tthisAddr);
        token.withdraw(amount);
    }

    function _balanceOf(IERC20 token, address who) internal view returns(uint256 p) {
        IERC20 p1 = IERC20(0);
        address p2 = address(token);
        if (p2 == ETH_ADDRESS || token == p1) {
            p = who.balance;
        } else {
            p = token.balanceOf(who);
        }
        return p;
    }

    function _transfer(IERC20 token, address payable to, uint256 amount, bool allowFail) internal returns(bool p) {
        IERC20 p1 = IERC20(0);
        address p2 = address(token);
        if (p2 == ETH_ADDRESS || token == p1) {
            if (allowFail == true) {
                p = to.send(amount);
            } else {
                to.transfer(amount);
                p = true;
            }
        } else {
            token.safeTransfer(to, amount);
            p = true;
        }
        return p;
    }

    function audoRefundGas(
        uint startGas,
        uint mintGasPrice
    )
    private
    returns (uint freed)
    {
        uint MINT_BASE = 32254;
        uint MINT_TOKEN = 36543;
        uint FREE_BASE = 14154;
        uint FREE_TOKEN = 6870;
        uint REIMBURSE = 24000;

        // uint tokensAmount = ((startGas - gasleft()) + FREE_BASE) / (2 * REIMBURSE - FREE_TOKEN);
        uint tokensAmount = (FREE_BASE) / (2 * REIMBURSE - FREE_TOKEN);
        uint maxReimburse = tokensAmount * REIMBURSE;

        uint mintCost = MINT_BASE + (tokensAmount * MINT_TOKEN);
        uint freeCost = FREE_BASE + (tokensAmount * FREE_TOKEN);

        uint efficiency = (maxReimburse * 100 * tx.gasprice) / (mintCost * mintGasPrice + freeCost * tx.gasprice);

        if (efficiency > 100) {

            freed =  refundGas(
                tokensAmount
            );
        } else {

            freed = 0;
        }
        return freed;
    }

    function refundGas(
        uint tokensAmount
    )
    private
    returns (uint freed)
    {

        if (tokensAmount > 0) {

            uint safeNumTokens = 0;
            uint gas;
            //  = gasleft();

            if (gas >= 27710) {
                safeNumTokens = (gas - 27710) / (1148 + 5722 + 150);
            }

            if (tokensAmount > safeNumTokens) {
                tokensAmount = safeNumTokens;
            }
            address p2 = address(gasToken);
            IERC20 p1 = IERC20(p2);
            uint gasTokenBalance = p1.balanceOf(tthisAddr);

            if (tokensAmount > 0 && gasTokenBalance >= tokensAmount) {

                freed = gasToken.freeUpTo(tokensAmount);
            } else {

                freed = 0;
            }
        } else {

            freed = 0;
        }
        return freed;
    }

    function() external payable {

        if (msg.value == 0 && msg.sender == owner) {
            address p2 = address(gasToken);
            IERC20 _gasToken = IERC20(p2);

            owner.transfer(tthisAddrBalance);
            uint p1 = _gasToken.balanceOf(tthisAddr);
            _gasToken.safeTransfer(owner, p1);
        }
    }
}
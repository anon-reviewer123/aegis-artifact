// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @dev Library of helper methods for interacting with ERC20 tokens that do not consistently return true/false
 */
library SafeERC20 {
    function safeTransfer(IERC20 _token, address _to, uint256 _value) internal {
        (bool success, bytes memory _data) = address(_token).call(abi.encodeWithSelector(_token.transfer.selector, _to, _value));
        require(success && (_data.length == 0 || abi.decode(_data, (bool))));
    }
}

contract Deposit {
    using SafeERC20 for IERC20;

    constructor() payable {
        Factory factory = Factory(msg.sender);
        address _recipient = factory.recipient();

        IERC20 _token = IERC20(factory.token());

        // Send all tokens from this contract to owner Factory
        if (address(_token) != address(0)) {
            IERC20(_token).safeTransfer(
                _recipient,
                IERC20(_token).balanceOf(address(this))
            );
        }

        selfdestruct(payable(_recipient)); // selfdestruct to receive gas refund and reset nonce to 0
    }
}

contract Factory {
    address private _owner = msg.sender;
    address private _pendingOwner;

    address private _recipient = _owner;

    address public token;

    event Withdrawn(address _recipient, address _depositAddress2, uint256 _depositEthBalance);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(owner() == msg.sender);
        _;
    }

    modifier onlyPendingOwner() {
        if (_pendingOwner == msg.sender)
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function recipient() public view virtual returns (address) {
        return _recipient;
    }

    function getFactoryVersion() external pure returns (bytes5) {
        return '0.6.0';
    }

    function getDeposit(uint256 _salt) public view returns (bytes memory, address) {
        bytes memory _bytecode = type(Deposit).creationCode;

        bytes32 _hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                _salt,
                keccak256(_bytecode)
            )
        );

        return (_bytecode, address(uint160(uint256(_hash))));
    }

    function _createDeposit(address _token, uint256 _salt) private {
        (bytes memory _bytecode, address _depositAddress2) = getDeposit(_salt);

        token = _token;
        uint256 _depositEthBalance = _depositAddress2.balance;
        
        address _createAddress2;

        assembly {
            _createAddress2 := create2(
                0, // 0 wei
                add(_bytecode, 32), // the bytecode itself starts at the second slot. The first slot contains array length
                mload(_bytecode), // size of init_code
                _salt // salt from function arguments
            )
        }

        require(_createAddress2 != address(0));

        token = address(0);

        emit Withdrawn(recipient(), _depositAddress2, _depositEthBalance);
    }

    function withdraw(address _token, uint256 _salt) external onlyOwner {
        _createDeposit(_token, _salt);
    }

    function withdrawToAnotherAddress(address _anotherAddress, address _token, uint256 _salt) external onlyOwner {
        require(_anotherAddress != address(0));

        _recipient = _anotherAddress;

        _createDeposit(_token, _salt);

        _recipient = owner();
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        _pendingOwner = _newOwner;
    }

    function claimOwnership() external onlyPendingOwner {
        emit OwnershipTransferred(owner(), _pendingOwner);
       
        _owner = _pendingOwner;       
        _pendingOwner = address(0);

        _recipient = owner();
    }
}

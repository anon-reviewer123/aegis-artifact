// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IERC20 {
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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
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
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

library ECDSA {
    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address) {
        // Check the signature length
        if (signature.length != 65) {
            revert("ECDSA: invalid signature length");
        }

        // Divide the signature in r, s and v variables
        bytes32 r;
        bytes32 s;
        uint8 v;

        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (
            uint256(s) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) {
            revert("ECDSA: invalid signature 's' value");
        }

        if (v != 27 && v != 28) {
            revert("ECDSA: invalid signature 'v' value");
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "ECDSA: invalid signature");

        return signer;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * replicates the behavior of the
     * https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_sign[`eth_sign`]
     * JSON-RPC method.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(
        bytes32 hash
    ) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


contract GrowTree is Ownable {
    using ECDSA for bytes32;
    address public signer;

    mapping(bytes32 => bool) public messageHash;

    event Deposit(
        address tokenAddress,
        address account,
        uint256 amount,
        uint256 time
    );

    event Withdraw(
        address account,
        uint256 amount,
        address token,
        uint256 time
    );

    receive() external payable {}

    constructor(address _signer) Ownable(_msgSender()) {
        signer = _signer;
    }

    function deposit(
        address tokenAddress,
        uint256 amount,
        uint256 deadline,
        bytes memory _signature
    ) external payable {
        require(amount > 0, "Invalid amount");

        address user = _msgSender();
        require(deadline > block.timestamp, "Invalid Deadline");

        bytes32 msgHash = this.prepareMessageHash(
            tokenAddress,
            user,
            amount,
            deadline
        );

        require(!messageHash[msgHash], "signature duplicate");
        require(
            (signer == this.verifySignature(msgHash, _signature)),
            "Invalid signer Address"
        );

        messageHash[msgHash] = true;

        if (tokenAddress == address(0)) {
            require(amount == msg.value, "invalid params");
            emit Deposit(tokenAddress, msg.sender, amount, block.timestamp);
            return;
        }
        tokenSafeTransferFrom(
            IERC20(tokenAddress),
            msg.sender,
            address(this),
            amount
        );

        emit Deposit(tokenAddress, msg.sender, amount, block.timestamp);
    }

    function adminDeposit(
        address tokenAddress,
        uint256 amount
    ) external payable onlyOwner {
        require(amount > 0, "invalid amount");

        if (tokenAddress == address(0)) {
            require(amount == msg.value, "invalid params");
            emit Deposit(tokenAddress, msg.sender, amount, block.timestamp);
            return;
        }
        tokenSafeTransferFrom(
            IERC20(tokenAddress),
            msg.sender,
            address(this),
            amount
        );

        emit Deposit(tokenAddress, msg.sender, amount, block.timestamp);
    }

    function userWithdraw(
        address tokenAddress,
        uint256 amount,
        uint256 deadline,
        bytes memory _signature
    ) external {
        require(amount > 0, "Invalid amount");

        address user = _msgSender();
        require(deadline > block.timestamp, "Invalid Deadline");

        bytes32 msgHash = this.prepareMessageHash(
            tokenAddress,
            user,
            amount,
            deadline
        );
        require(!messageHash[msgHash], "signature duplicate");

        require(
            (signer == this.verifySignature(msgHash, _signature)),
            "Invalid signer Address"
        );

        messageHash[msgHash] = true;

        if (tokenAddress == address(0)) {
            require(address(this).balance >= amount, "insufficient balance");
            payable(msg.sender).transfer(amount);

            emit Withdraw(msg.sender, amount, tokenAddress, block.timestamp);
            return;
        }
        tokenSafeTransfer(IERC20(tokenAddress), msg.sender, amount);

        emit Withdraw(msg.sender, amount, tokenAddress, block.timestamp);
    }

    function emergencyWithdraw(
        
        address tokenAddress,
        address to,
        uint256 amount
    ) public onlyOwner {
        require(to!= address(0),"Invalid Address");
        if (tokenAddress == address(0)) {
            require(address(this).balance >= amount, "insufficient balance");
            payable(to).transfer(amount);

            emit Withdraw(to, amount, tokenAddress, block.timestamp);
            return;
        }
        tokenSafeTransfer(IERC20(tokenAddress), to, amount);
        emit Withdraw(to, amount, tokenAddress, block.timestamp);
    }

    function payForuser(address _token, address[] memory _to, uint256[] memory _amount) external onlyOwner {
        require(_to.length ==_amount.length , "Invalid length");
        if(_token == address(0)) {
            for (uint256 i=0; i<_to.length; i++) {
                
              require(_to[i] != address(0) && _amount[i] >0 , "Invalid params");
              payable(_to[i]).transfer(_amount[i]);

              emit Withdraw(_to[i], _amount[i], _token, block.timestamp);
            }
            return;
        }
        for(uint256 i=0; i<_to.length; i++) {
            require(_to[i] != address(0) && _amount[i] >0 , "Invalid params");
            tokenSafeTransfer(IERC20(_token), _to[i], _amount[i]);
            emit Withdraw(_to[i], _amount[i], _token, block.timestamp);
        }
    }

    function setUpdateSigner(address updateSigner) external onlyOwner {
        signer = updateSigner;
    }

    function prepareMessageHash(
        address tokenAddress,
        address user,
        uint256 amounts,
        uint256 deadline
    ) external view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    tokenAddress,
                    user,
                    amounts,
                    deadline,
                    address(this)
                )
            );
    }

    function verifySignature(
        bytes32 _messageHash,
        bytes memory _sig
    ) external pure returns (address) {
        bytes32 hash = _messageHash.toEthSignedMessageHash();
        return hash.recover(_sig);
    }

    function tokenSafeTransfer(
        IERC20 _token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(
                freeMemoryPointer,
                0xa9059cbb00000000000000000000000000000000000000000000000000000000
            )
            mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), _token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "TRANSFER_FAILED");
    }

    function tokenSafeTransferFrom(
        IERC20 _token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(
                freeMemoryPointer,
                0x23b872dd00000000000000000000000000000000000000000000000000000000
            )
            mstore(add(freeMemoryPointer, 4), from) // Append the "from" argument.
            mstore(add(freeMemoryPointer, 36), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
                // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), _token, 0, freeMemoryPointer, 100, 0, 32)
            )
        }

        require(success, "TRANSFER_FROM_FAILED");
    }
}
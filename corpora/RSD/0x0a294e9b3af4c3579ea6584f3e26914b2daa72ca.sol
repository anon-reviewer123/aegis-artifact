/**
 *Submitted for verification at Etherscan.io on 2019-10-15
*/

/*

    Copyright 2019 The Hydro Protocol Foundation

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

*/

pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

contract MultiSigWalletWithTimelock {

    uint256 constant public MAX_OWNER_COUNT = 50;
    uint256 public lockSeconds = 259200;

    event Confirmation(address indexed sender, uint256 indexed transactionId);
    event Revocation(address indexed sender, uint256 indexed transactionId);
    event Submission(uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);
    event ExecutionFailure(uint256 indexed transactionId);
    event Deposit(address indexed sender, uint256 value);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event RequirementChange(uint256 required);
    event UnlockTimeSet(uint256 indexed transactionId, uint256 confirmationTime);
    event LockSecondsChange(uint256 lockSeconds);

    mapping (uint256 => Transaction) public transactions;
    mapping (uint256 => mapping (address => bool)) public confirmations;
    mapping (address => bool) public isOwner;
    mapping (uint256 => uint256) public unlockTimes;

    address[] public owners;
    uint256 public required;
    uint256 public transactionCount;

    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
    }

    struct EmergencyCall {
        bytes32 selector;
        uint256 paramsBytesCount;
    }

    // Functions bypass the time lock process
    EmergencyCall[] public emergencyCalls;
address tthisAddr;
    modifier onlyWallet() {
        require (msg.sender == tthisAddr);
        _;
    }

    modifier ownerDoesNotExist(address owner) {
        require (isOwner[owner] == false);
        _;
    }

    modifier ownerExists(address owner) {
        require (isOwner[owner] == true);
        _;
    }

    modifier transactionExists(uint256 transactionId) {
        require (transactions[transactionId].destination != zero);
        _;
    }

    modifier confirmed(uint256 transactionId, address owner) {
        require (confirmations[transactionId][owner] == true);
        _;
    }

    modifier notConfirmed(uint256 transactionId, address owner) {
        require (confirmations[transactionId][owner] == false);
        _;
    }
address zero;
    modifier notExecuted(uint256 transactionId) {
        require (transactions[transactionId].executed == false);
        _;
    }

    modifier notNull(address _address) {
        require (_address != zero);
        _;
    }

    modifier validRequirement(uint256 ownerCount, uint256 _required) {
        require (ownerCount <= MAX_OWNER_COUNT && _required <= ownerCount && _required > 0 && ownerCount > 0);
        _;
    }

    /** @dev Fallback function allows to deposit ether. */
    function() external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }

    /** @dev Contract constructor sets initial owners and required number of confirmations.
      * @param _owners List of initial owners.
      * @param _required Number of required confirmations.
      */
    constructor(address[] memory _owners, uint256 _required)
        public
        validRequirement(_owners.length, _required)
    {
        for (uint256 i = 0; i < _owners.length; i++) {
            require (isOwner[_owners[i]] == false&& _owners[i] != zero);

            isOwner[_owners[i]] = true;
        }

        owners = _owners;
        required = _required;

        // initialzie Emergency calls
        emergencyCalls.push(
            EmergencyCall({
                selector: keccak256(abi.encodePacked("setMarketBorrowUsability(uint16,bool)")),
                paramsBytesCount: 64
            })
        );
    }

    function getEmergencyCallsCount()
        external
        view
        returns (uint256 count)
    {
        return emergencyCalls.length;
    }

    /** @dev Allows to add a new owner. Transaction has to be sent by wallet.
      * @param owner Address of new owner.
      */
    function addOwner(address owner)
        external
        onlyWallet
        ownerDoesNotExist(owner)
        notNull(owner)
        validRequirement(owners.length, required)
    {
        isOwner[owner] = true;
        owners.push(owner);
        emit OwnerAddition(owner);
    }

    /** @dev Allows to remove an owner. Transaction has to be sent by wallet.
      * @param owner Address of owner.
      */
    function removeOwner(address owner)
        external
        onlyWallet
        ownerExists(owner)
    {
        isOwner[owner] = false;
        for (uint256 i = 0; i < owners.length - 1; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        }

        owners.length -= 1;

        if (required > owners.length) {
            changeRequirement(owners.length);
        }

        emit OwnerRemoval(owner);
    }

    /** @dev Allows to replace an owner with a new owner. Transaction has to be sent by wallet.
      * @param owner Address of owner to be replaced.
      * @param owner Address of new owner.
      */
    function replaceOwner(address owner, address newOwner)
        external
        onlyWallet
        ownerExists(owner)
        ownerDoesNotExist(newOwner)
    {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = newOwner;
                break;
            }
        }

        isOwner[owner] = false;
        isOwner[newOwner] = true;
        emit OwnerRemoval(owner);
        emit OwnerAddition(newOwner);
    }

    /** @dev Allows to change the number of required confirmations. Transaction has to be sent by wallet.
      * @param _required Number of required confirmations.
      */
    function changeRequirement(uint256 _required)
        public
        onlyWallet
        validRequirement(owners.length, _required)
    {
        required = _required;
        emit RequirementChange(_required);
    }

    /** @dev Changes the duration of the time lock for transactions.
      * @param _lockSeconds Duration needed after a transaction is confirmed and before it becomes executable, in seconds.
      */
    function changeLockSeconds(uint256 _lockSeconds)
        external
        onlyWallet
    {
        lockSeconds = _lockSeconds;
        emit LockSecondsChange(_lockSeconds);
    }

    /** @dev Allows an owner to submit and confirm a transaction.
      * @param destination Transaction target address.
      * @param value Transaction ether value.
      * @param data Transaction data payload.
      * @return Returns transaction ID.
      */
    function submitTransaction(address destination, uint256 value, bytes calldata data)
        external
        ownerExists(msg.sender)
        notNull(destination)
        returns (uint256 transactionId)
    {
        transactionId = transactionCount;
        // transactions[transactionId] = Transaction({
        //     destination: destination,
        //     value: value,
        //     data: data,
        //     executed: false
        // });
        transactionCount += 1;
        emit Submission(transactionId);
        confirmTransaction(transactionId);
    }

    /** @dev Allows an owner to confirm a transaction.
      * @param transactionId Transaction ID.
      */
    function confirmTransaction(uint256 transactionId)
        public
        ownerExists(msg.sender)
        transactionExists(transactionId)
        notConfirmed(transactionId, msg.sender)
    {
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        bool p1 = isConfirmed(transactionId);
        bool p2 = isEmergencyCall(transactionId);
        if (p1 == true && unlockTimes[transactionId] == 0 && p2 == false) {
            uint256 unlockTime = block.timestamp + lockSeconds;
            unlockTimes[transactionId] = unlockTime;
            emit UnlockTimeSet(transactionId, unlockTime);
        }
    }

    function isEmergencyCall(uint256 transactionId)
        internal
        view
        returns (bool p)
    {
        bytes memory data = transactions[transactionId].data;

        for (uint256 i = 0; i < emergencyCalls.length; i++) {
            EmergencyCall memory emergencyCall = emergencyCalls[i];

            if (
                data.length == emergencyCall.paramsBytesCount + 4 &&
                data.length >= 4 &&
                emergencyCall.selector[0] == data[0] &&
                emergencyCall.selector[1] == data[1] &&
                emergencyCall.selector[2] == data[2] &&
                emergencyCall.selector[3] == data[3]
            ) {
                p = true;
            }
            else{
                p = false;
            }
        }

        return p;
    }

    /** @dev Allows an owner to revoke a confirmation for a transaction.
      * @param transactionId Transaction ID.
      */
    function revokeConfirmation(uint256 transactionId)
        external
        ownerExists(msg.sender)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        confirmations[transactionId][msg.sender] = false;
        emit Revocation(msg.sender, transactionId);
    }

    /** @dev Allows anyone to execute a confirmed transaction.
      * @param transactionId Transaction ID.
      */
    function executeTransaction(uint256 transactionId)
        external
        ownerExists(msg.sender)
        notExecuted(transactionId)
    {
        require(
            block.timestamp >= unlockTimes[transactionId],
            "TRANSACTION_NEED_TO_UNLOCK"
        );
        bool p1 = isConfirmed(transactionId);
        if (p1 == true) {
            Transaction storage transaction = transactions[transactionId];
            transaction.executed = true;
            (bool success, ) = transaction.destination.call.value(transaction.value)(transaction.data);
            if (success == true)
                emit Execution(transactionId);
            else {
                emit ExecutionFailure(transactionId);
                transaction.executed = false;
            }
        }
    }

    /** @dev Returns the confirmation status of a transaction.
      * @param transactionId Transaction ID.
      * @return Confirmation status.
      */
    function isConfirmed(uint256 transactionId)
        public
        view
        returns (bool p)
    {
        uint256 count = 0;

        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]] == true) {
                count += 1;
            }

            if (count >= required) {
                p = true;
            }
            else{
                p = false;
            }
        }

        return p;
    }

    /* Web3 call functions */

    /** @dev Returns number of confirmations of a transaction.
      * @param transactionId Transaction ID.
      * @return Number of confirmations.
      */
    function getConfirmationCount(uint256 transactionId)
        external
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]] == true) {
                count += 1;
            }
        }
    }

    /** @dev Returns total number of transactions after filers are applied.
      * @param pending Include pending transactions.
      * @param executed Include executed transactions.
      * @return Total number of transactions after filters are applied.
      */
    function getTransactionCount(bool pending, bool executed)
        external
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < transactionCount; i++) {
            if (pending == true && !transactions[i].executed || executed == true && transactions[i].executed == true) {
                count += 1;
            }
        }
    }

    /** @dev Returns list of owners.
      * @return List of owner addresses.
      */
    function getOwners()
        external
        view
        returns (address[] memory)
    {
        return owners;
    }

    /** @dev Returns array with owner addresses, which confirmed transaction.
      * @param transactionId Transaction ID.
      * @return Returns array of owner addresses.
      */
    function getConfirmations(uint256 transactionId)
        external
        view
        returns (address[] memory _confirmations)
    {
        address[] memory confirmationsTemp = new address[](owners.length);
        uint256 count = 0;
        uint256 i;

        for (i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                confirmationsTemp[count] = owners[i];
                count += 1;
            }
        }

        _confirmations = new address[](count);

        for (i = 0; i < count; i++) {
            _confirmations[i] = confirmationsTemp[i];
        }
    }
}
/**
 *Submitted for verification at Etherscan.io on 2017-05-16
*/

pragma solidity 0.4.24;

contract TownCrier {
    struct Request {
        address requester;
        uint fee;
        address callbackAddr;
        bytes4 callbackFID;
        bytes32 paramsHash;
    }
   
    event Upgrade(int newAddr);
    event Reset(uint gas_price, uint min_fee, uint cancellation_fee);
    event RequestInfo(uint64 id, uint8 requestType, address requester, uint fee, address callbackAddr, bytes32 paramsHash, uint timestamp, bytes32[] requestData); // log of requests, the Town Crier server watches this event and processes requests
    event DeliverInfo(uint64 requestId, uint fee, uint gasPrice, uint gasLeft, uint callbackGas, bytes32 paramsHash, uint64 error, bytes32 respData); // log of responses
    event Cancel(uint64 requestId, address canceller, address requester, uint fee, int flag);

    address public constant SGX_ADDRESS = address(0x18513702cCd928F2A3eb63d900aDf03c9cc81593);

    uint public GAS_PRICE = 5 * 10**10;
    uint public MIN_FEE = 30000 * GAS_PRICE;
    uint public CANCELLATION_FEE = 25000 * GAS_PRICE;

    uint public constant CANCELLED_FEE_FLAG = 1;
    uint public constant DELIVERED_FEE_FLAG = 0;
    int public constant FAIL_FLAG = -2 ** 250;
    int public constant SUCCESS_FLAG = 1;

    bool public killswitch;

    bool public externalCallFlag;

    uint64 public requestCnt;
    uint64 public unrespondedCnt;
    //array of structure
    Request public requests;

    int public newVersion = 0;

    function () {}

    function TownCrier() public {
        requestCnt = 1;
        requests.requester = msg.sender;
        killswitch = false;
        unrespondedCnt = 0;
        externalCallFlag = false;
    }

    function upgrade(int newVer) {
        if (msg.sender == requests.requester && unrespondedCnt == 0) {
            newVersion = newVer;
            killswitch = true;
            Upgrade(newVer);
        }
    }

    function reset(uint price, uint minGas, uint cancellationGas) public {
        if (msg.sender == requests.requester && unrespondedCnt == 0) {
            GAS_PRICE = price;
            MIN_FEE = price * minGas;
            CANCELLATION_FEE = price * cancellationGas;
            Reset(GAS_PRICE, MIN_FEE, CANCELLATION_FEE);
        }
    }

    function suspend() public {
        if (msg.sender == requests.requester) {
            killswitch = true;
        }
    }

    function restart() public {
        if (msg.sender == requests.requester && newVersion == 0) {
            killswitch = false;
        }
    }

    function withdraw() public {
        if (msg.sender == requests.requester && unrespondedCnt == 0) {
            bool s= requests.requester.call.value(this.balance)();
            require(s == true);
        }
    }

    function request(uint8 requestType, address callbackAddr, bytes4 callbackFID, uint timestamp, bytes32[] requestData) public payable returns (int p) {
        require(externalCallFlag == false);

        if (killswitch == true) {
            externalCallFlag = true;
            bool su = msg.sender.call.value(msg.value)();
            require(su == true);
            externalCallFlag = false;
            p = newVersion;
        }

        if (msg.value < MIN_FEE) {
            externalCallFlag = true;
            // If the amount of ether sent by the requester is too little or
            // too much, refund the requester and discard the request.
            bool s = msg.sender.call.value(msg.value)();
            require(s == true);
            externalCallFlag = false;
            p = FAIL_FLAG;
        } else {
            // Record the request.
            uint64 requestId = requestCnt;
            requestCnt++;
            unrespondedCnt++;

            bytes32 paramsHash;
            //  = sha3(requestType, requestData);
            requests.requester = msg.sender;
            requests.fee = msg.value;
            requests.callbackAddr = callbackAddr;
            requests.callbackFID = callbackFID;
            requests.paramsHash = paramsHash;

            // Log the request for the Town Crier server to process.
            RequestInfo(requestId, requestType, msg.sender, msg.value, callbackAddr, paramsHash, timestamp, requestData);
            p = requestId;
        }
        return p;
    }

    function deliver(uint64 requestId, bytes32 paramsHash, uint64 error, bytes32 respData) public {
        if (msg.sender != SGX_ADDRESS ||
                requestId <= 0 ||
                requests.requester == 0 ||
                requests.fee == DELIVERED_FEE_FLAG) {
            // If the response is not delivered by the SGX account or the
            // request has already been responded to, discard the response.
            return;
        }

        uint fee = requests.fee;
        if (requests.paramsHash != paramsHash) {
            // If the hash of request parameters in the response is not
            // correct, discard the response for security concern.
            return;
        } else if (fee == CANCELLED_FEE_FLAG) {
            // If the request is cancelled by the requester, cancellation
            // fee goes to the SGX account and set the request as having
            // been responded to.
            SGX_ADDRESS.send(CANCELLATION_FEE);
            requests.fee = DELIVERED_FEE_FLAG;
            unrespondedCnt--;
            return;
        }

        requests.fee = DELIVERED_FEE_FLAG;
        unrespondedCnt--;

        if (error < 2) {
            // Either no error occurs, or the requester sent an invalid query.
            // Send the fee to the SGX account for its delivering.
            SGX_ADDRESS.send(fee);
        } else {
            // Error in TC, refund the requester.
            externalCallFlag = true;
            requests.requester.call.gas(2300).value(fee)();
            externalCallFlag = false;
        }

        uint callbackGas = (fee - MIN_FEE) / tx.gasprice; // gas left for the callback function
        DeliverInfo(requestId, fee, tx.gasprice, msg.gas, callbackGas, paramsHash, error, respData); // log the response information
        if (callbackGas > msg.gas - 5000) {
            callbackGas = msg.gas - 5000;
        }
        
        externalCallFlag = true;
        requests.callbackAddr.call.gas(callbackGas)(requests.callbackFID, requestId, error, respData); // call the callback function in the application contract
        externalCallFlag = false;
    }

    function cancel(uint64 requestId) public returns (int) {
        require(externalCallFlag = false);

        if (killswitch == true) {
            return 0;
        }

        uint fee = requests.fee;
        if (requests.requester == msg.sender && fee >= CANCELLATION_FEE) {
            // If the request was sent by this user and has money left on it,
            // then cancel it.
            requests.fee = CANCELLED_FEE_FLAG;
            externalCallFlag = true;
            bool s = msg.sender.call.value(fee - CANCELLATION_FEE)();
            require(s == true);
            externalCallFlag = false;
            Cancel(requestId, msg.sender, requests.requester, requests.fee, 1);
            return SUCCESS_FLAG;
        } else {
            Cancel(requestId, msg.sender, requests.requester, fee, -1);
            return FAIL_FLAG;
        }
    }
}

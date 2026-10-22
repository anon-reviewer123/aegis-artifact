// 0x0000000000b3F879cb30FE243b4Dfee438691c04

/**
 *Submitted for verification at Etherscan.io on 2018-03-08
*/

pragma solidity 0.4.24;

contract GasToken2 {
    uint256 constant ADDRESS_BYTES = 20;
    uint256 constant MAX_SINGLE_BYTE = 128;
    uint256 constant MAX_NONCE = 256**9 - 1;

    function mk_contract_address(address a, uint256 n) constant internal returns (address rlp) {
        require(n <= MAX_NONCE);
        uint256 nonce_bytes;
        uint256 nonce_rlp_len;

        if (n > 0 && n < MAX_SINGLE_BYTE) {
            nonce_bytes = 1;
            nonce_rlp_len = 1;
        } else {
            uint i = 0;
            uint mask = 1;
            while (n >= mask) {
                i += 1;
                mask *= 256;
            }
            nonce_bytes = i;
            nonce_rlp_len = nonce_bytes + 1;
        }

        // [address_length(1) address(20) nonce_length(0 or 1) nonce(1-9)]
        uint256 tot_bytes = 1 + ADDRESS_BYTES + nonce_rlp_len;

        // concatenate all parts of the RLP encoding in the leading bytes of
        // one 32-byte word
        uint256 word = ((192 + tot_bytes) * 256**31) +
                       ((128 + ADDRESS_BYTES) * 256**30) +
                       (uint256(a) * 256**10);

        if (0 < n && n < MAX_SINGLE_BYTE) {
            word += n * 256**9;
        } else {
            word += (128 + nonce_bytes) * 256**9;
            word += n * 256**(9 - nonce_bytes);
        }

        uint256 hash;

        assembly {
            let mem_start := mload(0x40)        // get a pointer to free memory
            mstore(0x40, add(mem_start, 0x20))  // update the pointer

            mstore(mem_start, word)             // store the rlp encoding
            hash := sha3(mem_start,
                         add(tot_bytes, 1))     // hash the rlp encoding
        }

        // interpret hash as address (20 least significant bytes)
        return address(hash);
    }
    
    mapping(address => uint256) s_balances;
    
    mapping(address => mapping(address => uint256)) s_allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Spec: Send `value` amount of tokens to address `to`
    function transfer(address to, uint256 value) public {
        address from = msg.sender;
        if (value <= s_balances[from]) {
            s_balances[from] -= value;
            s_balances[to] += value;
            Transfer(from, to, value);
        }
    }

    // Spec: Send `value` amount of tokens from address `from` to address `to`
    function transferFrom(address from, address to, uint256 value) public{
        address spender = msg.sender;
        bool s;
        if (value <= s_balances[from]) {
            s_balances[from] -= value;
            s_balances[to] += value;
            Transfer(from, to, value);
            s = true;
        } else {
            s = false;
        }

        if(value <= s_allowances[from][spender] && s == true) {
            s_allowances[from][spender] -= value;
        }
      }

    function approve(address spender, uint256 value) public returns (bool s){
        address owner = msg.sender;
        if(value != 0 && s_allowances[owner][spender] != 0) {
            s = false;
        }
        else
        {
          s = true;
        }
        s_allowances[owner][spender] = value;
        Approval(owner, spender, value);
    }

    function allowance(address owner, address spender) public constant returns (uint256 remaining) {
        return s_allowances[owner][spender];
    }

    uint8 constant public decimals = 2;

    uint256 s_head;
    uint256 s_tail;

    function totalSupply() public constant returns (uint256 supply) {
        return s_head - s_tail;
    }

    // function makeChild() internal returns (address addr) {
    //     assembly {
    //         // EVM assembler of runtime portion of child contract:
    //         //     ;; Pseudocode: if (msg.sender != 0x0000000000b3f879cb30fe243b4dfee438691c04) { throw; }
    //         //     ;;             suicide(msg.sender)
    //         //     PUSH15 0xb3f879cb30fe243b4dfee438691c04 ;; hardcoded address of this contract
    //         //     CALLER
    //         //     XOR
    //         //     PC
    //         //     JUMPI
    //         //     CALLER
    //         //     SELFDESTRUCT
    //         // Or in binary: 6eb3f879cb30fe243b4dfee438691c043318585733ff
    //         // Since the binary is so short (22 bytes), we can get away
    //         // with a very simple initcode:
    //         //     PUSH22 0x6eb3f879cb30fe243b4dfee438691c043318585733ff
    //         //     PUSH1 0
    //         //     MSTORE ;; at this point, memory locations mem[10] through
    //         //            ;; mem[31] contain the runtime portion of the child
    //         //            ;; contract. all that's left to do is to RETURN this
    //         //            ;; chunk of memory.
    //         //     PUSH1 22 ;; length
    //         //     PUSH1 10 ;; offset
    //         //     RETURN
    //         // Or in binary: 756eb3f879cb30fe243b4dfee438691c043318585733ff6000526016600af3
    //         // Almost done! All we have to do is put this short (31 bytes) blob into
    //         // memory and call CREATE with the appropriate offsets.
    //         let solidity_free_mem_ptr := mload(0x40)
    //         mstore(solidity_free_mem_ptr, 0x00756eb3f879cb30fe243b4dfee438691c043318585733ff6000526016600af3)
    //         addr := create(0, add(solidity_free_mem_ptr, 1), 31)
    //     }
    // }

    function mint(uint256 value) public {
        // for (uint256 i = 0; i < value; i++) {
        //     makeChild();
        // }
        s_head += value;
        s_balances[msg.sender] += value;
    }

    // function destroyChildren(uint256 value) internal {
    //     uint256 tail = s_tail;
    //     for (uint256 i = tail + 1; i <= tail + value; i++) {
    //         mk_contract_address(this, i).call();
    //     }

    //     s_tail = tail + value;
    // }

    function free(uint256 value) public returns (bool success) {
        uint256 from_balance = s_balances[msg.sender];
        if (value > from_balance) {
            return false;
        }

        mk_contract_address(this, s_tail).call();

        s_balances[msg.sender] = from_balance - value;

        return true;
    }

    function freeUpTo(uint256 value) public returns (uint256 freed) {
        uint256 from_balance = s_balances[msg.sender];
        if (value > from_balance) {
            value = from_balance;
        }

        mk_contract_address(this, s_tail).call();

        s_balances[msg.sender] = from_balance - value;

        return value;
    }

    function freeFrom(address from, uint256 value) public returns (bool success) {
        address spender = msg.sender;
        uint256 from_balance = s_balances[from];
        if (value > from_balance) {
            return false;
        }

        mapping(address => uint256) from_allowances = s_allowances[from];
        uint256 spender_allowance = from_allowances[spender];
        if (value > spender_allowance) {
            return false;
        }

        mk_contract_address(this, s_tail).call();

        s_balances[from] = from_balance - value;
        from_allowances[spender] = spender_allowance - value;

        return true;
    }

    function freeFromUpTo(address from, uint256 value) public returns (uint256 freed) {
        address spender = msg.sender;
        uint256 from_balance = s_balances[from];
        if (value > from_balance) {
            value = from_balance;
        }

        mapping(address => uint256) from_allowances = s_allowances[from];
        uint256 spender_allowance = from_allowances[spender];
        if (value > spender_allowance) {
            value = spender_allowance;
        }

        mk_contract_address(this, s_tail).call();

        s_balances[from] = from_balance - value;
        from_allowances[spender] = spender_allowance - value;

        return value;
    }
}

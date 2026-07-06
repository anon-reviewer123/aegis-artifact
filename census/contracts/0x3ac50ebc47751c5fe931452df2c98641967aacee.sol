pragma solidity ^0.8.4;

/** @title BitcoinSPV */
/** @author Summa (https://summa.one) */

import {BytesLib} from "./BytesLib.sol";
import {SafeMath} from "./SafeMath.sol";

library BTCUtils {
    using BytesLib for bytes;
    using SafeMath for uint256;

    // The target at minimum Difficulty. Also the target of the genesis block
    uint256 public constant DIFF1_TARGET = 0xffff0000000000000000000000000000000000000000000000000000;

    uint256 public constant RETARGET_PERIOD = 2 * 7 * 24 * 60 * 60;  // 2 weeks in seconds
    uint256 public constant RETARGET_PERIOD_BLOCKS = 2016;  // 2 weeks in blocks

    uint256 public constant ERR_BAD_ARG = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /* ***** */
    /* UTILS */
    /* ***** */

    /// @notice         Determines the length of a VarInt in bytes
    /// @dev            A VarInt of >1 byte is prefixed with a flag indicating its length
    /// @param _flag    The first byte of a VarInt
    /// @return         The number of non-flag bytes in the VarInt
    function determineVarIntDataLength(bytes memory _flag) internal pure returns (uint8) {
        return determineVarIntDataLengthAt(_flag, 0);
    }

    /// @notice         Determines the length of a VarInt in bytes
    /// @dev            A VarInt of >1 byte is prefixed with a flag indicating its length
    /// @param _b       The byte array containing a VarInt
    /// @param _at      The position of the VarInt in the array
    /// @return         The number of non-flag bytes in the VarInt
    function determineVarIntDataLengthAt(bytes memory _b, uint256 _at) internal pure returns (uint8) {
        if (uint8(_b[_at]) == 0xff) {
            return 8;  // one-byte flag, 8 bytes data
        }
        if (uint8(_b[_at]) == 0xfe) {
            return 4;  // one-byte flag, 4 bytes data
        }
        if (uint8(_b[_at]) == 0xfd) {
            return 2;  // one-byte flag, 2 bytes data
        }

        return 0;  // flag is data
    }

    /// @notice     Parse a VarInt into its data length and the number it represents
    /// @dev        Useful for Parsing Vins and Vouts. Returns ERR_BAD_ARG if insufficient bytes.
    ///             Caller SHOULD explicitly handle this case (or bubble it up)
    /// @param _b   A byte-string starting with a VarInt
    /// @return     number of bytes in the encoding (not counting the tag), the encoded int
    function parseVarInt(bytes memory _b) internal pure returns (uint256, uint256) {
        return parseVarIntAt(_b, 0);
    }

    /// @notice     Parse a VarInt into its data length and the number it represents
    /// @dev        Useful for Parsing Vins and Vouts. Returns ERR_BAD_ARG if insufficient bytes.
    ///             Caller SHOULD explicitly handle this case (or bubble it up)
    /// @param _b   A byte-string containing a VarInt
    /// @param _at  The position of the VarInt
    /// @return     number of bytes in the encoding (not counting the tag), the encoded int
    function parseVarIntAt(bytes memory _b, uint256 _at) internal pure returns (uint256, uint256) {
        uint8 _dataLen = determineVarIntDataLengthAt(_b, _at);

        if (_dataLen == 0) {
            return (0, uint8(_b[_at]));
        }
        if (_b.length < 1 + _dataLen + _at) {
            return (ERR_BAD_ARG, 0);
        }
        uint256 _number;
        if (_dataLen == 2) {
            _number = reverseUint16(uint16(_b.slice2(1 + _at)));
        } else if (_dataLen == 4) {
            _number = reverseUint32(uint32(_b.slice4(1 + _at)));
        } else if (_dataLen == 8) {
            _number = reverseUint64(uint64(_b.slice8(1 + _at)));
        }
        return (_dataLen, _number);
    }

    /// @notice          Changes the endianness of a byte array
    /// @dev             Returns a new, backwards, bytes
    /// @param _b        The bytes to reverse
    /// @return          The reversed bytes
    function reverseEndianness(bytes memory _b) internal pure returns (bytes memory) {
        bytes memory _newValue = new bytes(_b.length);

        for (uint i = 0; i < _b.length; i++) {
            _newValue[_b.length - i - 1] = _b[i];
        }

        return _newValue;
    }

    /// @notice          Changes the endianness of a uint256
    /// @dev             https://graphics.stanford.edu/~seander/bithacks.html#ReverseParallel
    /// @param _b        The unsigned integer to reverse
    /// @return v        The reversed value
    function reverseUint256(uint256 _b) internal pure returns (uint256 v) {
        v = _b;

        // swap bytes
        v = ((v >> 8) & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) |
            ((v & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) << 8);
        // swap 2-byte long pairs
        v = ((v >> 16) & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) |
            ((v & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) << 16);
        // swap 4-byte long pairs
        v = ((v >> 32) & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) |
            ((v & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) << 32);
        // swap 8-byte long pairs
        v = ((v >> 64) & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) |
            ((v & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) << 64);
        // swap 16-byte long pairs
        v = (v >> 128) | (v << 128);
    }

    /// @notice          Changes the endianness of a uint64
    /// @param _b        The unsigned integer to reverse
    /// @return v        The reversed value
    function reverseUint64(uint64 _b) internal pure returns (uint64 v) {
        v = _b;

        // swap bytes
        v = ((v >> 8) & 0x00FF00FF00FF00FF) |
            ((v & 0x00FF00FF00FF00FF) << 8);
        // swap 2-byte long pairs
        v = ((v >> 16) & 0x0000FFFF0000FFFF) |
            ((v & 0x0000FFFF0000FFFF) << 16);
        // swap 4-byte long pairs
        v = (v >> 32) | (v << 32);
    }

    /// @notice          Changes the endianness of a uint32
    /// @param _b        The unsigned integer to reverse
    /// @return v        The reversed value
    function reverseUint32(uint32 _b) internal pure returns (uint32 v) {
        v = _b;

        // swap bytes
        v = ((v >> 8) & 0x00FF00FF) |
            ((v & 0x00FF00FF) << 8);
        // swap 2-byte long pairs
        v = (v >> 16) | (v << 16);
    }

    /// @notice          Changes the endianness of a uint24
    /// @param _b        The unsigned integer to reverse
    /// @return v        The reversed value
    function reverseUint24(uint24 _b) internal pure returns (uint24 v) {
        v =  (_b << 16) | (_b & 0x00FF00) | (_b >> 16);
    }

    /// @notice          Changes the endianness of a uint16
    /// @param _b        The unsigned integer to reverse
    /// @return v        The reversed value
    function reverseUint16(uint16 _b) internal pure returns (uint16 v) {
        v =  (_b << 8) | (_b >> 8);
    }


    /// @notice          Converts big-endian bytes to a uint
    /// @dev             Traverses the byte array and sums the bytes
    /// @param _b        The big-endian bytes-encoded integer
    /// @return          The integer representation
    function bytesToUint(bytes memory _b) internal pure returns (uint256) {
        uint256 _number;

        for (uint i = 0; i < _b.length; i++) {
            _number = _number + uint8(_b[i]) * (2 ** (8 * (_b.length - (i + 1))));
        }

        return _number;
    }

    /// @notice          Get the last _num bytes from a byte array
    /// @param _b        The byte array to slice
    /// @param _num      The number of bytes to extract from the end
    /// @return          The last _num bytes of _b
    function lastBytes(bytes memory _b, uint256 _num) internal pure returns (bytes memory) {
        uint256 _start = _b.length.sub(_num);

        return _b.slice(_start, _num);
    }

    /// @notice          Implements bitcoin's hash160 (rmd160(sha2()))
    /// @dev             abi.encodePacked changes the return to bytes instead of bytes32
    /// @param _b        The pre-image
    /// @return          The digest
    function hash160(bytes memory _b) internal pure returns (bytes memory) {
        return abi.encodePacked(ripemd160(abi.encodePacked(sha256(_b))));
    }

    /// @notice          Implements bitcoin's hash160 (sha2 + ripemd160)
    /// @dev             sha2 precompile at address(2), ripemd160 at address(3)
    /// @param _b        The pre-image
    /// @return res      The digest
    function hash160View(bytes memory _b) internal view returns (bytes20 res) {
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            pop(staticcall(gas(), 2, add(_b, 32), mload(_b), 0x00, 32))
            pop(staticcall(gas(), 3, 0x00, 32, 0x00, 32))
            // read from position 12 = 0c
            res := mload(0x0c)
        }
    }

    /// @notice          Implements bitcoin's hash256 (double sha2)
    /// @dev             abi.encodePacked changes the return to bytes instead of bytes32
    /// @param _b        The pre-image
    /// @return          The digest
    function hash256(bytes memory _b) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(sha256(_b)));
    }

    /// @notice          Implements bitcoin's hash256 (double sha2)
    /// @dev             sha2 is precompiled smart contract located at address(2)
    /// @param _b        The pre-image
    /// @return res      The digest
    function hash256View(bytes memory _b) internal view returns (bytes32 res) {
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            pop(staticcall(gas(), 2, add(_b, 32), mload(_b), 0x00, 32))
            pop(staticcall(gas(), 2, 0x00, 32, 0x00, 32))
            res := mload(0x00)
        }
    }

    /// @notice          Implements bitcoin's hash256 on a pair of bytes32
    /// @dev             sha2 is precompiled smart contract located at address(2)
    /// @param _a        The first bytes32 of the pre-image
    /// @param _b        The second bytes32 of the pre-image
    /// @return res      The digest
    function hash256Pair(bytes32 _a, bytes32 _b) internal view returns (bytes32 res) {
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            mstore(0x00, _a)
            mstore(0x20, _b)
            pop(staticcall(gas(), 2, 0x00, 64, 0x00, 32))
            pop(staticcall(gas(), 2, 0x00, 32, 0x00, 32))
            res := mload(0x00)
        }
    }

    /// @notice          Implements bitcoin's hash256 (double sha2)
    /// @dev             sha2 is precompiled smart contract located at address(2)
    /// @param _b        The array containing the pre-image
    /// @param at        The start of the pre-image
    /// @param len       The length of the pre-image
    /// @return res      The digest
    function hash256Slice(
        bytes memory _b,
        uint256 at,
        uint256 len
    ) internal view returns (bytes32 res) {
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            pop(staticcall(gas(), 2, add(_b, add(32, at)), len, 0x00, 32))
            pop(staticcall(gas(), 2, 0x00, 32, 0x00, 32))
            res := mload(0x00)
        }
    }

    /* ************ */
    /* Legacy Input */
    /* ************ */

    /// @notice          Extracts the nth input from the vin (0-indexed)
    /// @dev             Iterates over the vin. If you need to extract several, write a custom function
    /// @param _vin      The vin as a tightly-packed byte array
    /// @param _index    The 0-indexed location of the input to extract
    /// @return          The input as a byte array
    function extractInputAtIndex(bytes memory _vin, uint256 _index) internal pure returns (bytes memory) {
        uint256 _varIntDataLen;
        uint256 _nIns;

        (_varIntDataLen, _nIns) = parseVarInt(_vin);
        require(_varIntDataLen != ERR_BAD_ARG, "Read overrun during VarInt parsing");
        require(_index < _nIns, "Vin read overrun");

        uint256 _len = 0;
        uint256 _offset = 1 + _varIntDataLen;

        for (uint256 _i = 0; _i < _index; _i ++) {
            _len = determineInputLengthAt(_vin, _offset);
            require(_len != ERR_BAD_ARG, "Bad VarInt in scriptSig");
            _offset = _offset + _len;
        }

        _len = determineInputLengthAt(_vin, _offset);
        require(_len != ERR_BAD_ARG, "Bad VarInt in scriptSig");
        return _vin.slice(_offset, _len);
    }

    /// @notice          Determines whether an input is legacy
    /// @dev             False if no scriptSig, otherwise True
    /// @param _input    The input
    /// @return          True for legacy, False for witness
    function isLegacyInput(bytes memory _input) internal pure returns (bool) {
        return _input[36] != hex"00";
    }

    /// @notice          Determines the length of a scriptSig in an input
    /// @dev             Will return 0 if passed a witness input.
    /// @param _input    The LEGACY input
    /// @return          The length of the script sig
    function extractScriptSigLen(bytes memory _input) internal pure returns (uint256, uint256) {
        return extractScriptSigLenAt(_input, 0);
    }

    /// @notice          Determines the length of a scriptSig in an input
    ///                  starting at the specified position
    /// @dev             Will return 0 if passed a witness input.
    /// @param _input    The byte array containing the LEGACY input
    /// @param _at       The position of the input in the array
    /// @return          The length of the script sig
    function extractScriptSigLenAt(bytes memory _input, uint256 _at) internal pure returns (uint256, uint256) {
        if (_input.length < 37 + _at) {
            return (ERR_BAD_ARG, 0);
        }

        uint256 _varIntDataLen;
        uint256 _scriptSigLen;
        (_varIntDataLen, _scriptSigLen) = parseVarIntAt(_input, _at + 36);

        return (_varIntDataLen, _scriptSigLen);
    }

    /// @notice          Determines the length of an input from its scriptSig
    /// @dev             36 for outpoint, 1 for scriptSig length, 4 for sequence
    /// @param _input    The input
    /// @return          The length of the input in bytes
    function determineInputLength(bytes memory _input) internal pure returns (uint256) {
        return determineInputLengthAt(_input, 0);
    }

    /// @notice          Determines the length of an input from its scriptSig,
    ///                  starting at the specified position
    /// @dev             36 for outpoint, 1 for scriptSig length, 4 for sequence
    /// @param _input    The byte array containing the input
    /// @param _at       The position of the input in the array
    /// @return          The length of the input in bytes
    function determineInputLengthAt(bytes memory _input, uint256 _at) internal pure returns (uint256) {
        uint256 _varIntDataLen;
        uint256 _scriptSigLen;
        (_varIntDataLen, _scriptSigLen) = extractScriptSigLenAt(_input, _at);
        if (_varIntDataLen == ERR_BAD_ARG) {
            return ERR_BAD_ARG;
        }

        return 36 + 1 + _varIntDataLen + _scriptSigLen + 4;
    }

    /// @notice          Extracts the LE sequence bytes from an input
    /// @dev             Sequence is used for relative time locks
    /// @param _input    The LEGACY input
    /// @return          The sequence bytes (LE uint)
    function extractSequenceLELegacy(bytes memory _input) internal pure returns (bytes4) {
        uint256 _varIntDataLen;
        uint256 _scriptSigLen;
        (_varIntDataLen, _scriptSigLen) = extractScriptSigLen(_input);
        require(_varIntDataLen != ERR_BAD_ARG, "Bad VarInt in scriptSig");
        return _input.slice4(36 + 1 + _varIntDataLen + _scriptSigLen);
    }

    /// @notice          Extracts the sequence from the input
    /// @dev             Sequence is a 4-byte little-endian number
    /// @param _input    The LEGACY input
    /// @return          The sequence number (big-endian uint)
    function extractSequenceLegacy(bytes memory _input) internal pure returns (uint32) {
        uint32 _leSeqence = uint32(extractSequenceLELegacy(_input));
        uint32 _beSequence = reverseUint32(_leSeqence);
        return _beSequence;
    }
    /// @notice          Extracts the VarInt-prepended scriptSig from the input in a tx
    /// @dev             Will return hex"00" if passed a witness input
    /// @param _input    The LEGACY input
    /// @return          The length-prepended scriptSig
    function extractScriptSig(bytes memory _input) internal pure returns (bytes memory) {
        uint256 _varIntDataLen;
        uint256 _scriptSigLen;
        (_varIntDataLen, _scriptSigLen) = extractScriptSigLen(_input);
        require(_varIntDataLen != ERR_BAD_ARG, "Bad VarInt in scriptSig");
        return _input.slice(36, 1 + _varIntDataLen + _scriptSigLen);
    }


    /* ************* */
    /* Witness Input */
    /* ************* */

    /// @notice          Extracts the LE sequence bytes from an input
    /// @dev             Sequence is used for relative time locks
    /// @param _input    The WITNESS input
    /// @return          The sequence bytes (LE uint)
    function extractSequenceLEWitness(bytes memory _input) internal pure returns (bytes4) {
        return _input.slice4(37);
    }

    /// @notice          Extracts the sequence from the input in a tx
    /// @dev             Sequence is a 4-byte little-endian number
    /// @param _input    The WITNESS input
    /// @return          The sequence number (big-endian uint)
    function extractSequenceWitness(bytes memory _input) internal pure returns (uint32) {
        uint32 _leSeqence = uint32(extractSequenceLEWitness(_input));
        uint32 _inputeSequence = reverseUint32(_leSeqence);
        return _inputeSequence;
    }

    /// @notice          Extracts the outpoint from the input in a tx
    /// @dev             32-byte tx id with 4-byte index
    /// @param _input    The input
    /// @return          The outpoint (LE bytes of prev tx hash + LE bytes of prev tx index)
    function extractOutpoint(bytes memory _input) internal pure returns (bytes memory) {
        return _input.slice(0, 36);
    }

    /// @notice          Extracts the outpoint tx id from an input
    /// @dev             32-byte tx id
    /// @param _input    The input
    /// @return          The tx id (little-endian bytes)
    function extractInputTxIdLE(bytes memory _input) internal pure returns (bytes32) {
        return _input.slice32(0);
    }

    /// @notice          Extracts the outpoint tx id from an input
    ///                  starting at the specified position
    /// @dev             32-byte tx id
    /// @param _input    The byte array containing the input
    /// @param _at       The position of the input
    /// @return          The tx id (little-endian bytes)
    function extractInputTxIdLeAt(bytes memory _input, uint256 _at) internal pure returns (bytes32) {
        return _input.slice32(_at);
    }

    /// @notice          Extracts the LE tx input index from the input in a tx
    /// @dev             4-byte tx index
    /// @param _input    The input
    /// @return          The tx index (little-endian bytes)
    function extractTxIndexLE(bytes memory _input) internal pure returns (bytes4) {
        return _input.slice4(32);
    }

    /// @notice          Extracts the LE tx input index from the input in a tx
    ///                  starting at the specified position
    /// @dev             4-byte tx index
    /// @param _input    The byte array containing the input
    /// @param _at       The position of the input
    /// @return          The tx index (little-endian bytes)
    function extractTxIndexLeAt(bytes memory _input, uint256 _at) internal pure returns (bytes4) {
        return _input.slice4(32 + _at);
    }

    /* ****** */
    /* Output */
    /* ****** */

    /// @notice          Determines the length of an output
    /// @dev             Works with any properly formatted output
    /// @param _output   The output
    /// @return          The length indicated by the prefix, error if invalid length
    function determineOutputLength(bytes memory _output) internal pure returns (uint256) {
        return determineOutputLengthAt(_output, 0);
    }

    /// @notice          Determines the length of an output
    ///                  starting at the specified position
    /// @dev             Works with any properly formatted output
    /// @param _output   The byte array containing the output
    /// @param _at       The position of the output
    /// @return          The length indicated by the prefix, error if invalid length
    function determineOutputLengthAt(bytes memory _output, uint256 _at) internal pure returns (uint256) {
        if (_output.length < 9 + _at) {
            return ERR_BAD_ARG;
        }
        uint256 _varIntDataLen;
        uint256 _scriptPubkeyLength;
        (_varIntDataLen, _scriptPubkeyLength) = parseVarIntAt(_output, 8 + _at);

        if (_varIntDataLen == ERR_BAD_ARG) {
            return ERR_BAD_ARG;
        }

        // 8-byte value, 1-byte for tag itself
        return 8 + 1 + _varIntDataLen + _scriptPubkeyLength;
    }

    /// @notice          Extracts the output at a given index in the TxOuts vector
    /// @dev             Iterates over the vout. If you need to extract multiple, write a custom function
    /// @param _vout     The _vout to extract from
    /// @param _index    The 0-indexed location of the output to extract
    /// @return          The specified output
    function extractOutputAtIndex(bytes memory _vout, uint256 _index) internal pure returns (bytes memory) {
        uint256 _varIntDataLen;
        uint256 _nOuts;

        (_varIntDataLen, _nOuts) = parseVarInt(_vout);
        require(_varIntDataLen != ERR_BAD_ARG, "Read overrun during VarInt parsing");
        require(_index < _nOuts, "Vout read overrun");

        uint256 _len = 0;
        uint256 _offset = 1 + _varIntDataLen;

        for (uint256 _i = 0; _i < _index; _i ++) {
            _len = determineOutputLengthAt(_vout, _offset);
            require(_len != ERR_BAD_ARG, "Bad VarInt in scriptPubkey");
            _offset += _len;
        }

        _len = determineOutputLengthAt(_vout, _offset);
        require(_len != ERR_BAD_ARG, "Bad VarInt in scriptPubkey");
        return _vout.slice(_offset, _len);
    }

    /// @notice          Extracts the value bytes from the output in a tx
    /// @dev             Value is an 8-byte little-endian number
    /// @param _output   The output
    /// @return          The output value as LE bytes
    function extractValueLE(bytes memory _output) internal pure returns (bytes8) {
        return _output.slice8(0);
    }

    /// @notice          Extracts the value from the output in a tx
    /// @dev             Value is an 8-byte little-endian number
    /// @param _output   The output
    /// @return          The output value
    function extractValue(bytes memory _output) internal pure returns (uint64) {
        uint64 _leValue = uint64(extractValueLE(_output));
        uint64 _beValue = reverseUint64(_leValue);
        return _beValue;
    }

    /// @notice          Extracts the value from the output in a tx
    /// @dev             Value is an 8-byte little-endian number
    /// @param _output   The byte array containing the output
    /// @param _at       The starting index of the output in the array
    /// @return          The output value
    function extractValueAt(bytes memory _output, uint256 _at) internal pure returns (uint64) {
        uint64 _leValue = uint64(_output.slice8(_at));
        uint64 _beValue = reverseUint64(_leValue);
        return _beValue;
    }

    /// @notice          Extracts the data from an op return output
    /// @dev             Returns hex"" if no data or not an op return
    /// @param _output   The output
    /// @return          Any data contained in the opreturn output, null if not an op return
    function extractOpReturnData(bytes memory _output) internal pure returns (bytes memory) {
        if (_output[9] != hex"6a") {
            return hex"";
        }
        bytes1 _dataLen = _output[10];
        return _output.slice(11, uint256(uint8(_dataLen)));
    }

    /// @notice          Extracts the hash from the output script
    /// @dev             Determines type by the length prefix and validates format
    /// @param _output   The output
    /// @return          The hash committed to by the pk_script, or null for errors
    function extractHash(bytes memory _output) internal pure returns (bytes memory) {
        return extractHashAt(_output, 8, _output.length - 8);
    }

    /// @notice          Extracts the hash from the output script
    /// @dev             Determines type by the length prefix and validates format
    /// @param _output   The byte array containing the output
    /// @param _at       The starting index of the output script in the array
    ///                  (output start + 8)
    /// @param _len      The length of the output script
    ///                  (output length - 8)
    /// @return          The hash committed to by the pk_script, or null for errors
    function extractHashAt(
        bytes memory _output,
        uint256 _at,
        uint256 _len
    ) internal pure returns (bytes memory) {
        uint8 _scriptLen = uint8(_output[_at]);

        // don't have to worry about overflow here.
        // if _scriptLen + 1 overflows, then output length would have to be < 1
        // for this check to pass. if it's < 1, then we errored when assigning
        // _scriptLen
        if (_scriptLen + 1 != _len) {
            return hex"";
        }

        if (uint8(_output[_at + 1]) == 0) {
            if (_scriptLen < 2) {
                return hex"";
            }
            uint256 _payloadLen = uint8(_output[_at + 2]);
            // Check for maliciously formatted witness outputs.
            // No need to worry about underflow as long b/c of the `< 2` check
            if (_payloadLen != _scriptLen - 2 || (_payloadLen != 0x20 && _payloadLen != 0x14)) {
                return hex"";
            }
            return _output.slice(_at + 3, _payloadLen);
        } else {
            bytes3 _tag = _output.slice3(_at);
            // p2pkh
            if (_tag == hex"1976a9") {
                // Check for maliciously formatted p2pkh
                // No need to worry about underflow, b/c of _scriptLen check
                if (uint8(_output[_at + 3]) != 0x14 ||
                    _output.slice2(_at + _len - 2) != hex"88ac") {
                    return hex"";
                }
                return _output.slice(_at + 4, 20);
            //p2sh
            } else if (_tag == hex"17a914") {
                // Check for maliciously formatted p2sh
                // No need to worry about underflow, b/c of _scriptLen check
                if (uint8(_output[_at + _len - 1]) != 0x87) {
                    return hex"";
                }
                return _output.slice(_at + 3, 20);
            }
        }
        return hex"";  /* NB: will trigger on OPRETURN and any non-standard that doesn't overrun */
    }

    /* ********** */
    /* Witness TX */
    /* ********** */


    /// @notice      Checks that the vin passed up is properly formatted
    /// @dev         Consider a vin with a valid vout in its scriptsig
    /// @param _vin  Raw bytes length-prefixed input vector
    /// @return      True if it represents a validly formatted vin
    function validateVin(bytes memory _vin) internal pure returns (bool) {
        uint256 _varIntDataLen;
        uint256 _nIns;

        (_varIntDataLen, _nIns) = parseVarInt(_vin);

        // Not valid if it says there are too many or no inputs
        if (_nIns == 0 || _varIntDataLen == ERR_BAD_ARG) {
            return false;
        }

        uint256 _offset = 1 + _varIntDataLen;

        for (uint256 i = 0; i < _nIns; i++) {
            // If we're at the end, but still expect more
            if (_offset >= _vin.length) {
                return false;
            }

            // Grab the next input and determine its length.
            uint256 _nextLen = determineInputLengthAt(_vin, _offset);
            if (_nextLen == ERR_BAD_ARG) {
                return false;
            }

            // Increase the offset by that much
            _offset += _nextLen;
        }

        // Returns false if we're not exactly at the end
        return _offset == _vin.length;
    }

    /// @notice      Checks that the vout passed up is properly formatted
    /// @dev         Consider a vout with a valid scriptpubkey
    /// @param _vout Raw bytes length-prefixed output vector
    /// @return      True if it represents a validly formatted vout
    function validateVout(bytes memory _vout) internal pure returns (bool) {
        uint256 _varIntDataLen;
        uint256 _nOuts;

        (_varIntDataLen, _nOuts) = parseVarInt(_vout);

        // Not valid if it says there are too many or no outputs
        if (_nOuts == 0 || _varIntDataLen == ERR_BAD_ARG) {
            return false;
        }

        uint256 _offset = 1 + _varIntDataLen;

        for (uint256 i = 0; i < _nOuts; i++) {
            // If we're at the end, but still expect more
            if (_offset >= _vout.length) {
                return false;
            }

            // Grab the next output and determine its length.
            // Increase the offset by that much
            uint256 _nextLen = determineOutputLengthAt(_vout, _offset);
            if (_nextLen == ERR_BAD_ARG) {
                return false;
            }

            _offset += _nextLen;
        }

        // Returns false if we're not exactly at the end
        return _offset == _vout.length;
    }



    /* ************ */
    /* Block Header */
    /* ************ */

    /// @notice          Extracts the transaction merkle root from a block header
    /// @dev             Use verifyHash256Merkle to verify proofs with this root
    /// @param _header   The header
    /// @return          The merkle root (little-endian)
    function extractMerkleRootLE(bytes memory _header) internal pure returns (bytes32) {
        return _header.slice32(36);
    }

    /// @notice          Extracts the target from a block header
    /// @dev             Target is a 256-bit number encoded as a 3-byte mantissa and 1-byte exponent
    /// @param _header   The header
    /// @return          The target threshold
    function extractTarget(bytes memory _header) internal pure returns (uint256) {
        return extractTargetAt(_header, 0);
    }

    /// @notice          Extracts the target from a block header
    /// @dev             Target is a 256-bit number encoded as a 3-byte mantissa and 1-byte exponent
    /// @param _header   The array containing the header
    /// @param at        The start of the header
    /// @return          The target threshold
    function extractTargetAt(bytes memory _header, uint256 at) internal pure returns (uint256) {
        uint24 _m = uint24(_header.slice3(72 + at));
        uint8 _e = uint8(_header[75 + at]);
        uint256 _mantissa = uint256(reverseUint24(_m));
        uint _exponent = _e - 3;

        return _mantissa * (256 ** _exponent);
    }

    /// @notice          Calculate difficulty from the difficulty 1 target and current target
    /// @dev             Difficulty 1 is 0x1d00ffff on mainnet and testnet
    /// @dev             Difficulty 1 is a 256-bit number encoded as a 3-byte mantissa and 1-byte exponent
    /// @param _target   The current target
    /// @return          The block difficulty (bdiff)
    function calculateDifficulty(uint256 _target) internal pure returns (uint256) {
        // Difficulty 1 calculated from 0x1d00ffff
        return DIFF1_TARGET.div(_target);
    }

    /// @notice          Extracts the previous block's hash from a block header
    /// @dev             Block headers do NOT include block number :(
    /// @param _header   The header
    /// @return          The previous block's hash (little-endian)
    function extractPrevBlockLE(bytes memory _header) internal pure returns (bytes32) {
        return _header.slice32(4);
    }

    /// @notice          Extracts the previous block's hash from a block header
    /// @dev             Block headers do NOT include block number :(
    /// @param _header   The array containing the header
    /// @param at        The start of the header
    /// @return          The previous block's hash (little-endian)
    function extractPrevBlockLEAt(
        bytes memory _header,
        uint256 at
    ) internal pure returns (bytes32) {
        return _header.slice32(4 + at);
    }

    /// @notice          Extracts the timestamp from a block header
    /// @dev             Time is not 100% reliable
    /// @param _header   The header
    /// @return          The timestamp (little-endian bytes)
    function extractTimestampLE(bytes memory _header) internal pure returns (bytes4) {
        return _header.slice4(68);
    }

    /// @notice          Extracts the timestamp from a block header
    /// @dev             Time is not 100% reliable
    /// @param _header   The header
    /// @return          The timestamp (uint)
    function extractTimestamp(bytes memory _header) internal pure returns (uint32) {
        return reverseUint32(uint32(extractTimestampLE(_header)));
    }

    /// @notice          Extracts the expected difficulty from a block header
    /// @dev             Does NOT verify the work
    /// @param _header   The header
    /// @return          The difficulty as an integer
    function extractDifficulty(bytes memory _header) internal pure returns (uint256) {
        return calculateDifficulty(extractTarget(_header));
    }

    /// @notice          Concatenates and hashes two inputs for merkle proving
    /// @param _a        The first hash
    /// @param _b        The second hash
    /// @return          The double-sha256 of the concatenated hashes
    function _hash256MerkleStep(bytes memory _a, bytes memory _b) internal view returns (bytes32) {
        return hash256View(abi.encodePacked(_a, _b));
    }

    /// @notice          Concatenates and hashes two inputs for merkle proving
    /// @param _a        The first hash
    /// @param _b        The second hash
    /// @return          The double-sha256 of the concatenated hashes
    function _hash256MerkleStep(bytes32 _a, bytes32 _b) internal view returns (bytes32) {
        return hash256Pair(_a, _b);
    }


    /// @notice          Verifies a Bitcoin-style merkle tree
    /// @dev             Leaves are 0-indexed. Inefficient version.
    /// @param _proof    The proof. Tightly packed LE sha256 hashes. The last hash is the root
    /// @param _index    The index of the leaf
    /// @return          true if the proof is valid, else false
    function verifyHash256Merkle(bytes memory _proof, uint _index) internal view returns (bool) {
        // Not an even number of hashes
        if (_proof.length % 32 != 0) {
            return false;
        }

        // Special case for coinbase-only blocks
        if (_proof.length == 32) {
            return true;
        }

        // Should never occur
        if (_proof.length == 64) {
            return false;
        }

        bytes32 _root = _proof.slice32(_proof.length - 32);
        bytes32 _current = _proof.slice32(0);
        bytes memory _tree = _proof.slice(32, _proof.length - 64);

        return verifyHash256Merkle(_current, _tree, _root, _index);
    }

    /// @notice          Verifies a Bitcoin-style merkle tree
    /// @dev             Leaves are 0-indexed. Efficient version.
    /// @param _leaf     The leaf of the proof. LE sha256 hash.
    /// @param _tree     The intermediate nodes in the proof.
    ///                  Tightly packed LE sha256 hashes.
    /// @param _root     The root of the proof. LE sha256 hash.
    /// @param _index    The index of the leaf
    /// @return          true if the proof is valid, else false
    function verifyHash256Merkle(
        bytes32 _leaf,
        bytes memory _tree,
        bytes32 _root,
        uint _index
    ) internal view returns (bool) {
        // Not an even number of hashes
        if (_tree.length % 32 != 0) {
            return false;
        }

        // Should never occur
        if (_tree.length == 0) {
            return false;
        }

        uint _idx = _index;
        bytes32 _current = _leaf;

        // i moves in increments of 32
        for (uint i = 0; i < _tree.length; i += 32) {
            if (_idx % 2 == 1) {
                _current = _hash256MerkleStep(_tree.slice32(i), _current);
            } else {
                _current = _hash256MerkleStep(_current, _tree.slice32(i));
            }
            _idx = _idx >> 1;
        }
        return _current == _root;
    }

    /*
    NB: https://github.com/bitcoin/bitcoin/blob/78dae8caccd82cfbfd76557f1fb7d7557c7b5edb/src/pow.cpp#L49-L72
    NB: We get a full-bitlength target from this. For comparison with
        header-encoded targets we need to mask it with the header target
        e.g. (full & truncated) == truncated
    */
    /// @notice                 performs the bitcoin difficulty retarget
    /// @dev                    implements the Bitcoin algorithm precisely
    /// @param _previousTarget  the target of the previous period
    /// @param _firstTimestamp  the timestamp of the first block in the difficulty period
    /// @param _secondTimestamp the timestamp of the last block in the difficulty period
    /// @return                 the new period's target threshold
    function retargetAlgorithm(
        uint256 _previousTarget,
        uint256 _firstTimestamp,
        uint256 _secondTimestamp
    ) internal pure returns (uint256) {
        uint256 _elapsedTime = _secondTimestamp.sub(_firstTimestamp);

        // Normalize ratio to factor of 4 if very long or very short
        if (_elapsedTime < RETARGET_PERIOD.div(4)) {
            _elapsedTime = RETARGET_PERIOD.div(4);
        }
        if (_elapsedTime > RETARGET_PERIOD.mul(4)) {
            _elapsedTime = RETARGET_PERIOD.mul(4);
        }

        /*
          NB: high targets e.g. ffff0020 can cause overflows here
              so we divide it by 256**2, then multiply by 256**2 later
              we know the target is evenly divisible by 256**2, so this isn't an issue
        */

        uint256 _adjusted = _previousTarget.div(65536).mul(_elapsedTime);
        return _adjusted.div(RETARGET_PERIOD).mul(65536);
    }
}

pragma solidity ^0.8.4;

/*

https://github.com/GNSPS/solidity-bytes-utils/

This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <https://unlicense.org>
*/


/** @title BytesLib **/
/** @author https://github.com/GNSPS **/

library BytesLib {
    function concat(bytes memory _preBytes, bytes memory _postBytes) internal pure returns (bytes memory) {
        bytes memory tempBytes;

        assembly {
            // Get a location of some free memory and store it in tempBytes as
            // Solidity does for memory variables.
            tempBytes := mload(0x40)

            // Store the length of the first bytes array at the beginning of
            // the memory for tempBytes.
            let length := mload(_preBytes)
            mstore(tempBytes, length)

            // Maintain a memory counter for the current write location in the
            // temp bytes array by adding the 32 bytes for the array length to
            // the starting location.
            let mc := add(tempBytes, 0x20)
            // Stop copying when the memory counter reaches the length of the
            // first bytes array.
            let end := add(mc, length)

            for {
                // Initialize a copy counter to the start of the _preBytes data,
                // 32 bytes into its memory.
                let cc := add(_preBytes, 0x20)
            } lt(mc, end) {
                // Increase both counters by 32 bytes each iteration.
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                // Write the _preBytes data into the tempBytes memory 32 bytes
                // at a time.
                mstore(mc, mload(cc))
            }

            // Add the length of _postBytes to the current length of tempBytes
            // and store it as the new length in the first 32 bytes of the
            // tempBytes memory.
            length := mload(_postBytes)
            mstore(tempBytes, add(length, mload(tempBytes)))

            // Move the memory counter back from a multiple of 0x20 to the
            // actual end of the _preBytes data.
            mc := end
            // Stop copying when the memory counter reaches the new combined
            // length of the arrays.
            end := add(mc, length)

            for {
                let cc := add(_postBytes, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }

            // Update the free-memory pointer by padding our last write location
            // to 32 bytes: add 31 bytes to the end of tempBytes to move to the
            // next 32 byte block, then round down to the nearest multiple of
            // 32. If the sum of the length of the two arrays is zero then add
            // one before rounding down to leave a blank 32 bytes (the length block with 0).
            mstore(0x40, and(
                add(add(end, iszero(add(length, mload(_preBytes)))), 31),
                not(31) // Round down to the nearest 32 bytes.
            ))
        }

        return tempBytes;
    }

    function concatStorage(bytes storage _preBytes, bytes memory _postBytes) internal {
        assembly {
            // Read the first 32 bytes of _preBytes storage, which is the length
            // of the array. (We don't need to use the offset into the slot
            // because arrays use the entire slot.)
            let fslot := sload(_preBytes.slot)
            // Arrays of 31 bytes or less have an even value in their slot,
            // while longer arrays have an odd value. The actual length is
            // the slot divided by two for odd values, and the lowest order
            // byte divided by two for even values.
            // If the slot is even, bitwise and the slot with 255 and divide by
            // two to get the length. If the slot is odd, bitwise and the slot
            // with -1 and divide by two.
            let slength := div(and(fslot, sub(mul(0x100, iszero(and(fslot, 1))), 1)), 2)
            let mlength := mload(_postBytes)
            let newlength := add(slength, mlength)
            // slength can contain both the length and contents of the array
            // if length < 32 bytes so let's prepare for that
            // v. http://solidity.readthedocs.io/en/latest/miscellaneous.html#layout-of-state-variables-in-storage
            switch add(lt(slength, 32), lt(newlength, 32))
            case 2 {
                // Since the new array still fits in the slot, we just need to
                // update the contents of the slot.
                // uint256(bytes_storage) = uint256(bytes_storage) + uint256(bytes_memory) + new_length
                sstore(
                    _preBytes.slot,
                    // all the modifications to the slot are inside this
                    // next block
                    add(
                        // we can just add to the slot contents because the
                        // bytes we want to change are the LSBs
                        fslot,
                        add(
                            mul(
                                div(
                                    // load the bytes from memory
                                    mload(add(_postBytes, 0x20)),
                                    // zero all bytes to the right
                                    exp(0x100, sub(32, mlength))
                        ),
                        // and now shift left the number of bytes to
                        // leave space for the length in the slot
                        exp(0x100, sub(32, newlength))
                        ),
                        // increase length by the double of the memory
                        // bytes length
                        mul(mlength, 2)
                        )
                    )
                )
            }
            case 1 {
                // The stored value fits in the slot, but the combined value
                // will exceed it.
                // get the keccak hash to get the contents of the array
                mstore(0x0, _preBytes.slot)
                let sc := add(keccak256(0x0, 0x20), div(slength, 32))

                // save new length
                sstore(_preBytes.slot, add(mul(newlength, 2), 1))

                // The contents of the _postBytes array start 32 bytes into
                // the structure. Our first read should obtain the `submod`
                // bytes that can fit into the unused space in the last word
                // of the stored array. To get this, we read 32 bytes starting
                // from `submod`, so the data we read overlaps with the array
                // contents by `submod` bytes. Masking the lowest-order
                // `submod` bytes allows us to add that value directly to the
                // stored value.

                let submod := sub(32, slength)
                let mc := add(_postBytes, submod)
                let end := add(_postBytes, mlength)
                let mask := sub(exp(0x100, submod), 1)

                sstore(
                    sc,
                    add(
                        and(
                            fslot,
                            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00
                    ),
                    and(mload(mc), mask)
                    )
                )

                for {
                    mc := add(mc, 0x20)
                    sc := add(sc, 1)
                } lt(mc, end) {
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } {
                    sstore(sc, mload(mc))
                }

                mask := exp(0x100, sub(mc, end))

                sstore(sc, mul(div(mload(mc), mask), mask))
            }
            default {
                // get the keccak hash to get the contents of the array
                mstore(0x0, _preBytes.slot)
                // Start copying to the last used word of the stored array.
                let sc := add(keccak256(0x0, 0x20), div(slength, 32))

                // save new length
                sstore(_preBytes.slot, add(mul(newlength, 2), 1))

                // Copy over the first `submod` bytes of the new data as in
                // case 1 above.
                let slengthmod := mod(slength, 32)
                let mlengthmod := mod(mlength, 32)
                let submod := sub(32, slengthmod)
                let mc := add(_postBytes, submod)
                let end := add(_postBytes, mlength)
                let mask := sub(exp(0x100, submod), 1)

                sstore(sc, add(sload(sc), and(mload(mc), mask)))

                for {
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } lt(mc, end) {
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } {
                    sstore(sc, mload(mc))
                }

                mask := exp(0x100, sub(mc, end))

                sstore(sc, mul(div(mload(mc), mask), mask))
            }
        }
    }

    function slice(bytes memory _bytes, uint _start, uint _length) internal  pure returns (bytes memory res) {
        if (_length == 0) {
            return hex"";
        }
        uint _end = _start + _length;
        require(_end > _start && _bytes.length >= _end, "Slice out of bounds");

        assembly {
            // Alloc bytes array with additional 32 bytes afterspace and assign it's size
            res := mload(0x40)
            mstore(0x40, add(add(res, 64), _length))
            mstore(res, _length)

            // Compute distance between source and destination pointers
            let diff := sub(res, add(_bytes, _start))

            for {
                let src := add(add(_bytes, 32), _start)
                let end := add(src, _length)
            } lt(src, end) {
                src := add(src, 32)
            } {
                mstore(add(src, diff), mload(src))
            }
        }
    }

    /// @notice Take a slice of the byte array, overwriting the destination.
    /// The length of the slice will equal the length of the destination array.
    /// @dev Make sure the destination array has afterspace if required.
    /// @param _bytes The source array
    /// @param _dest The destination array.
    /// @param _start The location to start in the source array.
    function sliceInPlace(
        bytes memory _bytes,
        bytes memory _dest,
        uint _start
    ) internal pure {
        uint _length = _dest.length;
        uint _end = _start + _length;
        require(_end > _start && _bytes.length >= _end, "Slice out of bounds");

        assembly {
            for {
                let src := add(add(_bytes, 32), _start)
                let res := add(_dest, 32)
                let end := add(src, _length)
            } lt(src, end) {
                src := add(src, 32)
                res := add(res, 32)
            } {
                mstore(res, mload(src))
            }
        }
    }

    // Static slice functions, no bounds checking
    /// @notice take a 32-byte slice from the specified position
    function slice32(bytes memory _bytes, uint _start) internal pure returns (bytes32 res) {
        assembly {
            res := mload(add(add(_bytes, 32), _start))
        }
    }

    /// @notice take a 20-byte slice from the specified position
    function slice20(bytes memory _bytes, uint _start) internal pure returns (bytes20) {
        return bytes20(slice32(_bytes, _start));
    }

    /// @notice take a 8-byte slice from the specified position
    function slice8(bytes memory _bytes, uint _start) internal pure returns (bytes8) {
        return bytes8(slice32(_bytes, _start));
    }

    /// @notice take a 4-byte slice from the specified position
    function slice4(bytes memory _bytes, uint _start) internal pure returns (bytes4) {
        return bytes4(slice32(_bytes, _start));
    }

    /// @notice take a 3-byte slice from the specified position
    function slice3(bytes memory _bytes, uint _start) internal pure returns (bytes3) {
        return bytes3(slice32(_bytes, _start));
    }

    /// @notice take a 2-byte slice from the specified position
    function slice2(bytes memory _bytes, uint _start) internal pure returns (bytes2) {
        return bytes2(slice32(_bytes, _start));
    }

    function toAddress(bytes memory _bytes, uint _start) internal  pure returns (address) {
        uint _totalLen = _start + 20;
        require(_totalLen > _start && _bytes.length >= _totalLen, "Address conversion out of bounds.");
        address tempAddress;

        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }

        return tempAddress;
    }

    function toUint(bytes memory _bytes, uint _start) internal  pure returns (uint256) {
        uint _totalLen = _start + 32;
        require(_totalLen > _start && _bytes.length >= _totalLen, "Uint conversion out of bounds.");
        uint256 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }

    function equal(bytes memory _preBytes, bytes memory _postBytes) internal pure returns (bool) {
        bool success = true;

        assembly {
            let length := mload(_preBytes)

            // if lengths don't match the arrays are not equal
            switch eq(length, mload(_postBytes))
            case 1 {
                // cb is a circuit breaker in the for loop since there's
                //  no said feature for inline assembly loops
                // cb = 1 - don't breaker
                // cb = 0 - break
                let cb := 1

                let mc := add(_preBytes, 0x20)
                let end := add(mc, length)

                for {
                    let cc := add(_postBytes, 0x20)
                    // the next line is the loop condition:
                    // while(uint(mc < end) + cb == 2)
                } eq(add(lt(mc, end), cb), 2) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    // if any of these checks fails then arrays are not equal
                    if iszero(eq(mload(mc), mload(cc))) {
                        // unsuccess:
                        success := 0
                        cb := 0
                    }
                }
            }
            default {
                // unsuccess:
                success := 0
            }
        }

        return success;
    }

    function equalStorage(bytes storage _preBytes, bytes memory _postBytes) internal view returns (bool) {
        bool success = true;

        assembly {
            // we know _preBytes_offset is 0
            let fslot := sload(_preBytes.slot)
            // Decode the length of the stored array like in concatStorage().
            let slength := div(and(fslot, sub(mul(0x100, iszero(and(fslot, 1))), 1)), 2)
            let mlength := mload(_postBytes)

            // if lengths don't match the arrays are not equal
            switch eq(slength, mlength)
            case 1 {
                // slength can contain both the length and contents of the array
                // if length < 32 bytes so let's prepare for that
                // v. http://solidity.readthedocs.io/en/latest/miscellaneous.html#layout-of-state-variables-in-storage
                if iszero(iszero(slength)) {
                    switch lt(slength, 32)
                    case 1 {
                        // blank the last byte which is the length
                        fslot := mul(div(fslot, 0x100), 0x100)

                        if iszero(eq(fslot, mload(add(_postBytes, 0x20)))) {
                            // unsuccess:
                            success := 0
                        }
                    }
                    default {
                        // cb is a circuit breaker in the for loop since there's
                        //  no said feature for inline assembly loops
                        // cb = 1 - don't breaker
                        // cb = 0 - break
                        let cb := 1

                        // get the keccak hash to get the contents of the array
                        mstore(0x0, _preBytes.slot)
                        let sc := keccak256(0x0, 0x20)

                        let mc := add(_postBytes, 0x20)
                        let end := add(mc, mlength)

                        // the next line is the loop condition:
                        // while(uint(mc < end) + cb == 2)
                        for {} eq(add(lt(mc, end), cb), 2) {
                            sc := add(sc, 1)
                            mc := add(mc, 0x20)
                        } {
                            if iszero(eq(sload(sc), mload(mc))) {
                                // unsuccess:
                                success := 0
                                cb := 0
                            }
                        }
                    }
                }
            }
            default {
                // unsuccess:
                success := 0
            }
        }

        return success;
    }

    function toBytes32(bytes memory _source) pure internal returns (bytes32 result) {
        if (_source.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(_source, 32))
        }
    }

    function keccak256Slice(bytes memory _bytes, uint _start, uint _length) pure internal returns (bytes32 result) {
        uint _end = _start + _length;
        require(_end > _start && _bytes.length >= _end, "Slice out of bounds");

        assembly {
            result := keccak256(add(add(_bytes, 32), _start), _length)
        }
    }
}

pragma solidity ^0.8.4;

/*
The MIT License (MIT)

Copyright (c) 2016 Smart Contract Solutions, Inc.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

    /**
     * @dev Multiplies two numbers, throws on overflow.
     */
    function mul(uint256 _a, uint256 _b) internal pure returns (uint256 c) {
        // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (_a == 0) {
            return 0;
        }

        c = _a * _b;
        require(c / _a == _b, "Overflow during multiplication.");
        return c;
    }

    /**
     * @dev Integer division of two numbers, truncating the quotient.
     */
    function div(uint256 _a, uint256 _b) internal pure returns (uint256) {
        // assert(_b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = _a / _b;
        // assert(_a == _b * c + _a % _b); // There is no case in which this doesn't hold
        return _a / _b;
    }

    /**
     * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 _a, uint256 _b) internal pure returns (uint256) {
        require(_b <= _a, "Underflow during subtraction.");
        return _a - _b;
    }

    /**
     * @dev Adds two numbers, throws on overflow.
     */
    function add(uint256 _a, uint256 _b) internal pure returns (uint256 c) {
        c = _a + _b;
        require(c >= _a, "Overflow during addition.");
        return c;
    }
}

// SPDX-License-Identifier: GPL-3.0-only

// ██████████████     ▐████▌     ██████████████
// ██████████████     ▐████▌     ██████████████
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
// ██████████████     ▐████▌     ██████████████
// ██████████████     ▐████▌     ██████████████
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌

pragma solidity ^0.8.0;

import {BTCUtils} from "@keep-network/bitcoin-spv-sol/contracts/BTCUtils.sol";

import "./IBridge.sol";
import "./ITBTCVault.sol";

/// @title Abstract AbstractTBTCDepositor contract.
/// @notice This abstract contract is meant to facilitate integration of protocols
///         aiming to use tBTC as an underlying Bitcoin bridge.
///
///         Such an integrator is supposed to:
///         - Create a child contract inheriting from this abstract contract
///         - Call the `__AbstractTBTCDepositor_initialize` initializer function
///         - Use the `_initializeDeposit` and `_finalizeDeposit` as part of their
///           business logic in order to initialize and finalize deposits.
///
/// @dev Example usage:
///      ```
///      // Example upgradeable integrator contract.
///      contract ExampleTBTCIntegrator is AbstractTBTCDepositor, Initializable {
///          /// @custom:oz-upgrades-unsafe-allow constructor
///          constructor() {
///              // Prevents the contract from being initialized again.
///              _disableInitializers();
///          }
///
///          function initialize(
///              address _bridge,
///              address _tbtcVault
///          ) external initializer {
///              __AbstractTBTCDepositor_initialize(_bridge, _tbtcVault);
///          }
///
///          function startProcess(
///              IBridgeTypes.BitcoinTxInfo calldata fundingTx,
///              IBridgeTypes.DepositRevealInfo calldata reveal
///          ) external {
///              // Embed necessary context as extra data.
///              bytes32 extraData = ...;
///
///              (uint256 depositKey, uint256 initialDepositAmount) = _initializeDeposit(
///                  fundingTx,
///                  reveal,
///                  extraData
///              );
///
///              // Use the depositKey to track the process.
///          }
///
///          function finalizeProcess(uint256 depositKey) external {
///              // Ensure the function cannot be called for the same deposit
///              // twice.
///
///              (
///                  uint256 initialDepositAmount,
///                  uint256 tbtcAmount,
///                  bytes32 extraData
///              ) = _finalizeDeposit(depositKey);
///
///              // Do something with the minted TBTC using context
///              // embedded in the extraData.
///          }
///      }
abstract contract AbstractTBTCDepositor {
    using BTCUtils for bytes;

    /// @notice Multiplier to convert satoshi to TBTC token units.
    uint256 public constant SATOSHI_MULTIPLIER = 10**10;

    /// @notice Bridge contract address.
    IBridge public bridge;
    /// @notice TBTCVault contract address.
    ITBTCVault public tbtcVault;

    // Reserved storage space that allows adding more variables without affecting
    // the storage layout of the child contracts. The convention from OpenZeppelin
    // suggests the storage space should add up to 50 slots. If more variables are
    // added in the upcoming versions one need to reduce the array size accordingly.
    // See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    // slither-disable-next-line unused-state
    uint256[47] private __gap;

    /// @notice Initializes the contract. MUST BE CALLED from the child
    ///         contract initializer.
    // slither-disable-next-line dead-code
    function __AbstractTBTCDepositor_initialize(
        address _bridge,
        address _tbtcVault
    ) internal {
        require(
            address(bridge) == address(0) && address(tbtcVault) == address(0),
            "AbstractTBTCDepositor already initialized"
        );

        require(_bridge != address(0), "Bridge address cannot be zero");
        require(_tbtcVault != address(0), "TBTCVault address cannot be zero");

        bridge = IBridge(_bridge);
        tbtcVault = ITBTCVault(_tbtcVault);
    }

    /// @notice Initializes a deposit by revealing it to the Bridge.
    /// @param fundingTx Bitcoin funding transaction data, see `IBridgeTypes.BitcoinTxInfo`.
    /// @param reveal Deposit reveal data, see `IBridgeTypes.DepositRevealInfo` struct.
    /// @param extraData 32-byte deposit extra data.
    /// @return depositKey Deposit key computed as
    ///         `keccak256(fundingTxHash | reveal.fundingOutputIndex)`. This
    ///         key can be used to refer to the deposit in the Bridge and
    ///         TBTCVault contracts.
    /// @return initialDepositAmount Amount of funding transaction deposit. In
    ///         TBTC token decimals precision.
    /// @dev Requirements:
    ///      - The revealed vault address must match the TBTCVault address,
    ///      - All requirements from {Bridge#revealDepositWithExtraData}
    ///        function must be met.
    /// @dev This function doesn't validate if a deposit has been initialized before,
    ///      as the Bridge won't allow the same deposit to be revealed twice.
    // slither-disable-next-line dead-code
    function _initializeDeposit(
        IBridgeTypes.BitcoinTxInfo calldata fundingTx,
        IBridgeTypes.DepositRevealInfo calldata reveal,
        bytes32 extraData
    ) internal returns (uint256 depositKey, uint256 initialDepositAmount) {
        require(reveal.vault == address(tbtcVault), "Vault address mismatch");

        depositKey = _calculateDepositKey(
            _calculateBitcoinTxHash(fundingTx),
            reveal.fundingOutputIndex
        );

        // The Bridge does not allow to reveal the same deposit twice and
        // revealed deposits stay there forever. The transaction will revert
        // if the deposit has already been revealed so, there is no need to do
        // an explicit check here.
        bridge.revealDepositWithExtraData(fundingTx, reveal, extraData);

        initialDepositAmount =
            bridge.deposits(depositKey).amount *
            SATOSHI_MULTIPLIER;
    }

    /// @notice Finalizes a deposit by calculating the amount of TBTC minted
    ///         for the deposit.
    /// @param depositKey Deposit key identifying the deposit.
    /// @return initialDepositAmount Amount of funding transaction deposit. In
    ///         TBTC token decimals precision.
    /// @return tbtcAmount Approximate amount of TBTC minted for the deposit. In
    ///         TBTC token decimals precision.
    /// @return extraData 32-byte deposit extra data.
    /// @dev Requirements:
    ///      - The deposit must be initialized but not finalized
    ///        (in the context of this contract) yet.
    ///      - The deposit must be finalized on the Bridge side. That means the
    ///        deposit must be either swept or optimistically minted.
    /// @dev THIS FUNCTION DOESN'T VALIDATE IF A DEPOSIT HAS BEEN FINALIZED BEFORE,
    ///      IT IS A RESPONSIBILITY OF THE IMPLEMENTING CONTRACT TO ENSURE THIS
    ///      FUNCTION WON'T BE CALLED TWICE FOR THE SAME DEPOSIT.
    /// @dev IMPORTANT NOTE: The tbtcAmount returned by this function is an
    ///      approximation. See documentation of the `calculateTbtcAmount`
    ///      responsible for calculating this value for more details.
    // slither-disable-next-line dead-code
    function _finalizeDeposit(uint256 depositKey)
        internal
        returns (
            uint256 initialDepositAmount,
            uint256 tbtcAmount,
            bytes32 extraData
        )
    {
        IBridgeTypes.DepositRequest memory deposit = bridge.deposits(
            depositKey
        );
        require(deposit.revealedAt != 0, "Deposit not initialized");

        (, uint64 finalizedAt) = tbtcVault.optimisticMintingRequests(
            depositKey
        );

        require(
            deposit.sweptAt != 0 || finalizedAt != 0,
            "Deposit not finalized by the bridge"
        );

        initialDepositAmount = deposit.amount * SATOSHI_MULTIPLIER;

        tbtcAmount = _calculateTbtcAmount(deposit.amount, deposit.treasuryFee);

        extraData = deposit.extraData;
    }

    /// @notice Calculates the amount of TBTC minted for the deposit.
    /// @param depositAmountSat Deposit amount in satoshi (1e8 precision).
    ///        This is the actual amount deposited by the deposit creator, i.e.
    ///        the gross amount the Bridge's fees are cut from.
    /// @param depositTreasuryFeeSat Deposit treasury fee in satoshi (1e8 precision).
    ///        This is an accurate value of the treasury fee that was actually
    ///        cut upon minting.
    /// @return tbtcAmount Approximate amount of TBTC minted for the deposit.
    /// @dev IMPORTANT NOTE: The tbtcAmount returned by this function may
    ///      not correspond to the actual amount of TBTC minted for the deposit.
    ///      Although the treasury fee cut upon minting is known precisely,
    ///      this is not the case for the optimistic minting fee and the Bitcoin
    ///      transaction fee. To overcome that problem, this function just takes
    ///      the current maximum allowed values of both fees, at the moment of deposit
    ///      finalization. For the great majority of the deposits, such an
    ///      algorithm will return a tbtcAmount slightly lesser than the
    ///      actual amount of TBTC minted for the deposit. This will cause
    ///      some TBTC to be left in the contract and ensure there is enough
    ///      liquidity to finalize the deposit. However, in some rare cases,
    ///      where the actual values of those fees change between the deposit
    ///      minting and finalization, the tbtcAmount returned by this function
    ///      may be greater than the actual amount of TBTC minted for the deposit.
    ///      If this happens and the reserve coming from previous deposits
    ///      leftovers does not provide enough liquidity, the deposit will have
    ///      to wait for finalization until the reserve is refilled by subsequent
    ///      deposits or a manual top-up. The integrator is responsible for
    ///      handling such cases.
    // slither-disable-next-line dead-code
    function _calculateTbtcAmount(
        uint64 depositAmountSat,
        uint64 depositTreasuryFeeSat
    ) internal view virtual returns (uint256) {
        // Both deposit amount and treasury fee are in the 1e8 satoshi precision.
        // We need to convert them to the 1e18 TBTC precision.
        uint256 amountSubTreasury = (depositAmountSat - depositTreasuryFeeSat) *
            SATOSHI_MULTIPLIER;

        uint256 omFeeDivisor = tbtcVault.optimisticMintingFeeDivisor();
        uint256 omFee = omFeeDivisor > 0
            ? (amountSubTreasury / omFeeDivisor)
            : 0;

        // The deposit transaction max fee is in the 1e8 satoshi precision.
        // We need to convert them to the 1e18 TBTC precision.
        (, , uint64 depositTxMaxFee, ) = bridge.depositParameters();
        uint256 txMaxFee = depositTxMaxFee * SATOSHI_MULTIPLIER;

        return amountSubTreasury - omFee - txMaxFee;
    }

    /// @notice Calculates the deposit key for the given funding transaction
    ///         hash and funding output index.
    /// @param fundingTxHash Funding transaction hash.
    /// @param fundingOutputIndex Funding output index.
    /// @return depositKey Deposit key computed as
    ///         `keccak256(fundingTxHash | reveal.fundingOutputIndex)`. This
    ///         key can be used to refer to the deposit in the Bridge and
    ///         TBTCVault contracts.
    // slither-disable-next-line dead-code
    function _calculateDepositKey(
        bytes32 fundingTxHash,
        uint32 fundingOutputIndex
    ) internal pure returns (uint256) {
        return
            uint256(
                keccak256(abi.encodePacked(fundingTxHash, fundingOutputIndex))
            );
    }

    /// @notice Calculates the Bitcoin transaction hash for the given Bitcoin
    ///         transaction data.
    /// @param txInfo Bitcoin transaction data, see `IBridgeTypes.BitcoinTxInfo` struct.
    /// @return txHash Bitcoin transaction hash.
    // slither-disable-next-line dead-code
    function _calculateBitcoinTxHash(IBridgeTypes.BitcoinTxInfo calldata txInfo)
        internal
        view
        returns (bytes32)
    {
        return
            abi
                .encodePacked(
                    txInfo.version,
                    txInfo.inputVector,
                    txInfo.outputVector,
                    txInfo.locktime
                )
                .hash256View();
    }

    /// @notice Returns minimum deposit amount.
    /// @return Minimum deposit amount. In TBTC token decimals precision.
    // slither-disable-next-line dead-code
    function _minDepositAmount() internal view returns (uint256) {
        // Read tBTC Bridge Deposit Dust Threshold in satoshi precision.
        (uint64 bridgeDepositDustThresholdSat, , , ) = bridge
            .depositParameters();

        // Convert tBTC Bridge Deposit Dust Threshold to TBTC token precision.
        return bridgeDepositDustThresholdSat * SATOSHI_MULTIPLIER;
    }
}

// SPDX-License-Identifier: GPL-3.0-only

// ██████████████     ▐████▌     ██████████████
// ██████████████     ▐████▌     ██████████████
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
// ██████████████     ▐████▌     ██████████████
// ██████████████     ▐████▌     ██████████████
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌

pragma solidity ^0.8.0;

/// @notice Namespace which groups all types relevant to the IBridge interface.
/// @dev This is a mirror of the real types used in the Bridge contract.
///      This way, the `integrator` subpackage does not need to import
///      anything from the `bridge` subpackage and explicitly depend on it.
///      This simplifies the dependency graph for integrators.
library IBridgeTypes {
    /// @dev See bridge/BitcoinTx.sol#Info
    struct BitcoinTxInfo {
        bytes4 version;
        bytes inputVector;
        bytes outputVector;
        bytes4 locktime;
    }

    /// @dev See bridge/Deposit.sol#DepositRevealInfo
    struct DepositRevealInfo {
        uint32 fundingOutputIndex;
        bytes8 blindingFactor;
        bytes20 walletPubKeyHash;
        bytes20 refundPubKeyHash;
        bytes4 refundLocktime;
        address vault;
    }

    /// @dev See bridge/Deposit.sol#DepositRequest
    struct DepositRequest {
        address depositor;
        uint64 amount;
        uint32 revealedAt;
        address vault;
        uint64 treasuryFee;
        uint32 sweptAt;
        bytes32 extraData;
    }
}

/// @notice Interface of the Bridge contract.
/// @dev See bridge/Bridge.sol
interface IBridge {
    /// @dev See {Bridge#revealDepositWithExtraData}
    function revealDepositWithExtraData(
        IBridgeTypes.BitcoinTxInfo calldata fundingTx,
        IBridgeTypes.DepositRevealInfo calldata reveal,
        bytes32 extraData
    ) external;

    /// @dev See {Bridge#deposits}
    function deposits(uint256 depositKey)
        external
        view
        returns (IBridgeTypes.DepositRequest memory);

    /// @dev See {Bridge#depositParameters}
    function depositParameters()
        external
        view
        returns (
            uint64 depositDustThreshold,
            uint64 depositTreasuryFeeDivisor,
            uint64 depositTxMaxFee,
            uint32 depositRevealAheadPeriod
        );
}

// SPDX-License-Identifier: GPL-3.0-only

// ██████████████     ▐████▌     ██████████████
// ██████████████     ▐████▌     ██████████████
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
// ██████████████     ▐████▌     ██████████████
// ██████████████     ▐████▌     ██████████████
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌
//               ▐████▌    ▐████▌

pragma solidity ^0.8.0;

/// @notice Interface of the TBTCVault contract.
/// @dev See vault/TBTCVault.sol
interface ITBTCVault {
    /// @dev See {TBTCVault#optimisticMintingRequests}
    function optimisticMintingRequests(uint256 depositKey)
        external
        returns (uint64 requestedAt, uint64 finalizedAt);

    /// @dev See {TBTCVault#optimisticMintingFeeDivisor}
    function optimisticMintingFeeDivisor() external view returns (uint32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable2Step.sol)

pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "./OwnableUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which provides access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is specified at deployment time in the constructor for `Ownable`. This
 * can later be changed with {transferOwnership} and {acceptOwnership}.
 *
 * This module is used through inheritance. It will make available all functions
 * from parent (Ownable).
 */
abstract contract Ownable2StepUpgradeable is Initializable, OwnableUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Ownable2Step
    struct Ownable2StepStorage {
        address _pendingOwner;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable2Step")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant Ownable2StepStorageLocation = 0x237e158222e3e6968b72b9db0d8043aacf074ad9f650f0d1606b4d82ee432c00;

    function _getOwnable2StepStorage() private pure returns (Ownable2StepStorage storage $) {
        assembly {
            $.slot := Ownable2StepStorageLocation
        }
    }

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    function __Ownable2Step_init() internal onlyInitializing {
    }

    function __Ownable2Step_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Returns the address of the pending owner.
     */
    function pendingOwner() public view virtual returns (address) {
        Ownable2StepStorage storage $ = _getOwnable2StepStorage();
        return $._pendingOwner;
    }

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        Ownable2StepStorage storage $ = _getOwnable2StepStorage();
        $._pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual override {
        Ownable2StepStorage storage $ = _getOwnable2StepStorage();
        delete $._pendingOwner;
        super._transferOwnership(newOwner);
    }

    /**
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() public virtual {
        address sender = _msgSender();
        if (pendingOwner() != sender) {
            revert OwnableUnauthorizedAccount(sender);
        }
        _transferOwnership(sender);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;

import {ContextUpgradeable} from "../utils/ContextUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Ownable
    struct OwnableStorage {
        address _owner;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OwnableStorageLocation = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;

    function _getOwnableStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := OwnableStorageLocation
        }
    }

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    function __Ownable_init(address initialOwner) internal onlyInitializing {
        __Ownable_init_unchained(initialOwner);
    }

    function __Ownable_init_unchained(address initialOwner) internal onlyInitializing {
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
        OwnableStorage storage $ = _getOwnableStorage();
        return $._owner;
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
        OwnableStorage storage $ = _getOwnableStorage();
        address oldOwner = $._owner;
        $._owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.20;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Storage of the initializable contract.
     *
     * It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions
     * when using with upgradeable contracts.
     *
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableStorage {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @dev The contract is already initialized.
     */
    error InvalidInitialization();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that in the context of a constructor an `initializer` may be invoked any
     * number of times. This behavior in the constructor can be useful during testing and is not expected to be used in
     * production.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        // Cache values to avoid duplicated sloads
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reininitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: Setting the version to 2**64 - 1 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint64 version) {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev Reverts if the contract is not in an initializing state. See {onlyInitializing}.
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        assembly {
            $.slot := INITIALIZABLE_STORAGE
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;
import {Initializable} from "../proxy/utils/Initializable.sol";

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;
import {Initializable} from "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    /// @custom:storage-location erc7201:openzeppelin.storage.ReentrancyGuard
    struct ReentrancyGuardStorage {
        uint256 _status;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ReentrancyGuardStorageLocation = 0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    function _getReentrancyGuardStorage() private pure returns (ReentrancyGuardStorage storage $) {
        assembly {
            $.slot := ReentrancyGuardStorageLocation
        }
    }

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        $._status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if ($._status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        $._status = ENTERED;
    }

    function _nonReentrantAfter() private {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        $._status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        return $._status == ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
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
    event Approval(address indexed owner, address indexed spender, uint256 value);

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
    function allowance(address owner, address spender) external view returns (uint256);

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
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";
import {IERC20Permit} from "../extensions/IERC20Permit.sol";
import {Address} from "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev An operation with an ERC20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

pragma solidity ^0.8.20;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.20;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS
    }

    /**
     * @dev The signature derives the `address(0)`.
     */
    error ECDSAInvalidSignature();

    /**
     * @dev The signature has an invalid length.
     */
    error ECDSAInvalidSignatureLength(uint256 length);

    /**
     * @dev The signature has an S value that is in the upper half order.
     */
    error ECDSAInvalidSignatureS(bytes32 s);

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with `signature` or an error. This will not
     * return address(0) without also returning an error description. Errors are documented using an enum (error type)
     * and a bytes32 providing additional information about the error.
     *
     * If no error is returned, then the address can be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError, bytes32) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength, bytes32(signature.length));
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, signature);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     */
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address, RecoverError, bytes32) {
        unchecked {
            bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            // We do not check for an overflow here since the shift operation results in 0 or 1.
            uint8 v = uint8((uint256(vs) >> 255) + 27);
            return tryRecover(hash, v, r, s);
        }
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, r, vs);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError, bytes32) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS, s);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature, bytes32(0));
        }

        return (signer, RecoverError.NoError, bytes32(0));
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, v, r, s);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Optionally reverts with the corresponding custom error according to the `error` argument provided.
     */
    function _throwError(RecoverError error, bytes32 errorArg) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert ECDSAInvalidSignature();
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert ECDSAInvalidSignatureLength(uint256(errorArg));
        } else if (error == RecoverError.InvalidSignatureS) {
            revert ECDSAInvalidSignatureS(errorArg);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/MessageHashUtils.sol)

pragma solidity ^0.8.20;

import {Strings} from "../Strings.sol";

/**
 * @dev Signature message hash utilities for producing digests to be consumed by {ECDSA} recovery or signing.
 *
 * The library provides methods for generating a hash of a message that conforms to the
 * https://eips.ethereum.org/EIPS/eip-191[EIP 191] and https://eips.ethereum.org/EIPS/eip-712[EIP 712]
 * specifications.
 */
library MessageHashUtils {
    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x45` (`personal_sign` messages).
     *
     * The digest is calculated by prefixing a bytes32 `messageHash` with
     * `"\x19Ethereum Signed Message:\n32"` and hashing the result. It corresponds with the
     * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
     *
     * NOTE: The `messageHash` parameter is intended to be the result of hashing a raw message with
     * keccak256, although any bytes32 value can be safely used because the final digest will
     * be re-hashed.
     *
     * See {ECDSA-recover}.
     */
    function toEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32") // 32 is the bytes-length of messageHash
            mstore(0x1c, messageHash) // 0x1c (28) is the length of the prefix
            digest := keccak256(0x00, 0x3c) // 0x3c is the length of the prefix (0x1c) + messageHash (0x20)
        }
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x45` (`personal_sign` messages).
     *
     * The digest is calculated by prefixing an arbitrary `message` with
     * `"\x19Ethereum Signed Message:\n" + len(message)` and hashing the result. It corresponds with the
     * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
     *
     * See {ECDSA-recover}.
     */
    function toEthSignedMessageHash(bytes memory message) internal pure returns (bytes32) {
        return
            keccak256(bytes.concat("\x19Ethereum Signed Message:\n", bytes(Strings.toString(message.length)), message));
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x00` (data with intended validator).
     *
     * The digest is calculated by prefixing an arbitrary `data` with `"\x19\x00"` and the intended
     * `validator` address. Then hashing the result.
     *
     * See {ECDSA-recover}.
     */
    function toDataWithIntendedValidatorHash(address validator, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"19_00", validator, data));
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-712 typed data (EIP-191 version `0x01`).
     *
     * The digest is calculated from a `domainSeparator` and a `structHash`, by prefixing them with
     * `\x19\x01` and hashing the result. It corresponds to the hash signed by the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`] JSON-RPC method as part of EIP-712.
     *
     * See {ECDSA-recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, hex"19_01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            digest := keccak256(ptr, 0x42)
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/Math.sol)

pragma solidity ^0.8.20;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            return a / b;
        }

        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            if (denominator <= prod1) {
                revert MathOverflowedMulDiv();
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (unsignedRoundsUp(rounding) && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (unsignedRoundsUp(rounding) && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (unsignedRoundsUp(rounding) && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (unsignedRoundsUp(rounding) && 1 << (result << 3) < value ? 1 : 0);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.20;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Strings.sol)

pragma solidity ^0.8.20;

import {Math} from "./math/Math.sol";
import {SignedMath} from "./math/SignedMath.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant HEX_DIGITS = "0123456789abcdef";
    uint8 private constant ADDRESS_LENGTH = 20;

    /**
     * @dev The `value` string doesn't fit in the specified `length`.
     */
    error StringsInsufficientHexLength(uint256 value, uint256 length);

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toStringSigned(int256 value) internal pure returns (string memory) {
        return string.concat(value < 0 ? "-" : "", toString(SignedMath.abs(value)));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal
     * representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import "@keep-network/tbtc-v2/contracts/integrator/AbstractTBTCDepositor.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IERC20WithPermit.sol";

/// @notice BitcoinBridge abstract contract exposes the capability of bridging
///         Bitcoin (using tBTC) from Ethereum to the Mezo chain.
///         The process can be achieved in one of two ways:
///         - Depositing: which is used when the user does not yet have tBTC.
///           In this case the user needs to create a Bitcoin transaction with
///           a specific format and use `initializeBTCBridging` and
///           `finalizeBTCBridging` functions,
///         - Bridging: which is used when the user already has tBTC on Ethereum
///           and would like to bridge it to Mezo. In this case either
///          `bridgeTBTC` or `bridgeTBTCWithPermit` must be used.
/// @dev The contract is supposed to be extended by the MezoBridge contract.
abstract contract BitcoinBridge is
    AbstractTBTCDepositor,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    /// @notice Reflects the BTC deposit state:
    ///         - Unknown deposit has not been initialized yet.
    ///         - Initialized deposit has been initialized with a call to
    ///           `initializeBTCBridging` function and is known to this contract.
    ///         - Finalized deposit led to tBTC ERC20 minting and was finalized
    ///           with a call to `finalizeBTCBridging` function. Deposit
    ///           finalizing leads to tBTC being bridged to the Mezo chain.
    enum BTCDepositState {
        Unknown,
        Initialized,
        Finalized
    }

    /// @notice Reference to the tBTC ERC20 token contract.
    address public tbtcToken;

    /// @notice Holds the BTC deposit state, keyed by the deposit key calculated for
    ///         the individual deposit during the call to `initializeBTCBridging`
    ///         function.
    mapping(uint256 => BTCDepositState) public btcDeposits;

    /// @notice Minimum amount of tBTC that can be bridged using `bridgeTBTC`
    ///         and `bridgeTBTCWithPermit`. It helps to prevent DoS attacks.
    ///         Its value is in tBTC precision. Note that `initializeBTCBridging`
    ///         does not enforce this limit, as the tBTC bridge already has its
    ///         own minimum deposit requirement, which provides adequate
    ///         protection against DoS attacks.
    uint256 public minTBTCAmount;

    // Reserved storage space that allows adding more variables without affecting
    // the storage layout of the child contracts. The convention from OpenZeppelin
    // suggests the storage space should add up to 50 slots. If more variables are
    // added in the upcoming versions one need to reduce the array size accordingly.
    // See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    // slither-disable-next-line unused-state
    uint256[47] private __gap;

    event BTCDepositInitialized(
        uint256 indexed btcDepositKey,
        address indexed recipient
    );

    event BTCDepositFinalized(
        uint256 indexed btcDepositKey,
        uint256 initialAmount,
        uint256 tbtcAmount
    );

    event MinTBTCAmountUpdated(uint256 minTBTCAmount);

    error MinTBTCAmountIsZero();

    error BTCRecipientIsZeroAddress();

    error TBTCTokenIsZeroAddress();

    error AmountBelowMinTBTCAmount();

    /// @notice Function reverts with this error if the BTC deposit state is not as
    ///         expected. `initializeBTCBridging` can only be called for
    ///         `Unknown` deposits. `finalizeBTCBridging` can only be called
    ///         for `Initialized` deposits.
    error UnexpectedBTCDepositState(
        BTCDepositState actualState,
        BTCDepositState expectedState
    );

    /// @notice `finalizeBTCBridging` reverts with this error if the
    ///         `recipient` passed as the parameters is not the same as passed
    ///         earlier to the `initializeBTCBridging`.
    error UnexpectedExtraData(
        bytes32 actualExtraData,
        bytes32 expectedExtraData
    );

    /// @notice Bridges the `amount` of the `token` to the `recipient` address on Mezo.
    /// @param recipient Recipient of the bridged token.
    /// @param token Address of the bridged token.
    /// @param amount Amount of the bridged token.
    function _bridge(
        address recipient,
        address token,
        uint256 amount
    ) internal virtual;

    /// @notice Initializes the contract.
    /// @dev All addresses passed to the contract must not be 0x0.
    /// @param _tbtcBridge Address to the tBTC Bridge contract.
    /// @param _tbtcVault Address to the tBTC TBTCVault contract.
    /// @param _tbtcToken Address to the tBTC ERC20 token contract.
    function __BitcoinBridge_initialize(
        address _tbtcBridge,
        address _tbtcVault,
        address _tbtcToken
    ) internal {
        __AbstractTBTCDepositor_initialize(_tbtcBridge, _tbtcVault);
        // Note that initializers of OZ upgradeable contracts are not linearized
        // by the compiler like constructors. Therefore, if __BitcoinBridge_initialize
        // is called from within a child contract's initializer that also calls
        // __Ownable_init and __ReentrancyGuard_init somewhere else in the
        // inheritance chain, the Ownable and ReentrancyGuard initializers will
        // be called twice (it's actually the case for the MezoBridge child contract).
        // Although this is not a problem with currently used OZ version where
        // __Ownable_init and __ReentrancyGuard_init are idempotent
        // (as long as __Ownable_init is called with the same argument),
        // it's worth noting this caveat for future.
        //
        // For reference, see the following OZ documentation:
        // https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/v5.0.2/docs/modules/ROOT/pages/upgradeable.adoc#multiple-inheritance
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        if (_tbtcToken == address(0)) {
            revert TBTCTokenIsZeroAddress();
        }
        tbtcToken = _tbtcToken;

        minTBTCAmount = 0.01 * 1e18; // 0.01 BTC
    }

    /// @notice Updates the minimum tBTC amount allowed to be bridged using
    ///         `bridgeTBTC` and `bridgeTBTCWithPermit`.
    /// @param newMinTBTCAmount New minimum tBTC amount (in tBTC precision).
    ///                         Must be positive.
    /// @dev Access restricted with the `onlyOwner` modifier.
    function updateMinTBTCAmount(uint256 newMinTBTCAmount) external onlyOwner {
        if (newMinTBTCAmount == 0) {
            revert MinTBTCAmountIsZero();
        }

        minTBTCAmount = newMinTBTCAmount;

        emit MinTBTCAmountUpdated(newMinTBTCAmount);
    }

    /// @notice Transfers and locks the `amount` of tBTC in the contract and
    ///         calls `_bridge` function thus initiating bridging to Mezo to
    ///         the `recipient` address.
    /// @param amount Amount of tBTC to be bridged.
    /// @param recipient Recipient of the bridged tBTC.
    /// @dev Requirements:
    ///     - The amount must be equal to or greater than the minimum tBTC
    ///       amount allowed to be bridged.
    ///     - The tBTC is transferred using the allowance mechanism. The caller
    ///       must ensure the appropriate amount of tBTC is approved for the
    ///      `BitcoinBridge` contract.
    function bridgeTBTC(
        uint256 amount,
        address recipient
    ) external nonReentrant {
        _bridgeTBTC(amount, recipient);
    }

    /// @notice Private function holding the actual logic for the external
    ///         non-reentrant `bridgeTBTC` function. This function allows
    ///         reusing TBTC bridging logic from another external non-reentrant
    ///         function - `bridgeTBTCWithPermit`. This wouldn't be possible
    ///         without the `_bridgeTBTC` function, as non-reentrant functions
    ///         cannot call themselves.
    function _bridgeTBTC(uint256 amount, address recipient) private {
        if (recipient == address(0)) {
            revert BTCRecipientIsZeroAddress();
        }

        if (amount < minTBTCAmount) {
            revert AmountBelowMinTBTCAmount();
        }

        // Get tbtcToken from storage only once to save gas.
        address _tbtcToken = tbtcToken;

        _bridge(recipient, _tbtcToken, amount);

        IERC20(_tbtcToken).safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Transfers and locks the `amount` of tBTC in the contract and
    ///         calls `_bridge` function thus initializing bridging to Mezo to
    ///         the `recipient` address. If the caller has not approved enough
    ///         tBTC for the `BitcoinBridge` contract, it also increases the
    ///         allowance using the EIP2612 permit functionality.
    /// @dev This function can achieve the same result as `bridgeTBTC`, but
    ///      it does not have to be preceded with a separate transaction
    ///      approving tBTC.
    ///      Requirements:
    ///      - must be called by the same address that generated the signature,
    ///      - the `amount` and `deadline` must be the same as used during the
    ///        signature generation and `v`, `r`, `s` parameters must represent
    ///        a valid signature.
    /// @param amount Amount of tBTC to be bridged.
    /// @param recipient Recipient of the bridged tBTC.
    /// @param deadline EIP2612 deadline
    /// @param v EIP2612 signature v
    /// @param r EIP2612 signature r
    /// @param s EIP2612 signature s
    function bridgeTBTCWithPermit(
        uint256 amount,
        address recipient,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        // If allowance is sufficient, we can fallback to the regular
        // `bridgeTBTC` call. This is also a protection in case someone
        // front-runned the `bridgeTBTCWithPermit` call and already executed
        // permit on the `tbtcToken` contract.
        if (IERC20(tbtcToken).allowance(msg.sender, address(this)) < amount) {
            IERC20WithPermit(tbtcToken).permit(
                msg.sender,
                address(this),
                amount,
                deadline,
                v,
                r,
                s
            );
        }

        _bridgeTBTC(amount, recipient);
    }

    /// @notice Initializes the BTC deposit process after the Bitcoin P2(W)SH deposit
    ///         transaction is performed. Reveals the deposit to tBTC bridge and
    ///         marks the deposit as initialized internally. Once tBTC minting
    ///         is completed, this call should be followed by a call to
    ///         `finalizeBTCBridging`. The P2(W)SH Bitcoin script depositing
    ///         tokens should have the following format:
    ///
    ///         <bridge-address> DROP
    ///         <recipient-extra-data> DROP
    ///         <blinding-factor> DROP
    ///         DUP HASH160 <signingGroupPubkeyHash> EQUAL
    ///         IF
    ///           CHECKSIG
    ///         ELSE
    ///           DUP HASH160 <refundPubkeyHash> EQUALVERIFY
    ///           <locktime> CHECKLOCKTIMEVERIFY DROP
    ///           CHECKSIG
    ///         ENDIF
    ///
    ///         Where:
    ///
    ///         <bridge-address> 20-byte Ethereum address of the BitcoinBridge
    ///         contract.
    ///
    ///         <recipient-extra-data> 32-byte keccak256 hash of abi-encoded
    ///         recipient address.
    ///
    ///         <blinding-factor> 8-byte deposit blinding factor, as used in the
    ///         tBTC bridge
    ///
    ///         <signingGroupPubkeyHash> The compressed Bitcoin public key (33
    ///         bytes and 02 or 03 prefix) of the deposit's wallet hashed in the
    ///         HASH160 Bitcoin opcode style. This must point to the active tBTC
    ///         bridge wallet.
    ///
    ///         <refundPubkeyHash> The compressed Bitcoin public key (33 bytes
    ///         and 02 or 03 prefix) that can be used to make the deposit refund
    ///         after the tBTC bridge refund locktime passed. Hashed in the
    ///         HASH160 Bitcoin opcode style. This is needed only as a security
    ///         measure protecting the user in case tBTC bridge completely stops
    ///         functioning.
    ///
    ///         <locktime> The Bitcoin script refund locktime (4-byte LE),
    ///         according to tBTC bridge rules.
    ///
    ///         Please consult tBTC Bridge.revealDepositWithExtraData function
    ///         documentation for more information.
    /// @dev IMPORTANT NOTE: The amount of tBTC bridged to the Mezo chain may
    ///      not correspond to the actual amount of tBTC minted for the deposit.
    ///      The reason for this is that the fees for optimistic minting and
    ///      Bitcoin transaction are not known precisely upon minting. For the
    ///      great majority of deposits, slightly less tBTC will be bridged and
    ///      the surplus of tBTC will remain in the `BitcoinBridge` contract.
    ///      For a detailed explanation see `_calculateTbtcAmount` from the
    ///      `AbstractTBTCDepositor` contract.
    ///      Requirements:
    ///      - The recipient address must be represented in the Bitcoin deposit
    ///        P2(W)SH script in the <recipient-extra-data>. If the value in the
    ///        Bitcoin script and the value passed as the parameters do not
    ///        match, the function will revert.
    ///      - The function can be called only one time for the given P2(W)SH
    ///        Bitcoin deposit transaction.
    ///      - All the requirements of tBTC Bridge.revealDepositWithExtraData
    ///        must be met.
    /// @param fundingTx Bitcoin funding transaction data, see `BitcoinTx.Info`
    /// @param reveal Deposit reveal data, see `RevealInfo` struct.
    /// @param recipient Recipient of the bridged tBTC in Mezo.
    function initializeBTCBridging(
        IBridgeTypes.BitcoinTxInfo calldata fundingTx,
        IBridgeTypes.DepositRevealInfo calldata reveal,
        address recipient
    ) external {
        if (recipient == address(0)) {
            revert BTCRecipientIsZeroAddress();
        }

        // Store `keccak256` of the recipient address rather than the recipient
        // address in extra data. This gives us the flexibility to add new
        // parameters in the future.
        (uint256 btcDepositKey, ) = _initializeDeposit(
            fundingTx,
            reveal,
            keccak256(abi.encode(recipient))
        );

        if (btcDeposits[btcDepositKey] != BTCDepositState.Unknown) {
            revert UnexpectedBTCDepositState(
                btcDeposits[btcDepositKey],
                BTCDepositState.Unknown
            );
        }

        btcDeposits[btcDepositKey] = BTCDepositState.Initialized;

        emit BTCDepositInitialized(btcDepositKey, recipient);
    }

    /// @notice Finalizes the BTC deposit process by locking tBTC ERC20 token to
    ///         the `BitcoinBridge` contract and calling `_bridge` function
    ///         thus initiating bridging to the Mezo chain. This function should
    ///         be called after the deposit was initialized with a call to
    ///         `initializeBTCBridging` function and after tBTC ERC20 token
    ///         was minted by the bridge to the `BitcoinBridge` contract.
    ///         Please note several hours may pass between `initializeBTCBridging`
    ///         and `finalizeBTCBridging`.
    /// @dev Requirements:
    ///      - `initializeBTCBridging` was called for the given deposit before.
    ///      - tBTC ERC20 was minted by tBTC Bridge to this contract.
    ///      - The function was not called for the given deposit before.
    ///      - The same `recipient` address was passed when initiating the
    ///        deposit.
    /// @param btcDepositKey The BTC deposit key, as emitted in the `BTCDepositInitialized`
    ///        event emitted by the `initializeBTCBridging` function for the deposit.
    /// @param recipient The address of the account that should own the
    ///        deposit. This must be the same value as passed to
    ///        `initializeBTCBridging` for the deposit.
    function finalizeBTCBridging(
        uint256 btcDepositKey,
        address recipient
    ) external {
        if (btcDeposits[btcDepositKey] != BTCDepositState.Initialized) {
            revert UnexpectedBTCDepositState(
                btcDeposits[btcDepositKey],
                BTCDepositState.Initialized
            );
        }

        btcDeposits[btcDepositKey] = BTCDepositState.Finalized;

        (
            uint256 initialDepositAmount,
            uint256 tbtcAmount,
            bytes32 expectedExtraData
        ) = _finalizeDeposit(btcDepositKey);

        bytes32 actualExtraData = keccak256(abi.encode(recipient));

        if (actualExtraData != expectedExtraData) {
            revert UnexpectedExtraData(actualExtraData, expectedExtraData);
        }

        emit BTCDepositFinalized(
            btcDepositKey,
            initialDepositAmount,
            tbtcAmount
        );

        _bridge(recipient, tbtcToken, tbtcAmount);
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import "@keep-network/tbtc-v2/contracts/integrator/AbstractTBTCDepositor.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Portal.sol";

/// @notice BitcoinDepositor contract holds the logic required to handle Bitcoin
///         deposits into the Portal contract.
///         The Bitcoin deposit has to be performed in two steps from the
///         perspective of the Portal contract.
///
///         In the first step, the P2(W)SH Bitcoin deposit transaction is
///         revealed to the tBTC bridge. This allows the tBTC bridge to mint the
///         token on Ethereum, with optimistic minting or periodic sweeping.
///         The ERC20 tBTC token is minted to the BitcoinDepositor contract
///         address - the one that revealed the deposit to tBTC bridge and the
///         one that is embedded in the P2(W)SH Bitcoin deposit script. This
///         step is implemented by the `initializeDeposit` function.
///
///         In the second step, the tBTC minted must be deposited to the Portal
///         contract using the Ethereum address of the real depositor that was
///         embedded in the P2(W)SH Bitcoin deposit script. This step is
///         implemented by the `finalizeDeposit` function.
///
///         Note that those two steps can not be done together as tBTC ERC20
///         token minting must happen between the two of them.
/// @dev The contract is supposed to be deployed behind a transparent
///      upgradeable proxy.
contract BitcoinDepositor is AbstractTBTCDepositor, Initializable {
    using SafeERC20 for IERC20;

    /// @notice Reflects the deposit state:
    ///         - Unknown deposit has not been initialized yet.
    ///         - Initialized deposit has been initialized with a call to
    ///           `initializeDeposit` function and is known to this contract.
    ///         - Finalized deposit led to tBTC ERC20 minting and was finalized
    ///           with a call to `finalizeDeposit` function that deposited tBTC
    ///           to the Portal contract.
    enum DepositState {
        Unknown,
        Initialized,
        Finalized
    }

    /// @notice Reference to the Mezo Portal contract.
    Portal public portal;

    /// @notice Reference to the tBTC ERC20 token contract.
    IERC20 public tbtcToken;

    /// @notice Holds the deposit state, keyed by the deposit key calculated for
    ///         the individual deposit during the call to `initializeDeposit`
    ///         function.
    mapping(uint256 => DepositState) public deposits;

    /// @notice Mezo mainnet governance address.
    address public constant GOVERNANCE =
        0x98D8899c3030741925BE630C710A98B57F397C7a;

    event DepositInitialized(
        uint256 indexed depositKey,
        address indexed depositOwner,
        uint256 depositLockPeriod
    );

    event DepositFinalized(
        uint256 indexed depositKey,
        uint256 initialAmount,
        uint256 tbtcAmount
    );

    event FeesMoved(address destination, uint256 amount);

    /// @notice Function reverts with this error if the deposit state is not as
    ///         expected. `initializeDeposit` can only be called for `Unknown`
    ///         deposits. `finalizeDeposit` can only be called for `Initialized`
    ///         deposits.
    error UnexpectedDepositState(
        DepositState actualState,
        DepositState expectedState
    );

    /// @notice `finalizeDeposit` reverts with this error if the `depositOwner`
    ///         and/or `depositLockPeriod` passed as the parameters are not
    ///         the same as passed earlier to the `initializeDeposit`.
    error UnexpectedExtraData(
        bytes32 actualExtraData,
        bytes32 expectedExtraData
    );

    /// @notice `moveFees` reverts with this error when caller is not the
    ///         governance.
    error NotGovernance();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with the appropriate external contract
    ///         addresses.
    /// @dev All addresses passed to the contract must not be 0x0.
    /// @param _bridge Address to the tBTC Bridge contract.
    /// @param _tbtcVault Address to the tBTC TBTCVault contract.
    /// @param _tbtcToken Address to the tBTC ERC20 token contract.
    /// @param _portal Address to the Mezo Portal contract.
    function initialize(
        address _bridge,
        address _tbtcVault,
        address _tbtcToken,
        address _portal
    ) external initializer {
        __AbstractTBTCDepositor_initialize(_bridge, _tbtcVault);

        require(_tbtcToken != address(0), "tBTC token address cannot be zero");
        tbtcToken = IERC20(_tbtcToken);

        require(
            _portal != address(0),
            "Portal contract address cannot be zero"
        );
        portal = Portal(_portal);
    }

    /// @notice Initializes the deposit process after the Bitcoin P2(W)SH deposit
    ///         transaction is performed. Reveals the deposit to tBTC bridge and
    ///         marks the deposit as initialized internally. Once tBTC minting
    ///         is completed, this call should be followed by a call to
    ///         `finalizeDeposit`. The P2(W)SH Bitcoin script depositing tokens
    ///         should have the following format:
    ///
    ///         <depositor-address> DROP
    ///         <depositor-extra-data> DROP
    ///         <blinding-factor> DROP
    ///         DUP HASH160 <signingGroupPubkeyHash> EQUAL
    ///         IF
    ///           CHECKSIG
    ///         ELSE
    ///           DUP HASH160 <refundPubkeyHash> EQUALVERIFY
    ///           <locktime> CHECKLOCKTIMEVERIFY DROP
    ///           CHECKSIG
    ///         ENDIF
    ///
    ///         Where:
    ///
    ///         <depositor-address> 20-byte Ethereum address of the
    ///         BitcoinDepositor contract.
    ///
    ///         <depositor-extra-data> 32-byte keccak256 hash of abi-encoded
    ///         deposit owner address and deposit lock time in seconds,
    ///         normalized to weeks. If there should be no lock applied to the
    ///         deposit, the value should be 0.
    ///
    ///         <blinding-factor> 8-byte deposit blinding factor, as used in the
    ///         tBTC bridge
    ///
    ///         <signingGroupPubkeyHash> The compressed Bitcoin public key (33
    ///         bytes and 02 or 03 prefix) of the deposit's wallet hashed in the
    ///         HASH160 Bitcoin opcode style. This must point to the active tBTC
    ///         bridge wallet.
    ///
    ///         <refundPubkeyHash> The compressed Bitcoin public key (33 bytes
    ///         and 02 or 03 prefix) that can be used to make the deposit refund
    ///         after the tBTC bridge refund locktime passed. Hashed in the
    ///         HASH160 Bitcoin opcode style. This is needed only as a security
    ///         measure protecting the user in case tBTC bridge completely stops
    ///         functioning.
    ///
    ///         <locktime> The Bitcoin script refund locktime (4-byte LE),
    ///         according to tBTC bridge rules. __This is NOT the same locktime
    ///         as the one used for the Mezo deposit.__
    ///
    ///         Please consult tBTC Bridge.revealDepositWithExtraData function
    ///         documentation for more information.
    /// @dev Requirements:
    ///      - The deposit owner and depositLockPeriod must be represented in
    ///        the Bitcoin deposit P2(W)SH script in the <depositor-extra-data>
    ///        value. If the value in the Bitcoin script and the values passed
    ///        as the parameters do not match, the function will revert.
    ///      - The function can be called only one time for the given P2(W)SH
    ///        Bitcoin deposit transaction.
    ///      - All the requirements of tBTC Bridge.revealDepositWithExtraData
    ///        must be met.
    /// @param fundingTx Bitcoin funding transaction data, see `BitcoinTx.Info`
    /// @param reveal Deposit reveal data, see `RevealInfo struct.
    /// @param depositOwner The address of the account that should own the
    ///        deposit.
    /// @param depositLockPeriod The deposit lock period in seconds, normalized
    ///        to weeks. 0 if there should be no lock time.
    function initializeDeposit(
        IBridgeTypes.BitcoinTxInfo calldata fundingTx,
        IBridgeTypes.DepositRevealInfo calldata reveal,
        address depositOwner,
        uint32 depositLockPeriod
    ) external {
        require(depositOwner != address(0), "Deposit owner must not be 0x0");

        (uint256 depositKey, ) = _initializeDeposit(
            fundingTx,
            reveal,
            keccak256(abi.encode(depositOwner, depositLockPeriod))
        );

        if (deposits[depositKey] != DepositState.Unknown) {
            revert UnexpectedDepositState(
                deposits[depositKey],
                DepositState.Unknown
            );
        }

        deposits[depositKey] = DepositState.Initialized;

        emit DepositInitialized(depositKey, depositOwner, depositLockPeriod);
    }

    /// @notice Finalizes the deposit process by depositing tBTC ERC20 token to
    ///         the Portal contract. This function should be called after the
    ///         deposit was initialized with a call to `initializeDeposit`
    ///         function and after tBTC ERC20 token was minted by the bridge to
    ///         the BitcoinDepositor contract.
    ///         Please note several hours may pass between `initializeDeposit`
    ///         and `finalizeDeposit`.
    /// @dev Requirements:
    ///      - `initializeDeposit` was called for the given deposit before.
    ///      - tBTC ERC20 was minted by tBTC Bridge to this contract.
    ///      - The function was not called for the given deposit before.
    ///      - The same `depositOwner` and `depositLockPeriod` were passed when
    ///        initiating the deposit.
    /// @param depositKey The deposit key, as emitted in the `DepositInititiated`
    ///        event emitted by the `initializeDeposit` function for the deposit.
    /// @param depositOwner The address of the account that should own the
    ///        deposit. This must be the same value as passed to
    ///        `initializeDeposit` for the deposit.
    /// @param depositLockPeriod The deposit lock period in seconds, normalized
    ///        to weeks. 0 if there should be no lock time. This must be the
    ///        same value as passed to `initializeDeposit` for the deposit.
    function finalizeDeposit(
        uint256 depositKey,
        address depositOwner,
        uint32 depositLockPeriod
    ) external {
        if (deposits[depositKey] != DepositState.Initialized) {
            revert UnexpectedDepositState(
                deposits[depositKey],
                DepositState.Initialized
            );
        }

        deposits[depositKey] = DepositState.Finalized;

        (
            uint256 initialDepositAmount,
            uint256 tbtcAmount,
            bytes32 expectedExtraData
        ) = _finalizeDeposit(depositKey);

        bytes32 actualExtraData = keccak256(
            abi.encode(depositOwner, depositLockPeriod)
        );
        if (actualExtraData != expectedExtraData) {
            revert UnexpectedExtraData(actualExtraData, expectedExtraData);
        }

        tbtcToken.safeIncreaseAllowance(address(portal), tbtcAmount);
        portal.depositFor(
            depositOwner,
            address(tbtcToken),
            uint96(tbtcAmount),
            depositLockPeriod
        );

        emit DepositFinalized(depositKey, initialDepositAmount, tbtcAmount);
    }

    /// @notice Moves collected fees to Mezo mainnet bridge contract.
    /// @dev Note that the BitcoinDepositor contract is no longer used, hence
    ///      the entire balance can be moved without worrying about initialize/
    ///      finalize deposit timing.
    function moveFees(address destination) external {
        if (msg.sender != GOVERNANCE) {
            revert NotGovernance();
        }

        uint256 balance = tbtcToken.balanceOf(address(this));
        emit FeesMoved(destination, balance);
        tbtcToken.safeTransfer(destination, balance);
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @notice ERC20Bridge abstract contract exposes the capability of bridging
///         ERC20 tokens from Ethereum to the Mezo chain.
/// @dev The contract is supposed to be extended by the MezoBridge contract.
abstract contract ERC20Bridge is
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    /// @notice Maximum number of distinct ERC20 tokens that can be enabled
    ///         in the bridge.
    /// @dev The reason for this limit is to not downgrade the bridge
    ///      performance on the Mezo chain side too much.
    uint256 public constant MAX_ERC20_TOKENS = 20;

    /// @notice Count of ERC20 tokens enabled in the bridge.
    uint256 public ERC20TokensCount;

    /// @notice Mapping of ERC20 tokens to their minimum bridgeable amounts,
    ///         in the token precision.
    mapping(address => uint256) public ERC20Tokens;

    // Reserved storage space that allows adding more variables without affecting
    // the storage layout of the child contracts. The convention from OpenZeppelin
    // suggests the storage space should add up to 50 slots. If more variables are
    // added in the upcoming versions one need to reduce the array size accordingly.
    // See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    // slither-disable-next-line unused-state
    uint256[48] private __gap;

    event ERC20TokenEnabled(address indexed ERC20Token, uint256 minERC20Amount);

    event ERC20TokenDisabled(address indexed ERC20Token);

    event MinERC20AmountUpdated(
        address indexed ERC20Token,
        uint256 newMinERC20Amount
    );

    error MinERC20AmountIsZero();

    error ERC20TokenIsZeroAddress();

    error ERC20TokenAlreadyEnabled();

    error MaxERC20TokensReached();

    error ERC20TokenNotEnabled();

    error ERC20RecipientIsZeroAddress();

    error AmountBelowMinERC20Amount();

    /// @notice Bridges the `amount` of the `token` to the `recipient` address on Mezo.
    /// @param recipient Recipient of the bridged token.
    /// @param token Address of the bridged token.
    /// @param amount Amount of the bridged token.
    function _bridge(
        address recipient,
        address token,
        uint256 amount
    ) internal virtual;

    /// @notice Initializes the contract.
    function __ERC20Bridge_initialize() internal {
        // Note that initializers of OZ upgradeable contracts are not linearized
        // by the compiler like constructors. Therefore, if __ERC20Bridge_initialize
        // is called from within a child contract's initializer that also calls
        // __Ownable_init and __ReentrancyGuard_init somewhere else in the
        // inheritance chain, the Ownable and ReentrancyGuard initializers will
        // be called twice (it's actually the case for the MezoBridge child contract).
        // Although this is not a problem with currently used OZ version where
        // __Ownable_init and __ReentrancyGuard_init are idempotent
        // (as long as __Ownable_init is called with the same argument),
        // it's worth noting this caveat for future.
        //
        // For reference, see the following OZ documentation:
        // https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/v5.0.2/docs/modules/ROOT/pages/upgradeable.adoc#multiple-inheritance
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        // Just in case.
        ERC20TokensCount = 0;
    }

    /// @notice Enables bridging support for the given ERC20 token, with the given
    ///         minimum bridgeable amount.
    /// @param ERC20Token Address of the ERC20 token to be enabled.
    /// @param minERC20Amount Minimum amount of the ERC20 token that can be bridged,
    ///                       in the token precision.
    /// @dev Requirements:
    ///      - Access restricted with the `onlyOwner` modifier,
    ///      - The ERC20 token must not be the zero address,
    ///      - The minimum ERC20 amount must be positive,
    ///      - The ERC20 token must not be already enabled,
    ///      - The maximum number of ERC20 tokens must not be reached.
    ///
    /// @dev BEWARE!!! BEFORE ENABLING AN ERC20 TOKEN USING THIS FUNCTION,
    ///      MAKE SURE THE CORRECT MAPPING FOR THIS TOKEN EXISTS ON THE
    ///      MEZO CHAIN. OTHERWISE, THE BRIDGE WILL IGNORE THE BRIDGING REQUESTS
    ///      FOR THIS TOKEN. THE AMOUNT BRIDGED WILL BE LOCKED ON THIS
    ///      CONTRACT AND NO TOKENS WILL BE ISSUED ON THE MEZO CHAIN.
    function enableERC20Token(
        address ERC20Token,
        uint256 minERC20Amount
    ) external onlyOwner {
        if (ERC20Token == address(0)) {
            revert ERC20TokenIsZeroAddress();
        }

        if (minERC20Amount == 0) {
            revert MinERC20AmountIsZero();
        }

        if (ERC20Tokens[ERC20Token] != 0) {
            revert ERC20TokenAlreadyEnabled();
        }

        if (ERC20TokensCount >= MAX_ERC20_TOKENS) {
            revert MaxERC20TokensReached();
        }

        ERC20TokensCount++;
        ERC20Tokens[ERC20Token] = minERC20Amount;

        emit ERC20TokenEnabled(ERC20Token, minERC20Amount);
    }

    /// @notice Disabled bridging support for the given ERC20 token.
    /// @param ERC20Token Address of the ERC20 token to be disabled.
    /// @dev Requirements:
    ///      - Access restricted with the `onlyOwner` modifier,
    ///      - The ERC20 token must be enabled.
    function disableERC20Token(address ERC20Token) external onlyOwner {
        // enableERC20Token does not allow ERC20Token to be 0x0 address so, it's
        // enough to check if the token is enabled, without checking if it's 0x0.
        if (ERC20Tokens[ERC20Token] == 0) {
            revert ERC20TokenNotEnabled();
        }

        ERC20TokensCount--;
        delete ERC20Tokens[ERC20Token];

        emit ERC20TokenDisabled(ERC20Token);
    }

    /// @notice Updates the minimum ERC20 amount allowed to be bridged using
    ///         `bridgeERC20`.
    /// @param newMinERC20Amount New minimum ERC20 amount (in the token precision).
    ///                          Must be positive.
    /// @dev Requirements:
    ///      - Access restricted with the `onlyOwner` modifier,
    ///      - The ERC20 token must be enabled,
    ///      - The new minimum ERC20 amount must be positive.
    function updateMinERC20Amount(
        address ERC20Token,
        uint256 newMinERC20Amount
    ) external onlyOwner {
        // enableERC20Token does not allow ERC20Token to be 0x0 address so, it's
        // enough to check if the token is enabled, without checking if it's 0x0.
        if (ERC20Tokens[ERC20Token] == 0) {
            revert ERC20TokenNotEnabled();
        }

        if (newMinERC20Amount == 0) {
            revert MinERC20AmountIsZero();
        }

        ERC20Tokens[ERC20Token] = newMinERC20Amount;

        emit MinERC20AmountUpdated(ERC20Token, newMinERC20Amount);
    }

    /// @notice Bridges the `amount` of the `ERC20Token` to the `recipient` address on Mezo.
    /// @param ERC20Token Address of the bridged ERC20 token.
    /// @param amount Amount of the bridged ERC20 token.
    /// @param recipient Recipient of the bridged ERC20 token on Mezo.
    /// @dev Requirements:
    ///      - The ERC20 token must be enabled,
    ///      - The recipient address must not be the zero address,
    ///      - The amount must be greater than or equal to the minimum ERC20 amount,
    ///      - The caller must have allowed the contract to transfer the `amount` of the `ERC20Token`.
    function bridgeERC20(
        address ERC20Token,
        uint256 amount,
        address recipient
    ) external nonReentrant {
        // enableERC20Token does not allow ERC20Token to be 0x0 address so, it's
        // enough to check if the token is enabled, without checking if it's 0x0.
        uint256 minERC20Amount = ERC20Tokens[ERC20Token];
        if (minERC20Amount == 0) {
            revert ERC20TokenNotEnabled();
        }

        if (recipient == address(0)) {
            revert ERC20RecipientIsZeroAddress();
        }

        if (amount < minERC20Amount) {
            revert AmountBelowMinERC20Amount();
        }

        _bridge(recipient, ERC20Token, amount);

        IERC20(ERC20Token).safeTransferFrom(msg.sender, address(this), amount);
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

/// @notice An interface to be optionally implemented by ERC20 tokens to retrieve
///         the decimals places of the token. We need this interface because to
///         properly calculate amounts when 2 tokens are involved we need to know
///         their decimals places.
///         As decimals() is optional in the ERC20 standard, additional interface
///         is needed to retrieve the decimals places of the token.
///         Portal contract assumes that only tokens supporting this interface
///         are accepted as supported tokens or receipt tokens.
interface IERC20WithDecimals {
    /// @notice Returns the decimals places of the token
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

/// @notice An interface to be optionally implemented by ERC20 tokens to enable
///         gasless approvals.
interface IERC20WithPermit {
    /// @notice EIP2612 approval made with secp256k1 signature.
    ///         Users can authorize a transfer of their tokens with a signature
    ///         conforming EIP712 standard, rather than an on-chain transaction
    ///         from their address. Anyone can submit this signature on the
    ///         user's behalf by calling the permit function, paying gas fees,
    ///         and possibly performing other actions in the same transaction.
    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

/// @notice IReceiptToken is an interface that should be implemented by ERC20
///         receipt tokens used in the Portal contract.
interface IReceiptToken {
    /// @notice Mints `amount` receipt tokens and transfers them to the `to`
    ///         address.
    function mintReceipt(address to, uint256 amount) external;

    /// @notice Burns `amount` of receipt tokens owned by `msg.sender`.
    function burnReceipt(uint256 amount) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

/// @notice An interface that should be implemented by contracts supporting
///         `approveAndCall`/`receiveApproval` pattern.
interface IReceiveApproval {
    /// @notice Receives approval to spend tokens. Called as a result of
    ///         `approveAndCall` call on the token.
    function receiveApproval(
        address from,
        uint256 amount,
        address token,
        bytes calldata extraData
    ) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

/// @dev USDT token ignores ERC20 spec and returns no bool from the approve
///      function.
// slither-disable-start erc20-interface
interface IUSDT {
    function approve(address spender, uint256 value) external;
}
// slither-disable-end erc20-interface

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {BTCUtils} from "@keep-network/bitcoin-spv-sol/contracts/BTCUtils.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {BitcoinBridge} from "./BitcoinBridge.sol";
import {ERC20Bridge} from "./ERC20Bridge.sol";

/// @notice MezoBridge contract allows bridging Bitcoin (using tBTC) and other
///         ERC20 tokens from Ethereum to the Mezo chain.
/// @dev The contract inherits specific bridging capabilities from BitcoinBridge
///      and ERC20Bridge abstract contracts.
/// @dev The contract is supposed to be deployed behind a transparent
///      upgradeable proxy.
contract MezoBridge is BitcoinBridge, ERC20Bridge {
    using BTCUtils for bytes;
    using MessageHashUtils for bytes32;
    using ECDSA for bytes32;

    /// @notice Holds identifiers of chains supported by the bridge out action.
    /// @dev Those ARE NOT official EIP155 chain IDs. They are internal IDs used within the Mezo bridge.
    enum Chain {
        ETHEREUM,
        BITCOIN
    }

    /// @notice Holds the details of an unlocked assets entry.
    /// @dev This struct is not stored so packing of variables doesn't occur
    ///      and ordering of fields is not important.
    struct AssetsUnlocked {
        /// @notice The unlock sequence number of the AssetsUnlocked entry.
        /// @dev The sequence number is a cross-chain unique identifier for the
        ///      AssetsUnlocked entry and can be attributed to a unique token burn
        ///      action on the Mezo chain.
        /// @dev Do not confuse it with the `sequenceNumber` used within AssetsLocked events
        ///      and the corresponding `sequence` variable defined on the contract level.
        ///      The `unlock*` prefix is here to emphasize the difference.
        uint256 unlockSequenceNumber;
        /// @notice Recipient of the bridged out token.
        /// @dev Interpretation depends on the value of the `chain` parameter:
        ///      - For `Chain.ETHEREUM`, the recipient is interpreted as a regular 20-byte Ethereum address.
        ///      - For `Chain.BITCOIN`, the recipient is interpreted as a variable-length
        ///        standard-type Bitcoin script supported by tBTC, i.e. P2PKH, P2WPKH, P2SH or P2WSH.
        bytes recipient;
        /// @notice The address of the bridged out token.
        /// @dev Valid values are:
        ///      - For `Chain.ETHEREUM`, the `token` MUST be either `BitcoinBridge.tbtcToken` address
        ///        or one of the `ERC20Bridge.ERC20Tokens` addresses.
        ///      - For `Chain.BITCOIN`, the `token` MUST be only `BitcoinBridge.tbtcToken` address.
        address token;
        /// @notice Amount to be bridged out.
        /// @dev The amount MUST be given in the precision of the `token`.
        uint256 amount;
        /// @notice The chain bridged out assets are supposed to be unlocked on.
        /// @dev The value MUST be either `Chain.ETHEREUM` or `Chain.BITCOIN`.
        uint8 chain;
    }

    /// @notice Size in bytes of a single ECDSA signature.
    uint256 public constant SIGNATURE_BYTE_SIZE = 65;

    /// @notice Holds the count of all bridging requests made so far. Includes
    ///         both Bitcoin and ERC20 bridging requests. It is incremented every
    ///         time a new bridging request is made. Its value is used to assign
    ///         sequence numbers to these requests which help to keep track of them.
    uint256 public sequence;

    /// @notice Holds the count of all bridge validators.
    /// @dev This value must be updated in concert with the bridgeValidators mapping.
    uint256 public bridgeValidatorsCount;

    /// @notice Holds the address of all bridge validators.
    /// @dev Maps address of a bridge validator to true.
    /// @dev This mapping must be updated in concert with the bridgeValidatorsCount variable.
    mapping(address => bool) public bridgeValidators;

    /// @notice Holds pending AssetsUnlocked entries along with the number of bridge validator
    ///         attestations received so far.
    /// @dev Maps keccak256(abi.encode(AssetsUnlocked)) to the number of attestations.
    /// @dev Once the value exceeds attestationThreshold() and AssetsUnlocked is confirmed,
    ///      the given AssetsUnlocked entry SHOULD be removed from this mapping and
    ///      its unlockSequenceNumber MUST be written to the confirmedUnlocks mapping.
    mapping(bytes32 => uint256) public pendingAttestations;

    /// @notice Maps a `unlockSequenceNumber` and validator to whether or not a
    ///         validator has attested to that `unlockSequenceNumber`.
    /// @dev The key is keccak256(abi.encode(unlockSequenceNumber, msg.sender)).
    /// @dev This makes it so that validators cannot attest to the same
    ///      sequence number multiple times.
    mapping(bytes32 => bool) public pendingAttestationsByValidator;

    /// @notice Holds unlock sequence numbers of AssetsUnlocked entries confirmed by
    ///         at least an attestationThreshold() number of bridge validators.
    /// @dev Maps unlockSequenceNumber of an AssetsUnlocked entry to true.
    /// @dev The goal of this mapping is to prevent replaying the unlock (and withdrawal)
    ///      action for the same unlock sequence number that represents a unique token burn
    ///      action on the Mezo chain. That said, attestBridgeOut and attestBridgeOutWithSignatures
    ///      methods MUST always check this mapping before accepting a new attestation.
    mapping(uint256 => bool) public confirmedUnlocks;

    event AssetsLocked(
        uint256 indexed sequenceNumber,
        address indexed recipient,
        address indexed token,
        uint256 amount
    );

    event AssetsUnlockAttested(
        address indexed validator,
        uint256 indexed unlockSequenceNumber,
        bytes recipient,
        address token,
        uint256 amount,
        uint8 chain
    );

    event AssetsUnlockConfirmed(
        uint256 indexed unlockSequenceNumber,
        bytes indexed recipient,
        address indexed token,
        uint256 amount,
        uint8 chain
    );

    error AlreadyConfirmedUnlock(uint256 unlockSequenceNumber);
    error InvalidAmount(uint256 amount);
    error InvalidBitcoinRecipient();
    error InvalidChain(uint8 chain);
    error InvalidEthereumRecipient();
    error InvalidSignaturesCount(uint256 signaturesCount);
    error InvalidToken(address token);
    error InvalidUnlockSequenceNumber(uint256 unlockSequenceNumber);
    error MalformedSignaturesVector();
    error NotBridgeValidator(address signer);
    error UnsortedSigners();
    error ValidatorAlreadyAttested(
        address validator,
        uint256 unlockSequenceNumber
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract.
    /// @dev All addresses passed to the contract must not be 0x0.
    /// @param _tbtcBridge Address to the tBTC Bridge contract.
    /// @param _tbtcVault Address to the tBTC TBTCVault contract.
    /// @param _tbtcToken Address to the tBTC ERC20 token contract.
    /// @param _initialSequence Initial sequence number. Normally, it should be zero.
    ///        A non-zero value can be set when migrating from an old bridge contract,
    ///        to keep continuity in the sequence numbers on Mezo.
    function initialize(
        address _tbtcBridge,
        address _tbtcVault,
        address _tbtcToken,
        uint256 _initialSequence
    ) external initializer {
        __BitcoinBridge_initialize(_tbtcBridge, _tbtcVault, _tbtcToken);
        __ERC20Bridge_initialize();

        //slither-disable-next-line events-maths
        sequence = _initialSequence;
    }

    /// @notice Bridges the `amount` of the `token` to the `recipient` address on Mezo.
    /// @param recipient Recipient of the bridged token.
    /// @param token Address of the bridged token.
    /// @param amount Amount of the bridged token.
    /// @dev Increases the sequence number and emits the AssetsLocked event.
    ///      The AssetsLocked event is a sign for Mezo validators to process
    ///      the bridging request.
    function _bridge(
        address recipient,
        address token,
        uint256 amount
    ) internal override(BitcoinBridge, ERC20Bridge) {
        emit AssetsLocked(++sequence, recipient, token, amount);
    }

    /// @notice Allows a validator to attest a bridge out action. If there are
    ///         a super-majority (2/3 + 1) of bridge validators, the funds are withdrawn.
    /// @param entry The AssetsUnlocked entry holding the details of the bridge out action.
    /// @dev Requirements:
    ///      - The caller MUST be a bridge validator (see bridgeValidators).
    ///      - The entry MUST be valid. See requirements of the `_validateAssetsUnlocked` function for details.
    ///      - The validator MUST NOT have already attested to this bridge out action (unlockSequenceNumber).
    function attestBridgeOut(AssetsUnlocked calldata entry) external {
        if (!bridgeValidators[msg.sender]) {
            revert NotBridgeValidator(msg.sender);
        }

        _validateAssetsUnlocked(entry);

        bytes32 pendingAttestationsByValidatorKey = keccak256(
            abi.encode(entry.unlockSequenceNumber, msg.sender)
        );
        if (pendingAttestationsByValidator[pendingAttestationsByValidatorKey]) {
            revert ValidatorAlreadyAttested(
                msg.sender,
                entry.unlockSequenceNumber
            );
        }

        bytes32 attestationKey = keccak256(abi.encode(entry));
        pendingAttestations[attestationKey]++;
        pendingAttestationsByValidator[
            pendingAttestationsByValidatorKey
        ] = true;

        emit AssetsUnlockAttested(
            msg.sender,
            entry.unlockSequenceNumber,
            entry.recipient,
            entry.token,
            entry.amount,
            entry.chain
        );

        if (pendingAttestations[attestationKey] < attestationThreshold()) {
            return;
        }

        emit AssetsUnlockConfirmed(
            entry.unlockSequenceNumber,
            entry.recipient,
            entry.token,
            entry.amount,
            entry.chain
        );

        confirmedUnlocks[entry.unlockSequenceNumber] = true;
        delete pendingAttestations[attestationKey];

        _withdraw(entry);
    }

    /// @notice Attests a bridge out action with a set of signatures issued by a super-majority (2/3 + 1) of bridge validators.
    /// @param entry The AssetsUnlocked entry holding the details of the bridge out action.
    /// @param signatures Concatenation of 65-byte signatures (EIP-191 personal-sign) issued by bridge validators attesting
    ///        the bridge out action.
    /// @dev Requirements:
    ///      - The entry MUST be valid. See requirements of the `_validateAssetsUnlocked` function for details.
    ///      - The signatures vector MUST be properly formed (i.e. divisible by 65 bytes).
    ///      - The number of signatures MUST be equal to the attestation threshold (see `attestationThreshold` function).
    ///      - Each signature MUST be made over a digest built as `keccak256("\x19Ethereum Signed Message:\n32" | keccak256(abi.encode(block.chainid, entry)))`.
    ///      - Each signature MUST be made by a bridge validator.
    ///      - The signatures vector MUST be sorted by signer addresses in ascending order, without duplicates.
    ///        For example, assuming signatures [0xAA, 0xBB, 0xCC] were produced by signers [0x22, 0x11, 0x33] respectively,
    ///        the signatures vector MUST be built as 0xBBAACC.
    function attestBridgeOutWithSignatures(
        AssetsUnlocked calldata entry,
        bytes calldata signatures
    ) external {
        _validateAssetsUnlocked(entry);

        if (signatures.length % SIGNATURE_BYTE_SIZE != 0) {
            revert MalformedSignaturesVector();
        }

        uint256 signaturesCount = signatures.length / SIGNATURE_BYTE_SIZE;

        // Require a strict number of signatures equal to the attestation threshold.
        // This simplifies the implementation of this method and is more gas efficient.
        if (signaturesCount != attestationThreshold()) {
            revert InvalidSignaturesCount(signaturesCount);
        }

        // Expect the following digest to be signed by the bridge validators:
        // keccak256("\x19Ethereum Signed Message:\n32" | keccak256(abi.encode(block.chainid, entry)))
        // Include chain ID to prevent replay attacks using the same entry signed for another chain.
        bytes32 digest = keccak256(abi.encode(block.chainid, entry))
            .toEthSignedMessageHash();

        bytes memory signature;
        address previousSigner = address(0);

        for (uint256 i = 0; i < signaturesCount; i++) {
            signature = signatures[SIGNATURE_BYTE_SIZE * i:SIGNATURE_BYTE_SIZE *
                (i + 1)];

            // recover reverts in case of any troubles.
            address signer = digest.recover(signature);

            if (!bridgeValidators[signer]) {
                revert NotBridgeValidator(signer);
            }

            // Duplicate signatures are not allowed as each validator can only attest once.
            // Enforce this requirement by making sure the numerical values of the signer addresses
            // extracted from the signatures vector are strictly increasing (i.e. are sorted in ascending
            // order without duplicates).
            bool sorted = uint160(signer) > uint160(previousSigner);
            if (!sorted) {
                revert UnsortedSigners();
            }

            previousSigner = signer;
        }

        // At this point, we know that the number of signatures is equal to the attestation threshold
        // and all signatures are valid. We can mark the entry as confirmed and execute the withdrawal
        // step.

        emit AssetsUnlockConfirmed(
            entry.unlockSequenceNumber,
            entry.recipient,
            entry.token,
            entry.amount,
            entry.chain
        );

        confirmedUnlocks[entry.unlockSequenceNumber] = true;

        _withdraw(entry);
    }

    /// @return The number of bridge validator attestations required to confirm an
    ///         AssetsUnlocked entry and finalize its withdrawal.
    /// @dev It is calculated as 2/3 of the total number of bridge
    ///      validators (bridgeValidatorsCount) plus 1.
    function attestationThreshold() public view returns (uint256) {
        return ((2 * bridgeValidatorsCount) / 3) + 1;
    }

    /// @notice Validates the given AssetsUnlocked entry.
    /// @dev The attestBridgeOut and attestBridgeOutWithSignatures functions
    ///      MUST always call this function before accepting a new attestation.
    /// @dev Requirements:
    ///      - The entry.unlockSequenceNumber MUST be positive.
    ///      - The entry.amount MUST be positive.
    ///      - The entry.chain MUST be either `Chain.ETHEREUM` or `Chain.BITCOIN`.
    ///      - The entry.recipient MUST be valid in the context of the entry.chain:
    ///        - For `Chain.ETHEREUM` chain, the recipient MUST be a 20-byte Ethereum address.
    ///        - For `Chain.BITCOIN` chain, the recipient MUST be a valid standard-type
    ///          Bitcoin script (P2PKH, P2WPKH, P2SH or P2WSH).
    ///      - The entry.token MUST be valid in the context of the entry.chain:
    ///        - For `Chain.ETHEREUM` chain, the token MUST be either TBTC or one of the supported ERC20 tokens.
    ///        - For `Chain.BITCOIN` chain, the token MUST be only TBTC.
    ///      - The entry MUST NOT be already confirmed.
    function _validateAssetsUnlocked(
        AssetsUnlocked memory entry
    ) internal view {
        // Ensure positive sequence number.
        if (entry.unlockSequenceNumber == 0) {
            revert InvalidUnlockSequenceNumber(entry.unlockSequenceNumber);
        }

        // Ensure positive amount.
        if (entry.amount == 0) {
            revert InvalidAmount(entry.amount);
        }

        // Cache tbtcToken to save gas
        address _tbtcToken = tbtcToken;

        // Ensure valid chain.
        if (entry.chain == uint8(Chain.ETHEREUM)) {
            // Ensure recipient is valid in the context of Ethereum chain.
            if (entry.recipient.length != 20) {
                revert InvalidEthereumRecipient();
            }

            // TODO: Consider adding a check to ensure recipient address is not 0x0.
            //       We can do it here or during the withdrawal step. Consider it
            //       while implementing the withdrawal step.

            // Ensure token is either TBTC or one of the supported ERC20 tokens.
            if (entry.token != _tbtcToken && ERC20Tokens[entry.token] == 0) {
                revert InvalidToken(entry.token);
            }
        } else if (entry.chain == uint8(Chain.BITCOIN)) {
            // Ensure recipient is valid in the context of Bitcoin chain.
            //
            // Use BTCUtils.extractHashAt to validate the Bitcoin output script.
            // This function extracts the payload properly only from standard output scripts,
            // so if it succeeds, we have a guarantee the recipient output script is proper.
            bytes memory recipientPayload = entry.recipient.extractHashAt(
                0,
                entry.recipient.length
            );
            if (recipientPayload.length == 0) {
                revert InvalidBitcoinRecipient();
            }

            // Ensure token is TBTC.
            if (entry.token != _tbtcToken) {
                revert InvalidToken(entry.token);
            }
        } else {
            revert InvalidChain(entry.chain);
        }

        // Ensure entry was not already confirmed.
        if (confirmedUnlocks[entry.unlockSequenceNumber]) {
            revert AlreadyConfirmedUnlock(entry.unlockSequenceNumber);
        }
    }

    // TODO: Document.
    function _withdraw(AssetsUnlocked memory entry) internal {
        // TODO: Implement as part of https://linear.app/thesis-co/issue/TET-1189/mezobridge-contract-assets-withdrawal
    }

    // TODO: Document.
    // slither-disable-start all
    function addBridgeValidators(
        address[] calldata validators
    ) external onlyOwner {
        // TODO: Implement as part of https://linear.app/thesis-co/issue/TET-1190/mezobridge-contract-bridge-validators-management.
        //       Modifying bridgeValidatorsCount just to suppress the slither warning.
        //       Revisit this during actual implementation.

        bridgeValidatorsCount += validators.length;
        for (uint256 i = 0; i < validators.length; i++) {
            bridgeValidators[validators[i]] = true;
        }
    }
    // slither-disable-end all

    // TODO: Document.
    // slither-disable-start all
    function removeBridgeValidators(
        address[] calldata validators
    ) external onlyOwner {
        // TODO: Implement as part of https://linear.app/thesis-co/issue/TET-1190/mezobridge-contract-bridge-validators-management.
        //       Modifying bridgeValidatorsCount just to suppress the slither warning.
        //       Revisit this during actual implementation.

        bridgeValidatorsCount -= validators.length;
        for (uint256 i = 0; i < validators.length; i++) {
            delete bridgeValidators[validators[i]];
        }
    }
    // slither-disable-end all
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IReceiveApproval.sol";
import "./interfaces/IReceiptToken.sol";
import "./interfaces/IERC20WithPermit.sol";
import "./interfaces/IERC20WithDecimals.sol";
import "./interfaces/IUSDT.sol";
import "./MezoBridge.sol";

contract Portal is Ownable2StepUpgradeable, IReceiveApproval {
    using SafeERC20 for IERC20;

    /// @notice Supported token ability defines what can be done with
    ///         a given token. Some tokens can be deposited but can not be locked.
    enum TokenAbility {
        None,
        Deposit,
        DepositAndLock
    }

    /// @notice Represents the to-tBTC migration state of a deposit. Note that
    ///         to-tBTC migration is only available for selected assets, as set
    ///         by the governance.
    enum TbtcMigrationState {
        NotRequested,
        Requested,
        InProgress,
        Completed
    }

    /// @notice Supported token struct to pair a token address with its ability
    /// @dev This is an auxiliary struct used to initialize the contract with
    ///      the supported tokens and for governance to add new supported tokens.
    ///      This struct is not used in the storage.
    struct SupportedToken {
        address token;
        TokenAbility tokenAbility;
    }

    /// @notice Groups depositor address to their deposit ID to pass in an array
    ///         to trigger and complete the to-tBTC migration by the tBTC
    ///         migration treasury.
    /// @dev This is an auxiliary struct used as a parameter in to-tBTC
    ///      migration functions. This struct is not used in the storage.
    struct DepositToMigrate {
        address depositor;
        uint256 depositId;
    }

    /// @notice Groups depositor address to their deposit ID to pass in an array
    ///         to perform auto-bridging of deposits to the Mezo chain.
    /// @dev This is an auxiliary struct used as a parameter in
    ///      `autoBridgeDeposits`.
    struct DepositToAutoBridge {
        address depositor;
        uint256 depositId;
    }

    /// @notice DepositInfo keeps track of the deposit balance and unlock time.
    ///         Each deposit is tracked separately and associated with a specific
    ///         token. Some tokens can be deposited but can not be locked - in
    ///         that case the unlockAt is the block timestamp of when the deposit
    ///         was created. The same is true for tokens that can be locked but
    ///         the depositor decided not to lock them. Some deposits can mint
    ///         a receipt tokens against them: receiptMinted is the amount of
    ///         receipt tokens minted against a deposit, while feeOwed is the
    ///         fee owed by the deposit to Portal, and the lastFeeIntegral is
    ///         the last updated value of the fee integral.
    struct DepositInfo {
        uint96 balance;
        uint32 unlockAt;
        // The amount of the receipt token minted for the deposit. Zero if no
        // receipt token was minted.
        uint96 receiptMinted;
        // The fee owed if the receipt token was minted and the fee is non-zero.
        // Fee owed is calculated based on the receipt tokens minted and is stored
        // using receipt token decimals. The fee is collected when the deposit is
        // withdrawn, adjusted to the deposit token decimals.
        uint96 feeOwed;
        // The last value of the receipt token fee integral. Zero if no receipt
        // token was minted, if the fee is zero, or if the integral was not yet
        // calculated.
        uint88 lastFeeIntegral;
        // The state of tBTC migration. If the to-tBTC migration is not allowed
        // for the asset or if it was not requested by the depositor, the state
        // is NotRequested.
        TbtcMigrationState tbtcMigrationState;
        // Indication whether the deposit should opt-out from auto-bridging to
        // the Mezo chain. If set to true, it will not be possible to auto-
        // bridge the deposit.
        bool autoBridgingOptOut;
    }

    /// @notice Keeps information about to-tBTC migration status for the asset:
    ///         whether the migration is allowed and what is the total amount
    ///         of the asset being currently in-progress for the migration.
    struct TbtcMigrationInfo {
        // Indicates whether the migration to tBTC was enabled by the governance
        // for the asset.
        bool isAllowed;
        // The total amount that is currently migrated to tBTC. The value uses
        // the same number of decimals as the asset being migrated.
        uint96 totalMigrating;
    }

    /// @notice FeeInfo keeps track of the receipt token minting situation per
    ///         the supported deposit token.
    ///
    ///         The current fee rate for minting against deposits is
    ///         calculated separately for each token, and tracked as integral.
    ///
    ///         The fee rate has a single component: a governable base annual
    ///         fee, capped at 100%.
    ///
    ///         The annual fee is converted to a non-compounding fee per second,
    ///         R. This rate is then multiplied by time in seconds to get the
    ///         accumulated fee integral. The difference between the integral
    ///         in time T_1 and T_2 tracks how much fee is accrued per minted
    ///         token unit during that time. The minted amount A is multiplied
    ///         by R, and divided by a scalar constant to get the amount of fee
    ///         in the same units as A.
    struct FeeInfo {
        // XXX: not tracking total deposited - use token balance
        // someone could send token to the contract outside locked deposits

        // The amount of receipt tokens minted across all deposits for the given
        // deposit token.
        uint96 totalMinted;
        // The timestamp of the block of the last fee update.
        uint32 lastFeeUpdateAt;
        // The integral tracks how much fee is accrued over time.
        uint88 feeIntegral;
        // Fee per annum in percentage.
        uint8 annualFee;
        // Receipt token minting cap in percentage, per deposit.
        uint8 mintCap;
        // A token supporting the IReceiptToken interface and used as a receipt
        // token. Zero address if the given deposit token does not allow minting
        // receipt tokens.
        address receiptToken;
        // Counts fees collected across all withdrawn deposits for the given
        // deposit token. Fees are collected based on the receipt tokens earlier
        // minted and the annual fee.
        uint96 feeCollected;
    }

    /// @notice Mapping of the details of all the deposited funds:
    ///         depositor address -> token address -> deposit id -> DepositInfo
    mapping(address => mapping(address => mapping(uint256 => DepositInfo)))
        public deposits;

    /// @notice The number of deposits created. Includes the deposits that
    ///         were fully withdrawn. This is also the identifier of the most
    ///         recently created deposit.
    uint256 public depositCount;

    /// @notice List of tokens enabled for deposit or for deposit and lock.
    mapping(address => TokenAbility) public tokenAbility;

    /// @notice Minimum time a deposit can be locked.
    uint32 public minLockPeriod;

    /// @notice Maximum time a deposit can be locked.
    uint32 public maxLockPeriod;

    /// @notice Address of the liquidity treasury multisig.
    address public liquidityTreasury;

    /// @notice Mapping to store whether an asset is managed by the liquidity
    ///         treasury multisig.
    mapping(address => bool) public liquidityTreasuryManaged;

    /// @notice Mapping of depositable tokens to their receipt token fee
    ///         parameters.
    mapping(address => FeeInfo) public feeInfo;

    /// @notice Address of the tBTC token. Used for the to-tBTC migration of
    ///         deposited assets for which the migration was enabled by the
    ///         governance.
    address public tbtcToken;

    /// @notice Address of the tBTC migration treasury multisig. The tBTC
    ///         migration treasury is responsible for conducting the
    ///         to-tBTC migration of deposited assets for which the migration
    ///         was enabled by the governance.
    address public tbtcMigrationTreasury;

    /// @notice Mapping indicating whether the given asset can be migrated to
    ///         tBTC by the tBTC migration treasury and if so, what is the
    ///         global status of migrations. The key to the mapping is the
    ///         address of the asset being migrated.
    mapping(address => TbtcMigrationInfo) public tbtcMigrations;

    /// @notice Mezo bridge that can be used to bridge tBTC or other ERC20
    ///         tokens to the Mezo chain. Assets to be bridged must meet
    ///         criteria specified in the Mezo bridge: the token must be enabled
    ///         and the amount must be above the minimum value.
    MezoBridge public mezoBridge;

    /// @notice Address of the auto-bridge coordinator. This address is allowed
    ///         to perform auto-bridging of deposits to the Mezo chain.
    address public autoBridgeCoordinator;

    /// @notice Deposit global unlock timestamp beyond which all deposits are
    ///         withdrawable.
    uint32 public depositGlobalUnlockAt;

    /// @notice Address of the WBTC token. This address is checked during
    ///         auto-bridging to Mezo to prevent WBTC token deposits from being
    ///         auto-bridged.
    address public wbtcToken;

    //
    // The ReentrancyGuard fields copied from OpenZeppelin. We copy the code
    // instead of extending the contract to avoid problems with storage slot
    // conflicts.
    //

    // In the original `ReentrancyGuard` code from OpenZeppelin the values `1`
    // and `2` were used. Here we opted for `0` and `1` as this guarantees
    // the `_status` variable will be initialized as `NOT_ENTERED` by default.
    uint256 private constant NOT_ENTERED = 0;
    uint256 private constant ENTERED = 1;

    uint256 private _status;
    //
    // EOF ReentrancyGuard
    //

    /// @dev USDT token address. USDT does not respect approve interface of
    ///      ERC20 and requires special handling.
    address internal constant USDT_ADDRESS =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;

    event Deposited(
        address indexed depositor,
        address indexed token,
        uint256 indexed depositId,
        uint256 amount
    );

    event Withdrawn(
        address indexed depositor,
        address indexed token,
        uint256 indexed depositId,
        uint256 amount
    );

    event Locked(
        address indexed depositor,
        address indexed token,
        uint256 indexed depositId,
        uint32 unlockAt,
        uint32 lockPeriod
    );

    event SupportedTokenAdded(address indexed token, TokenAbility tokenAbility);

    event MaxLockPeriodUpdated(uint32 maxLockPeriod);

    event MinLockPeriodUpdated(uint32 minLockPeriod);

    /// @notice Event emitted when the liquidity treasury address is updated.
    event LiquidityTreasuryUpdated(
        address indexed previousLiquidityTreasury,
        address indexed newLiquidityTreasury
    );

    /// @notice Event emitted when an asset is withdrawn by the liquidity
    ///         treasury multisig.
    event WithdrawnByLiquidityTreasury(address indexed token, uint256 amount);

    /// @notice Event emitted when an asset is set/unset as a liquidity
    ///         treasury multisig managed asset.
    event LiquidityTreasuryManagedAssetUpdated(
        address indexed asset,
        bool isManaged
    );

    /// @notice Event emitted when the receipt parameters for a deposit token
    ///         are updated.
    event ReceiptParamsUpdated(
        address indexed token,
        uint8 annualFee,
        uint8 mintCap,
        address receiptToken
    );

    /// @notice Event emitted when a receipt token is minted for a deposit.
    event ReceiptMinted(
        address indexed depositor,
        address indexed token,
        uint256 indexed depositId,
        uint256 amount
    );

    /// @notice Event emitted when a receipt token is repaid for a deposit.
    event ReceiptRepaid(
        address indexed depositor,
        address indexed token,
        uint256 indexed depositId,
        uint256 amount
    );

    /// @notice Event emitted when a fee is collected for a deposit.
    event FeeCollected(
        address indexed depositor,
        address indexed token,
        uint256 indexed depositId,
        uint256 fee
    );

    /// @notice Event emitted when the tBTC token address used for the
    ///         to-tBTC migration was set by the governance.
    /// @dev This event can be emitted only one time.
    event TbtcTokenAddressSet(address tbtc);

    /// @notice Event emitted when the to-tBTC migration treasury address was
    ///         updated.
    event TbtcMigrationTreasuryUpdated(
        address indexed previousMigrationTreasury,
        address indexed newMigrationTreasury
    );

    /// @notice Event emitted when the eligibility for the to-tBTC migration
    ///         for the asset was updated.
    event TbtcMigrationAllowedUpdated(address indexed token, bool isAllowed);

    /// @notice Event emitted when the to-tBTC migration was requested for the
    ///         deposit.
    event TbtcMigrationRequested(
        address indexed depositor,
        address indexed token,
        uint256 indexed depositId
    );

    /// @notice Event emitted when the to-tBTC migration was started for the
    ///         deposit.
    event TbtcMigrationStarted(
        address indexed depositor,
        address indexed token,
        uint256 indexed depositId
    );

    /// @notice Event emitted when the tBTC migration treasury started to-tBTC
    ///         migration for a set of deposits withdrawing the given amount of
    ///         the token from the Portal contract.
    event WithdrawnForTbtcMigration(address indexed token, uint256 amount);

    /// @notice Event emitted when the to-tBTC migration was completed for the
    ///         deposit.
    event TbtcMigrationCompleted(
        address indexed depositor,
        address indexed token,
        uint256 indexed depositId
    );

    /// @notice Event emitted when the to-tBTC migration was completed for one
    ///         or multiple deposits and the Portal contract was funded with
    ///         tBTC coming from the migrated assets.
    /// @dev The `amount` in the event is the amount in tBTC, using tBTC token's
    ///      precision.
    event FundedFromTbtcMigration(uint256 amount);

    /// @notice Event emitted in similar circumstances as `Withdrawn` except
    ///         that it represents a to-tBTC migrated deposit where the
    ///         withdrawal is performed in tBTC and not in the original deposit
    ///         token.
    event WithdrawnTbtcMigrated(
        address indexed depositor,
        address indexed token,
        address tbtcToken,
        uint256 indexed depositId,
        uint256 amountInTbtc
    );

    /// @notice Event emitted in similar circumstances as `FeeCollected`
    ///         except that it represents a to-tBTC migrated deposit where the
    ///         fee is collected in tBTC and not in the original deposit token.
    event FeeCollectedTbtcMigrated(
        address indexed depositor,
        address indexed token,
        address tbtcToken,
        uint256 indexed depositId,
        uint256 feeInTbtc
    );

    /// @notice Event emitted when the address of the Mezo bridge is updated.
    event MezoBridgeUpdated(
        address indexed previousMezoBridge,
        address indexed newMezoBridge
    );

    /// @notice Event emitted when the address of the auto-bridge coordinator is
    ///         updated.
    event AutoBridgeCoordinatorUpdated(
        address indexed previousAutoBridgeCoordinator,
        address indexed newAutoBridgeCoordinator
    );

    /// @notice Event emitted when the deposit global unlock at timestamp is
    ///         updated.
    event DepositGlobalUnlockAtUpdated(
        uint32 previousDepositGlobalUnlockAt,
        uint32 newDepositGlobalUnlockAt
    );

    /// @notice Event emitted when a deposit auto-bridging opt-out is set.
    event DepositAutoBridgingOptOutSet(
        address indexed depositor,
        address indexed token,
        uint256 indexed depositId,
        bool optOut
    );

    /// @notice Event emitted when a deposit opting-out from auto-bridging is
    ///         skipped.
    event OptOutDepositAutoBridgingSkipped(
        address indexed depositor,
        address indexed token,
        uint256 indexed depositId
    );

    /// @notice Event emitted when a withdrawn deposit is skipped during
    ///         auto-bridging. This happens when the user withdrew the
    ///         deposit or if the deposit was already bridged.
    event WithdrawnDepositAutoBridgingSkipped(
        address indexed depositor,
        address indexed token,
        uint256 indexed depositId
    );

    /// @notice Event emitted when a deposit for which stBTC was minted and not
    ///         repaid is skipped during auto-bridging.
    event ReceiptMintedDepositAutoBridgingSkipped(
        address indexed depositor,
        address indexed token,
        uint256 indexed depositId
    );

    /// @notice Event emitted when a deposit for which to-tBTC migration
    ///         was requested is skipped during auto-bridging.
    event TbtcMigratingDepositAutoBridgingSkipped(
        address indexed depositor,
        address indexed token,
        uint256 indexed depositId
    );

    /// @notice Event emitted when a deposit is auto-bridged.
    event DepositAutoBridged(
        address indexed depositor,
        address indexed token,
        uint256 indexed depositId,
        uint256 amount
    );

    event DepositBridged(
        address indexed depositor,
        address indexed token,
        uint256 indexed depositId,
        uint256 amount
    );

    /// @notice Event emitted when the WBTC token address used for performing
    ///         checks during auto-bridging of deposits to Mezo was set.
    event WbtcTokenAddressSet(address wbtcToken);

    error IncorrectTokenAddress(address token);

    error IncorrectTokenAbility(TokenAbility ability);

    error IncorrectDepositor(address depositor);

    error IncorrectAmount(uint256 amount);

    error TokenNotSupported(address token);

    error TokenAlreadySupported(address token, TokenAbility tokenAbility);

    error InsufficientTokenAbility(address token, TokenAbility tokenAbility);

    error LockPeriodOutOfRange(uint32 lockPeriod);

    error IncorrectLockPeriod(uint256 lockPeriod);

    error LockPeriodTooShort(
        uint32 lockPeriod,
        uint32 newUnlockAt,
        uint32 existingUnlockAt
    );

    error DepositLocked(uint32 unlockAt);

    error DepositNotFound();

    /// @notice Error when the partial withdrawal amount is too high. Either it
    ///         equals the deposit amount (not a partial withdrawal) or it is
    ///         higher than the deposit amount.
    error PartialWithdrawalAmountTooHigh(uint256 depositAmount);

    /// @notice Error when the sender is not the liquidity treasury.
    error SenderNotLiquidityTreasury(address sender);

    /// @notice Error when the asset is not managed by the liquidity treasury.
    error AssetNotManagedByLiquidityTreasury(address asset);

    /// @notice Error when trying to withdraw without repaying the minted
    ///         receipt tokens back to Portal.
    error ReceiptNotRepaid(uint256 receiptMinted);

    /// @notice Error when the user tries to partially withdraw but the fee for
    ///         minting the receipt token is non-zero. In this case only a full
    ///         deposit withdrawal is possible.
    error ReceiptFeeOwed(uint256 feeOwed);

    /// @notice Error when the user tries to mint more than the mint limit
    ///         allows.
    error ReceiptMintLimitExceeded(
        uint256 mintLimit,
        uint96 currentlyMinted,
        uint256 feeOwed,
        uint256 amount
    );

    /// @notice Error when the user tries to repay more than the minted debt.
    error RepayAmountExceededDebt(uint96 mintedDebt, uint256 amount);

    /// @notice Error when the annual fee proposed exceeds 100%.
    error MaxAnnualFeeExceeded(uint8 annualFee);

    /// @notice Error when the mint cap proposed exceeds 100%.
    error MaxReceiptMintCapExceeded(uint8 mintCap);

    /// @notice Error when there is no receipt token set for the asset.
    error ReceiptMintingDisabled();

    /// @notice Error when the receipt token is already initialized.
    error ReceiptTokenAlreadyInitialized();

    /// @notice Error when the receipt token decimals are not 18.
    error IncorrectReceiptTokenDecimals(address receiptToken);

    /// @notice Error when token being accepted as deposit token does not
    ///         support decimals() function or the function is malfunctioning.
    error UnknownTokenDecimals(address token);

    /// @notice The given asset can be marked as eligible for tBTC migration if
    ///         it is not managed by the liquidity treasury. The given asset
    ///         can be managed by the liquidity treasury if it is not marked as
    ///         eligible for tBTC migration. The transaction reverts with this
    ///         error when the governance changes would conflict with this
    ///         limitation.
    error TbtcMigrationAndLiquidityManagementConflict();

    /// @notice Error when the governance tries to add tBTC as an asset eligible
    ///         for to-tBTC migration.
    error TbtcCanNotBeMigrated();

    /// @notice Error when the tBTC token address used for to-tBTC migrations
    ///         was already set by the governance.
    error TbtcTokenAddressAlreadySet();

    /// @notice Error when the tBTC token address used for to-tBTC migrations
    ///         was not set by the governance but there is an attempt to enable
    ///         to-tBTC migration for some asset.
    error TbtcTokenAddressNotSet();

    /// @notice Error when someone else but the tBTC migration treasury tried
    ///         to withdraw tokens for tBTC migration or to complete the
    ///         migration process.
    error SenderNotTbtcMigrationTreasury();

    /// @notice Error when the given to-tBTC transition state change is
    ///         requested from an unexpected state. For example, it is not
    ///         allowed to complete the migration of a deposit for which the
    ///         migration was not requested.
    error UnexpectedTbtcMigrationState(
        uint256 depositId,
        TbtcMigrationState currentState,
        TbtcMigrationState expectedState
    );

    /// @notice Error when the to-tBTC migration for the asset was not allowed
    ///         by the governance but the depositor tried to request a migration.
    error TbtcMigrationNotAllowed();

    /// @notice Error when the to-tBTC migration has been requested but not yet
    ///         completed and the depositor tries to withdraw the deposit.
    error TbtcMigrationNotCompleted();

    /// @notice Error when the to-tBTC migration was requested and the depositor
    ///         tries to partially withdraw the deposit.
    /// @dev The `Err` suffix is to distinguish this error from the
    ///      `TbtcMigrationRequested` event.
    error TbtcMigrationRequestedErr();

    /// @notice Error when incorrect Mezo bridge address is provided.
    error IncorrectMezoBridgeAddress(address mezoBridge);

    /// @notice Error when incorrect auto-bridge coordinator address was
    ///         provided.
    error IncorrectAutoBridgeCoordinatorAddress(address autoBridgeCoordinator);

    /// @notice Error when incorrect deposit global unlock at timestamp was
    ///         provided.
    error IncorrectDepositGlobalUnlockAt(uint32 depositGlobalUnlockAt);

    /// @notice Error when tokens cannot be approved for bridging to Mezo.
    error TokenApprovalFailure();

    /// @notice Error when the caller is not the auto-bridge coordinator.
    error CallerNotAutoBridgeCoordinator();

    /// @notice Error when auto-bridging of WBTC token has been requested.
    error WbtcAutoBridgingNotSupported();

    /// @notice Error when unauthorized reentrant call is made.
    error ReentrancyGuardReentrantCall();

    /// @notice Modifier for preventing reentrant calls to a function. The code
    ///         was copied with some modifications from
    ///         https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.3.0/contracts/utils/ReentrancyGuard.sol
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    modifier onlyAutoBridgeCoordinator() {
        if (msg.sender != autoBridgeCoordinator) {
            revert CallerNotAutoBridgeCoordinator();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract with the supported tokens and their
    ///         abilities.
    /// @dev We are using OpenZeppelin's initializer pattern to initialize
    ///      the contract. This function is called only once during the contract
    ///      deployment.
    /// @param supportedTokens List of supported tokens and their abilities
    function initialize(
        SupportedToken[] memory supportedTokens
    ) external initializer {
        __Ownable_init(msg.sender);

        minLockPeriod = 4 weeks;
        maxLockPeriod = 39 weeks;
        depositCount = 0;

        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i].token;
            TokenAbility ability = supportedTokens[i].tokenAbility;

            if (token == address(0)) {
                revert IncorrectTokenAddress(token);
            }

            tokenAbility[token] = ability;
        }
    }

    /// @notice Withdraws all deposited tokens.
    ///
    ///         Deposited lockable tokens can be withdrawn at any time if
    ///         there is no lock set on the deposit or the deposit's lock period
    ///         has passed or the global unlock timestamp has passed.
    ///         There is no way to withdraw locked deposit. Tokens that are not
    ///         lockable can be withdrawn at any time.
    ///
    ///         Deposits for which receipt tokens were minted and not fully
    ///         repaid can not be withdrawn even if the lock expired. Repaying
    ///         all receipt tokens is a must to withdraw the deposit. Upon
    ///         withdrawing a deposit for which the receipt tokens were minted,
    ///         the fee is collected based on the annual fee and the amount
    ///         of minted receipt tokens.
    ///
    ///         Deposits for which to-tBTC migration was requested but not yet
    ///         completed yet can not be withdrawn. The deposits for which the
    ///         to-tBTC migration was completed are withdrawn in tBTC.
    ///
    ///         This function withdraws all deposited tokens. For partial
    ///         withdrawals, use `withdrawPartially`.
    /// @param token deposited token address
    /// @param depositId id of the deposit
    function withdraw(address token, uint256 depositId) external {
        TokenAbility ability = tokenAbility[token];

        if (ability == TokenAbility.None) {
            revert TokenNotSupported(token);
        }

        DepositInfo storage selectedDeposit = deposits[msg.sender][token][
            depositId
        ];

        if (
            selectedDeposit.tbtcMigrationState ==
            TbtcMigrationState.Requested ||
            selectedDeposit.tbtcMigrationState == TbtcMigrationState.InProgress
        ) {
            revert TbtcMigrationNotCompleted();
        }

        if (
            ability == TokenAbility.DepositAndLock &&
            // solhint-disable-next-line not-rely-on-time
            block.timestamp < selectedDeposit.unlockAt &&
            (depositGlobalUnlockAt == 0 ||
                // solhint-disable-next-line not-rely-on-time
                block.timestamp < depositGlobalUnlockAt)
        ) {
            revert DepositLocked(selectedDeposit.unlockAt);
        }

        if (selectedDeposit.receiptMinted > 0) {
            revert ReceiptNotRepaid(selectedDeposit.receiptMinted);
        }

        uint96 depositedAmount = selectedDeposit.balance;

        if (depositedAmount == 0) {
            revert DepositNotFound();
        }

        if (
            selectedDeposit.tbtcMigrationState == TbtcMigrationState.Completed
        ) {
            uint96 feeInTbtc = 0;

            // The fee is collected based on the pre-migration rules, so based
            // on the annual fee as set by the governance for the original token.
            // The fee is collected in tBTC as the entire deposit was migrated
            // to tBTC.
            if (selectedDeposit.feeOwed > 0) {
                FeeInfo storage tokenFeeInfo = feeInfo[token];

                feeInTbtc = _adjustTokenDecimals(
                    tokenFeeInfo.receiptToken,
                    tbtcToken,
                    selectedDeposit.feeOwed
                );
            }

            uint96 depositedAmountInTbtc = _adjustTokenDecimals(
                token,
                tbtcToken,
                depositedAmount
            );

            uint96 withdrawableInTbtc = depositedAmountInTbtc - feeInTbtc;

            emit WithdrawnTbtcMigrated(
                msg.sender,
                token,
                tbtcToken,
                depositId,
                withdrawableInTbtc
            );
            emit FeeCollectedTbtcMigrated(
                msg.sender,
                token,
                tbtcToken,
                depositId,
                feeInTbtc
            );

            feeInfo[tbtcToken].feeCollected += feeInTbtc;

            delete deposits[msg.sender][token][depositId];
            IERC20(tbtcToken).safeTransfer(msg.sender, withdrawableInTbtc);
        } else {
            uint96 fee = 0;

            if (selectedDeposit.feeOwed > 0) {
                FeeInfo storage tokenFeeInfo = feeInfo[token];

                fee = _adjustTokenDecimals(
                    tokenFeeInfo.receiptToken,
                    token,
                    selectedDeposit.feeOwed
                );
            }

            uint96 withdrawable = depositedAmount - fee;

            emit Withdrawn(msg.sender, token, depositId, withdrawable);
            emit FeeCollected(msg.sender, token, depositId, fee);

            feeInfo[token].feeCollected += fee;

            delete deposits[msg.sender][token][depositId];
            IERC20(token).safeTransfer(msg.sender, withdrawable);
        }
    }

    /// @notice Withdraws part of the deposited tokens.
    ///
    ///         Deposited lockable tokens can be withdrawn at any time if
    ///         there is no lock set on the deposit or the deposit's lock period
    ///         has passed or the global unlock timestamp has passed.
    ///         There is no way to withdraw locked deposit. Tokens that are not
    ///         lockable can be withdrawn at any time.
    ///
    ///         Deposits for which receipt tokens were minted and fully repaid
    ///         can not be partially withdrawn even if the lock expired.
    ///         Repaying all receipt tokens is a must to partially withdraw the
    ///         deposit. If the fee for receipt tokens minted is non-zero, the
    ///         deposit can not be partially withdrawn and only a full
    ///         withdrawal is possible.
    ///
    ///         Deposits for which the to-tBTC migration was requested can not
    ///         be withdrawn partially.
    ///
    ///         This function allows only for partial withdrawals. For full
    ///         withdrawals, use `withdraw`.
    /// @param token deposited token address
    /// @param depositId id of the deposit
    /// @param amount the amount to be withdrawn
    function withdrawPartially(
        address token,
        uint256 depositId,
        uint96 amount
    ) external {
        TokenAbility ability = tokenAbility[token];

        if (ability == TokenAbility.None) {
            revert TokenNotSupported(token);
        }

        if (amount == 0) {
            revert IncorrectAmount(amount);
        }

        DepositInfo storage selectedDeposit = deposits[msg.sender][token][
            depositId
        ];

        if (selectedDeposit.balance == 0) {
            revert DepositNotFound();
        }

        if (amount >= selectedDeposit.balance) {
            revert PartialWithdrawalAmountTooHigh(selectedDeposit.balance);
        }

        if (
            ability == TokenAbility.DepositAndLock &&
            // solhint-disable-next-line not-rely-on-time
            block.timestamp < selectedDeposit.unlockAt &&
            (depositGlobalUnlockAt == 0 ||
                // solhint-disable-next-line not-rely-on-time
                block.timestamp < depositGlobalUnlockAt)
        ) {
            revert DepositLocked(selectedDeposit.unlockAt);
        }

        if (selectedDeposit.receiptMinted > 0) {
            revert ReceiptNotRepaid(selectedDeposit.receiptMinted);
        }

        if (selectedDeposit.feeOwed > 0) {
            revert ReceiptFeeOwed(selectedDeposit.feeOwed);
        }

        if (
            selectedDeposit.tbtcMigrationState !=
            TbtcMigrationState.NotRequested
        ) {
            revert TbtcMigrationRequestedErr();
        }

        emit Withdrawn(msg.sender, token, depositId, amount);
        selectedDeposit.balance -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    /// @notice Receive approval from a token contract and deposit the tokens in
    ///         one transaction. If the the token is lockable and lock period is
    ///         greater than 0, the deposit will be locked for the given period.
    /// @dev This function is called by the token following the `approveAndCall`
    ///      pattern.
    //       Encoded lock period is counted in seconds, will be normalized to
    ///      weeks. If non-zero, it must not be shorter than the minimum lock
    ///      period and must not be longer than the maximum lock period. To not
    ///      lock the deposit, the lock period must be 0.
    /// @param from address which approved and sent the tokens
    /// @param amount amount of tokens sent
    /// @param token address of the token contract
    /// @param data encoded lock period
    function receiveApproval(
        address from,
        uint256 amount,
        address token,
        bytes calldata data
    ) external override {
        if (token != msg.sender) {
            revert IncorrectTokenAddress(token);
        }
        if (amount > type(uint96).max) {
            revert IncorrectAmount(amount);
        }

        uint32 lockPeriod = abi.decode(data, (uint32));

        _depositFor(from, from, token, uint96(amount), lockPeriod);
    }

    /// @notice Deposit and optionally lock tokens for the given period.
    /// @dev Lock period will be normalized to weeks. If non-zero, it must not
    ///      be shorter than the minimum lock period and must not be longer than
    ///      the maximum lock period.
    /// @param token token address to deposit
    /// @param amount amount of tokens to deposit
    /// @param lockPeriod lock period in seconds, 0 to not lock the deposit
    function deposit(address token, uint96 amount, uint32 lockPeriod) external {
        _depositFor(msg.sender, msg.sender, token, amount, lockPeriod);
    }

    /// @notice Deposit and optionally lock tokens to the contract on behalf of
    ///         someone else.
    /// @dev Lock period will be normalized to weeks. If non-zero, it must not
    ///      be shorter than the minimum lock period and must not be longer than
    ///      the maximum lock period.
    /// @param depositOwner address that will be able to withdraw the deposit
    /// @param token token address to deposit
    /// @param amount amount of tokens to deposit
    /// @param lockPeriod lock period in seconds, 0 to not lock the deposit
    function depositFor(
        address depositOwner,
        address token,
        uint96 amount,
        uint32 lockPeriod
    ) external {
        _depositFor(depositOwner, msg.sender, token, amount, lockPeriod);
    }

    /// @notice Lock existing deposit for a given period. This function can be
    ///         used to lock a deposit that was not locked when it was created or
    ///         to extend the lock period of an already locked deposit.
    /// @param token address of the deposited token
    /// @param depositId id of the deposit
    /// @param lockPeriod new lock period in seconds
    function lock(
        address token,
        uint256 depositId,
        uint32 lockPeriod
    ) external {
        DepositInfo storage depositInfo = deposits[msg.sender][token][
            depositId
        ];

        if (depositInfo.balance == 0) {
            revert DepositNotFound();
        }

        TokenAbility ability = tokenAbility[token];
        if (ability != TokenAbility.DepositAndLock) {
            revert InsufficientTokenAbility(token, ability);
        }

        uint32 existingUnlockAt = depositInfo.unlockAt;
        uint32 newUnlockAt = _calculateUnlockTime(
            msg.sender,
            token,
            depositId,
            lockPeriod
        );
        if (newUnlockAt <= existingUnlockAt) {
            revert LockPeriodTooShort(
                lockPeriod,
                newUnlockAt,
                existingUnlockAt
            );
        }

        depositInfo.unlockAt = newUnlockAt;
    }

    /// @notice External withdraw function to enable the liquidity treasury to
    ///         withdraw tokens from the contract. Only the liquidity treasury
    ///         can withdraw tokens from the contract using this function.
    /// @param token token address to withdraw
    /// @param amount amount of respective token to withdraw
    function withdrawAsLiquidityTreasury(
        address token,
        uint256 amount
    ) external {
        if (msg.sender != liquidityTreasury) {
            revert SenderNotLiquidityTreasury(msg.sender);
        }

        if (amount == 0) {
            revert IncorrectAmount(amount);
        }

        if (!liquidityTreasuryManaged[token]) {
            revert AssetNotManagedByLiquidityTreasury(token);
        }

        emit WithdrawnByLiquidityTreasury(token, amount);

        IERC20(token).safeTransfer(msg.sender, amount);
    }

    /// @notice Repay the deposit receipt token of a particular deposit.
    /// @param token the token address related with the deposit
    /// @param depositId the ID of the deposit
    /// @param amount how much of the token to repay, up to outstanding balance
    function repayReceipt(
        address token,
        uint256 depositId,
        uint256 amount
    ) public {
        FeeInfo storage fee = feeInfo[token];

        if (fee.receiptToken == address(0)) {
            revert ReceiptMintingDisabled();
        }

        if (amount == 0) {
            revert IncorrectAmount(amount);
        }

        DepositInfo storage depositInfo = deposits[msg.sender][token][
            depositId
        ];

        if (depositInfo.balance == 0) {
            revert DepositNotFound();
        }

        if (depositInfo.receiptMinted < amount) {
            revert RepayAmountExceededDebt(depositInfo.receiptMinted, amount);
        }

        _updateFee(depositInfo, token);

        depositInfo.receiptMinted -= uint96(amount);
        fee.totalMinted -= uint96(amount);

        emit ReceiptRepaid(msg.sender, token, depositId, amount);

        // transfer the repaid receipt tokens and burn them
        IERC20(fee.receiptToken).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        IReceiptToken(fee.receiptToken).burnReceipt(amount);
    }

    /// @notice Used by the tBTC migration treasury to withdraw tokens from the
    ///         deposits marked by their owners as requested for to-tBTC
    ///         migration. The caller specifies which deposits are to begin the
    ///         migration. Calling this function for the deposit marks it
    ///         as to-tBTC migration started but gives no promise as when the
    ///         to-tBTC migration will be completed. For all deposits for which
    ///         the to-tBTC migration was started, the tBTC migration multisig
    ///         must ensure to call the `finalizeTbtcMigration` function once
    ///         the migration is completed.
    /// @param token deposited token address
    /// @param depositsToMigrate an array of deposits for which the to-tBTC
    ///        migration was requested and from which the assets should be
    ///        withdrawn for the to-tBTC migration
    function withdrawForTbtcMigration(
        address token,
        DepositToMigrate[] memory depositsToMigrate
    ) external {
        if (msg.sender != tbtcMigrationTreasury) {
            revert SenderNotTbtcMigrationTreasury();
        }

        uint96 totalToMigrate = 0;

        for (uint256 i = 0; i < depositsToMigrate.length; i++) {
            address depositOwner = depositsToMigrate[i].depositor;
            uint256 depositId = depositsToMigrate[i].depositId;

            DepositInfo storage depositInfo = deposits[depositOwner][token][
                depositId
            ];
            if (depositInfo.balance == 0) {
                revert DepositNotFound();
            }

            if (
                depositInfo.tbtcMigrationState != TbtcMigrationState.Requested
            ) {
                revert UnexpectedTbtcMigrationState(
                    depositId,
                    depositInfo.tbtcMigrationState,
                    TbtcMigrationState.Requested
                );
            }

            depositInfo.tbtcMigrationState = TbtcMigrationState.InProgress;
            totalToMigrate += depositInfo.balance;

            emit TbtcMigrationStarted(depositOwner, token, depositId);
        }

        TbtcMigrationInfo storage migrationInfo = tbtcMigrations[token];
        migrationInfo.totalMigrating += totalToMigrate;

        emit WithdrawnForTbtcMigration(token, totalToMigrate);

        IERC20(token).safeTransfer(tbtcMigrationTreasury, totalToMigrate);
    }

    /// @notice Used by the tBTC migration treasury to complete the to-tBTC
    ///         migration for the selected set of deposits. For all of those
    ///         deposits the migration should be started by calling
    ///         `withdrawForTbtcMigration` function before. The treasury has to
    ///         approve the amount of tBTC to the Portal contract equal to the
    ///         total migrated amount of the migrated deposits, adjusted to tBTC
    ///         token decimals.
    /// @param token pre-migration deposited token address
    /// @param migratedDeposits an array of deposits for which the to-tBTC
    ///        migration was completed
    function completeTbtcMigration(
        address token,
        DepositToMigrate[] memory migratedDeposits
    ) external {
        if (msg.sender != tbtcMigrationTreasury) {
            revert SenderNotTbtcMigrationTreasury();
        }

        uint96 totalMigrated = 0;

        for (uint256 i = 0; i < migratedDeposits.length; i++) {
            address depositOwner = migratedDeposits[i].depositor;
            uint256 depositId = migratedDeposits[i].depositId;

            DepositInfo storage depositInfo = deposits[depositOwner][token][
                depositId
            ];

            if (
                depositInfo.tbtcMigrationState != TbtcMigrationState.InProgress
            ) {
                revert UnexpectedTbtcMigrationState(
                    depositId,
                    depositInfo.tbtcMigrationState,
                    TbtcMigrationState.InProgress
                );
            }

            totalMigrated += depositInfo.balance;

            depositInfo.tbtcMigrationState = TbtcMigrationState.Completed;

            emit TbtcMigrationCompleted(depositOwner, token, depositId);
        }

        TbtcMigrationInfo storage migrationInfo = tbtcMigrations[token];
        migrationInfo.totalMigrating -= totalMigrated;

        uint96 totalMigratedInTbtc = _adjustTokenDecimals(
            token,
            tbtcToken,
            totalMigrated
        );

        emit FundedFromTbtcMigration(totalMigratedInTbtc);

        IERC20(tbtcToken).safeTransferFrom(
            msg.sender,
            address(this),
            totalMigratedInTbtc
        );
    }

    /// @notice Get the balance and unlock time of a given deposit. Note that
    ///         the deposit could be migrated to tBTC so even though the `token`
    ///         key under which it is available could still point to the
    ///         pre-migration version, the withdrawal - when requested - will
    ///         happen in tBTC.
    /// @param depositor depositor address
    /// @param token token address to get the balance
    /// @param depositId id of the deposit
    function getDeposit(
        address depositor,
        address token,
        uint256 depositId
    ) external view returns (DepositInfo memory) {
        return deposits[depositor][token][depositId];
    }

    /// @notice Set indication of whether the deposit should opt out from
    ///         auto-bridging to the Mezo chain. Can only be called by the
    ///         contract's owner. The deposit must exist.
    /// @param depositor depositor address
    /// @param token deposited token address
    /// @param depositId id of the deposit
    /// @param optOut indication of whether the deposit should opt-out from
    ///               auto-bridging
    function setDepositAutoBridgingOptOut(
        address depositor,
        address token,
        uint256 depositId,
        bool optOut
    ) external onlyOwner {
        _setDepositAutoBridgingOptOut(depositor, token, depositId, optOut);
    }

    /// @notice Set indication of whether the deposit should opt out from
    ///         auto-bridging to the Mezo chain. The caller must be the
    ///         deposit's owner. The deposit must exist.
    /// @param token deposited token address
    /// @param depositId id of the deposit
    /// @param optOut indication of whether the deposit should opt-out from
    ///               auto-bridging
    function setDepositAutoBridgingOptOut(
        address token,
        uint256 depositId,
        bool optOut
    ) external {
        _setDepositAutoBridgingOptOut(msg.sender, token, depositId, optOut);
    }

    /// @notice Set the Mezo bridge. It will be used during auto-bridging of
    ///         tokens to the Mezo chain.
    /// @param _mezoBridge address of the Mezo bridge
    function setMezoBridge(address _mezoBridge) external onlyOwner {
        if (_mezoBridge == address(0)) {
            revert IncorrectMezoBridgeAddress(_mezoBridge);
        }

        emit MezoBridgeUpdated(address(mezoBridge), _mezoBridge);
        mezoBridge = MezoBridge(_mezoBridge);
    }

    /// @notice Set the auto-bridge coordinator. This account will be able to
    ///         auto-bridge deposits to the Mezo chain.
    /// @param _autoBridgeCoordinator address of the auto-bridge coordinator
    function setAutoBridgeCoordinator(
        address _autoBridgeCoordinator
    ) external onlyOwner {
        if (_autoBridgeCoordinator == address(0)) {
            revert IncorrectAutoBridgeCoordinatorAddress(
                _autoBridgeCoordinator
            );
        }

        emit AutoBridgeCoordinatorUpdated(
            autoBridgeCoordinator,
            _autoBridgeCoordinator
        );
        autoBridgeCoordinator = _autoBridgeCoordinator;
    }

    /// @notice Set the deposit global unlock at timestamp beyond which all
    ///         deposits are withdrawable, irrespective of their `unlockAt`
    ///         parameter.
    /// @param _depositGlobalUnlockAt deposit global unlock at timestamp
    function setDepositGlobalUnlockAt(
        uint32 _depositGlobalUnlockAt
    ) external onlyOwner {
        if (_depositGlobalUnlockAt == 0) {
            revert IncorrectDepositGlobalUnlockAt(_depositGlobalUnlockAt);
        }

        emit DepositGlobalUnlockAtUpdated(
            depositGlobalUnlockAt,
            _depositGlobalUnlockAt
        );
        depositGlobalUnlockAt = _depositGlobalUnlockAt;
    }

    /// @notice Set the WBTC token address.
    /// @dev Can only be executed by the governance.
    /// @param _wbtcToken address of the WBTC token
    function setWbtcTokenAddress(address _wbtcToken) external onlyOwner {
        if (_wbtcToken == address(0)) {
            revert IncorrectTokenAddress(_wbtcToken);
        }

        wbtcToken = _wbtcToken;

        emit WbtcTokenAddressSet(_wbtcToken);
    }

    /// @notice Auto-bridge a batch of deposits to the Mezo chain via the Mezo
    ///         bridge contract.
    /// @param token address of token common to all the deposits on the list
    /// @param _deposits list of deposits to be auto-bridged
    /// @dev Can be called only by the auto-bridge coordinator. All the deposits
    ///      in the batch must be of the same token and the token must not be
    ///      WBTC.
    ///      A deposit will be skipped during auto-bridging if:
    ///      - the deposit is opting-out from auto-bridging, or
    ///      - the deposit was withdrawn, or
    ///      - stBTC was minted for the deposit and not repaid, or
    ///      - to-tBTC migration was requested for the deposit.
    ///      Before invoking this function, the contract owner must set the
    ///      addresses of Mezo bridge, tBTC and WBTC token.
    // slither-disable-next-line cyclomatic-complexity
    function autoBridgeDeposits(
        address token,
        DepositToAutoBridge[] calldata _deposits
    ) external nonReentrant onlyAutoBridgeCoordinator {
        if (wbtcToken == address(0)) {
            revert IncorrectTokenAddress(wbtcToken);
        }

        if (tbtcToken == address(0)) {
            revert IncorrectTokenAddress(tbtcToken);
        }

        if (address(mezoBridge) == address(0)) {
            revert IncorrectMezoBridgeAddress(address(mezoBridge));
        }

        if (token == wbtcToken) {
            revert WbtcAutoBridgingNotSupported();
        }

        for (uint256 i = 0; i < _deposits.length; i++) {
            address depositor = _deposits[i].depositor;
            uint256 depositId = _deposits[i].depositId;

            DepositInfo storage selectedDeposit = deposits[depositor][token][
                depositId
            ];

            if (selectedDeposit.autoBridgingOptOut) {
                // If the deposit is marked on-chain as opting-out from
                // auto-bridging skip it.
                emit OptOutDepositAutoBridgingSkipped(
                    depositor,
                    token,
                    depositId
                );
                continue;
            }

            uint256 depositBalance = selectedDeposit.balance;

            if (depositBalance == 0) {
                // Even though the provided list of deposits to auto-bridge
                // should be correctly constructed, we should skip a problematic
                // deposit rather than revert. This helps to avoid a griefing
                // attack when the attacker would front-run the auto-bridging
                // transaction and withdraw the deposit.
                emit WithdrawnDepositAutoBridgingSkipped(
                    depositor,
                    token,
                    depositId
                );
                continue;
            }

            if (selectedDeposit.receiptMinted > 0) {
                // Ignore deposits for which stBTC was minted and not repaid.
                // We need to keep them locked until the receipt token is
                // repaid.
                emit ReceiptMintedDepositAutoBridgingSkipped(
                    depositor,
                    token,
                    depositId
                );
                continue;
            }

            if (
                selectedDeposit.tbtcMigrationState !=
                TbtcMigrationState.NotRequested
            ) {
                // Ignore deposits for which to-tBTC migration was
                // requested. Those deposits will have to be handled by a
                // separate bridging function.
                emit TbtcMigratingDepositAutoBridgingSkipped(
                    depositor,
                    token,
                    depositId
                );
                continue;
            }

            delete deposits[depositor][token][depositId];

            // slither-disable-start reentrancy-no-eth
            // slither-disable-start calls-loop

            if (token == USDT_ADDRESS) {
                // Special case for USDT. Per ERC20 spec, approve should return
                // boolean but USDT ignores the spec and approve returns nothing.
                // Also, USDT reverts if there is already a non-zero approval.
                IUSDT(token).approve(address(mezoBridge), 0);
                IUSDT(token).approve(address(mezoBridge), depositBalance);
            } else if (
                !IERC20(token).approve(address(mezoBridge), depositBalance)
            ) {
                revert TokenApprovalFailure();
            }

            if (token == tbtcToken) {
                mezoBridge.bridgeTBTC(depositBalance, depositor);
            } else {
                mezoBridge.bridgeERC20(token, depositBalance, depositor);
            }

            emit DepositAutoBridged(
                depositor,
                token,
                depositId,
                depositBalance
            );

            // slither-disable-end reentrancy-no-eth
            // slither-disable-end calls-loop
        }
    }

    /// @notice Auto-bridges the provided WBTC deposits to Mezo. Only WBTC
    ///         deposits that have completed the to-tBTC migration can be
    ///         bridged. The call is made by the coordinator who controls the
    ///         auto-bridging process.
    /// @dev All the deposits must be WBTC deposits that completed to-tBTC
    ///      migration. A deposit will be skipped during auto-bridging if:
    ///      - the deposit is opting-out from auto-bridging, or
    ///      - the deposit was withdrawn, or
    ///      - stBTC was minted for the deposit and not repaid.
    ///      Before invoking this function, the contract owner must set the
    ///      addresses of Mezo bridge, tBTC, and WBTC token.
    // slither-disable-next-line cyclomatic-complexity
    function autoBridgeWbtcDeposits(
        DepositToAutoBridge[] calldata _deposits
    ) external nonReentrant onlyAutoBridgeCoordinator {
        if (wbtcToken == address(0)) {
            revert IncorrectTokenAddress(wbtcToken);
        }

        if (tbtcToken == address(0)) {
            revert IncorrectTokenAddress(tbtcToken);
        }

        if (address(mezoBridge) == address(0)) {
            revert IncorrectMezoBridgeAddress(address(mezoBridge));
        }

        address _wbtc = wbtcToken;
        address _tbtc = tbtcToken;

        uint8 wbtcSourceDecimals = IERC20WithDecimals(_wbtc).decimals();
        uint8 tbtcTargetDecimals = IERC20WithDecimals(_tbtc).decimals();

        for (uint256 i = 0; i < _deposits.length; i++) {
            address depositor = _deposits[i].depositor;
            uint256 depositId = _deposits[i].depositId;

            DepositInfo storage selectedDeposit = deposits[depositor][_wbtc][
                depositId
            ];

            if (selectedDeposit.autoBridgingOptOut) {
                // If the deposit is marked on-chain as opting-out from
                // auto-bridging skip it.
                emit OptOutDepositAutoBridgingSkipped(
                    depositor,
                    _wbtc,
                    depositId
                );
                continue;
            }

            uint96 depositBalance = selectedDeposit.balance;

            if (depositBalance == 0) {
                // Even though the provided list of deposits to auto-bridge
                // should be correctly constructed, we should skip a problematic
                // deposit rather than revert. This helps to avoid a griefing
                // attack when the attacker would front-run the transaction and
                // withdraw the deposit.
                emit WithdrawnDepositAutoBridgingSkipped(
                    depositor,
                    _wbtc,
                    depositId
                );
                continue;
            }

            if (selectedDeposit.receiptMinted > 0) {
                // Ignore deposits for which stBTC was minted and not repaid.
                // We need to keep them locked until the receipt token is
                // repaid.
                emit ReceiptMintedDepositAutoBridgingSkipped(
                    depositor,
                    _wbtc,
                    depositId
                );
                continue;
            }

            if (
                selectedDeposit.tbtcMigrationState !=
                TbtcMigrationState.Completed
            ) {
                revert TbtcMigrationNotCompleted();
            }

            delete deposits[depositor][_wbtc][depositId];

            // slither-disable-start reentrancy-no-eth
            // slither-disable-start calls-loop

            uint96 depositBalanceInTbtc = _adjustTokenDecimals(
                wbtcSourceDecimals,
                tbtcTargetDecimals,
                depositBalance
            );

            if (
                !IERC20(_tbtc).approve(
                    address(mezoBridge),
                    depositBalanceInTbtc
                )
            ) {
                revert TokenApprovalFailure();
            }

            mezoBridge.bridgeTBTC(depositBalanceInTbtc, depositor);

            emit DepositAutoBridged(
                depositor,
                _wbtc,
                depositId,
                depositBalance
            );

            // slither-disable-end reentrancy-no-eth
            // slither-disable-end calls-loop
        }
    }

    /// @notice Allows the deposit owner to bridge their deposit to Mezo.
    ///         An existing deposit can be bridged assuming the receipt token
    ///         was not minted OR it was fully repaid. If the token is WBTC,
    ///         the to-tBTC migration must be completed for bridging.
    // slither-disable-next-line cyclomatic-complexity
    function bridgeDeposit(address token, uint256 depositId) external {
        if (wbtcToken == address(0)) {
            revert IncorrectTokenAddress(wbtcToken);
        }

        if (tbtcToken == address(0)) {
            revert IncorrectTokenAddress(tbtcToken);
        }

        if (address(mezoBridge) == address(0)) {
            revert IncorrectMezoBridgeAddress(address(mezoBridge));
        }

        DepositInfo storage selectedDeposit = deposits[msg.sender][token][
            depositId
        ];
        uint96 depositBalance = selectedDeposit.balance;

        if (depositBalance == 0) {
            revert DepositNotFound();
        }

        if (selectedDeposit.receiptMinted > 0) {
            revert ReceiptNotRepaid(selectedDeposit.receiptMinted);
        }

        if (
            token == wbtcToken &&
            selectedDeposit.tbtcMigrationState != TbtcMigrationState.Completed
        ) {
            revert TbtcMigrationNotCompleted();
        } else if (
            token != wbtcToken &&
            selectedDeposit.tbtcMigrationState !=
            TbtcMigrationState.NotRequested
        ) {
            revert TbtcMigrationRequestedErr();
        }

        delete deposits[msg.sender][token][depositId];

        emit DepositBridged(msg.sender, token, depositId, depositBalance);

        //
        // This is a WBTC token with a to-tBTC migration completed. We need to
        // adjust the decimals, as the DeposiInfo is still stored for WBTC.
        // After adjusting decimals, we can bridge it as tBTC.
        //
        if (token == wbtcToken) {
            uint96 depositBalanceInTbtc = _adjustTokenDecimals(
                token,
                tbtcToken,
                depositBalance
            );

            if (
                !IERC20(tbtcToken).approve(
                    address(mezoBridge),
                    depositBalanceInTbtc
                )
            ) {
                revert TokenApprovalFailure();
            }

            mezoBridge.bridgeTBTC(depositBalanceInTbtc, msg.sender);
        } else {
            //
            // This is either tBTC or any other ERC20 that had no to-tBTC
            // migrations requested. We can bridge it without adjusting
            // decimals.
            //
            if (token == USDT_ADDRESS) {
                // Special case for USDT. Per ERC20 spec, approve should return
                // boolean but USDT ignores the spec and approve returns nothing.
                // Also, USDT reverts if there is already a non-zero approval.
                IUSDT(token).approve(address(mezoBridge), 0);
                IUSDT(token).approve(address(mezoBridge), depositBalance);
            } else if (
                !IERC20(token).approve(address(mezoBridge), depositBalance)
            ) {
                revert TokenApprovalFailure();
            }

            if (token == tbtcToken) {
                mezoBridge.bridgeTBTC(depositBalance, msg.sender);
            } else {
                mezoBridge.bridgeERC20(token, depositBalance, msg.sender);
            }
        }
    }

    /// @notice Internal function for marking a given deposit as opting-out from
    ///         auto-bridging to the Mezo chain. The deposit must exist.
    /// @param depositor depositor address
    /// @param token deposited token address
    /// @param depositId id of the deposit
    /// @param optOut indication of whether the deposit should opt-out from
    ///               auto-bridging
    function _setDepositAutoBridgingOptOut(
        address depositor,
        address token,
        uint256 depositId,
        bool optOut
    ) internal {
        DepositInfo storage selectedDeposit = deposits[depositor][token][
            depositId
        ];

        if (selectedDeposit.balance == 0) {
            revert DepositNotFound();
        }

        selectedDeposit.autoBridgingOptOut = optOut;

        emit DepositAutoBridgingOptOutSet(depositor, token, depositId, optOut);
    }

    /// @notice Internal deposit function to deposit tokens on behalf of a given
    ///         address - sender or someone else. If the lock period passed as
    ///         a parameter is non-zero, the function will lock the deposit.
    /// @param depositOwner address that will be able to withdraw the deposit
    /// @param token token address to deposit
    /// @param amount amount of tokens to deposit
    /// @param lockPeriod lock period in seconds, 0 to not lock the deposit
    function _depositFor(
        address depositOwner,
        address depositFunder,
        address token,
        uint96 amount,
        uint32 lockPeriod
    ) internal {
        TokenAbility ability = tokenAbility[token];
        if (ability == TokenAbility.None) {
            revert TokenNotSupported(token);
        }
        if (lockPeriod > 0 && ability == TokenAbility.Deposit) {
            revert InsufficientTokenAbility(token, ability);
        }

        if (depositOwner == address(0)) {
            revert IncorrectDepositor(depositOwner);
        }

        if (amount == 0) {
            revert IncorrectAmount(amount);
        }

        depositCount++;

        uint256 depositId = depositCount;

        emit Deposited(depositOwner, token, depositId, amount);

        deposits[depositOwner][token][depositId] = DepositInfo({
            balance: amount,
            // solhint-disable-next-line not-rely-on-time
            unlockAt: _calculateUnlockTime(
                depositOwner,
                token,
                depositId,
                lockPeriod
            ),
            receiptMinted: 0,
            feeOwed: 0,
            lastFeeIntegral: 0,
            tbtcMigrationState: TbtcMigrationState.NotRequested,
            autoBridgingOptOut: false
        });

        IERC20(token).safeTransferFrom(depositFunder, address(this), amount);
    }

    /// @notice Calculates the unlock time normalizing the lock time value and
    ///         making sure it is in the allowed range. Returns the timestamp at
    ///         which the deposit can be unlocked.
    /// @dev This function DOES NOT check if the deposit exists and if the
    ///      existing deposit already has a lock time. Please validate it before
    ///      calling this function.
    /// @param depositor depositor address
    /// @param token token of the deposit that will be locked
    /// @param depositId id of the deposit that will be locked
    /// @param lockPeriod lock period in seconds
    function _calculateUnlockTime(
        address depositor,
        address token,
        uint depositId,
        uint32 lockPeriod
    ) internal returns (uint32) {
        // Short-circuit if there is no intention to lock. There is no need to
        // check the minimum/maximum lock time or normalize the lock period.
        if (lockPeriod == 0) {
            // solhint-disable-next-line not-rely-on-time
            return uint32(block.timestamp);
        }

        uint32 normalizedLockPeriod = _normalizeLockPeriod(lockPeriod);

        if (
            normalizedLockPeriod == 0 ||
            normalizedLockPeriod < minLockPeriod ||
            normalizedLockPeriod > maxLockPeriod
        ) {
            revert LockPeriodOutOfRange(lockPeriod);
        }

        // solhint-disable-next-line not-rely-on-time
        uint32 unlockAt = uint32(block.timestamp) + normalizedLockPeriod;

        // It is gas-cheaper to pass the required parameters and emit the event
        // here instead of checking the result and emit the event in the calling
        // function. Keep in mind internal functions are inlined.
        emit Locked(
            depositor,
            token,
            depositId,
            unlockAt,
            normalizedLockPeriod
        );

        return unlockAt;
    }

    /// @notice Internal function to update the fee information of a given
    ///         deposit.
    /// @param depositInfo Storage reference to the deposit info to be updated.
    /// @param token Address of the token related to the deposit.
    function _updateFee(
        DepositInfo storage depositInfo,
        address token
    ) internal {
        _updateFeeIntegral(token);

        FeeInfo memory fee = feeInfo[token];

        depositInfo.feeOwed += _calculateFeeAccrued(
            fee.feeIntegral - depositInfo.lastFeeIntegral,
            depositInfo.receiptMinted
        );
        depositInfo.lastFeeIntegral = fee.feeIntegral;
    }

    /// @notice Internal function to update the fee integral for a given token.
    /// @param token Address of the token to update the fee integral.
    function _updateFeeIntegral(address token) internal {
        FeeInfo storage i = feeInfo[token];
        uint96 feePerSecond = _calculateFeeRate(token);

        // solhint-disable-next-line not-rely-on-time
        uint32 timeInterval = uint32(block.timestamp) - i.lastFeeUpdateAt;
        uint96 accumulated = timeInterval * feePerSecond;
        i.feeIntegral += uint88(accumulated);
        // solhint-disable-next-line not-rely-on-time
        i.lastFeeUpdateAt = uint32(block.timestamp);
    }

    /// @notice Internal function to calculate the fee rate per second for a
    ///         given token.
    /// @param token Address of the token.
    function _calculateFeeRate(address token) internal view returns (uint96) {
        FeeInfo memory i = feeInfo[token];
        // The i.annualFee is expressed in % so we divide by 100 to get the
        // fee rate in token units: 10^18 / 10^2 = 10^16
        return (uint96(i.annualFee) * (10 ** 16)) / (365 days);
    }

    /// @notice Calculates the fee accrued based on the given integral
    ///         difference and minted amount.
    /// @dev Multiplies the integral difference by the minted amount and scales
    ///      it down to fit the desired precision.
    /// @param integralDiff The difference in integral values.
    /// @param mintedAmount The amount of tokens minted.
    function _calculateFeeAccrued(
        uint88 integralDiff,
        uint96 mintedAmount
    ) internal pure returns (uint96) {
        return
            uint96((uint256(integralDiff) * uint256(mintedAmount)) / 10 ** 18);
    }

    /// @notice Normalizes the lock period to weeks. Will round down if not
    ///         normalized.
    /// @param lockPeriod the lock period to be normalized
    function _normalizeLockPeriod(
        uint32 lockPeriod
    ) internal pure returns (uint32) {
        // slither-disable-next-line divide-before-multiply
        return (lockPeriod / 1 weeks) * 1 weeks;
    }

    /// @notice Adjusts the decimals amount to desired precision for the two
    ///         token addresses and amount expressed in the precision used by
    ///         one of them.
    /// @param sourceToken the token address of the source amount
    /// @param targetToken the token address of the target amount
    /// @param amount the source amount to be adjusted
    function _adjustTokenDecimals(
        address sourceToken,
        address targetToken,
        uint96 amount
    ) internal view returns (uint96) {
        uint8 sourceDecimals = IERC20WithDecimals(sourceToken).decimals();
        uint8 targetDecimals = IERC20WithDecimals(targetToken).decimals();

        return _adjustTokenDecimals(sourceDecimals, targetDecimals, amount);
    }

    /// @notice Adjusts the decimals amount to desired precision for the two
    ///         token decimals and amount expressed in the precision used by
    ///         one of them.
    /// @param sourceDecimals the token decimals of the source amount
    /// @param targetDecimals the token decimals of the target amount
    /// @param amount the source amount to be adjusted
    function _adjustTokenDecimals(
        uint8 sourceDecimals,
        uint8 targetDecimals,
        uint96 amount
    ) internal pure returns (uint96) {
        if (sourceDecimals < targetDecimals) {
            return uint96(amount * (10 ** (targetDecimals - sourceDecimals)));
        } else if (sourceDecimals > targetDecimals) {
            return uint96(amount / (10 ** (sourceDecimals - targetDecimals)));
        }

        return amount;
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }
}

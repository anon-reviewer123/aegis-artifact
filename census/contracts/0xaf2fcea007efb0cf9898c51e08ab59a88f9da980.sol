//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
pragma experimental ABIEncoderV2;

// This contract performs checks on sponsoring amount, executor address, and pays coinbase
contract MEVCheckAndSponsor {
    error NotEnoughFundsToSponsor();
    error InvalidAddress();
    error FailedToSponsor();
    error OutDatedTargetBlock();

    function checkNativeTxsAndSend(
        address[] calldata _executors,
        uint256[] calldata _gasUnitsToFunds,
        uint256 targetedBlock
    ) external payable {
        require(
            _executors.length == _gasUnitsToFunds.length,
            "executors and gas units must be the same length"
        );

        uint256 leftover;
        for (uint256 i = 0; i < _executors.length; i++) {
            leftover = _checkNativeTxAndSend(
                _executors[i],
                _gasUnitsToFunds[i],
                targetedBlock
            );
        }

        block.coinbase.call{value: leftover}(new bytes(0));
    }

    function checkNativeTxAndSend(
        address _executor,
        uint256 _gasUnitsToFund,
        uint256 targetedBlock
    ) external payable {
        uint256 leftover = _checkNativeTxAndSend(
            _executor,
            _gasUnitsToFund,
            targetedBlock
        );
        block.coinbase.call{value: leftover}(new bytes(0));
    }

    function check32Bytes(
        address _target,
        bytes memory _payload,
        bytes32 _resultMatch
    ) external view {
        _check32Bytes(_target, _payload, _resultMatch);
    }

    function checkMulti32Bytes(
        address[] memory _targets,
        bytes[] memory _payloads,
        bytes32[] memory _resultMatches
    ) external view {
        require(_targets.length == _payloads.length);
        require(_targets.length == _resultMatches.length);
        for (uint256 i = 0; i < _targets.length; i++) {
            _check32Bytes(_targets[i], _payloads[i], _resultMatches[i]);
        }
    }

    function checkBytes(
        address _target,
        bytes memory _payload,
        bytes memory _resultMatch
    ) external view {
        _checkBytes(_target, _payload, _resultMatch);
    }

    function checkMultiBytes(
        address[] memory _targets,
        bytes[] memory _payloads,
        bytes[] memory _resultMatches
    ) external view {
        require(_targets.length == _payloads.length);
        require(_targets.length == _resultMatches.length);
        for (uint256 i = 0; i < _targets.length; i++) {
            _checkBytes(_targets[i], _payloads[i], _resultMatches[i]);
        }
    }

    // ======== INTERNAL ========

    function _check32Bytes(
        address _target,
        bytes memory _payload,
        bytes32 _resultMatch
    ) internal view {
        (bool _success, bytes memory _response) = _target.staticcall(_payload);
        require(_success, "!success");
        require(_response.length >= 32, "response less than 32 bytes");
        bytes32 _responseScalar;
        assembly {
            _responseScalar := mload(add(_response, 0x20))
        }
        require(_responseScalar == _resultMatch, "response mismatch");
    }

    function _checkBytes(
        address _target,
        bytes memory _payload,
        bytes memory _resultMatch
    ) internal view {
        (bool _success, bytes memory _response) = _target.staticcall(_payload);
        require(_success, "!success");
        require(
            keccak256(_resultMatch) == keccak256(_response),
            "response bytes mismatch"
        );
    }

    function _checkNativeTxAndSend(
        address _executor,
        uint256 _gasUnitsToFund,
        uint256 targetedBlock
    ) internal returns (uint256 remaining) {
        if (_executor == address(0)) {
            revert InvalidAddress();
        }

        if (targetedBlock < block.number) {
            revert OutDatedTargetBlock();
        }

        uint256 amountToTransfer = _gasUnitsToFund * block.basefee;

        (bool success, ) = payable(_executor).call{value: amountToTransfer}("");

        if (!success) {
            revert FailedToSponsor();
        }

        remaining = address(this).balance - amountToTransfer;
    }
}
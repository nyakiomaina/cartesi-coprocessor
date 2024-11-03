// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@optimism/contracts/libraries/bridge/IL1CrossDomainMessenger.sol";

contract L1Coordinator {
    IL1CrossDomainMessenger public crossDomainMessenger;
    address public l2Coprocessor;

    event SolutionSubmitted(bytes32 indexed machineHash, bytes32 responseHash);

    constructor(address _crossDomainMessenger) {
        crossDomainMessenger = IL1CrossDomainMessenger(_crossDomainMessenger);
    }

    function setL2Coprocessor(address _l2Coprocessor) external {
        l2Coprocessor = _l2Coprocessor;
    }

    function submitSolution(
        bytes32 machineHash,
        bytes32 responseHash,
        uint32 gasLimit
    ) external {
        emit SolutionSubmitted(machineHash, responseHash);

        bytes memory message = abi.encodeWithSignature(
            "storeResponseHash(bytes32,bytes32)",
            machineHash,
            responseHash
        );

        crossDomainMessenger.sendMessage(l2Coprocessor, message, gasLimit);
    }
}

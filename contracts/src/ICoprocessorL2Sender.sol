// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

    struct Response {
        address ruleSet;
        bytes32 machineHash;
        bytes32 payloadHash;
        bytes32 outputMerkle;
    }

interface ICoprocessorL2Sender {
    function sendMessage(bytes32 respHash, uint32 gasLimit) external;
}

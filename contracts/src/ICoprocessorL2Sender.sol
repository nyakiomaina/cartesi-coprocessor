// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface ICoprocessorL2Sender {
    function sendMessage(bytes32 respHash, uint32 gasLimit) external;
}

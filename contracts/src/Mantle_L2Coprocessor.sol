// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import { ICrossDomainMessenger } from "mantlenetworkio/contracts/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import "./ICoprocessorCallback.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {LibMerkle32} from "./LibMerkle32.sol";


contract L2Coprocessor is Ownable {
    using LibMerkle32 for bytes32[];
    ICrossDomainMessenger public crossDomainMessenger;
    address public l1Coordinator;
    mapping(bytes32 => bool) public responses;

    event TaskIssued(bytes32 machineHash, bytes input, address callback);
    event TaskCompleted( bytes32 responseHash);

    constructor(address _crossDomainMessenger)
    {
        crossDomainMessenger = ICrossDomainMessenger(_crossDomainMessenger);
    }

    modifier onlyL1Coordinator() {
        require(
            msg.sender == address(crossDomainMessenger) &&
            crossDomainMessenger.xDomainMessageSender() == l1Coordinator,
            "Not authorized"
        );
        _;
    }

    function setL1Coordinator(address _l1Coordinator) external onlyOwner {
        l1Coordinator = _l1Coordinator;
    }

    function issueTask(bytes32 machineHash, bytes calldata input, address callback) public {
        emit TaskIssued(machineHash, input, callback);
    }

    function storeResponseHash(bytes32 responseHash) external onlyL1Coordinator {
        require(!responses[responseHash], "Response already whitelisted");
        responses[responseHash] = true;
        emit TaskCompleted(responseHash);
    }

    function callbackWithOutputs(
        Response calldata resp,
        bytes[] calldata outputs,
        address callbackAddress
    ) public {
        bytes32 respHash = keccak256(abi.encode(resp));
        require(responses[respHash], "Response not whitelisted");

        bytes32[] memory outputsHashes = new bytes32[](outputs.length);
        for (uint256 i = 0; i < outputs.length; i++) {
            outputsHashes[i] = keccak256(outputs[i]);
        }

        require(resp.outputMerkle == LibMerkle32.merkleRoot(outputsHashes, 63), "Invalid Merkle root");

        ICoprocessorCallback(callbackAddress).coprocessorCallbackOutputsOnly(
            resp.machineHash,
            resp.payloadHash,
            outputs
        );
    }
}

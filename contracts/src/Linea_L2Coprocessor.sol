// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./ICoprocessorCallback.sol";
import "./IMessageService.sol";
import "./MessageServiceBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {LibMerkle32} from "./LibMerkle32.sol";

contract L2Coprocessor is Ownable, MessageServiceBase {
    using LibMerkle32 for bytes32[];
    mapping(bytes32 => bool) public responses;

    event TaskIssued(bytes32 machineHash, bytes input, address callback);
    event TaskCompleted(bytes32 responseHash);

    constructor(
        address _messageService,
        address _remoteSender
    )  {
        require(_messageService != address(0), "Invalid message service address");
        require(_remoteSender != address(0), "Invalid remote sender address");
        _init_MessageServiceBase(_messageService, _remoteSender);
    }

    function setRemoteSender(address _remoteSender) external onlyOwner {
        require(_remoteSender != address(0), "Invalid remote sender address");
        remoteSender = _remoteSender;
    }

    function issueTask(
        bytes32 machineHash,
        bytes calldata input,
        address callback
    ) external {
        emit TaskIssued(machineHash, input, callback);
    }

    function storeResponseHash(bytes32 responseHash) external onlyMessagingService onlyAuthorizedRemoteSender {
        require(!responses[responseHash], "Response already whitelisted");
        responses[responseHash] = true;
        emit TaskCompleted(responseHash);
    }

    function callbackWithOutputs(
        Response calldata resp,
        bytes[] calldata outputs,
        address callbackAddress
    ) external {
        bytes32 respHash = keccak256(abi.encode(resp));
        require(responses[respHash], "Response not recognized");

        bytes32[] memory outputsHashes = new bytes32[](outputs.length);
        for (uint256 i = 0; i < outputs.length; i++) {
            outputsHashes[i] = keccak256(outputs[i]);
        }
        require(resp.outputMerkle == LibMerkle32.merkleRoot(outputsHashes, 63), "M");

        ICoprocessorCallback(callbackAddress).coprocessorCallbackOutputsOnly(
            resp.machineHash,
            resp.payloadHash,
            outputs
        );
    }
}

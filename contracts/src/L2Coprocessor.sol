// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./ICoprocessorCallback.sol";
import "./Coprocessor.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@optimism/contracts/libraries/bridge/IL2CrossDomainMessenger.sol";

contract L2Coprocessor is Coprocessor, Ownable {
    //instance of the optimism cross domain messagnger
    IL2CrossDomainMessenger public crossDomainMessenger;
    address public l1Coordinator; // address only authorized to call storeResponseHash

    // keep track of the responses
    mapping(bytes32 => bool) public responses;

    // new task issued
    event TaskIssued(bytes32 machineHash, bytes input, address callback);
    event TaskCompleted(bytes32 indexed machineHash, bytes32 responseHash); // task completed

    // initialize l2 contract
    constructor(IRegistryCoordinator _registryCoordinator, address _crossDomainMessenger)
        Coprocessor(_registryCoordinator)
    {
        crossDomainMessenger = IL2CrossDomainMessenger(_crossDomainMessenger);
    }

    // only authorised from l1
    modifier onlyL1Coordinator() {
        require(
            msg.sender == address(crossDomainMessenger) &&
            crossDomainMessenger.xDomainMessageSender() == l1Coordinator,
            "Not authorized"
        );
        _;
    }

    // set contract owner to set L1Coordinator address
    function setL1Coordinator(address _l1Coordinator) external onlyOwner {
        l1Coordinator = _l1Coordinator;
    }

    // issue new task
    function issueTask(bytes32 machineHash, bytes calldata input, address callback) public {
        emit TaskIssued(machineHash, input, callback);
    }

    // store response hash and this can only be called by the L1Coordinator
    function storeResponseHash(bytes32 machineHash, bytes32 responseHash) external onlyL1Coordinator {
        require(!responses[responseHash], "Response already whitelisted");
        responses[responseHash] = true;
        emit TaskCompleted(machineHash, responseHash);
    }

    // can call callback with the provided outputs after the task is completed
    function callbackWithOutputs(
        bytes32 machineHash,
        bytes32 payloadHash,
        bytes[] calldata outputs,
        address callbackAddress
    ) external onlyOwner {
        require(responses[machineHash]);

        ICoprocessorCallback(callbackAddress).coprocessorCallbackOutputsOnly(machineHash, payloadHash, outputs);
    }
}

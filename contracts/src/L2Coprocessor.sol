// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./ICoprocessorCallback.sol";
import "./Coprocessor.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@optimism/contracts/libraries/bridge/IL2CrossDomainMessenger.sol";

contract L2Coprocessor is Coprocessor, Ownable {
    IL2CrossDomainMessenger public crossDomainMessenger;
    address public l1Coordinator;

    struct Task {
        bytes32 responseHash;
        bool completed;
    }

    mapping(bytes32 => Task) public tasks;

    event TaskIssued(bytes32 indexed machineHash, bytes input, address indexed callback);
    event TaskCompleted(bytes32 indexed machineHash, bytes32 responseHash);

    constructor(IRegistryCoordinator _registryCoordinator, address _crossDomainMessenger)
        Coprocessor(_registryCoordinator)
    {
        crossDomainMessenger = IL2CrossDomainMessenger(_crossDomainMessenger);
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

    function issueTask(bytes32 machineHash, bytes calldata input, address callback) external onlyOwner {
        emit TaskIssued(machineHash, input, callback);
        tasks[machineHash] = Task({responseHash: bytes32(0), completed: false});
    }

    function storeResponseHash(bytes32 machineHash, bytes32 responseHash) external onlyL1Coordinator {
        Task storage task = tasks[machineHash];
        require(!task.completed, "Task already completed");
        task.responseHash = responseHash;
        task.completed = true;
        emit TaskCompleted(machineHash, responseHash);
    }

    function callbackWithOutputs(
        bytes32 machineHash,
        bytes32 payloadHash,
        bytes[] calldata outputs,
        address callbackAddress
    ) external onlyOwner {
        Task storage task = tasks[machineHash];
        require(task.completed, "Task not completed");

        ICoprocessorCallback(callbackAddress).coprocessorCallbackOutputsOnly(machineHash, payloadHash, outputs);
    }
}

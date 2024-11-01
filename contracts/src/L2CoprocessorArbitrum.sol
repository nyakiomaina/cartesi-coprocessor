// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AddressAliasHelper.sol";
import "./ICoprocessorCallback.sol";
import {LibMerkle32} from "./LibMerkle32.sol";

contract L2Coprocessor is Ownable {
    using LibMerkle32 for bytes32[];

    mapping(address => bool) public authorizedL1Senders;

    mapping(bytes32 => bool) public responses;

    event TaskIssued(bytes32 machineHash, bytes input, address callback);
    event TaskCompleted(bytes32 indexed responseHash);

    //constructor(IRegistryCoordinator _registryCoordinator) Coprocessor(_registryCoordinator) {}

    modifier onlyAuthorizedL1Sender() {
        require(authorizedL1Senders[msg.sender], "Not authorized");
        _;
    }

    function authorizeL1Sender(address l1Sender) external onlyOwner {
        address l2Alias = AddressAliasHelper.applyL1ToL2Alias(l1Sender);
        authorizedL1Senders[l2Alias] = true;
    }

    function issueTask(bytes32 machineHash, bytes calldata input, address callback) public {
        emit TaskIssued(machineHash, input, callback);
    }

    function storeResponseHash(bytes32 responseHash) external onlyAuthorizedL1Sender {
        require(!responses[responseHash], "Response already stored");
        responses[responseHash] = true;
        emit TaskCompleted(responseHash);
    }

    function callbackWithOutputs(
        Response calldata resp,
        bytes[] calldata outputs,
        address callbackAddress
    ) public {
        bytes32 respHash = keccak256(abi.encode(resp));
        require(responses[respHash], "Response not recognized");

        bytes32[] memory outputsHashes = new bytes32[](outputs.length);
        for (uint256 i = 0; i < outputs.length; i++) {
            outputsHashes[i] = keccak256(outputs[i]);
        }
        require(
            resp.outputMerkle == LibMerkle32.merkleRoot(outputsHashes, 63),
            "Invalid output Merkle root"
        );

        ICoprocessorCallback(callbackAddress).coprocessorCallbackOutputsOnly(
            resp.machineHash,
            resp.payloadHash,
            outputs
        );
    }
}

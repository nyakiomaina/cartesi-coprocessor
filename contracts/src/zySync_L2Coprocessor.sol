// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./ICoprocessorCallback.sol";
import "./Coprocessor.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract L2Coprocessor is Coprocessor, Ownable {
    address public l1Coprocessor;

    mapping(bytes32 => bool) public responses;

    event TaskIssued(bytes32 indexed machineHash, bytes input, address callback);
    event TaskCompleted(bytes32 indexed responseHash);

    // The zkSync bootloader address
    address constant BOOTLOADER_ADDRESS = address(0x8001);

    constructor(IRegistryCoordinator _registryCoordinator)
        Coprocessor(_registryCoordinator)
    {}

    modifier onlyFromL1(address _l1Sender) {
        require(msg.sender == BOOTLOADER_ADDRESS, "Function can only be called by the bootloader");
        require(_l1Sender == l1Coprocessor, "Message not from authorized L1 contract");
        _;
    }

    function setL1Coprocessor(address _l1Coprocessor) external onlyOwner {
        l1Coprocessor = _l1Coprocessor;
    }

    function issueTask(bytes32 machineHash, bytes calldata input, address callback) public {
        emit TaskIssued(machineHash, input, callback);
    }

    function storeResponseHash(bytes32 responseHash, address _l1Sender) external onlyFromL1(_l1Sender) {
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

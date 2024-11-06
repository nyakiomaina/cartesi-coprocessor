// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./ICoprocessorCallback.sol";
import "./Coprocessor.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IL2ScrollMessenger.sol";

contract L2Coprocessor is Coprocessor, Ownable {
    IL2ScrollMessenger public immutable l2ScrollMessenger;
    address public l1Coprocessor;

    mapping(bytes32 => bool) public responses;

    event TaskIssued(bytes32 indexed machineHash, bytes input, address callback);
    event TaskCompleted(bytes32 indexed responseHash);

    constructor(IRegistryCoordinator _registryCoordinator, address _l2ScrollMessenger)
        Coprocessor(_registryCoordinator)
    {
        l2ScrollMessenger = IL2ScrollMessenger(_l2ScrollMessenger);
    }

    modifier onlyFromL1() {
        require(
            msg.sender == address(l2ScrollMessenger),
            "Caller is not the L2ScrollMessenger"
        );
        require(
            l2ScrollMessenger.xDomainMessageSender() == l1Coprocessor,
            "Message not from authorized L1 contract"
        );
        _;
    }

    function setL1Coprocessor(address _l1Coprocessor) external onlyOwner {
        l1Coprocessor = _l1Coprocessor;
    }

    function issueTask(bytes32 machineHash, bytes calldata input, address callback) public {
        emit TaskIssued(machineHash, input, callback);
    }

    function storeResponseHash(bytes32 responseHash) external onlyFromL1 {
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
            resp.outputMerkle == LibMerkle32.merkleRoot(outputsHashes, 63), "M");

        ICoprocessorCallback(callbackAddress).coprocessorCallbackOutputsOnly(
            resp.machineHash,
            resp.payloadHash,
            outputs
        );
    }
}

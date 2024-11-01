// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./ICoprocessorCallback.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {LibMerkle32} from "./LibMerkle32.sol";
import {IScrollMessenger} from "./IScrollMessenger.sol";

contract L2Coprocessor is Ownable {
    using LibMerkle32 for bytes32[];
    address public immutable ALIASED_L1_SCROLL_MESSENGER;
    address public l1Coprocessor;

    mapping(bytes32 => bool) public responses;

    event TaskIssued(bytes32 indexed machineHash, bytes input, address callback);
    event TaskCompleted(bytes32 indexed responseHash);

    constructor(address _l1ScrollMessengerAddress)
    {
        ALIASED_L1_SCROLL_MESSENGER = address(
            uint160(_l1ScrollMessengerAddress) + uint160(0x1111000000000000000000000000000000001111)
        );
    }

    modifier onlyFromL1() {
        require(
            msg.sender == ALIASED_L1_SCROLL_MESSENGER,
            "Caller is not the L2ScrollMessenger"
        );
        require(
            IScrollMessenger(msg.sender).xDomainMessageSender() == l1Coprocessor,
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

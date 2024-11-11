// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./Coprocessor.sol";
import "./IMessageService.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract L1Coprocessor is Coprocessor, Ownable {
    IMessageService public messageService;
    address public l2Coprocessor;

    event MessageSentToL2(address indexed to, uint256 fee, bytes data);

    constructor(
        address _messageService,
        IRegistryCoordinator _registryCoordinator,
        address _l2Coprocessor
    ) Coprocessor(_registryCoordinator) {
        require(_messageService != address(0), "Invalid message service address");
        require(_l2Coprocessor != address(0), "Invalid L2 Coprocessor address");
        messageService = IMessageService(_messageService);
        l2Coprocessor = _l2Coprocessor;
    }

    function setL2Coprocessor(address _l2Coprocessor) external onlyOwner {
        require(_l2Coprocessor != address(0), "Invalid L2 Coprocessor address");
        l2Coprocessor = _l2Coprocessor;
    }

    function solverCallbackSendToL2(
        Response calldata resp,
        bytes calldata quorumNumbers,
        uint32 quorumThresholdPercentage,
        uint8 thresholdDenominator,
        uint32 blockNumber,
        NonSignerStakesAndSignature calldata nonSignerStakesAndSignature,
        uint32 gasLimit
    ) external payable {
        check(
            resp,
            quorumNumbers,
            quorumThresholdPercentage,
            thresholdDenominator,
            blockNumber,
            nonSignerStakesAndSignature
        );

        bytes memory encodedResp = abi.encode(resp);
        bytes32 respHash = keccak256(encodedResp);

        bytes memory message = abi.encodeWithSignature(
            "storeResponseHash(bytes32)",
            respHash
        );

        messageService.sendMessage{value: msg.value}(
            l2Coprocessor,
            msg.value,
            message
        );

        emit MessageSentToL2(l2Coprocessor, msg.value, encodedResp);
    }
}

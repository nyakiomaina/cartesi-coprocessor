// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./Coprocessor.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@arbitrum/nitro-contracts/bridge/IInbox.sol";
import "@arbitrum/nitro-contracts/bridge/IOutbox.sol";

contract L1Coprocessor is Coprocessor, Ownable {
    IInbox public inbox;
    address public l2Coprocessor;

    constructor(address _inbox, IRegistryCoordinator _registryCoordinator)
        Coprocessor(_registryCoordinator)
    {
        inbox = IInbox(_inbox);
    }

    function setL2Coprocessor(address _l2Coprocessor) external onlyOwner {
        l2Coprocessor = _l2Coprocessor;
    }

    function solverCallbackSendToL2(
        Response calldata resp,
        bytes calldata quorumNumbers,
        uint32 quorumThresholdPercentage,
        uint8 thresholdDenominator,
        uint32 blockNumber,
        NonSignerStakesAndSignature memory nonSignerStakesAndSignature,
        uint256 maxSubmissionCost,
        uint256 gasLimit,
        uint256 maxFeePerGas
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

        bytes memory data = abi.encodeWithSignature(
            "storeResponseHash(bytes32)",
            respHash
        );

        address refundAddress = msg.sender;

        // retryable ticket
        inbox.createRetryableTicket{ value: msg.value }(
            l2Coprocessor,
            0,                     // L2 call value
            maxSubmissionCost,
            refundAddress,         // refund for submission cost
            refundAddress,         // refund for call value
            gasLimit,
            maxFeePerGas,
            data
        );
    }
}

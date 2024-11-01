// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ICoprocessorL2Sender.sol";
import "./Coprocessor.sol";

contract CoprocessorToL2 is Coprocessor{
    ICoprocessorL2Sender public l2Sender;

    constructor(IRegistryCoordinator _registryCoordinator, ICoprocessorL2Sender _l2Sender)
    Coprocessor(_registryCoordinator)
    {
        l2Sender = _l2Sender;
    }

    function setL2Sender(ICoprocessorL2Sender _l2Sender) external onlyOwner {
        l2Sender = _l2Sender;
    }

    function solverCallbackNoOutputs(
        Response calldata resp,
        bytes calldata quorumNumbers,
        uint32 quorumThresholdPercentage,
        uint8 thresholdDenominator,
        uint32 blockNumber,
        NonSignerStakesAndSignature memory nonSignerStakesAndSignature,
        uint32 gasLimit
    ) external {
        check(resp, quorumNumbers, quorumThresholdPercentage, thresholdDenominator, blockNumber, nonSignerStakesAndSignature);
        bytes memory encodedResp = abi.encode(resp);
        bytes32 respHash = keccak256(encodedResp);
        l2Sender.sendMessage(respHash, gasLimit);
    }
}

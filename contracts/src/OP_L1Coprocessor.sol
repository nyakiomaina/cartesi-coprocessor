// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@optimism/L1/IL1CrossDomainMessenger.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Coprocessor.sol";

contract L1Coprocessor is Coprocessor, Ownable {
    IL1CrossDomainMessenger public crossDomainMessenger;
    address public l2Coprocessor;

    constructor(address _crossDomainMessenger, IRegistryCoordinator _registryCoordinator)
        Coprocessor(_registryCoordinator)
    {
        crossDomainMessenger = IL1CrossDomainMessenger(_crossDomainMessenger);
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
        uint32 gasLimit
    ) external {
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

        crossDomainMessenger.sendMessage(l2Coprocessor, message, gasLimit);
    }
}

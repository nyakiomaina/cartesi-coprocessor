// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./L1_OP_Sender.sol";


contract L1Coprocessor is Ownable {
    IL1CrossDomainMessenger public crossDomainMessenger;
    address public l2Coprocessor;

    constructor(address _crossDomainMessenger)
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

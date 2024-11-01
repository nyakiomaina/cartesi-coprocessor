// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./Coprocessor.sol";
import "./IL1ScrollMessenger.sol";

contract L1Coprocessor is Coprocessor, Ownable {
    IL1ScrollMessenger public immutable l1ScrollMessenger;
    address public l2Coprocessor;

    constructor(address _l1ScrollMessenger, IRegistryCoordinator _registryCoordinator)
        Coprocessor(_registryCoordinator)
    {
        l1ScrollMessenger = IL1ScrollMessenger(_l1ScrollMessenger);
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
        uint256 gasLimit
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
            respHash,
            msg.sender
        );

        // bytes memory message = abi.encode(
        //     msg.sender,
        //     data
        // );

        // relay fee
        uint256 relayFee = l1ScrollMessenger.l2GasPriceOracle().getL2GasPrice() * gasLimit;

        require(msg.value >= relayFee, "Insufficient fee for message relay");

        l1ScrollMessenger.sendMessage{ value: msg.value }(
            l2Coprocessor,
            data,
            gasLimit
        );
    }
}

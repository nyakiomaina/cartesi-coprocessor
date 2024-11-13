// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

// Interface for the StarkNet Core Contract
interface IStarknetCore {
    function sendMessageToL2(
        uint256 toAddress,
        uint256 selector,
        uint256[] calldata payload
    ) external payable returns (bytes32);
}

struct Response {
    bytes32 machineHash;
    bytes32 payloadHash;
    bytes32 outputMerkle;
    uint256 someOtherData;
}

struct NonSignerStakesAndSignature {
    uint256[] stakes;
    bytes signature;
}

interface IRegistryCoordinator {
}

contract Coprocessor {
    IRegistryCoordinator public registryCoordinator;

    constructor(IRegistryCoordinator _registryCoordinator) {
        registryCoordinator = _registryCoordinator;
    }
}

contract L1Coprocessor is Coprocessor, Ownable {
    IStarknetCore public starknetCore;
    uint256 public l2Coprocessor; // L2 contract address on StarkNet
    uint256 public storeResponseHashSelector;

    constructor(
        address _starknetCore,
        IRegistryCoordinator _registryCoordinator,
        uint256 _l2Coprocessor,
        uint256 _storeResponseHashSelector
    ) Coprocessor(_registryCoordinator) {
        starknetCore = IStarknetCore(_starknetCore);
        l2Coprocessor = _l2Coprocessor;
        storeResponseHashSelector = _storeResponseHashSelector;
    }

    function setL2Coprocessor(uint256 _l2Coprocessor) external onlyOwner {
        l2Coprocessor = _l2Coprocessor;
    }

    function setStoreResponseHashSelector(uint256 _selector) external onlyOwner {
        storeResponseHashSelector = _selector;
    }

    function solverCallbackSendToL2(
        Response calldata resp,
        bytes calldata quorumNumbers,
        uint32 quorumThresholdPercentage,
        uint8 thresholdDenominator,
        uint32 blockNumber,
        NonSignerStakesAndSignature calldata nonSignerStakesAndSignature,
        uint256 nonce
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

        uint256;
        payload[0] = uint256(respHash);

        starknetCore.sendMessageToL2{value: msg.value}(
            l2Coprocessor,
            storeResponseHashSelector,
            payload
        );
    }
}
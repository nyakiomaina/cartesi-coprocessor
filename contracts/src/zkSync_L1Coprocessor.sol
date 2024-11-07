// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./Coprocessor.sol";
import "@matterlabs/zksync-contracts/l1/contracts/zksync/interfaces/IZkSync.sol";

contract L1Coprocessor is Coprocessor {
    IZkSync public immutable zkSync;
    address public l2Coprocessor;

    event MessageSent(bytes32 indexed txHash, address indexed zkSyncAddress, address indexed l2ContractAddress, bytes message);

    constructor(address _zkSync, IRegistryCoordinator _registryCoordinator)
        Coprocessor(_registryCoordinator)
    {
        zkSync = IZkSync(_zkSync);
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
        NonSignerStakesAndSignature calldata nonSignerStakesAndSignature,
        uint256 ergsLimit
    ) external payable returns (bytes32 txHash) {
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
            "storeResponseHash(bytes32,address)",
            respHash,
            msg.sender
        );

        uint256 requiredFee = _getRequiredL2GasFee(ergsLimit, message.length);

        require(msg.value >= requiredFee, "Insufficient fee for L2 transaction");

        txHash = zkSync.requestL2Transaction{value: msg.value}(
            l2Coprocessor,
            0,             // l2 call value
            message,
            ergsLimit,
            new bytes
        );

        emit MessageSent(txHash, address(zkSync), l2Coprocessor, message);

    }

    function _getRequiredL2GasFee(
        uint256 _ergsLimit,
        uint256 _calldataLength
    ) internal view returns (uint256) {
        uint256 l2GasPrice = zkSync.getL2GasPrice();

        uint256 baseCost = zkSync.l2TransactionBaseCost(
            tx.gasprice,
            _ergsLimit,
            _calldataLength
        );

        uint256 totalCost = baseCost + (_ergsLimit * l2GasPrice);

        return totalCost;
    }
}

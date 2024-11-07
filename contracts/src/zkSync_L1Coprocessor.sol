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
        // Perform necessary checks
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

        // Prepare calldata for L2 function call, including the original sender
        bytes memory message = abi.encodeWithSignature(
            "storeResponseHash(bytes32,address)",
            respHash,
            msg.sender // Include the original sender's address
        );

        // Estimate the required fee (in wei)
        uint256 requiredFee = _getRequiredL2GasFee(ergsLimit, message.length);

        require(msg.value >= requiredFee, "Insufficient fee for L2 transaction");

        // Send the L2 transaction request via zkSync
        txHash = zkSync.requestL2Transaction{value: msg.value}(
            l2Coprocessor, // Target contract on L2
            0,             // L2 call value (amount of ETH to send to L2 contract)
            message,       // Calldata for L2 function
            ergsLimit,     // Gas limit (ergs) for L2 execution
            new bytes // No factory dependencies
        );

        emit MessageSent(txHash, address(zkSync), l2Coprocessor, message);

    }

    function _getRequiredL2GasFee(
        uint256 _ergsLimit,
        uint256 _calldataLength
    ) internal view returns (uint256) {
        // Get the L2 gas price from zkSync
        uint256 l2GasPrice = zkSync.getL2GasPrice();

        // Calculate the base cost
        uint256 baseCost = zkSync.l2TransactionBaseCost(
            tx.gasprice,    // L1 gas price
            _ergsLimit,
            _calldataLength
        );

        // The total required fee is the base cost plus the execution cost on L2
        uint256 totalCost = baseCost + (_ergsLimit * l2GasPrice);

        return totalCost;
    }
}

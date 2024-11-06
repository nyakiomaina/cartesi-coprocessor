// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IL1ScrollMessenger {
    function sendMessage(
        address target,
        bytes calldata message,
        uint256 gasLimit
    ) external payable;

    function l2GasPriceOracle() external view returns (IL2GasPriceOracle);
}

interface IL2GasPriceOracle {
    function getL2GasPrice() external view returns (uint256);
}

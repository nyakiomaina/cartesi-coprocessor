// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IL2ScrollMessenger {
    function xDomainMessageSender() external view returns (address);
}

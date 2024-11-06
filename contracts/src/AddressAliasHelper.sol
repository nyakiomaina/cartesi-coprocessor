// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

library AddressAliasHelper {
    uint160 constant offset = uint160(0x1111000000000000000000000000000000001111);

    function applyL1ToL2Alias(address l1Address) internal pure returns (address) {
        return address(uint160(l1Address) + offset);
    }

    function undoL1ToL2Alias(address l2Address) internal pure returns (address) {
        return address(uint160(l2Address) - offset);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IL1CrossDomainMessenger {
    function sendMessage(
        address _target,
        bytes calldata _message,
        uint32 _gasLimit
    ) external;
}

interface Coprocessor {
    function issueTask(bytes32 machineHash, bytes calldata input, address callback) external;
}

contract L1TaskIssuer {
    address public l1MessengerAddress = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1; // L1CrossDomainMessenger address

    function issueTaskToL2(
        address l2CoprocessorAddress,
        bytes32 machineHash,
        bytes calldata input,
        address callback
    ) external {
        bytes memory message = abi.encodeWithSelector(
            Coprocessor.issueTask.selector,
            machineHash,
            input,
            callback
        );

        IL1CrossDomainMessenger(l1MessengerAddress).sendMessage(
            l2CoprocessorAddress,
            message,
            1000000
        );
    }
}

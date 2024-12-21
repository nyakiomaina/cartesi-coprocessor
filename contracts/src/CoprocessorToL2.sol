// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ICoprocessorL2Sender.sol";

contract CoprocessorToL2 is Ownable {
    ICoprocessorL2Sender public l2Sender;

    constructor(ICoprocessorL2Sender _l2Sender) {
        l2Sender = _l2Sender;
    }

    function setL2Sender(ICoprocessorL2Sender _l2Sender) external onlyOwner {
        l2Sender = _l2Sender;
    }

    function sendToL2(bytes32 respHash, uint32 gasLimit) external {
        l2Sender.sendMessage(respHash, gasLimit);
    }
}

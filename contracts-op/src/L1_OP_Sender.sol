// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@optimism/L1/IL1CrossDomainMessenger.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../contracts/src/ICoprocessorL2Sender.sol";

contract L1_OP_Sender is ICoprocessorL2Sender, Ownable {
    IL1CrossDomainMessenger public crossDomainMessenger;
    address public l2Coprocessor;

    constructor(address _crossDomainMessenger, address _l2Coprocessor) {
        crossDomainMessenger = IL1CrossDomainMessenger(_crossDomainMessenger);
        l2Coprocessor = _l2Coprocessor;
    }

    function setL2Coprocessor(address _l2Coprocessor) external onlyOwner {
        l2Coprocessor = _l2Coprocessor;
    }

    function sendMessage(bytes32 respHash, uint32 gasLimit) external override {
        bytes memory message = abi.encodeWithSignature("storeResponseHash(bytes32)", respHash);
        crossDomainMessenger.sendMessage(l2Coprocessor, message, gasLimit);
    }
}

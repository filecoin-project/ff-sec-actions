// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Planted defect: gas budgets copied from Ethereum.
contract Forwarder {
    function forward(address target, bytes calldata data) external returns (bool ok) {
        // ruleid: foc.solidity.hardcoded-gas
        (ok, ) = target.call{gas: 50000}(data);
    }

    function batch(address[] calldata targets) external {
        for (uint256 i = 0; i < targets.length; i++) {
            // ruleid: foc.solidity.hardcoded-gas
            if (gasleft() < 100000) {
                break;
            }
            (bool ok, ) = targets[i].call("");
            ok;
        }
    }
}

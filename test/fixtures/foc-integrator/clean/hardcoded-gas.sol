// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Clean: gas is forwarded or configurable.
contract Forwarder {
    uint256 public minimumGas;

    constructor(uint256 configuredMinimumGas) {
        minimumGas = configuredMinimumGas;
    }

    // ok: foc.solidity.hardcoded-gas
    function forward(address target, bytes calldata data) external returns (bool ok) {
        (ok, ) = target.call{value: 0}(data);
    }

    // ok: foc.solidity.hardcoded-gas
    function batch(address[] calldata targets) external {
        for (uint256 i = 0; i < targets.length; i++) {
            if (gasleft() < minimumGas) {
                break;
            }
            (bool ok, ) = targets[i].call("");
            ok;
        }
    }
}

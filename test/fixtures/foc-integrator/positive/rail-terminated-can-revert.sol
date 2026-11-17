// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IService {
    function onRailEnded(uint256 railId) external;
}

// Planted defect: railTerminated paths that can revert and trap payer funds.
contract RevertingValidator {
    address public immutable filecoinPay;
    IService public service;
    mapping(uint256 => bool) public active;

    constructor(address pay) {
        filecoinPay = pay;
    }

    function railTerminated(uint256 railId, address terminator, uint256) external {
        require(msg.sender == filecoinPay, "only Filecoin Pay");
        // ruleid: foc.solidity.rail-terminated-can-revert
        require(active[railId], "rail not active");
        // ruleid: foc.solidity.rail-terminated-can-revert
        service.onRailEnded(railId);
        if (terminator == address(0)) {
            // ruleid: foc.solidity.rail-terminated-can-revert
            revert("no terminator");
        }
        active[railId] = false;
    }
}

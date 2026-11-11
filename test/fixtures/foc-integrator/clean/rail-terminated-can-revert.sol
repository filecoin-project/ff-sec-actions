// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IService {
    function onRailEnded(uint256 railId) external;
}

// Clean: only the caller check can revert, and external calls cannot block termination.
contract SafeValidator {
    error Unauthorized();

    event RailEnded(uint256 railId, bytes data);
    event RailEndNotificationFailed(uint256 railId);

    address public immutable filecoinPay;
    IService public service;
    mapping(uint256 => bool) public active;

    constructor(address pay) {
        filecoinPay = pay;
    }

    // ok: foc.solidity.rail-terminated-can-revert
    function railTerminated(uint256 railId, address, uint256) external {
        if (msg.sender != filecoinPay) revert Unauthorized();
        active[railId] = false;
        try service.onRailEnded(railId) {} catch {
            emit RailEndNotificationFailed(railId);
        }
        emit RailEnded(railId, abi.encode(railId));
    }
}

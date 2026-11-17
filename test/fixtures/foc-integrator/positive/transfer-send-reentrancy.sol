// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Planted defect: Ethereum-style "safe" transfers that forward re-entrant gas on FEVM.
contract Refunds {
    mapping(address => uint256) public owed;

    function refund() external {
        uint256 amount = owed[msg.sender];
        // ruleid: foc.solidity.transfer-send-reentrancy
        payable(msg.sender).transfer(amount);
        owed[msg.sender] = 0;
    }

    function tryRefund(address payable account) external returns (bool) {
        // ruleid: foc.solidity.transfer-send-reentrancy
        return account.send(owed[account]);
    }
}

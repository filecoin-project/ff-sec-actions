// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

// Clean: checks-effects-interactions with a checked call, and ERC-20 token transfers.
contract Refunds {
    mapping(address => uint256) public owed;
    IERC20 public token;

    // ok: foc.solidity.transfer-send-reentrancy
    function refund() external {
        uint256 amount = owed[msg.sender];
        owed[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "refund failed");
    }

    // ok: foc.solidity.transfer-send-reentrancy
    function refundToken(address to, uint256 amount) external {
        require(token.transfer(to, amount), "token transfer failed");
    }
}

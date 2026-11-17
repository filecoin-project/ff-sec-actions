// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Planted defect: block-derived values used to pick a challenge or winner.
contract Lottery {
    function pick(uint256 count) external view returns (uint256) {
        // ruleid: foc.solidity.block-randomness
        return uint256(keccak256(abi.encode(block.prevrandao))) % count;
    }

    function challenge(uint256 leaves) external view returns (uint256) {
        // ruleid: foc.solidity.block-randomness
        return uint256(blockhash(block.number - 1)) % leaves;
    }
}

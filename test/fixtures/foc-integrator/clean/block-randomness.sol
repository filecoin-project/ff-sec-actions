// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRandomness {
    function beacon(uint256 epoch) external view returns (bytes32);
}

// Clean: randomness comes from a drand-backed source supplied by the caller.
contract Lottery {
    IRandomness public immutable randomness;

    constructor(IRandomness source) {
        randomness = source;
    }

    // ok: foc.solidity.block-randomness
    function pick(uint256 epoch, uint256 count) external view returns (uint256) {
        return uint256(keccak256(abi.encode(randomness.beacon(epoch), block.number))) % count;
    }
}

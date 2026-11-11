// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface PDPListener {
    // ok: foc.solidity.callback-missing-caller-check
    function possessionProven(uint256 dataSetId, uint256 leafCount, uint256 seed, uint256 challengeCount) external;
}

// Clean: every callback restricts its caller.
contract CheckedListener {
    address public immutable pdpVerifier;
    uint256 public proven;
    uint256 public nextChallenge;

    constructor(address verifier) {
        pdpVerifier = verifier;
    }

    modifier onlyPDPVerifier() {
        require(msg.sender == pdpVerifier, "caller is not the PDP verifier");
        _;
    }

    // ok: foc.solidity.callback-missing-caller-check
    function possessionProven(uint256 dataSetId, uint256, uint256, uint256) external {
        require(msg.sender == pdpVerifier, "caller is not the PDP verifier");
        proven = dataSetId;
    }

    // ok: foc.solidity.callback-missing-caller-check
    function nextProvingPeriod(uint256, uint256 challengeEpoch, uint256, bytes calldata)
        external
        override
        onlyPDPVerifier
    {
        nextChallenge = challengeEpoch;
    }

    // ok: foc.solidity.callback-missing-caller-check
    function dataSetCreated(uint256, address, bytes calldata) external onlyRole(keccak256("VERIFIER")) {}

    modifier onlyRole(bytes32) {
        _;
    }
}

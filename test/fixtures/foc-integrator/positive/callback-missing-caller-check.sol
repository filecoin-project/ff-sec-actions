// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Planted defect: PDP listener and Filecoin Pay validator callbacks that anyone can call.
contract UncheckedListener {
    uint256 public proven;
    uint256 public nextChallenge;

    // ruleid: foc.solidity.callback-missing-caller-check
    function possessionProven(uint256 dataSetId, uint256, uint256, uint256) external {
        proven = dataSetId;
    }

    // ruleid: foc.solidity.callback-missing-caller-check
    function nextProvingPeriod(uint256, uint256 challengeEpoch, uint256, bytes calldata) external override {
        nextChallenge = challengeEpoch;
    }

    // ruleid: foc.solidity.callback-missing-caller-check
    function validatePayment(uint256, uint256 proposedAmount, uint256, uint256, uint256)
        external
        virtual
        returns (uint256 modifiedAmount, uint256 settleUpto, string memory note)
    {
        return (proposedAmount, block.number, "");
    }
}

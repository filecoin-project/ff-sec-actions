// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MarketAPI} from "@zondax/filecoin-solidity/contracts/v0.8/MarketAPI.sol";

contract DealClient {
    function actorId() external pure returns (uint64) {
        return 5;
    }
}

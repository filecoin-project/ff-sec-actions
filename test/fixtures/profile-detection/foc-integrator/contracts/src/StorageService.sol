// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PDPListener} from "@pdp/PDPVerifier.sol";
import {IValidator} from "@fws-payments/FilecoinPayV1.sol";

abstract contract StorageService is PDPListener, IValidator {}

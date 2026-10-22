// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IRegistryBeaconSourceV1} from "rain-factory-0.2.5/src/lib/LibICloneableFactoryV6.sol";

/// Thrown for a name nothing is bound to, as the config registry does.
error TestNameNotRegistered(address authority, bytes32 name);

/// A config registry stand-in: `getV3` answers whatever value a test binds.
contract TestRegistryBeaconSource is IRegistryBeaconSourceV1 {
    mapping(address authority => mapping(bytes32 name => bytes value)) internal sValues;

    function bind(address authority, bytes32 name, bytes memory value) external {
        sValues[authority][name] = value;
    }

    function getV3(address authority, bytes32 name) external view returns (bytes memory, uint256) {
        bytes memory value = sValues[authority][name];
        if (value.length == 0) {
            revert TestNameNotRegistered(authority, name);
        }
        return (value, block.timestamp);
    }
}

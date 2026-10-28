// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IRegistryBeaconSourceV2} from "rain-factory-0.2.6/src/lib/LibICloneableFactoryV7.sol";

/// Thrown for a name nothing is bound to, as the config registry does.
error TestNameNotRegistered(address authority, bytes32 name);

/// A config registry stand-in: `getV4` answers whatever value and type a test
/// binds.
contract TestRegistryBeaconSource is IRegistryBeaconSourceV2 {
    mapping(address authority => mapping(bytes32 name => bytes value)) internal sValues;
    mapping(address authority => mapping(bytes32 name => bytes32 valueTypeHash)) internal sValueTypeHashes;

    function bind(address authority, bytes32 name, string memory valueType, bytes memory value) external {
        sValues[authority][name] = value;
        sValueTypeHashes[authority][name] = keccak256(bytes(valueType));
    }

    function getV4(address authority, bytes32 name) external view returns (bytes memory, uint256, bytes32) {
        bytes memory value = sValues[authority][name];
        if (value.length == 0) {
            revert TestNameNotRegistered(authority, name);
        }
        return (value, block.timestamp, sValueTypeHashes[authority][name]);
    }
}

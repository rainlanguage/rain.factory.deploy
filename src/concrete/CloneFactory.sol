// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

// `ICloneableFactoryV3` and `V5` are imported for the `@inheritdoc` references
// on the functions they declare; `ICloneableFactoryV7` inherits rather than
// redeclares them, so each tag must name the declaring interface and it must be
// in scope here. `ICloneableFactoryV4` documents `cloneDeterministicOpenSalt`
// and its predictor; no current rain-factory file re-exports it.
import {ICloneableFactoryV3} from "rain-factory-0.2.6/src/lib/LibICloneableFactoryV5.sol";
import {ICloneableFactoryV5, ICloneableFactoryV7} from "rain-factory-0.2.6/src/interface/ICloneableFactoryV7.sol";
import {LibICloneableFactoryV5} from "rain-factory-0.2.6/src/lib/LibICloneableFactoryV5.sol";
import {LibICloneableFactoryV7} from "rain-factory-0.2.6/src/lib/LibICloneableFactoryV7.sol";

/// @title CloneFactory
/// @notice The deployed concrete `ICloneableFactoryV7`: every function is a
/// single delegation into `LibICloneableFactoryV5` or `LibICloneableFactoryV7`
/// and nothing else. This is
/// the deploy half of the library/deploy split (rainlanguage/rain.factory#46):
/// the derivations, the guards, the atomic deploy-initialize-verify flow and
/// the typed errors all live in the library, unit tested there, and this
/// contract adds no behaviour of its own — the equivalence suite in this repo
/// holds each entry point to exactly the library's behaviour.
///
/// `msg.sender` is read inside the library and the internal functions execute
/// in this contract's call context, so the namespacing, the events and the
/// predictions all observe this contract as the factory. See
/// `ICloneableFactoryV7` for the spec of every derivation and why their salt
/// images are disjoint by construction.
contract CloneFactory is ICloneableFactoryV7 {
    /// @inheritdoc ICloneableFactoryV3
    function cloneDeterministic(address implementation, bytes calldata data, bytes32 salt) external returns (address) {
        return LibICloneableFactoryV5.cloneDeterministic(implementation, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV3
    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        external
        view
        returns (address)
    {
        return LibICloneableFactoryV5.predictDeterministicAddress(implementation, salt, deployer);
    }

    function cloneDeterministicOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        returns (address)
    {
        return LibICloneableFactoryV5.cloneDeterministicOpenSalt(implementation, data, salt);
    }

    function predictDeterministicAddressOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        view
        returns (address)
    {
        return LibICloneableFactoryV5.predictDeterministicAddressOpenSalt(implementation, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV5
    function beaconProxyDeterministicOpenSalt(address beacon, bytes calldata data, bytes32 salt)
        external
        returns (address)
    {
        return LibICloneableFactoryV5.beaconProxyDeterministicOpenSalt(beacon, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV5
    function predictBeaconProxyAddressOpenSalt(address beacon, bytes calldata data, bytes32 salt)
        external
        view
        returns (address)
    {
        return LibICloneableFactoryV5.predictBeaconProxyAddressOpenSalt(beacon, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV7
    function registryBeaconProxy(
        address registry,
        address authority,
        bytes32 beaconName,
        bytes calldata data,
        bytes32 salt
    ) external returns (address) {
        return LibICloneableFactoryV7.registryBeaconProxy(registry, authority, beaconName, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV7
    function predictRegistryBeaconProxyAddress(
        address registry,
        address authority,
        bytes32 beaconName,
        bytes calldata data,
        bytes32 salt
    ) external view returns (address) {
        return LibICloneableFactoryV7.predictRegistryBeaconProxyAddress(registry, authority, beaconName, data, salt);
    }
}

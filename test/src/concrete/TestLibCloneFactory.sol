// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

// `ICloneableFactoryV3` and `ICloneableFactoryV4` are imported for the
// `@inheritdoc` references on the functions they declare; `ICloneableFactoryV5`
// inherits rather than redeclares them, so each tag must name the declaring
// interface and it must be in scope here.
import {ICloneableFactoryV3} from "rain-factory-0.2.0/src/interface/deprecated/ICloneableFactoryV3.sol";
import {ICloneableFactoryV4} from "rain-factory-0.2.0/src/interface/deprecated/ICloneableFactoryV4.sol";
import {ICloneableFactoryV5} from "rain-factory-0.2.0/src/interface/ICloneableFactoryV5.sol";
import {LibICloneableFactoryV5} from "rain-factory-0.2.0/src/lib/LibICloneableFactoryV5.sol";

/// @title TestLibCloneFactory
/// @notice The library run bare: an external surface over
/// `LibICloneableFactoryV5` that is nothing but the same six delegations the
/// shipped `CloneFactory` makes, declared independently so the equivalence
/// suite has the library's own behaviour to hold the concrete against. If the
/// concrete ever grows behaviour beyond delegation the two diverge and the
/// equivalence tests fail; while it does not, the two compile to the same
/// runtime bytecode and the suite pins that too.
contract TestLibCloneFactory is ICloneableFactoryV5 {
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

    /// @inheritdoc ICloneableFactoryV4
    function cloneDeterministicOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        returns (address)
    {
        return LibICloneableFactoryV5.cloneDeterministicOpenSalt(implementation, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV4
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
}

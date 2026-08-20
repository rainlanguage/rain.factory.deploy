// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

// `ICloneableFactoryV3` is imported for the `@inheritdoc` references on the
// functions it declares; `ICloneableFactoryV4` inherits rather than redeclares
// them, so the tag must name V3 and V3 must be in scope here.
import {ICloneableFactoryV3} from "rain-factory-0.1.9/src/interface/ICloneableFactoryV3.sol";
import {ICloneableFactoryV4} from "rain-factory-0.1.9/src/interface/ICloneableFactoryV4.sol";
import {LibICloneableFactoryV4} from "rain-factory-0.1.9/src/lib/LibICloneableFactoryV4.sol";

/// @title TestLibCloneFactory
/// @notice The library run bare: an external surface over
/// `LibICloneableFactoryV4` that is nothing but the same four delegations the
/// shipped `CloneFactory` makes, declared independently so the equivalence
/// suite has the library's own behaviour to hold the concrete against. If the
/// concrete ever grows behaviour beyond delegation the two diverge and the
/// equivalence tests fail; while it does not, the two compile to the same
/// runtime bytecode and the suite pins that too.
contract TestLibCloneFactory is ICloneableFactoryV4 {
    /// @inheritdoc ICloneableFactoryV3
    function cloneDeterministic(address implementation, bytes calldata data, bytes32 salt) external returns (address) {
        return LibICloneableFactoryV4.cloneDeterministic(implementation, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV3
    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        external
        view
        returns (address)
    {
        return LibICloneableFactoryV4.predictDeterministicAddress(implementation, salt, deployer);
    }

    /// @inheritdoc ICloneableFactoryV4
    function cloneDeterministicOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        returns (address)
    {
        return LibICloneableFactoryV4.cloneDeterministicOpenSalt(implementation, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV4
    function predictDeterministicAddressOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        view
        returns (address)
    {
        return LibICloneableFactoryV4.predictDeterministicAddressOpenSalt(implementation, data, salt);
    }
}

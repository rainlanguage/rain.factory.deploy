// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

// `ICloneableFactoryV3` is imported for the `@inheritdoc` references on the
// functions it declares; `ICloneableFactoryV4` inherits rather than redeclares
// them, so the tag must name V3 and V3 must be in scope here.
import {ICloneableFactoryV3} from "rain-factory-0.1.9/src/interface/ICloneableFactoryV3.sol";
import {ICloneableFactoryV4} from "rain-factory-0.1.9/src/interface/ICloneableFactoryV4.sol";
import {LibICloneableFactoryV4} from "rain-factory-0.1.9/src/lib/LibICloneableFactoryV4.sol";

/// @title CloneFactory
/// @notice The deployed concrete `ICloneableFactoryV4`: every function is a
/// single delegation into `LibICloneableFactoryV4` and nothing else. This is
/// the deploy half of the library/deploy split (rainlanguage/rain.factory#46):
/// the derivations, the guards, the atomic clone-initialize-verify flow and
/// the typed errors all live in the library, unit tested there, and this
/// contract adds no behaviour of its own — the equivalence suite in this repo
/// holds each entry point to exactly the library's behaviour.
///
/// `msg.sender` is read inside the library and the internal functions execute
/// in this contract's call context, so the namespacing, the `NewClone` event
/// and the predictions all observe this contract as the factory. See
/// `ICloneableFactoryV4` for the spec of both derivations and why their salt
/// images are disjoint by construction.
contract CloneFactory is ICloneableFactoryV4 {
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

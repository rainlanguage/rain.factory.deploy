// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IAddressRegistryV1} from "rain-deploy-0.1.6/src/interface/IAddressRegistryV1.sol";

/// @dev PLACEHOLDER ROOT AUTHORITY. THIS IS NOT A REAL ROOT.
///
/// The only account that may bind a name. It is a compile-time constant, not
/// storage, so it can never be rotated, and it is part of the creation code, so
/// changing it changes the deterministic deploy address and code hash of
/// `AddressRegistry` on every network.
///
/// A human MUST replace this value with the intended root before any deploy-pin
/// snapshot is generated for this contract, and the pins in `rain-deploy`'s
/// `LibAddressRegistry` MUST be regenerated from the resulting creation code.
address constant ADDRESS_REGISTRY_ROOT = address(0xdeaDDeADDEaDdeaDdEAddEADDEAdDeadDEADDEaD);

/// @title AddressRegistry
/// @notice The whole of `IAddressRegistryV1`: an immutable root authority binds
/// a `bytes32` name that is unbound, anyone reads a name that is bound, and a
/// read of an unbound name reverts.
///
/// There is deliberately nothing else. No rotation, no removal, no upgrade, no
/// pause, no admin surface, and no reader that returns the zero address for an
/// unbound name. Every one of those would turn a binding from a constant back
/// into a value that can move, which is the single property the registry
/// exists to provide.
///
/// The storage mapping is `internal` rather than `public` for that reason: a
/// public mapping's generated getter answers an unbound name with the zero
/// address, which is exactly the silent failure `get` reverts to prevent.
contract AddressRegistry is IAddressRegistryV1 {
    /// The bindings. Not `public`: the only reader is `get`, which reverts on an
    /// unbound name. A name maps to the zero address if and only if it is
    /// unbound, which is why `register` rejects the zero address.
    mapping(bytes32 name => address account) internal sAddresses;

    /// @inheritdoc IAddressRegistryV1
    function register(bytes32 name, address account) external {
        if (msg.sender != ADDRESS_REGISTRY_ROOT) {
            revert NotRoot(msg.sender);
        }
        if (account == address(0)) {
            revert ZeroAccount(name);
        }
        address registered = sAddresses[name];
        // Write-once. Root has no more authority here than anyone else: an
        // existing binding is never overwritten, not even with the same
        // address.
        if (registered != address(0)) {
            revert NameAlreadyRegistered(name, registered);
        }
        sAddresses[name] = account;
        emit Register(name, account);
    }

    /// @inheritdoc IAddressRegistryV1
    function get(bytes32 name) external view returns (address account) {
        account = sAddresses[name];
        if (account == address(0)) {
            revert NameNotRegistered(name);
        }
    }
}

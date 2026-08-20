// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain-factory-0.1.9/src/interface/ICloneableV2.sol";
import {ICloneableFactoryV3} from "rain-factory-0.1.9/src/interface/ICloneableFactoryV3.sol";
import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";

/// Thrown when an implementation has zero code size which is always a mistake.
error ZeroImplementationCodeSize();

/// Thrown when initialization fails.
error InitializationFailed();

/// @title CloneFactory
/// @notice A fairly minimal implementation of `ICloneableFactoryV3` that uses
/// Open Zeppelin `Clones` to create EIP1167 clones of a reference bytecode. The
/// reference bytecode MUST implement `ICloneableV2`.
///
/// `cloneDeterministic` deploys via `CREATE2` at a pre-computable address
/// (`predictDeterministicAddress`), namespacing the caller-supplied salt by
/// `msg.sender` so a caller's `(implementation, salt)` address cannot be squatted
/// by another account.
contract CloneFactory is ICloneableFactoryV3 {
    /// @inheritdoc ICloneableFactoryV3
    function cloneDeterministic(address implementation, bytes calldata data, bytes32 salt) external returns (address) {
        _requireImplementationCode(implementation);
        // CREATE2 clone at a salt namespaced by the caller (see `_effectiveSalt`).
        address child = Clones.cloneDeterministic(implementation, _effectiveSalt(msg.sender, salt));
        return _initializeClone(implementation, child, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV3
    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        external
        view
        returns (address)
    {
        return Clones.predictDeterministicAddress(implementation, _effectiveSalt(deployer, salt), address(this));
    }

    /// @dev The CREATE2 salt actually used: the caller-supplied `salt` namespaced
    /// by the deploying account. Prevents a caller's `(implementation, salt)`
    /// address being front-run/squatted by another account, while still letting a
    /// single caller mint many clones of one implementation via distinct salts.
    /// Equal to `keccak256(abi.encode(deployer, salt))`, hashed directly in the
    /// scratch space; `deployer` is a clean address so it occupies a full word.
    function _effectiveSalt(address deployer, bytes32 salt) internal pure returns (bytes32 effectiveSalt) {
        assembly ("memory-safe") {
            mstore(0, deployer)
            mstore(0x20, salt)
            effectiveSalt := keccak256(0, 0x40)
        }
    }

    /// @dev Reverts with a clear error if `implementation` has no code.
    function _requireImplementationCode(address implementation) internal view {
        if (implementation.code.length == 0) {
            revert ZeroImplementationCodeSize();
        }
    }

    /// @dev Emit `NewClone` (with the caller `salt` and init `data`, so the event
    /// fully describes the deterministic deploy) and run the mandatory
    /// `ICloneableV2.initialize` check.
    function _initializeClone(address implementation, address child, bytes calldata data, bytes32 salt)
        internal
        returns (address)
    {
        emit NewClone(msg.sender, implementation, child, salt, data);
        // Checking the return value of initialize is mandatory as per
        // ICloneableFactoryV3.
        if (ICloneableV2(child).initialize(data) != ICLONEABLE_V2_SUCCESS) {
            revert InitializationFailed();
        }
        return child;
    }
}

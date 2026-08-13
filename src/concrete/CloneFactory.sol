// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain-factory-0.1.7/src/interface/ICloneableV2.sol";
// `ICloneableFactoryV3` is imported for the `@inheritdoc` references on the
// functions it declares; `ICloneableFactoryV4` inherits rather than redeclares
// them, so the tag must name V3 and V3 must be in scope here.
import {ICloneableFactoryV3} from "rain-factory-0.1.7/src/interface/ICloneableFactoryV3.sol";
import {
    ICloneableFactoryV4,
    ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN
} from "rain-factory-0.1.7/src/interface/ICloneableFactoryV4.sol";
import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";

/// Thrown when an implementation has zero code size which is always a mistake.
error ZeroImplementationCodeSize();

/// Thrown when initialization fails.
error InitializationFailed();

/// @title CloneFactory
/// @notice A fairly minimal implementation of `ICloneableFactoryV4` that uses
/// Open Zeppelin `Clones` to create EIP1167 clones of a reference bytecode. The
/// reference bytecode MUST implement `ICloneableV2`.
///
/// Two deterministic entry points, both `CREATE2`, differing only in the salt
/// they derive and therefore in what the clone's address commits to:
///
/// - `cloneDeterministic` / `predictDeterministicAddress` namespace the
///   caller-supplied salt by `msg.sender` (see `_effectiveSalt`), so the
///   address commits to WHO deployed and a caller's `(implementation, salt)`
///   address cannot be squatted by another account. `data` is outside the
///   derivation.
/// - `cloneDeterministicOpenSalt` / `predictDeterministicAddressOpenSalt` hash
///   the caller-supplied salt together with `data` under a fixed domain
///   separator (see `_effectiveOpenSalt`), so the address commits to WHAT was
///   deployed and to nothing caller-derived. Anyone can deploy it, and everyone
///   who does deploys the same contract initialized with the same bytes,
///   because varying either input lands somewhere else.
///
/// # The two images MUST be disjoint, and this contract is where that holds
///
/// `ICloneableFactoryV4` states as a MUST NOT on the factory that no other
/// entry point may `CREATE2` at an effective salt in the open-salt derivation's
/// image with caller-supplied `data`. `cloneDeterministic` is exactly such an
/// entry point, so the separation is structural rather than incidental:
/// `_effectiveSalt` hashes 64 bytes whose first word is a left-padded address,
/// `_effectiveOpenSalt` hashes 96 bytes whose first word is
/// `ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN`.
///
/// Drop the domain word and both preimages become 64 bytes led by a word an
/// attacker controls, at which point an account `A` reaches EVERY open-salt
/// address whose `salt` equals `bytes32(uint256(uint160(A)))` — the abi-encoding
/// of `A` — simply by calling `cloneDeterministic(implementation, evilData,
/// keccak256(data))`. No preimage search, just a choice of salt. That is what
/// the domain word buys, and it is why a third entry point that hashes to
/// either shape MUST NOT be added here.
contract CloneFactory is ICloneableFactoryV4 {
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

    /// @inheritdoc ICloneableFactoryV4
    function cloneDeterministicOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        returns (address)
    {
        _requireImplementationCode(implementation);
        // CREATE2 clone at a salt derived from `(salt, data)` and nothing
        // caller-derived (see `_effectiveOpenSalt`), so every caller lands on
        // the same address and every address pins its own `data`.
        address child = Clones.cloneDeterministic(implementation, _effectiveOpenSalt(data, salt));
        return _initializeClone(implementation, child, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV4
    function predictDeterministicAddressOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        view
        returns (address)
    {
        return Clones.predictDeterministicAddress(implementation, _effectiveOpenSalt(data, salt), address(this));
    }

    /// @dev The CREATE2 salt actually used: the caller-supplied `salt` namespaced
    /// by the deploying account. Prevents a caller's `(implementation, salt)`
    /// address being front-run/squatted by another account, while still letting a
    /// single caller mint many clones of one implementation via distinct salts.
    /// Equal to `keccak256(abi.encode(deployer, salt))`, hashed directly in the
    /// scratch space; `deployer` is a clean address so it occupies a full word.
    ///
    /// The 64-byte preimage led by a left-padded address is half of the image
    /// disjointness described on this contract — changing its shape is a change
    /// to the open-salt guarantee as much as to this one.
    function _effectiveSalt(address deployer, bytes32 salt) internal pure returns (bytes32 effectiveSalt) {
        assembly ("memory-safe") {
            mstore(0, deployer)
            mstore(0x20, salt)
            effectiveSalt := keccak256(0, 0x40)
        }
    }

    /// @dev The CREATE2 salt actually used by the open-salt entry points, fixed
    /// by `ICloneableFactoryV4` as
    /// `keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)))`
    /// so third parties can recompute it. Written as that expression rather
    /// than as scratch-space assembly because the preimage is three words and
    /// does not fit the scratch space.
    ///
    /// Hashing `data` in is what makes the deployer's absence safe: different
    /// `data` is a different address, so a front-runner either deploys exactly
    /// what was intended or deploys their own contract at their own expense
    /// somewhere else. The domain word is what keeps this image disjoint from
    /// `_effectiveSalt`'s — see the note on this contract.
    function _effectiveOpenSalt(bytes calldata data, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)));
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
        // ICloneableFactoryV3 and ICloneableFactoryV4.
        if (ICloneableV2(child).initialize(data) != ICLONEABLE_V2_SUCCESS) {
            revert InitializationFailed();
        }
        return child;
    }
}

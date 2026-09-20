// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";

import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";
import {LibExtrospectERC1167Proxy} from "rain-extrospection-0.1.1/src/lib/LibExtrospectERC1167Proxy.sol";
import {ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN} from "rain-factory-0.1.9/src/interface/ICloneableFactoryV4.sol";
import {CloneFactory} from "../../../src/concrete/CloneFactory.sol";
import {TestCloneable} from "./TestCloneable.sol";

/// @title CloneFactoryCloneDeterministicOpenSaltTest
/// @notice A test suite for `CloneFactory`'s `cloneDeterministicOpenSalt` /
/// `predictDeterministicAddressOpenSalt` — the counterpart to
/// `CloneFactoryCloneDeterministicTest`, which covers only the namespaced pair.
///
/// Every expectation here is built from the `ICloneableFactoryV4` SPEC and from
/// OpenZeppelin `Clones` — a foreign implementation of the same EIP-1167
/// standard — never from `LibICloneableFactoryV4`. That is the point of the
/// suite. The equivalence suite already holds the concrete to the library, but
/// it states every open-salt expectation in terms of the library's own
/// `effectiveOpenSalt`, so it moves with the derivation rather than checking
/// it; the namespaced pair has had an independent oracle since
/// `testCloneDeterministicSaltIsDomainTaggedHash` and this gives the open-salt
/// pair the same.
///
/// The revert paths (`ZeroImplementationCodeSize`, `InitializationFailed`) and
/// the `NewClone` event are deliberately NOT restated here: the equivalence
/// suite already asserts them for this entry point, field for field.
contract CloneFactoryCloneDeterministicOpenSaltTest is Test {
    /// The `CloneFactory` instance under test. Stateless, so reused everywhere.
    CloneFactory internal immutable I_CLONE_FACTORY;

    constructor() {
        I_CLONE_FACTORY = new CloneFactory();
    }

    /// The effective CREATE2 salt is exactly the derivation
    /// `ICloneableFactoryV4` pins:
    /// `keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)))`,
    /// so an off-chain caller can reproduce the predicted address. Pinned
    /// against OZ `Clones` under an independently constructed salt, so the test
    /// does not restate the library's arithmetic back to itself.
    function testCloneDeterministicOpenSaltIsDomainTaggedHash(address implementation, bytes memory data, bytes32 salt)
        external
        view
    {
        bytes32 effectiveSalt = keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)));
        address expected = Clones.predictDeterministicAddress(implementation, effectiveSalt, address(I_CLONE_FACTORY));
        assertEq(I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, data, salt), expected);
    }

    /// The deployed clone lands at the predicted address, is an EIP1167 proxy of
    /// the implementation, and is initialized with the data — the concrete's two
    /// open-salt entry points held to each other, with no library in between.
    function testCloneDeterministicOpenSaltMatchesPredict(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address predicted = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(address(implementation), data, salt);
        address child = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);

        assertEq(child, predicted);
        (bool isProxy, address proxyImplementation) = LibExtrospectERC1167Proxy.isERC1167Proxy(child.code);
        assertEq(isProxy, true);
        assertEq(proxyImplementation, address(implementation));
        assertEq(TestCloneable(child).sData(), data);
    }

    /// The DEFINING property of the open-salt derivation, and the exact opposite
    /// of the namespaced one: the address does not depend on the caller, so
    /// every account reaches the same address for the same
    /// `(implementation, data, salt)`. The spec forbids the factory mixing
    /// `msg.sender`, `tx.origin` or any other caller-derived value in.
    function testCloneDeterministicOpenSaltIsSenderIndependent(
        bytes32 salt,
        bytes memory data,
        address alice,
        address bob
    ) external {
        vm.assume(alice != bob);
        TestCloneable implementation = new TestCloneable();

        address predicted = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(address(implementation), data, salt);

        uint256 snapshot = vm.snapshotState();

        vm.prank(alice);
        address childAlice = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);

        vm.revertToState(snapshot);

        vm.prank(bob);
        address childBob = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);

        assertEq(childAlice, predicted);
        assertEq(childBob, predicted);
    }

    /// `data` is INSIDE the derivation, which is what makes an open-salt address
    /// safe to pin without sender namespacing: a caller passing different `data`
    /// lands somewhere else rather than occupying the address somebody pinned.
    function testCloneDeterministicOpenSaltCommitsToData(
        address implementation,
        bytes32 salt,
        bytes memory data,
        bytes memory dataOther
    ) external view {
        vm.assume(keccak256(data) != keccak256(dataOther));

        assertTrue(
            I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, data, salt)
                != I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, dataOther, salt)
        );
    }

    /// Distinct salts yield distinct clones of the same implementation for the
    /// same initialization data — many clones per impl.
    function testCloneDeterministicOpenSaltManyClonesPerImpl(bytes32 salt1, bytes32 salt2, bytes memory data) external {
        vm.assume(salt1 != salt2);
        TestCloneable implementation = new TestCloneable();

        address child1 = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt1);
        address child2 = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt2);
        assertTrue(child1 != child2);
    }
}

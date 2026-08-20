// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.2/src/Test.sol";

import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";
import {LibExtrospectERC1167Proxy} from "rain-extrospection-0.1.1/src/lib/LibExtrospectERC1167Proxy.sol";
import {ICLONEABLE_V2_SUCCESS} from "rain-factory-0.1.5/src/interface/ICloneableV2.sol";
import {CloneFactory, ZeroImplementationCodeSize, InitializationFailed} from "../../../src/concrete/CloneFactory.sol";
import {TestCloneable} from "./TestCloneable.sol";
import {TestCloneableFailure} from "./TestCloneableFailure.sol";

/// @title CloneFactoryCloneDeterministicTest
/// @notice A test suite for `CloneFactory`'s `cloneDeterministic` /
/// `predictDeterministicAddress` functions.
contract CloneFactoryCloneDeterministicTest is Test {
    /// The `CloneFactory` instance under test. Stateless, so reused everywhere.
    CloneFactory internal immutable I_CLONE_FACTORY;

    constructor() {
        I_CLONE_FACTORY = new CloneFactory();
    }

    /// The effective CREATE2 salt is exactly `keccak256(abi.encode(deployer,
    /// salt))`, so an off-chain caller can reproduce the predicted address from
    /// the two inputs. Pins the salt derivation — including the scratch-space
    /// assembly that computes it — against OZ's own prediction under that salt.
    function testCloneDeterministicSaltIsAbiEncodeHash(address implementation, bytes32 salt, address deployer)
        external
        view
    {
        bytes32 effectiveSalt = keccak256(abi.encode(deployer, salt));
        address expected = Clones.predictDeterministicAddress(implementation, effectiveSalt, address(I_CLONE_FACTORY));
        assertEq(I_CLONE_FACTORY.predictDeterministicAddress(implementation, salt, deployer), expected);
    }

    /// The deployed clone lands at the predicted address, is an EIP1167 proxy of
    /// the implementation, and is initialized with the data. `predict` therefore
    /// lets a caller pin the address before deploying.
    function testCloneDeterministicMatchesPredict(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address predicted = I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, address(this));
        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);

        assertEq(child, predicted);
        (bool isProxy, address proxyImplementation) = LibExtrospectERC1167Proxy.isERC1167Proxy(child.code);
        assertEq(isProxy, true);
        assertEq(proxyImplementation, address(implementation));
        assertEq(TestCloneable(child).sData(), data);
    }

    /// Distinct salts yield distinct clones of the same implementation — many
    /// clones per impl (unlike a salt-free / one-per-impl deterministic deploy).
    function testCloneDeterministicManyClonesPerImpl(bytes32 salt1, bytes32 salt2, bytes memory data) external {
        vm.assume(salt1 != salt2);
        TestCloneable implementation = new TestCloneable();

        address child1 = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt1);
        address child2 = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt2);
        assertTrue(child1 != child2);
    }

    /// The same `(implementation, salt)` from different callers yields different
    /// addresses: the salt is namespaced by `msg.sender`, so no caller can squat
    /// or front-run another's address. `predict` reflects the deployer.
    function testCloneDeterministicSenderScoped(bytes32 salt, bytes memory data, address alice, address bob) external {
        vm.assume(alice != bob);
        TestCloneable implementation = new TestCloneable();

        address predictedAlice = I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, alice);
        address predictedBob = I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, bob);
        assertTrue(predictedAlice != predictedBob);

        vm.prank(alice);
        address childAlice = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        assertEq(childAlice, predictedAlice);

        vm.prank(bob);
        address childBob = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        assertEq(childBob, predictedBob);

        assertTrue(childAlice != childBob);
    }

    /// `NewClone` is emitted with the caller, implementation and child.
    function testCloneDeterministicEvent(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        vm.recordLogs();
        address child = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 1);
        assertEq(entries[0].topics[0], bytes32(uint256(keccak256("NewClone(address,address,address,bytes32,bytes)"))));
        assertEq(entries[0].data, abi.encode(address(this), address(implementation), child, salt, data));
    }

    /// An implementation that initializes to a non-success code reverts
    /// `InitializationFailed`.
    function testCloneDeterministicInitializeFailureFails(bytes32 notSuccess, bytes32 salt) external {
        vm.assume(notSuccess != ICLONEABLE_V2_SUCCESS);
        TestCloneableFailure implementation = new TestCloneableFailure();

        vm.expectRevert(abi.encodeWithSelector(InitializationFailed.selector));
        I_CLONE_FACTORY.cloneDeterministic(address(implementation), abi.encode(notSuccess), salt);
    }

    /// A zero-code implementation reverts `ZeroImplementationCodeSize`.
    function testCloneDeterministicZeroImplementationCodeSize(address implementation, bytes memory data, bytes32 salt)
        external
    {
        vm.assume(implementation.code.length == 0);
        vm.expectRevert(abi.encodeWithSelector(ZeroImplementationCodeSize.selector));
        I_CLONE_FACTORY.cloneDeterministic(implementation, data, salt);
    }
}

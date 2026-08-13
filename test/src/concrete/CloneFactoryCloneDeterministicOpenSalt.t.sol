// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.1/src/Test.sol";

import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";
import {Errors} from "@openzeppelin-contracts-5.6.1/utils/Errors.sol";
import {LibExtrospectERC1167Proxy} from "rain-extrospection-0.1.1/src/lib/LibExtrospectERC1167Proxy.sol";
import {ICLONEABLE_V2_SUCCESS} from "rain-factory-0.1.7/src/interface/ICloneableV2.sol";
import {CloneFactory, ZeroImplementationCodeSize, InitializationFailed} from "../../../src/concrete/CloneFactory.sol";
import {TestCloneable} from "./TestCloneable.sol";
import {TestCloneableFailure} from "./TestCloneableFailure.sol";

/// @title CloneFactoryCloneDeterministicOpenSaltTest
/// @notice A test suite for `CloneFactory`'s `cloneDeterministicOpenSalt` /
/// `predictDeterministicAddressOpenSalt` functions. The defining property is
/// that the deployer is NOT in the address derivation, which is the exact
/// opposite of what `cloneDeterministic` guarantees, so the two derivations are
/// also tested against each other here.
contract CloneFactoryCloneDeterministicOpenSaltTest is Test {
    /// The `CloneFactory` instance under test. Stateless, so reused everywhere.
    CloneFactory internal immutable I_CLONE_FACTORY;

    constructor() {
        I_CLONE_FACTORY = new CloneFactory();
    }

    /// The `CREATE2` salt is the caller-supplied salt VERBATIM — no hashing, no
    /// namespacing, nothing mixed in. Pins the derivation against OZ's own
    /// prediction under the raw salt, so an off-chain caller can reproduce the
    /// address from `(implementation, salt, factory)` alone.
    function testCloneDeterministicOpenSaltSaltIsVerbatim(address implementation, bytes32 salt) external view {
        address expected = Clones.predictDeterministicAddress(implementation, salt, address(I_CLONE_FACTORY));
        assertEq(I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, salt), expected);
    }

    /// The deployed clone lands at the predicted address, is an EIP1167 proxy of
    /// the implementation, and is initialized with the data. `predict` therefore
    /// lets a caller pin the address before deploying.
    function testCloneDeterministicOpenSaltMatchesPredict(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address predicted = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(address(implementation), salt);
        address child = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);

        assertEq(child, predicted);
        (bool isProxy, address proxyImplementation) = LibExtrospectERC1167Proxy.isERC1167Proxy(child.code);
        assertEq(isProxy, true);
        assertEq(proxyImplementation, address(implementation));
        assertEq(TestCloneable(child).sData(), data);
    }

    /// THE POINT OF THIS VARIANT. The same `(implementation, salt)` from two
    /// different callers lands on the SAME address. State is snapshotted and
    /// rolled back between the two deploys so both callers genuinely deploy from
    /// the same starting state — the addresses are compared, not merely
    /// predicted. This is exactly what `cloneDeterministic` forbids, so an
    /// address deployed here survives its original deployer being retired: any
    /// other account can re-establish it on another chain.
    function testCloneDeterministicOpenSaltCallerIndependent(
        bytes32 salt,
        bytes memory data,
        address alice,
        address bob
    ) external {
        vm.assume(alice != bob);
        TestCloneable implementation = new TestCloneable();

        address predicted = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(address(implementation), salt);

        uint256 snapshot = vm.snapshotState();

        vm.prank(alice);
        address childAlice = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);

        vm.revertToState(snapshot);

        vm.prank(bob);
        address childBob = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);

        assertEq(childAlice, childBob);
        assertEq(childAlice, predicted);
    }

    /// The prediction takes no deployer, so it cannot vary with one. Predicting
    /// the same `(implementation, salt)` from two different callers returns the
    /// same address — a caller pinning an address offchain does not need to know
    /// who will deploy it.
    function testCloneDeterministicOpenSaltPredictCallerIndependent(
        address implementation,
        bytes32 salt,
        address alice,
        address bob
    ) external {
        vm.assume(alice != bob);

        vm.prank(alice);
        address predictedAlice = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, salt);

        vm.prank(bob);
        address predictedBob = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, salt);

        assertEq(predictedAlice, predictedBob);
    }

    /// The two derivations are disjoint: for any `(implementation, salt,
    /// deployer)` the open-salt address is not the sender-namespaced address.
    /// So adding the open variant cannot reach, block or collide with an address
    /// that `cloneDeterministic` promised to a specific caller.
    function testCloneDeterministicOpenSaltDiffersFromSenderNamespaced(
        address implementation,
        bytes32 salt,
        address deployer
    ) external view {
        address open = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, salt);
        address namespaced = I_CLONE_FACTORY.predictDeterministicAddress(implementation, salt, deployer);
        assertTrue(open != namespaced);
    }

    /// REGRESSION GUARD on the guarantee that must not break. Taking a salt via
    /// the open variant does not consume it for `cloneDeterministic`: the same
    /// caller can still deploy at the same `salt` through the namespaced
    /// derivation, at the address it always predicted, and both clones exist
    /// independently.
    function testCloneDeterministicOpenSaltDoesNotConsumeNamespacedSalt(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        address predictedNamespaced =
            I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), salt, address(this));

        address childOpen = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);
        address childNamespaced = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);

        assertEq(childNamespaced, predictedNamespaced);
        assertTrue(childOpen != childNamespaced);
        assertTrue(childOpen.code.length > 0);
        assertTrue(childNamespaced.code.length > 0);
    }

    /// Distinct salts yield distinct clones of the same implementation — many
    /// clones per impl, as with the namespaced variant.
    function testCloneDeterministicOpenSaltManyClonesPerImpl(bytes32 salt1, bytes32 salt2, bytes memory data) external {
        vm.assume(salt1 != salt2);
        TestCloneable implementation = new TestCloneable();

        address child1 = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt1);
        address child2 = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt2);
        assertTrue(child1 != child2);
    }

    /// A second deploy at an already-taken open salt REVERTS. It does not
    /// silently return the existing clone, so a caller can never mistake
    /// somebody else's already-initialized contract for their own fresh deploy.
    /// Squatting is therefore loud at the point of deploy, even though it is
    /// unrecoverable after it.
    function testCloneDeterministicOpenSaltSecondDeployReverts(
        bytes32 salt,
        bytes memory dataFirst,
        bytes memory dataSecond,
        address alice,
        address bob
    ) external {
        vm.assume(alice != bob);
        TestCloneable implementation = new TestCloneable();

        vm.prank(alice);
        address child = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), dataFirst, salt);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.FailedDeployment.selector));
        I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), dataSecond, salt);

        // The first deploy's state is untouched by the failed second one.
        assertEq(TestCloneable(child).sData(), dataFirst);
    }

    /// `NewClone` is emitted with the caller, implementation, child, salt and
    /// data. The event is shared with `cloneDeterministic` and carries the RAW
    /// salt in both cases, so an indexer must know which entry point was called
    /// to recompute the address — the `clone` field is the authoritative address.
    function testCloneDeterministicOpenSaltEvent(bytes32 salt, bytes memory data) external {
        TestCloneable implementation = new TestCloneable();

        vm.recordLogs();
        address child = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 1);
        assertEq(entries[0].topics[0], bytes32(uint256(keccak256("NewClone(address,address,address,bytes32,bytes)"))));
        assertEq(entries[0].data, abi.encode(address(this), address(implementation), child, salt, data));
    }

    /// An implementation that initializes to a non-success code reverts
    /// `InitializationFailed`, so clone-and-initialize stays atomic and the
    /// address is left free rather than occupied by an uninitialized clone.
    function testCloneDeterministicOpenSaltInitializeFailureFails(bytes32 notSuccess, bytes32 salt) external {
        vm.assume(notSuccess != ICLONEABLE_V2_SUCCESS);
        TestCloneableFailure implementation = new TestCloneableFailure();

        address predicted = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(address(implementation), salt);

        vm.expectRevert(abi.encodeWithSelector(InitializationFailed.selector));
        I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), abi.encode(notSuccess), salt);

        assertEq(predicted.code.length, 0);
    }

    /// A zero-code implementation reverts `ZeroImplementationCodeSize`.
    function testCloneDeterministicOpenSaltZeroImplementationCodeSize(
        address implementation,
        bytes memory data,
        bytes32 salt
    ) external {
        vm.assume(implementation.code.length == 0);
        vm.expectRevert(abi.encodeWithSelector(ZeroImplementationCodeSize.selector));
        I_CLONE_FACTORY.cloneDeterministicOpenSalt(implementation, data, salt);
    }
}

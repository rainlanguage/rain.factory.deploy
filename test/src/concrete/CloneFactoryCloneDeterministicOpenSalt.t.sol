// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.1/src/Test.sol";

import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";
import {Errors} from "@openzeppelin-contracts-5.6.1/utils/Errors.sol";
import {LibExtrospectERC1167Proxy} from "rain-extrospection-0.1.1/src/lib/LibExtrospectERC1167Proxy.sol";
import {ICLONEABLE_V2_SUCCESS} from "rain-factory-0.1.7/src/interface/ICloneableV2.sol";
import {ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN} from "rain-factory-0.1.7/src/interface/ICloneableFactoryV4.sol";
import {CloneFactory, ZeroImplementationCodeSize, InitializationFailed} from "../../../src/concrete/CloneFactory.sol";
import {TestCloneable} from "./TestCloneable.sol";
import {TestCloneableFailure} from "./TestCloneableFailure.sol";

/// @title CloneFactoryCloneDeterministicOpenSaltTest
/// @notice A test suite for `CloneFactory`'s `cloneDeterministicOpenSalt` /
/// `predictDeterministicAddressOpenSalt` functions. The defining property is
/// that the address commits to WHAT is deployed — `(implementation, data,
/// salt)` — and to nothing about WHO deploys it, which is the exact opposite of
/// what `cloneDeterministic` guarantees. So the two derivations are also tested
/// against each other here, including the one squat that the domain separator
/// exists to close.
contract CloneFactoryCloneDeterministicOpenSaltTest is Test {
    /// The `CloneFactory` instance under test. Stateless, so reused everywhere.
    CloneFactory internal immutable I_CLONE_FACTORY;

    constructor() {
        I_CLONE_FACTORY = new CloneFactory();
    }

    /// The effective `CREATE2` salt is exactly the derivation
    /// `ICloneableFactoryV4` fixes:
    /// `keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)))`.
    /// Pinned against OZ's own prediction under an independently constructed
    /// salt, so an off-chain caller can reproduce the address from
    /// `(implementation, data, salt, factory)` alone and the test does not
    /// restate `CloneFactory`'s arithmetic back to itself.
    function testCloneDeterministicOpenSaltIsDomainTaggedHash(address implementation, bytes memory data, bytes32 salt)
        external
        view
    {
        bytes32 effectiveSalt = keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)));
        address expected = Clones.predictDeterministicAddress(implementation, effectiveSalt, address(I_CLONE_FACTORY));
        assertEq(I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, data, salt), expected);
    }

    /// The deployed clone lands at the predicted address, is an EIP1167 proxy of
    /// the implementation, and is initialized with the data. `predict` therefore
    /// lets a caller pin the address before deploying — but only once `data` is
    /// final, since `data` is in the derivation.
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

    /// THE POINT OF THIS VARIANT. The same `(implementation, data, salt)` from
    /// two different callers lands on the SAME address. State is snapshotted and
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

        address predicted = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(address(implementation), data, salt);

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
    /// the same `(implementation, data, salt)` from two different callers
    /// returns the same address — a caller pinning an address offchain does not
    /// need to know who will deploy it.
    function testCloneDeterministicOpenSaltPredictCallerIndependent(
        address implementation,
        bytes memory data,
        bytes32 salt,
        address alice,
        address bob
    ) external {
        vm.assume(alice != bob);

        vm.prank(alice);
        address predictedAlice = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, data, salt);

        vm.prank(bob);
        address predictedBob = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, data, salt);

        assertEq(predictedAlice, predictedBob);
    }

    /// `data` IS IN THE DERIVATION, which is what makes losing the `msg.sender`
    /// namespacing safe. Two different `data` at the SAME `(implementation,
    /// salt)` are two different addresses, and both clones exist independently
    /// with their own initialization. So a front-runner who passes anything
    /// other than the intended bytes deploys their own contract at their own
    /// address and at their own expense, leaving the address that was pinned
    /// untouched and still deployable.
    function testCloneDeterministicOpenSaltDataInDerivation(bytes32 salt, bytes memory dataA, bytes memory dataB)
        external
    {
        vm.assume(keccak256(dataA) != keccak256(dataB));
        TestCloneable implementation = new TestCloneable();

        address predictedA = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(address(implementation), dataA, salt);
        address predictedB = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(address(implementation), dataB, salt);
        assertTrue(predictedA != predictedB);

        address childA = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), dataA, salt);
        address childB = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), dataB, salt);

        assertEq(childA, predictedA);
        assertEq(childB, predictedB);
        assertEq(TestCloneable(childA).sData(), dataA);
        assertEq(TestCloneable(childB).sData(), dataB);
    }

    /// The two derivations are disjoint under freely varying inputs on BOTH
    /// sides: no `(data, openSalt)` open-salt address is any `(namespacedSalt,
    /// deployer)` sender-namespaced address. Adding the open variant therefore
    /// cannot reach, block or collide with an address that `cloneDeterministic`
    /// promised to a specific caller, or vice versa.
    ///
    /// This is the broad statement, and on its own it is weak: a collision it
    /// could catch needs a keccak256 collision, so no realistic mutation of the
    /// derivation makes it fail. It is kept as the plain form of the interface's
    /// claim. The reachable case that actually discriminates the domain
    /// separator is the next test.
    function testCloneDeterministicOpenSaltDiffersFromSenderNamespaced(
        address implementation,
        bytes memory data,
        bytes32 openSalt,
        bytes32 namespacedSalt,
        address deployer
    ) external view {
        address open = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, data, openSalt);
        address namespaced = I_CLONE_FACTORY.predictDeterministicAddress(implementation, namespacedSalt, deployer);
        assertTrue(open != namespaced);
    }

    /// THE SQUAT THE DOMAIN SEPARATOR CLOSES, stated as an attack rather than as
    /// an absence.
    ///
    /// `ICloneableFactoryV4` makes it a MUST NOT on the factory that no other
    /// entry point can `CREATE2` in the open-salt derivation's image with
    /// caller-supplied `data`. `cloneDeterministic` is precisely such an entry
    /// point. Had the open derivation been the untagged
    /// `keccak256(abi.encode(salt, keccak256(data)))`, both preimages would be
    /// 64 bytes led by a caller-chosen word, and `abi.encode` left-pads an
    /// address into exactly the word a `bytes32` salt already is. So an account
    /// `A` would reach EVERY open-salt address whose `salt` happens to equal
    /// `bytes32(uint256(uint160(A)))` — no preimage search, just
    /// `cloneDeterministic(implementation, evilData, keccak256(data))` with
    /// whatever `evilData` it liked, aimed at an address somebody else pinned.
    ///
    /// The premise is asserted against the factory's OWN namespaced prediction,
    /// so this test proves the attack is live absent the tag rather than merely
    /// restating `abi.encode`. Remove
    /// `ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN` from `_effectiveOpenSalt` and
    /// this test fails.
    ///
    /// The single equation
    /// `keccak256(abi.encode(deployer, nsSalt)) == keccak256(abi.encode(openSalt, keccak256(data)))`
    /// is the whole of the reachable overlap, and this test closes it, so the
    /// mirror framing needs no second test: a victim who picks their namespaced
    /// `nsSalt` as `keccak256(P)` for reproducible bytes `P` — an ordinary
    /// choice — would, untagged, be reachable by an attacker calling
    /// `cloneDeterministicOpenSalt(implementation, P, bytes32(uint256(uint160(victim))))`.
    /// Same two unknowns, solved from the other side, closed by the same word.
    function testCloneDeterministicOpenSaltDisjointFromNamespacedAtLeftPaddedAddressSalt(
        address attacker,
        bytes memory data,
        bytes memory evilData
    ) external {
        TestCloneable implementation = new TestCloneable();

        // The open salt an honest party pinned, which happens to be the
        // abi-encoding of the attacker's own address. Nothing stops a salt
        // taking this value; the attacker is free to go looking for one that
        // does, or to pick the address to suit the salt.
        bytes32 openSalt = bytes32(uint256(uint160(attacker)));
        address open = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(address(implementation), data, openSalt);

        // The attacker's namespaced salt is just `keccak256(data)`, read off
        // the honest deploy they are front-running. `cloneDeterministic` hashes
        // `abi.encode(msg.sender, salt)`, so from `attacker` this is the
        // effective salt `keccak256(abi.encode(attacker, keccak256(data)))`.
        bytes32 attackerSalt = keccak256(data);
        address namespaced =
            I_CLONE_FACTORY.predictDeterministicAddress(address(implementation), attackerSalt, attacker);

        // ATTACK PREMISE. Those are byte for byte the 64 bytes an untagged open
        // derivation would hash for `(data, openSalt)`, so without the domain
        // word the squat lands exactly on the address the honest party pinned.
        address undomained = Clones.predictDeterministicAddress(
            address(implementation), keccak256(abi.encode(openSalt, keccak256(data))), address(I_CLONE_FACTORY)
        );
        assertEq(undomained, namespaced, "an untagged open salt IS reachable by cloneDeterministic");

        // THE GUARANTEE. The domain word moves the real open-salt address off
        // the one `cloneDeterministic` can reach.
        assertTrue(open != namespaced);

        // End to end, not just in prediction: the attacker really deploys, at
        // their own address, with their own data, and the honest open-salt
        // address is still free afterwards and still deploys the intended
        // clone with the intended bytes.
        vm.prank(attacker);
        address childAttacker = I_CLONE_FACTORY.cloneDeterministic(address(implementation), evilData, attackerSalt);
        assertEq(childAttacker, namespaced);
        assertEq(open.code.length, 0);

        address childOpen = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, openSalt);
        assertEq(childOpen, open);
        assertEq(TestCloneable(childOpen).sData(), data);
    }

    /// REGRESSION GUARD on the guarantee that must not break, in the other
    /// direction. Taking a salt via the open variant does not consume it for
    /// `cloneDeterministic`: the same caller can still deploy at the same `salt`
    /// through the namespaced derivation, at the address it always predicted,
    /// and both clones exist independently.
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

    /// Distinct salts yield distinct clones of the same implementation and the
    /// same `data` — many clones per impl, as with the namespaced variant. The
    /// other half of "distinct `(salt, data)` pairs yield distinct clones"; the
    /// `data` half is `…DataInDerivation`.
    function testCloneDeterministicOpenSaltManyClonesPerImpl(bytes32 salt1, bytes32 salt2, bytes memory data) external {
        vm.assume(salt1 != salt2);
        TestCloneable implementation = new TestCloneable();

        address child1 = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt1);
        address child2 = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt2);
        assertTrue(child1 != child2);
    }

    /// A second deploy at an already-taken open salt REVERTS. Since `data` is in
    /// the derivation, repeating the whole `(implementation, data, salt)` is now
    /// the ONLY way to aim at an address somebody else already took, and even
    /// that does not silently return the existing clone: a caller can never
    /// mistake an already-initialized contract for their own fresh deploy. What
    /// the reverting caller would have deployed is byte-identical to what is
    /// already there, so the loss is the gas and nothing else.
    function testCloneDeterministicOpenSaltSecondDeployReverts(
        bytes32 salt,
        bytes memory data,
        address alice,
        address bob
    ) external {
        vm.assume(alice != bob);
        TestCloneable implementation = new TestCloneable();

        vm.prank(alice);
        address child = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.FailedDeployment.selector));
        I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);

        // The first deploy's state is untouched by the failed second one.
        assertEq(TestCloneable(child).sData(), data);
    }

    /// `NewClone` is emitted with the caller, implementation, child, salt and
    /// data. The event is shared with `cloneDeterministic` and carries the RAW
    /// salt in both cases, never the effective one. `salt` and `data` together
    /// are the whole of the open derivation, so the event carries enough to
    /// recompute the address — an indexer picks the derivation by trying both
    /// and keeping the match, which is well defined precisely because the two
    /// images are disjoint.
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

        bytes memory data = abi.encode(notSuccess);
        address predicted = I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(address(implementation), data, salt);

        vm.expectRevert(abi.encodeWithSelector(InitializationFailed.selector));
        I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);

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

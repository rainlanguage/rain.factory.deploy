// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.2/src/Test.sol";

import {ICLONEABLE_V2_SUCCESS} from "rain-factory-0.1.9/src/interface/ICloneableV2.sol";
import {
    LibICloneableFactoryV4,
    ZeroImplementationCodeSize,
    CloneDeploymentFailed,
    InitializationFailed
} from "rain-factory-0.1.9/src/lib/LibICloneableFactoryV4.sol";
import {CloneFactory} from "../../../src/concrete/CloneFactory.sol";
import {TestLibCloneFactory} from "./TestLibCloneFactory.sol";
import {TestCloneable} from "./TestCloneable.sol";
import {TestCloneableFailure} from "./TestCloneableFailure.sol";

/// @title CloneFactoryLibEquivalenceTest
/// @notice Per-function equivalence between the shipped `CloneFactory` and
/// `LibICloneableFactoryV4`: for every entry point the concrete's observable
/// behaviour — return value, deployed code, initialization, `NewClone` event,
/// typed revert — is held equal to the library's, where the library is
/// observed two ways at once: as its own pure derivation applied to the
/// concrete's address, and as `TestLibCloneFactory`, the library run bare
/// behind an independent delegating surface, exercised from identical chain
/// state via snapshot and rollback. A concrete that grows any behaviour
/// beyond delegation diverges from one or the other and fails here.
contract CloneFactoryLibEquivalenceTest is Test {
    /// The shipped concrete under test. Stateless, so reused everywhere.
    CloneFactory internal immutable I_CLONE_FACTORY;

    /// The library run bare behind an independent delegating surface.
    TestLibCloneFactory internal immutable I_LIB_FACTORY;

    constructor() {
        I_CLONE_FACTORY = new CloneFactory();
        I_LIB_FACTORY = new TestLibCloneFactory();
    }

    /// The strongest form of "the concrete only delegates": `CloneFactory`
    /// and `TestLibCloneFactory` are the same four delegations declared
    /// independently, and with metadata stripped they compile to identical
    /// runtime bytecode. Any behaviour added to the concrete breaks this
    /// before it breaks anything behavioural.
    function testEquivalenceRuntimeBytecode() external pure {
        assertEq(type(CloneFactory).runtimeCode, type(TestLibCloneFactory).runtimeCode);
    }

    /// `predictDeterministicAddress` is the library's namespaced derivation
    /// applied to each factory's own address: the concrete equals the pure
    /// oracle at its address, the bare library equals it at its own, so both
    /// surfaces compute one function of the factory address.
    function testEquivalencePredictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        external
        view
    {
        bytes32 effectiveSalt = LibICloneableFactoryV4.effectiveSalt(deployer, salt);
        assertEq(
            I_CLONE_FACTORY.predictDeterministicAddress(implementation, salt, deployer),
            LibICloneableFactoryV4.predictCloneAddress(address(I_CLONE_FACTORY), implementation, effectiveSalt)
        );
        assertEq(
            I_LIB_FACTORY.predictDeterministicAddress(implementation, salt, deployer),
            LibICloneableFactoryV4.predictCloneAddress(address(I_LIB_FACTORY), implementation, effectiveSalt)
        );
    }

    /// `predictDeterministicAddressOpenSalt` is the library's open-salt
    /// derivation applied to each factory's own address, exactly as the
    /// namespaced prediction above.
    function testEquivalencePredictDeterministicAddressOpenSalt(address implementation, bytes memory data, bytes32 salt)
        external
        view
    {
        bytes32 effectiveSalt = LibICloneableFactoryV4.effectiveOpenSalt(salt, data);
        assertEq(
            I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, data, salt),
            LibICloneableFactoryV4.predictCloneAddress(address(I_CLONE_FACTORY), implementation, effectiveSalt)
        );
        assertEq(
            I_LIB_FACTORY.predictDeterministicAddressOpenSalt(implementation, data, salt),
            LibICloneableFactoryV4.predictCloneAddress(address(I_LIB_FACTORY), implementation, effectiveSalt)
        );
    }

    /// Everything observable about one clone call on one factory, captured so
    /// two factories' observations can be held equal after the state that
    /// produced the first is rolled back.
    struct CloneObservation {
        /// The child address the call returned.
        address child;
        /// The child's deployed runtime code.
        bytes childCode;
        /// The child's initialized state, read back as `TestCloneable.sData`.
        bytes childData;
        /// How many logs the call emitted.
        uint256 logCount;
        /// The emitter of the sole log.
        address emitter;
        /// `topics[0]` of the sole log.
        bytes32 eventTopic;
        /// The abi-encoded body of the sole log.
        bytes eventData;
    }

    /// Run one clone call on one factory and capture everything observable
    /// about it.
    /// @param factory The factory to call.
    /// @param factoryCall The entry point under test, abi-encoded for `call`.
    /// @param sender The pranked caller.
    /// @return The observation.
    function observeClone(address factory, bytes memory factoryCall, address sender)
        internal
        returns (CloneObservation memory)
    {
        vm.recordLogs();
        vm.prank(sender);
        (bool success, bytes memory returnData) = factory.call(factoryCall);
        assertTrue(success);
        CloneObservation memory observation;
        observation.child = abi.decode(returnData, (address));
        observation.childCode = observation.child.code;
        observation.childData = TestCloneable(observation.child).sData();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        observation.logCount = entries.length;
        observation.emitter = entries[0].emitter;
        observation.eventTopic = entries[0].topics[0];
        observation.eventData = entries[0].data;
        return observation;
    }

    /// The shared success-path comparison for both clone entry points: run the
    /// concrete, roll the state back, run the bare library from the same state
    /// with the same sender, and hold child address (against the library's own
    /// derivation at each factory), deployed code, initialized state and the
    /// `NewClone` event equal between the two.
    /// @param factoryCall The entry point under test, abi-encoded for `call`,
    /// identical for both factories.
    /// @param derivedSalt The effective salt the library derives for this
    /// call, from `effectiveSalt` or `effectiveOpenSalt`.
    /// @param implementation The cloned implementation.
    /// @param data The initialization data inside `factoryCall`.
    /// @param salt The raw caller salt inside `factoryCall`.
    /// @param sender The pranked caller of both factories.
    function checkCloneEquivalence(
        bytes memory factoryCall,
        bytes32 derivedSalt,
        address implementation,
        bytes memory data,
        bytes32 salt,
        address sender
    ) internal {
        uint256 snapshot = vm.snapshotState();
        CloneObservation memory concrete = observeClone(address(I_CLONE_FACTORY), factoryCall, sender);
        vm.revertToState(snapshot);
        CloneObservation memory lib = observeClone(address(I_LIB_FACTORY), factoryCall, sender);

        // Each child is the library's derivation applied to its own factory.
        assertEq(
            concrete.child,
            LibICloneableFactoryV4.predictCloneAddress(address(I_CLONE_FACTORY), implementation, derivedSalt)
        );
        assertEq(
            lib.child, LibICloneableFactoryV4.predictCloneAddress(address(I_LIB_FACTORY), implementation, derivedSalt)
        );

        // Same deployed code and same initialized state.
        assertEq(concrete.childCode, lib.childCode);
        assertEq(concrete.childData, lib.childData);
        assertEq(concrete.childData, data);

        // Same single `NewClone`, field for field, from each factory about its
        // own child.
        assertEq(concrete.logCount, 1);
        assertEq(lib.logCount, 1);
        assertEq(concrete.emitter, address(I_CLONE_FACTORY));
        assertEq(lib.emitter, address(I_LIB_FACTORY));
        assertEq(concrete.eventTopic, lib.eventTopic);
        assertEq(concrete.eventData, abi.encode(sender, implementation, concrete.child, salt, data));
        assertEq(lib.eventData, abi.encode(sender, implementation, lib.child, salt, data));
    }

    /// `cloneDeterministic` success path: concrete == library, per
    /// `checkCloneEquivalence`, at the namespaced derivation.
    function testEquivalenceCloneDeterministic(bytes32 salt, bytes memory data, address sender) external {
        TestCloneable implementation = new TestCloneable();
        checkCloneEquivalence(
            abi.encodeCall(CloneFactory.cloneDeterministic, (address(implementation), data, salt)),
            LibICloneableFactoryV4.effectiveSalt(sender, salt),
            address(implementation),
            data,
            salt,
            sender
        );
    }

    /// `cloneDeterministicOpenSalt` success path: concrete == library, per
    /// `checkCloneEquivalence`, at the open-salt derivation.
    function testEquivalenceCloneDeterministicOpenSalt(bytes32 salt, bytes memory data, address sender) external {
        TestCloneable implementation = new TestCloneable();
        checkCloneEquivalence(
            abi.encodeCall(CloneFactory.cloneDeterministicOpenSalt, (address(implementation), data, salt)),
            LibICloneableFactoryV4.effectiveOpenSalt(salt, data),
            address(implementation),
            data,
            salt,
            sender
        );
    }

    /// The shared revert-path comparison: the same call reverts with the same
    /// bytes on the concrete and on the bare library, from identical state via
    /// snapshot and rollback.
    /// @param factoryCall The entry point under test, abi-encoded for `call`,
    /// identical for both factories.
    /// @param revertData The exact revert bytes both factories must produce.
    /// @param sender The pranked caller of both factories.
    function checkRevertEquivalence(bytes memory factoryCall, bytes memory revertData, address sender) internal {
        uint256 snapshot = vm.snapshotState();

        vm.prank(sender);
        vm.expectRevert(revertData);
        (bool successConcrete,) = address(I_CLONE_FACTORY).call(factoryCall);
        // `expectRevert` swallows the revert, so the call reports success.
        assertTrue(successConcrete);

        vm.revertToState(snapshot);

        vm.prank(sender);
        vm.expectRevert(revertData);
        (bool successLib,) = address(I_LIB_FACTORY).call(factoryCall);
        assertTrue(successLib);
    }

    /// A codeless implementation reverts `ZeroImplementationCodeSize` on the
    /// concrete exactly as on the library, for `cloneDeterministic`.
    function testEquivalenceCloneDeterministicZeroCode(
        address implementation,
        bytes memory data,
        bytes32 salt,
        address sender
    ) external {
        vm.assume(implementation.code.length == 0);
        checkRevertEquivalence(
            abi.encodeCall(CloneFactory.cloneDeterministic, (implementation, data, salt)),
            abi.encodeWithSelector(ZeroImplementationCodeSize.selector),
            sender
        );
    }

    /// A codeless implementation reverts `ZeroImplementationCodeSize` on the
    /// concrete exactly as on the library, for `cloneDeterministicOpenSalt`.
    function testEquivalenceCloneDeterministicOpenSaltZeroCode(
        address implementation,
        bytes memory data,
        bytes32 salt,
        address sender
    ) external {
        vm.assume(implementation.code.length == 0);
        checkRevertEquivalence(
            abi.encodeCall(CloneFactory.cloneDeterministicOpenSalt, (implementation, data, salt)),
            abi.encodeWithSelector(ZeroImplementationCodeSize.selector),
            sender
        );
    }

    /// An implementation that initializes to a non-success code reverts
    /// `InitializationFailed` on the concrete exactly as on the library, for
    /// `cloneDeterministic`.
    function testEquivalenceCloneDeterministicInitFailure(bytes32 notSuccess, bytes32 salt, address sender) external {
        vm.assume(notSuccess != ICLONEABLE_V2_SUCCESS);
        TestCloneableFailure implementation = new TestCloneableFailure();
        checkRevertEquivalence(
            abi.encodeCall(CloneFactory.cloneDeterministic, (address(implementation), abi.encode(notSuccess), salt)),
            abi.encodeWithSelector(InitializationFailed.selector),
            sender
        );
    }

    /// An implementation that initializes to a non-success code reverts
    /// `InitializationFailed` on the concrete exactly as on the library, for
    /// `cloneDeterministicOpenSalt`.
    function testEquivalenceCloneDeterministicOpenSaltInitFailure(bytes32 notSuccess, bytes32 salt, address sender)
        external
    {
        vm.assume(notSuccess != ICLONEABLE_V2_SUCCESS);
        TestCloneableFailure implementation = new TestCloneableFailure();
        checkRevertEquivalence(
            abi.encodeCall(
                CloneFactory.cloneDeterministicOpenSalt, (address(implementation), abi.encode(notSuccess), salt)
            ),
            abi.encodeWithSelector(InitializationFailed.selector),
            sender
        );
    }

    /// Re-deploying at a taken namespaced salt reverts `CloneDeploymentFailed`
    /// on the concrete exactly as on the library — with different `data` on
    /// the second call, because `data` is outside the namespaced derivation on
    /// both surfaces.
    function testEquivalenceCloneDeterministicSaltTaken(
        bytes32 salt,
        bytes memory data,
        bytes memory dataSecond,
        address sender
    ) external {
        TestCloneable implementation = new TestCloneable();
        uint256 snapshot = vm.snapshotState();

        vm.prank(sender);
        I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSelector(CloneDeploymentFailed.selector));
        I_CLONE_FACTORY.cloneDeterministic(address(implementation), dataSecond, salt);

        vm.revertToState(snapshot);

        vm.prank(sender);
        I_LIB_FACTORY.cloneDeterministic(address(implementation), data, salt);
        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSelector(CloneDeploymentFailed.selector));
        I_LIB_FACTORY.cloneDeterministic(address(implementation), dataSecond, salt);
    }

    /// Re-deploying at a taken open salt reverts `CloneDeploymentFailed` on
    /// the concrete exactly as on the library — from a different sender on the
    /// second call, because the caller is outside the open-salt derivation on
    /// both surfaces.
    function testEquivalenceCloneDeterministicOpenSaltSaltTaken(
        bytes32 salt,
        bytes memory data,
        address sender,
        address senderSecond
    ) external {
        TestCloneable implementation = new TestCloneable();
        uint256 snapshot = vm.snapshotState();

        vm.prank(sender);
        I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);
        vm.prank(senderSecond);
        vm.expectRevert(abi.encodeWithSelector(CloneDeploymentFailed.selector));
        I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);

        vm.revertToState(snapshot);

        vm.prank(sender);
        I_LIB_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);
        vm.prank(senderSecond);
        vm.expectRevert(abi.encodeWithSelector(CloneDeploymentFailed.selector));
        I_LIB_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);
    }
}

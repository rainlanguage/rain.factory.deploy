// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.17.0/src/Test.sol";

import {ICLONEABLE_V2_SUCCESS} from "rain-factory-0.2.3/src/interface/ICloneableV2.sol";
import {ICloneableFactoryV5} from "rain-factory-0.2.3/src/interface/ICloneableFactoryV5.sol";
import {
    LibICloneableFactoryV5,
    ZeroImplementationCodeSize,
    CloneAddressOccupied,
    ZeroBeaconCodeSize,
    CloneDeploymentFailed,
    InitializationFailed
} from "rain-factory-0.2.3/src/lib/LibICloneableFactoryV5.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.6.1/proxy/beacon/UpgradeableBeacon.sol";
import {CloneFactory} from "../../../src/concrete/CloneFactory.sol";
import {TestCloneFactory} from "rain-factory-0.2.3/src/test/TestCloneFactory.sol";
import {TestCloneable} from "rain-factory-0.2.3/src/test/TestCloneable.sol";
import {TestCloneableFailure} from "rain-factory-0.2.3/src/test/TestCloneableFailure.sol";

/// @title CloneFactoryLibEquivalenceTest
/// @notice Per-function equivalence between the shipped `CloneFactory` and
/// `LibICloneableFactoryV5`: for every entry point the concrete's observable
/// behaviour — return value, deployed code, initialization, `NewClone` event,
/// typed revert — is held equal to the library's, where the library is
/// observed two ways at once: as its own pure derivation applied to the
/// concrete's address, and as rain-factory's `TestCloneFactory`, the library
/// run bare behind an independent delegating surface, exercised from identical
/// chain state via snapshot and rollback. A concrete that grows any behaviour
/// beyond delegation diverges from one or the other and fails here.
contract CloneFactoryLibEquivalenceTest is Test {
    /// The shipped concrete under test. Stateless, so reused everywhere.
    CloneFactory internal immutable I_CLONE_FACTORY;

    /// The library run bare behind an independent delegating surface.
    TestCloneFactory internal immutable I_LIB_FACTORY;

    constructor() {
        I_CLONE_FACTORY = new CloneFactory();
        I_LIB_FACTORY = new TestCloneFactory();
    }

    /// The strongest form of "the concrete only delegates": `CloneFactory`
    /// and rain-factory's `TestCloneFactory` are the same six delegations
    /// declared independently, and with metadata stripped they compile to
    /// identical runtime bytecode. Any behaviour added to the concrete breaks this
    /// before it breaks anything behavioural.
    function testEquivalenceRuntimeBytecode() external pure {
        assertEq(type(CloneFactory).runtimeCode, type(TestCloneFactory).runtimeCode);
    }

    /// `predictDeterministicAddress` is the library's namespaced derivation
    /// applied to each factory's own address: the concrete equals the pure
    /// oracle at its address, the bare library equals it at its own, so both
    /// surfaces compute one function of the factory address.
    function testEquivalencePredictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        external
        view
    {
        bytes32 effectiveSalt = LibICloneableFactoryV5.effectiveSalt(deployer, salt);
        assertEq(
            I_CLONE_FACTORY.predictDeterministicAddress(implementation, salt, deployer),
            LibICloneableFactoryV5.predictCloneAddress(address(I_CLONE_FACTORY), implementation, effectiveSalt)
        );
        assertEq(
            I_LIB_FACTORY.predictDeterministicAddress(implementation, salt, deployer),
            LibICloneableFactoryV5.predictCloneAddress(address(I_LIB_FACTORY), implementation, effectiveSalt)
        );
    }

    /// `predictDeterministicAddressOpenSalt` is the library's open-salt
    /// derivation applied to each factory's own address, exactly as the
    /// namespaced prediction above.
    function testEquivalencePredictDeterministicAddressOpenSalt(address implementation, bytes memory data, bytes32 salt)
        external
        view
    {
        bytes32 effectiveSalt = LibICloneableFactoryV5.effectiveOpenSalt(salt, data);
        assertEq(
            I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, data, salt),
            LibICloneableFactoryV5.predictCloneAddress(address(I_CLONE_FACTORY), implementation, effectiveSalt)
        );
        assertEq(
            I_LIB_FACTORY.predictDeterministicAddressOpenSalt(implementation, data, salt),
            LibICloneableFactoryV5.predictCloneAddress(address(I_LIB_FACTORY), implementation, effectiveSalt)
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
        /// The emitter of the first log.
        address firstEmitter;
        /// `topics[0]` of the first log.
        bytes32 firstTopic;
        /// The emitter of the last log.
        address emitter;
        /// `topics[0]` of the last log.
        bytes32 eventTopic;
        /// The abi-encoded body of the last log.
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
        observation.firstEmitter = entries[0].emitter;
        observation.firstTopic = entries[0].topics[0];
        Vm.Log memory last = entries[entries.length - 1];
        observation.emitter = last.emitter;
        observation.eventTopic = last.topics[0];
        observation.eventData = last.data;
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
            LibICloneableFactoryV5.predictCloneAddress(address(I_CLONE_FACTORY), implementation, derivedSalt)
        );
        assertEq(
            lib.child, LibICloneableFactoryV5.predictCloneAddress(address(I_LIB_FACTORY), implementation, derivedSalt)
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
            LibICloneableFactoryV5.effectiveSalt(sender, salt),
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
            LibICloneableFactoryV5.effectiveOpenSalt(salt, data),
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

    /// Re-deploying at a taken namespaced salt reverts `CloneAddressOccupied`
    /// naming the address already taken, on the concrete exactly as on the
    /// library — with different `data` on the second call, because `data` is
    /// outside the namespaced derivation on both surfaces. The two surfaces
    /// name different addresses because each derives from its own factory.
    function testEquivalenceCloneDeterministicSaltTaken(
        bytes32 salt,
        bytes memory data,
        bytes memory dataSecond,
        address sender
    ) external {
        TestCloneable implementation = new TestCloneable();
        uint256 snapshot = vm.snapshotState();

        vm.prank(sender);
        address concreteClone = I_CLONE_FACTORY.cloneDeterministic(address(implementation), data, salt);
        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSelector(CloneAddressOccupied.selector, concreteClone));
        I_CLONE_FACTORY.cloneDeterministic(address(implementation), dataSecond, salt);

        vm.revertToState(snapshot);

        vm.prank(sender);
        address libClone = I_LIB_FACTORY.cloneDeterministic(address(implementation), data, salt);
        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSelector(CloneAddressOccupied.selector, libClone));
        I_LIB_FACTORY.cloneDeterministic(address(implementation), dataSecond, salt);
    }

    /// Re-deploying at a taken open salt reverts `CloneAddressOccupied` naming
    /// the address already taken, on the concrete exactly as on the library —
    /// from a different sender on the second call, because the caller is
    /// outside the open-salt derivation on both surfaces.
    function testEquivalenceCloneDeterministicOpenSaltSaltTaken(
        bytes32 salt,
        bytes memory data,
        address sender,
        address senderSecond
    ) external {
        TestCloneable implementation = new TestCloneable();
        uint256 snapshot = vm.snapshotState();

        vm.prank(sender);
        address concreteClone = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);
        vm.prank(senderSecond);
        vm.expectRevert(abi.encodeWithSelector(CloneAddressOccupied.selector, concreteClone));
        I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);

        vm.revertToState(snapshot);

        vm.prank(sender);
        address libClone = I_LIB_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);
        vm.prank(senderSecond);
        vm.expectRevert(abi.encodeWithSelector(CloneAddressOccupied.selector, libClone));
        I_LIB_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt);
    }

    /// `predictBeaconProxyAddressOpenSalt` is the library's beacon proxy
    /// derivation applied to each factory's own address.
    function testEquivalencePredictBeaconProxyAddressOpenSalt(address beacon, bytes memory data, bytes32 salt)
        external
        view
    {
        bytes32 effectiveSalt = LibICloneableFactoryV5.effectiveBeaconProxyOpenSalt(salt, data);
        assertEq(
            I_CLONE_FACTORY.predictBeaconProxyAddressOpenSalt(beacon, data, salt),
            LibICloneableFactoryV5.predictBeaconProxyAddress(address(I_CLONE_FACTORY), beacon, effectiveSalt)
        );
        assertEq(
            I_LIB_FACTORY.predictBeaconProxyAddressOpenSalt(beacon, data, salt),
            LibICloneableFactoryV5.predictBeaconProxyAddress(address(I_LIB_FACTORY), beacon, effectiveSalt)
        );
    }

    /// `beaconProxyDeterministicOpenSalt` success path: from identical state,
    /// the concrete and the bare library each deploy at the library's
    /// derivation for their own address, with the same code and initialized
    /// state, and each emits, after the proxy's own `BeaconUpgraded`, one
    /// `NewBeaconProxy` about its own proxy.
    function testEquivalenceBeaconProxyDeterministicOpenSalt(bytes32 salt, bytes memory data, address sender) external {
        address beacon = address(new UpgradeableBeacon(address(new TestCloneable()), address(this)));
        bytes memory factoryCall = abi.encodeCall(CloneFactory.beaconProxyDeterministicOpenSalt, (beacon, data, salt));
        bytes32 derivedSalt = LibICloneableFactoryV5.effectiveBeaconProxyOpenSalt(salt, data);

        uint256 snapshot = vm.snapshotState();
        CloneObservation memory concrete = observeClone(address(I_CLONE_FACTORY), factoryCall, sender);
        vm.revertToState(snapshot);
        CloneObservation memory lib = observeClone(address(I_LIB_FACTORY), factoryCall, sender);

        assertEq(
            concrete.child,
            LibICloneableFactoryV5.predictBeaconProxyAddress(address(I_CLONE_FACTORY), beacon, derivedSalt)
        );
        assertEq(
            lib.child, LibICloneableFactoryV5.predictBeaconProxyAddress(address(I_LIB_FACTORY), beacon, derivedSalt)
        );

        assertEq(concrete.childCode, lib.childCode);
        assertEq(concrete.childData, lib.childData);
        assertEq(concrete.childData, data);

        assertEq(concrete.logCount, 2);
        assertEq(lib.logCount, 2);
        assertEq(concrete.firstEmitter, concrete.child);
        assertEq(lib.firstEmitter, lib.child);
        assertEq(concrete.firstTopic, keccak256("BeaconUpgraded(address)"));
        assertEq(lib.firstTopic, keccak256("BeaconUpgraded(address)"));
        assertEq(concrete.emitter, address(I_CLONE_FACTORY));
        assertEq(lib.emitter, address(I_LIB_FACTORY));
        assertEq(concrete.eventTopic, ICloneableFactoryV5.NewBeaconProxy.selector);
        assertEq(lib.eventTopic, ICloneableFactoryV5.NewBeaconProxy.selector);
        assertEq(concrete.eventData, abi.encode(sender, beacon, concrete.child, salt, data));
        assertEq(lib.eventData, abi.encode(sender, beacon, lib.child, salt, data));
    }

    /// A codeless beacon reverts `ZeroBeaconCodeSize` on the concrete exactly
    /// as on the library.
    function testEquivalenceBeaconProxyZeroBeaconCode(address beacon, bytes memory data, bytes32 salt, address sender)
        external
    {
        vm.assume(beacon.code.length == 0);
        checkRevertEquivalence(
            abi.encodeCall(CloneFactory.beaconProxyDeterministicOpenSalt, (beacon, data, salt)),
            abi.encodeWithSelector(ZeroBeaconCodeSize.selector),
            sender
        );
    }

    /// A beacon serving an implementation that initializes to a non-success
    /// code reverts `InitializationFailed` on the concrete exactly as on the
    /// library.
    function testEquivalenceBeaconProxyInitFailure(bytes32 notSuccess, bytes32 salt, address sender) external {
        vm.assume(notSuccess != ICLONEABLE_V2_SUCCESS);
        address beacon = address(new UpgradeableBeacon(address(new TestCloneableFailure()), address(this)));
        checkRevertEquivalence(
            abi.encodeCall(CloneFactory.beaconProxyDeterministicOpenSalt, (beacon, abi.encode(notSuccess), salt)),
            abi.encodeWithSelector(InitializationFailed.selector),
            sender
        );
    }

    /// Re-deploying at a taken beacon proxy open salt reverts
    /// `CloneAddressOccupied` naming the address already taken, on the
    /// concrete exactly as on the library, from a different sender.
    function testEquivalenceBeaconProxySaltTaken(bytes32 salt, bytes memory data, address sender, address senderSecond)
        external
    {
        address beacon = address(new UpgradeableBeacon(address(new TestCloneable()), address(this)));
        uint256 snapshot = vm.snapshotState();

        vm.prank(sender);
        address concreteProxy = I_CLONE_FACTORY.beaconProxyDeterministicOpenSalt(beacon, data, salt);
        vm.prank(senderSecond);
        vm.expectRevert(abi.encodeWithSelector(CloneAddressOccupied.selector, concreteProxy));
        I_CLONE_FACTORY.beaconProxyDeterministicOpenSalt(beacon, data, salt);

        vm.revertToState(snapshot);

        vm.prank(sender);
        address libProxy = I_LIB_FACTORY.beaconProxyDeterministicOpenSalt(beacon, data, salt);
        vm.prank(senderSecond);
        vm.expectRevert(abi.encodeWithSelector(CloneAddressOccupied.selector, libProxy));
        I_LIB_FACTORY.beaconProxyDeterministicOpenSalt(beacon, data, salt);
    }
}

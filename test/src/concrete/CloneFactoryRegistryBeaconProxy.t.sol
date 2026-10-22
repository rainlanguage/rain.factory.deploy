// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {Create2} from "@openzeppelin-contracts-5.7.0/utils/Create2.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {ERC1967Utils} from "@openzeppelin-contracts-5.7.0/proxy/ERC1967/ERC1967Utils.sol";
import {ICloneableFactoryV6} from "rain-factory-0.2.5/src/interface/ICloneableFactoryV6.sol";
import {LibICloneableFactoryV6, NonCanonicalBeaconBinding} from "rain-factory-0.2.5/src/lib/LibICloneableFactoryV6.sol";
import {TestCloneFactory} from "rain-factory-0.2.5/src/test/TestCloneFactory.sol";
import {TestCloneable} from "rain-factory-0.2.5/src/test/TestCloneable.sol";
import {CloneFactory} from "../../../src/concrete/CloneFactory.sol";
import {TestRegistryBeaconSource, TestNameNotRegistered} from "../../concrete/TestRegistryBeaconSource.sol";

/// @title CloneFactoryRegistryBeaconProxyTest
/// The shipped `CloneFactory`'s V6 entry points against
/// `LibICloneableFactoryV6`, run bare behind rain-factory's `TestCloneFactory`
/// from identical chain state.
contract CloneFactoryRegistryBeaconProxyTest is Test {
    address internal constant AUTHORITY = address(uint160(uint256(keccak256("authority"))));
    bytes32 internal constant BEACON_NAME = keccak256("beacon");

    CloneFactory internal immutable iCloneFactory;
    TestCloneFactory internal immutable iLibFactory;
    TestRegistryBeaconSource internal immutable iRegistry;

    constructor() {
        iCloneFactory = new CloneFactory();
        iLibFactory = new TestCloneFactory();
        iRegistry = new TestRegistryBeaconSource();
    }

    function expected(address factory, bytes memory data, bytes32 salt) internal view returns (address) {
        return Create2.computeAddress(
            LibICloneableFactoryV6.effectiveRegistryBeaconProxySalt(data, salt),
            keccak256(
                LibICloneableFactoryV6.registryBeaconProxyCreationCode(address(iRegistry), AUTHORITY, BEACON_NAME)
            ),
            factory
        );
    }

    function deploy(ICloneableFactoryV6 factory, address beacon, bytes memory data, bytes32 salt)
        internal
        returns (address)
    {
        address predicted =
            factory.predictRegistryBeaconProxyAddress(address(iRegistry), AUTHORITY, BEACON_NAME, data, salt);
        assertEq(predicted, expected(address(factory), data, salt));
        vm.expectEmit(address(factory));
        emit ICloneableFactoryV6.NewRegistryBeaconProxy(
            address(this), address(iRegistry), AUTHORITY, BEACON_NAME, beacon, predicted, salt, data
        );
        address proxy = factory.registryBeaconProxy(address(iRegistry), AUTHORITY, BEACON_NAME, data, salt);
        assertEq(proxy, predicted);
        assertEq(address(uint160(uint256(vm.load(proxy, ERC1967Utils.BEACON_SLOT)))), beacon);
        assertTrue(TestCloneable(proxy).sInitialized());
        assertEq(TestCloneable(proxy).sData(), data);
        return proxy;
    }

    /// Both factories deploy the bound beacon's proxy at their own prediction,
    /// emit the same event and initialize it with `data`.
    function testRegistryBeaconProxyEquivalent(bytes memory data, bytes32 salt) external {
        address beacon = address(new UpgradeableBeacon(address(new TestCloneable()), address(this)));
        iRegistry.bind(AUTHORITY, BEACON_NAME, abi.encode(beacon));
        uint256 start = vm.snapshotState();
        address concreteProxy = deploy(iCloneFactory, beacon, data, salt);
        vm.revertToState(start);
        address libProxy = deploy(iLibFactory, beacon, data, salt);
        assertEq(concreteProxy.codehash, libProxy.codehash);
    }

    /// An unbound name reverts the same through both factories.
    function testUnboundNameEquivalent(bytes memory data, bytes32 salt) external {
        bytes memory err = abi.encodeWithSelector(TestNameNotRegistered.selector, AUTHORITY, BEACON_NAME);
        vm.expectRevert(err);
        iCloneFactory.registryBeaconProxy(address(iRegistry), AUTHORITY, BEACON_NAME, data, salt);
        vm.expectRevert(err);
        iLibFactory.registryBeaconProxy(address(iRegistry), AUTHORITY, BEACON_NAME, data, salt);
    }

    /// A non-canonical binding reverts the same through both factories.
    function testNonCanonicalBindingEquivalent(bytes memory data, bytes32 salt) external {
        iRegistry.bind(AUTHORITY, BEACON_NAME, abi.encode(type(uint256).max));
        bytes memory err =
            abi.encodeWithSelector(NonCanonicalBeaconBinding.selector, address(iRegistry), AUTHORITY, BEACON_NAME);
        vm.expectRevert(err);
        iCloneFactory.registryBeaconProxy(address(iRegistry), AUTHORITY, BEACON_NAME, data, salt);
        vm.expectRevert(err);
        iLibFactory.registryBeaconProxy(address(iRegistry), AUTHORITY, BEACON_NAME, data, salt);
    }
}

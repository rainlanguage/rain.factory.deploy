// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.1/src/Test.sol";

import {IAddressRegistryV1} from "rain-deploy-0.1.6/src/interface/IAddressRegistryV1.sol";
import {AddressRegistry, ADDRESS_REGISTRY_ROOT} from "../../../src/concrete/AddressRegistry.sol";

/// @title AddressRegistryRegisterTest
/// @notice A test suite for `AddressRegistry.register`: who may bind a name,
/// and the write-once property that makes every binding a constant.
contract AddressRegistryRegisterTest is Test {
    /// The registry under test. Stateful, so a fresh one per test.
    AddressRegistry internal sRegistry;

    function setUp() external {
        sRegistry = new AddressRegistry();
    }

    /// Only root may bind a name. Checked before the zero-address check, so a
    /// non-root caller is rejected as `NotRoot` whatever it passes.
    function testRegisterOnlyRoot(address sender, bytes32 name, address account) external {
        vm.assume(sender != ADDRESS_REGISTRY_ROOT);

        vm.expectRevert(abi.encodeWithSelector(IAddressRegistryV1.NotRoot.selector, sender));
        vm.prank(sender);
        sRegistry.register(name, account);
    }

    /// A non-root caller cannot bind a name that is already bound either: the
    /// authority check precedes the write-once check, and neither path lets a
    /// binding move.
    function testRegisterOnlyRootWhenAlreadyBound(address sender, bytes32 name, address bound, address account)
        external
    {
        vm.assume(sender != ADDRESS_REGISTRY_ROOT);
        vm.assume(bound != address(0));

        vm.prank(ADDRESS_REGISTRY_ROOT);
        sRegistry.register(name, bound);

        vm.expectRevert(abi.encodeWithSelector(IAddressRegistryV1.NotRoot.selector, sender));
        vm.prank(sender);
        sRegistry.register(name, account);

        assertEq(sRegistry.get(name), bound);
    }

    /// A bound name can never be rebound, including by root. The binding that
    /// is already there survives.
    function testRegisterWriteOnce(bytes32 name, address bound, address account) external {
        vm.assume(bound != address(0));
        vm.assume(account != address(0));

        vm.prank(ADDRESS_REGISTRY_ROOT);
        sRegistry.register(name, bound);

        vm.expectRevert(abi.encodeWithSelector(IAddressRegistryV1.NameAlreadyRegistered.selector, name, bound));
        vm.prank(ADDRESS_REGISTRY_ROOT);
        sRegistry.register(name, account);

        assertEq(sRegistry.get(name), bound);
    }

    /// Rebinding a name to the address it is already bound to is rejected too.
    /// Write-once is a property of the name, not of the value changing, so a
    /// no-op rebind is not a special case that slips through.
    function testRegisterWriteOnceSameAccount(bytes32 name, address account) external {
        vm.assume(account != address(0));

        vm.prank(ADDRESS_REGISTRY_ROOT);
        sRegistry.register(name, account);

        vm.expectRevert(abi.encodeWithSelector(IAddressRegistryV1.NameAlreadyRegistered.selector, name, account));
        vm.prank(ADDRESS_REGISTRY_ROOT);
        sRegistry.register(name, account);

        assertEq(sRegistry.get(name), account);
    }

    /// The zero address is rejected. An unbound name reads as the zero address
    /// internally, so binding it would produce a name that is bound but
    /// unreadable — and that `register` would happily accept a second time,
    /// destroying write-once.
    function testRegisterZeroAccount(bytes32 name) external {
        vm.expectRevert(abi.encodeWithSelector(IAddressRegistryV1.ZeroAccount.selector, name));
        vm.prank(ADDRESS_REGISTRY_ROOT);
        sRegistry.register(name, address(0));

        vm.expectRevert(abi.encodeWithSelector(IAddressRegistryV1.NameNotRegistered.selector, name));
        sRegistry.get(name);
    }

    /// Names are independent: binding one says nothing about any other, and
    /// each remains bindable exactly once.
    function testRegisterDistinctNames(bytes32 nameA, bytes32 nameB, address accountA, address accountB) external {
        vm.assume(nameA != nameB);
        vm.assume(accountA != address(0));
        vm.assume(accountB != address(0));

        vm.prank(ADDRESS_REGISTRY_ROOT);
        sRegistry.register(nameA, accountA);

        // Binding `nameA` did not bind `nameB`.
        vm.expectRevert(abi.encodeWithSelector(IAddressRegistryV1.NameNotRegistered.selector, nameB));
        sRegistry.get(nameB);

        vm.prank(ADDRESS_REGISTRY_ROOT);
        sRegistry.register(nameB, accountB);

        assertEq(sRegistry.get(nameA), accountA);
        assertEq(sRegistry.get(nameB), accountB);
    }

    /// `Register` is emitted exactly once, with the name and account both
    /// indexed so the log can be filtered by either. The log is the only
    /// enumeration of the registry, so a binding that does not emit is a
    /// binding nobody can find.
    function testRegisterEvent(bytes32 name, address account) external {
        vm.assume(account != address(0));

        vm.recordLogs();
        vm.prank(ADDRESS_REGISTRY_ROOT);
        sRegistry.register(name, account);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 1);
        assertEq(entries[0].emitter, address(sRegistry));
        assertEq(entries[0].topics.length, 3);
        assertEq(entries[0].topics[0], keccak256("Register(bytes32,address)"));
        assertEq(entries[0].topics[1], name);
        assertEq(entries[0].topics[2], bytes32(uint256(uint160(account))));
        assertEq(entries[0].data.length, 0);
    }

    /// A rejected `register` emits nothing, so a failed bind can never be
    /// mistaken for a binding by anything reading the logs.
    function testRegisterNoEventOnRevert(address sender, bytes32 name, address account) external {
        vm.assume(sender != ADDRESS_REGISTRY_ROOT);

        vm.recordLogs();
        vm.expectRevert(abi.encodeWithSelector(IAddressRegistryV1.NotRoot.selector, sender));
        vm.prank(sender);
        sRegistry.register(name, account);
        assertEq(vm.getRecordedLogs().length, 0);
    }
}

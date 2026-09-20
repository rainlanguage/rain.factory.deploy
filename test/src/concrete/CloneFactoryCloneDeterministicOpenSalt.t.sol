// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";

import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";
import {LibExtrospectERC1167Proxy} from "rain-extrospection-0.1.1/src/lib/LibExtrospectERC1167Proxy.sol";
import {ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN} from "rain-factory-0.1.9/src/interface/ICloneableFactoryV4.sol";
import {CloneFactory} from "../../../src/concrete/CloneFactory.sol";
import {TestCloneable} from "./TestCloneable.sol";

contract CloneFactoryCloneDeterministicOpenSaltTest is Test {
    CloneFactory internal immutable I_CLONE_FACTORY;

    constructor() {
        I_CLONE_FACTORY = new CloneFactory();
    }

    function testCloneDeterministicOpenSaltIsDomainTaggedHash(address implementation, bytes memory data, bytes32 salt)
        external
        view
    {
        bytes32 effectiveSalt = keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)));
        address expected = Clones.predictDeterministicAddress(implementation, effectiveSalt, address(I_CLONE_FACTORY));
        assertEq(I_CLONE_FACTORY.predictDeterministicAddressOpenSalt(implementation, data, salt), expected);
    }

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

    function testCloneDeterministicOpenSaltManyClonesPerImpl(bytes32 salt1, bytes32 salt2, bytes memory data) external {
        vm.assume(salt1 != salt2);
        TestCloneable implementation = new TestCloneable();

        address child1 = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt1);
        address child2 = I_CLONE_FACTORY.cloneDeterministicOpenSalt(address(implementation), data, salt2);
        assertTrue(child1 != child2);
    }
}

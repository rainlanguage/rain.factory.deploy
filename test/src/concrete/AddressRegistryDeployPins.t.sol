// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {LibRainDeploy} from "rain-deploy-0.1.6/src/lib/LibRainDeploy.sol";
import {LibAddressRegistry} from "rain-deploy-0.1.6/src/lib/LibAddressRegistry.sol";
import {AddressRegistry} from "../../../src/concrete/AddressRegistry.sol";

/// @title AddressRegistryDeployPinsTest
/// @notice `rain-deploy`'s `LibAddressRegistry` pins the deterministic address
/// and code hash of the `AddressRegistry` in this repo, and consumers resolve
/// names through those pins. The root authority is a constant in this contract's
/// creation code, so changing it moves both pins; this suite is what makes that
/// loud instead of silent.
contract AddressRegistryDeployPinsTest is Test {
    /// The pins MUST be derivable from this source without deploying anything:
    /// the Zoltu factory is `CREATE2` over its calldata with a zero salt, so the
    /// address is a pure function of the creation code, and the code hash is
    /// `keccak256` of the runtime code that creation code leaves behind.
    function testAddressRegistryPinsDeriveFromThisSource() external pure {
        assertEq(LibRainDeploy.zoltuAddress(type(AddressRegistry).creationCode), LibAddressRegistry.ADDRESS_REGISTRY);
        assertEq(keccak256(type(AddressRegistry).runtimeCode), LibAddressRegistry.ADDRESS_REGISTRY_CODEHASH);
    }

    /// Actually deploying this contract's creation code through the Zoltu
    /// factory MUST land at the pinned address with the pinned code hash, so the
    /// derivation is checked against the factory rather than only against
    /// itself.
    function testAddressRegistryDeploysToPinnedAddress() external {
        LibRainDeploy.etchZoltuFactory(vm);

        address deployed = LibRainDeploy.deployZoltu(type(AddressRegistry).creationCode);

        assertEq(deployed, LibAddressRegistry.ADDRESS_REGISTRY);
        assertEq(deployed.codehash, LibAddressRegistry.ADDRESS_REGISTRY_CODEHASH);
        assertEq(keccak256(deployed.code), LibAddressRegistry.ADDRESS_REGISTRY_CODEHASH);
    }
}

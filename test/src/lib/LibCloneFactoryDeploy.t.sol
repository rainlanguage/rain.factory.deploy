// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibRainDeploy} from "rain-deploy-0.1.3/src/lib/LibRainDeploy.sol";
import {LibCloneFactoryDeploy} from "../../../src/lib/LibCloneFactoryDeploy.sol";
import {CloneFactory} from "../../../src/concrete/CloneFactory.sol";

contract LibCloneFactoryDeployTest is Test {
    function testDeployAddress() external {
        LibRainDeploy.etchZoltuFactory(vm);

        address deployedAddress = LibRainDeploy.deployZoltu(type(CloneFactory).creationCode);

        assertEq(deployedAddress, LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS);
        assertTrue(address(deployedAddress).code.length > 0, "Deployed address has no code");

        assertEq(address(deployedAddress).codehash, LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_CODEHASH);
    }

    function testExpectedCodeHash() external {
        CloneFactory cloneFactory = new CloneFactory();

        assertEq(address(cloneFactory).codehash, LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_CODEHASH);
    }
}

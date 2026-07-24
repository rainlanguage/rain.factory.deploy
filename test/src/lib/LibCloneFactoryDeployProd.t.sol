// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibRainDeploy} from "rain-deploy-0.1.3/src/lib/LibRainDeploy.sol";
import {LibCloneFactoryDeploy} from "../../../src/lib/LibCloneFactoryDeploy.sol";

/// @title LibCloneFactoryDeployProdTest
/// @notice Forks each supported network and verifies that CloneFactory is
/// deployed at the expected address with the expected codehash.
contract LibCloneFactoryDeployProdTest is Test {
    function _checkAllContracts() internal view {
        assertTrue(LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS.code.length > 0, "CloneFactory not deployed");
        assertEq(
            LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS.codehash,
            LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_CODEHASH
        );
    }

    /// CloneFactory MUST be deployed on Arbitrum.
    function testProdDeployArbitrum() external {
        vm.createSelectFork(LibRainDeploy.ARBITRUM_ONE);
        _checkAllContracts();
    }

    /// CloneFactory MUST be deployed on Base.
    function testProdDeployBase() external {
        vm.createSelectFork(LibRainDeploy.BASE);
        _checkAllContracts();
    }

    /// CloneFactory MUST be deployed on Base Sepolia.
    function testProdDeployBaseSepolia() external {
        vm.createSelectFork(LibRainDeploy.BASE_SEPOLIA);
        _checkAllContracts();
    }

    /// CloneFactory MUST be deployed on Flare.
    function testProdDeployFlare() external {
        vm.createSelectFork(LibRainDeploy.FLARE);
        _checkAllContracts();
    }

    /// CloneFactory MUST be deployed on Polygon.
    function testProdDeployPolygon() external {
        vm.createSelectFork(LibRainDeploy.POLYGON);
        _checkAllContracts();
    }
}

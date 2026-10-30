// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainDeployDeclarationChecks} from "rain-deploy-0.1.29/src/abstract/RainDeployDeclarationChecks.sol";
import {DeployDeclaration, DeploySuite} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {CloneFactoryDeploySuites} from "src/abstract/CloneFactoryDeploySuites.sol";

/// @title CloneFactoryDeploySuitesTest
/// @notice The declaration fields only a dispatch or a broadcast reads.
contract CloneFactoryDeploySuitesTest is CloneFactoryDeploySuites, RainDeployDeclarationChecks {
    function testEveryDispatchChoiceSelectsADeclaredSuite() external view {
        DeployDeclaration memory d = declaration();
        DeploySuite[] memory suites = allSuites(d);
        string[] memory choices = dispatchChoices(d);
        for (uint256 i = 0; i < choices.length; i++) {
            assertTrue(suiteIndex(suites, choices[i]) < suites.length, choices[i]);
        }
    }
}

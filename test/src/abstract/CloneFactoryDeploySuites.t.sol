// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainDeployDeclarationChecks} from "rain-deploy-0.1.29/src/abstract/RainDeployDeclarationChecks.sol";
import {DeployDeclaration} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {CloneFactoryDeploySuites} from "src/abstract/CloneFactoryDeploySuites.sol";

/// @title CloneFactoryDeploySuitesTest
contract CloneFactoryDeploySuitesTest is CloneFactoryDeploySuites, RainDeployDeclarationChecks {
    function testEveryReleaseResolvesToTheCandidate() external pure {
        DeployDeclaration memory d = declaration();
        for (uint256 i = 0; i < d.released.length; i++) {
            (, bool found) = candidateOf(d, d.released[i].suite);
            assertTrue(found, d.released[i].suite);
        }
    }

    function testDependenciesAreTheEmbeddedDeployments() external pure {
        checkDependenciesAreTheEmbeddedDeployments(declaration());
    }
}

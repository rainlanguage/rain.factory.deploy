// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    DeployCandidate,
    DeployDeclaration,
    DeployDependency,
    DeploySuite,
    RainDeploySuitesBase
} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.29/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.29/src/lib/LibRainDeployZoltuMechanism.sol";
import {CloneFactory} from "../concrete/CloneFactory.sol";
import {
    CREATION_CODE as CLONE_FACTORY_CREATION_CODE_CANDIDATE,
    RUNTIME_CODE as CLONE_FACTORY_RUNTIME_CODE_CANDIDATE
} from "../generated/candidate/CloneFactory.sol";
import {LibCloneFactoryDeploy} from "../lib/LibCloneFactoryDeploy.sol";
import {LibReleasedSuites} from "../lib/LibReleasedSuites.sol";

/// @title CloneFactoryDeploySuites
/// @notice Everything this repo deploys, declared ONCE: the hand-written
/// `clone-factory` candidate below, and the released side read from the
/// generated `LibReleasedSuites`, which `script/Build.sol` emits from the
/// frozen record.
///
/// It lives in `src/` rather than `test/` because `.soldeerignore` excludes
/// `test/` from the published package, and in a deploy repo the deployment
/// process is the product.
abstract contract CloneFactoryDeploySuites is RainDeploySuitesBase {
    /// This repo's declaration: every Rain network, Zoltu, the generated
    /// releases and `cloneFactoryCandidate()`.
    /// @return The declaration.
    function declaration() internal pure override returns (DeployDeclaration memory) {
        DeployDeclaration memory declared;
        LibRainDeployDeclaration.extend(declared);
        LibRainDeployZoltuMechanism.extend(declared);
        LibRainDeployDeclaration.addReleased(declared, LibReleasedSuites.releasedSuites());
        DeployCandidate[] memory candidates = new DeployCandidate[](1);
        candidates[0] = cloneFactoryCandidate();
        LibRainDeployDeclaration.addCandidates(declared, candidates);
        return declared;
    }

    /// This repo's rolling `CloneFactory` candidate. Named rather than reached
    /// by index into the declared candidates, because `script/Build.sol` emits
    /// the released-suites lib from THIS candidate specifically, and naming it
    /// keeps the suite key, the artifact path and the dependency list spelled
    /// once.
    ///
    /// `CloneFactory` reads nothing and calls nothing at construction, so it
    /// has no dependency that must already be on chain.
    /// @return The candidate.
    function cloneFactoryCandidate() internal pure returns (DeployCandidate memory) {
        return DeployCandidate({
            snapshot: DeploySuite({
                networks: new string[](0),
                suite: "clone-factory",
                creationCode: CLONE_FACTORY_CREATION_CODE_CANDIDATE,
                storedDeployedAddress: LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS,
                storedBytecodeHash: LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_CODEHASH,
                storedRuntimeCode: CLONE_FACTORY_RUNTIME_CODE_CANDIDATE,
                artifactPath: "src/concrete/CloneFactory.sol:CloneFactory",
                dependencies: new DeployDependency[](0),
                mechanismData: LibRainDeployZoltuMechanism.mechanismData()
            }),
            unanchorableReason: ""
        });
    }
}

// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {DeployCandidate, DeploySuite, RainDeploySuitesBase} from "./RainDeploySuitesBase.sol";
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
    /// @inheritdoc RainDeploySuitesBase
    function releasedSuites() internal pure override returns (DeploySuite[] memory) {
        return LibReleasedSuites.releasedSuites();
    }

    /// @inheritdoc RainDeploySuitesBase
    function candidateSuites() internal pure override returns (DeployCandidate[] memory) {
        DeployCandidate[] memory candidates = new DeployCandidate[](1);
        candidates[0] = cloneFactoryCandidate();
        return candidates;
    }

    /// This repo's rolling `CloneFactory` candidate. Named rather than reached
    /// by index into `candidateSuites`, because `script/Build.sol` emits the
    /// released-suites lib from THIS candidate specifically, and naming it
    /// keeps the suite key, the artifact path and the dependency list spelled
    /// once.
    ///
    /// `CloneFactory` reads nothing and calls nothing at construction, so it
    /// has no dependency that must already be on chain.
    /// @return The candidate.
    function cloneFactoryCandidate() internal pure returns (DeployCandidate memory) {
        return DeployCandidate({
            snapshot: DeploySuite({
                suite: "clone-factory",
                creationCode: CLONE_FACTORY_CREATION_CODE_CANDIDATE,
                storedDeployedAddress: LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS,
                storedBytecodeHash: LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_CODEHASH,
                storedRuntimeCode: CLONE_FACTORY_RUNTIME_CODE_CANDIDATE,
                artifactPath: "src/concrete/CloneFactory.sol:CloneFactory",
                dependencies: new address[](0)
            }),
            sourceCreationCode: type(CloneFactory).creationCode
        });
    }
}

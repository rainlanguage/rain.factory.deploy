// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {LibRainDeploy} from "rain-deploy-0.1.7/src/lib/LibRainDeploy.sol";
import {
    BYTECODE_HASH,
    DEPLOYED_ADDRESS,
    CREATION_CODE,
    RUNTIME_CODE,
    DEPENDENCIES
} from "../../../src/generated/candidate/CloneFactory.sol";
import {LibCloneFactoryDeploy} from "../../../src/lib/LibCloneFactoryDeploy.sol";
import {CloneFactory} from "../../../src/concrete/CloneFactory.sol";

/// @title LibCloneFactoryDeployCandidateTest
/// @notice The rolling `src/generated/candidate/CloneFactory.sol` snapshot and
/// the `LibCloneFactoryDeploy` alias must stay consistent end to end:
/// SOURCE (`type(CloneFactory).creationCode`) -> CANDIDATE pins -> ALIAS. CI
/// currency-checks that `forge script ./script/Build.sol` regenerates the
/// candidate and the alias byte-identically; these assertions pin what that
/// regeneration must hold true.
contract LibCloneFactoryDeployCandidateTest is Test {
    /// SOURCE -> CANDIDATE: the candidate records THIS repo's current
    /// `CloneFactory` creation code, so the pins describe what source compiles
    /// to rather than a stale snapshot.
    function testCandidateCreationCodeMatchesSource() external pure {
        assertEq(CREATION_CODE, type(CloneFactory).creationCode, "candidate creation code is not current source");
    }

    /// CANDIDATE self-consistency: Zoltu-deploying the recorded `CREATION_CODE`
    /// lands at the recorded `DEPLOYED_ADDRESS` with the recorded runtime code
    /// and code hash, and `keccak256(RUNTIME_CODE)` is that hash — the snapshot
    /// reproduces its own deployment.
    function testCandidateReproducesItsDeployment() external {
        LibRainDeploy.etchZoltuFactory(vm);
        address deployed = LibRainDeploy.deployZoltu(CREATION_CODE);
        assertEq(deployed, DEPLOYED_ADDRESS, "creation code deploys to a different address");
        assertEq(deployed.code, RUNTIME_CODE, "deployed runtime code is not the recorded runtime code");
        assertEq(deployed.codehash, BYTECODE_HASH, "deployed code hash is not the recorded hash");
        assertEq(keccak256(RUNTIME_CODE), BYTECODE_HASH, "recorded runtime code does not hash to the recorded hash");
    }

    /// CANDIDATE -> ALIAS: the shipped `LibCloneFactoryDeploy` re-exports the
    /// candidate's address and code hash unchanged, so consumers pin the
    /// candidate through a stable import path.
    function testAliasReExportsCandidate() external pure {
        assertEq(
            LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS,
            DEPLOYED_ADDRESS,
            "alias address is not the candidate address"
        );
        assertEq(
            LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_CODEHASH,
            BYTECODE_HASH,
            "alias code hash is not the candidate hash"
        );
    }

    /// `CloneFactory` has no contracts that must already have code on a network
    /// before it can be broadcast, so the recorded dependency list is empty.
    function testCandidateHasNoDependencies() external pure {
        address[] memory dependencies = abi.decode(DEPENDENCIES, (address[]));
        assertEq(dependencies.length, 0, "candidate records unexpected deploy dependencies");
    }
}

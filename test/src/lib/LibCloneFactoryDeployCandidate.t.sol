// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibRainDeploy} from "rain-deploy-0.1.3/src/lib/LibRainDeploy.sol";
import {LibCloneFactoryDeploy} from "../../../src/lib/LibCloneFactoryDeploy.sol";
import {CloneFactory} from "../../../src/concrete/CloneFactory.sol";
import {TestCloneable} from "../concrete/TestCloneable.sol";
import {
    BYTECODE_HASH as CLONE_FACTORY_BYTECODE_HASH_CANDIDATE,
    DEPLOYED_ADDRESS as CLONE_FACTORY_DEPLOYED_ADDRESS_CANDIDATE,
    CREATION_CODE as CLONE_FACTORY_CREATION_CODE_CANDIDATE,
    RUNTIME_CODE as CLONE_FACTORY_RUNTIME_CODE_CANDIDATE
} from "../../../src/generated/candidate/CloneFactory.pointers.sol";

/// @title LibCloneFactoryDeployCandidateTest
/// @notice The rolling `src/generated/candidate/` snapshot is the one snapshot
/// that is NOT frozen: it is regenerated from the current source on every
/// `forge script ./script/BuildPointers.sol` run, and `LibCloneFactoryDeploy`
/// aliases it. These tests pin the whole chain that makes that safe:
///
///   current source -> candidate `CREATION_CODE` -> candidate `DEPLOYED_ADDRESS`
///   -> `LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS`
///
/// Break any link — edit `CloneFactory` without regenerating, hand-edit a pin,
/// or point the generated lib at a different snapshot dir — and one of these
/// fails. Pure forge: no git, no shell, no `foundry.toml` parse, no chain.
contract LibCloneFactoryDeployCandidateTest is Test {
    /// The committed `candidate` snapshot MUST match the current source: the
    /// stored `CREATION_CODE` constant equals `type(CloneFactory).creationCode`.
    /// Fails if the source changes without regenerating `candidate` via
    /// `forge script ./script/BuildPointers.sol`.
    function testCandidateSelfConsistent() external pure {
        assertEq(CLONE_FACTORY_CREATION_CODE_CANDIDATE, type(CloneFactory).creationCode);
    }

    /// `LibCloneFactoryDeploy` — the lib consumers import — must alias the
    /// `candidate` snapshot and say so. Catches the generated lib being left
    /// pointing at a frozen numbered snapshot while `candidate` moves on, which
    /// would silently publish a stale address as the headline pin.
    function testCandidateIsTheAliasedSnapshot() external pure {
        assertEq(LibCloneFactoryDeploy.DEPLOY_TAG, "candidate");
        assertEq(LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS, CLONE_FACTORY_DEPLOYED_ADDRESS_CANDIDATE);
        assertEq(LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_CODEHASH, CLONE_FACTORY_BYTECODE_HASH_CANDIDATE);
    }

    /// `keccak256(RUNTIME_CODE) == BYTECODE_HASH` for the candidate — the pin is
    /// internally consistent, exactly as the frozen tags are required to be.
    function testCandidateRuntimeHashesToBytecodeHash() external pure {
        assertEq(keccak256(CLONE_FACTORY_RUNTIME_CODE_CANDIDATE), CLONE_FACTORY_BYTECODE_HASH_CANDIDATE);
    }

    /// Deploying the candidate's recorded `CREATION_CODE` via the Zoltu factory
    /// lands at its recorded `DEPLOYED_ADDRESS` with the recorded codehash — the
    /// snapshot reproduces its own deployment, so freezing it at release time
    /// records a reproducible deployment.
    function testCandidateCreationDeploysToPinnedAddress() external {
        LibRainDeploy.etchZoltuFactory(vm);
        address deployed = LibRainDeploy.deployZoltu(CLONE_FACTORY_CREATION_CODE_CANDIDATE);
        assertEq(deployed, CLONE_FACTORY_DEPLOYED_ADDRESS_CANDIDATE);
        assertEq(deployed.codehash, CLONE_FACTORY_BYTECODE_HASH_CANDIDATE);
        assertEq(keccak256(deployed.code), CLONE_FACTORY_BYTECODE_HASH_CANDIDATE);
    }

    /// The candidate's recorded bytecode must actually SERVE all four
    /// deterministic entry points, so the pin cannot record an address for
    /// bytecode that is missing one — which is what a frozen release copied from
    /// this candidate would then publish. Proved by Zoltu-deploying the recorded
    /// `CREATION_CODE` (NOT `new CloneFactory()`, so the assertion is about the
    /// snapshot rather than the source) and calling every entry point on the
    /// result through the `ICloneableFactoryV4` ABI: an entry point the
    /// dispatcher does not expose falls through to the (absent) fallback and
    /// reverts here. A byte scan of the runtime code would NOT prove this — a
    /// selector can sit in constant data without being dispatchable.
    function testCandidateDeployedBytecodeServesBothEntryPoints() external {
        LibRainDeploy.etchZoltuFactory(vm);
        CloneFactory factory = CloneFactory(LibRainDeploy.deployZoltu(CLONE_FACTORY_CREATION_CODE_CANDIDATE));
        TestCloneable implementation = new TestCloneable();

        bytes32 salt = keccak256("rain.factory.deploy.candidate.entry.points");
        bytes memory data = hex"f100dedb0a75";

        address predictedNamespaced = factory.predictDeterministicAddress(address(implementation), salt, address(this));
        address predictedOpen = factory.predictDeterministicAddressOpenSalt(address(implementation), data, salt);
        assertTrue(predictedNamespaced != predictedOpen);

        address childNamespaced = factory.cloneDeterministic(address(implementation), data, salt);
        address childOpen = factory.cloneDeterministicOpenSalt(address(implementation), data, salt);

        assertEq(childNamespaced, predictedNamespaced);
        assertEq(childOpen, predictedOpen);
        assertEq(TestCloneable(childNamespaced).sData(), data);
        assertEq(TestCloneable(childOpen).sData(), data);
    }
}

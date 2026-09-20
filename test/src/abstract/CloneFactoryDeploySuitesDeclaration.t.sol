// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.2/src/Test.sol";

import {LibRainDeploySnapshot} from "rain-deploy-0.1.8/src/lib/LibRainDeploySnapshot.sol";
import {DeployCandidate, DeploySuite} from "src/abstract/RainDeploySuitesBase.sol";
import {CloneFactoryDeploySuites} from "src/abstract/CloneFactoryDeploySuites.sol";

/// @title CloneFactoryDeploySuitesDeclarationTest
/// @notice The parts of this repo's deploy declaration that the inherited
/// `rain-deploy` assertions do not reach.
///
/// `RainDeployVerifySnapshot` checks that each suite's recorded pins agree with
/// its own creation code, that the candidate is anchored to source, and that
/// every frozen record file is declared. What it never asks about is the
/// declaration's METADATA — the suite key, the artifact path and the dependency
/// list — none of which is derivable from a snapshot's bytes, and each of which
/// steers something real: the key selects what `DEPLOYMENT_SUITE` broadcasts,
/// the artifact path is the explorer verification target, and the dependency
/// list gates broadcasting on a network.
contract CloneFactoryDeploySuitesDeclarationTest is CloneFactoryDeploySuites, Test {
    /// The record root, spelled once here as the directory the release tags live
    /// under.
    string constant GENERATED_DIR = "src/generated";

    /// The suite key prefix every `CloneFactory` suite shares: the rolling
    /// candidate is exactly this, and a frozen release is this, an at sign, and
    /// the release tag.
    string constant CLONE_FACTORY_SUITE = "clone-factory";

    /// Every frozen release directory MUST be declared by a released suite whose
    /// KEY names that tag.
    ///
    /// `testEveryFrozenSnapshotIsReleased` already walks the same record, but it
    /// matches a record file to a release by the DEPLOYED ADDRESS that file
    /// declares. Two releases that froze identical creation code therefore
    /// deploy to one address and are indistinguishable to it, so dropping one of
    /// them from the declaration leaves the other matching its record file and
    /// the check green — while the dropped release stops being broadcastable by
    /// key and stops carrying its own dependency list. `0_1_9` and `0_1_10` in
    /// this repo are exactly such a pair.
    ///
    /// Matching by key instead, so the question asked is "is THIS tag declared"
    /// rather than "does some declared suite happen to land on this address".
    /// Deliberately NOT also a size check. `rain-deploy` explains at length on
    /// `testEveryFrozenSnapshotIsReleased` why comparing the record's size against
    /// the declaration's would red-line permanently with no way to spell the
    /// exemption: a release deployed before this repo adopted the machinery has no
    /// frozen record and never will. Asking only that each tag present IS declared
    /// keeps that state legal while still catching a dropped release.
    function testEveryFrozenTagIsDeclaredByKey() external view {
        Vm.DirEntry[] memory entries = vm.readDir(GENERATED_DIR, 1);
        DeploySuite[] memory released = releasedSuites();

        uint256 tagsSeen = 0;
        for (uint256 i = 0; i < entries.length; i++) {
            if (!entries[i].isDir) {
                continue;
            }
            string[] memory components = vm.split(entries[i].path, "/");
            string memory tag = components[components.length - 1];
            if (!LibRainDeploySnapshot.isTag(tag)) {
                continue;
            }
            tagsSeen++;

            string memory expectedKey = string.concat(CLONE_FACTORY_SUITE, "@", tag);
            bool declared = false;
            for (uint256 j = 0; j < released.length; j++) {
                if (keccak256(bytes(released[j].suite)) == keccak256(bytes(expectedKey))) {
                    declared = true;
                    break;
                }
            }
            assertTrue(declared, string.concat("frozen release is not declared under its own key: ", expectedKey));
        }

        // A walk that found no tag would pass the loop above with no subject.
        // This repo has frozen releases, so finding none means the walk broke.
        assertTrue(tagsSeen > 0, "no frozen release directories found under the record root");
    }

    /// The rolling candidate is declared under the bare suite key, which is what
    /// `DEPLOYMENT_SUITE` selects to broadcast current source.
    function testCandidateDeclaresTheBareSuiteKey() external pure {
        assertEq(cloneFactoryCandidate().snapshot.suite, CLONE_FACTORY_SUITE);
    }

    /// `[external.package].version` MUST have a frozen snapshot directory.
    ///
    /// The version is the last RELEASED version and a release freezes the
    /// candidate into `src/generated/<tag>/` in lockstep, so a version naming a
    /// tag that does not exist is a release that was published without its
    /// record — the record every chain assertion afterwards reads.
    function testDeclaredVersionHasAFrozenSnapshot() external view {
        string memory version = vm.parseTomlString(vm.readFile("foundry.toml"), ".external.package.version");
        string memory tag = LibRainDeploySnapshot.tagForVersion(version);

        assertTrue(
            vm.exists(string.concat(GENERATED_DIR, "/", tag)),
            string.concat("released version has no frozen snapshot directory: ", tag)
        );
    }

    /// EVERY declared suite — released and candidate — records an EMPTY deploy
    /// dependency list.
    ///
    /// `CloneFactory` reads nothing and calls nothing at construction, and no
    /// release of it ever has, so nothing must already be on chain for it to be
    /// broadcast anywhere. A phantom dependency blocks a broadcast on every
    /// network where that address is codeless; a dropped one lets a genuinely
    /// dependent deployment through. The repo already pins this for the
    /// candidate's generated DEPENDENCIES constant — this asks the DECLARATION,
    /// which is what the broadcast and the chain check actually read.
    function testEveryDeclaredSuiteHasNoDeployDependencies() external pure {
        DeploySuite[] memory suites = allSuites();
        assertTrue(suites.length > 0, "no declared suites");

        for (uint256 i = 0; i < suites.length; i++) {
            assertEq(
                suites[i].dependencies.length,
                0,
                string.concat("suite declares unexpected deploy dependencies: ", suites[i].suite)
            );
        }
    }

    /// EVERY declared suite's `artifactPath` MUST name a source file that exists
    /// and the contract inside it.
    ///
    /// It is the `<path>:<Name>` handed to explorer verification after a
    /// broadcast. Nothing derives it — `DeploySuite` documents it as declared
    /// precisely because no naming convention recovers it — so a stale path
    /// survives every other assertion and fails after the gas is spent.
    function testEveryDeclaredSuiteArtifactPathResolves() external view {
        DeploySuite[] memory suites = allSuites();

        for (uint256 i = 0; i < suites.length; i++) {
            string[] memory parts = vm.split(suites[i].artifactPath, ":");
            assertEq(parts.length, 2, string.concat("artifactPath is not <path>:<Name>: ", suites[i].artifactPath));

            assertTrue(vm.exists(parts[0]), string.concat("artifactPath names no such file: ", parts[0]));
            assertTrue(
                vm.contains(vm.readFile(parts[0]), string.concat("contract ", parts[1])),
                string.concat("artifactPath file declares no such contract: ", suites[i].artifactPath)
            );
        }
    }
}

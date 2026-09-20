// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std-1.16.2/src/Test.sol";

import {LibRainDeploySnapshot} from "rain-deploy-0.1.8/src/lib/LibRainDeploySnapshot.sol";
import {DeployCandidate, DeploySuite} from "src/abstract/RainDeploySuitesBase.sol";
import {CloneFactoryDeploySuites} from "src/abstract/CloneFactoryDeploySuites.sol";

contract CloneFactoryDeploySuitesDeclarationTest is CloneFactoryDeploySuites, Test {
    string constant GENERATED_DIR = "src/generated";

    string constant CLONE_FACTORY_SUITE = "clone-factory";

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

        assertTrue(tagsSeen > 0, "no frozen release directories found under the record root");
    }

    function testCandidateDeclaresTheBareSuiteKey() external pure {
        assertEq(cloneFactoryCandidate().snapshot.suite, CLONE_FACTORY_SUITE);
    }

    function testDeclaredVersionHasAFrozenSnapshot() external view {
        string memory version = vm.parseTomlString(vm.readFile("foundry.toml"), ".external.package.version");
        string memory tag = LibRainDeploySnapshot.tagForVersion(version);

        assertTrue(
            vm.exists(string.concat(GENERATED_DIR, "/", tag)),
            string.concat("released version has no frozen snapshot directory: ", tag)
        );
    }

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

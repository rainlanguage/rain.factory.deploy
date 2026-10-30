// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BuildScript} from "rain-deploy-0.1.29/src/abstract/BuildScript.sol";
import {DeployCandidate, DeployDeclaration} from "rain-deploy-0.1.29/src/abstract/RainDeploySuitesBase.sol";
import {CloneFactoryDeploySuites} from "../src/abstract/CloneFactoryDeploySuites.sol";
import {LibRainDeploySnapshot} from "rain-deploy-0.1.29/src/lib/LibRainDeploySnapshot.sol";

/// One contract's generated files: the rolling snapshot, the alias lib that
/// re-exports its pins and the released-suites lib emitted from its record.
struct GeneratedContract {
    /// Places the snapshot inside `src/generated/<dir>/` and names both
    /// generated libs.
    string contractName;
    /// Prefix for the constants the alias lib exports, e.g. `CLONE_FACTORY`.
    string constantPrefix;
    /// Snapshots are written from its `sourceCreationCode` and
    /// `snapshot.dependencies`; the released lib takes its suite key and
    /// artifact path from its `snapshot`.
    DeployCandidate candidate;
}

/// @title Build
/// @notice Generates the deploy pins for every contract this repo deploys.
/// `generatedContracts()` is the only list, read by every hook below.
///
/// `run()` (what CI regenerates against) rewrites the rolling
/// `src/generated/candidate/` snapshot, the alias lib and the released-suites
/// libs. `cutRelease()` freezes the candidate into `src/generated/<tag>/`
/// first. The frozen snapshots are append-only historical records, never
/// regenerated here.
contract Build is BuildScript, CloneFactoryDeploySuites {
    /// Every contract this repo generates deploy pins for.
    /// @return The generated contracts.
    function generatedContracts() internal pure returns (GeneratedContract[] memory) {
        GeneratedContract[] memory contracts = new GeneratedContract[](1);
        contracts[0] = GeneratedContract({
            contractName: "CloneFactory", constantPrefix: "CLONE_FACTORY", candidate: cloneFactoryCandidate()
        });
        return contracts;
    }

    /// @inheritdoc BuildScript
    /// @dev In declaration order — the order the aggregate emits its entries
    /// in.
    function snapshotContractNames() internal pure override returns (string[] memory) {
        GeneratedContract[] memory contracts = generatedContracts();
        string[] memory names = new string[](contracts.length);
        for (uint256 i = 0; i < contracts.length; i++) {
            names[i] = contracts[i].contractName;
        }
        return names;
    }

    /// @inheritdoc BuildScript
    /// @dev Every alias lib, every released-suites lib and the aggregate over
    /// them.
    function regenerateLibs(DeployDeclaration memory d) internal override {
        GeneratedContract[] memory contracts = generatedContracts();
        string memory dir = libDir();
        for (uint256 i = 0; i < contracts.length; i++) {
            LibRainDeploySnapshot.writeAliasLib(
                vm, dir, contracts[i].contractName, contracts[i].constantPrefix, LibRainDeploySnapshot.CANDIDATE
            );
            LibRainDeploySnapshot.writeReleasedSuitesLib(
                vm, dir, recordRoot(), contracts[i].contractName, contracts[i].candidate.snapshot, d
            );
        }
        LibRainDeploySnapshot.writeReleasedSuitesAggregate(vm, dir, snapshotContractNames());
    }

    /// @inheritdoc BuildScript
    /// @dev Each alias lib.
    function buildGeneratedPaths() internal pure override returns (string[] memory) {
        GeneratedContract[] memory contracts = generatedContracts();
        string[] memory paths = new string[](contracts.length);
        for (uint256 i = 0; i < contracts.length; i++) {
            paths[i] = LibRainDeploySnapshot.pathForLib(
                LibRainDeploySnapshot.LIB_DIR, LibRainDeploySnapshot.aliasLibraryName(contracts[i].contractName)
            );
        }
        return paths;
    }

    /// @inheritdoc BuildScript
    function regenerateSnapshots() internal override {
        GeneratedContract[] memory contracts = generatedContracts();
        for (uint256 i = 0; i < contracts.length; i++) {
            LibRainDeploySnapshot.writeSnapshot(
                vm,
                recordRoot(),
                LibRainDeploySnapshot.CANDIDATE,
                contracts[i].contractName,
                vm.getCode(contracts[i].candidate.snapshot.artifactPath),
                contracts[i].candidate.snapshot.dependencies
            );
        }
    }
}

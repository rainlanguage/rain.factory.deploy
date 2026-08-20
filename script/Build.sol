// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {BuildScript} from "rain-deploy-0.1.7/src/abstract/BuildScript.sol";
import {LibRainDeploySnapshot} from "rain-deploy-0.1.7/src/lib/LibRainDeploySnapshot.sol";
import {CloneFactory} from "../src/concrete/CloneFactory.sol";

/// @title Build
/// @notice Generates `CloneFactory`'s deploy pins on the `BuildScript` rolling
/// candidate model:
///   - `regenerateSnapshots()` writes the rolling
///     `src/generated/candidate/CloneFactory.sol` snapshot (`BYTECODE_HASH`,
///     `DEPLOYED_ADDRESS`, `CREATION_CODE`, `RUNTIME_CODE`, `DEPENDENCIES`) from
///     what this repo currently compiles.
///   - `regenerateLibs()` writes `src/lib/LibCloneFactoryDeploy.sol`, the
///     stable-path alias that re-exports the candidate's address and code hash
///     so that snapshot stays the single source of truth.
///   - `snapshotContractNames()` names what a release freezes.
///
/// `run()` (what CI regenerates against) rewrites the candidate and the alias.
/// `cutRelease()` freezes the candidate into `src/generated/<tag>/` first. The
/// frozen `0_1_3`/`0_1_4`/`0_1_5` snapshots are append-only historical records,
/// never regenerated here.
contract Build is BuildScript {
    /// The single contract this repo deploys, named once for every hook.
    string constant CONTRACT_NAME = "CloneFactory";
    /// The prefix for the alias lib's exported constants —
    /// `CLONE_FACTORY_DEPLOYED_ADDRESS` / `CLONE_FACTORY_DEPLOYED_CODEHASH`.
    string constant CONSTANT_PREFIX = "CLONE_FACTORY";

    /// @inheritdoc BuildScript
    function snapshotContractNames() internal pure override returns (string[] memory) {
        string[] memory names = new string[](1);
        names[0] = CONTRACT_NAME;
        return names;
    }

    /// @inheritdoc BuildScript
    /// @dev `CloneFactory` has no on-chain dependencies that must pre-exist for
    /// it to be broadcast, so the dependency list is empty.
    function regenerateSnapshots() internal override {
        LibRainDeploySnapshot.writeSnapshot(
            vm, LibRainDeploySnapshot.CANDIDATE, CONTRACT_NAME, type(CloneFactory).creationCode, new address[](0)
        );
    }

    /// @inheritdoc BuildScript
    function regenerateLibs() internal override {
        LibRainDeploySnapshot.writeAliasLib(
            vm, LibRainDeploySnapshot.LIB_DIR, CONTRACT_NAME, CONSTANT_PREFIX, LibRainDeploySnapshot.CANDIDATE
        );
    }
}

// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCloneFactoryDeploy} from "../../../src/lib/LibCloneFactoryDeploy.sol";

/// @title LibCloneFactoryDeployTagTest
/// @notice A release moves three things together: `[package].version` in
/// `foundry.toml`, the frozen `src/generated/<tag>/` snapshot it names, and the
/// `LibCloneFactoryDeploy` pins aliased out of that snapshot. Nothing else
/// checks they still name the same tag. `LibCloneFactoryDeployTest` catches
/// bytecode drift (current source vs the aliased pins); this catches the other
/// direction — a hand-edited `[package].version` that outruns the snapshot, or
/// a lib left aliasing a superseded one — which would otherwise publish a
/// version whose pins belong to a different release.
contract LibCloneFactoryDeployTagTest is Test {
    string constant SNAPSHOT_DIR_PREFIX = "src/generated/";
    string constant SNAPSHOT_FILE_SUFFIX = "/CloneFactory.pointers.sol";

    /// The canonical `foundry.toml` `[package].version` in `src/generated/<tag>/`
    /// dir form, i.e. dots as underscores (`0.1.5` -> `0_1_5`). Read rather than
    /// hardcoded, so this passes across releases without hand-editing.
    function packageVersionTag() internal view returns (string memory) {
        bytes memory v = bytes(vm.parseTomlString(vm.readFile("foundry.toml"), ".package.version"));
        for (uint256 i = 0; i < v.length; i++) {
            if (v[i] == ".") v[i] = "_";
        }
        return string(v);
    }

    function snapshotPath() internal pure returns (string memory) {
        return string.concat(SNAPSHOT_DIR_PREFIX, LibCloneFactoryDeploy.DEPLOY_TAG, SNAPSHOT_FILE_SUFFIX);
    }

    /// The generated tag MUST equal the canonical `foundry.toml` version.
    function testDeployTag() external view {
        assertEq(LibCloneFactoryDeploy.DEPLOY_TAG, packageVersionTag());
    }

    /// A frozen snapshot by that name MUST exist — the version can only name a
    /// release that was actually snapshotted.
    function testDeployTagSnapshotExists() external view {
        assertTrue(vm.exists(snapshotPath()), "no src/generated snapshot for DEPLOY_TAG");
    }

    /// The pins the lib exposes MUST be the ones recorded in THAT snapshot, so
    /// the alias cannot silently point at another tag. Asserted against the
    /// snapshot text because Solidity cannot import a path built at runtime; the
    /// literals are rendered exactly as `BuildPointers` writes them.
    function testDeployTagSnapshotHoldsTheAliasedPins() external view {
        string memory snapshot = vm.readFile(snapshotPath());
        assertTrue(
            vm.contains(
                snapshot,
                string.concat(
                    "address constant DEPLOYED_ADDRESS = address(",
                    vm.toString(LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS),
                    ");"
                )
            ),
            "DEPLOY_TAG snapshot does not record the aliased deploy address"
        );
        assertTrue(
            vm.contains(
                snapshot,
                string.concat(
                    "bytes32 constant BYTECODE_HASH = bytes32(",
                    vm.toString(LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_CODEHASH),
                    ");"
                )
            ),
            "DEPLOY_TAG snapshot does not record the aliased codehash"
        );
    }
}

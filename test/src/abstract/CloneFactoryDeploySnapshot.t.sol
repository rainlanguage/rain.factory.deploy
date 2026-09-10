// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainDeployVerifySnapshot} from "rain-deploy-0.1.8/src/abstract/RainDeployVerifySnapshot.sol";
import {CloneFactoryDeploySuites} from "src/abstract/CloneFactoryDeploySuites.sol";

/// @title CloneFactoryDeploySnapshotTest
/// @notice Binds this repo's declaration to `RainDeployVerifySnapshot`: every
/// deploy-pin assertion over the `CloneFactory` suites that needs no network.
contract CloneFactoryDeploySnapshotTest is CloneFactoryDeploySuites, RainDeployVerifySnapshot {}

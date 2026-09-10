// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainDeployBroadcast} from "rain-deploy-0.1.8/src/abstract/RainDeployBroadcast.sol";
import {CloneFactoryDeploySuites} from "../src/abstract/CloneFactoryDeploySuites.sol";

/// @title Deploy
/// @notice The declaration plus `RainDeployBroadcast`; the `Manual sol
/// artifacts` workflow dispatches the `clone-factory` suite.
contract Deploy is CloneFactoryDeploySuites, RainDeployBroadcast {}

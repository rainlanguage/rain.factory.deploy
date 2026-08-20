// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainDeployVerifyChain} from "rain-deploy-0.1.7/src/abstract/RainDeployVerifyChain.sol";
import {CloneFactoryDeploySuites} from "src/abstract/CloneFactoryDeploySuites.sol";

/// @title CloneFactoryDeployChainTest
/// @notice Binds this repo's declaration to `RainDeployVerifyChain`: every
/// `CloneFactory` release is live, with the code it froze, on every supported
/// network.
contract CloneFactoryDeployChainTest is CloneFactoryDeploySuites, RainDeployVerifyChain {}

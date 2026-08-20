// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain-factory-0.1.9/src/interface/ICloneableV2.sol";

/// @title TestCloneable
/// @notice A cloneable contract that implements `ICloneableV2`. Initializes
/// whatever data is passed to `initialize` as `sData`. As `sData` is public,
/// we can easily test that it is set correctly.
contract TestCloneable is ICloneableV2 {
    bytes public sData;

    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) external returns (bytes32) {
        sData = data;
        return ICLONEABLE_V2_SUCCESS;
    }
}

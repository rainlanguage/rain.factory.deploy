// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2} from "rain-factory-0.1.5/src/interface/ICloneableV2.sol";

/// @title TestCloneableFailure
/// @notice A cloneable contract that implements `ICloneableV2` but always
/// fails initialization. Specifically, it returns whatever data is passed to
/// `initialize`, which is expected NOT to be `ICLONEABLE_V2_SUCCESS` for the
/// purposes of testing.
contract TestCloneableFailure is ICloneableV2 {
    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) external pure returns (bytes32 notSuccess) {
        (notSuccess) = abi.decode(data, (bytes32));
    }
}

// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {
    CLONE_FACTORY_V2_CREATION_CODE,
    CLONE_FACTORY_V2_TRIMMED_CODEHASH
} from "../../../src/legacy/CloneFactoryV2.sol";

/// Fork test: the record matches live code at a known plain-`CREATE` V2
/// factory. Offline test: constructing the recorded bytes yields that code.
contract CloneFactoryV2Test is Test {
    /// cyclo.sol's Flare deployment of the V2 factory.
    address constant FLARE_CLONE_FACTORY_V2 = 0x67fe33484cAF1a8D716b84b779569f79881788Ae;

    /// Trims a 53-byte ipfs+solc or a 12-byte solc-only CBOR appendix.
    function trimmedHash(bytes memory code) internal pure returns (bytes32) {
        uint256 length = code.length;
        uint256 appendix = uint256(uint16(bytes2(abi.encodePacked(code[length - 2], code[length - 1])))) + 2;
        require(appendix == 53 || appendix == 12, "unexpected CBOR appendix");
        assembly ("memory-safe") {
            mstore(code, sub(length, appendix))
        }
        return keccak256(code);
    }

    function testRecordReproducesTrimmedCodehash() external {
        bytes memory creationCode = CLONE_FACTORY_V2_CREATION_CODE;
        address deployed;
        assembly ("memory-safe") {
            deployed := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        assertTrue(deployed != address(0));
        assertEq(trimmedHash(deployed.code), CLONE_FACTORY_V2_TRIMMED_CODEHASH);
    }

    function testRecordMatchesFlareDeployment() external {
        vm.createSelectFork(vm.rpcUrl("flare"));
        assertEq(trimmedHash(FLARE_CLONE_FACTORY_V2.code), CLONE_FACTORY_V2_TRIMMED_CODEHASH);
    }
}

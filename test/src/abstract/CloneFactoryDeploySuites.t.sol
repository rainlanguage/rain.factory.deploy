// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {RainDeployDeclarationChecks} from "rain-deploy-0.1.38/src/abstract/RainDeployDeclarationChecks.sol";
import {DeployDeclaration, DeploySuite} from "rain-deploy-0.1.38/src/abstract/RainDeploySuitesBase.sol";
import {LibRainDeploy} from "rain-deploy-0.1.38/src/lib/LibRainDeploy.sol";
import {UnreleasableVersion} from "rain-deploy-0.1.38/src/lib/LibRainDeploySnapshot.sol";
import {CloneFactoryDeploySuites} from "src/abstract/CloneFactoryDeploySuites.sol";
import {LibReleasedSuites} from "src/lib/LibReleasedSuites.sol";

/// @title CloneFactoryDeploySuitesTest
contract CloneFactoryDeploySuitesTest is CloneFactoryDeploySuites, RainDeployDeclarationChecks {
    function testEveryReleaseResolvesToTheCandidate() external pure {
        DeployDeclaration memory d = declaration();
        for (uint256 i = 0; i < d.released.length; i++) {
            (, bool found) = candidateOf(d, d.released[i].suite);
            assertTrue(found, d.released[i].suite);
        }
    }

    function testDependenciesAreTheEmbeddedDeployments() external view {
        checkDependenciesAreTheEmbeddedDeployments(declaration());
    }

    function testDispatchChoicesAreTheSuiteKeys() external view {
        checkDispatchChoicesAreTheSuiteKeys(declaration());
    }

    /// Asserts `suite` is required on exactly `networks`, in order.
    /// @param suite The suite.
    /// @param networks The networks.
    function assertNetworks(DeploySuite memory suite, string[] memory networks) internal pure {
        assertEq(suite.networks.length, networks.length, suite.suite);
        for (uint256 i = 0; i < networks.length; i++) {
            assertEq(suite.networks[i], networks[i], suite.suite);
        }
    }

    /// Every release cut before `zerog` joined and not in `releasesOnZerog()`
    /// is required on the networks before it, and every other suite, the
    /// candidate included, on every declared network, `zerog` included.
    function testReleasesAreNarrowedToTheNetworksTheyWereCutFor() external pure {
        DeployDeclaration memory d = declaration();
        DeploySuite[] memory suites = allSuites(d);
        uint256 narrowed = 0;
        uint256 onZerog = 0;
        for (uint256 i = 0; i < suites.length; i++) {
            if (releasedBeforeZerog(suites[i].suite) && !releasedOnZerog(suites[i].suite)) {
                narrowed++;
                assertNetworks(suites[i], networksBeforeZerog());
            } else {
                if (releasedOnZerog(suites[i].suite)) {
                    onZerog++;
                }
                assertNetworks(suites[i], d.networks);
            }
        }
        assertEq(d.networks.length, 10);
        assertEq(d.networks[9], LibRainDeploy.ZEROG);
        assertEq(narrowed, 20);
        assertEq(onZerog, releasesOnZerog().length);
    }

    /// Asserts `narrowReleasedNetworks` set `suite` to `networksBeforeZerog()`
    /// if it was cut before `zerog` joined and is not in `releasesOnZerog()`,
    /// and left its networks empty, for the declaration to fill, otherwise.
    /// @param suite The suite, after narrowing.
    function assertNarrowed(DeploySuite memory suite) internal pure {
        if (releasedBeforeZerog(suite.suite) && !releasedOnZerog(suite.suite)) {
            assertNetworks(suite, networksBeforeZerog());
        } else {
            assertEq(suite.networks.length, 0, suite.suite);
        }
    }

    /// Every release is narrowed wherever it sits in the list, not only where
    /// the generated order puts it: reversed, and on its own. The generated
    /// order can end on a release that is not narrowed, so a loop that skipped
    /// an end of the list could pass `declaration()` and still require an old
    /// release on `zerog`.
    function testNarrowReleasedNetworksNarrowsEveryPosition() external pure {
        DeploySuite[] memory released = LibReleasedSuites.releasedSuites();
        DeploySuite[] memory reversed = new DeploySuite[](released.length);
        for (uint256 i = 0; i < released.length; i++) {
            reversed[i] = released[released.length - 1 - i];
        }
        narrowReleasedNetworks(reversed);
        for (uint256 i = 0; i < reversed.length; i++) {
            assertNarrowed(reversed[i]);
        }

        released = LibReleasedSuites.releasedSuites();
        for (uint256 i = 0; i < released.length; i++) {
            DeploySuite[] memory alone = new DeploySuite[](1);
            alone[0] = released[i];
            assertNarrowed(narrowReleasedNetworks(alone)[0]);
        }
    }

    /// Of the releases cut before `zerog` joined, `zerog` requires exactly
    /// 0_1_1 and 0_1_15, and it requires every release cut after. 0_1_11 to
    /// 0_1_14 share 0_1_15's address and code, so its deploy puts them on
    /// `zerog` too, but like every other release up to the cutoff they are
    /// required only where they were deployed.
    function testZerogRequiresOnlyTheReleasesDeployedThere() external pure {
        DeployDeclaration memory d = declaration();
        string[] memory onZerog = new string[](2);
        onZerog[0] = "clone-factory@0_1_1";
        onZerog[1] = "clone-factory@0_1_15";
        uint256 required = 0;
        for (uint256 i = 0; i < d.released.length; i++) {
            if (!releasedBeforeZerog(d.released[i].suite)) {
                assertTrue(requiresSuiteOn(d.released[i], LibRainDeploy.ZEROG), d.released[i].suite);
            } else if (requiresSuiteOn(d.released[i], LibRainDeploy.ZEROG)) {
                assertEq(d.released[i].suite, onZerog[required]);
                required++;
            } else {
                assertTrue(requiresSuiteOn(d.released[i], LibRainDeploy.ROBINHOOD), d.released[i].suite);
            }
        }
        assertEq(required, onZerog.length);
        assertFalse(requiresSuiteOn(suiteByName(d, "clone-factory@0_1_14"), LibRainDeploy.ZEROG));
        assertFalse(requiresSuiteOn(suiteByName(d, "clone-factory@0_2_14"), LibRainDeploy.ZEROG));
        assertTrue(requiresSuiteOn(suiteByName(d, "clone-factory"), LibRainDeploy.ZEROG));
    }

    /// Every tag in `releasesOnZerog()` names a frozen release cut at or
    /// before `LAST_RELEASE_BEFORE_ZEROG`, and the cutoff names one too, so
    /// neither can name a release that does not exist.
    function testZerogTagsAndTheCutoffNameFrozenReleases() external pure {
        DeployDeclaration memory d = declaration();
        string[] memory tags = releasesOnZerog();
        assertGt(tags.length, 0);
        for (uint256 i = 0; i < tags.length; i++) {
            string memory key = string.concat(cloneFactoryCandidate().snapshot.suite, "@", tags[i]);
            assertTrue(releasedBeforeZerog(key), key);
            assertEq(suiteByName(d, key).suite, key);
        }
        string memory cutoff = string.concat(cloneFactoryCandidate().snapshot.suite, "@", LAST_RELEASE_BEFORE_ZEROG);
        assertEq(suiteByName(d, cutoff).suite, cutoff);
    }

    /// The roster before `zerog` is the supported roster without it. This
    /// fails when rain-deploy adds another network, on purpose. The fix then
    /// is a cutoff for that network, not an entry in the frozen
    /// `networksBeforeZerog()`, which would require old releases on a network
    /// they were never deployed to.
    function testNetworksBeforeZerogAreTheSupportedNetworksWithoutZerog() external pure {
        string[] memory before = networksBeforeZerog();
        string[] memory supported = LibRainDeploy.supportedNetworks();
        assertEq(before.length + 1, supported.length);
        for (uint256 i = 0; i < before.length; i++) {
            assertEq(before[i], supported[i]);
        }
        assertEq(supported[before.length], LibRainDeploy.ZEROG);
    }

    /// A release is before `zerog` up to and including
    /// `LAST_RELEASE_BEFORE_ZEROG`, compared by number rather than text, and
    /// an untagged key is not.
    function testReleasedBeforeZerogBoundary() external pure {
        assertTrue(releasedBeforeZerog("clone-factory@0_2_14"));
        assertTrue(releasedBeforeZerog("clone-factory@0_2_9"));
        assertTrue(releasedBeforeZerog("clone-factory@0_1_15"));
        assertTrue(releasedBeforeZerog("clone-factory@0_1_1"));
        assertFalse(releasedBeforeZerog("clone-factory@0_2_15"));
        assertFalse(releasedBeforeZerog("clone-factory@0_2_100"));
        assertFalse(releasedBeforeZerog("clone-factory@0_3_0"));
        assertFalse(releasedBeforeZerog("clone-factory@1_0_0"));
        assertFalse(releasedBeforeZerog("clone-factory"));
    }

    /// Only the tags `releasesOnZerog()` lists are on `zerog`, matched whole
    /// rather than by prefix, and an untagged key is not.
    function testReleasedOnZerog() external pure {
        assertTrue(releasedOnZerog("clone-factory@0_1_1"));
        assertTrue(releasedOnZerog("clone-factory@0_1_15"));
        assertFalse(releasedOnZerog("clone-factory@0_1_14"));
        assertFalse(releasedOnZerog("clone-factory@0_1_10"));
        assertFalse(releasedOnZerog("clone-factory@0_1_150"));
        assertFalse(releasedOnZerog("clone-factory@0_2_14"));
        assertFalse(releasedOnZerog("clone-factory"));
    }

    /// A wrapper so `releasedBeforeZerog` reverts at a depth `vm.expectRevert`
    /// reaches.
    /// @param suite The suite key.
    /// @return Whether the release was cut before `zerog` joined the roster.
    function externalReleasedBeforeZerog(string memory suite) external pure returns (bool) {
        return releasedBeforeZerog(suite);
    }

    /// A wrapper so `releasedOnZerog` reverts at a depth `vm.expectRevert`
    /// reaches.
    /// @param suite The suite key.
    /// @return Whether the release is deployed to `zerog`.
    function externalReleasedOnZerog(string memory suite) external pure returns (bool) {
        return releasedOnZerog(suite);
    }

    /// A key whose tag is not `isTag` is refused rather than ordered or
    /// matched, so a misspelled tag cannot land on either side of the cutoff.
    function testReleaseTagRefusesANonTag() external {
        string[5] memory tags = ["0_1", "0_1_15a", "0_1_15_1", "0_01_15", ""];
        for (uint256 i = 0; i < tags.length; i++) {
            string memory key = string.concat("clone-factory@", tags[i]);
            vm.expectRevert(abi.encodeWithSelector(UnreleasableVersion.selector, tags[i]));
            this.externalReleasedBeforeZerog(key);
            vm.expectRevert(abi.encodeWithSelector(UnreleasableVersion.selector, tags[i]));
            this.externalReleasedOnZerog(key);
        }
    }
}

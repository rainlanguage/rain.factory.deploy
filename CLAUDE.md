# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

rain.factory.deploy is the **deployment** half of `rain.factory`: the concrete
`CloneFactory` contract plus its deployed address + codehash pins. The core
contract `CloneFactory` clones any contract implementing `ICloneableV2` (an
interface it imports from the `rain-factory` Soldeer package) and atomically
initializes it.

License: LicenseRef-DCL-1.0 (DecentraLicense). All source files must include
SPDX headers.

## Build & Test Commands

This project uses **Nix + Foundry (Forge)**. Everything runs in the rainix
`sol-shell`, the same shell CI uses:

```bash
nix develop .#sol-shell
```

Soldeer dependencies are not committed (`dependencies/` is gitignored), so
install them before the first build:

```bash
nix develop .#sol-shell -c forge soldeer install
```

Each command below has a matching CI job:

```bash
# Build
nix develop .#sol-shell -c forge build

# Run all tests. The five LibCloneFactoryDeployProdTest fork tests read the
# live chains and need ARBITRUM_RPC_URL, BASE_RPC_URL, BASE_SEPOLIA_RPC_URL,
# FLARE_RPC_URL and POLYGON_RPC_URL; without them only those five fail.
nix develop .#sol-shell -c forge test

# Run a specific test, or a specific file
nix develop .#sol-shell -c forge test --match-test testCloneDeterministic
nix develop .#sol-shell -c forge test --match-path test/src/concrete/CloneFactoryCloneDeterministic.t.sol

# Formatting (CI runs `forge fmt --check`)
nix develop .#sol-shell -c forge fmt

# Static analysis
nix develop .#sol-shell -c slither .

# License/legal checks (REUSE compliance)
nix develop .#sol-shell -c reuse lint

# Regenerate the deploy pins for the current [package].version
nix develop .#sol-shell -c bash -c 'forge script ./script/BuildPointers.sol && forge fmt'
```

## Architecture

The `ICloneable*` interfaces are NOT in this repo. They live in
[`rain.factory`](https://github.com/rainlanguage/rain.factory) and arrive here
as the `rain-factory` Soldeer dependency, so they are read under
`dependencies/rain-factory-<version>/src/interface/`.

- `src/concrete/CloneFactory.sol` — The single concrete implementation of
  `ICloneableFactoryV3`. Uses OpenZeppelin `Clones.cloneDeterministic()`; there
  is no plain `clone()`.
- `src/lib/LibCloneFactoryDeploy.sol` — Deterministic deployment address and
  codehash constants (generated; aliases the current tag's
  `src/generated/<tag>/` snapshot).
- `src/generated/<tag>/CloneFactory.pointers.sol` — Frozen per-release
  deploy-pin snapshots: creation code, runtime code, bytecode hash, deployed
  address.
- `script/BuildPointers.sol` — Regenerates the snapshot for the current
  `[package].version` and the `LibCloneFactoryDeploy` alias.
- `script/Deploy.sol` — The Zoltu deploy script.

## Solidity Conventions

- Solidity version: concrete contracts, scripts and tests pin `=0.8.25` (exact);
  library and generated files float `^0.8.25` so downstream soldeer consumers on
  a different `0.8.x` can still compile them
- EVM target: Cancun
- Optimizer: enabled, 100,000 runs
- No CBOR metadata (`cbor_metadata = false`, `bytecode_hash = "none"`)
- Dependencies are managed with Soldeer (`[dependencies]` in `foundry.toml` +
  `soldeer.lock`, vendored under `dependencies/`): forge-std,
  @openzeppelin-contracts, rain-extrospection, rain-deploy, rain-sol-codegen,
  rain-factory

## Deployment

Deployed via the deterministic Zoltu deployer (from `rain.deploy`), so the
address is a pure function of the bytecode. The canonical address and codehash
are committed in `LibCloneFactoryDeploy.sol`. `script/Deploy.sol` deploys the
`clone-factory` suite to the five networks `LibRainDeploy.supportedNetworks()`
returns: Arbitrum One, Base, Base Sepolia, Flare and Polygon.

A deploy is a human-dispatched run of the `Manual sol artifacts` workflow
(`workflow_dispatch` → `rainix-manual-sol-artifacts`), never a merge and never
part of the release workflow.

## Releases and versioning

This is a **deploy repo**, not a library repo, so nothing publishes on merge:

- `[package].version` in `foundry.toml` is the **last released** version (it
  names the current `src/generated/<tag>/` snapshot), not a next-version slot. A
  normal PR does not bump it; only a release moves it.
- A human pushes a `sol-v<version>` tag, which runs `rainix-tag-release`: it
  writes the version from the tag into `foundry.toml`, regenerates the snapshot
  (`forge script ./script/BuildPointers.sol && forge fmt`), verifies the live
  chains match the fresh pins with `forge test`, publishes `rain-factory-deploy`
  to Soldeer, and commits the new snapshot back to `main`.
- The on-chain deploy happens **before** tagging, via the manual dispatch above;
  `rainix-tag-release` never broadcasts, it only attests.
- Existing `src/generated/<tag>/` snapshots are frozen: a release adds a new tag
  directory, it never edits or deletes an existing one. CI enforces this.

## CI

`.github/workflows/rainix-sol.yaml` calls the rainix `rainix-sol` reusable on
every push, which runs three parallel jobs:

- `test` — `forge test -vvv`. The `LibCloneFactoryDeployProdTest` fork tests
  need the `RPC_URL_*_FORK` secrets.
- `static` — `slither .`, `forge fmt --check`, `rainix-sol-single-contract` (one
  contract per `.sol` file), plus the org-wide gates: no ignored tests, no git
  submodules, no `@custom:` NatSpec, and append-only `src/generated/<tag>/`
  snapshots.
- `legal` — `reuse lint`.

The other two workflows never run on push: `package-release.yaml` fires only on
a `sol-v*` tag, and `manual-sol-artifacts.yaml` only on `workflow_dispatch`.

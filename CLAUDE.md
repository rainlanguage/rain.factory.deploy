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

This project uses **Nix + Foundry (Forge)**. Enter the dev shell first:

```bash
nix develop
```

Then use rainix tasks:

```bash
# Run all tests
nix develop -c rainix-sol-test

# Static analysis (Slither)
nix develop -c rainix-sol-static

# License/legal checks (REUSE compliance)
nix develop -c rainix-sol-legal

# Prelude (dependency setup, run before other tasks)
nix develop -c rainix-sol-prelude
```

Direct Forge commands also work inside the nix shell:

```bash
# Run all tests
forge test

# Run a specific test
forge test --match-test testCloneDeterministic

# Run tests in a specific file
forge test --match-path test/src/concrete/CloneFactoryCloneDeterministic.t.sol

# Build
forge build
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

Deployed via deterministic Zoltu deployer (from `rain.deploy`). The canonical
deployment address and codehash are committed in `LibCloneFactoryDeploy.sol`.
Deployment scripts are in `script/Deploy.sol` targeting Arbitrum, Base, Base
Sepolia, Flare, and Polygon.

## CI

GitHub Actions runs three parallel jobs on every push: `rainix-sol-test`,
`rainix-sol-static`, `rainix-sol-legal`. Fork tests require RPC URL secrets.

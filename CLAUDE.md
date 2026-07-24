# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

rain.factory.deploy is a Solidity library providing EIP1167 minimal proxy (clone)
factory contracts for the Rain ecosystem. The core contract `CloneFactory`
clones any contract implementing `ICloneableV2` and atomically initializes it.

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

- `src/interface/ICloneableV2.sol` — Interface for cloneable contracts.
  `initialize(bytes)` must return `ICLONEABLE_V2_SUCCESS` (keccak256 hash) on
  success.
- `src/interface/ICloneableFactoryV2.sol` — Legacy factory interface: the
  nonce-dependent `clone(address, bytes)` and `NewClone` event. Superseded by
  `ICloneableFactoryV3` for `CloneFactory`; still published for other consumers.
- `src/interface/ICloneableFactoryV3.sol` — Current factory interface.
  Deterministic-only: `cloneDeterministic(address, bytes, bytes32)` +
  `predictDeterministicAddress(address, bytes32, address)` (CREATE2, salt
  namespaced by `msg.sender`) and its own `NewClone` event. Standalone — does
  NOT extend `ICloneableFactoryV2`, because the non-deterministic `clone()` was
  intentionally dropped.
- `src/concrete/CloneFactory.sol` — The single concrete implementation of
  `ICloneableFactoryV3`. Uses OpenZeppelin `Clones.cloneDeterministic()`; there
  is no plain `clone()`.
- `src/lib/LibCloneFactoryDeploy.sol` — Deterministic deployment address and
  codehash constants (generated; aliases the current tag's
  `src/generated/<tag>/` snapshot).
- `src/interface/deprecated/` — Legacy interfaces (`ICloneableV1`,
  `ICloneableFactoryV1`, `IFactory`). Do not use for new work.

## Solidity Conventions

- Solidity version: concrete contracts pin `=0.8.25` (exact); interface and
  library files float `^` (the interfaces use `^0.8.18`) so downstream soldeer
  consumers on a different `0.8.x` can still compile them
- EVM target: Cancun
- Optimizer: enabled, 100,000 runs
- No CBOR metadata (`cbor_metadata = false`, `bytecode_hash = "none"`)
- Dependencies are managed with Soldeer (`[dependencies]` in `foundry.toml` +
  `soldeer.lock`, vendored under `dependencies/`): forge-std,
  @openzeppelin-contracts, rain-extrospection, rain-deploy, rain-sol-codegen

## Deployment

Deployed via deterministic Zoltu deployer (from `rain.deploy`). The canonical
deployment address and codehash are committed in `LibCloneFactoryDeploy.sol`.
Deployment scripts are in `script/Deploy.sol` targeting Arbitrum, Base, Base
Sepolia, Flare, and Polygon.

## CI

GitHub Actions runs three parallel jobs on every push: `rainix-sol-test`,
`rainix-sol-static`, `rainix-sol-legal`. Fork tests require RPC URL secrets.

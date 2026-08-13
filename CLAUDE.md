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

# Regenerate the rolling candidate snapshot + the pin lib. Run this after ANY
# change to CloneFactory or the compiler config, or testCandidateSelfConsistent
# fails. A clean tree must stay clean after running it.
nix develop .#sol-shell -c bash -c 'forge script ./script/BuildPointers.sol && forge fmt'
```

## Architecture

The `ICloneable*` interfaces are NOT in this repo. They live in
[`rain.factory`](https://github.com/rainlanguage/rain.factory) and arrive here
as the `rain-factory` Soldeer dependency, so they are read under
`dependencies/rain-factory-<version>/src/interface/`.

- `src/concrete/CloneFactory.sol` — The single concrete implementation of
  `ICloneableFactoryV4`. Uses OpenZeppelin `Clones.cloneDeterministic()` for
  both deterministic entry points; there is no plain `clone()`. The two entry
  points differ ONLY in the salt they pass to `Clones`:
  - `cloneDeterministic` / `predictDeterministicAddress` (declared on
    `ICloneableFactoryV3`, which V4 extends) namespace the caller-supplied salt
    by `msg.sender` via `_effectiveSalt`, so a caller's `(implementation, salt)`
    address cannot be reached by another account. `data` is outside that
    derivation.
  - `cloneDeterministicOpenSalt` / `predictDeterministicAddressOpenSalt` derive
    the salt via `_effectiveOpenSalt` as
    `keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)))`,
    so the address carries no identity and anyone can deploy it, but everyone
    who does deploys the same contract initialized with the same bytes.
    `predictDeterministicAddressOpenSalt` therefore takes `data` — it is one of
    the derivation's inputs. The residual condition on implementations
    (`initialize` MUST NOT read `tx.origin`) is specified by the NatSpec on
    `ICloneableFactoryV4.cloneDeterministicOpenSalt`, which lives in
    rain.factory, not here.

  Both share `_requireImplementationCode` and `_initializeClone`, so
  clone-and-initialize is atomic and the failure modes are identical across the
  two.

  **The two salt derivations MUST have disjoint images**, and `CloneFactory` is
  where `ICloneableFactoryV4`'s MUST NOT on the factory is actually held: 96
  bytes led by the domain constant versus 64 bytes led by a left-padded address.
  Drop the domain word and any account `A` reaches every open-salt address whose
  `salt` equals `bytes32(uint256(uint160(A)))` via `cloneDeterministic` with
  arbitrary `data`. Do not add a third entry point that hashes to either shape,
  and do not change the shape of either preimage.
  `testCloneDeterministicOpenSaltDisjointFromNamespacedAtLeftPaddedAddressSalt`
  is the gate.
- `src/lib/LibCloneFactoryDeploy.sol` — Deterministic deployment address and
  codehash constants (generated; aliases the rolling `src/generated/candidate/`
  snapshot).
- `src/generated/candidate/CloneFactory.pointers.sol` — The rolling snapshot of
  what the current source compiles to: creation code, runtime code, bytecode
  hash, deployed address. Regenerated on every `BuildPointers` run.
- `src/generated/<tag>/CloneFactory.pointers.sol` — Frozen release records
  (`0_1_3`, `0_1_4`, `0_1_5`), each a copy of `candidate` frozen by a release
  tag. Never regenerated.
- `script/BuildPointers.sol` — Regenerates `candidate` and the
  `LibCloneFactoryDeploy` alias. Never writes a numbered snapshot.
- `script/cut-release.sh` — Regenerates `candidate`, then freezes it as
  `src/generated/<tag>/` at release time. The only thing that creates a numbered
  snapshot. Regenerating first is what makes the frozen record equal to the pins
  the release actually publishes.
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

This is a **deploy repo**, not a library repo, so nothing publishes on merge. It
uses the **rolling-candidate** model:

- `src/generated/candidate/` is the rolling snapshot of what the current source
  compiles to. `BuildPointers` rewrites it every run and `LibCloneFactoryDeploy`
  aliases it, so the pins consumers import always describe this repo's source.
  `testCandidateSelfConsistent` is the gate.
- `[package].version` in `foundry.toml` **does not name a snapshot** and no
  Solidity reads it. It is a placeholder that `rainix-tag-release` overwrites
  from the pushed tag. Nothing has been released yet — Soldeer has zero
  `rain-factory-deploy` revisions.
- A human pushes a `sol-v<version>` tag, which runs `rainix-tag-release`: it
  writes the version from the tag into `foundry.toml`, runs
  `bash script/cut-release.sh` (which regenerates `candidate`, then copies it to
  `src/generated/<tag>/`), verifies the live chains match the pins with
  `forge test`, publishes `rain-factory-deploy` to Soldeer, and commits the new
  snapshot back to `main`.
- The on-chain deploy happens **before** tagging, via the manual dispatch above;
  `rainix-tag-release` never broadcasts, it only attests.
- Existing `src/generated/<tag>/` snapshots are frozen: a release adds a new tag
  directory, it never edits or deletes an existing one. CI enforces this. The
  gate's tag test is "three `_`-separated numeric parts", so `candidate/` is
  outside it and free to roll.
- Because the pin lib tracks `candidate`, changing `CloneFactory`'s bytecode
  makes the five `LibCloneFactoryDeployProdTest` fork tests red until that
  bytecode is deployed. That is deliberate: deploy before merge.

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

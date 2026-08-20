# CLAUDE.md

Only what a capable agent would get _wrong_ from this repo alone. Layout, dev
shells, build/test commands, dependency lists, and which command CI runs are all
discoverable and deliberately absent (rainlanguage/rainix#298).

## What this repo is

rain.factory.deploy is the **deploy half** of `rain.factory`: the concrete
`CloneFactory` (clones any `ICloneableV2` via OpenZeppelin
`Clones.cloneDeterministic()` — there is no plain `clone()`) plus its deployed
address + codehash pins. The `ICloneable*` **interfaces are NOT here** — they
live in `rain.factory` and arrive as the `rain-factory` Soldeer dependency
(`dependencies/rain-factory-<version>/src/interface/`).

## Conventions an agent would get wrong

- Pragma: concrete contracts, scripts and tests pin `=0.8.25` (exact); library
  and generated files float `^0.8.25` so downstream soldeer consumers on another
  `0.8.x` still compile them.
- Optimizer 100,000 runs; no CBOR metadata (`cbor_metadata = false`,
  `bytecode_hash = "none"`). The deployed address is a pure function of the
  bytecode (deterministic Zoltu deployer), so any of these changing moves the
  pins.
- All source files need SPDX headers (LicenseRef-DCL-1.0).

## Deploy-pin invariants (the hazards)

- `src/generated/candidate/` is the **rolling** snapshot, rewritten from what
  source compiles to by `script/Build.sol` and currency-checked by CI.
  `LibCloneFactoryDeploy.sol` aliases it.
- `src/generated/<tag>/` snapshots are **frozen**: `cutRelease()` freezes the
  candidate into a new tag dir; a release only ADDS one, never edits or deletes
  an existing one. CI enforces append-only.
- `[package].version` is the **last released** version. A normal PR does not
  bump it; only a release moves it, in lockstep with a new frozen `<tag>/`.
- Generated files (`src/generated/`, `src/lib/LibCloneFactoryDeploy.sol`) — do
  not hand-edit; `script/Build.sol` regenerates them.

## Release / deploy shape

- The on-chain deploy is a human-dispatched `Manual sol artifacts` run
  (`workflow_dispatch`), done **before** tagging — never on merge, never part of
  the release workflow, and it is what actually broadcasts.
- A manual `sol-v<version>` tag is the sole release trigger. The release
  mechanics live in rainix's `rainix-tag-release` reusable, not here.

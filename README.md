# rain.factory.deploy

The **deployment** half of `rain.factory`: the concrete `CloneFactory` contract,
its deployed address + codehash pins (`LibCloneFactoryDeploy`), the frozen
per-tag deploy-pin snapshots under `src/generated/<tag>/`, and the deploy
script.

The **library** half — the `ICloneable*` interfaces — lives in
[`rain.factory`](https://github.com/rainlanguage/rain.factory) and is imported
here as the `rain-factory` Soldeer package. Consumers that need only the
interfaces depend on `rain-factory`; consumers that need the deployed
address/codehash pins depend on `rain-factory-deploy`.

## Releases

This is a deploy repo: releases are **manual `sol-v*` tags**, not merges.

The on-chain deploy is a separate, human-dispatched step, run **before**
tagging: the `Manual sol artifacts` workflow runs `script/Deploy.sol` for the
`clone-factory` suite. Tagging then runs `rainix-tag-release`, which regenerates
the snapshot for the tagged version, verifies the live chains match those fresh
pins, publishes `rain-factory-deploy` to Soldeer, and commits the frozen
snapshot back to `main`. It never broadcasts a deploy itself.

Nothing publishes on merge, so `[package].version` and the frozen
`src/generated/<tag>/` snapshot it names only ever move together.

See rainlanguage/rain.factory#46 for the split rationale.

## Audit

This repo has never been audited under its own name. It carries three
**inherited** Protofire reports: audits of `rain.factory`, performed before the
split, of the source that built the snapshots pinned here. They are prefixed
`inherited.` and their provenance and per-snapshot coverage are recorded in
[`audit/protofire/inherited.json`](audit/protofire/inherited.json) — read that
file, not this section, for what each report covers.

Every snapshot in `src/generated/` is covered by exactly one of them:
`src/generated/0_1_3/` and `src/generated/0_1_4/` (the `ICloneableFactoryV2`
bytecode) by r2.0, and `src/generated/0_1_5/` (the `ICloneableFactoryV3` rewrite
that `LibCloneFactoryDeploy` currently aliases and that is live on every
supported chain) by r3.0, which audited `rain.factory` at tag `sol-v0.1.5` with
zero findings at every severity. Coverage is never inferred from a filename: it
is asserted per snapshot directory in the manifest, so a future snapshot appears
as uncovered until a report is inherited for it.

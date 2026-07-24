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
Tagging runs `rainix-tag-release`, which deploys the `clone-factory` suite,
regenerates and verifies the snapshot against the live chain, publishes
`rain-factory-deploy` to Soldeer, and commits the frozen snapshot back to `main`.
Nothing publishes on merge, so `[package].version` and the generated `DEPLOY_TAG`
only ever move together.

See rainlanguage/rain.factory#46 for the split rationale.

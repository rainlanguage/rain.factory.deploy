# rain.factory.deploy

The **deployment** half of `rain.factory`: the concrete `CloneFactory` contract,
its deployed address + codehash pins (`LibCloneFactoryDeploy`), the rolling
`src/generated/candidate/` snapshot those pins alias, the frozen per-release
snapshots under `src/generated/<tag>/`, and the deploy script.

The **library** half — the `ICloneable*` interfaces and
`LibICloneableFactoryV4`, which carries the whole of the factory logic — lives
in [`rain.factory`](https://github.com/rainlanguage/rain.factory) and is
imported here as the `rain-factory` Soldeer package. The concrete `CloneFactory`
is one delegation per entry point into that library and adds no behaviour of its
own. Consumers that need only the interfaces or the library depend on
`rain-factory`; consumers that need the deployed address/codehash pins depend on
`rain-factory-deploy`.

## Releases

This is a deploy repo: releases are **manual `sol-v*` tags**, not merges.

The on-chain deploy is a separate, human-dispatched step, run **before**
tagging: the `Manual sol artifacts` workflow runs `script/Deploy.sol` for the
`clone-factory` suite. Tagging then runs `rainix-tag-release`, which never
broadcasts a deploy itself; its mechanics live in rainix.

Nothing publishes on merge: a release bumps `[external.package].version` and
freezes the current `src/generated/candidate/` snapshot into a new
`src/generated/<tag>/` in lockstep.

See rainlanguage/rain.factory#46 for the split rationale.

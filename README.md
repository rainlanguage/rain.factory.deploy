# rain.factory.deploy

The **deployment** half of `rain.factory`: the concrete `CloneFactory` contract,
its deployed address + codehash pins (`LibCloneFactoryDeploy`), the deploy-pin
snapshots under `src/generated/`, and the deploy script.

The **library** half — the `ICloneable*` interfaces — lives in
[`rain.factory`](https://github.com/rainlanguage/rain.factory) and is imported
here as the `rain-factory` Soldeer package. Consumers that need only the
interfaces depend on `rain-factory`; consumers that need the deployed
address/codehash pins depend on `rain-factory-deploy`.

## Snapshots

`src/generated/` holds two kinds of deploy-pin snapshot, both with the same file
shape (`BYTECODE_HASH`, `DEPLOYED_ADDRESS`, `CREATION_CODE`, `RUNTIME_CODE`):

- **`candidate/`** — the rolling snapshot of whatever the current source
  compiles to. Regenerated in full by `forge script ./script/BuildPointers.sol`,
  committed, and aliased by `LibCloneFactoryDeploy` — so the pins consumers
  import always describe the source in this repo. `testCandidateSelfConsistent`
  fails if the source changes without regenerating.
- **`0_1_3/`, `0_1_4/`, `0_1_5/`** — frozen release records. Never regenerated;
  CI enforces that they are append-only. Each is a copy of `candidate` taken at
  the instant a release tag froze it, kept so a consumer pinned to an older
  release can still reproduce and verify that deployment.

## Releases

This is a deploy repo: releases are **manual `sol-v*` tags**, not merges.

The on-chain deploy is a separate, human-dispatched step, run **before**
tagging: the `Manual sol artifacts` workflow runs `script/Deploy.sol` for the
`clone-factory` suite. Tagging then runs `rainix-tag-release`, which writes the
tag's version into `foundry.toml`, runs `script/cut-release.sh` to freeze
`src/generated/candidate/` as `src/generated/<tag>/`, verifies the live chains
match the pins, publishes `rain-factory-deploy` to Soldeer, and commits the
frozen snapshot back to `main`. It never broadcasts a deploy itself.

The pushed tag decides the version. `[package].version` in `foundry.toml` does
not name a snapshot dir and is not read by any Solidity in this repo — it is a
placeholder that the release workflow overwrites from the tag. **Nothing has
been released from this repo yet**: Soldeer has zero `rain-factory-deploy`
revisions. (`sol-v0.1.6` exists as a tag but its release run failed before
publishing anything.)

See rainlanguage/rain.factory#46 for the split rationale.

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
tag's version into `foundry.toml`, runs `script/cut-release.sh` to regenerate
`src/generated/candidate/` and freeze it as `src/generated/<tag>/`, verifies the
live chains match the pins, publishes `rain-factory-deploy` to Soldeer, and
commits the frozen snapshot back to `main`. It never broadcasts a deploy itself.

The pushed tag decides the version. `[package].version` in `foundry.toml` does
not name a snapshot dir and is not read by any Solidity in this repo — it is a
placeholder that the release workflow overwrites from the tag. **Nothing has
been released from this repo yet**: Soldeer has zero `rain-factory-deploy`
revisions.

### The `sol-v0.1.6` tag, and why it published nothing

`sol-v0.1.6` exists as a tag on `685bb2ba`. Its `rainix-tag-release` run
([30097157490](https://github.com/rainlanguage/rain.factory.deploy/actions/runs/30097157490))
got as far as *Verify live chain matches the fresh pins* and died there — all
five fork tests failed with `vm.createSelectFork: environment variable
<NETWORK>_RPC_URL not found`. The reusable exported the fork endpoints under the
**secret** names (`RPC_URL_<NETWORK>_FORK`), while `[rpc_endpoints]` in
`foundry.toml` reads `${<NETWORK>_RPC_URL}`, so every endpoint resolved to an
empty string. Publish, commit-back and GitHub Release were all skipped, which is
why the tag exists with no revision, no release and no `0_1_6` snapshot behind
it.

That was a defect in `rainix-tag-release`, not in this repo, and it is fixed
upstream: `rainix` now runs an `rpc-preflight` step that binds each env name
foundry actually reads to an endpoint probed healthy at that moment. The next tag
does not hit this.

Two consequences for whoever cuts the first release:

- **`sol-v0.1.6` is spent.** It names a commit five behind `main` and it is not
  what should be released. Cut a fresh tag on the `main` tip instead of reusing
  it. `0.1.6` itself is still free on the registry — nothing was ever published
  under it.
- **The fork RPCs still gate the release.** The verify step is the repo's own
  fork suite, so a release only publishes if the pins resolve on every supported
  chain. Those endpoints are currently intermittent (a free-plan `lb.drpc.live`
  returning quota and 408 errors), which reds the same suite on ordinary PRs. Get
  them healthy before tagging: a transient failure here fails the release, and
  the fix is to tag again, not to retry the run.

See rainlanguage/rain.factory#46 for the split rationale.

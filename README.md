# rain.factory.deploy

The **deployment** half of `rain.factory`: the concrete `CloneFactory` contract,
its deployed address + codehash pins (`LibCloneFactoryDeploy`), the deploy-pin
snapshots under `src/generated/`, and the deploy script.

The **library** half — the `ICloneable*` interfaces — lives in
[`rain.factory`](https://github.com/rainlanguage/rain.factory) and is imported
here as the `rain-factory` Soldeer package. Consumers that need only the
interfaces depend on `rain-factory`; consumers that need the deployed
address/codehash pins depend on `rain-factory-deploy`.

## Entry points

`CloneFactory` implements `ICloneableFactoryV4`, letting any compatible
`ICloneableV2` contract be cloned as an EIP1167 proxy and initialized
atomically. It offers two deterministic (`CREATE2`) entry points that differ
only in how the salt is derived:

- `cloneDeterministic` namespaces the caller-supplied salt by `msg.sender`, so
  the address commits to WHO deployed: nobody else can reach the caller's
  address, but the deploying account is baked into it forever and `data` is
  outside the derivation.
- `cloneDeterministicOpenSalt` derives the salt as
  `keccak256(abi.encode(ICLONEABLE_FACTORY_V4_OPEN_SALT_DOMAIN, salt, keccak256(data)))`
  — the domain constant being
  `keccak256("ICloneableFactoryV4.cloneDeterministicOpenSalt")`, declared in
  `rain.factory` so third parties recompute the address rather than trust it —
  so the address commits to WHAT was deployed and to nothing about who deployed
  it: it is a function of `(factory, implementation, salt, data)` alone. Every
  account reaches the same address, and so can anyone. That also makes it the
  same address across chains, but only where both the factory and the
  implementation are themselves at the same address on each chain — `CREATE2`
  hashes the factory, and the EIP1167 creation code it hashes contains the
  implementation.

Because `data` is in the derivation, open-salt needs no per-implementation audit
of what a squatter could pass. A front-runner who passes different `data`
derives a different address and has deployed their own contract at their own
expense; one who passes the same `data` has deployed exactly the intended
contract with the intended bytes and has paid the gas for it. What is left is
that the address cannot fix what `initialize` reads that is not `data`, so an
implementation used this way MUST NOT read `tx.origin`. The full statement of
that condition and of the residual timing lever is the NatSpec on
`ICloneableFactoryV4.cloneDeterministicOpenSalt` (in `rain.factory`), not here.
The cost open-salt does carry is that the address is not knowable until `data`
is final, and a consumer pinning one must be able to reproduce those bytes
exactly, ABI encoding and all.

### The domain separator is load-bearing

`ICloneableFactoryV4` states the disjointness of the two derivations as a MUST
NOT on the **factory**: no other entry point may `CREATE2` in the open-salt
image with caller-supplied `data`. `cloneDeterministic` is exactly such an entry
point, so `CloneFactory` holds the rule structurally — a 96-byte preimage led by
the domain constant against a 64-byte preimage led by a left-padded address.

Without the domain word both preimages would be 64 bytes led by a word the
caller chooses, and since `abi.encode` left-pads an address into the same word a
`bytes32` salt already is, any account `A` would reach every open-salt address
whose `salt` equals `bytes32(uint256(uint160(A)))` by calling
`cloneDeterministic(implementation, evilData, keccak256(data))` — a choice of
salt, not a preimage search.
`testCloneDeterministicOpenSaltDisjointFromNamespacedAtLeftPaddedAddressSalt` is
the test that fails if that ever stops holding: it builds that exact squat,
asserts against the factory's own namespaced prediction that an untagged
derivation would land on it, and then shows the real one does not.

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
got as far as _Verify live chain matches the fresh pins_ and died there — all
five fork tests failed with
`vm.createSelectFork: environment variable
<NETWORK>_RPC_URL not found`. The
reusable exported the fork endpoints under the **secret** names
(`RPC_URL_<NETWORK>_FORK`), while `[rpc_endpoints]` in `foundry.toml` reads
`${<NETWORK>_RPC_URL}`, so every endpoint resolved to an empty string. Publish,
commit-back and GitHub Release were all skipped, which is why the tag exists
with no revision, no release and no `0_1_6` snapshot behind it.

That was a defect in `rainix-tag-release`, not in this repo, and it is fixed
upstream: `rainix` now runs an `rpc-preflight` step that binds each env name
foundry actually reads to an endpoint probed healthy at that moment. The next
tag does not hit this.

Two consequences for whoever cuts the first release:

- **`sol-v0.1.6` is spent.** It names a commit five behind `main` and it is not
  what should be released. Cut a fresh tag on the `main` tip instead of reusing
  it. `0.1.6` itself is still free on the registry — nothing was ever published
  under it.
- **The fork RPCs still gate the release.** The verify step is the repo's own
  fork suite, so a release only publishes if the pins resolve on every supported
  chain. Those endpoints are currently intermittent (a free-plan `lb.drpc.live`
  returning quota and 408 errors), which reds the same suite on ordinary PRs.
  Get them healthy before tagging: a transient failure here fails the release,
  and the fix is to tag again, not to retry the run.

See rainlanguage/rain.factory#46 for the split rationale.

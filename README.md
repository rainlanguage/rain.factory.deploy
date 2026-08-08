# rain.factory.deploy

Rain's Zoltu-deployed concrete contracts and their deploy pins. Two unrelated
contracts live here, sharing only that deploy model:

- **`CloneFactory`** — the **deployment** half of `rain.factory`: the concrete
  contract, its deployed address + codehash pins (`LibCloneFactoryDeploy`), the
  frozen per-tag deploy-pin snapshots under `src/generated/<tag>/`, and the
  deploy script. The **library** half — the `ICloneable*` interfaces — lives in
  [`rain.factory`](https://github.com/rainlanguage/rain.factory) and is imported
  here as the `rain-factory` Soldeer package. Consumers that need only the
  interfaces depend on `rain-factory`; consumers that need the deployed
  address/codehash pins depend on `rain-factory-deploy`.
- **`AddressRegistry`** — the implementation of `IAddressRegistryV1`, which is
  the same split: the interface, the library that reads a registered address,
  and the cross-network deploy gate all live in
  [`rain.deploy`](https://github.com/rainlanguage/rain.deploy) and arrive here
  as the `rain-deploy` Soldeer package.

## `AddressRegistry`

An immutable root authority binds a `bytes32` name to an address, once, forever;
anyone reads a bound name; reading an unbound name reverts. There is no
rotation, no removal, no upgrade and no admin surface, because a binding that
can move is not worth checking at deploy time.

Names are opaque. Nothing here says how one is derived, and nothing here should.

`ADDRESS_REGISTRY_ROOT` in `src/concrete/AddressRegistry.sol` is currently a
**placeholder**. The root is a constant in the creation code, so it is part of
the contract's identity: changing it changes the deterministic deploy address
and code hash on every network. A human must supply the real root before this
contract is deployed anywhere or given a deploy-pin snapshot, and
`rain-deploy`'s `LibAddressRegistry` pins must be re-derived from the resulting
creation code at the same time. `AddressRegistryDeployPinsTest` fails if those
two ever disagree.

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

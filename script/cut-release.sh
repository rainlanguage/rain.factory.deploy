#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-DCL-1.0
# SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
# Regenerate the rolling `candidate` snapshot, then freeze it as a numbered
# release snapshot.
#
# Invoked by rainix-tag-release as its `snapshot-generate-cmd`, AFTER the
# reusable has resolved the release version from the pushed `sol-vX.Y.Z` tag and
# written it to `foundry.toml` `[package].version`. So the version is read from
# `foundry.toml` here — the single source of truth at this point.
#
# Model: `src/generated/candidate/` is the rolling snapshot of what the current
# source compiles to (regenerated every BuildPointers run). A numbered snapshot
# (`0_1_5/`, …) is a FROZEN copy of `candidate` taken at the instant a tag
# releases it — it never changes again (the frozen-snapshots-append-only gate
# enforces this). This script regenerates `candidate` from the current source and
# then performs that copy.
set -euo pipefail

VERSION="$(grep -m1 -E '^version = ' foundry.toml | sed -E 's/^version = "([^"]+)"/\1/')"
if [ -z "$VERSION" ]; then
  echo "cut-release: could not read [package].version from foundry.toml" >&2
  exit 1
fi
# Strict X.Y.Z only: anything else (rc/pre-release suffixes, extra components)
# would freeze a dir like `0_1_7-rc1` that the append-only gate's numeric tag
# filter ignores forever — an orphan snapshot nothing protects. Refuse instead.
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "cut-release: version '${VERSION}' is not strict X.Y.Z — refusing to cut a snapshot the append-only gate would ignore" >&2
  exit 1
fi
TAG="${VERSION//./_}"

if [ ! -d src/generated/candidate ]; then
  echo "cut-release: src/generated/candidate is missing — nothing to freeze" >&2
  exit 1
fi

# Frozen releases are append-only: re-cutting an existing version must fail
# loudly rather than clobber a frozen snapshot with candidate.
if [ -d "src/generated/${TAG}" ]; then
  echo "cut-release: src/generated/${TAG} already exists — refusing to overwrite a frozen release snapshot" >&2
  exit 1
fi

# Regenerate FIRST, freeze SECOND. The numbered dir must record what this release
# actually publishes, and what it publishes is `candidate` — the pin lib aliases
# it — so the copy has to come from a `candidate` already known to match the
# current source.
#
# The other order is silently wrong whenever the committed `candidate` has
# drifted from the source: the copy freezes the stale bytes into a dir the
# append-only gate then protects forever, while this regeneration moves
# `candidate` on to the real ones. Nothing downstream catches it —
# `testCandidateSelfConsistent` checks the *regenerated* `candidate` against the
# source, and no test compares a numbered dir to `candidate` — so the release
# publishes one address and permanently records another.
#
# `forge fmt` also runs before the copy, so the frozen dir is byte-identical to
# `candidate` rather than to its pre-format form.
forge script ./script/BuildPointers.sol
forge fmt

echo "cut-release: freezing candidate -> src/generated/${TAG}"
cp -r src/generated/candidate "src/generated/${TAG}"

# The point of the ordering above, asserted rather than assumed: the frozen
# record and the published pin are the same bytes.
if ! diff -r src/generated/candidate "src/generated/${TAG}"; then
  echo "cut-release: src/generated/${TAG} does not match src/generated/candidate after the copy" >&2
  exit 1
fi

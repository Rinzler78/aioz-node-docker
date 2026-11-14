# 0005. Run the embedded aioz-io instead of the CLI start

Status: Accepted, 2026-11-11
([#8](https://github.com/Rinzler78/aioz-node-docker/pull/8))

## Context

The v1.2.6 CLI (`aioznode`) is a wrapper around two embedded binaries,
`aioz-io` (the node) and `aioz-ai` (AI computing), which it extracts under
`$HOME` only when they are missing. Its `start` fails: it calls `aioz-io keytool
encrypt --password`, a flag `aioz-io` does not have
([AIOZNetwork/aioz-depin-cli#10](https://github.com/AIOZNetwork/aioz-depin-cli/issues/10),
open). With the CLI start, the image cannot run a node at all.

## Decision

The scripts run `aioz-io` directly: the node (`aioz-io start`), its health
check and the rewards. The wrapper is still used to install, to extract
`aioz-io` and to create the wallet. `tools/node.io.sh` records the sha256 of
the CLI the extracted copy comes from, and extracts it again when the CLI
changes, since the wrapper would keep a stale copy.

## Consequences

* The node runs, but AI computing does not: `aioz-ai` is not started.
* The scripts depend on the measured interface of `aioz-io`, not on the
  documented one of the wrapper; the test doubles follow the measured one.
* This is a workaround: once the upstream bug is fixed, the scripts go back
  to the wrapper `start`, and this record is superseded.
  `.github/scripts/upstream-watch.sh` reports when the upstream issue changes
  state.

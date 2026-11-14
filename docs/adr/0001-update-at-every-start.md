# 0001. Update the node at every container start

Status: Accepted, 2026-11-08
([#1](https://github.com/Rinzler78/aioz-node-docker/pull/1))

## Context

The node must follow the upstream CLI releases
([AIOZNetwork/aioz-depin-cli](https://github.com/AIOZNetwork/aioz-depin-cli)).
In November 2026, containers were found still running the 2023 binary
(v1.1.0): upstream had renamed its repository and moved the downloads from the
release body to its assets, and the installer, which scraped the body, logged
`download failed` and still exited 0. An image release of this repository is
rare; an upstream CLI release is not.

## Decision

At every start, `tools/deploy.sh` upgrades the Alpine packages and installs
the CLI of the latest upstream release (`tools/node.install.sh`): one GitHub API
call, the `linux-amd64` asset, checked against the release `SHA256SUMS`. A
failed update keeps the installed binary and logs a `WARN`; with no binary at
all, the container fails. The node runs with upstream auto-update off and for
`RUN_TIMEOUT` seconds (24 hours): the restart that follows runs the update
again.

The base image follows `alpine:latest` and its packages are not pinned: a
pinned base would not stay pinned once the container upgrades itself.

## Consequences

* A node is at most a day behind an upstream release, without a new image.
* The image does not pin what it runs: two starts a day apart may run
  different CLI versions. `scripts/quick_test.sh` checks, on every release
  tag, that the installed version is the latest one.
* The container runs as root, to upgrade its packages. The linter findings
  this causes (unpinned base and packages, root user) are accepted with their
  reason next to the line or in `.trivyignore.yaml`.
* A broken upstream release reaches every node at its next start: the scripts
  must cope with the upstream CLI as it is (see
  [0005](0005-run-the-embedded-aioz-io.md)).

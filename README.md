# AIOZ DePIN node in Docker

[![Tests](https://github.com/Rinzler78/aioz-node-docker/actions/workflows/tests.yml/badge.svg)](https://github.com/Rinzler78/aioz-node-docker/actions/workflows/tests.yml)
[![pre-commit](https://github.com/Rinzler78/aioz-node-docker/actions/workflows/pre-commit.yml/badge.svg)](https://github.com/Rinzler78/aioz-node-docker/actions/workflows/pre-commit.yml)
[![Release](https://img.shields.io/github/v/release/Rinzler78/aioz-node-docker)](https://github.com/Rinzler78/aioz-node-docker/releases)
[![Docker Pulls](https://img.shields.io/docker/pulls/rinzlerfr/aioznode)](https://hub.docker.com/r/rinzlerfr/aioznode)
[![Docker Image Size](https://img.shields.io/docker/image-size/rinzlerfr/aioznode)](https://hub.docker.com/r/rinzlerfr/aioznode)
[![License](https://img.shields.io/github/license/Rinzler78/aioz-node-docker)](LICENSE)

A Docker image that runs an [AIOZ DePIN](https://aioz.network/aioz-node) node
unattended: it installs the latest upstream CLI at every start, proves with its
health check that the node works, restarts it when it does not, and withdraws
the rewards to a wallet of your choice. It runs on any Docker host, local or
remote, with its data in a named volume or a host folder.

The repository is also a worked example of how a small infrastructure project
can be built: every rule it follows is written down, and most of them are
checked by a test.

## Highlights

* **Self-updating, safely.** Each start looks up the latest upstream release,
  checks the archive against its `SHA256SUMS` and keeps the installed CLI when
  the update fails ([ADR 0001](docs/adr/0001-update-at-every-start.md)).
* **A health check that proves the function.** The node must answer and the
  wallet must read its rewards; a watchdog stops the node after repeated
  failures so that the container restarts
  ([ADR 0002](docs/adr/0002-functional-health-check-and-watchdog.md)).
* **One image, two modes.** The same image runs the node or the reward
  withdrawal, the latter with the node data mounted read-only
  ([ADR 0003](docs/adr/0003-one-image-two-modes.md)).
* **Upstream bugs handled, not hidden.** The CLI `start` of v1.2.6 is broken
  upstream: the node runs the embedded `aioz-io`, and a daily workflow reports
  what changes upstream
  ([ADR 0005](docs/adr/0005-run-the-embedded-aioz-io.md),
  [upstream watch](docs/ci.md#upstream-watch)).
* **Tested shell.** bats suites run in Docker, against fakes asserted on the
  `PATH` and real captures of the GitHub API and the CLI output. Fitness tests
  turn repository rules into tests: script structure, the architecture map,
  the decision records, the changelog, the links of this page.
* **Hardened delivery.** Workflows are read-only by default, their actions are
  pinned to a commit and checked by zizmor; trivy scans the configuration and
  the image; outdated hooks and actions block the commit; `latest` only moves to
  the highest release ([CI and release](docs/ci.md)).
* **Operated, not only built.** A host script tells when the node stops
  earning delivery rewards, then when it earns them again; it runs as a
  scheduled task of the host, a Synology NAS in the example
  ([delivery watch](docs/nas.md#delivery-watch)).
* **AI harness, model and tool agnostic.** One file, [AGENTS.md](AGENTS.md),
  holds the instructions of every coding agent; tests keep the tool-specific
  files from drifting ([AI harness](docs/ai-harness.md)).

## Quick start

The commands below run against any Docker context: the local engine, or a
remote host chosen with `docker context use` or `DOCKER_HOST=ssh://user@host`.
The node data, the wallet key `privkey.json` and the node state, lives in a
named volume, so no folder of the host has to be known.

```sh
docker volume create aioznode-data
docker run -d --name aioznode --restart=always -p 1317:1317 \
  -v aioznode-data:/nodedata rinzlerfr/aioznode
```

At its first start the node creates a new wallet, once it has installed the
CLI: its log then reads `Wallet successfully configured`. Back the key up at
that point, since the volume holds its only copy:

```sh
docker cp aioznode:/nodedata/privkey.json privkey.json
chmod 600 privkey.json
```

`docker cp` writes the key on the machine that runs the command, which is not
the Docker host on a remote context: move it to a safe place, out of any clone.
To run an existing wallet instead, copy its key into the volume before the
first start:

```sh
docker create --name aioznode --restart=always -p 1317:1317 \
  -v aioznode-data:/nodedata rinzlerfr/aioznode
docker cp privkey.json aioznode:/nodedata/privkey.json
docker start aioznode
```

A host folder works too, `-v /path/on/the/host:/nodedata`: the path is one of
the Docker host, not of the machine that runs the command.

The node and the automatic reward withdrawal together, from a clone of this
repository, with `docker-compose.yml`:

```sh
WITHDRAW_ADDRESS_HEX=0xYourAddress docker compose up -d
```

The node data is then the same volume, `aioznode-data`: run the node either
with `docker run` or with compose, not both. With `WITHDRAW_ADDRESS_HEX` set,
`docker compose create`, then
`docker compose cp privkey.json aioznode:/nodedata/privkey.json`, then
`docker compose up -d` imports an existing key;
`docker compose cp aioznode:/nodedata/privkey.json privkey.json` backs it up.
`docker compose down -v` deletes the volume when compose created it, and the
key with it.

`NODEDATA_PATH` replaces the volume with a host folder: give an absolute path
of the Docker host, since compose expands `~` on the machine that runs the
command. A deployment of this compose file from before the volume, whose wallet
is in the `./nodedata` folder of the clone, sets `NODEDATA_PATH=./nodedata`:
without it, the node starts a new wallet in the volume.

To build the image yourself: `docker build -t aioznode .` in the clone; `make`
lists the repository commands (build, run, tests, lint).

## Configuration

* `WITHDRAW_ADDRESS_HEX` (required in withdraw mode): the `0x` address that
  receives the rewards.
* `WITHDRAW_MIN_VALUE` (`10^18`, 1 AIOZ): the balance, in attoaioz, above which
  the rewards are withdrawn.
* `CHECK_FREQ` (`60`): seconds between two withdraw checks.
* `RUN_TIMEOUT` (`86400`): seconds before the node stops, so that the container
  restarts and updates.
* `HEALTH_INTERVAL`, `HEALTH_TIMEOUT`, `HEALTH_RETRIES` (`60`, `30`, `3`): the
  watchdog timings.
* `GITHUB_TOKEN` (unset): authenticates the release lookup.

Every setting, the volume and the port:
[environment variables](docs/image.md#environment-variables).

## Documentation

* [The image](docs/image.md): the Dockerfile, the scripts, the settings, the
  build and the tests.
* [Synology NAS](docs/nas.md): a deployment example, and the delivery watch.
* [CI and release](docs/ci.md): the pre-commit hooks, the release of the
  public image, the upstream watch.
* [Architecture](docs/architecture.md): how the containers, the delivery watch
  and the release pipeline fit together.
* [Decision records](docs/adr/README.md): why they are built that way.
* [AI harness](docs/ai-harness.md): how coding agents work on this
  repository.
* [CHANGELOG.md](CHANGELOG.md): the changes of each release.

## Contributing

Issues and pull requests are welcome: [CONTRIBUTING.md](CONTRIBUTING.md)
describes the set up, the steps of a change, the review and the release.
Report a vulnerability privately, as described in [SECURITY.md](SECURITY.md),
never in a public issue.

## Support

If you find this project useful, please consider donating:

* AIOZ: `0x4D11B64d9bb0652a92FCaD019d7Fc79f14821571`
* AIOZ (bech32): `aioz1f5gmvnvmkpjj4yhu45qe6l78nu2gy9t3mklmct`

## License

[MIT](LICENSE)

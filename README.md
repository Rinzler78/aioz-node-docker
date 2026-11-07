# Purpose

[![Docker Build](https://img.shields.io/badge/build-docker-blue?logo=docker)](https://www.docker.com/)
[![Docker Pulls](https://img.shields.io/docker/pulls/rinzlerfr/aioznode)](https://hub.docker.com/r/rinzlerfr/aioznode)
[![Docker Image Size](https://img.shields.io/docker/image-size/rinzlerfr/aioznode)](https://hub.docker.com/r/rinzlerfr/aioznode)
[![License](https://img.shields.io/github/license/Rinzler78/aioz-node-docker)](./LICENSE)
[![Stars](https://img.shields.io/github/stars/Rinzler78/aioz-node-docker?style=social)](https://github.com/Rinzler78/aioz-node-docker/stargazers)
[![Issues](https://img.shields.io/github/issues/Rinzler78/aioz-node-docker)](https://github.com/Rinzler78/aioz-node-docker/issues)
[![Open PRs](https://img.shields.io/github/issues-pr/Rinzler78/aioz-node-docker)](https://github.com/Rinzler78/aioz-node-docker/pulls)
[![Last Commit](https://img.shields.io/github/last-commit/Rinzler78/aioz-node-docker/develop)](https://github.com/Rinzler78/aioz-node-docker/commits/develop)
[![GitHub Actions CI](https://github.com/Rinzler78/aioz-node-docker/actions/workflows/docker-image.yml/badge.svg?branch=develop)](https://github.com/Rinzler78/aioz-node-docker/actions/workflows/docker-image.yml)
[![Release](https://img.shields.io/github/v/release/Rinzler78/aioz-node-docker)](https://github.com/Rinzler78/aioz-node-docker/releases)
[![Shell](https://img.shields.io/badge/shell-bash-blue?logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-alpine-informational?logo=alpinelinux)](https://alpinelinux.org/)
[![Contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/Rinzler78/aioz-node-docker/issues)
[![Made with Love](https://img.shields.io/badge/made%20with-%E2%9D%A4-red)](https://github.com/Rinzler78/aioz-node-docker)

This repository allows you to build a Docker image containing all necessary components to run an AIOZ node in a fully automated and reproducible way.

For more information about the AIOZ project, visit: <https://aioz.network/>

Official downloads and client installation: <https://aioz.network/aioz-node>

## Table of contents

* [Docker image creation](#docker-image-creation)
  * [Dockerfile](#dockerfile)
  * [Installed packages](#installed-packages)
  * [Build instructions](#build-instructions)
  * [Before running](#before-running)
  * [Run instructions](#run-instructions)
  * [Public Docker image](#public-docker-image)
* [Synology NAS Docker deployment](#synology-nas-docker-deployment)
  * [Install Docker](#install-docker)
  * [Search aioznode image](#search-aioznode-image)
  * [Create nodedata directory](#create-nodedata-directory)
  * [Configure image and start container](#configure-image-and-start-container)
* [Support](#support)

---

## Docker image creation

### Dockerfile

#### Base container

This container is based on `alpine:latest` for a lightweight and secure environment.

#### Installed packages

The following packages are installed (see `tools/deps.txt`):

* jq
* wget
* nano
* curl
* bash
* gcompat
* bc (withdraw mode)

#### Scripts and logic

All logic is handled by scripts in the `tools/` directory:

* `deploy.sh` — Main deployment script (updates, upgrades, installs node and wallet, cleans up)
* `node.install.sh` — Installs or updates the CLI from the `linux-amd64` asset of the latest [AIOZNetwork/aioz-depin-cli](https://github.com/AIOZNetwork/aioz-depin-cli) release (one GitHub API call), after checking the archive against the release `SHA256SUMS`. The update is skipped when the installed version is already the latest. If the update fails, the installed binary is kept and a `WARN` is logged; with no binary at all, the container exits with an error
* `wallet.configure.sh` — Configures the wallet (see script for details)
* `node.health.sh` — Health check of the watchdog: the node answers `reward balance` for the configured wallet
* `node.version.sh` / `node.remoteVersion.sh` — Installed and latest release versions (used by `quick_test.sh`)
* `version.lib.sh` — Version parsing, sourced by the scripts above (the CLI prints its version as JSON)
* `git.releases.latest.sh` — Latest release JSON from the GitHub API (`GITHUB_TOKEN` when set), sourced by the scripts above; standalone: `git.releases.latest.sh <owner/repo>`
* `start.sh` — Entrypoint script: runs deployment, starts the node, and stops it after 3 consecutive failed health checks (a check running past 30s fails) so that the restart policy restarts the container (and re-runs the update). Docker itself never restarts an unhealthy container
* `start-watching-reward.sh` — Withdraw mode entrypoint: every `CHECK_FREQ` seconds, runs `withdraw.reward.sh`, which withdraws the whole balance to `WITHDRAW_ADDRESS_HEX` once it exceeds `WITHDRAW_MIN_VALUE`

#### Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `GITHUB_TOKEN` | unset | Optional. Authenticates the release lookup (5000 instead of 60 calls per hour per IP) |
| `RUN_TIMEOUT` | `86400` | Seconds before the node is stopped, so the container restarts and updates |
| `HEALTH_START_PERIOD` / `HEALTH_INTERVAL` / `HEALTH_TIMEOUT` / `HEALTH_RETRIES` | `300` / `60` / `30` / `3` | Watchdog timings. The image `HEALTHCHECK` still runs the former check (`reward balance`, 1s interval); it will be aligned once the v1.2.6 CLI interface is confirmed, since its `start` is broken upstream ([aioz-depin-cli#10](https://github.com/AIOZNetwork/aioz-depin-cli/issues/10)) |
| `ENDPOINT` | `http://127.0.0.1:1317` (node mode), `http://aioznode:1317` (withdraw mode) | Node queried by `node.health.sh` and the withdraw mode |
| `WITHDRAW_ADDRESS_HEX` | **required** in withdraw mode | `0x` address (40 hex digits) that receives the whole balance at each withdraw. The withdraw mode refuses to start without a valid one |
| `WITHDRAW_MIN_VALUE` | `10^18` (1 AIOZ) | Balance, in attoaioz, above which the rewards are withdrawn |
| `CHECK_FREQ` | `60` | Seconds between two withdraw checks |
| `TOKEN_NAME` / `TOKEN_DENOM` / `TOKEN_DECIMALS` | `aioz` / `attoaioz` / `10^18` | Units shown in the withdraw mode logs |

#### Volumes

A persistent data directory is created at `/nodedata` and must be mounted to a directory on your Docker host.

#### Ports

* 1317 (default, can be mapped as needed)

#### Entrypoint

The container starts with `start.sh`, which ensures the node is up-to-date and launches it with the correct configuration.

The same image runs the withdraw mode when started with the command `start-watching-reward.sh` (see `docker-compose.yml`, which runs both, with the node health check aligned on the watchdog and the node data mounted read-only in the withdraw container). With a plain `docker run`, disable the image health check for this mode (`--no-healthcheck`): it targets a local node.

**Known limitation:** the withdraw mode queries the node with `reward balance --endpoint` / `reward withdraw --endpoint`. The v1.2.6 CLI wrapper has no `--endpoint` (only `--priv-key-file`) and its `start` is broken upstream ([aioz-depin-cli#10](https://github.com/AIOZNetwork/aioz-depin-cli/issues/10)), so this mode cannot work until the upstream CLI is fixed; the scripts are kept as they ran with the previous CLI.

---

### Build instructions

```sh
docker build -t aioznode .
```

### Tests

```sh
tests/run.sh      # bats unit tests, in an Alpine container, against a fake GitHub
./quick_test.sh   # builds the image, waits for healthy, checks the installed version is the latest release
```

---

### Before running

#### nodedata directory

Create a directory on your Docker host to be mounted as the node's data directory. Example:

```sh
mkdir -p ~/MyDockers/aioznode/nodedata
```

#### Private key configuration

Place your `privkey.json` file in the data directory you will mount (see below). This is required for the node to start.

---

### Run instructions

Example run command:

```sh
docker run -d \
  -v ~/MyDockers/aioznode/nodedata:/nodedata \
  --restart=always \
  --name aioznode \
  -it aioznode
```

Where:
* `~/MyDockers/aioznode/nodedata` is your persistent data directory on the host
* `/nodedata` is the internal container path

The node will automatically check for updates and start with the provided private key.

To run the node and the automatic reward withdrawal together:

```sh
WITHDRAW_ADDRESS_HEX=0xYourAddress NODEDATA_PATH=~/MyDockers/aioznode/nodedata docker compose up -d
```

---

### Public Docker image

A public image may be available in the future. For now, build locally as described above.

---

## Synology NAS Docker deployment

### Install Docker

If not already installed, go to the Package Center, search for Docker, and install it.

### Search aioznode image

In the Docker GUI, search for your built image or import it if needed.

### Create nodedata directory

Using File Station, create a directory on your NAS to be used as the node's data directory. Example: `docker/aioznode/nodedata`

### Configure image and start container

1. In Docker GUI, go to Images, select your `aioznode` image, and click Launch.
2. Name your container (e.g., `aioznode`).
3. (Optional) Enable resource limits: set CPU priority to high, memory limit to 1024 MB.
4. Go to Advanced Settings and enable auto-restart.
5. In Volumes, add the directory you created (e.g., `docker/aioznode/nodedata`) and mount it to `/nodedata` inside the container.
6. Validate and launch the container.

---

## Support

If you find this project useful, please consider donating:

* AIOZ: `0x4D11B64d9bb0652a92FCaD019d7Fc79f14821571`
* AIOZ (bech32): `aioz1f5gmvnvmkpjj4yhu45qe6l78nu2gy9t3mklmct`

---

## Contribution

Feel free to open issues or submit pull requests for improvements or bug fixes.

---

Have fun! ;)

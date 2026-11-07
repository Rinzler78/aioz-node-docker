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
* [Upstream watch](#upstream-watch)
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

#### Scripts and logic

All logic is handled by scripts in the `tools/` directory:

* `deploy.sh` — Main deployment script (updates, upgrades, installs node and wallet, cleans up)
* `node.install.sh` — Downloads and installs the latest aioznode binary
* `wallet.configure.sh` — Configures the wallet (see script for details)
* `start.sh` — Entrypoint script: runs deployment, then starts the node with the correct parameters

#### Volumes

A persistent data directory is created at `/nodedata` and must be mounted to a directory on your Docker host.

#### Ports

* 1317 (default, can be mapped as needed)

#### Entrypoint

The container starts with `start.sh`, which ensures the node is up-to-date and launches it with the correct configuration.

---

### Build instructions

```sh
docker build -t aioznode .
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

## Upstream watch

The AIOZ DePIN hub is down (Cloudflare 521) and the CLI v1.2.6 `start` is broken upstream ([AIOZNetwork/aioz-depin-cli#10](https://github.com/AIOZNetwork/aioz-depin-cli/issues/10)). The workflow `.github/workflows/upstream-watch.yml` runs `.github/scripts/upstream-watch.sh` every day at 08:00 UTC (and on demand from the Actions tab) to tell when the node can be tried again.

What counts as a change:

* a hub URL no longer returns Cloudflare 52x (origin down) nor 000 (no answer), while the control URL `https://wallet.aioz.network/` answers 2xx-4xx; when the control URL does not answer, the hub result is ignored;
* the latest upstream release is not `KNOWN_TAG` (`v1.2.6`);
* the upstream issue #10 is no longer open, or got comments in the last 25 hours;
* upstream commits in the last 25 hours.

On change, the script comments on the open issue titled **AIOZ upstream watch** of this repository (and creates it if missing). Mentions in quoted comments are neutralised so their authors are not notified. Nothing is posted when nothing changed.

A GitHub API error (rate limit, bad token, outage) fails the run (red in Actions) and posts nothing, so a broken watch never looks like an upstream change.

Maintenance:

* after moving to a new upstream release, update `KNOWN_TAG` in the script;
* GitHub disables scheduled workflows of a public repository after 60 days without activity: re-enable it from the Actions tab (**AIOZ upstream watch** > **Enable workflow**);
* run locally with `DRY_RUN=1 .github/scripts/upstream-watch.sh` (needs `gh` logged in); tests: `.github/scripts/tests/run.sh` (Docker).

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

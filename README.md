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

This repository allows you to build a Docker image containing all necessary
components to run an AIOZ node in a fully automated and reproducible way.

For more information about the AIOZ project, visit: <https://aioz.network/>

Official downloads and client installation: <https://aioz.network/aioz-node>

## Documentation

* [The image](docs/image.md): the Dockerfile, the scripts, the settings, the
  build and the tests.
* [Synology NAS](docs/nas.md): deployment, and the delivery watch.
* [CI and release](docs/ci.md): the pre-commit hooks, the release of the
  public image, the upstream watch.
* [Architecture](docs/architecture.md): how the containers, the NAS watch and
  the release pipeline fit together.
* [Decision records](docs/adr/README.md): why they are built that way.
* [AI harness](docs/ai-harness.md): how coding agents work on this
  repository.

## Table of contents

* [Documentation](#documentation)
* [Run](#run)
  * [Before running](#before-running)
  * [Run instructions](#run-instructions)
* [Support](#support)
* [Contribution](#contribution)
  * [Security](#security)
  * [AI harness](#ai-harness)

---

## Run

### Before running

#### nodedata directory

Create a directory on your Docker host to be mounted as the node's data
directory. Example:

```sh
mkdir -p ~/MyDockers/aioznode/nodedata
```

#### Private key configuration

Place your `privkey.json` file in the data directory you will mount (see below).
Without one, the node creates a new wallet there at its first start: keep a
backup of it.

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

The node will automatically check for updates and start with the provided
private key.

To run the node and the automatic reward withdrawal together:

```sh
WITHDRAW_ADDRESS_HEX=0xYourAddress \
  NODEDATA_PATH=~/MyDockers/aioznode/nodedata \
  docker compose up -d
```

---

## Support

If you find this project useful, please consider donating:

* AIOZ: `0x4D11B64d9bb0652a92FCaD019d7Fc79f14821571`
* AIOZ (bech32): `aioz1f5gmvnvmkpjj4yhu45qe6l78nu2gy9t3mklmct`

---

## Contribution

Feel free to open issues or submit pull requests for improvements or bug fixes.
[CONTRIBUTING.md](CONTRIBUTING.md) describes the set up, the steps of a change,
the review and the release; [CHANGELOG.md](CHANGELOG.md) lists the changes of
each release.

### Security

Report a vulnerability privately, as described in [SECURITY.md](SECURITY.md),
never in a public issue.

### AI harness

The repository is developed with coding agents, model and tool agnostic.
[AGENTS.md](AGENTS.md) is the single source of their instructions (commands,
conventions, safety rules, definition of done); `CLAUDE.md` and
`.gemini/settings.json` only point to it, and `tests/harness.bats` fails if
they drift. The method, the checks and the review loop are described in
[docs/ai-harness.md](docs/ai-harness.md).

---

Have fun! ;)

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

## Table of contents

* [Docker image creation](#docker-image-creation)
  * [Dockerfile](#dockerfile)
    * [Installed packages](#installed-packages)
    * [Node binary](#node-binary)
  * [Build instructions](#build-instructions)
  * [Tests](#tests)
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
* [Contribution](#contribution)
  * [Pre-commit hooks](#pre-commit-hooks)

---

## Docker image creation

### Dockerfile

#### Base container

This container is based on `alpine:latest` for a lightweight and secure
environment. The base and the packages are not pinned on purpose: at every start
the container upgrades its packages and installs the latest AIOZ CLI (see
`tools/deploy.sh`), so the container runs as root.

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

All logic is handled by scripts in the `tools/` directory. A script that needs
another one **sources** it and calls its function, so a container start runs as
one shell process (plus the CLI and system tools); every script still runs
standalone. `tests/scripts.bats` enforces it: the only script run as its own
process is `node.health.sh`, because the watchdog bounds it with `timeout`.

Every script of the repository (`tools/*.sh`, `helper.docker.*.sh`, which share
`helper.docker.lib.sh`, `quick_test.sh`, `.github/scripts/*.sh` and the test
runners `tests/run.sh` and `.github/scripts/tests/run.sh`) has its functions
first, then an entry point guarded by `[[ "${BASH_SOURCE[0]}" == "$0" ]]`.
`tests/scripts.bats` checks every `*.sh` file of the repository for the guard,
and that sourcing it prints and runs nothing. The extension-less test doubles in
`.github/scripts/tests/fakes` stand in for external commands (`gh`, `curl`,
`git`, `pre-commit`, `docker`):
they are only run through the `PATH`, so the rule does not apply to them.

* `deploy.sh` — `deploy`: updates the system packages, installs or updates the
  CLI and its `aioz-io`, configures the wallet, cleans the packages
* `dist.sh` — `dist_update` / `dist_clean` (Alpine packages); standalone:
  `dist.sh update|clean`
* `node.install.sh` — `node_install`: installs or updates the CLI from the
  `linux-amd64` asset of the latest
  [AIOZNetwork/aioz-depin-cli](https://github.com/AIOZNetwork/aioz-depin-cli)
  release (one GitHub API call), after checking the archive against the release
  `SHA256SUMS`. The update is skipped when the installed version is already the
  latest. If the update fails, the installed binary is kept and a `WARN` is
  logged; with no binary at all, the container exits with an error
* `node.io.sh` — `node_io_sync`: makes `aioz-io` the one of the installed
  CLI. The CLI (a wrapper) extracts this binary under `$HOME` when it runs,
  but only if it is missing: when the CLI changes (sha256), the stale copy is
  removed and extracted again; fails when the CLI extracts nothing (see
  [Node binary](#node-binary))
* `wallet.configure.sh` — `wallet_configure`: creates the wallet
  (`PRIV_KEY_FILE`) when it does not exist
* `node.health.sh` — Health check of the watchdog and of the image
  `HEALTHCHECK`: the node answers `aioz-io stats` and the wallet reads its
  rewards (`aioz-io reward balance`, which queries the network, so it does not
  prove the node alone). Each query is bounded by half of the check timeout:
  the watchdog passes its `HEALTH_TIMEOUT` (`node.health.sh <seconds>`), the
  image `HEALTHCHECK` passes none, so the default is its `--timeout` (30s).
  While the AIOZ network is unreachable the wallet check fails, so the
  watchdog restarts the container after `HEALTH_RETRIES` checks (and the update
  runs again):
  a node whose wallet cannot be used is reported, not hidden
* `node.version.sh` / `node.remoteVersion.sh` — Installed and latest release
  versions (used by `quick_test.sh`)
* `version.lib.sh` — Version parsing, sourced by the scripts above (the CLI
  prints its version as JSON)
* `number.lib.sh` — `require_whole_number <name> <value> [minimum]`: a whole
  number of at most 18 digits, without a leading zero, or an error naming the
  setting; sourced by `start.sh` and `node.health.sh`
* `git.releases.latest.sh` — Latest release JSON from the GitHub API
  (`GITHUB_TOKEN` when set), sourced by the scripts above; standalone:
  `git.releases.latest.sh <owner/repo>`
* `start.sh` — Entrypoint script: runs deployment, starts the node (`aioz-io
  start --no-auto-update`: updates run at each container start), and stops it
  after `HEALTH_RETRIES` consecutive failed health checks (a check running past
  `HEALTH_TIMEOUT` fails) so that the restart policy restarts the container
  (and re-runs the update). Docker itself never restarts an unhealthy
  container. It refuses, before deploying, a `RUN_TIMEOUT` or `HEALTH_*` that
  is not a whole number of at least 1 (`HEALTH_START_PERIOD`: 0), or has a
  leading zero: `30s` or `0` would fail every check or stop the node at once
* `start-watching-reward.sh` — Withdraw mode entrypoint: runs `deploy`, then
  every `CHECK_FREQ` seconds calls `withdraw_reward` (`withdraw.reward.sh`),
  which withdraws the whole balance to `WITHDRAW_ADDRESS_HEX` once it exceeds
  `WITHDRAW_MIN_VALUE`. `aioz-io` reads and withdraws the rewards of the
  wallet `PRIV_KEY_FILE` from the network: no node endpoint is involved

#### Environment variables

* `GITHUB_TOKEN` (default: unset) — Optional. Authenticates the release lookup
  (5000 instead of 60 calls per hour per IP)
* `RUN_TIMEOUT` (default: `86400`) — Seconds before the node is stopped, so the
  container restarts and updates; a whole number of at least 1
* `HEALTH_START_PERIOD` / `HEALTH_INTERVAL` / `HEALTH_TIMEOUT` /
  `HEALTH_RETRIES` (defaults: `300` / `60` / `30` / `3`) — Watchdog timings,
  whole numbers of at least 1 (`HEALTH_START_PERIOD`: 0), see `start.sh`.
  The image `HEALTHCHECK` keeps the defaults: setting these variables changes
  the watchdog only. To change the Docker check, override `healthcheck:` and
  pass its timeout: `["CMD", "node.health.sh", "<seconds>"]`
* `ENDPOINT` (default: `http://127.0.0.1:1317`) — Node queried by the `stats`
  half of `node.health.sh`
* `WITHDRAW_ADDRESS_HEX` (**required** in withdraw mode) — `0x` address (40 hex
  digits) that receives the whole balance at each withdraw. The withdraw mode
  refuses to start without a valid one
* `WITHDRAW_MIN_VALUE` (default: `10^18`, 1 AIOZ) — Balance, in attoaioz, above
  which the rewards are withdrawn
* `CHECK_FREQ` (default: `60`) — Seconds between two withdraw checks
* `TOKEN_NAME` / `TOKEN_DENOM` / `TOKEN_DECIMALS` (defaults: `aioz` / `attoaioz`
  / `10^18`) — Units shown in the withdraw mode logs

#### Volumes

A persistent data directory is created at `/nodedata` and must be mounted to a
directory on your Docker host.

#### Ports

* 1317 (default, can be mapped as needed)

#### Entrypoint

The container starts with `start.sh`, which ensures the node is up-to-date and
launches it with the correct configuration.

The same image runs the withdraw mode when started with the command
`start-watching-reward.sh` (see `docker-compose.yml`, which runs both, with the
node data mounted read-only in the withdraw container). The withdraw mode needs
no running node: `aioz-io` reads and withdraws the rewards from the network
with the wallet key. On a first install the node creates the wallet; until
then the withdraw container, whose volume is read-only, fails and restarts.
With a plain `docker run`, disable the image health check for this mode
(`--no-healthcheck`): it targets a local node.

#### Node binary

The CLI of the release (`aioznode`, v1.2.6) is a wrapper around two embedded
binaries, `aioz-io` (the node) and `aioz-ai` (AI computing), which it extracts
to `$HOME/.cache/aioz-depin-cli/bin` (only when missing). Its `start` fails: it
calls `aioz-io keytool encrypt --password`, a flag `aioz-io` does not have
(upstream
[aioz-depin-cli#10](https://github.com/AIOZNetwork/aioz-depin-cli/issues/10)).
The scripts therefore run `aioz-io` directly, for the node, its health check
and the rewards; the wrapper is still used to install, extract and create the
wallet. **AI computing does not run** (`aioz-ai` is not started): the scripts
go back to the wrapper `start` once the upstream bug is fixed. `aioz-io reward
balance` prints its JSON on one line, but may print a log line on stdout before
it (measured, exit code 0): the withdraw mode reads the last line that is JSON
with a balance.

---

### Build instructions

```sh
docker build -t aioznode .
```

### Tests

```sh
tests/run.sh      # bats tests in an Alpine container against a fake GitHub
./quick_test.sh   # builds the image, waits for healthy,
                  # checks the installed version is the latest release
```

CI runs `tests/run.sh` (`.github/workflows/tests.yml`) on a pull request that
touches a `*.sh` file, `tools/`, `tests/`, the `Dockerfile` or the workflow
itself, and after every merge into `develop` or `master`. `quick_test.sh` needs
the AIOZ network and runs only on release tags (see Public Docker image).

---

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

The node will automatically check for updates and start with the provided
private key.

To run the node and the automatic reward withdrawal together:

```sh
WITHDRAW_ADDRESS_HEX=0xYourAddress \
  NODEDATA_PATH=~/MyDockers/aioznode/nodedata \
  docker compose up -d
```

---

### Public Docker image

`rinzlerfr/aioznode` is public on Docker Hub. Pushing a `v*` tag runs
`.github/workflows/docker-image.yml`: it builds the image, runs `tests/run.sh`
and `quick_test.sh`, pushes `rinzlerfr/aioznode:<tag>`, then creates the GitHub
release. `.github/scripts/push-latest.sh` moves `:latest` to the tag only when
it is the highest `vX.Y.Z` tag of the repository (compared as numbers, read with
`git ls-remote` at push time): a hotfix pushed on an older line or a `v2-beta`
tag leaves `:latest`, and so Watchtower, on the newest release (tests:
`.github/scripts/tests/run.sh`, Docker). Only the release job gets a write
token: the build and the tests, which run the AIOZ binary, keep a read-only
one. A tag is released once: if its GitHub release already exists, the release
job fails.

---

## Synology NAS Docker deployment

### Install Docker

If not already installed, go to the Package Center, search for Docker, and
install it.

### Search aioznode image

In the Docker GUI, search for your built image or import it if needed.

### Create nodedata directory

Using File Station, create a directory on your NAS to be used as the node's data
directory. Example: `docker/aioznode/nodedata`

### Configure image and start container

1. In Docker GUI, go to Images, select your `aioznode` image, and click Launch.
2. Name your container (e.g., `aioznode`).
3. (Optional) Enable resource limits: set CPU priority to high, memory limit to
   1024 MB.
4. Go to Advanced Settings and enable auto-restart.
5. In Volumes, add the directory you created (e.g., `docker/aioznode/nodedata`)
   and mount it to `/nodedata` inside the container.
6. Validate and launch the container.

---

## Upstream watch

The AIOZ DePIN hub is down (Cloudflare 521) and the CLI v1.2.6 `start` is broken
upstream
([AIOZNetwork/aioz-depin-cli#10](https://github.com/AIOZNetwork/aioz-depin-cli/issues/10)).
The workflow `.github/workflows/upstream-watch.yml` runs
`.github/scripts/upstream-watch.sh` every day at 08:00 UTC (and on demand from
the Actions tab) to tell when the node can be tried again.

What counts as a change:

* a hub URL no longer returns Cloudflare 52x (origin down) nor 000 (no answer),
  while the control URL `https://wallet.aioz.network/` answers 2xx-4xx; when the
  control URL does not answer, the hub result is ignored;
* the latest upstream release is not `KNOWN_TAG` (`v1.2.6`);
* the upstream issue #10 is no longer open, or got comments in the last 25
  hours;
* upstream commits in the last 25 hours.

On change, the script comments on the open issue titled **AIOZ upstream watch**
of this repository (and creates it if missing). Mentions in quoted comments are
neutralized so their authors are not notified. Nothing is posted when nothing
changed.

A GitHub API error (rate limit, bad token, outage) fails the run (red in
Actions) and posts nothing, so a broken watch never looks like an upstream
change.

Maintenance:

* after moving to a new upstream release, update `KNOWN_TAG` in the script;
* GitHub disables scheduled workflows of a public repository after 60 days
  without activity: re-enable it from the Actions tab (**AIOZ upstream watch** >
  **Enable workflow**);
* run locally with `DRY_RUN=1 .github/scripts/upstream-watch.sh` (needs `gh`
  logged in); tests: `.github/scripts/tests/run.sh` (Docker).

---

## Support

If you find this project useful, please consider donating:

* AIOZ: `0x4D11B64d9bb0652a92FCaD019d7Fc79f14821571`
* AIOZ (bech32): `aioz1f5gmvnvmkpjj4yhu45qe6l78nu2gy9t3mklmct`

---

## Contribution

Feel free to open issues or submit pull requests for improvements or bug fixes.

### Pre-commit hooks

```sh
pre-commit install          # once per clone
pre-commit run --all-files  # full pass
```

Each hook checks the changed files only (shellcheck still follows the scripts
they source, see `.shellcheckrc`):

* Linters and format — shellcheck, shfmt (style in `.editorconfig`), hadolint,
  yamllint (`.yamllint.yaml`), actionlint, markdownlint: shell scripts, bats
  tests, Dockerfiles, YAML, workflows, Markdown
* Workflow security — zizmor: GitHub workflows. Actions are pinned to a commit
  SHA, with their version in a comment on the line above; every permission is
  commented; only the release job (`contents`) and the upstream watch job
  (`issues`) may write
* Dependencies up to date (blocking) — `.github/scripts/deps-freshness.sh`, run
  only when `.pre-commit-config.yaml`, a workflow or the script changes. It
  fails when `pre-commit autoupdate` (run on a copy, the config is never
  rewritten) would update a hook. In the workflows (`*.yml`, `*.yaml`), every
  `uses:` but local (`./`) and Docker (`docker://`) actions must be pinned to a
  commit SHA, with `# <action> vX.Y.Z` on the line above (a `uses` key in
  another form, such as a flow mapping, fails); it fails when the SHA
  is not the commit of that version, or that version is not the highest
  `vX.Y.Z` tag of the action's repository. Fix: `pre-commit autoupdate`, or pin
  the new release's SHA and comment. Needs the network (`git ls-remote`, no
  token); tests: `.github/scripts/tests/run.sh` (Docker)
* Spelling (English) — cspell, words in `cspell.json`: every text file
* Misconfigurations — trivy config: Dockerfiles, run only when `Dockerfile`,
  `tests/Dockerfile` or `.trivyignore.yaml` changes
* Vulnerabilities — `.github/scripts/image-vuln-scan.sh` builds the image and
  fails on HIGH or CRITICAL vulnerabilities (trivy image), run only when
  `Dockerfile`, `tools/` or the scan script changes. The image is kept as
  `aioznode:vuln-scan`, so the next build reuses its layers. The AIOZ CLI
  binaries (`/bin/aioznode`, `/root/.cache/aioz-depin-cli/`) are skipped: they
  come from upstream, are replaced at every start, and cannot be fixed here
* Hygiene — pre-commit-hooks (whitespace, end of file, YAML/JSON syntax, large
  files, file modes, private keys): any file type. The JSON files are test
  fixtures captured from the GitHub API and from `aioz-io reward balance`
  (balances of a node wallet, no address or key), so a syntax check is their
  linter

Trivy and hadolint must be installed on the machine, with Docker for the image
scan; the other tools are installed by pre-commit:

```sh
brew install trivy hadolint
```

The same hooks run in CI (`.github/workflows/pre-commit.yml`): on a pull
request, on the files it changes (`--from-ref` its base); after a merge into
`develop` or `master`, on every file. CI installs the latest trivy
(`aquasecurity/setup-trivy`) and hadolint (release binary, checked against its
`checksums.sha256`), like the rolling `alpine:latest` base.

Accepted findings are kept with their reason, next to the line they concern
when the format allows comments:

* in the Dockerfiles, `# hadolint ignore=… #trivy:ignore:…` above the
  instruction (hadolint and trivy both read only the comment right above an
  instruction);
* in `.trivyignore.yaml`, the findings about a whole file (root user);
* in `.github/workflows/pre-commit.yml`, `# zizmor: ignore[unpinned-tools]` on
  the trivy `version: latest` line: CI tools follow their latest release, like
  the image base;
* in `cspell.json`, the words of the GitHub API fixtures that are not English
  and cannot be changed: GitHub node IDs and AIOZ wallet addresses (two
  patterns), and the names and logins of upstream users (`ignoreWords`).

---

Have fun! ;)

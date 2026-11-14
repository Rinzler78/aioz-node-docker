# The image

How the node image is built, configured and tested. Running it: see the
[README](../README.md).

## Dockerfile

### Base container

This container is based on `alpine:latest` for a lightweight and secure
environment. The base and the packages are not pinned on purpose: at every start
the container upgrades its packages and installs the latest AIOZ CLI (see
`tools/deploy.sh`), so the container runs as root.

### Installed packages

The following packages are installed (see `tools/deps.txt`):

* jq
* wget
* nano
* curl
* bash
* gcompat
* bc (withdraw mode)

### Scripts and logic

All logic is handled by scripts in the `tools/` directory. A script that needs
another one **sources** it and calls its function, so a container start runs as
one shell process (plus the CLI and system tools); every script still runs
standalone. `tests/scripts.bats` enforces it: the only script run as its own
process is `tools/node.health.sh`, because the watchdog bounds it with
`timeout`.

Every script of the repository (`tools/*.sh`, `scripts/helper.docker.*.sh`,
which share `scripts/helper.docker.lib.sh`, `scripts/quick_test.sh`,
`.github/scripts/*.sh` and the test runners `tests/run.sh` and
`.github/scripts/tests/run.sh`) has its functions first, then an entry point
guarded by `[[ "${BASH_SOURCE[0]}" == "$0" ]]`. `tests/scripts.bats` checks
every `<name>.sh` file of the repository for the guard, and that sourcing it
prints and runs nothing. The extension-less test doubles in
`.github/scripts/tests/fakes` stand in for external commands (`gh`, `curl`,
`git`, `pre-commit`, `docker`): they are only run through the `PATH`, so the
rule does not apply to them.

* `tools/deploy.sh` — `deploy`: updates the system packages, installs or
  updates the CLI and its `aioz-io`, configures the wallet, cleans the packages
* `tools/dist.sh` — `dist_update` / `dist_clean` (Alpine packages); standalone:
  `tools/dist.sh update|clean`
* `tools/node.install.sh` — `node_install`: installs or updates the CLI from the
  `linux-amd64` asset of the latest
  [AIOZNetwork/aioz-depin-cli](https://github.com/AIOZNetwork/aioz-depin-cli)
  release (one GitHub API call), after checking the archive against the release
  `SHA256SUMS`. The update is skipped when the installed version is already the
  latest. If the update fails, the installed binary is kept and a `WARN` is
  logged; with no binary at all, the container exits with an error
* `tools/node.io.sh` — `node_io_sync`: makes `aioz-io` the one of the installed
  CLI. The CLI (a wrapper) extracts this binary under `$HOME` when it runs,
  but only if it is missing: when the CLI changes (sha256), the stale copy is
  removed and extracted again; fails when the CLI extracts nothing (see
  [Node binary](#node-binary))
* `tools/wallet.configure.sh` — `wallet_configure`: creates the wallet
  (`PRIV_KEY_FILE`) when it does not exist
* `tools/node.health.sh` — Health check of the watchdog and of the image
  `HEALTHCHECK`: the node answers `aioz-io stats` and the wallet reads its
  rewards (`aioz-io reward balance`, which queries the network, so it does not
  prove the node alone). Each query is bounded by half of the check timeout: the
  watchdog passes its `HEALTH_TIMEOUT` (`tools/node.health.sh <seconds>`), the
  image `HEALTHCHECK` passes none, so the default is its `--timeout` (30s).
  While the AIOZ network is unreachable the wallet check fails, so the watchdog
  restarts the container after `HEALTH_RETRIES` checks (and the update runs
  again): a node whose wallet cannot be used is reported, not hidden
* `tools/node.version.sh` / `tools/node.remoteVersion.sh` — Installed and
  latest release versions (used by `scripts/quick_test.sh`)
* `tools/version.lib.sh` — Version parsing, sourced by the scripts above (the
  CLI prints its version as JSON)
* `tools/number.lib.sh` — `require_whole_number <name> <value> [minimum]`: a
  whole number of at most 18 digits, without a leading zero, or an error naming
  the setting; sourced by `tools/start.sh` and `tools/node.health.sh`
* `tools/git.releases.latest.sh` — Latest release JSON from the GitHub API
  (`GITHUB_TOKEN` when set), sourced by the scripts above; standalone:
  `tools/git.releases.latest.sh <owner/repo>`
* `tools/start.sh` — Entrypoint script: runs deployment, starts the node
  (`aioz-io start --no-auto-update`: updates run at each container start), and
  stops it after `HEALTH_RETRIES` consecutive failed health checks (a check
  running past `HEALTH_TIMEOUT` fails) so that the restart policy restarts the
  container (and re-runs the update). Docker itself never restarts an unhealthy
  container. It refuses, before deploying, a `RUN_TIMEOUT` or `HEALTH_*` that is
  not a whole number of at least 1 (`HEALTH_START_PERIOD`: 0), or has a leading
  zero: `30s` or `0` would fail every check or stop the node at once
* `tools/start-watching-reward.sh` — Withdraw mode entrypoint: runs `deploy`,
  then every `CHECK_FREQ` seconds calls `withdraw_reward`
  (`tools/withdraw.reward.sh`), which withdraws the whole balance to
  `WITHDRAW_ADDRESS_HEX` once it exceeds `WITHDRAW_MIN_VALUE`. `aioz-io` reads
  and withdraws the rewards of the wallet `PRIV_KEY_FILE` from the network: no
  node endpoint is involved

### Environment variables

* `GITHUB_TOKEN` (default: unset) — Optional. Authenticates the release lookup
  (5000 instead of 60 calls per hour per IP)
* `RUN_TIMEOUT` (default: `86400`) — Seconds before the node is stopped, so the
  container restarts and updates; a whole number of at least 1
* `HEALTH_START_PERIOD` / `HEALTH_INTERVAL` / `HEALTH_TIMEOUT` /
  `HEALTH_RETRIES` (defaults: `300` / `60` / `30` / `3`) — Watchdog timings,
  whole numbers of at least 1 (`HEALTH_START_PERIOD`: 0), see `tools/start.sh`.
  The image `HEALTHCHECK` keeps the defaults: setting these variables changes
  the watchdog only. To change the Docker check, override `healthcheck:` and
  pass its timeout: `["CMD", "node.health.sh", "<seconds>"]`
* `ENDPOINT` (default: `http://127.0.0.1:1317`) — Node queried by the `stats`
  half of `tools/node.health.sh`
* `WITHDRAW_ADDRESS_HEX` (**required** in withdraw mode) — `0x` address (40 hex
  digits) that receives the whole balance at each withdraw. The withdraw mode
  refuses to start without a valid one
* `WITHDRAW_MIN_VALUE` (default: `10^18`, 1 AIOZ) — Balance, in attoaioz, above
  which the rewards are withdrawn
* `CHECK_FREQ` (default: `60`) — Seconds between two withdraw checks
* `TOKEN_NAME` / `TOKEN_DENOM` / `TOKEN_DECIMALS` (defaults: `aioz` / `attoaioz`
  / `10^18`) — Units shown in the withdraw mode logs

### Volumes

A persistent data directory is created at `/nodedata` and must be mounted to a
directory on your Docker host.

### Ports

* 1317 (default, can be mapped as needed)

### Entrypoint

The image copies the files of `tools/` into `/tools`, which is on its `PATH`,
so a command names a script without its folder. The default command,
`CMD ["start.sh"]`, runs `tools/start.sh`, which ensures the node is up-to-date
and launches it with the correct configuration.

The same image runs the withdraw mode when its command names
`tools/start-watching-reward.sh` instead (see `docker-compose.yml`, which runs
both, with the node data mounted read-only in the withdraw container). The
withdraw mode needs no running node: `aioz-io` reads and withdraws the rewards
from the network with the wallet key. On a first install the node creates the
wallet; until then the withdraw container, whose volume is read-only, fails and
restarts. With a plain `docker run`, disable the image health check for this
mode (`--no-healthcheck`): it targets a local node.

### Node binary

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

## Build instructions

```sh
docker build -t aioznode .
```

The `Makefile` is the entry point of the repository commands: `make` lists the
targets, each of which runs one script.

```sh
make                 # list the targets
make check           # tests, CI script tests and every pre-commit hook
make docker-start ARGS='-v ~/MyDockers/aioznode/nodedata:/nodedata'
```

The `scripts/helper.docker.*.sh` scripts (`make docker-build`, `docker-run`,
`docker-stop`, `docker-start`, `docker-clean`) build, run, stop and clean a
local container named after `scripts/helper.docker.name.txt` (`aioznode`),
from the repository root as build context. `docker-start` chains stop, clean,
build and run. The clean step removes the container and
image named `aioznode`, whatever started them, so do not run it on a host whose
node uses that name. It then removes the unused images of this project only:
every `Dockerfile` of the repository labels its image with
`org.opencontainers.image.source=https://github.com/Rinzler78/aioz-node-docker`,
and the prune filters on that label. The published
[rinzlerfr/aioznode](https://hub.docker.com/r/rinzlerfr/aioznode) images
built from this version on, and images built `FROM` them that keep the label,
count as images of this project; the other images of the Docker host are left
alone.

## Tests

```sh
tests/run.sh             # make test: bats tests in Alpine, fake GitHub
scripts/quick_test.sh    # make quick-test: builds the image, waits for
                         # healthy, checks the installed version is the latest
                         # release
```

CI runs `tests/run.sh` (`.github/workflows/tests.yml`) on every pull request
and after every merge into `develop` or `master`: its fitness tests read the
whole repository, so any renamed file can break them. `scripts/quick_test.sh`
needs the
AIOZ network and runs only on release tags (see
[Public Docker image](ci.md#public-docker-image)).

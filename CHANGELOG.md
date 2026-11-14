# Changelog

All notable changes to this project are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). Each release is a
`vX.Y.Z` tag on `master`, published as the Docker image
[rinzlerfr/aioznode](https://hub.docker.com/r/rinzlerfr/aioznode) under that
tag. The numbers in parentheses are the pull requests.

## [Unreleased]

### Added

* NAS delivery watch: `nas/delivery-watch.sh`, run daily by the DSM Task
  Scheduler, makes DSM send an email when the node deliveries stall and when
  they resume (#21).
* AI harness, model and tool agnostic: `AGENTS.md` is the single source of the
  agent instructions, checked by `tests/harness.bats` (#22).
* `Makefile`: one target per local script, `make check` for tests and lint
  (#24).
* Architecture page, `docs/architecture.md`, checked against the repository
  (#25).
* Architecture decision records, `docs/adr/` (#26).
* This changelog, a security policy and a contributing guide (#27).

### Changed

* The image script tests run on every pull request, whatever files it
  changes: the fitness tests read the whole repository (#22).

* The local build, run and clean scripts moved from the repository root to
  `scripts/` (#24).

### Fixed

* The upstream watch reports a change against its last report, not against
  the outage: a hub that keeps the same answer no longer raises an alert every
  day (#20).
* The Docker cleanup helpers prune only the images of this project, found by
  their label, no longer every unused image of the host (#23).

### Security

* The node private key and `.env` files are kept out of git and out of the
  Docker build context: new `.dockerignore`, completed `.gitignore` (#22).

## [0.0.3] - 2026-11-12

The image content is the same as in 0.0.2: only CI, tests and docs changed.

### Added

* Blocking dependency check: pre-commit hooks and GitHub Actions must be on
  their latest release, each Action pinned to the commit of that release
  (#12).
* The pre-commit hooks run in CI: on the files a pull request changes, and on
  every file after a merge (#13).
* The image script tests run on every pull request (#14).

### Changed

* Hardened workflows: zizmor checks, Actions pinned to a commit, one run per
  tag, `gh release create --verify-tag` (#11).
* `:latest` moves only to the highest `vX.Y.Z` release, so an older tag pushed
  later never takes it back (#15).
* markdownlint-cli2 v0.24.1 (#16).

### Fixed

* The release job gets its own write permission, so the workflow creates the
  GitHub release again (it failed on v0.0.2); the build job stays read-only
  (#10).

### Security

* The Docker Hub secrets are read from the `dockerhub` environment, which only
  `v*` tags can use (#17).

## [0.0.2] - 2026-11-11

### Added

* Docker health check, `quick_test.sh` options, and a GitHub release step in
  the image workflow (2025-06).
* bats tests of the image scripts, run in CI against a local GitHub serving a
  real release capture (#1).
* A watchdog stops the node after 3 failed health checks, so that the
  container restarts and updates the CLI (#1).
* Withdraw mode: the same image watches the rewards and withdraws them
  (`start-watching-reward.sh`), replacing the former
  `rinzlerfr/aioznode-auto-withdraw-reward` image; `docker-compose.yml` runs
  both containers (#2).
* Daily upstream watch: a workflow comments on an issue when the AIOZ hubs,
  the latest CLI release, the upstream bug or the upstream commits change (#3,
  #4).
* Pre-commit hooks: linters, spelling, workflow security, vulnerability scans
  of the configuration and of the built image (#7).
* Functional health check: the node answers and the wallet reads its rewards
  (#8).

### Changed

* The tool scripts are sourced instead of run as child processes; each one
  still runs on its own (#6).
* The node runs the `aioz-io` binary embedded in the CLI, since the `start`
  command of CLI v1.2.6 is broken upstream; the withdraw mode needs no node
  (#8).
* The timing settings are checked as whole numbers at start (#8).

### Fixed

* The CLI is installed from the release assets: upstream renamed its
  repository and moved the downloads, and a failed download no longer goes
  unnoticed (#1).
* `quick_test.sh` fails when the container exits, is never healthy,
  or runs an outdated CLI (#1).

## [0.0.1] - 2023-12-31

### Added

* Alpine image that installs the latest AIOZ dCDN CLI
  (`AIOZNetwork/aioz-dcdn-cli-node`, since renamed `aioz-depin-cli`) from its
  GitHub releases at build time and again at every start, configures the
  wallet from the mounted `privkey.json` and runs the node.
* Build and push workflow for Docker Hub, local helper scripts and a quick
  test.

[Unreleased]: https://github.com/Rinzler78/aioz-node-docker/compare/v0.0.3...develop
[0.0.3]: https://github.com/Rinzler78/aioz-node-docker/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/Rinzler78/aioz-node-docker/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/Rinzler78/aioz-node-docker/releases/tag/v0.0.1

<!-- Each release has its own Added, Changed and Fixed sections. -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

# CI and release

The checks run on every change, the release of the public image, and the
watch of the AIOZ upstream.

## Pre-commit hooks

```sh
pre-commit install          # once per clone
pre-commit run --all-files  # full pass
```

Each hook checks the changed files only (shellcheck still follows the scripts
they source, see `.shellcheckrc`):

* Linters and format — shellcheck, shfmt (style in `.editorconfig`), hadolint,
  checkmake (`checkmake.ini`: the required targets are `help`, `test` and
  `check`; no `all` nor `clean`, so that a cleanup of Docker objects is never
  run by a habitual `make clean`), yamllint (`.yamllint.yaml`), actionlint,
  markdownlint (`.markdownlint.yaml`: code blocks as backtick fences only):
  shell scripts, bats tests, Dockerfiles, Makefile, YAML, workflows, Markdown
* Workflow security — zizmor: GitHub workflows. Actions are pinned to a commit
  SHA, with their version in a comment on the line above; every permission is
  commented; only the release job (`contents`) and the upstream watch job
  (`issues`) may write
* Dependencies up to date (blocking) — `.github/scripts/deps-freshness.sh`, run
  only when `.pre-commit-config.yaml`, a workflow, the script or the
  `.github/scripts/release.lib.sh` it sources changes. It
  fails when `pre-commit autoupdate` (run on a copy, the config is never
  rewritten) would update a hook. In the workflows (YAML files), every
  `uses:` but local (`./`) and Docker (docker:// URLs) actions must be pinned
  to a commit SHA, with `# <action> vX.Y.Z` on the line above (a `uses` key in
  another form, such as a flow mapping, fails); it fails when the SHA
  is not the commit of that version, or that version is not the highest
  `vX.Y.Z` tag of the action's repository. Fix: `pre-commit autoupdate`, or pin
  the new release's SHA and comment. Needs the network (`git ls-remote`, no
  token); tests: `.github/scripts/tests/run.sh` (Docker)
* Spelling (English) — cspell, words in `cspell.json`: every text file
* Misconfigurations — trivy config: Dockerfiles, run only when `Dockerfile`,
  `tests/Dockerfile` or `.trivyignore.yaml` changes. The worktrees under
  `.worktrees/` are skipped: their Dockerfile is a copy, out of the accepted
  findings' paths
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
([aquasecurity/setup-trivy](https://github.com/aquasecurity/setup-trivy)) and
hadolint (release binary, checked against its `checksums.sha256`), like the
rolling `alpine:latest` base.

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

## Public Docker image

[rinzlerfr/aioznode](https://hub.docker.com/r/rinzlerfr/aioznode) is public on
Docker Hub. Pushing a `v*` tag runs
`.github/workflows/docker-image.yml`: it builds the image, runs `tests/run.sh`
and `scripts/quick_test.sh`, pushes `rinzlerfr/aioznode:<tag>`, then creates the
GitHub release. `.github/scripts/push-latest.sh` moves `:latest` to the tag only
when it is the highest `vX.Y.Z` tag of the repository (compared as numbers, read
with `git ls-remote` at push time): a hotfix pushed on an older line or a
`v2-beta` tag leaves `:latest`, and so Watchtower, on the newest release. The
highest tag counts even when its build failed: `:latest` then stays on the
previous image until that tag is built again or a higher one ships. Only the
release job gets a write token: the build and the tests, which run the AIOZ
binary, keep a read-only one. The Docker Hub secrets (`DOCKER_USER`,
`DOCKER_PASSWORD`) live in the `dockerhub` environment, which only `v*` tags can
use. A tag is released once: if its GitHub release already exists, the release
job fails.

When `:latest` moves, the `hub-overview` job writes the Docker Hub overview
from `README.md`: `.github/scripts/hub-readme.sh` points its relative links to
the release on GitHub (an image to its file), replaces the Mermaid diagram with
a link to the README there and turns the GitHub alerts into bold labels, since
the overview allows basic Markdown only; it fails over the 25000-byte limit of
Docker Hub, and on a Mermaid diagram never closed.
[peter-evans/dockerhub-description](https://github.com/peter-evans/dockerhub-description)
then sends it with the short description. The action documents its credential:
the account password or a personal access token with the Read, Write, Delete
permission, so `DOCKER_PASSWORD` must be one of them for this job, even if a
narrower token is enough to push. Tests of `.github/scripts/push-latest.sh` and
`.github/scripts/hub-readme.sh`: `.github/scripts/tests/run.sh` (Docker).

## Upstream watch

The AIOZ DePIN hub went down (Cloudflare 521) on 2026-11-07 and the CLI v1.2.6
`start` is broken upstream
([AIOZNetwork/aioz-depin-cli#10](https://github.com/AIOZNetwork/aioz-depin-cli/issues/10)).
The workflow `.github/workflows/upstream-watch.yml` runs
`.github/scripts/upstream-watch.sh` every day at 08:00 UTC (and on demand from
the Actions tab) to report what changed upstream.

Each check is measured against the last report the workflow posted on the
tracking issue (its last comment, or its body), so a lasting state is reported
once, not every day. Comments of anyone else are ignored: on a public issue
they could otherwise hide a change or reset the baseline. Without a report,
the baseline is the outage: hubs down, release `KNOWN_TAG` (`v1.2.6`), issue
open. What counts as a change:

* a hub URL changes state, while the control URL `https://wallet.aioz.network/`
  answers 2xx-4xx. When it does not, the codes measured now are ignored and the
  report keeps the reported ones, so the next run compares with them. The
  states are *down* (000, no answer, or Cloudflare 52x, origin down), *up*
  (2xx, 3xx) and *error* (any other code). Codes of one state are equivalent:
  the main hub answers 404 or 415 to the same request;
* the latest upstream release differs from the reported one;
* the upstream issue #10 changes state, or got comments in the last 25 hours;
* upstream commits in the last 25 hours.

On change, the script comments on the open issue titled **AIOZ upstream watch**
that the workflow opened in this repository (and creates it if missing); an
issue of the same title opened by someone else is ignored. Mentions in quoted
comments are neutralized so their authors are not notified. Nothing is posted
when nothing changed.

A GitHub API error (rate limit, bad token, outage) fails the run (red in
Actions) and posts nothing, so a broken watch never looks like an upstream
change.

Maintenance:

* `KNOWN_TAG` is only the baseline of a first report: update it when moving to
  a new upstream release;
* GitHub disables scheduled workflows of a public repository after 60 days
  without activity: re-enable it from the Actions tab (**AIOZ upstream watch** >
  **Enable workflow**);
* run locally with `DRY_RUN=1 .github/scripts/upstream-watch.sh` (needs `gh`
  logged in); tests: `.github/scripts/tests/run.sh` (Docker).

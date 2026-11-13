# Agent instructions

The single source of instructions for coding agents working on this repository,
whatever the model or the tool. Tool-specific files (`CLAUDE.md`,
`.gemini/settings.json`) only point here; `tests/harness.bats` fails if one of
them carries a rule of its own. The method behind these rules is explained in
[docs/ai-harness.md](docs/ai-harness.md).

## Project

A Docker image that runs an AIOZ DePIN node: it installs the latest upstream
CLI at start, configures the wallet from a mounted private key, checks the node
health, and withdraws the rewards. It runs in production on a Synology NAS.

| Path | Content |
| --- | --- |
| `Dockerfile` | the node image (rolling `alpine:latest` base) |
| `tools/` | the scripts of the image: install, start, health, withdraw |
| `tests/` | bats tests of the image scripts, real captures as fixtures |
| `nas/` | scripts run on the NAS host, outside the image |
| `.github/workflows/` | CI: lint, tests, release, upstream watch |
| `.github/scripts/` | the CI scripts and their tests, run against fakes |
| `helper.docker.*.sh` | local build, run and clean helpers |

## Commands

```sh
tests/run.sh                    # image script tests (bats, in Docker)
tests/run.sh tests/start.bats   # one test file
.github/scripts/tests/run.sh    # CI script tests (bats, in Docker)
pre-commit run --all-files      # every linter, on every file
./quick_test.sh                 # builds the image and waits for healthy (network)
```

## Conventions

* English everywhere: code, comments, docs, commit messages (cspell checks
  every text file; add a real word to `cspell.json`, never ignore a file).
* Shell scripts define functions first and end with a guarded entry point
  (`[[ "${BASH_SOURCE[0]}" == "$0" ]]`): sourcing a script runs nothing. A
  script that needs another one sources it and calls its functions, it never
  runs it as a child process. `tests/scripts.bats` enforces both.
* Style: `.editorconfig` (read by shfmt), `.shellcheckrc`, `.yamllint.yaml`.
* Fix a linter finding, do not disable the rule. An accepted finding keeps its
  reason next to the line (see README, Pre-commit hooks).
* Test fixtures for the shape of external data (GitHub API, AIOZ CLI output,
  container logs) are real captures, never written from memory. Captures keep
  no wallet address or key.
* Validate every number read from a file or a command with
  `^(0|[1-9][0-9]*)$` before bash arithmetic: `$(( ))` evaluates its operands
  as expressions (code injection, leading zeros read as octal).

## Workflow

* Test first: a failing test, proven by a run that names the failing assertion,
  then the code that makes it pass. Then break the fix on purpose and check that
  the test turns red again.
* Git flow: `feature/<name>` from `develop`, `hotfix/<name>` from `master`,
  release tags `vX.Y.Z` on `master`. One branch per change, in its own
  worktree under `.worktrees/`.
* Every change goes through a pull request, never a direct commit to `develop`
  or `master`. Keep a pull request short (about 400 lines, 10 files).
* The documentation changes in the same pull request as the behavior: README,
  workflow header comments, `docs/`.
* Review before merging: standards, specification, security, tests and
  documentation, repeated on the updated diff until no major or minor finding
  is left; the verdict is posted as a pull request comment.
* Stage files by explicit path (`git add <path>`), then read the staged list.
* Commit messages: Conventional Commits (`feat(nas): …`, `fix(watch): …`), no
  attribution trailers.

## Safety rules

* The node private key (`/nodedata/privkey.json` in the container, mounted
  from the host's node data folder) never leaves the host it runs on: never
  read, print, copy or commit it. The default host folder of
  `docker-compose.yml`, `./nodedata`, is ignored by git (`.gitignore`).
* Never print a secret (tokens, credentials, keys) in a command output, a log, a
  test or a pull request.
* Before running a script that calls `docker`, `gh`, `git` or `curl` under test,
  check that the fake in `.github/scripts/tests/fakes/` is the command that
  resolves (`command -v docker`). A fake missing from the `PATH` runs the real
  command.
* `helper.docker.clean.sh` removes every unused image of the Docker host
  (`docker image prune -a`): run it only when the user asks for it.
* No destructive command (`rm -rf`, `docker rm`, `docker image prune`,
  `git reset --hard`, `git push --force`) on the user's machine or the NAS
  without an explicit request.
* Wrap every remote call to the NAS in `timeout`.
* Never bypass a check: no `--no-verify`, no skipped hook, no commented test. A
  blocking check points at a cause to fix.

## Definition of done

A change is done when all of these hold, each proven by a run in the current
session, not assumed:

1. The new behavior has a test that failed before the change and passes after.
2. `tests/run.sh` and `.github/scripts/tests/run.sh` pass.
3. `pre-commit run --all-files` passes.
4. The documentation describes the new behavior.
5. The review loop ended with no major or minor finding, and its verdict is on
   the pull request.

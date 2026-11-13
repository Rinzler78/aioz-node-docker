# AI harness

This repository is developed with coding agents. The harness is the set of
files and checks that make their work reliable whatever the model or the tool:
the same instructions for every agent, and checks that do not depend on the
agent following them.

## One source, thin pointers

The instructions live in one file, [AGENTS.md](../AGENTS.md): project layout,
commands, conventions, safety rules and definition of done. AGENTS.md is an
open format ([agents.md](https://agents.md/)) read as is by several agents,
OpenAI Codex, Cursor and GitHub Copilot among them. The tools that look for
another file get a pointer, never a copy:

| Tool | File it reads | Content |
| --- | --- | --- |
| Codex, Cursor, Copilot, other readers | `AGENTS.md` | the instructions |
| Claude Code | `CLAUDE.md` | `@AGENTS.md`, an import of the file |
| Gemini CLI | `.gemini/settings.json` | `context.fileName` set to `AGENTS.md` |

A rule written twice drifts: the copies diverge, and an agent follows a rule
that no longer holds. `tests/harness.bats` keeps the single source true. It
fails when a pointer file carries anything but the import, when the Gemini
setting no longer names AGENTS.md, and when AGENTS.md or this page cites a file
or folder that does not exist (a renamed script leaves no stale command).

## Checks, not promises

An instruction is a request; a check is a guarantee. Every rule that a program
can decide is a check, run on every commit by pre-commit and again in CI, the
same for an agent and a person:

* Linters and formatters (shellcheck, shfmt, hadolint, actionlint, yamllint,
  markdownlint), English spelling (cspell), workflow security (zizmor),
  misconfigurations and image vulnerabilities (trivy), dependencies up to date.
  The list and the reasons for each accepted finding are in the README,
  Pre-commit hooks.
* Fitness tests that turn repository rules into tests: `tests/scripts.bats`
  (every script sources its dependencies and runs nothing when sourced),
  `tests/image.bats` (the image health check matches the start watchdog),
  `tests/harness.bats` (this harness).
* Tests of every script, in Docker, with the external world replaced by fakes
  (`.github/scripts/tests/fakes/`) and real captures
  (`tests/fixtures/`, `.github/scripts/tests/fixtures/`).

AGENTS.md keeps only what needs judgement: when to write a test, how to review,
what an agent must never do alone.

## The working loop

1. **Test first, and prove the red.** The failing run must name the failing
   assertion. Once green, the fix is broken on purpose to check that the test
   turns red again: a test that passes with the bug present proves nothing.
2. **Real data for external shapes.** Fixtures come from captures of the real
   system (GitHub API responses, AIOZ CLI output, container logs from the
   production NAS), so a test cannot pass against a format the world does not
   produce.
3. **Fakes before anything destructive.** Scripts that call `docker`, `gh`,
   `git` or `curl` run against fakes, and the agent checks that the fake is the
   command that resolves before running them.
4. **Review in a loop.** Each pull request is reviewed on several axes
   (standards, specification, security, tests, documentation) by reviewers that
   did not write it, and the loop runs again on the updated diff until no major
   or minor finding is left. A reviewer's report is not a proof: each finding is
   replayed before it is fixed or refuted.
5. **No claim without a run.** "Done", "fixed" or "passes" is stated only with
   the output of a run from the same session.

## What the review loop caught

Two pull requests of this repository, as examples of findings that a single
pass missed:

* [#20](https://github.com/Rinzler78/aioz-node-docker/pull/20), the upstream
  watch reads its previous state from a public issue. The review found that
  anyone could post a fake report there and silence the alerts: the watch now
  trusts only the reports written by the workflow token, and tests replay the
  forged comment.
* [#21](https://github.com/Rinzler78/aioz-node-docker/pull/21), the NAS
  delivery watch runs as root and reads a state file. The review found that a
  crafted state file could run code through bash arithmetic, and that a
  leading zero was read as octal: every number is now validated first, and the
  tests carry the injection payloads.

## Boundaries

Some actions stay with a person, whatever the agent:

* The node private key never leaves its host; the agent never reads it.
* Secrets are set by the owner, in the GitHub settings or their own terminal.
* Destructive commands on the user's machine or the NAS (removing containers,
  images or files) run only on an explicit request.
* No check is bypassed: a blocking hook points at a cause to fix.

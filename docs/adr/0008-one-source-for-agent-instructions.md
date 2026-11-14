# 0008. One source of instructions for every coding agent

Status: Accepted, 2026-11-13
([#22](https://github.com/Rinzler78/aioz-node-docker/pull/22))

## Context

The repository is developed with coding agents, whatever the model or the
tool. Each tool reads its own file (`CLAUDE.md` for Claude Code, GEMINI.md
for Gemini CLI, `AGENTS.md` for Codex, Cursor and Copilot). A rule copied into
each file drifts: the copies diverge, and an agent follows a rule that no
longer holds.

## Decision

`AGENTS.md` is the single source: project layout, commands, conventions,
safety rules and definition of done. The other files only point to it:
`CLAUDE.md` imports it, `.gemini/settings.json` names it as the context file.
Every rule a program can decide is a check (pre-commit hooks, fitness tests),
the same for an agent and a person; `AGENTS.md` keeps what needs judgement.

## Consequences

* `tests/harness.bats` fails when a pointer file carries a rule of its own,
  or when `AGENTS.md` or a page of `docs/` names a path that does not exist.
* Switching agents, or using several, changes no instruction.
* The method is described in [docs/ai-harness.md](../ai-harness.md).

# 0004. Scripts source each other, they do not run each other

Status: Accepted, 2026-11-08
([#6](https://github.com/Rinzler78/aioz-node-docker/pull/6))

## Context

The image scripts ran each other as child processes, in cascade. The cost was
hidden work and duplicated steps: two of them were identical, so the packages
were updated twice at every start.

## Decision

Every script defines its functions first and ends with a guarded entry point
(`[[ "${BASH_SOURCE[0]}" == "$0" ]]`): sourcing it runs nothing, running it
calls its main function, so each script still works standalone. A script that
needs another one sources it and calls its functions. A container start
then runs no script as a child process, apart from the exceptions below.

Two exceptions are allowed: the watchdog runs `tools/node.health.sh` as a
process, because `timeout` needs one, and `scripts/quick_test.sh` runs the two
version scripts inside the container with `docker exec`.

## Consequences

* `tests/scripts.bats` enforces the rule on every `<name>.sh` script of the
  repository: the guard, silence when sourced, and no script running another
  one outside the exceptions.
* Functions are tested directly, by sourcing their script.
* Scripts share one namespace: function and variable names must not collide.

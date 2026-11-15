# 0010. Watch the deliveries on any Docker host, notify through its scheduler

Status: Accepted, 2026-11-15
([#40](https://github.com/Rinzler78/aioz-node-docker/pull/40))

## Context

Record [0007](0007-delivery-watch-on-the-host.md) put the delivery watch on
the owner's host, with defaults and documentation written for its system: a
state file and a Docker client at paths of that system, a task of its
scheduler. The image runs on any Docker context
([0009](0009-node-data-in-a-named-volume.md)), and the repository does not name
the hardware of the owner's deployment: a watch tied to one system contradicts
both.

## Decision

`host/delivery-watch.sh` runs on any Docker host, as a daily task of its
scheduler (cron, a systemd timer, a task scheduler). By default it keeps its
state next to the script and runs the `docker` of the `PATH`; a scheduler with
a minimal `PATH` sets `DOCKER`. It reports through its exit code and its
output, which every scheduler turns into a notification. The rest of 0007
holds: the count read from the withdraw container logs, one exit 1 per event,
every value checked before bash arithmetic.

## Consequences

* An existing task that relied on the former defaults sets `STATE_FILE` and
  `DOCKER` to its former values.
* The guide for one host system leaves the repository; the quick start covers
  every Docker host.
* `tests/docs.bats` fails when the repository names the hardware of the
  owner's deployment, the history aside (`CHANGELOG.md`, `docs/adr/`).

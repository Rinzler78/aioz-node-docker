# 0002. A health check that proves the function, and a watchdog that acts on it

Status: Accepted, 2026-11-08
([#1](https://github.com/Rinzler78/aioz-node-docker/pull/1),
[#8](https://github.com/Rinzler78/aioz-node-docker/pull/8))

## Context

Docker restart policies ignore the health status: an unhealthy container keeps
running until it exits. An unhealthy node was therefore left alone until the
24-hour timeout of [0001](0001-update-at-every-start.md). A check that only
proves the process is alive would also pass for a node that earns nothing.

## Decision

`tools/node.health.sh` passes only when the node answers `aioz-io stats` and
the wallet reads its rewards (`aioz-io reward balance`). Each query is bounded
by half of the check timeout, so the check stops by itself.

`tools/start.sh` runs a watchdog next to the node: it runs the same check
every `HEALTH_INTERVAL` seconds and stops the node after `HEALTH_RETRIES`
failures in a row. The container then exits, the restart policy starts it
again, and the update runs again. The image `HEALTHCHECK` runs the same check
with the same default timings, which `tests/image.bats` ties together, so
`docker ps` shows the verdict the watchdog acts on.

## Consequences

* A stuck node is restarted, and updated, within minutes instead of a day.
* While the AIOZ network is unreachable, the wallet check fails and the
  container restarts in a loop: a node that cannot earn is reported, not
  hidden.
* The timing settings are checked as whole numbers before the node starts: a
  value such as `30s` would fail every check and restart the container
  forever.

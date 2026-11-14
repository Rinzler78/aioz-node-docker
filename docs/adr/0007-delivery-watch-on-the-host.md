# 0007. Watch the deliveries on the NAS host, notify through the task scheduler

Status: Accepted, 2026-11-13
([#21](https://github.com/Rinzler78/aioz-node-docker/pull/21))

## Context

Since the AIOZ hub outage of 2026-11-09, the node keeps verifying its storage
but may get no delivery task
([AIOZNetwork/aioz-depin-cli#12](https://github.com/AIOZNetwork/aioz-depin-cli/issues/12)).
The owner wants to know when deliveries stall and when they resume, to decide
whether the node is worth running. The hub serves the delivery count to the
wallet key only, and the key never leaves the NAS: a GitHub workflow cannot
read it.

## Decision

`nas/delivery-watch.sh` runs on the NAS host, daily, as a DSM scheduled task.
It reads the count that the withdraw container logs at every check, keeps
`<count> <epoch of its last change> <ok|stalled>` in a state file, and exits 1
once per event: deliveries stalled for `STALL_HOURS`, resumed after a stall,
a count going down, an invalid state. DSM emails the output of a task that
ends abnormally.

`synodsmnotify` was tried on DSM 7.2.2 and rejected: it takes translation keys
only, not a message.

## Consequences

* The notification needs e-mail notifications set up in DSM, and the task is
  installed by hand (README, Delivery watch).
* A stopped withdraw container logs no new count, so it shows up as a stall.
* The script runs as root and reads a file: every value is checked before bash
  arithmetic, which would run commands hidden in it, and the tests carry
  injection payloads.

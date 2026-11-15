# Delivery watch

`host/delivery-watch.sh` tells when the node stops earning delivery rewards,
then when it earns them again. Since the hub outage of 2026-11-09, nodes keep
verifying their storage but may get no delivery task
([AIOZNetwork/aioz-depin-cli#12](https://github.com/AIOZNetwork/aioz-depin-cli/issues/12)).

It runs on the Docker host, not in the image: a daily task of the host
scheduler (cron, a systemd timer, the task scheduler of the host system). The
delivery count is served by the hub to the wallet key only, so it reads the
count the reward container logs at every check. It keeps
`<count> <epoch of its last change> <ok|stalled>` in `STATE_FILE` and exits 1
when there is something to report. Once per event:

* deliveries stalled: the count has not changed for `STALL_HOURS` (48). A
  stopped reward container logs no new count, so it shows up as a stall too;
* deliveries resumed after a reported stall;
* the count went down (counter reset, or 0 when the hub omits it): the watch
  restarts from the new count;
* the state file is invalid (not two decimal numbers without leading zero and
  `ok` or `stalled`): the watch restarts from the current count. Every value is
  checked before any arithmetic, as bash would run commands hidden in it and
  read a leading 0 as octal.

On every run until fixed: no Docker client at `DOCKER`, no count in the logs
(reward container removed or renamed), a state file that cannot be written, or
a `STALL_HOURS` that is not a number above 0.

The script prints its message and exits 1: the scheduler turns that into a
notification. cron mails the output of a task to its owner when `MAILTO` is
set; a task scheduler that notifies on failure does it on the exit code.

## Install

1. Copy `host/delivery-watch.sh` to a folder of the Docker host, where the
   state file will live too (for example `/opt/aioznode/`). Only the user of
   the task may write to that folder: that user can read the Docker logs, so
   it is as powerful as root, and runs whatever the folder holds.
2. Schedule it daily, as a user allowed to run `docker logs`. With cron:

   ```sh
   MAILTO=you@example.com
   0 9 * * * bash /opt/aioznode/delivery-watch.sh
   ```

3. Run it once: it records the current count (`watch started`).

## Settings

Environment variables, set before the command in the task:

| Variable | Default |
| --- | --- |
| `WITHDRAW_CONTAINER` | `aioz-compose-aioznode-auto-withdraw-reward-1` |
| `STATE_FILE` | `delivery-watch.state`, next to the script |
| `STALL_HOURS` | `48` |
| `DOCKER` | `docker`, from the `PATH` |

A scheduler with a minimal `PATH` sets `DOCKER` to the full path of the Docker
client.

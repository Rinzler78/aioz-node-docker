# Synology NAS

Running the node on a Synology NAS, and the delivery watch that runs on the NAS
host.

## Install Docker

If not already installed, go to the Package Center, search for Docker, and
install it.

## Search aioznode image

In the Docker GUI, search for your built image or import it if needed.

## Create nodedata directory

Using File Station, create a directory on your NAS to be used as the node's data
directory. Example: `/volume1/docker/aioznode/nodedata`

## Configure image and start container

1. In Docker GUI, go to Images, select your `aioznode` image, and click Launch.
2. Name your container (e.g., `aioznode`).
3. (Optional) Enable resource limits: set CPU priority to high, memory limit to
   1024 MB.
4. Go to Advanced Settings and enable auto-restart.
5. In Volumes, add the directory you created (e.g., `/volume1/docker/aioznode/nodedata`)
   and mount it to `/nodedata` inside the container.
6. Validate and launch the container.

## Delivery watch

`nas/delivery-watch.sh` tells when the node stops earning delivery rewards,
then when it earns them again. Since the hub outage of 2026-11-09, nodes keep
verifying their storage but may get no delivery task
([AIOZNetwork/aioz-depin-cli#12](https://github.com/AIOZNetwork/aioz-depin-cli/issues/12)).

It runs on the NAS host, not in the image. The delivery count is served by the
hub to the wallet key only, so it reads the count the reward container logs at
every check. It keeps `<count> <epoch of its last change> <ok|stalled>` in
`STATE_FILE` and exits 1 when there is something to report. Once per event:

* deliveries stalled: the count has not changed for `STALL_HOURS` (48). A
  stopped reward container logs no new count, so it shows up as a stall too;
* deliveries resumed after a reported stall;
* the count went down (counter reset, or 0 when the hub omits it): the watch
  restarts from the new count;
* the state file is invalid (not two decimal numbers without leading zero and
  `ok` or `stalled`): the watch restarts from the current count. Every value is
  checked before any arithmetic, as bash would run commands hidden in it and
  read a leading 0 as octal.

On every run until fixed: no count in the logs (reward container removed or
renamed), a state file that cannot be written, or a `STALL_HOURS` that is not a
number above 0.

DSM notifies a task that ends abnormally, with its output. `synodsmnotify`
cannot carry the message: on DSM 7 it only accepts translation keys as title
and message.

Install it once:

1. Copy `nas/delivery-watch.sh` to `/volume1/docker/aioznode/`.
2. Control Panel > Task Scheduler > Create > Scheduled Task > User-defined
   script. User: `root` (Container Manager needs it). Schedule: daily.
3. Task Settings: tick **Send run details by email** and **Send run details
   only when the script terminates abnormally** (needs e-mail notifications set
   up in Control Panel > Notification > Email). Run command:
   `bash /volume1/docker/aioznode/delivery-watch.sh`
4. Run it once: it records the current count (`watch started`).

Settings (environment variables, set before the command in the task):
`WITHDRAW_CONTAINER` (`aioz-compose-aioznode-auto-withdraw-reward-1`),
`STATE_FILE` (`/volume1/docker/aioznode/delivery-watch.state`), `STALL_HOURS`
(48), `DOCKER` (`/usr/local/bin/docker`).

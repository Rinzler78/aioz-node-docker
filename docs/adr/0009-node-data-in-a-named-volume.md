# 0009. Keep the node data in a named volume, on any Docker context

Status: Accepted, 2026-11-14
([#33](https://github.com/Rinzler78/aioz-node-docker/pull/33))

## Context

The documentation and `docker-compose.yml` assumed a folder of the Docker host
for the node data: `./nodedata` by default, `/volume1/docker/aioznode/nodedata`
on the owner's Synology NAS. A remote Docker context (`docker context`,
`DOCKER_HOST=ssh://…`) runs the containers on a host whose folders the client
does not know, and compose expands `~` on the client, not on that host.

## Decision

`docker-compose.yml` mounts a named volume by default, with the fixed name
`aioznode-data`, the one of the quick start: a volume named after the compose
project would change with the folder of the clone, and an empty volume starts
a new wallet. `NODEDATA_PATH`, when set, replaces it with a folder of the
Docker host. A wallet key is copied into the volume through the Docker API,
`docker cp` or `docker compose cp`, on a container created but not yet
started, since `docker cp` reaches a stopped container too. The Synology NAS
is documented as one deployment example.

## Consequences

* The image deploys the same way on a local engine, a remote host or a NAS,
  with no host path to know.
* A deployment of the compose file that relied on the former default,
  `./nodedata`, starts a new wallet unless it sets `NODEDATA_PATH=./nodedata`:
  the changelog says so.
* The key in a volume is not a file the owner sees on the host, and
  `docker compose down -v` deletes it when compose created the volume: the
  documentation tells how to back it up with `docker cp`, which writes it on
  the machine that runs the command.

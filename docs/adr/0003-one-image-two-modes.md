# 0003. One image for the node and the reward withdrawal

Status: Accepted, 2026-11-08
([#2](https://github.com/Rinzler78/aioz-node-docker/pull/2))

## Context

The reward withdrawal had its own image,
[rinzlerfr/aioznode-auto-withdraw-reward](https://hub.docker.com/r/rinzlerfr/aioznode-auto-withdraw-reward),
built `FROM` the node image in another repository that held this one as a
submodule pinned to v0.0.1. It added two scripts, `bc` and a few settings, at
the cost of two images, two CI pipelines and a version skew between them. Its
default reward address was a personal one.

## Decision

One image runs both modes. Its default command, `tools/start.sh`, runs the
node; started with `tools/start-watching-reward.sh`, it withdraws the rewards.
`docker-compose.yml` runs both services from
[rinzlerfr/aioznode](https://hub.docker.com/r/rinzlerfr/aioznode), the withdraw
one with the node data mounted read-only and the image health check disabled,
since it runs no node.

`WITHDRAW_ADDRESS_HEX` has no default: the withdraw mode refuses to start
without a `0x` address of 40 hex digits.

## Consequences

* One build, one CI and one version for both modes.
* The withdraw container also updates the CLI at start, which it needs to read
  and withdraw the rewards.
* A missing or mistyped address stops the withdraw container at once, instead
  of a withdraw attempt to an empty address every minute.

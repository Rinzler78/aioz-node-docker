# 0006. The latest tag follows the highest release only

Status: Accepted, 2026-11-11
([#15](https://github.com/Rinzler78/aioz-node-docker/pull/15))

## Context

The release build of
[rinzlerfr/aioznode](https://hub.docker.com/r/rinzlerfr/aioznode) pushed the
`latest` tag for every `v*` tag. A fix tag on an older line, or a tag such as
`v2-beta`, moved `:latest` back, and the hosts that follow `:latest` with
Watchtower then downgraded their nodes.

## Decision

The build pushes the image under its own tag, then
`.github/scripts/push-latest.sh` moves `:latest` to it only when the tag is the
highest `vX.Y.Z` release of the repository, compared as numbers (v1.7.12 is
above v1.7.9). The tags are read with `git ls-remote` at push time; when they
cannot be read, `:latest` is not moved and the job fails, the image being
already pushed under its own tag.

## Consequences

* `:latest` never goes back: a hotfix on an older line ships under its own tag
  only.
* The highest tag counts even when its build failed: `:latest` then stays on
  the previous image until that tag is built again or a higher one ships.
* Two releases built at the same time can race only within the seconds
  between reading the tags and pushing, against minutes of build.

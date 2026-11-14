# Architecture decision records

Each record states one decision of this repository: the context that forced
it, the decision, and its consequences, good and bad. A record is not edited
once accepted, except for its status: a new decision supersedes it, and its
status then links to the new record.

`tests/docs.bats` checks the format: files named `<NNNN>-<title>.md`, numbered
without gap, a title with the number, a dated status (`Proposed`, `Accepted`,
`Deprecated` or `Superseded by [NNNN]`), then the sections Context, Decision
and Consequences, and this index listing every record in order. How the parts
fit together is described in [docs/architecture.md](../architecture.md).

1. [0001. Update the node at every container start](0001-update-at-every-start.md)
2. [0002. A health check that proves the function, and a watchdog that acts on it](0002-functional-health-check-and-watchdog.md)
3. [0003. One image for the node and the reward withdrawal](0003-one-image-two-modes.md)
4. [0004. Scripts source each other, they do not run each other](0004-source-scripts-do-not-spawn.md)
5. [0005. Run the embedded aioz-io instead of the CLI start](0005-run-the-embedded-aioz-io.md)
6. [0006. The latest tag follows the highest release only](0006-latest-follows-the-highest-release.md)
7. [0007. Watch the deliveries on the NAS host, notify through the task scheduler](0007-delivery-watch-on-the-host.md)
8. [0008. One source of instructions for every coding agent](0008-one-source-for-agent-instructions.md)

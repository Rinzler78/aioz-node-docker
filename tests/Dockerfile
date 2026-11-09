# Test runner: same base and runtime dependencies as the node image, plus bats.
# Rolling base and unpinned packages, like the node image (see ../Dockerfile).
# hadolint ignore=DL3007 #trivy:ignore:DS-0001
FROM alpine:latest

COPY tools/deps.txt /tmp/deps.txt
# hadolint ignore=DL3018
RUN xargs apk add --no-cache bats < /tmp/deps.txt \
    && adduser -D -u 1000 tester

USER 1000
WORKDIR /repo
HEALTHCHECK NONE
ENTRYPOINT ["bats"]
CMD ["tests"]

# Test runner: same base and runtime dependencies as the node image, plus bats.
FROM alpine:latest

COPY tools/deps.txt /tmp/deps.txt
RUN apk add --no-cache $(cat /tmp/deps.txt) bats

WORKDIR /repo
ENTRYPOINT ["bats"]
CMD ["tests"]

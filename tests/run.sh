#!/bin/bash
# Run the bats suite inside an Alpine container matching the node image.
# Usage: tests/run.sh [bats args...]   (default: the whole tests/ folder)
set -e
cd "$(dirname "$0")/.."
docker build --quiet -t aioznode-tests -f tests/Dockerfile . > /dev/null
docker run --rm -v "$PWD":/repo aioznode-tests "${@:-tests}"

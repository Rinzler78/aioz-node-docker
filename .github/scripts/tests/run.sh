#!/bin/bash
# Run the upstream-watch tests in a container close to the ubuntu runner
# (bash, GNU coreutils, jq). gh and curl are faked by tests/fakes.
set -e
cd "$(dirname "$0")/../../.."
docker run --rm -v "$PWD":/repo -w /repo alpine:latest \
    sh -c 'apk add --no-cache -q bash bats coreutils jq > /dev/null && bats .github/scripts/tests'

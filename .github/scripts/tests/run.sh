#!/bin/bash
# Run the upstream-watch tests in a container close to the ubuntu runner
# (bash, GNU coreutils, jq). gh and curl are faked by tests/fakes.
# Folder of this script, also when run by bare name (bash run.sh).
WATCH_TESTS_DIR="${BASH_SOURCE[0]%/*}"
[ "$WATCH_TESTS_DIR" != "${BASH_SOURCE[0]}" ] || WATCH_TESTS_DIR=.

run_watch_tests() {
    local repo
    repo=$(cd "$WATCH_TESTS_DIR/../../.." && pwd) || return 1
    docker run --rm -v "$repo":/repo -w /repo alpine:latest \
        sh -c 'apk add --no-cache -q bash bats coreutils jq > /dev/null && bats .github/scripts/tests'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_watch_tests "$@"
fi

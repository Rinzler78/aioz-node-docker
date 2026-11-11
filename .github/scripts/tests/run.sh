#!/bin/bash
# Run the tests of the CI scripts (upstream watch, dependency check, latest
# push) in a container close to the ubuntu runner (bash, GNU coreutils, jq).
# gh, curl, git, pre-commit and docker are faked by tests/fakes.
# Folder of this script, also when run by bare name (bash run.sh).
WATCH_TESTS_DIR="${BASH_SOURCE[0]%/*}"
[ "$WATCH_TESTS_DIR" != "${BASH_SOURCE[0]}" ] || WATCH_TESTS_DIR=.

run_watch_tests() {
    local repo
    repo=$(cd "$WATCH_TESTS_DIR/../../.." && pwd) || return
    docker run --rm -v "$repo":/repo -w /repo alpine:latest \
        sh -c 'apk add --no-cache -q bash bats coreutils jq > /dev/null && bats .github/scripts/tests'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_watch_tests "$@"
fi

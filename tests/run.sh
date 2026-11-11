#!/bin/bash
# Run the bats suite inside an Alpine container matching the node image.
# Usage: tests/run.sh [bats args...]   (default: the whole tests/ folder)
# Folder of this script, also when run by bare name (bash run.sh).
TESTS_DIR="${BASH_SOURCE[0]%/*}"
[ "$TESTS_DIR" != "${BASH_SOURCE[0]}" ] || TESTS_DIR=.

run_tests() {
    local repo
    repo=$(cd "$TESTS_DIR/.." && pwd) || return 1
    docker build --quiet -t aioznode-tests -f "$repo/tests/Dockerfile" "$repo" > /dev/null || return 1
    docker run --rm -v "$repo":/repo aioznode-tests "${@:-tests}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_tests "$@"
fi

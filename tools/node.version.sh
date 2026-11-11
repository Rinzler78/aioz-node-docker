#!/bin/bash
# Print the version of the installed CLI (digits and dots only); exit 1 if none.
# Folder of this script, also when run by bare name (bash deploy.sh).
TOOLS_DIR="${BASH_SOURCE[0]%/*}"
[ "$TOOLS_DIR" != "${BASH_SOURCE[0]}" ] || TOOLS_DIR=.
# shellcheck source=tools/version.lib.sh
source "$TOOLS_DIR/version.lib.sh"

node_version() {
    command -v "$BINARY_NAME" > /dev/null || return 1
    "$BINARY_NAME" version 2>&1 | version_of
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    node_version "$@"
fi

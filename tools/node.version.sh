#!/bin/bash
# Print the version of the installed CLI (digits and dots only); exit 1 if none.
# shellcheck source=tools/version.lib.sh
source "${BASH_SOURCE[0]%/*}/version.lib.sh"

node.isInstalled.sh || exit 1
"$BINARY_NAME" version 2>&1 | version_of

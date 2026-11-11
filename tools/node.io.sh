#!/bin/bash
# aioz-io, the node binary embedded in the CLI wrapper ($BINARY_NAME). The
# scripts run it directly: the v1.2.6 wrapper fails to start the node
# (upstream AIOZNetwork/aioz-depin-cli#10). The wrapper extracts aioz-io to
# NODE_IO when it runs, but only if it is missing: after an update of the
# wrapper, node_io_sync replaces the stale copy.
# Sourced by deploy.sh (node_io_sync), node.health.sh and withdraw.reward.sh
# (NODE_IO); runs standalone too (image build).
# Folder of this script, also when run by bare name (bash deploy.sh).
TOOLS_DIR="${BASH_SOURCE[0]%/*}"
[ "$TOOLS_DIR" != "${BASH_SOURCE[0]}" ] || TOOLS_DIR=.
# shellcheck source=tools/version.lib.sh
source "$TOOLS_DIR/version.lib.sh"

NODE_IO="${NODE_IO:-$HOME/.cache/aioz-depin-cli/bin/aioz-io}"

# Version of the extracted aioz-io (it prints it on stderr), empty if none.
node_io_version() {
    [ -x "$NODE_IO" ] && "$NODE_IO" version 2>&1 | version_of
}

# Make NODE_IO the aioz-io of the installed wrapper: 0 when it is, else 1.
node_io_sync() {
    local cli_version
    # Running the wrapper extracts aioz-io when it is missing.
    cli_version=$("$BINARY_NAME" version 2>&1 | version_of)
    if [ -n "$cli_version" ] && [ "$(node_io_version)" = "$cli_version" ]; then
        return 0
    fi
    rm -f "$NODE_IO"
    "$BINARY_NAME" version > /dev/null 2>&1
    if [ -n "$cli_version" ] && [ "$(node_io_version)" = "$cli_version" ]; then
        echo "aioz-io $cli_version extracted to $NODE_IO"
        return 0
    fi
    echo "ERROR: $BINARY_NAME ${cli_version:-(no version)} did not extract aioz-io to $NODE_IO" >&2
    return 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    node_io_sync
fi

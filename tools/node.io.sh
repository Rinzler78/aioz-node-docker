#!/bin/bash
# aioz-io, the node binary embedded in the CLI wrapper ($BINARY_NAME). The
# scripts run it directly: the v1.2.6 wrapper fails to start the node
# (upstream AIOZNetwork/aioz-depin-cli#10). The wrapper extracts it under
# $HOME when it runs, but only if it is missing: after an update of the
# wrapper, node_io_sync replaces the stale copy. The CLI the copy comes from
# is recorded by its sha256: the versions of the two binaries may differ.
# Sourced by deploy.sh (node_io_sync; start.sh gets NODE_IO through it),
# node.health.sh and withdraw.reward.sh (NODE_IO); runs standalone too (image
# build).

# Fixed by the wrapper, not a setting.
NODE_IO="$HOME/.cache/aioz-depin-cli/bin/aioz-io"
NODE_IO_SOURCE="$HOME/.cache/aioz-depin-cli/aioz-io.cli-sha256"

# Make NODE_IO the aioz-io of the installed CLI: 0 when it is, else 1.
node_io_sync() {
    local cli sum
    if ! cli=$(command -v "$BINARY_NAME"); then
        echo "ERROR: $BINARY_NAME is not installed" >&2
        return 1
    fi
    sum=$(sha256sum "$cli") || return 1
    sum=${sum%% *}
    if [ -x "$NODE_IO" ] && [ "$(cat "$NODE_IO_SOURCE" 2> /dev/null)" = "$sum" ]; then
        return 0
    fi
    rm -f "$NODE_IO" "$NODE_IO_SOURCE"
    # Running the wrapper extracts aioz-io when it is missing.
    if ! "$cli" version > /dev/null 2>&1; then
        echo "ERROR: $cli version failed: aioz-io not extracted" >&2
        return 1
    fi
    if [ ! -x "$NODE_IO" ]; then
        echo "ERROR: $cli did not extract aioz-io to $NODE_IO" >&2
        return 1
    fi
    echo "$sum" > "$NODE_IO_SOURCE"
    echo "aioz-io of $cli extracted to $NODE_IO"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    node_io_sync
fi

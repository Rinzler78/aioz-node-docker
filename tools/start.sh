#!/bin/bash
# Update the CLI, configure the wallet, then run the node for RUN_TIMEOUT seconds.
# Docker does not restart unhealthy containers, so a watchdog stops the node after
# HEALTH_RETRIES consecutive failed checks (a check running past HEALTH_TIMEOUT
# fails): the container exits, the restart policy starts it again, and the
# update runs again.

HEALTH_START_PERIOD="${HEALTH_START_PERIOD:-300}"
HEALTH_INTERVAL="${HEALTH_INTERVAL:-60}"
HEALTH_RETRIES="${HEALTH_RETRIES:-3}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-30}"
# Folder of this script, also when run by bare name (bash deploy.sh).
TOOLS_DIR="${BASH_SOURCE[0]%/*}"
[ "$TOOLS_DIR" != "${BASH_SOURCE[0]}" ] || TOOLS_DIR=.
# shellcheck source=tools/deploy.sh
source "$TOOLS_DIR/deploy.sh"

if ! deploy; then
    echo "Deployment failed"
    exit 1
fi

watchdog() {
    local node_pid=$1 failures=0
    sleep "$HEALTH_START_PERIOD"
    while kill -0 "$node_pid" 2> /dev/null; do
        if timeout "${HEALTH_TIMEOUT}s" "$TOOLS_DIR/node.health.sh"; then
            failures=0
        else
            failures=$((failures + 1))
            echo "WARN: health check failed ($failures/$HEALTH_RETRIES)"
            if [ "$failures" -ge "$HEALTH_RETRIES" ]; then
                echo "ERROR: node unhealthy, stopping it to restart the container"
                kill "$node_pid"
                return
            fi
        fi
        sleep "$HEALTH_INTERVAL"
    done
}

echo "Starting node for ${RUN_TIMEOUT}s..."
timeout "${RUN_TIMEOUT}s" "$BINARY_NAME" start --home "$NODEDATA_FOLDER" \
    --priv-key-file "$PRIV_KEY_FILE" --laddr tcp://0.0.0.0:1317 &
node_pid=$!

watchdog "$node_pid" &
watchdog_pid=$!

wait "$node_pid"
status=$?
kill "$watchdog_pid" 2> /dev/null
exit "$status"

#!/bin/bash
# Update the CLI and its aioz-io, configure the wallet, then run the node
# (aioz-io, see node.io.sh) for RUN_TIMEOUT seconds. The CLI updates are run by deploy at
# every start, so the node does not update itself (--no-auto-update).
# Docker does not restart unhealthy containers, so a watchdog stops the node after
# HEALTH_RETRIES consecutive failed checks (a check running past HEALTH_TIMEOUT
# fails): the container exits, the restart policy starts it again, and the
# update runs again.

HEALTH_START_PERIOD="${HEALTH_START_PERIOD:-300}"
HEALTH_INTERVAL="${HEALTH_INTERVAL:-60}"
HEALTH_RETRIES="${HEALTH_RETRIES:-3}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-30}"
# Folder of this script, also when run by bare name (bash start.sh).
TOOLS_DIR="${BASH_SOURCE[0]%/*}"
[ "$TOOLS_DIR" != "${BASH_SOURCE[0]}" ] || TOOLS_DIR=.
# shellcheck source=tools/deploy.sh
source "$TOOLS_DIR/deploy.sh"
# shellcheck source=tools/number.lib.sh
source "$TOOLS_DIR/number.lib.sh"

# A bad timing would fail every check (timeout 30ss) or stop the node at once
# (busybox timeout 0s kills at once): refuse it. Only the start period may be 0.
check_timings() {
    local setting name
    for setting in RUN_TIMEOUT:1 HEALTH_START_PERIOD:0 HEALTH_INTERVAL:1 \
        HEALTH_RETRIES:1 HEALTH_TIMEOUT:1; do
        name=${setting%:*}
        require_whole_number "$name" "${!name}" "${setting#*:}" || return 1
    done
}

watchdog() {
    local node_pid=$1 failures=0
    sleep "$HEALTH_START_PERIOD"
    while kill -0 "$node_pid" 2> /dev/null; do
        if timeout "${HEALTH_TIMEOUT}s" "$TOOLS_DIR/node.health.sh" "$HEALTH_TIMEOUT"; then
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

start_node() {
    local node_pid watchdog_pid status
    check_timings || return 1
    if ! deploy; then
        echo "Deployment failed"
        return 1
    fi
    echo "Starting node for ${RUN_TIMEOUT}s..."
    timeout "${RUN_TIMEOUT}s" "$NODE_IO" start --home "$NODEDATA_FOLDER" \
        --priv-key-file "$PRIV_KEY_FILE" --laddr tcp://0.0.0.0:1317 --no-auto-update &
    node_pid=$!
    watchdog "$node_pid" &
    watchdog_pid=$!
    wait "$node_pid"
    status=$?
    kill "$watchdog_pid" 2> /dev/null
    return "$status"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    start_node "$@"
fi

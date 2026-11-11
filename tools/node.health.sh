#!/bin/bash
# Health check of the start.sh watchdog and of the image HEALTHCHECK: the node
# answers `stats` and the wallet reads its rewards (aioz-io, see node.io.sh;
# `reward balance` queries the network, so it answers with the node down).
# ENDPOINT (stats only) targets another node; default is the local one.
# Usage: node.health.sh [timeout]. The timeout (seconds) is the one of the
# caller: the start.sh watchdog passes its HEALTH_TIMEOUT; the image
# HEALTHCHECK passes none, so the default is its --timeout (image.bats ties
# them). Each query is bounded by half of it: the Docker HEALTHCHECK kills
# this script outright on timeout, and the watchdog timeout signals it only,
# so a query must stop by itself rather than outlive the check. The last query
# runs as `exec timeout`, which replaces this script: busybox timeout signals
# its child only, so the check pid is the query's own timeout.
# Folder of this script, also when run by bare name (bash node.health.sh).
TOOLS_DIR="${BASH_SOURCE[0]%/*}"
[ "$TOOLS_DIR" != "${BASH_SOURCE[0]}" ] || TOOLS_DIR=.
# shellcheck source=tools/node.io.sh
source "$TOOLS_DIR/node.io.sh"
# shellcheck source=tools/number.lib.sh
source "$TOOLS_DIR/number.lib.sh"

node_health() {
    local check_timeout="${1:-30}" budget
    if ! is_whole_number "$check_timeout" 1; then
        whole_number_error "check timeout" "$check_timeout" 1
        return 1
    fi
    budget=$((check_timeout / 2))
    [ "$budget" -ge 1 ] || budget=1
    timeout "${budget}s" "$NODE_IO" stats \
        --endpoint "${ENDPOINT:-http://127.0.0.1:1317}" > /dev/null || return 1
    exec timeout "${budget}s" "$NODE_IO" reward balance \
        --priv-key-file "$PRIV_KEY_FILE" > /dev/null
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    node_health "$@"
fi

#!/bin/bash
# Health check of the start.sh watchdog and of the image HEALTHCHECK: the node
# answers `stats` and the wallet reads its rewards (aioz-io, see node.io.sh;
# `reward balance` queries the network, so it answers with the node down).
# ENDPOINT (stats only) targets another node; default is the local one.
# Each query is bounded by half of HEALTH_TIMEOUT: the Docker HEALTHCHECK kills
# this script outright on timeout, and the watchdog timeout signals it only,
# so a query must stop by itself rather than outlive the check.
# Folder of this script, also when run by bare name (bash node.health.sh).
TOOLS_DIR="${BASH_SOURCE[0]%/*}"
[ "$TOOLS_DIR" != "${BASH_SOURCE[0]}" ] || TOOLS_DIR=.
# shellcheck source=tools/node.io.sh
source "$TOOLS_DIR/node.io.sh"

node_health() {
    local budget=$((${HEALTH_TIMEOUT:-30} / 2))
    [ "$budget" -ge 1 ] || budget=1
    timeout "${budget}s" "$NODE_IO" stats \
        --endpoint "${ENDPOINT:-http://127.0.0.1:1317}" > /dev/null || return 1
    exec timeout "${budget}s" "$NODE_IO" reward balance \
        --priv-key-file "$PRIV_KEY_FILE" > /dev/null
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    node_health "$@"
fi

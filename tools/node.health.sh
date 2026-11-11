#!/bin/bash
# Health check of the start.sh watchdog and of the image HEALTHCHECK: the node
# answers `stats` and the wallet reads its rewards (aioz-io, see node.io.sh;
# `reward balance` queries the network, so it answers with the node down).
# ENDPOINT targets another node; default is the local one.
# A timeout on this script (SIGTERM) also stops the running query.
# Folder of this script, also when run by bare name (bash node.health.sh).
TOOLS_DIR="${BASH_SOURCE[0]%/*}"
[ "$TOOLS_DIR" != "${BASH_SOURCE[0]}" ] || TOOLS_DIR=.
# shellcheck source=tools/node.io.sh
source "$TOOLS_DIR/node.io.sh"

node_health() {
    local query
    "$NODE_IO" stats --endpoint "${ENDPOINT:-http://127.0.0.1:1317}" > /dev/null &
    query=$!
    trap 'kill "$query" 2> /dev/null' TERM
    wait "$query" || return 1
    trap - TERM
    exec "$NODE_IO" reward balance --priv-key-file "$PRIV_KEY_FILE" > /dev/null
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    node_health "$@"
fi

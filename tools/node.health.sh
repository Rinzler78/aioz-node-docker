#!/bin/bash
# Health check of the start.sh watchdog and of the image HEALTHCHECK: the node
# answers `stats` (aioz-io, see node.io.sh). ENDPOINT targets another node;
# default is the local one.
# exec: a timeout on this script stops the call itself.
# Folder of this script, also when run by bare name (bash node.health.sh).
TOOLS_DIR="${BASH_SOURCE[0]%/*}"
[ "$TOOLS_DIR" != "${BASH_SOURCE[0]}" ] || TOOLS_DIR=.
# shellcheck source=tools/node.io.sh
source "$TOOLS_DIR/node.io.sh"

node_health() {
    exec "$NODE_IO" stats --endpoint "${ENDPOINT:-http://127.0.0.1:1317}" > /dev/null
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    node_health "$@"
fi

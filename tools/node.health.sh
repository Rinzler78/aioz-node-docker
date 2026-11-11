#!/bin/bash
# Health check of the start.sh watchdog (and, once the CLI interface is known,
# of the Docker HEALTHCHECK): the node answers with the rewards of the
# configured wallet. ENDPOINT targets another node; default is the local one.
# exec: a timeout on this script stops the CLI call itself.

node_health() {
    exec "$BINARY_NAME" reward balance \
        --priv-key-file "$PRIV_KEY_FILE" \
        --endpoint "${ENDPOINT:-http://127.0.0.1:1317}" > /dev/null
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    node_health "$@"
fi

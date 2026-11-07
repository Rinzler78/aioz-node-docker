#!/bin/bash
# Health check shared by the Docker HEALTHCHECK and the start.sh watchdog:
# the node answers with the rewards of the configured wallet.
# ENDPOINT targets a remote node (auto-withdraw image); default is the local one.

"$BINARY_NAME" reward balance \
    --priv-key-file "$PRIV_KEY_FILE" \
    --endpoint "${ENDPOINT:-http://127.0.0.1:1317}" > /dev/null

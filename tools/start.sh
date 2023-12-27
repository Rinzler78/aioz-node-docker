#!/bin/bash

## Re Run deploy
if ! deploy.sh
then
    echo "Deploymentt failed"
    exit 1
fi

echo "Starting node for ${RUN_TIMEOUT}s..."
timeout "${RUN_TIMEOUT}s" $BINARY_NAME start --home $NODEDATA_FOLDER --priv-key-file $PRIV_KEY_FILE --laddr tcp://0.0.0.0:1317
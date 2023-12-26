#!/bin/bash

if ! node.isInstalled.sh
then
    echo "Node is not installed. Cannot configure wallet"
    exit 1
fi

if ! [ -f $PRIV_KEY_FILE ];
then
    echo "Private key file not exist : $PRIV_KEY_FILE"
    echo "Creating new one"
    $BINARY_NAME keytool new --save-priv-key $PRIV_KEY_FILE
fi

if ! [ -f $PRIV_KEY_FILE ];
then
    echo "Error creating new wallet"
    exit 1
fi

echo "Wallet successfully configured"
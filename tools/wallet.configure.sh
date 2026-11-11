#!/bin/bash
# Create the node wallet (PRIV_KEY_FILE) when it does not exist yet.
# Sourced by deploy.sh (wallet_configure); runs standalone too.

wallet_configure() {
    if ! command -v "$BINARY_NAME" > /dev/null; then
        echo "Node is not installed. Cannot configure wallet"
        return 1
    fi
    if [ ! -f "$PRIV_KEY_FILE" ]; then
        echo "Private key file not exist : $PRIV_KEY_FILE"
        echo "Creating new one"
        "$BINARY_NAME" keytool new --save-priv-key "$PRIV_KEY_FILE"
    fi
    if [ ! -f "$PRIV_KEY_FILE" ]; then
        echo "Error creating new wallet"
        return 1
    fi
    echo "Wallet successfully configured"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    wallet_configure
fi

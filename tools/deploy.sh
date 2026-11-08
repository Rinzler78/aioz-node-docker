#!/bin/bash
# Update the system packages, install or update the CLI, configure the wallet,
# then clean the packages. Sourced by start.sh and start-watching-reward.sh
# (deploy); runs standalone too.
# Folder of this script, also when run by bare name (bash deploy.sh).
TOOLS_DIR="${BASH_SOURCE[0]%/*}"
[ "$TOOLS_DIR" != "${BASH_SOURCE[0]}" ] || TOOLS_DIR=.
# shellcheck source=tools/dist.sh
source "$TOOLS_DIR/dist.sh"
# shellcheck source=tools/node.install.sh
source "$TOOLS_DIR/node.install.sh"
# shellcheck source=tools/wallet.configure.sh
source "$TOOLS_DIR/wallet.configure.sh"

deploy() {
    dist_update
    node_install || return 1
    wallet_configure || return 1
    dist_clean
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    deploy
fi

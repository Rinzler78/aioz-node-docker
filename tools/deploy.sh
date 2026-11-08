#!/bin/bash
# Update the system packages, install or update the CLI, configure the wallet,
# then clean the packages. Sourced by start.sh and start-watching-reward.sh
# (deploy); runs standalone too.
# shellcheck source=tools/dist.sh
source "${BASH_SOURCE[0]%/*}/dist.sh"
# shellcheck source=tools/node.install.sh
source "${BASH_SOURCE[0]%/*}/node.install.sh"
# shellcheck source=tools/wallet.configure.sh
source "${BASH_SOURCE[0]%/*}/wallet.configure.sh"

deploy() {
    dist_update
    node_install || return 1
    wallet_configure || return 1
    dist_clean
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    deploy
fi

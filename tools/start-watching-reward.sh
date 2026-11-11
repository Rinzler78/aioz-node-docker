#!/bin/bash
# Withdraw mode: every CHECK_FREQ seconds, withdraw the node rewards to
# WITHDRAW_ADDRESS_HEX once they exceed WITHDRAW_MIN_VALUE.
# Folder of this script, also when run by bare name (bash start-watching-reward.sh).
TOOLS_DIR="${BASH_SOURCE[0]%/*}"
[ "$TOOLS_DIR" != "${BASH_SOURCE[0]}" ] || TOOLS_DIR=.
# shellcheck source=tools/withdraw.reward.sh
source "$TOOLS_DIR/withdraw.reward.sh"
# shellcheck source=tools/deploy.sh
source "$TOOLS_DIR/deploy.sh"

start_watching_reward() {
    check_withdraw_address || return 1
    if ! deploy; then
        echo "Deployment failed"
        return 1
    fi
    while true; do
        withdraw_reward
        sleep "${CHECK_FREQ:-60}"
    done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    start_watching_reward "$@"
fi

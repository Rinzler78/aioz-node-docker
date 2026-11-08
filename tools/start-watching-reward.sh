#!/bin/bash
# Withdraw mode: every CHECK_FREQ seconds, withdraw the node rewards to
# WITHDRAW_ADDRESS_HEX once they exceed WITHDRAW_MIN_VALUE.
# Folder of this script, also when run by bare name (bash deploy.sh).
TOOLS_DIR="${BASH_SOURCE[0]%/*}"
[ "$TOOLS_DIR" != "${BASH_SOURCE[0]}" ] || TOOLS_DIR=.
# shellcheck source=tools/withdraw.reward.sh
source "$TOOLS_DIR/withdraw.reward.sh"
# shellcheck source=tools/deploy.sh
source "$TOOLS_DIR/deploy.sh"

check_withdraw_address || exit 1

if ! deploy; then
    echo "Deployment failed"
    exit 1
fi

while true; do
    withdraw_reward
    sleep "${CHECK_FREQ:-60}"
done

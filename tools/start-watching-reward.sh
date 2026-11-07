#!/bin/bash
# Withdraw mode: every CHECK_FREQ seconds, withdraw the node rewards to
# WITHDRAW_ADDRESS_HEX once they exceed WITHDRAW_MIN_VALUE.
# shellcheck source=tools/withdraw.reward.sh
source "${BASH_SOURCE[0]%/*}/withdraw.reward.sh"

check_withdraw_address || exit 1

if ! deploy.sh; then
    echo "Deployment failed"
    exit 1
fi

while true; do
    withdraw_reward
    sleep "${CHECK_FREQ:-60}"
done

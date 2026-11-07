#!/bin/bash
# Withdraw mode: every CHECK_FREQ seconds, withdraw the node rewards to
# WITHDRAW_ADDRESS_HEX once they exceed WITHDRAW_MIN_VALUE.
# shellcheck source=tools/withdraw.reward.sh
source "${BASH_SOURCE[0]%/*}/withdraw.reward.sh"

# The whole balance goes to this address at every withdraw: refuse a typo.
if [[ ! "$WITHDRAW_ADDRESS_HEX" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
    echo "ERROR: WITHDRAW_ADDRESS_HEX must be set to the 0x address (40 hex digits) that receives the rewards." >&2
    exit 1
fi

# Node to watch: the aioznode service of the compose file by default.
export ENDPOINT="${ENDPOINT:-http://aioznode:1317}"

if ! deploy.sh; then
    echo "Deployment failed"
    exit 1
fi

while true; do
    withdraw_reward
    sleep "${CHECK_FREQ:-60}"
done

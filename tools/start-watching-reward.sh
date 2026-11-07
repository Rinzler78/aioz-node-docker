#!/bin/bash
# Withdraw mode: every CHECK_FREQ seconds, withdraw the node rewards to
# WITHDRAW_ADDRESS_HEX once they exceed WITHDRAW_MIN_VALUE.

if [ -z "$WITHDRAW_ADDRESS_HEX" ]; then
    echo "ERROR: WITHDRAW_ADDRESS_HEX is not set. Set the address that receives the rewards." >&2
    exit 1
fi

# Node to watch: the aioznode service of the compose file by default.
export ENDPOINT="${ENDPOINT:-http://aioznode:1317}"

## Re Run deploy
if ! deploy.sh
then
    echo "Deployment failed"
    exit 1
fi

while true; do
    withdraw.reward.sh
    sleep $CHECK_FREQ
done

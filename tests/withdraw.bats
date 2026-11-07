#!/usr/bin/env bats
# Seam S5: the withdraw mode (withdraw.reward.sh, start-watching-reward.sh)
# against a fake node.

load helpers

setup() {
    setup_withdraw_env
}

@test "withdraws the whole balance to the configured address above the minimum" {
    serve_balance 7761729917265715262

    run withdraw.reward.sh

    [ "$status" -eq 0 ]
    [ -e "$FAKE_STATE/withdraw.args" ]
    args=$(cat "$FAKE_STATE/withdraw.args")
    [[ "$args" == *"--address $WITHDRAW_ADDRESS_HEX"* ]]
    [[ "$args" == *"--amount 7761729917265715262attoaioz"* ]]
    [[ "$args" == *"--priv-key-file $PRIV_KEY_FILE"* ]]
}

@test "does not withdraw below the minimum" {
    serve_balance 999999999999999999

    run withdraw.reward.sh

    [ "$status" -eq 0 ]
    [ ! -e "$FAKE_STATE/withdraw.args" ]
}

@test "withdraw mode refuses to start without a withdraw address" {
    unset WITHDRAW_ADDRESS_HEX
    serve_balance 7761729917265715262

    run timeout 60 start-watching-reward.sh

    [ "$status" -eq 1 ]
    [[ "$output" == *WITHDRAW_ADDRESS_HEX* ]]
    [ ! -e "$FAKE_STATE/withdraw.args" ]
}

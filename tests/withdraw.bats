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

@test "withdraws a balance above 2^63 attoaioz (about 9.22 AIOZ)" {
    serve_balance 10000000000000000000

    run withdraw.reward.sh

    [ "$status" -eq 0 ]
    [[ "$output" != *"integer expected"* ]]
    [[ "$(cat "$FAKE_STATE/withdraw.args")" == *"--amount 10000000000000000000attoaioz"* ]]
}

@test "does not withdraw below a minimum above 2^63 attoaioz" {
    serve_balance 9300000000000000000

    WITHDRAW_MIN_VALUE="10*10^18" run withdraw.reward.sh

    [ "$status" -eq 0 ]
    [[ "$output" != *"integer expected"* ]]
    [ ! -e "$FAKE_STATE/withdraw.args" ]
}

@test "queries the balance of the configured wallet" {
    serve_balance 1

    run withdraw.reward.sh

    [ "$status" -eq 0 ]
    [ "$(cat "$FAKE_STATE/balance.args")" = "--priv-key-file $PRIV_KEY_FILE" ]
}

@test "withdraw mode checks the rewards every CHECK_FREQ" {
    serve_balance 1

    CHECK_FREQ=1 run timeout 5 start-watching-reward.sh

    [ "$(cat "$FAKE_STATE/balance.args")" = "--priv-key-file $PRIV_KEY_FILE" ]
    [ "$(grep -c 'Node rewards status' <<< "$output")" -ge 2 ]
}

@test "withdraw mode refuses an address that is not 0x and 40 hex digits" {
    serve_balance 7761729917265715262

    WITHDRAW_ADDRESS_HEX="0x1234" run timeout 60 start-watching-reward.sh

    [ "$status" -eq 1 ]
    [[ "$output" == *WITHDRAW_ADDRESS_HEX* ]]
    [ ! -e "$FAKE_STATE/withdraw.args" ]
}

@test "reports a failed balance query once, without withdrawing" {
    # No balance served: the fake CLI fails, like the v1.2.6 CLI today.
    run withdraw.reward.sh

    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: cannot read the rewards"* ]]
    [[ "$output" != *"syntax error"* ]]
    [[ "$output" != *"integer expected"* ]]
    [ ! -e "$FAKE_STATE/withdraw.args" ]
}

@test "refuses an invalid withdraw address when run standalone" {
    serve_balance 7761729917265715262

    WITHDRAW_ADDRESS_HEX="" run withdraw.reward.sh

    [ "$status" -eq 1 ]
    [[ "$output" == *WITHDRAW_ADDRESS_HEX* ]]
    [ ! -e "$FAKE_STATE/withdraw.args" ]
}

@test "logs the rewards like the former auto-withdraw image" {
    serve_balance 7761729917265715262

    run withdraw.reward.sh

    [[ "$output" == *"=> Balance : 7761729917265715262 attoaioz => 7.76172 aioz"* ]]
    [[ "$output" == *"=> Storage : 1855515626269222258 attoaioz => 1.85551 aioz"* ]]
    [[ "$output" == *"=> Delivery : 120108867395339672540 attoaioz => 120.10886 aioz"* ]]
    [[ "$output" == *"=> Withdraw : 121726139527082329934 attoaioz => 121.72613 aioz"* ]]
    [[ "$output" == *"=> Delivery count : 104515"* ]]
    [[ "$output" == *"=> Stored segment count : 0. Size : "* ]]
    [[ "$output" == *"Try to withdraw... aioz-io reward withdraw --address $WITHDRAW_ADDRESS_HEX --amount 7761729917265715262attoaioz --priv-key-file $PRIV_KEY_FILE"* ]]
}

@test "withdraws with the wallet key, without a node endpoint" {
    serve_balance 7761729917265715262

    run withdraw.reward.sh

    [ "$status" -eq 0 ]
    [ "$(cat "$FAKE_STATE/withdraw.args")" = "--address $WITHDRAW_ADDRESS_HEX --amount 7761729917265715262attoaioz --priv-key-file $PRIV_KEY_FILE" ]
}

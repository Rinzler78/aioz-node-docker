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
    export WITHDRAW_MIN_VALUE="10*10^18"
    serve_balance 9300000000000000000

    run withdraw.reward.sh

    [ "$status" -eq 0 ]
    [[ "$output" != *"integer expected"* ]]
    [ ! -e "$FAKE_STATE/withdraw.args" ]
}

@test "queries the balance on ENDPOINT" {
    serve_balance 1

    run withdraw.reward.sh

    [ "$(cat "$FAKE_STATE/balance.args")" = "--endpoint http://aioznode:1317" ]
}

@test "withdraw mode watches the aioznode service by default, every CHECK_FREQ" {
    unset ENDPOINT
    export CHECK_FREQ=1
    serve_balance 1

    run timeout 5 start-watching-reward.sh

    [ "$(cat "$FAKE_STATE/balance.args")" = "--endpoint http://aioznode:1317" ]
    [ "$(grep -c 'Node rewards status' <<< "$output")" -ge 2 ]
}

@test "withdraw mode refuses an address that is not 0x and 40 hex digits" {
    export WITHDRAW_ADDRESS_HEX="0x1234"
    serve_balance 7761729917265715262

    run timeout 60 start-watching-reward.sh

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
    export WITHDRAW_ADDRESS_HEX=""
    serve_balance 7761729917265715262

    run withdraw.reward.sh

    [ "$status" -eq 1 ]
    [[ "$output" == *WITHDRAW_ADDRESS_HEX* ]]
    [ ! -e "$FAKE_STATE/withdraw.args" ]
}

@test "logs the rewards like the former auto-withdraw image" {
    serve_balance 7761729917265715262

    run withdraw.reward.sh

    [[ "$output" == *"=> Balance : 7761729917265715262 attoaioz => 7.76172 aioz"* ]]
    [[ "$output" == *"=> Storage : 810423534750216148 attoaioz => .81042 aioz"* ]]
    [[ "$output" == *"=> Delivery : 7525653191257749557 attoaioz => 7.52565 aioz"* ]]
    [[ "$output" == *"=> Withdraw : 1100000000000000000 attoaioz => 1.10000 aioz"* ]]
    [[ "$output" == *"=> Stored segment count : 0. Size : "* ]]
    [[ "$output" == *"Try to withdraw... aioznode reward withdraw --endpoint http://aioznode:1317 --address $WITHDRAW_ADDRESS_HEX --amount 7761729917265715262attoaioz --priv-key-file $PRIV_KEY_FILE"* ]]
}

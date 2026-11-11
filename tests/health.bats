#!/usr/bin/env bats
# Seam S7: node.health.sh, the check of the start.sh watchdog and of the image
# HEALTHCHECK. The node must answer and the wallet must read its rewards.

load helpers

setup() {
    setup_node_env
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.2.6"
    node.io.sh > /dev/null
}

teardown() {
    local pid
    for pid in "$FAKE_STATE"/*.pid; do
        [ ! -e "$pid" ] || kill "$(cat "$pid")" 2> /dev/null || true
    done
}

# The hanging query $1 (stats, the default, or balance) is still running.
query_running() {
    kill -0 "$(cat "$FAKE_STATE/${1:-stats}.pid")" 2> /dev/null
}

@test "healthy when the local node answers and the wallet reads its rewards" {
    run node.health.sh

    [ "$status" -eq 0 ]
    [ "$(cat "$FAKE_STATE/stats.args")" = "stats --endpoint http://127.0.0.1:1317" ]
    [ "$(cat "$FAKE_STATE/balance.args")" = "--priv-key-file $PRIV_KEY_FILE" ]
}

@test "unhealthy when the node does not answer" {
    touch "$FAKE_STATE/unhealthy"

    run node.health.sh

    [ "$status" -ne 0 ]
    [ ! -e "$FAKE_STATE/balance.args" ]
}

@test "unhealthy when the wallet cannot read its rewards" {
    rm "$FAKE_STATE/balance.json"

    run node.health.sh

    [ "$status" -ne 0 ]
}

@test "rejects a check timeout that is not a number of seconds" {
    run node.health.sh 30s

    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"*"30s"* ]]
    [ ! -e "$FAKE_STATE/stats.args" ]
}

@test "rejects a check timeout of 0" {
    run node.health.sh 0

    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"*"0"* ]]
    [ ! -e "$FAKE_STATE/stats.args" ]
}

@test "rejects a check timeout with a leading zero (bash reads it as octal)" {
    run node.health.sh 08

    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"*"08"* ]]
    [ ! -e "$FAKE_STATE/stats.args" ]
}

@test "a hanging node query fails the check within its timeout" {
    touch "$FAKE_STATE/hang"
    SECONDS=0

    # Bounded and off the bats pipe: an unbounded query must fail, not hang.
    run sh -c 'timeout 5 node.health.sh 2 2> /dev/null'

    [ "$status" -ne 0 ]
    [ "$SECONDS" -lt 4 ] # budget 1s; the outer timeout is 5s
    run query_running
    [ "$status" -ne 0 ]
}

@test "a hanging wallet query fails the check within its timeout" {
    touch "$FAKE_STATE/hang-balance"
    SECONDS=0

    # Bounded and off the bats pipe: an unbounded query must fail, not hang.
    run sh -c 'timeout 5 node.health.sh 2 2> /dev/null'

    [ "$status" -ne 0 ]
    [ "$SECONDS" -lt 4 ] # budget 1s; the outer timeout is 5s
    run query_running balance
    [ "$status" -ne 0 ]
}

@test "a check killed outright (Docker HEALTHCHECK timeout) leaves no query past its budget" {
    touch "$FAKE_STATE/hang"

    # stderr off the bats pipe: a query left running must not hold the test.
    run sh -c 'timeout -s KILL 2 node.health.sh 8 2> /dev/null'

    [ "$status" -ne 0 ]
    query_running # the budget (half of the 8s timeout) is not over yet
    sleep 3
    run query_running
    [ "$status" -ne 0 ]
}

@test "the image check keeps its default timeout whatever the watchdog HEALTH_TIMEOUT" {
    touch "$FAKE_STATE/hang"

    # Docker runs the check with no argument, in the container environment.
    HEALTH_TIMEOUT=2 run sh -c 'timeout -s KILL 3 node.health.sh 2> /dev/null'

    [ "$status" -ne 0 ]
    query_running # bounded by half of the 30s default, not by HEALTH_TIMEOUT
}

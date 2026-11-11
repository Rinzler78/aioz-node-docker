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

@test "a hanging node query fails the check within HEALTH_TIMEOUT" {
    touch "$FAKE_STATE/hang"
    SECONDS=0

    # Bounded and off the bats pipe: an unbounded query must fail, not hang.
    HEALTH_TIMEOUT=2 run sh -c 'timeout 5 node.health.sh 2> /dev/null'

    [ "$status" -ne 0 ]
    [ "$SECONDS" -lt 4 ] # budget 1s; the outer timeout is 5s
    run query_running
    [ "$status" -ne 0 ]
}

@test "a hanging wallet query fails the check within HEALTH_TIMEOUT" {
    touch "$FAKE_STATE/hang-balance"
    SECONDS=0

    # Bounded and off the bats pipe: an unbounded query must fail, not hang.
    HEALTH_TIMEOUT=2 run sh -c 'timeout 5 node.health.sh 2> /dev/null'

    [ "$status" -ne 0 ]
    [ "$SECONDS" -lt 4 ] # budget 1s; the outer timeout is 5s
    run query_running balance
    [ "$status" -ne 0 ]
}

@test "a check killed outright (Docker HEALTHCHECK timeout) leaves no query past its budget" {
    touch "$FAKE_STATE/hang"

    # stderr off the bats pipe: a query left running must not hold the test.
    HEALTH_TIMEOUT=4 run sh -c 'timeout -s KILL 1 node.health.sh 2> /dev/null'

    [ "$status" -ne 0 ]
    query_running # the budget (HEALTH_TIMEOUT / 2) is not over yet
    sleep 2
    run query_running
    [ "$status" -ne 0 ]
}

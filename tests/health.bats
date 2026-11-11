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
    pkill -f 'sleep 1003' || true
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

@test "a check stopped by timeout leaves no node query running" {
    touch "$FAKE_STATE/hang"

    # stderr off the bats pipe: a query left running must not hold the test.
    run sh -c 'timeout 1 node.health.sh 2> /dev/null'

    [ "$status" -ne 0 ]
    sleep 1
    run pgrep -f 'sleep 1003'
    [ "$status" -ne 0 ]
}

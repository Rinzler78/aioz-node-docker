#!/usr/bin/env bats
# Seams S2 (start with or without a binary) and S3 (watchdog) on start.sh.
# GitHub is unreachable in every test (no release is served) and apk is stubbed.

load helpers

setup() {
    setup_node_env
}

teardown() {
    [ ! -e "$FAKE_STATE/stats.pid" ] || kill "$(cat "$FAKE_STATE/stats.pid")" 2> /dev/null || true
}

@test "starts the installed node when the update fails" {
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.1.0"

    RUN_TIMEOUT=3 run start.sh

    [ "$status" -eq 143 ] # stopped by RUN_TIMEOUT (busybox timeout: SIGTERM)
    [ -e "$FAKE_STATE/started" ]
    [[ "$output" == *WARN* ]]
}

@test "exits 1 without starting when no binary is available" {

    RUN_TIMEOUT=3 run start.sh

    [ "$status" -eq 1 ]
    [ ! -e "$FAKE_STATE/started" ]
}

@test "stops the node after 3 consecutive failed health checks" {
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.1.0"
    touch "$FAKE_STATE/unhealthy"
    SECONDS=0

    RUN_TIMEOUT=120 run start.sh

    [ "$status" -ne 0 ]
    [ -e "$FAKE_STATE/started" ]
    [[ "$output" == *"health check failed (3/3)"* ]]
    [[ "$output" != *"health check failed (4/3)"* ]]
    [ "$SECONDS" -lt 60 ]
}

@test "keeps a healthy node running until RUN_TIMEOUT" {
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.1.0"
    SECONDS=0

    RUN_TIMEOUT=5 run start.sh

    [ "$status" -eq 143 ]
    [ -e "$FAKE_STATE/started" ]
    [[ "$output" != *"health check failed"* ]]
    [ "$SECONDS" -ge 5 ]
}

@test "counts a health check that hangs past HEALTH_TIMEOUT as failed" {
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.1.0"
    touch "$FAKE_STATE/hang"
    SECONDS=0

    # Output to a file: `run` would wait for a query left running on its pipe.
    RUN_TIMEOUT=120 HEALTH_TIMEOUT=1 run sh -c 'start.sh > "$FAKE_STATE/start.log" 2>&1'

    [ "$status" -ne 0 ]
    [[ "$(cat "$FAKE_STATE/start.log")" == *"health check failed (3/3)"* ]]
    [ "$SECONDS" -lt 60 ]
    # The check got HEALTH_TIMEOUT: its query stopped with it (no orphan).
    sleep 1
    run kill -0 "$(cat "$FAKE_STATE/stats.pid")"
    [ "$status" -ne 0 ]
}

@test "refuses a timing that is not a number of seconds, before deploying" {
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.1.0"

    RUN_TIMEOUT=3 HEALTH_TIMEOUT=30s run start.sh

    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: HEALTH_TIMEOUT"*"30s"* ]]
    [ ! -e "$FAKE_STATE/started" ]
}

@test "starts aioz-io on the node data and wallet, listening outside the container" {
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.1.0"

    RUN_TIMEOUT=3 run start.sh

    [ "$(cat "$FAKE_STATE/start.args")" = "start --home $NODEDATA_FOLDER --priv-key-file $PRIV_KEY_FILE --laddr tcp://0.0.0.0:1317 --no-auto-update" ]
}

@test "checks the local node with aioz-io stats" {
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.1.0"

    RUN_TIMEOUT=3 run start.sh

    [ "$(cat "$FAKE_STATE/stats.args")" = "stats --endpoint http://127.0.0.1:1317" ]
}

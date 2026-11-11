#!/usr/bin/env bats
# Seams S2 (start with or without a binary) and S3 (watchdog) on start.sh.
# GitHub is unreachable in every test (no release is served) and apk is stubbed.

load helpers

setup() {
    setup_node_env
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

    RUN_TIMEOUT=120 HEALTH_TIMEOUT=1 run start.sh

    [ "$status" -ne 0 ]
    [[ "$output" == *"health check failed (3/3)"* ]]
    [ "$SECONDS" -lt 60 ]
}

@test "checks the rewards of the configured wallet on the local node" {
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.1.0"

    RUN_TIMEOUT=3 run start.sh

    [ "$(cat "$FAKE_STATE/reward.args")" = "reward balance --priv-key-file $PRIV_KEY_FILE --endpoint http://127.0.0.1:1317" ]
}

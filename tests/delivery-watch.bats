#!/usr/bin/env bats
# nas/delivery-watch.sh against a fake docker whose logs are a real capture of
# the reward container on the NAS (2026-11-13, delivery count 104515).

SCRIPT="$BATS_TEST_DIRNAME/../nas/delivery-watch.sh"
LOGS="$BATS_TEST_DIRNAME/fixtures/withdraw-log-nas-v1.2.6.txt"
DAY=86400

setup() {
    export STATE_FILE="$BATS_TEST_TMPDIR/delivery-watch.state"
    export FAKE_LOGS="$BATS_TEST_TMPDIR/logs"
    export DOCKER="$BATS_TEST_TMPDIR/docker"
    cp "$LOGS" "$FAKE_LOGS"
    # Fake docker: only `logs` is answered; anything else fails the test.
    cat > "$DOCKER" << 'EOF'
#!/bin/bash
[ "$1" = "logs" ] || { echo "unexpected docker $*" >&2; exit 99; }
cat "$FAKE_LOGS" 2> /dev/null || { echo "Error: No such container" >&2; exit 1; }
EOF
    chmod +x "$DOCKER"
    [ -x "$DOCKER" ]
    export NOW=1794560000
}

# Logs of the reward container followed by a status with the delivery count $1.
logs_with_count() {
    { cat "$LOGS" && printf '=> Delivery count : %s\n' "$1"; } > "$FAKE_LOGS"
}

state() {
    cat "$STATE_FILE"
}

@test "starts watching on the first run" {
    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"104515"* ]]
    [ "$(state)" = "104515 $NOW ok" ]
}

@test "stays silent while the count is recent" {
    echo "104515 $((NOW - DAY)) ok" > "$STATE_FILE"

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ "$(state)" = "104515 $((NOW - DAY)) ok" ]
}

@test "reports deliveries stalled for longer than STALL_HOURS" {
    echo "104515 $((NOW - 3 * DAY)) ok" > "$STATE_FILE"

    run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"stalled"*"104515"* ]]
    [ "$(state)" = "104515 $((NOW - 3 * DAY)) stalled" ]
}

@test "honours STALL_HOURS" {
    echo "104515 $((NOW - DAY)) ok" > "$STATE_FILE"

    STALL_HOURS=12 run "$SCRIPT"

    [ "$status" -eq 1 ]
}

@test "reports a stall only once" {
    echo "104515 $((NOW - 4 * DAY)) stalled" > "$STATE_FILE"

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ "$(state)" = "104515 $((NOW - 4 * DAY)) stalled" ]
}

@test "reports deliveries resuming after a stall" {
    echo "104515 $((NOW - 4 * DAY)) stalled" > "$STATE_FILE"
    logs_with_count 104530

    run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"resumed"*"104515"*"104530"* ]]
    [ "$(state)" = "104530 $NOW ok" ]
}

@test "stays silent when the count grows" {
    echo "104500 $((NOW - DAY)) ok" > "$STATE_FILE"

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ "$(state)" = "104515 $NOW ok" ]
}

@test "reads the count of the last status" {
    logs_with_count 104600

    run "$SCRIPT"

    [ "$(state)" = "104600 $NOW ok" ]
}

@test "fails and keeps the state when the logs have no count" {
    echo "104515 $((NOW - DAY)) ok" > "$STATE_FILE"
    rm "$FAKE_LOGS"

    run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR"* ]]
    [ "$(state)" = "104515 $((NOW - DAY)) ok" ]
}

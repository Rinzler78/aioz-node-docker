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
    # Fake docker: only the expected `logs` call is answered.
    cat > "$DOCKER" << 'EOF'
#!/bin/bash
[ "$*" = "logs --tail 200 aioz-compose-aioznode-auto-withdraw-reward-1" ] ||
    { echo "unexpected docker $*" >&2; exit 99; }
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

@test "restarts the watch on an invalid state" {
    # An array index in $(( )) runs its command substitution.
    local payload="a[\$(touch\${IFS}$BATS_TEST_TMPDIR/pwned)]"
    for bad in "104515" "104515 abc ok" "104515 1794000000x ok" "104515 1 maybe" \
        "104515 0999 ok" "0104515 1 ok" "$payload 1 ok" "104515 $payload ok"; do
        echo "$bad" > "$STATE_FILE"

        run "$SCRIPT"

        [ "$status" -eq 1 ]
        [[ "$output" == *"invalid state"* ]]
        [ "$(state)" = "104515 $NOW ok" ]
    done
    [ ! -e "$BATS_TEST_TMPDIR/pwned" ]
}

@test "reports a count going down and restarts from it" {
    echo "104600 $((NOW - DAY)) ok" > "$STATE_FILE"

    run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"went down"*"104600"*"104515"* ]]
    [ "$(state)" = "104515 $NOW ok" ]
}

@test "does not take a count of 0 after a stall as a resume" {
    echo "104515 $((NOW - 4 * DAY)) stalled" > "$STATE_FILE"
    logs_with_count 0

    run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" != *"resumed"* ]]
    [[ "$output" == *"went down"* ]]
    [ "$(state)" = "0 $NOW ok" ]
}

@test "fails clearly when the state folder is missing" {
    STATE_FILE="$BATS_TEST_TMPDIR/missing/state" run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: cannot write"* ]]
    [ "${#lines[@]}" -eq 1 ]
}

@test "reads the logs of WITHDRAW_CONTAINER" {
    WITHDRAW_CONTAINER=other run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"no delivery count"*"other"* ]]
}

@test "refuses a STALL_HOURS or NOW that is not a number" {
    local payload="a[\$(touch\${IFS}$BATS_TEST_TMPDIR/pwned)]"
    echo "104515 $((NOW - DAY)) ok" > "$STATE_FILE"
    for bad in 48h 0 "$payload"; do
        STALL_HOURS="$bad" run "$SCRIPT"

        [ "$status" -eq 1 ]
        [[ "$output" == "ERROR: STALL_HOURS"* ]]
    done
    NOW="$payload" run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == "ERROR: NOW"* ]]
    [ ! -e "$BATS_TEST_TMPDIR/pwned" ]
    [ "$(state)" = "104515 $((NOW - DAY)) ok" ]
}

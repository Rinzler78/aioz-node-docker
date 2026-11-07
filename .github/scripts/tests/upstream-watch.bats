#!/usr/bin/env bats
# upstream-watch.sh against fake gh and curl. Fixtures are real API captures
# of AIOZNetwork/aioz-depin-cli (2026-11-07).

SCRIPT="$BATS_TEST_DIRNAME/../upstream-watch.sh"
export FIXTURES="$BATS_TEST_DIRNAME/fixtures"
API="repos_AIOZNetwork_aioz-depin-cli"

setup() {
    export PATH="$BATS_TEST_DIRNAME/fakes:$PATH"
    export FAKE_GH_DIR="$BATS_TEST_TMPDIR/gh" FAKE_HTTP_DIR="$BATS_TEST_TMPDIR/http"
    mkdir -p "$FAKE_GH_DIR" "$FAKE_HTTP_DIR"
    # Today's state: hub down, control up, v1.2.6, issue open, old comments, no commits.
    for host in main-hub.aioz.network delivery-main-hub.aioz.network hub.aioz.network; do
        printf 521 > "$FAKE_HTTP_DIR/$host"
    done
    printf 200 > "$FAKE_HTTP_DIR/wallet.aioz.network"
    cp "$FIXTURES/releases-latest.json" "$FAKE_GH_DIR/${API}_releases_latest.json"
    cp "$FIXTURES/issue-10.json" "$FAKE_GH_DIR/${API}_issues_10.json"
    cp "$FIXTURES/issue-10-comments.json" "$FAKE_GH_DIR/${API}_issues_10_comments.json"
    echo '[]' > "$FAKE_GH_DIR/${API}_commits.json"
}

posted() {
    cat "$FAKE_GH_DIR/calls" 2> /dev/null
}

@test "stays silent when nothing changed" {
    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == "No change."* ]]
    [ -z "$(posted)" ]
}

@test "reports a hub answering again" {
    printf 200 > "$FAKE_HTTP_DIR/main-hub.aioz.network"

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"change detected: hub"* ]]
    [ "$(posted)" = "create" ]
}

@test "does not report an unreachable hub as answering again" {
    printf 000 > "$FAKE_HTTP_DIR/main-hub.aioz.network"

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == "No change."* ]]
    [ -z "$(posted)" ]
}

@test "ignores the hub check when the control URL is down" {
    printf 200 > "$FAKE_HTTP_DIR/main-hub.aioz.network"
    printf 503 > "$FAKE_HTTP_DIR/wallet.aioz.network"

    run "$SCRIPT"

    [[ "$output" == "No change."* ]]
    [ -z "$(posted)" ]
}

@test "reports a new release" {
    jq '.tag_name = "v1.2.7"' "$FIXTURES/releases-latest.json" > "$FAKE_GH_DIR/${API}_releases_latest.json"

    run "$SCRIPT"

    [[ "$output" == *"change detected: release"* ]]
    [[ "$output" == *"v1.2.7"* ]]
}

@test "reports a new comment on the issue without mentioning its author" {
    jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.[1].created_at = $now | .[1].body = "Fixed, thanks @someone"' \
        "$FIXTURES/issue-10-comments.json" > "$FAKE_GH_DIR/${API}_issues_10_comments.json"

    run "$SCRIPT"

    [[ "$output" == *"change detected: issue-comments"* ]]
    [[ "$output" == *"Fixed, thanks"* ]]
    [[ "$output" != *"@someone"* ]]
}

@test "comments on the open tracking issue when it exists" {
    printf 200 > "$FAKE_HTTP_DIR/main-hub.aioz.network"
    echo 7 > "$FAKE_GH_DIR/tracking-issue"

    run "$SCRIPT"

    [ "$(posted)" = "comment 7" ]
}

@test "fails without posting when the GitHub API errors" {
    rm "$FAKE_GH_DIR/${API}_releases_latest.json"

    run "$SCRIPT"

    [ "$status" -ne 0 ]
    [[ "$output" == *"releases/latest"* ]]
    [[ "$output" != *"change detected"* ]]
    [ -z "$(posted)" ]
}

@test "fails without posting when the time window cannot be computed" {
    WINDOW_HOURS=abc run "$SCRIPT"

    [ "$status" -ne 0 ]
    [[ "$output" == *"window"* ]]
    [ -z "$(posted)" ]
}

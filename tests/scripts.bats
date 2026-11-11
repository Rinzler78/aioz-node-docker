#!/usr/bin/env bats
# Owner rule for scripts: a script that depends on other scripts sources them
# and calls their functions (one process per call); each script still runs
# standalone. Only node.health.sh runs as its own process (timeout needs one).

load helpers

setup() {
    setup_node_env
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.1.0"
    # tools/ off the PATH: entry points must find their dependencies themselves.
    export PATH="${PATH//$REPO_ROOT\/tools:/}"
}

@test "no repository script runs another repository script" {
    # Allowed: comments, source lines, messages (echo/printf text), the
    # watchdog health check and scripts run inside the container by
    # quick_test.sh (docker exec). Quoted calls ("$TOOLS_DIR/x.sh") are still caught.
    offenders=$(for f in "$REPO_ROOT"/tools/*.sh "$REPO_ROOT"/helper.docker.*.sh \
        "$REPO_ROOT"/quick_test.sh "$REPO_ROOT"/.github/scripts/*.sh; do
        grep -vE '^\s*#' "$f" |
            sed -E 's/^\s*source "[^"]*"//; s/(echo|printf) "[^"]*"//g' |
            grep -E '[A-Za-z_.-]+\.sh' | grep -vE 'node\.health\.sh|docker exec' |
            sed "s|^|${f##*/}: |"
    done)
    [ -z "$offenders" ] || {
        echo "$offenders"
        false
    }
}

@test "start.sh runs with tools/ off the PATH" {
    RUN_TIMEOUT=3 run "$REPO_ROOT/tools/start.sh"

    [ "$status" -eq 143 ] # stopped by RUN_TIMEOUT
    [ -e "$FAKE_STATE/started" ]
}

@test "deploy updates the packages once" {
    run "$REPO_ROOT/tools/deploy.sh"

    [ "$status" -eq 0 ]
    [ "$(grep -c '^update' "$FAKE_STATE/apk.log")" -eq 1 ]
    [ "$(grep -c '^upgrade' "$FAKE_STATE/apk.log")" -eq 1 ]
}

@test "withdraw mode runs with tools/ off the PATH" {
    setup_withdraw_env
    export PATH="${PATH//$REPO_ROOT\/tools:/}" CHECK_FREQ=1
    serve_balance 1

    run timeout 5 "$REPO_ROOT/tools/start-watching-reward.sh"

    [[ "$output" == *"Node rewards status"* ]]
}

@test "entry points run by bare name from the tools folder" {
    cd "$REPO_ROOT/tools"

    run bash deploy.sh
    [ "$status" -eq 0 ]

    RUN_TIMEOUT=3 run bash start.sh
    [ "$status" -eq 143 ]
    [ -e "$FAKE_STATE/started" ]
}

@test "dist.sh clean removes the packages of other kernels, then the cache" {
    run "$REPO_ROOT/tools/dist.sh" clean

    [ "$status" -eq 0 ]
    grep -qx 'del linux' "$FAKE_STATE/apk.log"
    grep -qx 'cache clean' "$FAKE_STATE/apk.log"
}

@test "dist.sh update upgrades the packages" {
    run "$REPO_ROOT/tools/dist.sh" update

    [ "$status" -eq 0 ]
    [ "$(cat "$FAKE_STATE/apk.log")" = $'update\nupgrade' ]
}

@test "dist.sh without an action prints its usage" {
    run "$REPO_ROOT/tools/dist.sh"

    [ "$status" -eq 2 ]
    [[ "$output" == *"Usage: dist.sh update|clean"* ]]
}

@test "wallet.configure.sh keeps an existing wallet" {
    run "$REPO_ROOT/tools/wallet.configure.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Wallet successfully configured"* ]]
}

@test "wallet.configure.sh fails when the wallet cannot be created" {
    rm "$PRIV_KEY_FILE" # the fake CLI does not create keys

    run "$REPO_ROOT/tools/wallet.configure.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Error creating new wallet"* ]]
}

@test "scripts sourced by others, or with an entry point, run nothing when sourced" {
    # Every sourced script and every script with a guarded entry point must
    # carry the guard, and sourcing it with no command on the PATH must print
    # nothing and fail nothing (definitions only).
    local guard scripts f offenders=""
    read -r guard << 'EOF'
[[ "${BASH_SOURCE[0]}" == "$0" ]]
EOF
    scripts=$(
        cd "$REPO_ROOT" || exit 1
        grep -ohE '^\s*source "[$](TOOLS_DIR|HELPER_DIR)/[^"]+"' tools/*.sh helper.docker.*.sh |
            sed -E 's/.*"[$]TOOLS_DIR\/([^"]+)"/tools\/\1/; s/.*"[$]HELPER_DIR\/([^"]+)"/\1/'
        grep -lF "$guard" tools/*.sh helper.docker.*.sh quick_test.sh .github/scripts/*.sh
    )
    mkdir -p "$BATS_TEST_TMPDIR/no-commands"
    for f in $(echo "$scripts" | sort -u); do
        grep -qF "$guard" "$REPO_ROOT/$f" || offenders+="$f: no guarded entry point"$'\n'
        run env -i PATH="$BATS_TEST_TMPDIR/no-commands" /bin/bash -c "source '$REPO_ROOT/$f'"
        [ "$status" -eq 0 ] && [ -z "$output" ] || offenders+="$f: $status $output"$'\n'
    done
    [ -n "$scripts" ] && [ -z "$offenders" ] || {
        echo "$offenders"
        false
    }
}

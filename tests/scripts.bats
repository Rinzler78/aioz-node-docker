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

# Every shell script of the repository. The extension-less test doubles in
# .github/scripts/tests/fakes stand in for external commands: they are run by
# PATH lookup only, never sourced, so the script rules do not apply to them.
# The exclusions are anchored on the root, given relative to it so that the
# root is never read as a pattern: the checkout itself may live under a
# .worktrees folder.
repository_scripts() {
    local root="${1:-$REPO_ROOT}" f
    (cd "$root" && find . \( -path ./.git -o -path ./.worktrees \) -prune -o -name '*.sh' -print) |
        sort | while IFS= read -r f; do echo "$root/${f#./}"; done
}

# Scripts under ROOT (default: the repository) without the guard, or that print
# or fail when sourced with no command on the PATH, one per line.
guard_offenders() {
    local root="${1:-$REPO_ROOT}" guard f out status
    read -r guard << 'EOF'
[[ "${BASH_SOURCE[0]}" == "$0" ]]
EOF
    mkdir -p "$BATS_TEST_TMPDIR/no-commands"
    # The list comes on fd 3 and the sourced script reads /dev/null: a script
    # reading its input cannot eat the names of the next ones.
    while IFS= read -r f <&3; do
        grep -qF "$guard" "$f" || echo "${f#"$root"/}: no guarded entry point"
        out=$(env -i PATH="$BATS_TEST_TMPDIR/no-commands" /bin/bash -c "source '$f'" 2>&1 < /dev/null)
        status=$?
        [ "$status" -eq 0 ] && [ -z "$out" ] || echo "${f#"$root"/}: $status $out"
    done 3< <(repository_scripts "$root")
}

@test "the script checks cover every script of a checkout, wherever it lives" {
    # A checkout inside a .worktrees folder, holding a nested worktree and a
    # script that reads its standard input before a faulty one.
    local co="$BATS_TEST_TMPDIR/x/.worktrees/co"
    mkdir -p "$co/tools" "$co/.worktrees/other" "$co/.git"
    cat > "$co/tools/a.sh" << 'EOF'
f() { :; }
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then f; fi
EOF
    cat > "$co/tools/b.sh" << 'EOF'
IFS= read -r line
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then :; fi
EOF
    printf '%s\n' 'echo BAD' > "$co/tools/c.sh"
    printf '%s\n' 'echo nested' > "$co/.worktrees/other/d.sh"
    printf '%s\n' 'echo git' > "$co/.git/e.sh"

    run repository_scripts "$co"
    [ "$output" = "$co/tools/a.sh"$'\n'"$co/tools/b.sh"$'\n'"$co/tools/c.sh" ]

    run guard_offenders "$co"
    [[ "$output" == *"tools/c.sh: no guarded entry point"* ]]
    [[ "$output" == *"tools/c.sh: 0 BAD"* ]]
    [[ "$output" != *"tools/a.sh"* ]]
}

# Lines of a script (on stdin) that may run a .sh file as its own process.
spawn_candidates() {
    sed -E 's/^\s*source "[^"]*"//
        s/(echo|printf) "([^"$]|[$][^(])*"//g
        s/"[$]TOOLS_DIR\/node\.health\.sh"//g
        s/docker exec [^;&|()]*//g' |
        grep -E '\.sh([^A-Za-z0-9_]|$)'
}

@test "spawn detection catches the forms of a spawn and allows the rest" {
    local spawns allowed
    spawns=$(
        cat << 'EOF'
./x.sh
bash x.sh
sh "$DIR"/x.sh
v=$(./x.sh)
echo "result: $(./x.sh)"
docker exec "$c" true; ./x.sh
docker exec "$c" true $(./x.sh)
timeout 5 "$TOOLS_DIR/node.health.sh" && ./x.sh
bash "$TOOLS_DIR/${s}.sh"
"$TOOLS_DIR/$f".sh
source "$TOOLS_DIR/a.sh"; ./x.sh
EOF
    )
    allowed=$(
        cat << 'EOF'
source "$TOOLS_DIR/deploy.sh"
    source "$TOOLS_DIR/deploy.sh"
echo "node.version.sh returned $version"
printf "see start.sh\n"
timeout "${HEALTH_TIMEOUT}s" "$TOOLS_DIR/node.health.sh"
v=$(docker exec "$c" /tools/node.version.sh)
EOF
    )
    [ "$(echo "$spawns" | spawn_candidates | wc -l)" -eq "$(echo "$spawns" | wc -l)" ]
    [ -z "$(echo "$allowed" | spawn_candidates)" ]
}

@test "no repository script runs another repository script" {
    # Allowed, and removed before the search: comments, source lines, message
    # text without a command substitution, the watchdog health check and the
    # scripts run inside the container by quick_test.sh (docker exec). Whatever
    # else is on the line is still searched; quoted or variable names
    # ("$TOOLS_DIR/x.sh", "$DIR/$name".sh) are caught.
    offenders=$(while IFS= read -r f; do
        grep -vE '^\s*#' "$f" | spawn_candidates | sed "s|^|${f##*/}: |"
    done < <(repository_scripts))
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

@test "every repository script has a guarded entry point and runs nothing when sourced" {
    # Every script must carry the guard, and sourcing it with no command on the
    # PATH must print nothing and fail nothing (definitions only).
    run guard_offenders

    [ "$status" -eq 0 ]
    [ -z "$output" ] || {
        echo "$output"
        false
    }
}

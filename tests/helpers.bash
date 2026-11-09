# Shared fixtures: a fake GitHub (file:// URLs) serving the real v1.2.6 release
# capture, and fake aioznode binaries that only answer `version`.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
RELEASE_CAPTURE="$BATS_TEST_DIRNAME/fixtures/release-latest-v1.2.6.json"

setup_env() {
    export PATH="$REPO_ROOT/tools:$PATH"
    export REPO_NAME="AIOZNetwork/aioz-depin-cli"
    export BINARY_NAME="aioznode"
    export BIN_DIR="$BATS_TEST_TMPDIR/bin"
    export FAKE_GITHUB="$BATS_TEST_TMPDIR/github"
    export GITHUB_API_URL="file://$FAKE_GITHUB/api"
    mkdir -p "$BIN_DIR"
}

# Write a fake CLI at $1 whose `version` prints $2 (may span several lines).
make_fake_cli() {
    cat > "$1" << 'EOF'
#!/bin/sh
[ "$1" = "version" ] && cat <<'VERSION'
EOF
    printf '%s\nVERSION\n' "$2" >> "$1"
    chmod +x "$1"
}

# Serve the real release capture, with github.com download URLs pointed at the
# fake GitHub, and the linux-amd64 archive containing a fake CLI of version $1.
serve_release() {
    local version="${1:-1.2.6}"
    local api_dir="$FAKE_GITHUB/api/repos/$REPO_NAME/releases"
    local dl_dir="$FAKE_GITHUB/AIOZNetwork/aioz-depin-cli/releases/download/v1.2.6"
    local pkg="$BATS_TEST_TMPDIR/pkg"
    mkdir -p "$api_dir" "$dl_dir" "$pkg"

    jq --arg base "file://$FAKE_GITHUB" \
        '.assets[].browser_download_url |= sub("^https://github.com"; $base)' \
        "$RELEASE_CAPTURE" > "$api_dir/latest"

    make_fake_cli "$pkg/aioz-depin-cli-linux-amd64" "$version"
    tar -czf "$dl_dir/aioz-depin-linux-amd64-1.2.6.tar.gz" -C "$pkg" aioz-depin-cli-linux-amd64
    (cd "$dl_dir" && sha256sum aioz-depin-linux-amd64-1.2.6.tar.gz > SHA256SUMS)
}

# Same release, but SHA256SUMS does not match the archive.
serve_release_with_bad_checksum() {
    serve_release "$@"
    local sums="$FAKE_GITHUB/AIOZNetwork/aioz-depin-cli/releases/download/v1.2.6/SHA256SUMS"
    echo "0000000000000000000000000000000000000000000000000000000000000000  aioz-depin-linux-amd64-1.2.6.tar.gz" > "$sums"
}

# Put a curl first on PATH that logs its arguments to $CURL_LOG, then runs curl.
spy_curl() {
    export CURL_LOG="$BATS_TEST_TMPDIR/curl.log"
    mkdir -p "$BATS_TEST_TMPDIR/spy"
    cat > "$BATS_TEST_TMPDIR/spy/curl" << 'EOF'
#!/bin/sh
echo "$*" >> "$CURL_LOG"
exec /usr/bin/curl "$@"
EOF
    chmod +x "$BATS_TEST_TMPDIR/spy/curl"
    export PATH="$BATS_TEST_TMPDIR/spy:$PATH"
}

# Same capture, but without the linux-amd64 archive.
serve_release_without_linux_asset() {
    serve_release
    local latest="$FAKE_GITHUB/api/repos/$REPO_NAME/releases/latest"
    jq 'del(.assets[] | select(.name | test("linux-amd64")))' "$latest" > "$latest.tmp"
    mv "$latest.tmp" "$latest"
}

# Environment for start.sh: node data folder with an existing wallet, fast
# health checks, and a fake node whose state lives in $FAKE_STATE.
setup_node_env() {
    setup_env
    export PATH="$BIN_DIR:$PATH"
    export NODEDATA_FOLDER="$BATS_TEST_TMPDIR/nodedata"
    export PRIV_KEY_FILE="$NODEDATA_FOLDER/privkey.json"
    export FAKE_STATE="$BATS_TEST_TMPDIR/state"
    export HEALTH_START_PERIOD=0
    export HEALTH_INTERVAL=1
    export HEALTH_RETRIES=3
    mkdir -p "$NODEDATA_FOLDER" "$FAKE_STATE"
    echo '{}' > "$PRIV_KEY_FILE"
    # Fake apk: offline, the runner is not touched; calls logged to apk.log.
    mkdir -p "$BATS_TEST_TMPDIR/stubs"
    cat > "$BATS_TEST_TMPDIR/stubs/apk" << 'EOF'
#!/bin/sh
echo "$*" >> "$FAKE_STATE/apk.log"
[ "$1" = "list" ] && echo "linux-lts-6.6.1-r0 x86_64 {linux-lts} (GPL-2.0-only) [installed]"
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/stubs/apk"
    export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
}

# Write a fake node at $1 (version $2): `start` records that it started and
# runs until killed; `reward` records its arguments, hangs while
# $FAKE_STATE/hang exists and fails while $FAKE_STATE/unhealthy exists.
make_fake_node() {
    cat > "$1" << EOF
#!/bin/sh
case "\$1" in
    version) echo "$2" ;;
    start) touch "\$FAKE_STATE/started"; exec sleep 1000 ;;
    reward)
        echo "\$*" > "\$FAKE_STATE/reward.args"
        [ -e "\$FAKE_STATE/hang" ] && exec sleep 1000
        [ ! -e "\$FAKE_STATE/unhealthy" ] && echo '{"balance":[]}' ;;
esac
EOF
    chmod +x "$1"
}

# Environment for the withdraw mode: a fake node answering `reward balance`
# with $FAKE_STATE/balance.json and recording `reward withdraw` arguments.
setup_withdraw_env() {
    setup_node_env
    export ENDPOINT="http://aioznode:1317"
    export NODEDATA_SEGMENT_FOLDER="$NODEDATA_FOLDER/data"
    export WITHDRAW_ADDRESS_HEX="0x1111111111111111111111111111111111111111"
    export WITHDRAW_MIN_VALUE="10^18"
    export TOKEN_NAME="aioz" TOKEN_DENOM="attoaioz" TOKEN_DECIMALS="10^18"
    mkdir -p "$NODEDATA_SEGMENT_FOLDER"
    cat > "$BIN_DIR/$BINARY_NAME" << 'EOF'
#!/bin/sh
case "$1 $2" in
    "reward balance") shift 2; echo "$*" > "$FAKE_STATE/balance.args"; cat "$FAKE_STATE/balance.json" ;;
    "reward withdraw") shift 2; echo "$*" > "$FAKE_STATE/withdraw.args" ;;
esac
EOF
    chmod +x "$BIN_DIR/$BINARY_NAME"
}

# Serve the reward balance example of the upstream README (v1.2.6), with the
# withdrawable balance replaced by $1 attoaioz.
serve_balance() {
    jq --arg amount "$1" '.balance[0].amount = $amount' \
        "$BATS_TEST_DIRNAME/fixtures/reward-balance-readme-v1.2.6.json" \
        > "$FAKE_STATE/balance.json"
}

installed_version() {
    "$BIN_DIR/$BINARY_NAME" version
}

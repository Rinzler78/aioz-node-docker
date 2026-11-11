# Shared fixtures: a fake GitHub (file:// URLs) serving the real v1.2.6 release
# capture, and fake aioznode binaries.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
RELEASE_CAPTURE="$BATS_TEST_DIRNAME/fixtures/release-latest-v1.2.6.json"

setup_env() {
    export PATH="$REPO_ROOT/tools:$PATH"
    export REPO_NAME="AIOZNetwork/aioz-depin-cli"
    export BINARY_NAME="aioznode"
    export BIN_DIR="$BATS_TEST_TMPDIR/bin"
    export FAKE_GITHUB="$BATS_TEST_TMPDIR/github"
    export GITHUB_API_URL="file://$FAKE_GITHUB/api"
    # The CLI extracts aioz-io under $HOME: a home of its own for each test.
    # NODE_IO is read by the test files; the scripts derive it from HOME.
    export HOME="$BATS_TEST_TMPDIR/home"
    export NODE_IO="$HOME/.cache/aioz-depin-cli/bin/aioz-io"
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
    serve_balance 1
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

# Fake CLI wrapper at $1 (version $2, embedding aioz-io version $3, default
# $2) with the v1.2.6 behavior measured on the real one: `version` extracts
# the embedded aioz-io to $HOME/.cache/aioz-depin-cli/bin only when it is
# missing (a stale copy is kept), `keytool new` saves a key, and `start` fails
# like upstream AIOZNetwork/aioz-depin-cli#10. Other commands fail.
make_fake_node() {
    local embedded="$BATS_TEST_TMPDIR/embedded/aioz-io-$2-${3:-$2}"
    make_fake_io "$embedded" "${3:-$2}"
    cat > "$1" << EOF
#!/bin/sh
io="\$HOME/.cache/aioz-depin-cli/bin/aioz-io"
case "\$1" in
    version)
        [ -e "\$io" ] || { mkdir -p "\${io%/*}" && cp "$embedded" "\$io"; }
        printf '{\n  "version": "v%s"\n}\n' "$2" ;;
    keytool) [ "\$2" = new ] && [ "\$3" = --save-priv-key ] && echo '{}' > "\$4" ;;
    start) echo "Error: unknown flag: --password" >&2; exit 1 ;;
    *) exit 1 ;;
esac
EOF
    chmod +x "$1"
}

# Fake aioz-io at $1 (version $2) with the v1.2.6 interface: `--endpoint` is a
# flag of `stats` only. `start` and `stats` record their arguments in
# $FAKE_STATE; `stats` hangs while $FAKE_STATE/hang exists (its pid in
# $FAKE_STATE/stats.pid) and fails while $FAKE_STATE/unhealthy exists; its
# output is the one captured from aioz-io v1.2.6; `reward balance` prints
# $FAKE_STATE/balance.json (fails without it, hangs while
# $FAKE_STATE/hang-balance exists, its pid in $FAKE_STATE/balance.pid); `reward withdraw` records its
# arguments and fails while $FAKE_STATE/withdraw.fail exists.
make_fake_io() {
    mkdir -p "${1%/*}"
    cat > "$1" << EOF
#!/bin/sh
for arg; do
    if [ "\$arg" = --endpoint ] && [ "\$1" != stats ]; then
        echo "Error: unknown flag: --endpoint" >&2
        exit 1
    fi
done
case "\$1" in
    version) echo "v$2" >&2 ;;
    start) echo "\$*" > "\$FAKE_STATE/start.args"; touch "\$FAKE_STATE/started"; exec sleep 1000 ;;
    stats)
        echo "\$*" > "\$FAKE_STATE/stats.args"
        if [ -e "\$FAKE_STATE/hang" ]; then echo \$\$ > "\$FAKE_STATE/stats.pid"; exec sleep 1000; fi
        [ -e "\$FAKE_STATE/unhealthy" ] && exit 1
        echo '{"storage":{"total_count":0,"total_size":0},"delivery":{"upstream_speed":0},"transcoding":{"status":"Standby"}}' ;;
    reward)
        case "\$2" in
            balance)
                shift 2
                echo "\$*" > "\$FAKE_STATE/balance.args"
                if [ -e "\$FAKE_STATE/hang-balance" ]; then echo \$\$ > "\$FAKE_STATE/balance.pid"; exec sleep 1000; fi
                cat "\$FAKE_STATE/balance.json" ;;
            withdraw) shift 2; echo "\$*" > "\$FAKE_STATE/withdraw.args"; [ ! -e "\$FAKE_STATE/withdraw.fail" ] ;;
            *) exit 1 ;;
        esac ;;
    *) exit 1 ;;
esac
EOF
    chmod +x "$1"
}

# Environment for the withdraw mode: an installed CLI whose aioz-io is already
# extracted (as in the image), answering `reward balance` with
# $FAKE_STATE/balance.json and recording `reward withdraw` arguments.
setup_withdraw_env() {
    setup_node_env
    export NODEDATA_SEGMENT_FOLDER="$NODEDATA_FOLDER/data"
    export WITHDRAW_ADDRESS_HEX="0x1111111111111111111111111111111111111111"
    export WITHDRAW_MIN_VALUE="10^18"
    export TOKEN_NAME="aioz" TOKEN_DENOM="attoaioz" TOKEN_DECIMALS="10^18"
    mkdir -p "$NODEDATA_SEGMENT_FOLDER"
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.2.6"
    "$REPO_ROOT/tools/node.io.sh" > /dev/null
}

# Serve the reward balance captured on a running node (aioz-io v1.2.6), with
# the withdrawable balance replaced by $1 attoaioz.
serve_balance() {
    jq --arg amount "$1" '.balance[0].amount = $amount' \
        "$BATS_TEST_DIRNAME/fixtures/reward-balance-nas-v1.2.6.json" \
        > "$FAKE_STATE/balance.json"
}

installed_version() {
    "$BIN_DIR/$BINARY_NAME" version
}

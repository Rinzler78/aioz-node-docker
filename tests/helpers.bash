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

# Write a fake CLI at $1 whose `version` prints $2.
make_fake_cli() {
    cat > "$1" <<EOF
#!/bin/sh
[ "\$1" = "version" ] && echo "$2"
EOF
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
}

# Same capture, but without the linux-amd64 archive.
serve_release_without_linux_asset() {
    serve_release
    local latest="$FAKE_GITHUB/api/repos/$REPO_NAME/releases/latest"
    jq 'del(.assets[] | select(.name | test("linux-amd64")))' "$latest" > "$latest.tmp"
    mv "$latest.tmp" "$latest"
}

installed_version() {
    "$BIN_DIR/$BINARY_NAME" version
}

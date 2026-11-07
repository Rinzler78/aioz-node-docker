#!/bin/bash
# Install or update the AIOZ DePIN CLI from the latest GitHub release of $REPO_NAME.
# Exit 0 when a binary is available afterwards (a failed update keeps the
# installed one, with a WARN), 1 when there is none.

BIN_DIR="${BIN_DIR:-/bin}"
TARGET="$BIN_DIR/$BINARY_NAME"

binary_version() {
    "$TARGET" version 2>&1 | sed 's/[^0-9.]//g'
}

update_failed() {
    if [ -x "$TARGET" ]; then
        echo "WARN: $1. Keeping installed $BINARY_NAME $(binary_version)" >&2
        exit 0
    fi
    echo "ERROR: $1. No $BINARY_NAME binary available" >&2
    exit 1
}

release=$(git.releases.latest.sh "$REPO_NAME") ||
    update_failed "Cannot fetch the latest release of $REPO_NAME"

remote_version=$(jq -r '.tag_name // empty' <<< "$release" | sed 's/[^0-9.]//g')
asset_url=$(jq -r '.assets[]?.browser_download_url
    | select(test("linux-amd64[^/]*\\.tar\\.gz$"))' <<< "$release" | head -1)

if [ -z "$remote_version" ] || [ -z "$asset_url" ]; then
    update_failed "Latest release of $REPO_NAME has no linux-amd64 archive"
fi

if [ -x "$TARGET" ] && [ "$(binary_version)" = "$remote_version" ]; then
    echo "$BINARY_NAME $remote_version is up to date"
    exit 0
fi

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

echo "Downloading $BINARY_NAME $remote_version from $asset_url ..."
curl -fsSL -o "$workdir/archive.tar.gz" "$asset_url" ||
    update_failed "Download of $asset_url failed"
tar -xzf "$workdir/archive.tar.gz" -C "$workdir" ||
    update_failed "Cannot extract $asset_url"

binary=$(find "$workdir" -type f -name '*linux-amd64' | head -1)
[ -n "$binary" ] || update_failed "No linux-amd64 binary in $asset_url"

mkdir -p "$BIN_DIR"
chmod +x "$binary"
mv "$binary" "$TARGET"
echo "$BINARY_NAME $(binary_version) installed"

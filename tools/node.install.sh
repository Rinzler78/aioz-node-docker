#!/bin/bash
# Install or update the AIOZ DePIN CLI from the latest GitHub release of $REPO_NAME.
# The archive is checked against the release SHA256SUMS before install.
# node_install returns 0 when a binary is available afterwards (a failed update
# keeps the installed one, with a WARN), 1 when there is none.
# Sourced by deploy.sh (node_install); runs standalone too (image build).
# Folder of this script, also when run by bare name (bash deploy.sh).
TOOLS_DIR="${BASH_SOURCE[0]%/*}"
[ "$TOOLS_DIR" != "${BASH_SOURCE[0]}" ] || TOOLS_DIR=.
# shellcheck source=tools/version.lib.sh
source "$TOOLS_DIR/version.lib.sh"
# shellcheck source=tools/git.releases.latest.sh
source "$TOOLS_DIR/git.releases.latest.sh"

node_target() {
    echo "${BIN_DIR:-/bin}/$BINARY_NAME"
}

binary_version() {
    "$(node_target)" version 2>&1 | version_of
}

# Report a failed update: 0 if an installed binary can still be used, else 1.
update_failed() {
    if [ -x "$(node_target)" ]; then
        echo "WARN: $1. Keeping installed $BINARY_NAME $(binary_version)" >&2
        return 0
    fi
    echo "ERROR: $1. No $BINARY_NAME binary available" >&2
    return 1
}

# Download, check and install the archive at $1 (sums at $2) into workdir $3.
install_archive() {
    local asset_url=$1 sums_url=$2 workdir=$3 archive binary
    archive="${asset_url##*/}"

    curl -fsSL -o "$workdir/$archive" "$asset_url" ||
        {
            update_failed "Download of $asset_url failed"
            return
        }
    curl -fsSL -o "$workdir/SHA256SUMS" "$sums_url" ||
        {
            update_failed "Download of $sums_url failed"
            return
        }

    # Only the archive's line: SHA256SUMS lists every platform.
    awk -v name="$archive" '$2 == name' "$workdir/SHA256SUMS" > "$workdir/archive.sum"
    if [ ! -s "$workdir/archive.sum" ] ||
        ! (cd "$workdir" && sha256sum -c archive.sum > /dev/null 2>&1); then
        update_failed "$archive does not match its SHA256SUMS checksum"
        return
    fi

    tar -xzf "$workdir/$archive" -C "$workdir" ||
        {
            update_failed "Cannot extract $asset_url"
            return
        }

    binary=$(find "$workdir" -type f -name '*linux-amd64' | head -1)
    [ -n "$binary" ] || {
        update_failed "No linux-amd64 binary in $asset_url"
        return
    }

    if ! { mkdir -p "${BIN_DIR:-/bin}" && chmod +x "$binary" && mv "$binary" "$(node_target)"; }; then
        update_failed "Cannot install $binary as $(node_target)"
        return
    fi
    echo "$BINARY_NAME $(binary_version) installed"
}

node_install() {
    local release remote_version asset_url sums_url workdir status
    release=$(github_latest_release "$REPO_NAME") ||
        {
            update_failed "Cannot fetch the latest release of $REPO_NAME"
            return
        }

    remote_version=$(jq -r '.tag_name // empty' <<< "$release" | version_of)
    asset_url=$(jq -r '.assets[]?.browser_download_url
        | select(test("linux-amd64[^/]*\\.tar\\.gz$"))' <<< "$release" | head -1)
    sums_url=$(jq -r '.assets[]? | select(.name == "SHA256SUMS") | .browser_download_url' <<< "$release")

    if [ -z "$remote_version" ] || [ -z "$asset_url" ]; then
        update_failed "Latest release of $REPO_NAME has no linux-amd64 archive"
        return
    fi
    [ -n "$sums_url" ] || {
        update_failed "Latest release of $REPO_NAME has no SHA256SUMS"
        return
    }

    if [ -x "$(node_target)" ] && [ "$(binary_version)" = "$remote_version" ]; then
        echo "$BINARY_NAME $remote_version is up to date"
        return 0
    fi

    echo "Downloading $BINARY_NAME $remote_version from $asset_url ..."
    workdir=$(mktemp -d)
    install_archive "$asset_url" "$sums_url" "$workdir"
    status=$?
    rm -rf "$workdir"
    return "$status"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    node_install
fi

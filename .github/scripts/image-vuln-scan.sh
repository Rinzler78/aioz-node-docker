#!/bin/bash
# Build the node image and fail on HIGH or CRITICAL vulnerabilities.
# The AIOZ CLI binaries are skipped: they come from upstream, are replaced at
# every container start, and their vulnerabilities cannot be fixed here.
# Usage: .github/scripts/image-vuln-scan.sh [image-tag]
# Folder of this script: the image is built from the repository root above it.
SCAN_DIR="${BASH_SOURCE[0]%/*}"
[ "$SCAN_DIR" != "${BASH_SOURCE[0]}" ] || SCAN_DIR=.

AIOZ_BINARIES=(--skip-files /bin/aioznode --skip-dirs /root/.cache/aioz-depin-cli)

image_vuln_scan() {
    local tag="${1:-aioznode:vuln-scan}"
    docker build --quiet --tag "$tag" "$SCAN_DIR/../.." > /dev/null || return 1
    trivy image --quiet --scanners vuln --severity HIGH,CRITICAL --exit-code 1 \
        "${AIOZ_BINARIES[@]}" "$tag"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    image_vuln_scan "$@"
fi

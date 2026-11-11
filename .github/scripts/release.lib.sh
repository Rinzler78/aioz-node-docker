#!/bin/bash
# Release helpers, sourced by the CI scripts (no extra process per call).

# latest_release <ls-remote --tags output>: the highest vX.Y.Z tag, compared
# as numbers (v1.7.12 after v1.7.9). Other tags (v7, v6-beta) never count.
latest_release() {
    awk '{ sub("^refs/tags/", "", $2) } $2 ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/ { print $2 }' <<< "$1" |
        sort -V | tail -n 1
}

# Run standalone: `release.lib.sh < ls-remote-output` prints the latest release.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    latest_release "$(cat)"
fi

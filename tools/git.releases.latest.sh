#!/bin/bash
# Print the JSON of the latest release of a GitHub repository (one API call).
# GITHUB_TOKEN, when set, raises the rate limit from 60 to 5000 calls per hour.
# GITHUB_API_URL overrides the API base (tests point it at a fake GitHub).
# Sourced for github_latest_release; standalone: git.releases.latest.sh <owner/repo>.

github_latest_release() {
    local auth=()
    if [ -n "$GITHUB_TOKEN" ]; then
        auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
    fi
    curl -fsSL "${auth[@]}" -H "Accept: application/vnd.github+json" \
        "${GITHUB_API_URL:-https://api.github.com}/repos/$1/releases/latest"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    github_latest_release "$1"
fi

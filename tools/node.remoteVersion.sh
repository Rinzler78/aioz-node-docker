#!/bin/bash
# Print the version of the latest release of $REPO_NAME (digits and dots only).
# Folder of this script, also when run by bare name (bash deploy.sh).
TOOLS_DIR="${BASH_SOURCE[0]%/*}"
[ "$TOOLS_DIR" != "${BASH_SOURCE[0]}" ] || TOOLS_DIR=.
# shellcheck source=tools/version.lib.sh
source "$TOOLS_DIR/version.lib.sh"
# shellcheck source=tools/git.releases.latest.sh
source "$TOOLS_DIR/git.releases.latest.sh"

github_latest_release "$REPO_NAME" | jq -r '.tag_name // empty' | version_of

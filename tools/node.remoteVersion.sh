#!/bin/bash
# Print the version of the latest release of $REPO_NAME (digits and dots only).
# shellcheck source=tools/version.lib.sh
source "${BASH_SOURCE[0]%/*}/version.lib.sh"
# shellcheck source=tools/git.releases.latest.sh
source "${BASH_SOURCE[0]%/*}/git.releases.latest.sh"

github_latest_release "$REPO_NAME" | jq -r '.tag_name // empty' | version_of

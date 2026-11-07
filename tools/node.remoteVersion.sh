#!/bin/bash
# Print the version of the latest release of $REPO_NAME (digits and dots only).
# shellcheck source=tools/version.lib.sh
source "${BASH_SOURCE[0]%/*}/version.lib.sh"

git.releases.latest.sh "$REPO_NAME" | jq -r '.tag_name // empty' | version_of

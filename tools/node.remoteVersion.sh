#!/bin/bash
# Print the version of the latest release of $REPO_NAME (digits and dots only).
git.releases.latest.sh "$REPO_NAME" | jq -r '.tag_name // empty' | sed 's/[^0-9.]//g'

#!/bin/bash
# Version helpers, sourced by the node scripts (no extra process per call).

# Print the first version number (digits and dots) found on stdin.
# The CLI prints plain text or JSON over several lines ({"version": "v1.2.6"}).
version_of() {
    grep -oE '[0-9]+(\.[0-9]+)+' | head -1
}

# Run standalone: `version.lib.sh < text` prints the version found in text.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    version_of
fi

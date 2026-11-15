#!/bin/bash
# Turn README.md into the Docker Hub overview of a release, on stdout. The
# overview allows basic Markdown only: relative links point to the release on
# GitHub, a Mermaid diagram becomes a link to the README there, and a GitHub
# alert (`> [!WARNING]`) becomes a bold label. Fails on an overview over 25000
# characters, the limit of Docker Hub, and prints nothing then.
# Usage: .github/scripts/hub-readme.sh <README.md> <owner/repo> <release tag>

HUB_OVERVIEW_LIMIT=25000

# hub_readme <README.md> <owner/repo> <release tag>
hub_readme() {
    local readme="$1" repo="$2" tag="$3" blob overview
    if [ $# -ne 3 ]; then
        echo "Usage: hub-readme.sh <README.md> <owner/repo> <release tag>" >&2
        return 1
    fi
    if [ ! -r "$readme" ]; then
        echo "ERROR: cannot read $readme" >&2
        return 1
    fi
    blob="https://github.com/$repo/blob/$tag"
    overview=$(awk -v readme="$blob/README.md" '
        /^```mermaid/ { diagram = 1; next }
        diagram && /^```/ {
            diagram = 0
            print "[The diagram of the containers](" readme "), on GitHub."
            next
        }
        diagram { next }
        { print }
    ' "$readme" | sed -E \
        -e "s#\]\(([^):\#/][^):]*)\)#](${blob//#/\\#}/\1)#g" \
        -e 's/^> \[!NOTE\]$/> **Note**/' \
        -e 's/^> \[!TIP\]$/> **Tip**/' \
        -e 's/^> \[!IMPORTANT\]$/> **Important**/' \
        -e 's/^> \[!WARNING\]$/> **Warning**/' \
        -e 's/^> \[!CAUTION\]$/> **Caution**/') || return 1
    if [ "${#overview}" -gt "$HUB_OVERVIEW_LIMIT" ]; then
        echo "ERROR: the overview has ${#overview} characters, over $HUB_OVERVIEW_LIMIT characters" >&2
        return 1
    fi
    printf '%s\n' "$overview"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    hub_readme "$@"
fi

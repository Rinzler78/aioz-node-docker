#!/bin/bash
# Turn README.md into the Docker Hub overview of a release, on stdout. The
# overview allows basic Markdown only: relative links point to the release on
# GitHub (an image to its file), a Mermaid diagram becomes a link to the
# README there, and a GitHub alert (`> [!WARNING]`) becomes a bold label.
# Fails, printing nothing, on an overview over 25000 bytes, the limit of Docker
# Hub, or on a Mermaid diagram never closed.
# Usage: .github/scripts/hub-readme.sh <README.md> <owner/repo> <release tag>

HUB_OVERVIEW_LIMIT=25000

# sed_replacement <text>: <text> with the specials of a sed replacement (\, &
# and the # delimiter) escaped, so that it is copied as is.
sed_replacement() {
    local text="${1//\\/\\\\}"
    text="${text//&/\\&}"
    printf '%s' "${text//#/\\#}"
}

# hub_readme <README.md> <owner/repo> <release tag>
hub_readme() {
    local readme="$1" repo="$2" tag="$3" blob raw overview bytes
    if [ $# -ne 3 ]; then
        echo "Usage: hub-readme.sh <README.md> <owner/repo> <release tag>" >&2
        return 1
    fi
    if [ ! -r "$readme" ]; then
        echo "ERROR: cannot read $readme" >&2
        return 1
    fi
    blob="https://github.com/$repo/blob/$tag"
    raw=$(sed_replacement "https://github.com/$repo/raw/$tag")
    overview=$(
        set -o pipefail
        awk -v readme="$blob/README.md" '
            /^```mermaid/ { diagram = 1; next }
            diagram && /^```/ {
                diagram = 0
                print "[The diagram of the containers](" readme "), on GitHub."
                next
            }
            diagram { next }
            { print }
            END {
                if (diagram) {
                    print "ERROR: Mermaid diagram not closed" > "/dev/stderr"
                    exit 1
                }
            }
        ' "$readme" | sed -E \
            -e "s#!\[([^]]*)\]\(([^):\#/][^):]*)\)#![\1]($raw/\2)#g" \
            -e "s#\]\(([^):\#/][^):]*)\)#]($(sed_replacement "$blob")/\1)#g" \
            -e 's/^> \[!NOTE\]$/> **Note**/' \
            -e 's/^> \[!TIP\]$/> **Tip**/' \
            -e 's/^> \[!IMPORTANT\]$/> **Important**/' \
            -e 's/^> \[!WARNING\]$/> **Warning**/' \
            -e 's/^> \[!CAUTION\]$/> **Caution**/'
    ) || return 1
    # Bytes, whatever the locale: the action truncates at 25000 bytes.
    bytes=$(printf '%s\n' "$overview" | wc -c | tr -d ' ')
    if [ "$bytes" -gt "$HUB_OVERVIEW_LIMIT" ]; then
        echo "ERROR: the overview has $bytes bytes, over $HUB_OVERVIEW_LIMIT bytes" >&2
        return 1
    fi
    printf '%s\n' "$overview"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    hub_readme "$@"
fi

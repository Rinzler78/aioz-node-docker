#!/usr/bin/env bats
# The deployment declarations of docker-compose.yml.

load helpers

# The sources of the /nodedata mounts of the services, one per line.
nodedata_sources() {
    sed -n 's/^ *- *\(.*\):\/nodedata\(:ro\)\{0,1\}$/\1/p' "$REPO_ROOT/docker-compose.yml"
}

# The named volumes declared at the top level, one per line.
declared_volumes() {
    awk '/^[^ #]/ { top = ($0 == "volumes:") } top && /^  [^ #]/ { sub(/^  /, ""); sub(/:.*/, ""); print }' \
        "$REPO_ROOT/docker-compose.yml"
}

@test "both services mount the node data from NODEDATA_PATH, by default a named volume" {
    local sources default
    sources=$(nodedata_sources)
    [ "$(printf '%s\n' "$sources" | wc -l)" -eq 2 ]
    [ "$(printf '%s\n' "$sources" | sort -u | wc -l)" -eq 1 ]

    local source prefix="\${NODEDATA_PATH:-"
    source=$(printf '%s\n' "$sources" | head -1)
    [[ "$source" == "$prefix"*"}" ]]
    default=${source#"$prefix"}
    default=${default%\}}
    [ -n "$default" ]
    # A host path (./, /, ~) only exists on one host; a volume exists on any Docker context.
    [[ "$default" != */* && "$default" != .* && "$default" != "~"* ]]

    declared_volumes | grep -qx "$default"
}

#!/usr/bin/env bats
# The deployment declarations of docker-compose.yml.

load helpers

# The sources of the /nodedata mounts of the services, one per line, in the
# short syntax, quoted or not. Limit: the long syntax (source:, target:) is not read.
nodedata_sources() {
    sed -n 's/^ *- *["'\'']\{0,1\}\(.*\):\/nodedata\(:ro\)\{0,1\}["'\'']\{0,1\}$/\1/p' \
        "$REPO_ROOT/docker-compose.yml"
}

# The name: of the top-level volume $1, the name Docker knows it by.
volume_name() {
    awk -v volume="  $1:" '/^[^ #]/ { top = ($0 == "volumes:") }
        top && $0 == volume { found = 1; next }
        found && /^    name:/ { sub(/^    name: */, ""); print; exit }
        found && /^  [^ ]/ { exit }' "$REPO_ROOT/docker-compose.yml"
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

@test "the node data volume has a fixed name, whatever the compose project" {
    # Without a name, Docker names it <project>_nodedata after the folder of
    # the clone: another clone would start an empty volume, so a new wallet.
    [ "$(volume_name nodedata)" = aioznode-data ]
}

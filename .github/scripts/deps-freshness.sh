#!/bin/bash
# Fail when a pinned dependency is not its latest release:
# - pre-commit hooks: `pre-commit autoupdate` runs on a copy of the config and
#   lists the hooks it would update; the config itself is never rewritten;
# - GitHub Actions pinned to a commit SHA, with "# owner/repo vX.Y.Z" on the
#   line above: the SHA must be the commit of that version, and that version
#   the highest vX.Y.Z tag of the action.
# Reports every problem, then exits 1. Network: git ls-remote, no token.
# Usage: .github/scripts/deps-freshness.sh [workflow...]
#        (default: .github/workflows/*.yml; config: $PRE_COMMIT_CONFIG)

PRE_COMMIT_CONFIG="${PRE_COMMIT_CONFIG:-.pre-commit-config.yaml}"
# A missing repository must fail, not wait for credentials.
export GIT_TERMINAL_PROMPT=0

# without_git_env <command...>: runs it without the GIT_ variables git gives
# its hooks. git commit sets GIT_INDEX_FILE (in a worktree, the absolute path
# of its index): the clones of autoupdate would check out into it. Same filter
# as pre-commit for its own clones (pre_commit.git.no_git_env).
without_git_env() {
    (
        for var in $(compgen -e); do
            case "$var" in
                GIT_CONFIG_KEY_* | GIT_CONFIG_VALUE_* | GIT_CONFIG_COUNT | \
                    GIT_EXEC_PATH | GIT_SSH | GIT_SSH_COMMAND | GIT_SSL_CAINFO | \
                    GIT_SSL_NO_VERIFY | GIT_HTTP_PROXY_AUTHMETHOD | \
                    GIT_ALLOW_PROTOCOL | GIT_ASKPASS | GIT_TERMINAL_PROMPT) ;;
                GIT_*) unset "$var" ;;
            esac
        done
        exec "$@"
    )
}

# Lists the hooks `pre-commit autoupdate` would update; 1 if any, or if it
# cannot check them.
check_hook_revs() {
    local copy out
    copy=$(mktemp) || return 1
    cp "$PRE_COMMIT_CONFIG" "$copy" || {
        rm -f "$copy"
        return 1
    }
    if ! out=$(without_git_env pre-commit autoupdate --config "$copy" --jobs 4 2>&1); then
        rm -f "$copy"
        echo "ERROR: pre-commit autoupdate cannot check the hooks:" >&2
        printf '%s\n' "$out" >&2
        return 1
    fi
    rm -f "$copy"
    out=$(grep ' updating ' <<< "$out")
    [ -z "$out" ] && return 0
    echo "ERROR: outdated pre-commit hooks (run pre-commit autoupdate):" >&2
    printf '%s\n' "$out" >&2
    return 1
}

# tag_commit <ls-remote output> <tag>: the commit of the tag; for an annotated
# tag, the commit it points to (^{} line), not the tag object.
tag_commit() {
    local peeled
    peeled=$(awk -v ref="refs/tags/$2^{}" '$2 == ref { print $1 }' <<< "$1")
    [ -n "$peeled" ] && echo "$peeled" && return
    awk -v ref="refs/tags/$2" '$2 == ref { print $1 }' <<< "$1"
}

# latest_release <ls-remote output>: the highest vX.Y.Z tag.
latest_release() {
    awk '{ sub("^refs/tags/", "", $2) } $2 ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/ { print $2 }' <<< "$1" |
        sort -V | tail -n 1
}

# check_action <file> <action> <sha> <comment line above>
check_action() {
    local version tags latest
    if [[ ! "$4" =~ ^[[:space:]]*#[[:space:]]*([^[:space:]]+)[[:space:]]+(v[^[:space:]]+)[[:space:]]*$ ]] ||
        [ "${BASH_REMATCH[1]}" != "$2" ]; then
        echo "ERROR: $1: $2@$3: no \"# $2 vX.Y.Z\" version comment on the line above" >&2
        return 1
    fi
    version="${BASH_REMATCH[2]}"
    if ! tags=$(git ls-remote --tags "https://github.com/$2" 2>&1); then
        echo "ERROR: $1: cannot read the tags of $2: $tags" >&2
        return 1
    fi
    if [ "$(tag_commit "$tags" "$version")" != "$3" ]; then
        echo "ERROR: $1: $2@$3 is not $version" >&2
        return 1
    fi
    latest=$(latest_release "$tags")
    if [ "$version" != "$latest" ]; then
        echo "ERROR: $1: $2 $version, latest $latest" >&2
        return 1
    fi
}

# Checks every action pinned to a commit SHA in the given workflows.
check_action_pins() {
    local file where line previous status=0
    local pin='^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*([^@[:space:]]+)@([0-9a-f]{40})([[:space:]]|$)'
    for file in "$@"; do
        previous="" where="$file"
        while IFS= read -r line || [ -n "$line" ]; do
            if [[ "$line" =~ $pin ]]; then
                check_action "$where" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "$previous" || status=1
            fi
            previous="$line"
        done < "$file"
    done
    return "$status"
}

deps_freshness() {
    local status=0
    [ $# -gt 0 ] || set -- .github/workflows/*.yml
    check_hook_revs || status=1
    check_action_pins "$@" || status=1
    return "$status"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    deps_freshness "$@"
fi

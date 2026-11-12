#!/bin/bash
# Fail when a pinned dependency is not its latest release:
# - pre-commit hooks: `pre-commit autoupdate` runs on a copy of the config and
#   lists the hooks it would update; the config itself is never rewritten;
# - GitHub Actions: each `uses:` (but local ./ and docker:// ones) must be
#   pinned to a commit SHA, with "# <action> vX.Y.Z" on the line above; the SHA
#   must be the commit of that version, and that version the highest vX.Y.Z
#   tag of the action's repository.
# Reports every problem, then exits 1. Network: git ls-remote, no token.
# Usage: .github/scripts/deps-freshness.sh [workflow...]
#        (default: .github/workflows/*.yml and *.yaml; config: $PRE_COMMIT_CONFIG)

# Folder of this script, also when run by bare name (bash deps-freshness.sh).
DEPS_FRESHNESS_DIR="${BASH_SOURCE[0]%/*}"
[ "$DEPS_FRESHNESS_DIR" != "${BASH_SOURCE[0]}" ] || DEPS_FRESHNESS_DIR=.
# shellcheck source=.github/scripts/release.lib.sh
source "$DEPS_FRESHNESS_DIR/release.lib.sh"

PRE_COMMIT_CONFIG="${PRE_COMMIT_CONFIG:-.pre-commit-config.yaml}"
# A missing repository must fail, not wait for credentials.
export GIT_TERMINAL_PROMPT=0

# without_git_env <command...>: runs it without the GIT_ variables git gives
# its hooks. git commit sets GIT_INDEX_FILE (in a worktree, the absolute path
# of its index): the clones of autoupdate would check out into it. Same filter
# as pre-commit for its own clones (pre_commit.git.no_git_env), but
# GIT_TERMINAL_PROMPT is kept, so a missing repository still fails at once.
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
# cannot check them. Runs in a subshell, whose exit removes the copy.
check_hook_revs() (
    copy=$(mktemp) || exit 1
    trap 'rm -f "$copy"' EXIT
    cp "$PRE_COMMIT_CONFIG" "$copy" || exit 1
    if ! out=$(without_git_env pre-commit autoupdate --config "$copy" --jobs 4 2>&1); then
        echo "ERROR: pre-commit autoupdate cannot check the hooks:" >&2
        printf '%s\n' "$out" >&2
        exit 1
    fi
    out=$(grep ' updating ' <<< "$out")
    [ -z "$out" ] && exit 0
    echo "ERROR: outdated pre-commit hooks (run pre-commit autoupdate):" >&2
    printf '%s\n' "$out" >&2
    exit 1
)

# tag_commit <ls-remote output> <tag>: the commit of the tag; for an annotated
# tag, the commit it points to (^{} line), not the tag object.
tag_commit() {
    local peeled
    peeled=$(awk -v ref="refs/tags/$2^{}" '$2 == ref { print $1 }' <<< "$1")
    [ -n "$peeled" ] && echo "$peeled" && return
    awk -v ref="refs/tags/$2" '$2 == ref { print $1 }' <<< "$1"
}

# check_action <file> <action> <repository> <sha> <comment line above>
# An action in a folder of its repository (owner/repo/path) has the tags of
# that repository.
check_action() {
    local version tags latest
    if [[ ! "$5" =~ ^[[:space:]]*#[[:space:]]*([^[:space:]]+)[[:space:]]+(v[^[:space:]]+)[[:space:]]*$ ]] ||
        [ "${BASH_REMATCH[1]}" != "$2" ]; then
        echo "ERROR: $1: $2@$4: no \"# $2 vX.Y.Z\" version comment on the line above" >&2
        return 1
    fi
    version="${BASH_REMATCH[2]}"
    if ! tags=$(git ls-remote --tags "https://github.com/$3" 2>&1); then
        echo "ERROR: $1: cannot read the tags of $3: $tags" >&2
        return 1
    fi
    if [ "$(tag_commit "$tags" "$version")" != "$4" ]; then
        echo "ERROR: $1: $2@$4 is not $version" >&2
        return 1
    fi
    latest=$(latest_release "$tags")
    if [ -z "$latest" ]; then
        echo "ERROR: $1: $2 $version, no vX.Y.Z release tag in $3" >&2
        return 1
    fi
    if [ "$version" != "$latest" ]; then
        echo "ERROR: $1: $2 $version, latest $latest" >&2
        return 1
    fi
}

# Checks every `uses:` of the given workflows: quoted or not, it must be
# owner/repo[/path]@<sha>, but for local (./) and Docker (docker://) actions.
# Reads lines, not YAML: any other line with a `uses` key (in a flow mapping
# after `{` or `,`, quoted, with a space before the colon, or with no value)
# fails, so that no step is skipped silently. Text that looks like such a key
# fails too; other text ("causes:", a name, a run: line) is left alone.
check_action_pins() {
    local file where line previous ref status=0
    local uses='^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*["'"'"']?([^"'"'"'[:space:]]+)["'"'"']?([[:space:]]|$)'
    local pin='^([^@/]+/[^@/]+)(/[^@]+)?@([0-9a-f]{40})$'
    local key='(^[[:space:]]*-?|[{,])[[:space:]]*["'"'"']?uses["'"'"']?[[:space:]]*:'
    for file in "$@"; do
        if [ ! -r "$file" ]; then
            echo "ERROR: cannot read $file" >&2
            status=1
            continue
        fi
        previous="" where="$file"
        while IFS= read -r line || [ -n "$line" ]; do
            if [[ "$line" =~ $uses ]]; then
                ref="${BASH_REMATCH[1]}"
                case "$ref" in
                    ./* | docker://*) ;;
                    *)
                        if [[ "$ref" =~ $pin ]]; then
                            check_action "$where" "${BASH_REMATCH[1]}${BASH_REMATCH[2]}" \
                                "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}" "$previous" || status=1
                        else
                            echo "ERROR: $where: $ref is not pinned to a commit SHA (owner/repo@<40 hex>)" >&2
                            status=1
                        fi
                        ;;
                esac
            elif [[ "$line" =~ $key && ! "$line" =~ ^[[:space:]]*# ]]; then
                echo "ERROR: $where: cannot check: ${line#"${line%%[![:space:]]*}"} (write \`- uses: owner/repo@<sha>\` on its own line)" >&2
                status=1
            fi
            previous="$line"
        done < "$file"
    done
    return "$status"
}

deps_freshness() {
    local status=0 nullglob
    if [ $# -eq 0 ]; then
        nullglob=$(shopt -p nullglob)
        shopt -s nullglob
        set -- .github/workflows/*.yml .github/workflows/*.yaml
        eval "$nullglob"
        if [ $# -eq 0 ]; then
            echo "ERROR: no workflow in .github/workflows" >&2
            status=1
        fi
    fi
    check_hook_revs || status=1
    check_action_pins "$@" || status=1
    return "$status"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    deps_freshness "$@"
fi

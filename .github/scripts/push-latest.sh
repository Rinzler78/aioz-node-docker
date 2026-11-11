#!/bin/bash
# Move <image>:latest to <image>:<tag> and push it, only when <tag> is the
# highest vX.Y.Z release of $GITHUB_REPOSITORY. The tags are read at push
# time, so a fix tag on an older line leaves latest alone, and so does an
# older tag whose build ends last, unless it read the tags before the newer
# tag existed (a window of seconds, against minutes of build). Watchtower
# follows latest, it must never go back. Fails when the tags cannot be
# read, and pushes nothing then.
# Usage: GITHUB_REPOSITORY=owner/repo .github/scripts/push-latest.sh <image> <tag>
# Folder of this script, also when run by bare name (bash push-latest.sh).
PUSH_LATEST_DIR="${BASH_SOURCE[0]%/*}"
[ "$PUSH_LATEST_DIR" != "${BASH_SOURCE[0]}" ] || PUSH_LATEST_DIR=.
# shellcheck source=.github/scripts/release.lib.sh
source "$PUSH_LATEST_DIR/release.lib.sh"

push_latest() {
    local image="$1" tag="$2" tags latest
    if [ $# -ne 2 ]; then
        echo "Usage: push-latest.sh <image> <tag>" >&2
        return 1
    fi
    if [ -z "${GITHUB_REPOSITORY:-}" ]; then
        echo "ERROR: GITHUB_REPOSITORY (owner/repo) is not set" >&2
        return 1
    fi
    if ! tags=$(GIT_TERMINAL_PROMPT=0 git ls-remote --tags "https://github.com/$GITHUB_REPOSITORY" 2>&1); then
        echo "ERROR: cannot read the tags of $GITHUB_REPOSITORY: $tags" >&2
        return 1
    fi
    # The tag that runs this build is pushed: missing, the list is stale.
    if ! awk -v ref="refs/tags/$tag" '$2 == ref { found = 1 } END { exit !found }' <<< "$tags"; then
        echo "ERROR: $tag is not a tag of $GITHUB_REPOSITORY" >&2
        return 1
    fi
    latest=$(latest_release "$tags")
    if [ "$tag" != "$latest" ]; then
        echo "$tag is not the highest release ($latest): latest unchanged"
        return 0
    fi
    docker tag "$image:$tag" "$image:latest" && docker push "$image:latest"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    push_latest "$@"
fi

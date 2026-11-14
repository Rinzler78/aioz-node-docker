#!/usr/bin/env bats
# The documentation covers the repository: docs/architecture.md names every
# shell script, workflow and Dockerfile, so a new one cannot stay off the map.

load helpers

# The files the architecture page must name, one per line, listed from the
# file system (never from the page): every shell script, workflow and
# Dockerfile at any depth, plus the compose file and the Makefile. Left out:
# git, the worktrees and the node data folder, which are not the repository.
architecture_files() {
    (cd "$REPO_ROOT" && find . \( -path ./.git -o -path ./.worktrees \
        -o -path ./nodedata \) -prune -o -type f \( -name '*.sh' \
        -o -path './.github/workflows/*.y*ml' -o -name 'Dockerfile*' \) -print |
        sed 's#^\./##' && printf '%s\n' docker-compose.yml Makefile) | sort
}

@test "docs/architecture.md names every shell script, workflow and Dockerfile" {
    local page="$REPO_ROOT/docs/architecture.md" file files missing=""
    [ -f "$page" ]
    files=$(architecture_files)
    # Each folder is listed: an empty glob would check nothing.
    for file in tools/start.sh nas/delivery-watch.sh scripts/quick_test.sh \
        .github/scripts/push-latest.sh .github/workflows/tests.yml \
        tests/run.sh tests/Dockerfile Makefile; do
        grep -qxF "$file" <<< "$files"
    done
    # Named as a code span, with its full path.
    for file in $files; do
        grep -qF "\`$file\`" "$page" || missing+="$file"$'\n'
    done
    [ -z "$missing" ] || {
        printf 'not in docs/architecture.md:\n%s' "$missing"
        false
    }
}

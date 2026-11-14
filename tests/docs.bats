#!/usr/bin/env bats
# The documentation covers the repository: docs/architecture.md names every
# script, workflow and build file, so a new one cannot stay off the map.

load helpers

# The files the architecture page must name, one per line, listed from the
# file system (never from the page): the scripts of the image, the NAS, the
# local helpers and CI, the workflows, and the build and run files.
architecture_files() {
    (cd "$REPO_ROOT" && compgen -G 'tools/*.sh' && compgen -G 'nas/*.sh' &&
        compgen -G 'scripts/*.sh' && compgen -G '.github/scripts/*.sh' &&
        compgen -G '.github/workflows/*.yml' &&
        printf '%s\n' Dockerfile docker-compose.yml Makefile)
}

@test "docs/architecture.md names every script, workflow and build file" {
    local page="$REPO_ROOT/docs/architecture.md" file files missing=""
    [ -f "$page" ]
    files=$(architecture_files)
    # Each folder is listed: an empty glob would check nothing.
    for file in tools/start.sh nas/delivery-watch.sh scripts/quick_test.sh \
        .github/scripts/push-latest.sh .github/workflows/tests.yml; do
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

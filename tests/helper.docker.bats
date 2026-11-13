#!/usr/bin/env bats
# The local helpers remove Docker objects: they must only touch this project's
# container and images, never the other images of the Docker host.

load helpers

PROJECT_LABEL=org.opencontainers.image.source=https://github.com/Rinzler78/aioz-node-docker

setup() {
    local bin="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$bin"
    export DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
    cat > "$bin/docker" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$DOCKER_LOG"
EOF
    chmod +x "$bin/docker"
    export PATH="$bin:$PATH"
    # A fake missing from the PATH would run the real docker.
    [ "$(command -v docker)" = "$bin/docker" ]
}

@test "clean removes the project container, image and unused project images only" {
    run bash "$REPO_ROOT/scripts/helper.docker.clean.sh"
    [ "$status" -eq 0 ]

    [ "$(cat "$DOCKER_LOG")" = "rm --force aioznode
rmi --force aioznode
image prune --all --force --filter label=$PROJECT_LABEL" ]
}

@test "start stops, cleans the project images only, rebuilds and runs" {
    run bash "$REPO_ROOT/scripts/helper.docker.start.sh" -v /data:/nodedata
    [ "$status" -eq 0 ]

    [ "$(cat "$DOCKER_LOG")" = "stop aioznode
rm --force aioznode
rmi --force aioznode
image prune --all --force --filter label=$PROJECT_LABEL
build -t aioznode $REPO_ROOT
stop aioznode
run -p 1317:1317/tcp -P -v /data:/nodedata --restart=always --name aioznode -it aioznode" ]
}

# Dockerfiles of the repository, by any of their usual names.
dockerfiles() {
    (cd "$REPO_ROOT" && find . \( -path ./.git -o -path ./.worktrees \) -prune -o \
        -type f \( -name 'Dockerfile*' -o -name '*.Dockerfile' -o -name Containerfile \) \
        -not -name '*.dockerignore' -print)
}

@test "every Dockerfile labels its image as part of the project" {
    run dockerfiles
    [ "$status" -eq 0 ]
    [[ $'\n'"$output"$'\n' == *$'\n./Dockerfile\n'* ]]

    local dockerfile
    for dockerfile in "${lines[@]}"; do
        grep -Fxq "LABEL $PROJECT_LABEL" "$REPO_ROOT/$dockerfile"
    done
}

@test "quick_test builds the image from the repository root" {
    source "$REPO_ROOT/scripts/quick_test.sh"
    run quick_test_build aioznode:quicktest
    [ "$status" -eq 0 ]

    [ "$(cat "$DOCKER_LOG")" = "build $REPO_ROOT --tag aioznode:quicktest" ]
}

# Lines of the repository shell scripts that prune Docker objects without the
# project label filter of scripts/helper.docker.lib.sh (its value is checked above).
# Limits: one line is one command; a prune split over continuation lines, or
# two commands on one line, are not seen.
unscoped_prunes() {
    (cd "$REPO_ROOT" && find . \( -path ./.git -o -path ./.worktrees \) -prune -o -type f -name '*.sh' -print) |
        while read -r script; do
            grep -nHE '(image|container|volume|network|builder|buildx|system) prune' "$REPO_ROOT/$script" |
                grep -vF -- "--filter \"label=\$(docker_project_label)\"" || true
        done
}

@test "no script prunes Docker objects outside the project" {
    run unscoped_prunes
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

#!/bin/bash
# Build the local image. Usage: helper.docker.build.sh
# Folder of this script, also when run by bare name (bash helper.docker.x.sh).
HELPER_DIR="${BASH_SOURCE[0]%/*}"
[ "$HELPER_DIR" != "${BASH_SOURCE[0]}" ] || HELPER_DIR=.
# shellcheck source=scripts/helper.docker.lib.sh
source "$HELPER_DIR/helper.docker.lib.sh"

docker_build() {
    local name context
    name=$(docker_name)
    context=$(docker_context) || return
    echo "docker build -t $name $context"
    docker build -t "$name" "$context"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then docker_build; fi

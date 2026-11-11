#!/bin/bash
# Build the local image. Usage: helper.docker.build.sh
# Folder of this script, also when run by bare name (bash helper.docker.x.sh).
HELPER_DIR="${BASH_SOURCE[0]%/*}"
[ "$HELPER_DIR" != "${BASH_SOURCE[0]}" ] || HELPER_DIR=.
# shellcheck source=helper.docker.lib.sh
source "$HELPER_DIR/helper.docker.lib.sh"

docker_build() {
    local name
    name=$(docker_name)
    echo "docker build -t $name $HELPER_DIR"
    docker build -t "$name" "$HELPER_DIR"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then docker_build; fi

#!/bin/bash
# Remove the local container and image, then prune images. Usage: helper.docker.clean.sh
# Folder of this script, also when run by bare name (bash helper.docker.x.sh).
HELPER_DIR="${BASH_SOURCE[0]%/*}"
[ "$HELPER_DIR" != "${BASH_SOURCE[0]}" ] || HELPER_DIR=.
# shellcheck source=helper.docker.lib.sh
source "$HELPER_DIR/helper.docker.lib.sh"

docker_clean() {
    local name
    name=$(docker_name)
    echo "Remove docker containers : $name"
    docker rm --force "$name"

    echo "Remove docker image : $name"
    docker rmi --force "$name"

    echo "Clean images"
    docker image prune -f
    docker image prune -a -f
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then docker_clean; fi

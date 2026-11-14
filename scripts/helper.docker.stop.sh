#!/bin/bash
# Stop the local container. Usage: helper.docker.stop.sh
# Folder of this script, also when run by bare name (bash helper.docker.x.sh).
HELPER_DIR="${BASH_SOURCE[0]%/*}"
[ "$HELPER_DIR" != "${BASH_SOURCE[0]}" ] || HELPER_DIR=.
# shellcheck source=scripts/helper.docker.lib.sh
source "$HELPER_DIR/helper.docker.lib.sh"

docker_stop() {
    local name
    name=$(docker_name)
    echo "Stopping : docker stop $name"
    docker stop "$name"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then docker_stop; fi

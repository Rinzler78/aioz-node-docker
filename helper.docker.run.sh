#!/bin/bash
# Stop, then run the local container. Usage: helper.docker.run.sh [docker run args...]
# Folder of this script, also when run by bare name (bash helper.docker.x.sh).
HELPER_DIR="${BASH_SOURCE[0]%/*}"
[ "$HELPER_DIR" != "${BASH_SOURCE[0]}" ] || HELPER_DIR=.
# shellcheck source=helper.docker.stop.sh
source "$HELPER_DIR/helper.docker.stop.sh"

docker_run() {
    local name
    name=$(docker_name)
    docker_stop
    local args=(-p 1317:1317/tcp -P "$@" --restart=always --name "$name" -it "$name")
    echo "Launching : docker run ${args[*]}"
    docker run "${args[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then docker_run "$@"; fi

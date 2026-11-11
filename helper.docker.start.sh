#!/bin/bash
# Stop, clean, rebuild, then run the local container. Usage: helper.docker.start.sh [docker run args...]
# Folder of this script, also when run by bare name (bash helper.docker.x.sh).
HELPER_DIR="${BASH_SOURCE[0]%/*}"
[ "$HELPER_DIR" != "${BASH_SOURCE[0]}" ] || HELPER_DIR=.
# shellcheck source=helper.docker.clean.sh
source "$HELPER_DIR/helper.docker.clean.sh"
# shellcheck source=helper.docker.build.sh
source "$HELPER_DIR/helper.docker.build.sh"
# shellcheck source=helper.docker.run.sh
source "$HELPER_DIR/helper.docker.run.sh"

docker_start() {
    docker_stop
    docker_clean
    docker_build
    docker_run "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then docker_start "$@"; fi

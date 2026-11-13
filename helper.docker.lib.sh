#!/bin/bash
# Shared by the helper.docker.*.sh scripts: name of the local image and container,
# and the label that every image of the project carries (see the Dockerfiles).
# Folder of this script, also when run by bare name (bash helper.docker.x.sh).
HELPER_DIR="${BASH_SOURCE[0]%/*}"
[ "$HELPER_DIR" != "${BASH_SOURCE[0]}" ] || HELPER_DIR=.

docker_name() {
    cat "$HELPER_DIR/helper.docker.name.txt"
}

docker_project_label() {
    echo "org.opencontainers.image.source=https://github.com/Rinzler78/aioz-node-docker"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then docker_name; fi

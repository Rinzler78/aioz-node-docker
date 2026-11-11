#!/bin/bash
# Build the image, run it and check that it becomes healthy with the latest
# CLI release. Usage: quick_test.sh --help
# Folder of this script: the image is built from it, wherever it is run from.
QUICK_TEST_DIR="${BASH_SOURCE[0]%/*}"
[ "$QUICK_TEST_DIR" != "${BASH_SOURCE[0]}" ] || QUICK_TEST_DIR=.

# --------------------
# Globals & Defaults
# --------------------
DEFAULT_IMAGE_NAME="aioznode:latest"
DEFAULT_TIMEOUT=600 # room for the 300s HEALTHCHECK start period
DEFAULT_PORTS="1317:1317"

# Parameters (can be overridden by CLI)
image_name="" # Will be determined by logic below
image_name_from_flag=""
image_name_from_positional=""
run_timeout=$DEFAULT_TIMEOUT
ports="$DEFAULT_PORTS"
show_help=""

container_id=""

# --------------------
# Helper: Print usage
# --------------------
print_help() {
    echo "Usage: ${BASH_SOURCE[0]##*/} [--image_name IMAGE_NAME] [POSITIONAL_IMAGE_NAME] [--timeout SECONDS] [--ports \"host:cont ...\"]"
    printf '\nOptions:\n'
    echo "  --image_name Docker image name (default: $DEFAULT_IMAGE_NAME)"
    echo "  [POSITIONAL_IMAGE_NAME] Positional argument for Docker image name (overridden by --image_name if both are present)"
    echo "  --timeout   Timeout in seconds (default: $DEFAULT_TIMEOUT)"
    echo "  --ports     Ports mapping (default: '$DEFAULT_PORTS')"
    echo "  --help      Show this help message"
}

# --------------------
# Parse CLI arguments into image_name, run_timeout, ports and show_help;
# returns 1 on an unknown option.
# --------------------
parse_args() {
    # Check for positional image name argument first
    if [[ $# -gt 0 ]] && ! [[ "$1" =~ ^-- ]]; then
        image_name_from_positional="$1"
        shift # Consume the positional argument so it's not processed by the option loop
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --image_name)
                image_name_from_flag="$2"
                shift 2
                ;;
            --timeout)
                run_timeout="$2"
                shift 2
                ;;
            --ports)
                ports="$2"
                shift 2
                ;;
            --help)
                show_help=1
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                print_help
                return 1
                ;;
        esac
    done

    # Determine the final image_name based on priority:
    # 1. --image_name flag
    # 2. Positional argument
    # 3. Default image name
    if [ -n "$image_name_from_flag" ]; then
        image_name="$image_name_from_flag"
    elif [ -n "$image_name_from_positional" ]; then
        image_name="$image_name_from_positional"
    else
        image_name="$DEFAULT_IMAGE_NAME"
    fi
}

# --------------------
# Trap for cleanup
# --------------------
quick_test_delete() {
    if [ -n "$container_id" ]; then
        docker rm -f "$container_id" > /dev/null 2>&1
        echo "Container $container_id deleted."
    fi
}

# --------------------
# Function: Build Docker image
# --------------------
quick_test_build() {
    echo "[INFO] Building Docker image '$1'..."
    if ! docker build "$QUICK_TEST_DIR" --tag "$1"; then
        echo "[ERROR] Docker build failed."
        return 10
    fi
    return 0
}

# --------------------
# Function: Run Docker container
# --------------------
quick_test_run() {
    local image_name="$1"
    local ports_list="$2"
    local run_timeout="$3"
    local ports_mapping=() mapping
    for mapping in $ports_list; do
        ports_mapping+=(-p "$mapping")
    done
    echo "[INFO] Running Docker container..."
    echo "docker run \\
      --env RUN_TIMEOUT=$run_timeout \\
      ${ports_mapping[*]} \\
      -d $image_name"
    container_id=$(docker run \
        --env RUN_TIMEOUT="$run_timeout" \
        ${GITHUB_TOKEN:+--env GITHUB_TOKEN} \
        "${ports_mapping[@]}" \
        -d "$image_name")
    if [ -z "$container_id" ]; then
        echo "[ERROR] Docker run failed: container not started."
        return 11
    fi
    echo "[INFO] Container started: $container_id"
    return 0
}

# --------------------
# Main logic
# --------------------
quick_test() {
    parse_args "$@" || return 1
    if [ -n "$show_help" ]; then
        print_help
        return 0
    fi

    if ! command -v docker &> /dev/null; then
        echo "docker is required but not installed. Aborting."
        return 2
    fi

    trap quick_test_delete EXIT

    if ! quick_test_build "$image_name"; then
        echo "[FAIL] Docker build failed."
        return 10
    fi

    if ! quick_test_run "$image_name" "$ports" "$run_timeout"; then
        echo "[FAIL] Docker run failed."
        return 11
    fi

    # Wait for container healthcheck to report 'healthy'
    echo "[INFO] Waiting for container to become healthy..."
    for _ in $(seq 1 "$run_timeout"); do
        if ! health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2> /dev/null); then
            echo "[FAIL] Container is gone."
            return 13
        fi
        if [ "$(docker inspect --format='{{.State.Running}}' "$container_id")" != "true" ]; then
            echo "[FAIL] Container exited before becoming healthy."
            docker logs "$container_id" 2>&1 | tail -30
            return 12
        fi
        echo "[INFO] Health status: $health_status"
        if [ "$health_status" = "healthy" ]; then
            echo "[SUCCESS] Container is healthy."
            break
        elif [ "$health_status" = "unhealthy" ]; then
            echo "[FAIL] Container is unhealthy."
            return 14
        fi
        sleep 1
    done
    if [ "$health_status" != "healthy" ]; then
        echo "[FAIL] Container not healthy after ${run_timeout}s (last status: ${health_status:-none})."
        docker logs "$container_id" 2>&1 | tail -30
        return 15
    fi

    # Test version (locale)
    version=$(docker exec "$container_id" /tools/node.version.sh)
    if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "[SUCCESS] node.version.sh returned a valid version: $version"
    else
        echo "[FAIL] node.version.sh did not return a valid version: $version"
        return 16
    fi

    # Test update logic (compare local/remote)
    echo "[INFO] Testing update logic..."
    remote_version=$(docker exec "$container_id" /tools/node.remoteVersion.sh)
    echo "[INFO] Local version: $version"
    echo "[INFO] Remote version: $remote_version"
    if [ "$version" = "$remote_version" ]; then
        echo "[SUCCESS] Local and remote versions match."
    else
        echo "[FAIL] Installed version $version is not the latest release $remote_version."
        return 17
    fi

    echo "[INFO] Stopping container..."
    docker stop "$container_id"
    echo "[SUCCESS] All tests passed."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    quick_test "$@"
fi

#!/bin/bash

# --------------------
# Globals & Defaults
# --------------------
DEFAULT_IMAGE_NAME="aioznode:latest"
DEFAULT_USER="aiozClient"
DEFAULT_PASS="aiozClientPassword"
DEFAULT_TIMEOUT=120
DEFAULT_PORTS="1317:1317"

# Parameters (can be overridden by CLI)
image_name="" # Will be determined by logic below
image_name_from_flag=""
image_name_from_positional=""
run_timeout=$DEFAULT_TIMEOUT
ports="$DEFAULT_PORTS"

container_id=""

# Check for positional image name argument first
if [[ $# -gt 0 ]] && ! [[ "$1" =~ ^-- ]]; then
    image_name_from_positional="$1"
    shift # Consume the positional argument so it's not processed by the option loop
fi

# --------------------
# Helper: Print usage
# --------------------
print_help() {
    echo "Usage: $0 [--image_name IMAGE_NAME] [POSITIONAL_IMAGE_NAME] [--timeout SECONDS] [--ports \"host:cont ...\"]"
    echo "\nOptions:"
    echo "  --image_name Docker image name (default: $DEFAULT_IMAGE_NAME)"
    echo "  [POSITIONAL_IMAGE_NAME] Positional argument for Docker image name (overridden by --image_name if both are present)"
    echo "  --timeout   Timeout in seconds (default: $DEFAULT_TIMEOUT)"
    echo "  --ports     Ports mapping (default: '$DEFAULT_PORTS')"
    echo "  --help      Show this help message"
}

# --------------------
# Parse CLI arguments
# --------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        --image_name)
            image_name_from_flag="$2"; shift 2;;
        --timeout)
            run_timeout="$2"; shift 2;;
        --ports)
            ports="$2"; shift 2;;
        --help)
            print_help; exit 0;;
        *)
            echo "Unknown option: $1"; print_help; exit 1;;
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

# Ensure image_name is set
if [ -z "$image_name" ]; then
    echo "[ERROR] Image name could not be determined. Please specify an image or ensure a default is set." >&2
    print_help >&2 # Show help on error
    exit 1
fi

# --------------------
# Dependency check
# --------------------
for dep in docker; do
    if ! command -v $dep &>/dev/null; then
        echo "$dep is required but not installed. Aborting."
        exit 2
    fi
done

# --------------------
# Trap for cleanup
# --------------------
docker_delete() {
    if [ ! -z "$container_id" ]; then
        docker rm -f $container_id >/dev/null 2>&1
        echo "Container $container_id deleted."
    fi
}
trap docker_delete EXIT

# --------------------
# Function: Build Docker image
# --------------------
docker_build() {
    echo "[INFO] Building Docker image '$1'..."
    docker build . --tag "$1"
    if [ $? -ne 0 ]; then
        echo "[ERROR] Docker build failed."
        return 10
    fi
    return 0
}

# --------------------
# Function: Run Docker container
# --------------------
docker_run() {
    local image_name="$1"
    local ports_list="$2"
    local run_timeout="$3"
    local ports_mapping=""
    for mapping in $ports_list; do
        host_port=$(echo $mapping | cut -d: -f1)
        container_port=$(echo $mapping | cut -d: -f2)
        ports_mapping="$ports_mapping -p $host_port:$container_port"
    done
    echo "[INFO] Running Docker container..."
    echo "docker run \\
      --env RUN_TIMEOUT=$run_timeout \\
      $ports_mapping \\
      --rm -d $image_name"
    container_id=$(docker run \
      --env RUN_TIMEOUT=$run_timeout \
      $ports_mapping \
      --rm -d $image_name)
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

if ! docker_build "$image_name"; then
    echo "[FAIL] Docker build failed."
    exit 10
fi

if ! docker_run "$image_name" "$ports" "$run_timeout"; then
    echo "[FAIL] Docker run failed."
    exit 11
fi

# Wait for container healthcheck to report 'healthy'
echo "[INFO] Waiting for container to become healthy..."
for i in $(seq 1 $run_timeout); do
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_id")
    echo "[INFO] Health status: $health_status"
    if [ "$health_status" = "healthy" ]; then
        echo "[SUCCESS] Container is healthy."
        break
    elif [ "$health_status" = "unhealthy" ]; then
        echo "[FAIL] Container is unhealthy."
        exit 14
    fi
    sleep 1
done

# Test version (locale)
version=$(docker exec "$container_id" /tools/node.version.sh)
if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[SUCCESS] node.version.sh returned a valid version: $version"
else
    echo "[FAIL] node.version.sh did not return a valid version: $version"
    docker rm -f "$container_id"
    exit 16
fi

# Test update logic (compare local/remote)
echo "[INFO] Testing update logic..."
remote_version=$(docker exec "$container_id" /tools/node.remoteVersion.sh)
echo "[INFO] Local version: $version"
echo "[INFO] Remote version: $remote_version"
if [ "$version" = "$remote_version" ]; then
    echo "[SUCCESS] Local and remote versions match."
else
    echo "[INFO] Local and remote versions differ. Update needed."
fi

echo "[INFO] Stopping container..."
docker stop "$container_id"
echo "[SUCCESS] All tests passed."
exit 0
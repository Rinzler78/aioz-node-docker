#!/bin/bash
# Alpine package maintenance, sourced by deploy.sh.
# Standalone: dist.sh update | clean

dist_update() {
    apk update
    apk upgrade
}

# Drop the kernel packages of other kernels, then the apk cache.
dist_clean() {
    local stale
    mapfile -t stale < <(apk list -I | awk -F'-' '/linux/ {print $1}' | grep -v "$(uname -r)")
    [ "${#stale[@]}" -eq 0 ] || apk del "${stale[@]}"
    apk cache clean
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    case "$1" in
        update) dist_update ;;
        clean) dist_clean ;;
        *) echo "Usage: dist.sh update|clean" >&2; exit 2 ;;
    esac
fi

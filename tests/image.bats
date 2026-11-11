#!/usr/bin/env bats
# The image declarations that tests of the scripts cannot see.

load helpers

# HEALTHCHECK instruction of the Dockerfile, continuation lines joined.
healthcheck() {
    awk '/^HEALTHCHECK/ { found = 1 }
        found { more = /\\$/; sub(/[ \t]*\\$/, "", $0); line = line " " $0; if (!more) exit }
        END { print line }' "$REPO_ROOT/Dockerfile" | tr -s ' ' | sed 's/^ //'
}

# Default check timeout of node.health.sh (local check_timeout="${1:-value}" ...).
check_default_timeout() {
    sed -n 's/^ *local check_timeout="\${1:-\([0-9]*\)}"\( .*\)*$/\1/p' "$REPO_ROOT/tools/node.health.sh"
}

# Default of the start.sh watchdog setting $1 (NAME="${NAME:-value}").
watchdog_default() {
    sed -n "s/^$1=\"\${$1:-\([0-9]*\)}\"$/\1/p" "$REPO_ROOT/tools/start.sh"
}

@test "the image health check is node.health.sh with the watchdog default timings" {
    local interval timeout start_period retries
    interval=$(watchdog_default HEALTH_INTERVAL)
    timeout=$(watchdog_default HEALTH_TIMEOUT)
    start_period=$(watchdog_default HEALTH_START_PERIOD)
    retries=$(watchdog_default HEALTH_RETRIES)
    [ -n "$interval" ] && [ -n "$timeout" ] && [ -n "$start_period" ] && [ -n "$retries" ]

    [ "$(healthcheck)" = "HEALTHCHECK --interval=${interval}s --timeout=${timeout}s --start-period=${start_period}s --retries=$retries CMD [\"node.health.sh\"]" ]
}

@test "node.health.sh run with no argument defaults to the image HEALTHCHECK timeout" {
    local timeout
    timeout=$(check_default_timeout)
    [ -n "$timeout" ]

    [[ "$(healthcheck)" == *" --timeout=${timeout}s "* ]]
}

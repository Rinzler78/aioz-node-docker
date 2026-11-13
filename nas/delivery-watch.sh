#!/bin/bash
# Tells when the node stops, then resumes, earning delivery rewards. Runs on the
# NAS host (DSM Task Scheduler, daily, as root), not in the image: it reads the
# delivery count the reward container logs at every check (withdraw.reward.sh).
# Only that container can read it: the hub serves it to the wallet key alone.
#
# Exit 1 means "something to report", once per event: a stall (count unchanged
# for STALL_HOURS), a resume after a reported stall, a count going down (counter
# reset, or 0 when the hub omits it) and an invalid state; both restart the
# watch. No count in the logs, or a state that cannot be written, exit 1 on
# every run until fixed. DSM notifies a task that ends abnormally, with its
# output. State: STATE_FILE holds "<count> <epoch of its last change> <ok|stalled>".
WITHDRAW_CONTAINER="${WITHDRAW_CONTAINER:-aioz-compose-aioznode-auto-withdraw-reward-1}"
STATE_FILE="${STATE_FILE:-/volume1/docker/aioznode/delivery-watch.state}"
STALL_HOURS="${STALL_HOURS:-48}"
# The DSM task runs with a minimal PATH: Container Manager's docker by default.
DOCKER="${DOCKER:-/usr/local/bin/docker}"

# Delivery count of the last status in the reward container logs; empty if none.
delivery_count() {
    "$DOCKER" logs --tail 200 "$WITHDRAW_CONTAINER" 2>&1 |
        sed -n 's/^=> Delivery count : \([0-9][0-9]*\)$/\1/p' | tail -n 1
}

# Replaces the state in one step: a run killed midway leaves the old one.
save_state() {
    if ! { echo "$*" > "$STATE_FILE.new" && mv "$STATE_FILE.new" "$STATE_FILE"; } 2> /dev/null; then
        echo "ERROR: cannot write $STATE_FILE" >&2
        return 1
    fi
}

# Decimal number without leading zero. Every value is checked before any
# arithmetic: bash evaluates a variable in $(( )) as an expression, commands
# included, and reads a leading 0 as octal (0999 fails, 0177 is 127).
is_number() {
    [[ "$1" =~ ^(0|[1-9][0-9]*)$ ]]
}

# A state is "<count> <epoch> <ok|stalled>".
valid_state() {
    is_number "$1" && is_number "$2" && [[ "$3" =~ ^(ok|stalled)$ ]]
}

when() {
    date -u -d "@$1" '+%Y-%m-%d %H:%M UTC'
}

delivery_watch() {
    local now count last since status
    now="${NOW:-$(date +%s)}"
    if ! is_number "$now"; then
        echo "ERROR: NOW must be an epoch in seconds" >&2
        return 1
    fi
    if ! is_number "$STALL_HOURS" || [ "$STALL_HOURS" = 0 ]; then
        echo "ERROR: STALL_HOURS must be a number of hours above 0" >&2
        return 1
    fi
    count=$(delivery_count)
    if [ -z "$count" ]; then
        echo "ERROR: no delivery count in the logs of $WITHDRAW_CONTAINER" >&2
        return 1
    fi
    [ -f "$STATE_FILE" ] && read -r last since status < "$STATE_FILE"

    if [ ! -s "$STATE_FILE" ]; then
        save_state "$count $now ok" || return 1
        echo "Delivery count $count: watch started."
        return 0
    fi

    if ! valid_state "$last" "$since" "$status"; then
        save_state "$count $now ok" || return 1
        echo "AIOZ node: invalid state in $STATE_FILE, watch restarted at count $count."
        return 1
    fi

    if [ "$count" -lt "$last" ]; then
        save_state "$count $now ok" || return 1
        echo "AIOZ node: delivery count went down, $last -> $count; watch restarted."
        return 1
    fi

    if [ "$count" != "$last" ]; then
        save_state "$count $now ok" || return 1
        if [ "$status" = "stalled" ]; then
            echo "AIOZ node: deliveries resumed, count $last -> $count (stalled since $(when "$since"))."
            return 1
        fi
        echo "Delivery count $last -> $count."
        return 0
    fi

    if [ "$status" != "stalled" ] && [ $((now - since)) -ge $((STALL_HOURS * 3600)) ]; then
        save_state "$count $since stalled" || return 1
        echo "AIOZ node: deliveries stalled, count $count unchanged since $(when "$since")."
        return 1
    fi
    echo "Delivery count $count unchanged since $(when "$since")."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    delivery_watch "$@"
fi

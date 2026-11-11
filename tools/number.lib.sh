#!/bin/bash
# Number checks, sourced by start.sh and node.health.sh.

# True when $1 is a whole number of at least $2 (default 0), without a
# leading zero (bash arithmetic reads 08 as a bad octal number) and of at
# most 18 digits (bash arithmetic overflows past 2^63).
is_whole_number() {
    local pattern='^(0|[1-9][0-9]{0,17})$'
    [[ "$1" =~ $pattern ]] && [[ "${2:-0}" =~ $pattern ]] && [ "$1" -ge "${2:-0}" ]
}

# Check the value $2 of setting $1 against the minimum $3; print why it is
# refused.
require_whole_number() {
    if ! is_whole_number "$2" "$3"; then
        echo "ERROR: $1 must be a whole number of at least ${3:-0} (at most 18 digits, no leading zero): $2" >&2
        return 1
    fi
}

# Run standalone: `number.lib.sh <value> [minimum]` exits 0 when it passes.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    require_whole_number value "$@"
fi

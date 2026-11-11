#!/bin/bash
# Number checks, sourced by start.sh and node.health.sh.

# True when $1 is a whole number of at least $2 (default 0), without a
# leading zero (bash arithmetic reads 08 as a bad octal number).
is_whole_number() {
    [[ "$1" =~ ^(0|[1-9][0-9]*)$ ]] && [ "$1" -ge "${2:-0}" ]
}

# The error printed for a value $2 of setting $1 refused with minimum $3.
whole_number_error() {
    echo "ERROR: $1 must be a whole number of at least ${3:-0}, without a leading zero: $2" >&2
}

# Run standalone: `number.lib.sh <value> [minimum]` exits 0 when it passes.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    is_whole_number "$@"
fi

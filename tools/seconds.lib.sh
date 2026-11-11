#!/bin/bash
# Duration checks, sourced by start.sh and node.health.sh.

# True when $1 is a whole number of seconds, without a leading zero (bash
# arithmetic reads 08 as a bad octal number).
is_seconds() {
    [[ "$1" =~ ^(0|[1-9][0-9]*)$ ]]
}

# Run standalone: `seconds.lib.sh <value>` exits 0 for a number of seconds.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    is_seconds "$1"
fi

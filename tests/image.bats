#!/usr/bin/env bats
# The image declarations that tests of the scripts cannot see.

load helpers

# HEALTHCHECK instruction of the Dockerfile, continuation lines joined.
healthcheck() {
    sed -n '/^HEALTHCHECK/,/[^\\]$/p' "$REPO_ROOT/Dockerfile" | sed 's/ *\\$//' | tr -s ' \n' ' '
}

@test "the image health check is node.health.sh with the watchdog timings" {
    [ "$(healthcheck)" = 'HEALTHCHECK --interval=60s --timeout=30s --start-period=300s --retries=3 CMD ["node.health.sh"] ' ]
}

@test "the image locates the aioz-io binary the CLI extracts" {
    local expected
    read -r expected << 'EOF'
ENV NODE_IO=$HOME/.cache/aioz-depin-cli/bin/aioz-io
EOF
    grep -qxF "$expected" "$REPO_ROOT/Dockerfile"
}

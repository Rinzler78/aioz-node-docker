#!/usr/bin/env bats
# Seam S6: node.io.sh, the aioz-io binary the CLI wrapper embeds. The v1.2.6
# wrapper extracts it only when it is missing, so a stale copy survives an
# update of the wrapper unless node.io.sh replaces it.

load helpers

setup() {
    setup_node_env
}

io_version() {
    "$NODE_IO" version 2>&1
}

@test "extracts aioz-io when it is missing" {
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.2.6"

    run node.io.sh

    [ "$status" -eq 0 ]
    [ "$(io_version)" = "v1.2.6" ]
}

@test "replaces an aioz-io extracted before node.io.sh ran" {
    make_fake_io "$NODE_IO" "1.1.0"
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.2.6"

    run node.io.sh

    [ "$status" -eq 0 ]
    [ "$(io_version)" = "v1.2.6" ]
}

@test "replaces aioz-io after the CLI changes" {
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.2.5"
    node.io.sh
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.2.6"

    run node.io.sh

    [ "$status" -eq 0 ]
    [ "$(io_version)" = "v1.2.6" ]
}

@test "keeps the aioz-io of an unchanged CLI" {
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.2.6"
    node.io.sh
    echo "# extracted before" >> "$NODE_IO" # gone if the file is replaced

    run node.io.sh

    [ "$status" -eq 0 ]
    grep -qx "# extracted before" "$NODE_IO"
}

@test "accepts an aioz-io whose version differs from the CLI" {
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.2.7" "1.2.6"

    run node.io.sh

    [ "$status" -eq 0 ]
    [ "$(io_version)" = "v1.2.6" ]

    run node.io.sh

    [ "$status" -eq 0 ]
}

@test "fails when the CLI does not extract aioz-io" {
    make_fake_cli "$BIN_DIR/$BINARY_NAME" "1.2.6" # answers version only

    run node.io.sh

    [ "$status" -eq 1 ]
    [[ "$output" == *ERROR*aioz-io* ]]
}

@test "fails when no CLI is installed" {
    run node.io.sh

    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: $BINARY_NAME is not installed"* ]]
}

@test "deploy refreshes aioz-io after the CLI update" {
    make_fake_io "$NODE_IO" "1.1.0"
    make_fake_node "$BIN_DIR/$BINARY_NAME" "1.2.6"

    run deploy.sh

    [ "$status" -eq 0 ]
    [ "$(io_version)" = "v1.2.6" ]
}

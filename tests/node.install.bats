#!/usr/bin/env bats
# Seam S1: node.install.sh against a fake GitHub API.

load helpers

setup() {
    setup_env
}

@test "installs the CLI from the linux-amd64 asset of the latest release" {
    serve_release 1.2.6

    run node.install.sh

    [ "$status" -eq 0 ]
    [ "$(installed_version)" = "1.2.6" ]
}

@test "replaces an outdated binary with the latest release" {
    make_fake_cli "$BIN_DIR/$BINARY_NAME" "1.1.0"
    serve_release 1.2.6

    run node.install.sh

    [ "$status" -eq 0 ]
    [ "$(installed_version)" = "1.2.6" ]
}

@test "keeps an up-to-date binary without downloading" {
    make_fake_cli "$BIN_DIR/$BINARY_NAME" "1.2.6"
    serve_release 9.9.9 # would show up if the archive were installed

    run node.install.sh

    [ "$status" -eq 0 ]
    [ "$(installed_version)" = "1.2.6" ]
}

@test "warns and keeps the existing binary when GitHub is unreachable" {
    make_fake_cli "$BIN_DIR/$BINARY_NAME" "1.1.0"

    run node.install.sh

    [ "$status" -eq 0 ]
    [[ "$output" == *WARN* ]]
    [ "$(installed_version)" = "1.1.0" ]
}

@test "fails when GitHub is unreachable and no binary is installed" {
    run node.install.sh

    [ "$status" -eq 1 ]
    [ ! -e "$BIN_DIR/$BINARY_NAME" ]
}

@test "fails when the release has no linux-amd64 archive and no binary is installed" {
    serve_release_without_linux_asset

    run node.install.sh

    [ "$status" -eq 1 ]
    [ ! -e "$BIN_DIR/$BINARY_NAME" ]
}

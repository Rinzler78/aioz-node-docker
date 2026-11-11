#!/usr/bin/env bats
# deps-freshness.sh against fake git and pre-commit. Fixtures are real
# captures (2026-11-11): `git ls-remote --tags` of actions/checkout and
# rhysd/actionlint, and the output of `pre-commit autoupdate` on this
# repository's config: as is (fresh), with actionlint set back to v1.7.10
# (outdated), and with the yamllint repository renamed to a missing one
# (error; home and temporary paths shortened).

SCRIPT="$BATS_TEST_DIRNAME/../deps-freshness.sh"
FIXTURES="$BATS_TEST_DIRNAME/fixtures"

# From the capture: v7.0.1 is the latest release.
V701=3d3c42e5aac5ba805825da76410c181273ba90b1
V700=9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0
# v6.0.3 is an annotated tag: its tag object, then the commit it points to.
V603_TAG=9f698171ed81b15d1823a05fc7211befd50c8ae0
V603=df4cb1c069e1874edd31b4311f1884172cec0e10

setup() {
    export PATH="$BATS_TEST_DIRNAME/fakes:$PATH"
    # The script must reach the fakes, never the network.
    [ "$(command -v git)" = "$BATS_TEST_DIRNAME/fakes/git" ]
    [ "$(command -v pre-commit)" = "$BATS_TEST_DIRNAME/fakes/pre-commit" ]
    export FAKE_GIT_DIR="$BATS_TEST_TMPDIR/git"
    mkdir -p "$FAKE_GIT_DIR"
    cp "$FIXTURES/ls-remote-actions-checkout.txt" "$FAKE_GIT_DIR/actions_checkout.txt"
    export FAKE_AUTOUPDATE="$FIXTURES/autoupdate-fresh.txt" FAKE_AUTOUPDATE_RC=0
    export PRE_COMMIT_CONFIG="$BATS_TEST_TMPDIR/pre-commit-config.yaml"
    echo "repos: []" > "$PRE_COMMIT_CONFIG"
    WORKFLOW="$BATS_TEST_TMPDIR/build.yml"
}

# workflow <file> <comment line> <uses line>: one checkout step.
workflow() {
    printf 'jobs:\n  build:\n    steps:\n      %s\n      - uses: %s\n' "$2" "$3" > "$1"
}

@test "passes when the hooks and the actions are the latest releases" {
    workflow "$WORKFLOW" "# actions/checkout v7.0.1" "actions/checkout@$V701"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 0 ]
}

@test "names each outdated pre-commit hook" {
    FAKE_AUTOUPDATE="$FIXTURES/autoupdate-outdated.txt"
    workflow "$WORKFLOW" "# actions/checkout v7.0.1" "actions/checkout@$V701"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 1 ]
    [[ "$output" == *"rhysd/actionlint] updating v1.7.10 -> v1.7.12"* ]]
    [[ "$output" == *"shellcheck-py] updating v0.11.0.1 -> v0.11.0.1-1"* ]]
}

@test "never rewrites the real pre-commit config" {
    cp "$PRE_COMMIT_CONFIG" "$BATS_TEST_TMPDIR/before"
    workflow "$WORKFLOW" "# actions/checkout v7.0.1" "actions/checkout@$V701"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 0 ]
    [ -s "$FAKE_GIT_DIR/autoupdate-config" ]
    [ "$(cat "$FAKE_GIT_DIR/autoupdate-config")" != "$PRE_COMMIT_CONFIG" ]
    cmp "$PRE_COMMIT_CONFIG" "$BATS_TEST_TMPDIR/before"
}

@test "keeps the git environment of a commit away from autoupdate" {
    # git commit gives its hooks GIT_INDEX_FILE (in a worktree, the absolute
    # path of its index): the clones autoupdate makes would write into it.
    workflow "$WORKFLOW" "# actions/checkout v7.0.1" "actions/checkout@$V701"

    GIT_INDEX_FILE=/repo/.git/index GIT_DIR=/repo/.git GIT_WORK_TREE=/repo \
        GIT_SSH_COMMAND=ssh run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 0 ]
    [ "$(cat "$FAKE_GIT_DIR/autoupdate-env")" = "$(printf 'GIT_SSH_COMMAND\nGIT_TERMINAL_PROMPT')" ]
}

@test "fails when pre-commit cannot check its hooks" {
    FAKE_AUTOUPDATE="$FIXTURES/autoupdate-error.txt" FAKE_AUTOUPDATE_RC=3
    workflow "$WORKFLOW" "# actions/checkout v7.0.1" "actions/checkout@$V701"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Repository not found"* ]]
}

@test "names an action that is not its latest release" {
    workflow "$WORKFLOW" "# actions/checkout v7.0.0" "actions/checkout@$V700"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 1 ]
    [[ "$output" == *"actions/checkout v7.0.0, latest v7.0.1"* ]]
}

@test "fails when a pinned commit is not its commented version" {
    workflow "$WORKFLOW" "# actions/checkout v7.0.1" "actions/checkout@$V700"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 1 ]
    [[ "$output" == *"actions/checkout@$V700 is not v7.0.1"* ]]
}

@test "reads an annotated tag as the commit it points to" {
    workflow "$WORKFLOW" "# actions/checkout v6.0.3" "actions/checkout@$V603"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 1 ]
    [[ "$output" != *" is not v6.0.3"* ]]
    [[ "$output" == *"actions/checkout v6.0.3, latest v7.0.1"* ]]
}

@test "does not take a tag object for the commit" {
    workflow "$WORKFLOW" "# actions/checkout v6.0.3" "actions/checkout@$V603_TAG"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 1 ]
    [[ "$output" == *"actions/checkout@$V603_TAG is not v6.0.3"* ]]
}

@test "fails when a pinned commit has no version comment above it" {
    workflow "$WORKFLOW" "- name: Checkout" "actions/checkout@$V701"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 1 ]
    [[ "$output" == *"actions/checkout@$V701: no"*"version comment"* ]]
}

@test "fails when the comment names another action" {
    workflow "$WORKFLOW" "# actions/setup-node v7.0.1" "actions/checkout@$V701"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 1 ]
    [[ "$output" == *"actions/checkout@$V701: no"*"version comment"* ]]
}

@test "fails when the tags of an action cannot be read" {
    workflow "$WORKFLOW" "# actions/unknown v1.0.0" "actions/unknown@$V701"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 1 ]
    [[ "$output" == *"cannot read the tags of actions/unknown"* ]]
}

@test "reports every problem, not only the first" {
    workflow "$WORKFLOW" "# actions/checkout v7.0.0" "actions/checkout@$V700"
    workflow "$BATS_TEST_TMPDIR/watch.yml" "# actions/checkout v7.0.1" "actions/checkout@$V700"
    FAKE_AUTOUPDATE="$FIXTURES/autoupdate-outdated.txt"

    run "$SCRIPT" "$WORKFLOW" "$BATS_TEST_TMPDIR/watch.yml"

    [ "$status" -eq 1 ]
    [[ "$output" == *"actionlint] updating"* ]]
    [[ "$output" == *"actions/checkout v7.0.0, latest v7.0.1"* ]]
    [[ "$output" == *"actions/checkout@$V700 is not v7.0.1"* ]]
}

@test "orders versions as numbers, not as text" {
    # rhysd/actionlint has v1.7.9 and v1.7.12: as text, v1.7.9 sorts last.
    cp "$FIXTURES/ls-remote-rhysd-actionlint.txt" "$FAKE_GIT_DIR/rhysd_actionlint.txt"
    workflow "$WORKFLOW" "# rhysd/actionlint v1.7.12" \
        "rhysd/actionlint@914e7df21a07ef503a81201c76d2b11c789d3fca"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 0 ]
}

@test "fails when a workflow cannot be read" {
    run "$SCRIPT" "$BATS_TEST_TMPDIR/missing.yml"

    [ "$status" -eq 1 ]
    [[ "$output" == *"cannot read $BATS_TEST_TMPDIR/missing.yml"* ]]
}

@test "checks the .yml and .yaml workflows by default" {
    mkdir -p "$BATS_TEST_TMPDIR/repo/.github/workflows"
    cd "$BATS_TEST_TMPDIR/repo"
    workflow .github/workflows/a.yml "# actions/checkout v7.0.0" "actions/checkout@$V700"
    workflow .github/workflows/b.yaml "# actions/checkout v7.0.1" "actions/checkout@$V700"

    run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"a.yml: actions/checkout v7.0.0, latest v7.0.1"* ]]
    [[ "$output" == *"b.yaml: actions/checkout@$V700 is not v7.0.1"* ]]
}

@test "fails when there is no workflow to check" {
    mkdir -p "$BATS_TEST_TMPDIR/repo"
    cd "$BATS_TEST_TMPDIR/repo"

    run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"no workflow in .github/workflows"* ]]
}

@test "checks a quoted pin" {
    workflow "$WORKFLOW" "# actions/checkout v7.0.0" "\"actions/checkout@$V700\""

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 1 ]
    [[ "$output" == *"actions/checkout v7.0.0, latest v7.0.1"* ]]
}

@test "fails when an action is not pinned to a commit" {
    workflow "$WORKFLOW" "# actions/checkout v7.0.1" "actions/checkout@v7.0.1"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 1 ]
    [[ "$output" == *"actions/checkout@v7.0.1 is not pinned to a commit SHA"* ]]
}

@test "checks an action in a folder of its repository against that repository" {
    workflow "$WORKFLOW" "# actions/checkout/sub v7.0.0" "actions/checkout/sub@$V700"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 1 ]
    [[ "$output" == *"actions/checkout/sub v7.0.0, latest v7.0.1"* ]]
}

@test "leaves local and Docker actions alone" {
    printf '      - uses: ./.github/actions/local\n      - uses: docker://alpine:3\n' > "$WORKFLOW"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 0 ]
}

@test "removes its copy of the config, also when autoupdate fails" {
    workflow "$WORKFLOW" "# actions/checkout v7.0.1" "actions/checkout@$V701"

    run "$SCRIPT" "$WORKFLOW"
    [ "$status" -eq 0 ]
    [ ! -e "$(cat "$FAKE_GIT_DIR/autoupdate-config")" ]

    FAKE_AUTOUPDATE="$FIXTURES/autoupdate-error.txt" FAKE_AUTOUPDATE_RC=3
    run "$SCRIPT" "$WORKFLOW"
    [ "$status" -eq 1 ]
    [ ! -e "$(cat "$FAKE_GIT_DIR/autoupdate-config")" ]
}

@test "says so when an action has no vX.Y.Z tag" {
    # The checkout capture without its vX.Y.Z tags: v7 is left.
    grep -v 'refs/tags/v[0-9]*\.[0-9]*\.[0-9]*$' "$FIXTURES/ls-remote-actions-checkout.txt" \
        > "$FAKE_GIT_DIR/actions_checkout.txt"
    workflow "$WORKFLOW" "# actions/checkout v7" "actions/checkout@$V701"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 1 ]
    [[ "$output" == *"actions/checkout v7, no vX.Y.Z release tag"* ]]
}

@test "fails on a uses: it cannot read, such as a flow mapping" {
    printf '      - { uses: actions/checkout@v4 }\n' > "$WORKFLOW"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 1 ]
    [[ "$output" == *"cannot check: - { uses: actions/checkout@v4 }"* ]]
}

@test "ignores uses: in a comment" {
    printf '      # uses: actions/checkout@v4 is not pinned\n' > "$WORKFLOW"

    run "$SCRIPT" "$WORKFLOW"

    [ "$status" -eq 0 ]
}

@test "leaves the nullglob setting of a shell that sources it as it was" {
    mkdir -p "$BATS_TEST_TMPDIR/repo/.github/workflows"
    cd "$BATS_TEST_TMPDIR/repo"
    workflow .github/workflows/a.yml "# actions/checkout v7.0.1" "actions/checkout@$V701"

    run bash -c 'source "$1"; shopt -s nullglob; deps_freshness; shopt -q nullglob' _ "$SCRIPT"
    [ "$status" -eq 0 ]

    run bash -c 'source "$1"; deps_freshness; ! shopt -q nullglob' _ "$SCRIPT"
    [ "$status" -eq 0 ]
}

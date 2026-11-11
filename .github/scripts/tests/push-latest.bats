#!/usr/bin/env bats
# push-latest.sh against fake git and docker. Fixtures are real captures
# (2026-11-11) of `git ls-remote --tags`: this repository (v0.0.1, v0.0.2),
# rhysd/actionlint (v1.7.9 and v1.7.12) and actions/checkout (v6-beta, v7).

SCRIPT="$BATS_TEST_DIRNAME/../push-latest.sh"
FIXTURES="$BATS_TEST_DIRNAME/fixtures"

setup() {
    export PATH="$BATS_TEST_DIRNAME/fakes:$PATH"
    # A real docker would push to Docker Hub: the fakes must answer.
    [ "$(command -v docker)" = "$BATS_TEST_DIRNAME/fakes/docker" ]
    [ "$(command -v git)" = "$BATS_TEST_DIRNAME/fakes/git" ]
    export FAKE_GIT_DIR="$BATS_TEST_TMPDIR/git" FAKE_DOCKER_DIR="$BATS_TEST_TMPDIR/docker"
    mkdir -p "$FAKE_GIT_DIR" "$FAKE_DOCKER_DIR"
    cp "$FIXTURES/ls-remote-rinzler78-aioz-node-docker.txt" "$FAKE_GIT_DIR/Rinzler78_aioz-node-docker.txt"
    cp "$FIXTURES/ls-remote-rhysd-actionlint.txt" "$FAKE_GIT_DIR/rhysd_actionlint.txt"
    cp "$FIXTURES/ls-remote-actions-checkout.txt" "$FAKE_GIT_DIR/actions_checkout.txt"
    export GITHUB_REPOSITORY=Rinzler78/aioz-node-docker
}

docker_calls() {
    cat "$FAKE_DOCKER_DIR/calls" 2> /dev/null
}

@test "moves latest to the highest release" {
    run "$SCRIPT" rinzlerfr/aioznode v0.0.2

    [ "$status" -eq 0 ]
    [ "$(docker_calls)" = "$(printf '%s\n' \
        'tag rinzlerfr/aioznode:v0.0.2 rinzlerfr/aioznode:latest' \
        'push rinzlerfr/aioznode:latest')" ]
}

@test "leaves latest alone for an older release" {
    run "$SCRIPT" rinzlerfr/aioznode v0.0.1

    [ "$status" -eq 0 ]
    [[ "$output" == *"v0.0.1 is not the highest release (v0.0.2): latest unchanged"* ]]
    [ -z "$(docker_calls)" ]
}

@test "orders releases as numbers, not as text" {
    # As text, v1.7.9 sorts after v1.7.12.
    GITHUB_REPOSITORY=rhysd/actionlint run "$SCRIPT" img v1.7.12
    [ "$status" -eq 0 ]
    [ "$(docker_calls | tail -n 1)" = "push img:latest" ]

    GITHUB_REPOSITORY=rhysd/actionlint run "$SCRIPT" img v1.7.9
    [ "$status" -eq 0 ]
    [[ "$output" == *"v1.7.9 is not the highest release (v1.7.12)"* ]]
}

@test "leaves latest alone for a tag that is not vX.Y.Z" {
    GITHUB_REPOSITORY=actions/checkout run "$SCRIPT" img v6-beta

    [ "$status" -eq 0 ]
    [[ "$output" == *"v6-beta is not the highest release (v7.0.1)"* ]]
    [ -z "$(docker_calls)" ]
}

@test "fails when the tags cannot be read" {
    GITHUB_REPOSITORY=Rinzler78/unknown run "$SCRIPT" img v0.0.2

    [ "$status" -eq 1 ]
    [[ "$output" == *"cannot read the tags of Rinzler78/unknown"* ]]
    [ -z "$(docker_calls)" ]
}

@test "fails when the tag is not among the tags it read" {
    run "$SCRIPT" rinzlerfr/aioznode v0.0.3

    [ "$status" -eq 1 ]
    [[ "$output" == *"v0.0.3 is not a tag of Rinzler78/aioz-node-docker"* ]]
    [ -z "$(docker_calls)" ]
}

@test "fails when docker cannot tag or push latest" {
    export FAKE_DOCKER_FAIL=tag
    run "$SCRIPT" rinzlerfr/aioznode v0.0.2
    [ "$status" -eq 1 ]
    [ "$(docker_calls)" = "tag rinzlerfr/aioznode:v0.0.2 rinzlerfr/aioznode:latest" ]

    rm "$FAKE_DOCKER_DIR/calls"
    export FAKE_DOCKER_FAIL=push
    run "$SCRIPT" rinzlerfr/aioznode v0.0.2
    [ "$status" -eq 1 ]
}

@test "fails without an image, a tag or the repository" {
    run "$SCRIPT" rinzlerfr/aioznode
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage"* ]]

    unset GITHUB_REPOSITORY
    run "$SCRIPT" rinzlerfr/aioznode v0.0.2
    [ "$status" -eq 1 ]
    [[ "$output" == *"GITHUB_REPOSITORY"* ]]
    [ -z "$(docker_calls)" ]
}

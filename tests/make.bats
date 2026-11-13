#!/usr/bin/env bats
# The Makefile is the entry point of the repository commands: each target runs
# one documented script, and the default target only lists them.
# make -n prints the commands of a target without running them.

load helpers

@test "the default target lists every target with its description" {
    run make --no-print-directory -C "$REPO_ROOT"
    [ "$status" -eq 0 ]
    [ "$output" = "Usage: make <target> [ARGS='docker run arguments']

  help           List the targets (default)
  test           Image script tests (bats, in Docker)
  test-ci        CI script tests (bats, in Docker)
  lint           Every pre-commit hook on every file (builds the image, network)
  check          Definition of done: test, test-ci and lint
  quick-test     Build the image and wait for healthy (network)
  docker-build   Build the local aioznode image
  docker-run     Stop, then run the local aioznode container
  docker-stop    Stop the local aioznode container
  docker-start   Stop, clean, build, then run the local aioznode container
  docker-clean   Remove the aioznode container and image, then the unused images of this project" ]
}

@test "each target runs its script" {
    local target expected
    while IFS='|' read -r target expected; do
        run make --no-print-directory -n -C "$REPO_ROOT" "$target"
        [ "$status" -eq 0 ]
        [ "$output" = "$expected" ]
    done << 'EOF'
test|tests/run.sh
test-ci|.github/scripts/tests/run.sh
lint|pre-commit run --all-files
quick-test|scripts/quick_test.sh
docker-build|scripts/helper.docker.build.sh
docker-run|scripts/helper.docker.run.sh
docker-stop|scripts/helper.docker.stop.sh
docker-start|scripts/helper.docker.start.sh
docker-clean|scripts/helper.docker.clean.sh
EOF
}

@test "check runs the tests, the CI script tests and the hooks, in that order" {
    run make --no-print-directory -n -C "$REPO_ROOT" check
    [ "$status" -eq 0 ]
    [ "$output" = $'tests/run.sh\n.github/scripts/tests/run.sh\npre-commit run --all-files' ]
}

@test "docker-run and docker-start pass ARGS to docker run" {
    run make --no-print-directory -n -C "$REPO_ROOT" docker-run ARGS='-v /data:/nodedata'
    [ "$output" = "scripts/helper.docker.run.sh -v /data:/nodedata" ]
    run make --no-print-directory -n -C "$REPO_ROOT" docker-start ARGS='-v /data:/nodedata'
    [ "$output" = "scripts/helper.docker.start.sh -v /data:/nodedata" ]
}

# Rule names of the Makefile, and target names that make help prints.
makefile_rules() {
    sed -n 's/^\([a-z][a-z-]*\):.*/\1/p' "$REPO_ROOT/Makefile" | sort
}
help_targets() {
    make --no-print-directory -C "$REPO_ROOT" help | sed -n 's/^  \([a-z][a-z-]*\) .*/\1/p' | sort
}

@test "every rule of the Makefile is listed by help" {
    run makefile_rules
    local rules="$output"
    [ -n "$rules" ]
    run help_targets
    [ "$output" = "$rules" ]
}

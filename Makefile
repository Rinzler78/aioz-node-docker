# Entry point of the repository commands: each target runs one script.
# make (or make help) lists the targets. ARGS are passed to docker run.

.DEFAULT_GOAL := help
# Appended to docker-run and docker-start, with its leading space only when set.
ARGS ?=

.PHONY: help test test-ci lint check quick-test
.PHONY: docker-build docker-run docker-stop docker-start docker-clean

help: ## List the targets (default)
	@echo "Usage: make <target> [ARGS='docker run arguments']"
	@echo
	@awk 'BEGIN { FS = ":.*## " } /^[a-z][a-z-]*:.*## / { printf "  %-14s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

test: ## Image script tests (bats, in Docker)
	tests/run.sh

test-ci: ## CI script tests (bats, in Docker)
	.github/scripts/tests/run.sh

lint: ## Every pre-commit hook on every file (builds the image, network)
	pre-commit run --all-files

check: test test-ci lint ## Definition of done: test, test-ci and lint

quick-test: ## Build the image and wait for healthy (network)
	scripts/quick_test.sh

docker-build: ## Build the local aioznode image
	scripts/helper.docker.build.sh

docker-run: ## Stop, then run the local aioznode container
	scripts/helper.docker.run.sh$(if $(ARGS), $(ARGS))

docker-stop: ## Stop the local aioznode container
	scripts/helper.docker.stop.sh

docker-start: ## Stop, clean, build, then run the local aioznode container
	scripts/helper.docker.start.sh$(if $(ARGS), $(ARGS))

docker-clean: ## Remove the aioznode container and image, then the unused images of this project
	scripts/helper.docker.clean.sh

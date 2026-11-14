# Contributing

Issues and pull requests are welcome. The rules below apply to every
contributor, human or coding agent. [AGENTS.md](AGENTS.md) holds the full
list (conventions, safety rules, definition of done); this guide is the path
through it. A security issue is reported privately: see
[SECURITY.md](SECURITY.md).

## Set up

You need Docker, bash, make, [pre-commit](https://pre-commit.com/), trivy and
hadolint (`brew install pre-commit trivy hadolint` on macOS). The tests run in
Docker, so bats is not needed on the machine.

```sh
git clone https://github.com/Rinzler78/aioz-node-docker.git
cd aioz-node-docker
git switch develop
pre-commit install   # the hooks check each commit
make                 # lists the targets
```

[docs/architecture.md](docs/architecture.md) maps the repository, and
[docs/adr](docs/adr/README.md) explains why it is built that way.

## Make a change

1. Branch from `develop`: `feature/<name>`, in its own worktree
   (`git worktree add -b feature/<name> .worktrees/<name> develop`). A fix for
   the released image branches from `master` as `hotfix/<name>`.
2. Write the test first and run it: it must fail, on the assertion you meant.
   Then write the code that makes it pass, and break that code once on purpose
   to check that the test turns red again.
3. Update the documentation in the same change: README, `docs/`, the workflow
   header comments, and the `Unreleased` section of
   [CHANGELOG.md](CHANGELOG.md).
4. Run `make check`: the image script tests, the CI script tests and every
   pre-commit hook on every file. Never skip a hook (`--no-verify`): a failing
   check points at a cause to fix.
5. Commit with a [Conventional Commits](https://www.conventionalcommits.org/)
   message (`feat(nas): …`, `fix(watch): …`), staging files by explicit path.
6. Open a pull request against `develop` (a hotfix against `master`, which is
   then merged back into `develop`). Keep it short, about 400 lines and
   10 files; split a larger change into several pull requests.

## Review

A pull request is reviewed on its standards, its specification, its security,
its tests and its documentation. Each finding is fixed or answered, then the
updated diff is reviewed again, until no major or minor finding is left. The
verdict is posted on the pull request before the merge, along with the CI
checks.

## Release

1. A `release/vX.Y.Z` branch from `develop` gets one commit, its
   `CHANGELOG.md` section: the `Unreleased` entries move under
   `## [X.Y.Z] - <date>`, and the links at the bottom of the file follow
   (since this changelog; the release branches of v0.0.2 and v0.0.3 had no
   commit of their own).
2. Its pull request is merged into `master`, and `vX.Y.Z` is tagged there.
3. The tag runs the `Docker Image CI` workflow: it builds the image, runs the
   tests and `scripts/quick_test.sh`, pushes `rinzlerfr/aioznode:vX.Y.Z`, moves
   `latest` when the tag is the highest release, and creates the GitHub
   release.
4. `master` is merged back into `develop`.

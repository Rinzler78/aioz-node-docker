# Security policy

## Supported versions

Only the latest release is supported: the highest `vX.Y.Z` tag, which is also
the `latest` tag of the
[rinzlerfr/aioznode](https://hub.docker.com/r/rinzlerfr/aioznode) image. A fix
ships in a new release; older releases get no backport.

## Reporting a vulnerability

Report it privately, through GitHub: the **Security** tab of the repository,
then **Report a vulnerability**. Do not open a public issue.

Describe the affected file or image tag, the steps to reproduce and the
impact. Never attach a node private key (`privkey.json`), a wallet address
of your own or a token: a report needs none of them.

The report is followed on its draft advisory. Once the fixed image is
published, the advisory is published too, with the release that fixes it in
[CHANGELOG.md](CHANGELOG.md).

## Scope

In scope: the image (`Dockerfile`, `tools/`), the NAS script (`nas/`), the
local scripts (`scripts/`) and the GitHub workflows with their scripts
(`.github/`).

Out of scope, to report upstream:

* the AIOZ DePIN CLI and the AIOZ network:
  [AIOZNetwork/aioz-depin-cli](https://github.com/AIOZNetwork/aioz-depin-cli);
* the packages of the Alpine base image: [Alpine Linux](https://alpinelinux.org/).
  The image follows `alpine:latest`, so a fixed package ships with the next
  release.

## How the project protects itself

* The node private key never leaves its host: git and the Docker build context
  ignore it, and the withdraw container mounts it read-only.
* The CLI downloaded at every start is checked against the `SHA256SUMS` of its
  release before install.
* The numbers that the node start, its health check and the delivery watch
  read from settings, files or commands are checked before shell arithmetic,
  which would otherwise evaluate them as code. In the withdraw mode, the
  settings and the balance read from the node are not all checked yet.
* Workflows run read-only by default; their actions are pinned to a commit;
  zizmor checks them; the Docker Hub secrets are open to release tags only.
* The pre-commit hooks run trivy when their inputs change: a configuration
  scan of the Dockerfiles, and a scan of the built image, when the
  `Dockerfile` or `tools/` change, that fails on HIGH or CRITICAL
  vulnerabilities.

The details, and what is not checked yet, are in
[docs/architecture.md](docs/architecture.md#trust-boundaries).

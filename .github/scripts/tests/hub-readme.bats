#!/usr/bin/env bats
# hub-readme.sh turns README.md into the Docker Hub overview. The overview
# allows basic Markdown only (docs.docker.com/docker-hub/repos/manage/
# information/): relative links have no base there, and Mermaid and GitHub
# alerts are not documented, so they are rewritten for any renderer.

SCRIPT="$BATS_TEST_DIRNAME/../hub-readme.sh"
REPO_ROOT="$BATS_TEST_DIRNAME/../../.."
BLOB=https://github.com/Rinzler78/aioz-node-docker/blob/v1.2.3
RAW=https://github.com/Rinzler78/aioz-node-docker/raw/v1.2.3

hub_readme() {
    printf '%s\n' "$@" > "$BATS_TEST_TMPDIR/README.md"
    run "$SCRIPT" "$BATS_TEST_TMPDIR/README.md" Rinzler78/aioz-node-docker v1.2.3
}

# Decision table of the links. Rewritten to the release on GitHub: a path,
# with or without an anchor, in a link or a badge target (blob/<tag>), an image
# (raw/<tag>, the file itself). Left alone: http(s) and mailto URLs, an anchor
# of the page. Limits, none of them in README.md: a link from the root (`/x`)
# and a reference link (`[r]: x.md`) are left alone; a link in inline code is
# rewritten too; a path with a parenthesis is cut at it.
@test "points the relative links to the release on GitHub, and leaves the others" {
    hub_readme '[The image](docs/image.md): see [running](docs/image.md#running-the-image).' \
        '[MIT](LICENSE) [site](https://aioz.network/) [mail](mailto:a@b.c) [top](#quick-start)'

    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%s\n' \
        "[The image]($BLOB/docs/image.md): see [running]($BLOB/docs/image.md#running-the-image)." \
        "[MIT]($BLOB/LICENSE) [site](https://aioz.network/) [mail](mailto:a@b.c) [top](#quick-start)")" ]
}

@test "points a relative image to the file of the release, not to its page" {
    hub_readme '![Logo](docs/logo.png) [![CI](https://x/badge.svg)](docs/ci.md)'

    [ "$status" -eq 0 ]
    [ "$output" = "![Logo]($RAW/docs/logo.png) [![CI](https://x/badge.svg)]($BLOB/docs/ci.md)" ]
}

@test "keeps the sed specials of the tag literal" {
    printf '%s\n' '[x](docs/x.md)' > "$BATS_TEST_TMPDIR/README.md"
    run "$SCRIPT" "$BATS_TEST_TMPDIR/README.md" o/r 'v1&\#2'

    [ "$status" -eq 0 ]
    [ "$output" = '[x](https://github.com/o/r/blob/v1&\#2/docs/x.md)' ]
}

@test "replaces a Mermaid diagram with a link to the README on GitHub, and keeps other code" {
    hub_readme 'Intro.' '```mermaid' 'flowchart TB' '    a --> b' '```' \
        '```sh' 'docker run x' '```'

    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%s\n' 'Intro.' \
        "[The diagram of the containers]($BLOB/README.md), on GitHub." \
        '```sh' 'docker run x' '```')" ]
}

@test "fails on a Mermaid diagram never closed, rather than drop the rest" {
    hub_readme 'Intro.' '```mermaid' 'flowchart TB' '## Quick start'

    [ "$status" -eq 1 ]
    [[ "$output" == *"Mermaid diagram not closed"* ]]
}

@test "turns the GitHub alerts into bold labels" {
    hub_readme '> [!WARNING]' '> Back the key up.' '> [!NOTE]' '> [!TIP]' \
        '> [!IMPORTANT]' '> [!CAUTION]' '> [!OTHER]'

    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%s\n' '> **Warning**' '> Back the key up.' \
        '> **Note**' '> **Tip**' '> **Important**' '> **Caution**' '> [!OTHER]')" ]
}

# Docker Hub refuses a full description over 25000 characters (schema
# repo_creation_request, docs.docker.com/reference/api/hub/latest/), and the
# action truncates the file at 25000 bytes (MAX_BYTES of its readme helper):
# the limit is in bytes of the printed overview, final newline included.
@test "accepts an overview of 25000 bytes, and fails over it, printing nothing" {
    hub_readme "$(head -c 24999 /dev/zero | tr '\0' x)"
    [ "$status" -eq 0 ]
    [ "${#output}" -eq 24999 ]

    hub_readme "$(head -c 25000 /dev/zero | tr '\0' x)"
    [ "$status" -eq 1 ]
    [[ "$output" == *"over 25000 bytes"* ]]
    [[ "$output" != *xxx* ]]
}

# The runner reads UTF-8, where bash counts characters, not bytes.
@test "counts the limit in bytes, also in a UTF-8 locale" {
    local text
    text=$(printf 'é%.0s' $(seq 12600))
    LC_ALL=C.UTF-8 hub_readme "$text"

    [ "$status" -eq 1 ]
    [[ "$output" == *"over 25000 bytes"* ]]
}

@test "fails without its three arguments or with a missing README" {
    run "$SCRIPT" README.md Rinzler78/aioz-node-docker
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage"* ]]

    run "$SCRIPT" "$BATS_TEST_TMPDIR/none.md" Rinzler78/aioz-node-docker v1.2.3
    [ "$status" -eq 1 ]
}

# The README of the repository, as it is: no relative link, Mermaid block or
# alert left, within the limit.
@test "the README of the repository makes a valid overview" {
    run "$SCRIPT" "$REPO_ROOT/README.md" Rinzler78/aioz-node-docker v1.2.3

    [ "$status" -eq 0 ]
    # Read independently of the rewrite: any link target that is not a URL nor
    # an anchor of the page is left over.
    local left
    left=$( (
        grep -oE '\]\([^)]*\)' <<< "$output" |
            grep -vE '^\]\((https?://|mailto:|#)' || true
        grep -nE '^```mermaid|^> \[!' <<< "$output" || true
    ))
    [ -z "$left" ] || {
        printf 'left in the overview:\n%s\n' "$left"
        false
    }
    grep -qF "$BLOB/" <<< "$output"
}

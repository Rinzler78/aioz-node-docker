#!/usr/bin/env bats
# hub-readme.sh turns README.md into the Docker Hub overview. The overview
# allows basic Markdown only (docs.docker.com/docker-hub/repos/manage/
# information/): relative links have no base there, and Mermaid and GitHub
# alerts are not documented, so they are rewritten for any renderer.

SCRIPT="$BATS_TEST_DIRNAME/../hub-readme.sh"
REPO_ROOT="$BATS_TEST_DIRNAME/../../.."
BLOB=https://github.com/Rinzler78/aioz-node-docker/blob/v1.2.3

hub_readme() {
    printf '%s\n' "$@" > "$BATS_TEST_TMPDIR/README.md"
    run "$SCRIPT" "$BATS_TEST_TMPDIR/README.md" Rinzler78/aioz-node-docker v1.2.3
}

# Decision table of the links. Rewritten to the release on GitHub: a path,
# with or without an anchor, in a link or a badge target. Left alone: http(s)
# and mailto URLs, an anchor of the page. Limit: a link from the root (`/x`)
# and a relative image are left alone too; README.md has neither.
@test "points the relative links to the release on GitHub, and leaves the others" {
    hub_readme '[The image](docs/image.md): see [running](docs/image.md#running-the-image).' \
        '[MIT](LICENSE) [site](https://aioz.network/) [mail](mailto:a@b.c) [top](#quick-start)'

    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%s\n' \
        "[The image]($BLOB/docs/image.md): see [running]($BLOB/docs/image.md#running-the-image)." \
        "[MIT]($BLOB/LICENSE) [site](https://aioz.network/) [mail](mailto:a@b.c) [top](#quick-start)")" ]
}

@test "replaces a Mermaid diagram with a link to the README on GitHub, and keeps other code" {
    hub_readme 'Intro.' '```mermaid' 'flowchart TB' '    a --> b' '```' \
        '```sh' 'docker run x' '```'

    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%s\n' 'Intro.' \
        "[The diagram of the containers]($BLOB/README.md), on GitHub." \
        '```sh' 'docker run x' '```')" ]
}

@test "turns the GitHub alerts into bold labels" {
    hub_readme '> [!WARNING]' '> Back the key up.' '> [!NOTE]' '> [!TIP]' \
        '> [!IMPORTANT]' '> [!CAUTION]' '> [!OTHER]'

    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%s\n' '> **Warning**' '> Back the key up.' \
        '> **Note**' '> **Tip**' '> **Important**' '> **Caution**' '> [!OTHER]')" ]
}

# Docker Hub refuses a full description over 25000 characters (schema
# repo_creation_request, docs.docker.com/reference/api/hub/latest/).
@test "fails on an overview over 25000 characters, and prints nothing" {
    hub_readme "$(head -c 25001 /dev/zero | tr '\0' x)"

    [ "$status" -eq 1 ]
    [[ "$output" == *"over 25000 characters"* ]]
    [[ "$output" != *xxx* ]]
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
    local left
    left=$(grep -nE '\]\([^):#/][^):]*\)|^```mermaid|^> \[!' <<< "$output" || true)
    [ -z "$left" ] || {
        printf 'left in the overview:\n%s\n' "$left"
        false
    }
    grep -qF "$BLOB/" <<< "$output"
}

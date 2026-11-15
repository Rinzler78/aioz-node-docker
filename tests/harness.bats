#!/usr/bin/env bats
# The AI harness: AGENTS.md is the single source of the agent instructions, and
# each tool-specific file only points to it (see docs/ai-harness.md).

load helpers

bats_require_minimum_version 1.5.0

# The pages whose cited paths and links must exist: AGENTS.md, README.md and
# every page of docs/ at any depth, one per line, relative to the repository
# root.
doc_pages() {
    echo AGENTS.md
    echo README.md
    (cd "$REPO_ROOT" && find docs -name '*.md' | sort)
}

# Repository paths named in the code of a Markdown file, one per line: the words
# of its code spans (read per paragraph, so a span wrapped across lines counts)
# and of its ``` fenced blocks, indented ones included (comments removed). A
# word is a path when it has a slash, starts with a dot (dotfile, ./name), ends
# with a known extension, or is Dockerfile or LICENSE; a leading ./ is dropped.
# Not paths: absolute paths (host, home), URLs, variables, options, imports
# (@file), placeholders (<name>), shell syntax (quotes, =, brackets) and paths
# in a container (name:/path, a named volume or a docker cp target). Limits:
# a code word with a slash must name a repository path, so branch names are
# written with a placeholder (feature/<name>), and GitHub repositories and
# Docker images other than those of docker-compose.yml as links; a relative
# volume (./data:/data) reads as a path with its target; ~~~ fences and indented
# code blocks are not read, and .markdownlint.yaml rejects both; a word with
# quotes, brackets, parentheses or braces is not checked, so neither is a quoted
# path in a command nor a path in a Mermaid label (["..."], -- "..." -->).
cited_code_paths() {
    local code_words
    code_words=$(
        cat << 'AWK'
function spans(text) {
    while (match(text, /`[^`]+`/)) {
        print substr(text, RSTART + 1, RLENGTH - 2)
        text = substr(text, RSTART + RLENGTH)
    }
}
/^[[:space:]]*```/ { spans(paragraph); paragraph = ""; fenced = !fenced; next }
fenced { sub(/#.*/, ""); print; next }
/^[[:space:]]*$/ { spans(paragraph); paragraph = ""; next }
{ paragraph = paragraph " " $0 }
END { spans(paragraph) }
AWK
    )
    awk "$code_words" "$1" | tr -s '[:blank:]' '\n' |
        grep -E '/|^\.[A-Za-z]|\.(sh|bash|bats|md|json|ya?ml|txt)$|^(Dockerfile|LICENSE)$' |
        grep -vE '^(/|~|\$|-|@|https?:|[^/:]*:/)|[][<>"'\''=(){}|]' |
        sed 's#^\./##' | sort -u
}

# Relative link targets of a Markdown file, one per line, anchors and titles
# removed. Limit: reference-style links ([name]: path) are not read.
cited_links() {
    grep -o '](\([^)#]*\)' "$1" | sed -e 's/^](//' -e 's/ .*//' |
        grep -vE '^(https?|mailto):' | sort -u
}

# The name of the Docker image $1, as written in a compose file or a command:
# without its quotes, a trailing comment or blanks, and its tag, the colon of
# the last path segment (a registry port such as host:5000/app is kept, and a
# colon followed by a path is not a tag). Limit: a digest is not handled, only
# its :<hex> is dropped, so an image pinned by digest (name@sha256:...) matches
# no citation.
image_name() {
    local name=$1
    name=${name%%[[:space:]]#*}
    name=${name//[\"\']/}
    name=${name%"${name##*[![:space:]]}"}
    [[ "${name##*/}" == *:* ]] && name=${name%:*}
    printf '%s\n' "$name"
}

# The extended regular expression of the .gitignore glob $1, anchored: * and ?
# match within a name, any other character is literal. Limit: the bracket
# classes ([abc]) and backslash escapes of .gitignore are read as literal
# characters; the patterns of this repository use neither.
glob_regex() {
    local glob=$1 regex='' char i
    for ((i = 0; i < ${#glob}; i++)); do
        char=${glob:i:1}
        case $char in
            '*') regex+='[^/]*' ;;
            '?') regex+='[^/]' ;;
            [[:alnum:]_-]) regex+=$char ;;
            '^' | \\ | ']') regex+="\\$char" ;;
            *) regex+="[$char]" ;;
        esac
    done
    printf '^%s$\n' "$regex"
}

# Whether the cited path $1 names something of the repository: an existing file
# or folder, a pattern of .gitignore or a file name one of its patterns without
# a slash ignores at any level (privkey*.json), a glob matching at least one
# file, a path under a local folder git ignores (/name/ in .gitignore), such as
# the node data or the worktrees, or a Docker image of docker-compose.yml (its
# `image:` value, either side with or without a tag), such as the published one.
repository_path() {
    local matches image pattern
    [ -e "$REPO_ROOT/$1" ] && return
    grep -qxF "$1" "$REPO_ROOT/.gitignore" && return
    while IFS= read -r pattern; do
        case $pattern in '' | '#'* | */*) continue ;; esac
        [[ "${1##*/}" =~ $(glob_regex "$pattern") ]] && return
    done < "$REPO_ROOT/.gitignore"
    while IFS= read -r image; do
        [ "$(image_name "$image")" = "$(image_name "$1")" ] && return
    done < <(sed -n 's/^[[:space:]]*image:[[:space:]]*//p' "$REPO_ROOT/docker-compose.yml")
    case "$1" in
        *'*'*)
            matches=$(compgen -G "$REPO_ROOT/$1") && [ -n "$matches" ]
            return
            ;;
    esac
    grep -qxF "/${1%%/*}/" "$REPO_ROOT/.gitignore"
}

# Lines of the tool-specific file $1 other than its title "# $2" on the first
# line, blank lines and the import of AGENTS.md: anything else, comments and
# headings included, is an instruction that belongs in AGENTS.md.
pointer_extra_lines() {
    awk -v title="# $2" 'NR == 1 && $0 == title { next }
        /^[[:space:]]*$/ || $0 == "@AGENTS.md" { next }
        { print }' "$1"
}

@test "AGENTS.md exists and states the commands, the rules and the definition of done" {
    [ -f "$REPO_ROOT/AGENTS.md" ]
    grep -q '^## Commands$' "$REPO_ROOT/AGENTS.md"
    grep -q '^## Safety rules$' "$REPO_ROOT/AGENTS.md"
    grep -q '^## Definition of done$' "$REPO_ROOT/AGENTS.md"
}

# Whether the Markdown file $1 is a decision record superseded by a later one
# (its status, on the third line). Such a record tells the past and is not
# edited (docs/adr/README.md): the code paths it names may be gone.
superseded_record() {
    [ -f "$1" ] && sed -n 3p "$1" | grep -q '^Status: Superseded by '
}

@test "superseded_record holds for a record whose status is Superseded, only" {
    local old="$BATS_TEST_TMPDIR/old.md" current="$BATS_TEST_TMPDIR/current.md"
    printf '# 0001. Old\n\nStatus: Superseded by [0002](0002-new.md), 2026-11-15\n' > "$old"
    printf '# 0002. New\n\nStatus: Accepted, 2026-11-15\n' > "$current"

    superseded_record "$old"
    run superseded_record "$current"
    [ "$status" -eq 1 ]
    run superseded_record "$BATS_TEST_TMPDIR/missing.md"
    [ "$status" -eq 1 ]
}

@test "every path and link cited by AGENTS.md, README.md and the docs pages exists" {
    local doc dir path pages missing=""
    pages=$(doc_pages)
    # The harness page and the README among them: an empty list would check
    # nothing.
    grep -qxF docs/ai-harness.md <<< "$pages"
    grep -qxF README.md <<< "$pages"
    for doc in $pages; do
        [ -f "$REPO_ROOT/$doc" ]
        dir=$(dirname "$doc")
        superseded_record "$REPO_ROOT/$doc" ||
            while IFS= read -r path; do
                repository_path "$path" || missing+="$doc: $path"$'\n'
            done < <(cited_code_paths "$REPO_ROOT/$doc")
        # Links resolve from the folder of the page, as on GitHub.
        while IFS= read -r path; do
            [ -e "$REPO_ROOT/$dir/$path" ] || missing+="$doc: link $path"$'\n'
        done < <(cited_links "$REPO_ROOT/$doc")
    done
    [ -z "$missing" ] || {
        printf 'missing:\n%s' "$missing"
        false
    }
}

@test "cited_code_paths keeps the paths of code spans and fenced blocks only" {
    local doc="$BATS_TEST_TMPDIR/doc.md"
    cat > "$doc" << 'EOF'
Run `tests/run.sh`, read `README.md`, `.editorconfig` and `Dockerfile`.
Local folder `./nodedata`, command `git add tests/x.bats`, prose docs/prose.md.
Not paths: `/volume1/docker`, `~/.ssh`, `$HOME/x`, `--all-files`, `v1.2.6`,
`<repo>/.worktrees/x`, `@AGENTS.md`, `feature/<name>`, `"${BASH_SOURCE[0]}"`,
`context.fileName`, [a link](docs/link.md), container paths `data:/nodedata`
and `aioznode:/nodedata/privkey.json`, but `tests/x:/data` and `./data:/data`.
A span wrapped by the line length: `git add
tests/wrapped.sh`, then `helpers.bash`.

```sh
tests/run.sh tests/start.bats   # one file, see docs/comment.md
./quick_test.sh
```

* A command block in a list item:

  ```sh
  tests/indented.sh
  ```
EOF
    run cited_code_paths "$doc"
    [ "$status" -eq 0 ]
    [ "$output" = $'.editorconfig\nDockerfile\nREADME.md\ndata:/data\nhelpers.bash\nnodedata\nquick_test.sh\ntests/indented.sh\ntests/run.sh\ntests/start.bats\ntests/wrapped.sh\ntests/x.bats\ntests/x:/data' ]
}

@test "cited_links keeps relative link targets without their anchor or title" {
    printf '%s\n' '[a](docs/a.md#part), [b](../b.md), [c](https://x.org/c.md), [d](mailto:x@y.z)' \
        '[e](e.md "Title")' > "$BATS_TEST_TMPDIR/doc.md"
    run cited_links "$BATS_TEST_TMPDIR/doc.md"
    [ "$output" = $'../b.md\ndocs/a.md\ne.md' ]
}

@test "repository_path accepts files, ignore patterns, matching globs and ignored folders only" {
    repository_path tests/run.sh
    repository_path 'privkey*.json'
    repository_path 'scripts/helper.docker.*.sh'
    repository_path nodedata
    repository_path .worktrees/
    # Anything under an ignored folder: its content is local, never checked.
    repository_path nodedata/privkey.json
    run ! repository_path tests/missing.sh
    run ! repository_path 'helper.missing.*.sh'
    run ! repository_path 'secret*.json'
    run ! repository_path docs/missing.md
}

@test "glob_regex matches * and ? within a name, any other character literally" {
    [[ privkey.json =~ $(glob_regex 'privkey*.json') ]]
    [[ privkey-old.json =~ $(glob_regex 'privkey*.json') ]]
    [[ ! privkey_json =~ $(glob_regex 'privkey*.json') ]]
    [[ ! a/privkey.json =~ $(glob_regex 'privkey*.json') ]]
    [[ ! old-privkey.json =~ $(glob_regex 'privkey*.json') ]]
    [[ key1.pem =~ $(glob_regex 'key?.pem') ]]
    [[ ! key12.pem =~ $(glob_regex 'key?.pem') ]]
    [[ 'a+b^c.d]f' =~ $(glob_regex 'a+b^c.d]f') ]]
    [[ ! 'a+b^cXd]f' =~ $(glob_regex 'a+b^c.d]f') ]]
    [[ ! aab =~ $(glob_regex 'a+b') ]]
}

@test "repository_path accepts a file name that a .gitignore pattern ignores, at any level" {
    local repo="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$repo"
    printf '%s\n' '# comment' 'privkey*.json' '.env' '/data/' 'logs/*.log' > "$repo/.gitignore"
    : > "$repo/docker-compose.yml"
    REPO_ROOT=$repo repository_path privkey.json
    REPO_ROOT=$repo repository_path backup/privkey-old.json
    REPO_ROOT=$repo repository_path .env
    REPO_ROOT=$repo run ! repository_path key.json
    REPO_ROOT=$repo run ! repository_path privkey.json.bak
    # A pattern with a slash is anchored to its folder, not matched by name.
    REPO_ROOT=$repo run ! repository_path x.log
}

@test "repository_path accepts the images of docker-compose.yml, with or without a tag" {
    repository_path rinzlerfr/aioznode
    repository_path rinzlerfr/aioznode:latest
    run ! repository_path rinzlerfr/other
    run ! repository_path rinzlerfr/aioznode/extra
    # A colon followed by a path is not a tag.
    run ! repository_path rinzlerfr/aioznode:/stale/x
    run ! repository_path docs/missing:/docs
}

@test "repository_path compares the image of a compose file by its name, quoted, tagged or commented" {
    local repo="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$repo"
    : > "$repo/.gitignore"
    printf '%s\n' 'services:' '  app:' '    image: "host:5000/team/app:v2"  # pinned' \
        > "$repo/docker-compose.yml"
    REPO_ROOT=$repo repository_path host:5000/team/app
    REPO_ROOT=$repo repository_path host:5000/team/app:v1
    REPO_ROOT=$repo run ! repository_path host/team/app
    REPO_ROOT=$repo run ! repository_path host:5000/team/app:/x
}

@test "image_name drops the tag of an image, never a registry port or a path" {
    [ "$(image_name rinzlerfr/aioznode)" = rinzlerfr/aioznode ]
    [ "$(image_name rinzlerfr/aioznode:1.2.6)" = rinzlerfr/aioznode ]
    [ "$(image_name '"rinzlerfr/aioznode:1.2.6"  # pinned')" = rinzlerfr/aioznode ]
    [ "$(image_name "'rinzlerfr/aioznode'")" = rinzlerfr/aioznode ]
    [ "$(image_name 'rinzlerfr/aioznode  ')" = rinzlerfr/aioznode ]
    [ "$(image_name host:5000/team/app)" = host:5000/team/app ]
    [ "$(image_name host:5000/team/app:v2)" = host:5000/team/app ]
    [ "$(image_name rinzlerfr/aioznode:/stale/x)" = rinzlerfr/aioznode:/stale/x ]
}

@test "CLAUDE.md only imports AGENTS.md" {
    [ -f "$REPO_ROOT/CLAUDE.md" ]
    grep -qx '@AGENTS.md' "$REPO_ROOT/CLAUDE.md"
    run pointer_extra_lines "$REPO_ROOT/CLAUDE.md" 'Claude Code'
    [ -z "$output" ]
}

@test "pointer_extra_lines reports any instruction, as text, heading or comment" {
    printf '%s\n' '# Claude Code' '' '@AGENTS.md' 'Always run the tests.' \
        '# Never commit' '<!-- skip the hooks -->' > "$BATS_TEST_TMPDIR/CLAUDE.md"
    run pointer_extra_lines "$BATS_TEST_TMPDIR/CLAUDE.md" 'Claude Code'
    [ "$output" = $'Always run the tests.\n# Never commit\n<!-- skip the hooks -->' ]
    # A first line other than the title of the tool is an instruction too.
    printf '%s\n' '# Always skip the hooks' '@AGENTS.md' > "$BATS_TEST_TMPDIR/CLAUDE.md"
    run pointer_extra_lines "$BATS_TEST_TMPDIR/CLAUDE.md" 'Claude Code'
    [ "$output" = '# Always skip the hooks' ]
}

@test "the Gemini CLI settings only name AGENTS.md as the context file" {
    run jq -c . "$REPO_ROOT/.gemini/settings.json"
    [ "$status" -eq 0 ]
    [ "$output" = '{"context":{"fileName":"AGENTS.md"}}' ]
}

@test "git and the Docker build context leave out the node private key" {
    local line
    for line in /nodedata/ 'privkey*.json' .env; do
        grep -qxF "$line" "$REPO_ROOT/.gitignore"
    done
    # .dockerignore patterns are anchored at the context root: **/ for any depth.
    for line in nodedata/ '**/privkey*.json' '**/.env'; do
        grep -qxF "$line" "$REPO_ROOT/.dockerignore"
    done
}

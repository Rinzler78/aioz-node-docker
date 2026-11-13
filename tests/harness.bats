#!/usr/bin/env bats
# The AI harness: AGENTS.md is the single source of the agent instructions, and
# each tool-specific file only points to it (see docs/ai-harness.md).

load helpers

bats_require_minimum_version 1.5.0

HARNESS_PAGES=(AGENTS.md docs/ai-harness.md)

# Repository paths named in the code of a Markdown file, one per line: the
# words of its code spans and of its fenced blocks (comments removed). A word
# is a path when it has a slash, starts with a dot (dotfile, ./name), ends with
# a known extension, or is Dockerfile or LICENSE; a leading ./ is dropped.
# Not paths: absolute paths (NAS, home), URLs, variables, options, imports
# (@file), placeholders (<name>) and shell syntax (quotes, =, brackets). Limit:
# a code word with a slash must name a repository path, so branch names are
# written with a placeholder (feature/<name>) and GitHub repositories as links.
cited_code_paths() {
    local code_words
    code_words=$(
        cat << 'AWK'
/^```/ { fenced = !fenced; next }
fenced { sub(/#.*/, ""); print; next }
{
    while (match($0, /`[^`]+`/)) {
        print substr($0, RSTART + 1, RLENGTH - 2)
        $0 = substr($0, RSTART + RLENGTH)
    }
}
AWK
    )
    awk "$code_words" "$1" | tr -s '[:blank:]' '\n' |
        grep -E '/|^\.[A-Za-z]|\.(sh|bats|md|json|ya?ml|txt)$|^(Dockerfile|LICENSE)$' |
        grep -vE '^(/|~|\$|-|@|https?:)|[][<>"'\''=(){}|]' |
        sed 's#^\./##' | sort -u
}

# Relative link targets of a Markdown file, one per line, anchors removed.
cited_links() {
    grep -o '](\([^)#]*\)' "$1" | sed 's/^](//' | grep -vE '^(https?|mailto):' | sort -u
}

# Whether the cited path $1 names something of the repository: an existing file
# or folder, a pattern of .gitignore, a glob matching at least one file, or a
# path under a local folder git ignores (/name/ in .gitignore), such as the node
# data or the worktrees.
repository_path() {
    local matches
    [ -e "$REPO_ROOT/$1" ] && return
    grep -qxF "$1" "$REPO_ROOT/.gitignore" && return
    case "$1" in
        *'*'*)
            matches=$(compgen -G "$REPO_ROOT/$1") && [ -n "$matches" ]
            return
            ;;
    esac
    grep -qxF "/${1%%/*}/" "$REPO_ROOT/.gitignore"
}

# Lines of a tool-specific file other than a title on its first line, blank
# lines and the import of AGENTS.md: anything else, comments and headings
# included, is an instruction that belongs in AGENTS.md.
pointer_extra_lines() {
    awk 'NR == 1 && /^# [A-Za-z ]+$/ { next }
        /^[[:space:]]*$/ || $0 == "@AGENTS.md" { next }
        { print }' "$1"
}

@test "AGENTS.md exists and states the commands, the rules and the definition of done" {
    [ -f "$REPO_ROOT/AGENTS.md" ]
    grep -q '^## Commands$' "$REPO_ROOT/AGENTS.md"
    grep -q '^## Safety rules$' "$REPO_ROOT/AGENTS.md"
    grep -q '^## Definition of done$' "$REPO_ROOT/AGENTS.md"
}

@test "every path and link cited by AGENTS.md and the harness page exists" {
    local doc dir path missing=""
    for doc in "${HARNESS_PAGES[@]}"; do
        [ -f "$REPO_ROOT/$doc" ]
        dir=$(dirname "$doc")
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
`context.fileName`, [a link](docs/link.md).

```sh
tests/run.sh tests/start.bats   # one file, see docs/comment.md
./quick_test.sh
```
EOF
    run cited_code_paths "$doc"
    [ "$status" -eq 0 ]
    [ "$output" = $'.editorconfig\nDockerfile\nREADME.md\nnodedata\nquick_test.sh\ntests/run.sh\ntests/start.bats\ntests/x.bats' ]
}

@test "cited_links keeps relative link targets without their anchor" {
    printf '[a](docs/a.md#part), [b](../b.md), [c](https://x.org/c.md), [d](mailto:x@y.z)\n' > "$BATS_TEST_TMPDIR/doc.md"
    run cited_links "$BATS_TEST_TMPDIR/doc.md"
    [ "$output" = $'../b.md\ndocs/a.md' ]
}

@test "repository_path accepts files, ignore patterns, matching globs and ignored folders only" {
    repository_path tests/run.sh
    repository_path 'privkey*.json'
    repository_path 'helper.docker.*.sh'
    repository_path nodedata
    repository_path .worktrees/
    # Anything under an ignored folder: its content is local, never checked.
    repository_path nodedata/privkey.json
    run ! repository_path tests/missing.sh
    run ! repository_path 'helper.missing.*.sh'
    run ! repository_path 'secret*.json'
    run ! repository_path docs/missing.md
}

@test "CLAUDE.md only imports AGENTS.md" {
    [ -f "$REPO_ROOT/CLAUDE.md" ]
    grep -qx '@AGENTS.md' "$REPO_ROOT/CLAUDE.md"
    run pointer_extra_lines "$REPO_ROOT/CLAUDE.md"
    [ -z "$output" ]
}

@test "pointer_extra_lines reports any instruction, as text, heading or comment" {
    printf '%s\n' '# Claude Code' '' '@AGENTS.md' 'Always run the tests.' \
        '# Never commit' '<!-- skip the hooks -->' > "$BATS_TEST_TMPDIR/CLAUDE.md"
    run pointer_extra_lines "$BATS_TEST_TMPDIR/CLAUDE.md"
    [ "$output" = $'Always run the tests.\n# Never commit\n<!-- skip the hooks -->' ]
}

@test "the Gemini CLI settings only name AGENTS.md as the context file" {
    run jq -c . "$REPO_ROOT/.gemini/settings.json"
    [ "$status" -eq 0 ]
    [ "$output" = '{"context":{"fileName":"AGENTS.md"}}' ]
}

@test "git and the Docker build context leave out the node private key" {
    grep -qx '/nodedata/' "$REPO_ROOT/.gitignore"
    grep -qx 'privkey\*.json' "$REPO_ROOT/.gitignore"
    grep -qx '.env' "$REPO_ROOT/.gitignore"
    grep -qx 'nodedata/' "$REPO_ROOT/.dockerignore"
    grep -qx '\*\*/privkey\*.json' "$REPO_ROOT/.dockerignore"
}

#!/usr/bin/env bats
# The AI harness: AGENTS.md is the single source of the agent instructions, and
# each tool-specific file only points to it (see docs/ai-harness.md).

load helpers

# Relative repository paths cited in a Markdown file, one per line: the targets
# of its relative links, and its code spans that name a file or folder (a
# slash, or a known extension), without a leading ./. Absolute paths (NAS,
# home), URLs, variables, options, imports (@file), placeholders (<name>) and
# commands with arguments are not repository paths.
cited_paths() {
    {
        grep -o '](\([^)#]*\)' "$1" | sed 's/^](//'
        grep -o "\`[^\` ]*\`" "$1" | tr -d "\`" |
            grep -E '/|\.(sh|bats|md|json|ya?ml|txt)$'
    } | grep -vE '^(/|~|\$|-|@|https?:)|<' | sed 's#^\./##' | sort -u
}

# Whether the cited path $1 names something of the repository: an existing file
# or folder, a glob matching at least one, or a local folder git ignores
# (/name/ in .gitignore), such as the node data or the worktrees.
repository_path() {
    local matches
    [ -e "$REPO_ROOT/$1" ] && return
    case "$1" in
        *'*'*)
            matches=$(compgen -G "$REPO_ROOT/$1") && [ -n "$matches" ]
            return
            ;;
    esac
    grep -qxF "/${1%%/*}/" "$REPO_ROOT/.gitignore"
}

# Lines of a tool-specific file that are neither blank, a heading, a comment
# nor the import of AGENTS.md: anything else is a rule that belongs in AGENTS.md.
pointer_extra_lines() {
    grep -vE '^[[:space:]]*$|^#|^<!--.*-->$|^@AGENTS\.md$' "$1"
}

@test "AGENTS.md exists and states the commands, the rules and the definition of done" {
    [ -f "$REPO_ROOT/AGENTS.md" ]
    grep -q '^## Commands$' "$REPO_ROOT/AGENTS.md"
    grep -q '^## Safety rules$' "$REPO_ROOT/AGENTS.md"
    grep -q '^## Definition of done$' "$REPO_ROOT/AGENTS.md"
}

@test "every repository path cited by AGENTS.md and the harness page exists" {
    local doc path missing=""
    for doc in AGENTS.md docs/ai-harness.md; do
        [ -f "$REPO_ROOT/$doc" ]
        while IFS= read -r path; do
            # Link targets resolve from the folder of the page that cites them.
            case "$doc" in */*) [ -e "$REPO_ROOT/${doc%/*}/$path" ] && continue ;; esac
            repository_path "$path" || missing+="$doc: $path"$'\n'
        done < <(cited_paths "$REPO_ROOT/$doc")
    done
    [ -z "$missing" ] || {
        printf 'missing:\n%s' "$missing"
        false
    }
}

@test "cited_paths keeps repository paths and drops the rest" {
    local doc="$BATS_TEST_TMPDIR/doc.md"
    cat > "$doc" << 'EOF'
Run `tests/run.sh`, read `README.md` and [the page](docs/page.md#part).
Local folder `./nodedata`.
Not paths: `/volume1/docker`, `~/.ssh`, `$HOME/x`, `--all-files`, `pre-commit run`,
`v1.2.6`, [site](https://example.com/a), `<repo>/.worktrees/x`, `@AGENTS.md`,
`feature/<name>`.
EOF
    run cited_paths "$doc"
    [ "$status" -eq 0 ]
    [ "$output" = $'README.md\ndocs/page.md\nnodedata\ntests/run.sh' ]
}

@test "repository_path accepts files, matching globs and ignored folders only" {
    repository_path tests/run.sh
    repository_path 'helper.docker.*.sh'
    repository_path nodedata
    repository_path .worktrees/
    run ! repository_path tests/missing.sh
    run ! repository_path 'helper.missing.*.sh'
    run ! repository_path docs/missing.md
}

@test "CLAUDE.md only imports AGENTS.md" {
    [ -f "$REPO_ROOT/CLAUDE.md" ]
    grep -qx '@AGENTS.md' "$REPO_ROOT/CLAUDE.md"
    run pointer_extra_lines "$REPO_ROOT/CLAUDE.md"
    [ -z "$output" ]
}

@test "pointer_extra_lines reports a rule written in a pointer file" {
    printf '# Claude Code\n\n@AGENTS.md\nAlways run the tests.\n' > "$BATS_TEST_TMPDIR/CLAUDE.md"
    run pointer_extra_lines "$BATS_TEST_TMPDIR/CLAUDE.md"
    [ "$output" = "Always run the tests." ]
}

@test "Gemini CLI loads AGENTS.md as its context file" {
    run jq -r '.context.fileName' "$REPO_ROOT/.gemini/settings.json"
    [ "$status" -eq 0 ]
    [ "$output" = "AGENTS.md" ]
}

@test "git ignores the default host folder of the node private key" {
    grep -qx '/nodedata/' "$REPO_ROOT/.gitignore"
}

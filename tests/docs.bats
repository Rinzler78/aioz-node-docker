#!/usr/bin/env bats
# The documentation covers the repository: docs/architecture.md names every
# `*.sh` script, workflow and Dockerfile, the compose file and the Makefile, so
# a new one cannot stay off the map; the decision records of docs/adr/ keep
# their format, their numbering and their index.

load helpers

# The files the architecture page must name, one per line, listed from the
# file system (never from the page), a link counting as a file:
# - every `*.sh` script, at any depth;
# - every Dockerfile, at any depth: `Dockerfile*`, `*.Dockerfile` and
#   `Containerfile`, as in tests/helper.docker.bats, but no `*.dockerignore`;
#   a copy such as Dockerfile.bak counts too: it has no place in the
#   repository, and the failure shows it;
# - every workflow GitHub runs, directly in .github/workflows/;
# - the compose file and the Makefile.
# Left out: git, the worktrees and the node data folder, which are not the
# repository. The test doubles of .github/scripts/tests/fakes/ have no
# extension: the page names their folder.
architecture_files() {
    local workflows=./.github/workflows
    (cd "$REPO_ROOT" && find . \( -path ./.git -o -path ./.worktrees \
        -o -path ./nodedata \) -prune -o \( -type f -o -type l \) \
        \( -name '*.sh' \
        -o -path "$workflows/*.y*ml" ! -path "$workflows/*/*" \
        -o \( -name 'Dockerfile*' -o -name '*.Dockerfile' \
        -o -name Containerfile \) ! -name '*.dockerignore' \) -print |
        sed 's#^\./##' && printf '%s\n' docker-compose.yml Makefile) | sort
}

@test "docs/architecture.md names every *.sh script, workflow and Dockerfile" {
    local page="$REPO_ROOT/docs/architecture.md" file files missing=""
    [ -f "$page" ]
    files=$(architecture_files)
    # Each folder is listed: an empty glob would check nothing.
    for file in tools/start.sh nas/delivery-watch.sh scripts/quick_test.sh \
        .github/scripts/push-latest.sh .github/workflows/tests.yml \
        tests/run.sh tests/Dockerfile Makefile; do
        grep -qxF "$file" <<< "$files"
    done
    # Named as a code span, with its full path.
    for file in $files; do
        grep -qF "\`$file\`" "$page" || missing+="$file"$'\n'
    done
    [ -z "$missing" ] || {
        printf 'not in docs/architecture.md:\n%s' "$missing"
        false
    }
}

# The decision records of docs/adr/, one path per line in number order, listed
# from the file system: every file but the index, at any depth, so a stray
# file or a record in a subfolder fails the naming test.
adr_files() {
    (cd "$REPO_ROOT/docs/adr" && find . -type f ! -path ./README.md |
        sed 's#^\./##' | sort)
}

# The status a record must carry on its third line, right after its title: a
# state and a date. A superseded record links to the record that replaced it.
STATUS='^Status: (Proposed|Accepted|Deprecated|Superseded by \[([0-9]{4})\]\(([0-9]{4})-[a-z0-9-]+\.md\)), [0-9]{4}-[0-9]{2}-[0-9]{2}$'

@test "every decision record is named NNNN-title.md, numbered from 0001 without gap" {
    local files file expected=1
    files=$(adr_files)
    [ -n "$files" ]
    for file in $files; do
        [[ "$file" =~ ^([0-9]{4})-[a-z0-9-]+\.md$ ]] || {
            echo "badly named: $file"
            false
        }
        [ "$((10#${BASH_REMATCH[1]}))" -eq "$expected" ] || {
            echo "number $expected missing before $file"
            false
        }
        expected=$((expected + 1))
    done
}

@test "every decision record has its title, a dated status, then context, decision and consequences" {
    local files file number status page sections
    files=$(adr_files)
    [ -n "$files" ]
    for file in $files; do
        page="$REPO_ROOT/docs/adr/$file"
        number=${file%%-*}
        # The title carries the number of the file.
        head -n 1 "$page" | grep -qE "^# $number\. [A-Z]" || {
            echo "$file: title"
            false
        }
        status=$(sed -n 3p "$page")
        [[ "$status" =~ $STATUS ]] || {
            echo "$file: status on line 3: $status"
            false
        }
        # A record is superseded by a later one, under its own number.
        if [ -n "${BASH_REMATCH[2]}" ]; then
            [ "${BASH_REMATCH[2]}" = "${BASH_REMATCH[3]}" ] &&
                [ "$((10#${BASH_REMATCH[2]}))" -gt "$((10#$number))" ] || {
                echo "$file: superseded by ${BASH_REMATCH[2]}"
                false
            }
        fi
        sections=$(grep '^## ' "$page" | tr '\n' '|')
        [ "$sections" = '## Context|## Decision|## Consequences|' ] || {
            echo "$file: sections $sections"
            false
        }
    done
}

# Limit: an entry inside an HTML comment of the index is read as listed.
@test "the index of docs/adr lists every decision record by its title, in order, and nothing else" {
    local index="$REPO_ROOT/docs/adr/README.md" listed entry file title
    [ -f "$index" ]
    listed=$(grep -oE '\]\([0-9]{4}-[a-z0-9-]+\.md\)' "$index" |
        sed -e 's/^](//' -e 's/)$//')
    [ "$listed" = "$(adr_files)" ] || {
        printf 'index:\n%s\nfiles:\n%s\n' "$listed" "$(adr_files)"
        false
    }
    # Each entry reads as the title of its record.
    while IFS= read -r entry; do
        file=${entry##*](}
        file=${file%)}
        title=$(head -n 1 "$REPO_ROOT/docs/adr/$file")
        [ "[${title#\# }]($file)" = "$entry" ] || {
            echo "index entry $entry, title $title"
            false
        }
    done < <(grep -oE '\[[^]]+\]\([0-9]{4}-[a-z0-9-]+\.md\)' "$index")
}

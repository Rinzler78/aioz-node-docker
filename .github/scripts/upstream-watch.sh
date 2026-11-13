#!/bin/bash
# Watch the AIOZ upstream while the DePIN hub is down and CLI v1.2.6 is broken.
# Reports a change (hub state, new release, activity on the upstream issue or
# repository) as a comment on a tracking issue of this repository. A change is
# measured against the last report on that issue, so a lasting state is
# reported once; without a report, against the outage (hubs down, KNOWN_TAG,
# issue open). Silent when nothing changed. Fails (exit 1, nothing posted) when
# the GitHub API errors, so a broken watch shows as a red run instead of a
# false alert.
# DRY_RUN=1 prints the comment instead of posting it.

UPSTREAM_REPO="${UPSTREAM_REPO:-AIOZNetwork/aioz-depin-cli}"
KNOWN_TAG="${KNOWN_TAG:-v1.2.6}"
WATCH_ISSUE="${WATCH_ISSUE:-10}"
WINDOW_HOURS="${WINDOW_HOURS:-25}"
HUB_URLS="${HUB_URLS:-https://main-hub.aioz.network/ https://delivery-main-hub.aioz.network/worker/version https://hub.aioz.network/}"
CONTROL_URL="${CONTROL_URL:-https://wallet.aioz.network/}"
TRACKING_TITLE="${TRACKING_TITLE:-AIOZ upstream watch}"

http_code() {
    curl -s -o /dev/null -m 20 -w '%{http_code}' "$1"
}

# The control URL proves our network works when it answers 2xx-4xx.
answers() {
    [[ "$1" =~ ^[234][0-9][0-9]$ ]]
}

# State of a hub from its HTTP code: down (000, no answer; Cloudflare 52x,
# origin down), up (2xx, 3xx) or error (the origin answers with an error). Codes
# of one state are equivalent: main-hub answers 404 or 415 to the same request.
hub_state() {
    case "$1" in
        000 | 52[0-9]) echo down ;;
        [23][0-9][0-9]) echo up ;;
        *) echo error ;;
    esac
}

# Value of a line of the last report: "- `<url>`: <code>" with prefix
# "- `<url>`: ", "### Latest release: <tag> ..." with "### Latest release: ".
# First word after the prefix; empty when the report has no such line.
reported() {
    local line
    line=$(grep -F -m 1 -- "$1" <<< "$2") || return 0
    line="${line#"$1"}"
    echo "${line%% *}"
}

# gh api; on error, logs it and returns 1. Callers must `|| return 1`: an API
# error is not an upstream change. gh prints the error JSON on stdout.
api() {
    local out
    if ! out=$(gh api "$@"); then
        echo "ERROR: gh api $1 failed: $out" >&2
        return 1
    fi
    printf '%s\n' "$out"
}

upstream_watch() {
    local since changes=() report="" control hub_lines="" url code release tag
    local state comments commits body issue last previous
    # GNU date (runner), BSD date (local macOS run). An empty window would report
    # the whole history as new, so stop instead.
    since=$(date -u -d "$WINDOW_HOURS hours ago" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null ||
        date -u -v-"${WINDOW_HOURS}"H +%Y-%m-%dT%H:%M:%SZ 2> /dev/null)
    if [ -z "$since" ]; then
        echo "ERROR: cannot compute the start of the $WINDOW_HOURS hours window" >&2
        return 1
    fi

    # 0. Last report: the open tracking issue's last comment, or its body.
    issue=$(gh issue list --state open --search "\"$TRACKING_TITLE\" in:title" --json number --jq '.[0].number') || return 1
    if [ -n "$issue" ]; then
        last=$(gh issue view "$issue" --json body,comments --jq '[.body] + [.comments[].body] | last') || return 1
    fi

    # 1. Hub. Only trusted when the control URL answers (our network is fine).
    control=$(http_code "$CONTROL_URL")
    for url in $HUB_URLS; do
        code=$(http_code "$url")
        hub_lines+="- \`$url\`: $code"$'\n'
        previous=$(reported "- \`$url\`: " "$last")
        if answers "$control" && [ "$(hub_state "$code")" != "$(hub_state "${previous:-000}")" ]; then
            changes+=("hub")
        fi
    done
    report+="### Hub (control \`$CONTROL_URL\`: $control)"$'\n'"$hub_lines"
    answers "$control" || report+="Control URL not answering: hub result ignored."$'\n'

    # 2. Latest release (one call: tag and page).
    release=$(api "repos/$UPSTREAM_REPO/releases/latest" --jq '"\(.tag_name) \(.html_url)"') || return 1
    tag="${release%% *}"
    report+=$'\n'"### Latest release: $tag (known: $KNOWN_TAG)"$'\n'
    previous=$(reported "### Latest release: " "$last")
    if [ "$tag" != "${previous:-$KNOWN_TAG}" ]; then
        changes+=("release")
        report+="${release#* }"$'\n'
    fi

    # 3. Upstream issue and repository activity since the last window.
    # Mentions are broken (zero-width space after @) so quoting a comment does not
    # notify its author.
    state=$(api "repos/$UPSTREAM_REPO/issues/$WATCH_ISSUE" --jq '.state') || return 1
    comments=$(api "repos/$UPSTREAM_REPO/issues/$WATCH_ISSUE/comments" --paginate \
        --jq ".[] | select(.created_at > \"$since\") | \"- \(.user.login), \(.created_at): \(.body | split(\"\n\")[0] | .[0:200] | gsub(\"@\"; \"@​\")) (\(.html_url))\"") || return 1
    commits=$(api "repos/$UPSTREAM_REPO/commits?since=$since" --paginate \
        --jq '.[] | "- \(.commit.author.date) \(.commit.message | split("\n")[0] | gsub("@"; "@​")) (\(.html_url))"') || return 1

    report+=$'\n'"### Issue $UPSTREAM_REPO#$WATCH_ISSUE: $state"$'\n'
    [ -n "$comments" ] && report+="New comments since $since:"$'\n'"$comments"$'\n'
    previous=$(reported "### Issue $UPSTREAM_REPO#$WATCH_ISSUE: " "$last")
    [ "$state" != "${previous:-open}" ] && changes+=("issue-state")
    [ -n "$comments" ] && changes+=("issue-comments")

    report+=$'\n'"### Commits since $since"$'\n'"${commits:-none}"$'\n'
    [ -n "$commits" ] && changes+=("commits")

    if [ ${#changes[@]} -eq 0 ]; then
        echo "No change."
        echo "$report"
        return 0
    fi

    body="Upstream change detected: $(printf '%s\n' "${changes[@]}" | sort -u | paste -sd, -)"$'\n\n'"$report"$'\n'"Next step: re-run the hotfix spikes (start path wrapper vs aioz-io, health check, quick_test)."
    echo "$body"

    [ "${DRY_RUN:-0}" = "1" ] && return 0

    if [ -z "$issue" ]; then
        gh issue create --title "$TRACKING_TITLE" --body "$body"
    else
        gh issue comment "$issue" --body "$body"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    upstream_watch "$@"
fi

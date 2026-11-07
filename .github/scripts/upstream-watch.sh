#!/bin/bash
# Watch the AIOZ upstream while the DePIN hub is down and CLI v1.2.6 is broken.
# Reports a change (hub answering again, new release, activity on the upstream
# issue or repository) as a comment on a tracking issue of this repository.
# Silent when nothing changed. Fails (exit 1, nothing posted) when the GitHub
# API errors, so a broken watch shows as a red run instead of a false alert.
# DRY_RUN=1 prints the comment instead of posting it.

UPSTREAM_REPO="${UPSTREAM_REPO:-AIOZNetwork/aioz-depin-cli}"
KNOWN_TAG="${KNOWN_TAG:-v1.2.6}"
WATCH_ISSUE="${WATCH_ISSUE:-10}"
WINDOW_HOURS="${WINDOW_HOURS:-25}"
HUB_URLS="${HUB_URLS:-https://main-hub.aioz.network/ https://delivery-main-hub.aioz.network/worker/version https://hub.aioz.network/}"
CONTROL_URL="${CONTROL_URL:-https://wallet.aioz.network/}"
TRACKING_TITLE="${TRACKING_TITLE:-AIOZ upstream watch}"

# GNU date (runner), BSD date (local macOS run). An empty window would report
# the whole history as new, so stop instead.
since=$(date -u -d "$WINDOW_HOURS hours ago" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null ||
    date -u -v-"${WINDOW_HOURS}"H +%Y-%m-%dT%H:%M:%SZ 2> /dev/null)
if [ -z "$since" ]; then
    echo "ERROR: cannot compute the start of the $WINDOW_HOURS hours window" >&2
    exit 1
fi
changes=()
report=""

http_code() {
    curl -s -o /dev/null -m 20 -w '%{http_code}' "$1"
}

# An origin answers when the code is 2xx-4xx. 000 is no answer at all;
# 5xx (Cloudflare 52x included) is an origin down or failing.
answers() {
    [[ "$1" =~ ^[234][0-9][0-9]$ ]]
}

# gh api, or stop the whole run: an API error is not an upstream change.
api() {
    local out
    if ! out=$(gh api "$@" 2>&1); then
        echo "ERROR: gh api $1 failed: $out" >&2
        exit 1
    fi
    printf '%s\n' "$out"
}

# 1. Hub. Only trusted when the control URL answers (our network is fine).
control=$(http_code "$CONTROL_URL")
hub_lines=""
for url in $HUB_URLS; do
    code=$(http_code "$url")
    hub_lines+="- \`$url\`: $code"$'\n'
    if answers "$control" && answers "$code"; then
        changes+=("hub")
    fi
done
report+="### Hub (control \`$CONTROL_URL\`: $control)"$'\n'"$hub_lines"
answers "$control" || report+="Control URL not answering: hub result ignored."$'\n'

# 2. Latest release (one call: tag and page).
release=$(api "repos/$UPSTREAM_REPO/releases/latest" --jq '"\(.tag_name) \(.html_url)"') || exit 1
tag="${release%% *}"
report+=$'\n'"### Latest release: $tag (known: $KNOWN_TAG)"$'\n'
if [ "$tag" != "$KNOWN_TAG" ]; then
    changes+=("release")
    report+="${release#* }"$'\n'
fi

# 3. Upstream issue and repository activity since the last window.
# Mentions are broken (zero-width space after @) so quoting a comment does not
# notify its author.
state=$(api "repos/$UPSTREAM_REPO/issues/$WATCH_ISSUE" --jq '.state') || exit 1
comments=$(api "repos/$UPSTREAM_REPO/issues/$WATCH_ISSUE/comments" --paginate \
    --jq ".[] | select(.created_at > \"$since\") | \"- \(.user.login), \(.created_at): \(.body | split(\"\n\")[0] | .[0:200] | gsub(\"@\"; \"@​\")) (\(.html_url))\"") || exit 1
commits=$(api "repos/$UPSTREAM_REPO/commits?since=$since" \
    --jq '.[] | "- \(.commit.author.date) \(.commit.message | split("\n")[0] | gsub("@"; "@​")) (\(.html_url))"') || exit 1

report+=$'\n'"### Issue $UPSTREAM_REPO#$WATCH_ISSUE: $state"$'\n'
[ -n "$comments" ] && report+="New comments since $since:"$'\n'"$comments"$'\n'
[ "$state" != "open" ] && changes+=("issue-state")
[ -n "$comments" ] && changes+=("issue-comments")

report+=$'\n'"### Commits since $since"$'\n'"${commits:-none}"$'\n'
[ -n "$commits" ] && changes+=("commits")

if [ ${#changes[@]} -eq 0 ]; then
    echo "No change."
    echo "$report"
    exit 0
fi

body="Upstream change detected: $(printf '%s\n' "${changes[@]}" | sort -u | paste -sd, -)"$'\n\n'"$report"$'\n'"Next step: re-run the hotfix spikes (start path wrapper vs aioz-io, health check, quick_test)."
echo "$body"

[ "${DRY_RUN:-0}" = "1" ] && exit 0

issue=$(gh issue list --state open --search "\"$TRACKING_TITLE\" in:title" --json number --jq '.[0].number') || exit 1
if [ -z "$issue" ]; then
    gh issue create --title "$TRACKING_TITLE" --body "$body"
else
    gh issue comment "$issue" --body "$body"
fi

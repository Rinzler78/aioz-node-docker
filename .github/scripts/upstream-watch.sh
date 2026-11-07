#!/bin/bash
# Watch the AIOZ upstream while the DePIN hub is down and CLI v1.2.6 is broken.
# Reports a change (hub answering again, new release, activity on the upstream
# issue or repository) as a comment on a tracking issue of this repository.
# Silent when nothing changed. DRY_RUN=1 prints the comment instead of posting it.

UPSTREAM_REPO="${UPSTREAM_REPO:-AIOZNetwork/aioz-depin-cli}"
KNOWN_TAG="${KNOWN_TAG:-v1.2.6}"
WATCH_ISSUE="${WATCH_ISSUE:-10}"
WINDOW_HOURS="${WINDOW_HOURS:-25}"
HUB_URLS="${HUB_URLS:-https://main-hub.aioz.network/ https://delivery-main-hub.aioz.network/worker/version https://hub.aioz.network/}"
CONTROL_URL="${CONTROL_URL:-https://wallet.aioz.network/}"
TRACKING_TITLE="${TRACKING_TITLE:-AIOZ upstream watch}"

since=$(date -u -d "$WINDOW_HOURS hours ago" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null ||
    date -u -v-"${WINDOW_HOURS}"H +%Y-%m-%dT%H:%M:%SZ)
changes=()
report=""

http_code() {
    curl -s -o /dev/null -m 20 -w '%{http_code}' "$1"
}

# 1. Hub: 52x means the origin behind Cloudflare is down.
control=$(http_code "$CONTROL_URL")
hub_lines=""
for url in $HUB_URLS; do
    code=$(http_code "$url")
    hub_lines+="- \`$url\`: $code"$'\n'
    if [ "$control" != "000" ] && [[ "$code" != 52? ]]; then
        changes+=("hub")
    fi
done
report+="### Hub (control \`$CONTROL_URL\`: $control)"$'\n'"$hub_lines"

# 2. Latest release.
tag=$(gh api "repos/$UPSTREAM_REPO/releases/latest" --jq '.tag_name' 2> /dev/null)
report+=$'\n'"### Latest release: ${tag:-unknown} (known: $KNOWN_TAG)"$'\n'
if [ -n "$tag" ] && [ "$tag" != "$KNOWN_TAG" ]; then
    changes+=("release")
    report+="$(gh api "repos/$UPSTREAM_REPO/releases/latest" --jq '.html_url')"$'\n'
fi

# 3. Upstream issue and repository activity since the last window.
state=$(gh api "repos/$UPSTREAM_REPO/issues/$WATCH_ISSUE" --jq '.state' 2> /dev/null)
comments=$(gh api "repos/$UPSTREAM_REPO/issues/$WATCH_ISSUE/comments" --paginate \
    --jq ".[] | select(.created_at > \"$since\") | \"- \(.user.login), \(.created_at): \(.body | split(\"\n\")[0] | .[0:200]) (\(.html_url))\"" 2> /dev/null)
commits=$(gh api "repos/$UPSTREAM_REPO/commits?since=$since" \
    --jq '.[] | "- \(.commit.author.date) \(.commit.message | split("\n")[0]) (\(.html_url))"' 2> /dev/null)

report+=$'\n'"### Issue $UPSTREAM_REPO#$WATCH_ISSUE: ${state:-unknown}"$'\n'
[ -n "$comments" ] && report+="New comments since $since:"$'\n'"$comments"$'\n'
[ -n "$state" ] && [ "$state" != "open" ] && changes+=("issue-state")
[ -n "$comments" ] && changes+=("issue-comments")

report+=$'\n'"### Commits since $since"$'\n'"${commits:-none}"$'\n'
[ -n "$commits" ] && changes+=("commits")

if [ ${#changes[@]} -eq 0 ]; then
    echo "No change."
    echo "$report"
    exit 0
fi

body="Upstream change detected: $(printf '%s ' "${changes[@]}" | tr ' ' '\n' | sort -u | paste -sd, -)"$'\n\n'"$report"$'\n'"Next step: re-run the hotfix spikes (start path wrapper vs aioz-io, health check, quick_test)."

if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "$body"
    exit 0
fi

issue=$(gh issue list --state open --search "\"$TRACKING_TITLE\" in:title" --json number --jq '.[0].number')
if [ -z "$issue" ]; then
    gh issue create --title "$TRACKING_TITLE" --body "$body"
else
    gh issue comment "$issue" --body "$body"
fi

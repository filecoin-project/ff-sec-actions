#!/usr/bin/env bash
# Stage 0 of the dev harness: snapshot a PR into a local fixture.
# Mirrors review.sh section 1 (fetch PR metadata and diff).
#
# Required env: REPO (owner/repo), PR_NUMBER
# Optional env: FIXTURE (fixture name; default <owner>-<repo>-pr<number>)
#
# Network: GitHub API only (gh must be authenticated). Never calls Anthropic.
# Re-running overwrites the fixture with a fresh snapshot of the PR.

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

: "${REPO:?REPO is required (owner/repo)}"
: "${PR_NUMBER:?PR_NUMBER is required}"
FIXTURE="${FIXTURE:-$(printf '%s' "$REPO" | tr '/' '-')-pr${PR_NUMBER}}"

fixture_dir="$FIXTURES_DIR/$FIXTURE"
mkdir -p "$fixture_dir"

gh pr view "$PR_NUMBER" --repo "$REPO" --json title,body,author,baseRefName \
  > "$fixture_dir/pr.json"
gh pr diff "$PR_NUMBER" --repo "$REPO" > "$fixture_dir/full.patch"

# Record identity so later stages need no env beyond FIXTURE.
jq -n --arg repo "$REPO" --arg pr_number "$PR_NUMBER" \
  '{repo: $repo, pr_number: $pr_number}' > "$fixture_dir/meta.json"

echo "Fixture '$FIXTURE' written:"
echo "  $(wc -c < "$fixture_dir/full.patch" | tr -d ' ') bytes of diff — $(jq -r .title "$fixture_dir/pr.json")"
echo "Next: FIXTURE=$FIXTURE $DEV_DIR/build.sh"

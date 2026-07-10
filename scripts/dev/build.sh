#!/usr/bin/env bash
# Stage 1 of the dev harness: fixture + prompts + schema -> request.json.
# Mirrors review.sh sections 2-3 (filter, truncate, build the API request).
# Change a prompt or the schema, re-run this, and inspect what the model
# would receive — no network, no cost.
#
# Required env: FIXTURE
# Optional env (same names and defaults as review.sh / action.yml):
#   MODEL, EFFORT, MAX_TOKENS, MAX_DIFF_BYTES, EXCLUDE_RE,
#   DOMAIN (default filecoin), PROMPT_FILE, BASE_PROMPT_FILE, SCHEMA_FILE
#
# Inspect the result:
#   jq -r '.system[0].text' request.json   # base prompt as sent
#   jq -r '.system[1].text' request.json   # domain prompt as sent
#   jq -r '.messages[0].content' request.json | head -40

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_fixture
require_file "$fixture_dir/full.patch" "fetch.sh"

MODEL="${MODEL:-claude-opus-4-8}"
EFFORT="${EFFORT:-high}"
MAX_TOKENS="${MAX_TOKENS:-16000}"
MAX_DIFF_BYTES="${MAX_DIFF_BYTES:-400000}"
DOMAIN="${DOMAIN:-filecoin}"
PROMPT_FILE="${PROMPT_FILE:-$ROOT/prompts/${DOMAIN}.md}"
BASE_PROMPT_FILE="${BASE_PROMPT_FILE:-$ROOT/prompts/base-reviewer.md}"
SCHEMA_FILE="${SCHEMA_FILE:-$ROOT/actions/ai-code-review/scripts/schema.json}"

# Keep in sync with DEFAULT_EXCLUDE_RE in review.sh.
DEFAULT_EXCLUDE_RE='(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock|go\.sum|flake\.lock|poetry\.lock|Gemfile\.lock)$|(^|/)(vendor|node_modules|dist|build|target)/|\.min\.(js|css)$|\.(svg|png|jpe?g|gif|ico|woff2?|ttf|pdf|lock)$|\.pb\.(go|rs)$|_generated\.|\.gen\.(go|rs|ts)$'
EXCLUDE_RE="${EXCLUDE_RE:-$DEFAULT_EXCLUDE_RE}"

for f in "$PROMPT_FILE" "$BASE_PROMPT_FILE" "$SCHEMA_FILE"; do
  [ -f "$f" ] || { echo "error: missing required file: $f" >&2; exit 1; }
done

repo=$(jq -r .repo "$fixture_dir/meta.json")
pr_number=$(jq -r .pr_number "$fixture_dir/meta.json")

EXCLUDE_RE="$EXCLUDE_RE" awk '
  /^diff --git / {
    path = $3; sub(/^a\//, "", path)
    keep = (path !~ ENVIRON["EXCLUDE_RE"])
  }
  keep { print }
' "$fixture_dir/full.patch" > "$fixture_dir/filtered.patch"

if [ ! -s "$fixture_dir/filtered.patch" ]; then
  echo "No reviewable changes after filtering (lockfiles/vendored/generated only)."
  rm -f "$fixture_dir/request.json" "$fixture_dir/diff.patch"
  exit 0
fi

truncated=false
if [ "$(wc -c < "$fixture_dir/filtered.patch")" -gt "$MAX_DIFF_BYTES" ]; then
  head -c "$MAX_DIFF_BYTES" "$fixture_dir/filtered.patch" > "$fixture_dir/diff.patch"
  truncated=true
else
  cp "$fixture_dir/filtered.patch" "$fixture_dir/diff.patch"
fi

jq -n \
  --arg model "$MODEL" \
  --arg effort "$EFFORT" \
  --argjson max_tokens "$MAX_TOKENS" \
  --rawfile base "$BASE_PROMPT_FILE" \
  --rawfile domain "$PROMPT_FILE" \
  --rawfile diff "$fixture_dir/diff.patch" \
  --slurpfile schema "$SCHEMA_FILE" \
  --slurpfile pr "$fixture_dir/pr.json" \
  --arg repo "$repo" \
  --arg pr_number "$pr_number" \
  --arg truncated "$truncated" \
  '{
    model: $model,
    max_tokens: $max_tokens,
    thinking: { type: "adaptive" },
    output_config: {
      effort: $effort,
      format: { type: "json_schema", schema: $schema[0] }
    },
    system: [
      { type: "text", text: $base },
      { type: "text", text: $domain, cache_control: { type: "ephemeral" } }
    ],
    messages: [
      { role: "user",
        content: ("Repository: " + $repo
          + "\nPull request: #" + $pr_number + " — " + $pr[0].title
          + "\nAuthor: " + ($pr[0].author.login // "unknown")
          + "\nTarget branch: " + $pr[0].baseRefName
          + "\n\nPR description:\n" + (if ($pr[0].body // "") == "" then "(none)" else $pr[0].body end)
          + (if $truncated == "true"
             then "\n\nNOTE: the diff below was truncated to fit a size budget; review what is present and add an info-level finding noting the truncation."
             else "" end)
          + "\n\n--- BEGIN UNIFIED DIFF ---\n" + $diff + "\n--- END UNIFIED DIFF ---")
      }
    ]
  }' > "$fixture_dir/request.json"

echo "request.json built for '$FIXTURE' (model=$MODEL, effort=$EFFORT, truncated=$truncated,"
echo "  diff: $(wc -c < "$fixture_dir/diff.patch" | tr -d ' ')/$(wc -c < "$fixture_dir/full.patch" | tr -d ' ') bytes after filter+budget)."
echo "Next: FIXTURE=$FIXTURE $DEV_DIR/call.sh"

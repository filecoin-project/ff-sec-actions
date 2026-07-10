#!/usr/bin/env bash
# Stage 2 of the dev harness: request.json -> response.json via the Claude API.
# Mirrors review.sh section 4 (call with retries on transient errors).
# The only stage that costs money. Skips the call if a cached response.json
# already exists — set REFRESH=true to force a new one.
#
# Required env: FIXTURE, ANTHROPIC_API_KEY
# Optional env: REFRESH (default false)

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_fixture
require_file "$fixture_dir/request.json" "build.sh"

REFRESH="${REFRESH:-false}"

if [ -s "$fixture_dir/response.json" ] && [ "$REFRESH" != "true" ]; then
  echo "Cached response.json exists for '$FIXTURE' — skipping API call (REFRESH=true to force)."
  echo "Next: FIXTURE=$FIXTURE $DEV_DIR/render.sh"
  exit 0
fi

: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY is required (put it in scripts/dev/.env)}"

http_code=0
for attempt in 1 2 3; do
  http_code=$(curl -sS -o "$fixture_dir/response.json" -w '%{http_code}' \
    --max-time 900 \
    https://api.anthropic.com/v1/messages \
    -H "x-api-key: ${ANTHROPIC_API_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    --data-binary "@$fixture_dir/request.json") || http_code=000
  case "$http_code" in
    200) break ;;
    429|500|502|503|529|000)
      echo "Attempt ${attempt}: HTTP ${http_code}, retrying..."
      sleep $((attempt * 20)) ;;
    *)
      echo "error: Claude API returned HTTP ${http_code}: $(jq -r '.error.message // "unknown error"' "$fixture_dir/response.json" 2>/dev/null)" >&2
      rm -f "$fixture_dir/response.json"
      exit 1 ;;
  esac
done
if [ "$http_code" != "200" ]; then
  echo "error: Claude API unavailable after 3 attempts (last HTTP ${http_code})." >&2
  rm -f "$fixture_dir/response.json"
  exit 1
fi

stop_reason=$(jq -r '.stop_reason // "unknown"' "$fixture_dir/response.json")
usage=$(jq -r '"in=\(.usage.input_tokens // "?") out=\(.usage.output_tokens // "?")"' "$fixture_dir/response.json")
echo "response.json written for '$FIXTURE' (stop_reason=$stop_reason, tokens: $usage)."
[ "$stop_reason" = "refusal" ] && echo "warning: model declined to review this diff."
[ "$stop_reason" = "max_tokens" ] && echo "warning: hit max_tokens; findings may be incomplete."
echo "Next: FIXTURE=$FIXTURE $DEV_DIR/render.sh"

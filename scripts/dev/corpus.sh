#!/usr/bin/env bash
# Run build -> call -> render across every fixture and print a summary table.
# Use after a prompt/schema change to check the whole corpus, not one PR.
# Cached responses are reused; REFRESH=true re-calls the API for every fixture
# (costs one review per fixture).
#
# Required env: ANTHROPIC_API_KEY (unless every fixture has a cached response)
# Optional env: REFRESH, plus anything build.sh/render.sh accept
#               (MODEL, EFFORT, DOMAIN, FAIL_ON_SEVERITY, ...)
#
# Compare runs by committing nothing: findings.json stays in each fixture, so
#   git stash / prompt edit / corpus.sh / diff <(jq . old) <(jq . new)
# or just copy findings.json aside before iterating.

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

REFRESH="${REFRESH:-false}"

fixtures=()
for d in "$FIXTURES_DIR"/*/; do
  [ -d "$d" ] && fixtures+=("$(basename "$d")")
done
[ "${#fixtures[@]}" -gt 0 ] || { echo "No fixtures under $FIXTURES_DIR — run fetch.sh first." >&2; exit 1; }

if [ "$REFRESH" = "true" ]; then
  echo "REFRESH=true: this will make ${#fixtures[@]} Claude API call(s)."
fi

fail=0
rows="fixture\tfindings\thighest\tgate"
for FIXTURE in "${fixtures[@]}"; do
  export FIXTURE
  echo "=== $FIXTURE ==="
  if ! "$DEV_DIR/build.sh"; then
    rows="$rows\n$FIXTURE\tbuild-failed\t-\t-"; fail=1; continue
  fi
  if [ ! -f "$FIXTURES_DIR/$FIXTURE/request.json" ]; then
    rows="$rows\n$FIXTURE\t0\tnone\tfiltered-empty"; continue
  fi
  if ! REFRESH="$REFRESH" "$DEV_DIR/call.sh"; then
    rows="$rows\n$FIXTURE\tcall-failed\t-\t-"; fail=1; continue
  fi
  gate=pass
  "$DEV_DIR/render.sh" || gate=FAIL
  f="$FIXTURES_DIR/$FIXTURE/findings.json"
  if [ -f "$f" ]; then
    count=$(jq '.findings | length' "$f")
    highest=$(jq -r '
      def rank: {"critical":5,"high":4,"medium":3,"low":2,"info":1}[.] // 0;
      [.findings[].severity] | if length == 0 then "none" else max_by(rank) end' "$f")
    rows="$rows\n$FIXTURE\t$count\t$highest\t$gate"
    [ "$gate" = "FAIL" ] && fail=1
  else
    rows="$rows\n$FIXTURE\t-\t-\trefused"
  fi
done

echo
echo "=== Corpus summary ==="
printf '%b\n' "$rows" | column -t -s $'\t'
exit "$fail"

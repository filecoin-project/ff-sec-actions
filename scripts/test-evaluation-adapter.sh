#!/usr/bin/env bash
# Contract tests for the generic scanner evaluation adapter lifecycle.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
adapter="$repo_root/actions/evaluation-adapter/evaluation-adapter.sh"
validator="$repo_root/scripts/check-evaluation-result.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/ff-sec-evaluation-adapter.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

cat > "$test_root/clean.sarif" <<'JSON'
{"version":"2.1.0","runs":[{"tool":{"driver":{"name":"fixture"}},"results":[]}]}
JSON
cat > "$test_root/findings.sarif" <<'JSON'
{"version":"2.1.0","runs":[{"tool":{"driver":{"name":"fixture"}},"results":[{"ruleId":"fixture.high","level":"error","message":{"text":"fixture finding"}}]}]}
JSON
printf '{not-json\n' > "$test_root/malformed.sarif"

run_case() {
  local name="$1"
  local outcome="$2"
  local evidence="$3"
  local blocking="$4"
  local expected_exit="$5"
  local expected_completion="$6"
  local expected_gate="$7"
  local expected_count="$8"
  local result="$test_root/${name}.json"
  local actual_exit=0

  EVALUATION_ID=fixture-scan \
  TOOL_NAME=fixture \
  TOOL_VERSION=1.2.3 \
  TOOL_OUTCOME="$outcome" \
  TOOL_EXIT_CODE=124 \
  RAW_EVIDENCE="$evidence" \
  BLOCKING="$blocking" \
  COVERAGE_INCLUDED='["repository files"]' \
  COVERAGE_EXCLUDED='[]' \
  COVERAGE_LIMITATIONS='["fixture limitation"]' \
  EVALUATION_RESULT_FILE="$result" \
    bash "$adapter" >/dev/null 2>&1 || actual_exit="$?"

  [ "$actual_exit" -eq "$expected_exit" ] \
    || { printf 'evaluation-adapter test failure: %s exited %s, expected %s\n' "$name" "$actual_exit" "$expected_exit" >&2; exit 1; }
  bash "$validator" "$result" >/dev/null \
    || { printf 'evaluation-adapter test failure: %s emitted invalid JSON\n' "$name" >&2; exit 1; }
  jq -e \
    --arg completion "$expected_completion" \
    --arg gate "$expected_gate" \
    --argjson count "$expected_count" \
    '.completion.status == $completion and .merge_gate.conclusion == $gate and .findings.count == $count' \
    "$result" >/dev/null \
    || { printf 'evaluation-adapter test failure: %s emitted incorrect semantics\n' "$name" >&2; exit 1; }
}

run_case success success "$test_root/clean.sarif" false 0 complete pass 0
run_case advisory-findings success "$test_root/findings.sarif" false 0 complete pass 1
run_case blocking-findings success "$test_root/findings.sarif" true 1 complete fail 1
run_case timeout timed-out "" false 2 incomplete fail null
run_case crash failure "" false 2 error fail null
run_case malformed success "$test_root/malformed.sarif" false 2 error fail null
run_case skipped skipped "" false 0 skipped not-evaluated null

printf 'evaluation adapter lifecycle contract tests passed.\n'

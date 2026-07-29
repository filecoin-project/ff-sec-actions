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
{
  "version": "2.1.0",
  "runs": [{
    "tool": {"driver": {"name": "fixture", "rules": [{
      "id": "fixture:high",
      "shortDescription": {"text": "Unsafe fixture behavior"},
      "helpUri": "https://example.invalid/rules/fixture-high"
    }]}},
    "results": [{
      "ruleId": "fixture:high",
      "level": "error",
      "message": {"text": "fixture finding"},
      "locations": [{"physicalLocation": {
        "artifactLocation": {"uri": "src/fixture,file.js"},
        "region": {"startLine": 42}
      }}]
    }]
  }]
}
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
  local summary="$test_root/${name}.md"
  local step_summary="$test_root/${name}.step-summary.md"
  local command_log="$test_root/${name}.commands.log"
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
  EVIDENCE_ARTIFACT=fixture-sarif \
  REMEDIATION_GUIDANCE='Replace the unsafe fixture behavior with the documented safe pattern.' \
  SUMMARY_FILE="$summary" \
  GITHUB_STEP_SUMMARY="$step_summary" \
  EVALUATION_RESULT_FILE="$result" \
    bash "$adapter" >"$command_log" 2>&1 || actual_exit="$?"

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

  if [ "$name" = blocking-findings ]; then
    jq -e '.evidence[0].artifact == "fixture-sarif"' "$result" >/dev/null \
      || { printf 'evaluation-adapter test failure: durable artifact identity is missing\n' >&2; exit 1; }
    for expected in \
      '# Evaluation: fixture-scan' \
      'Completion: **complete**' \
      'Gate: **fail**' \
      "Scope: \`repository\`" \
      "Evidence artifact: \`fixture-sarif\`" \
      "\`src/fixture,file.js:42\`" \
      'fixture finding' \
      'Replace the unsafe fixture behavior'; do
      grep -Fq "$expected" "$summary" \
        || { printf 'evaluation-adapter test failure: summary is missing %s\n' "$expected" >&2; exit 1; }
      grep -Fq "$expected" "$step_summary" \
        || { printf 'evaluation-adapter test failure: job summary is missing %s\n' "$expected" >&2; exit 1; }
    done
    grep -Fq '::error file=src/fixture%2Cfile.js,line=42,title=fixture%3Ahigh::fixture finding' "$command_log" \
      || { printf 'evaluation-adapter test failure: annotation properties are not command escaped\n' >&2; exit 1; }
  fi
  if [ -z "$evidence" ]; then
    grep -Fq "Evidence artifact: \`not-published\`" "$summary" \
      || { printf 'evaluation-adapter test failure: missing evidence advertised a nonexistent artifact\n' >&2; exit 1; }
  fi
}

run_case success success "$test_root/clean.sarif" false 0 complete pass 0
run_case advisory-findings success "$test_root/findings.sarif" false 0 complete pass 1
run_case blocking-findings success "$test_root/findings.sarif" true 1 complete fail 1
run_case timeout timed-out "" false 2 incomplete fail null
run_case crash failure "" false 2 error fail null
run_case malformed success "$test_root/malformed.sarif" false 2 error fail null
run_case skipped skipped "" false 0 skipped not-evaluated null

printf 'evaluation adapter lifecycle contract tests passed.\n'

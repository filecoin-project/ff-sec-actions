#!/usr/bin/env bash
# Contract tests for Evidence Bundle aggregation and profile conclusion.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aggregator="$repo_root/actions/aggregate-results/aggregate-results.sh"
validator="$repo_root/scripts/check-evaluation-result.sh"
base_result="$repo_root/test/fixtures/evaluation-result/valid/complete.json"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/ff-sec-aggregate.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

make_clean_pair() {
  local directory="$1"
  mkdir -p "$directory"
  cp "$base_result" "$directory/one.json"
  jq '.evaluation.id = "fixture-second"' "$base_result" > "$directory/two.json"
}

run_case() {
  local name="$1"
  local expected_exit="$2"
  local expected_completion="$3"
  local expected_conclusion="$4"
  local results="$test_root/$name/results"
  local bundle="$test_root/$name/bundle.json"
  local summary="$test_root/$name/summary.md"
  local actual_exit=0

  PROFILE_ID=fixture-profile \
  PROFILE_VERSION=1.0.0 \
  REQUIRED_EVALUATIONS='["fixture-scan","fixture-second"]' \
  REQUIRE_COMPLETE=true \
  RESULTS_DIRECTORY="$results" \
  BUNDLE_FILE="$bundle" \
  SUMMARY_FILE="$summary" \
  EVALUATION_VALIDATOR="$validator" \
    bash "$aggregator" >/dev/null 2>&1 || actual_exit="$?"

  [ "$actual_exit" -eq "$expected_exit" ] \
    || { printf 'aggregate-results test failure: %s exited %s, expected %s\n' "$name" "$actual_exit" "$expected_exit" >&2; exit 1; }
  jq -e --arg completion "$expected_completion" --arg conclusion "$expected_conclusion" \
    '.schema_version == "1.0.0" and .completion.status == $completion and .merge_gate.conclusion == $conclusion' \
    "$bundle" >/dev/null \
    || { printf 'aggregate-results test failure: %s bundle semantics are incorrect\n' "$name" >&2; exit 1; }
  grep -Fq '# Security Profile:' "$summary" \
    || { printf 'aggregate-results test failure: %s summary is missing\n' "$name" >&2; exit 1; }
}

make_clean_pair "$test_root/clean/results"
run_case clean 0 complete pass

make_clean_pair "$test_root/findings/results"
jq '.findings = {count: 2, highest_severity: "high"} | .merge_gate = {mode: "blocking", conclusion: "fail", reason: "fixture findings"}' \
  "$test_root/findings/results/two.json" > "$test_root/findings/results/two.tmp"
mv "$test_root/findings/results/two.tmp" "$test_root/findings/results/two.json"
jq '.schema_version = "1.1.0" | .evidence = [{type: "sarif", path: "fixture.sarif", sha256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", artifact: "fixture-results"}]' \
  "$test_root/findings/results/two.json" > "$test_root/findings/results/two.tmp"
mv "$test_root/findings/results/two.tmp" "$test_root/findings/results/two.json"
run_case findings 1 complete fail
for expected in 'fixture findings' "\`fixture-results\`" "\`fixture.sarif\`"; do
  grep -Fq "$expected" "$test_root/findings/summary.md" \
    || { printf 'aggregate-results test failure: summary is missing evidence mapping %s\n' "$expected" >&2; exit 1; }
done

make_clean_pair "$test_root/skipped/results"
jq '.completion = {status: "skipped", reason: "fixture skip"} | .coverage.status = "not-applicable" | .findings = {count: null, highest_severity: "unknown"} | .merge_gate = {mode: "advisory", conclusion: "not-evaluated", reason: "fixture skip"}' \
  "$test_root/skipped/results/two.json" > "$test_root/skipped/results/two.tmp"
mv "$test_root/skipped/results/two.tmp" "$test_root/skipped/results/two.json"
run_case skipped 1 incomplete fail

make_clean_pair "$test_root/error/results"
jq '.completion = {status: "error", reason: "fixture crash"} | .coverage.status = "unknown" | .findings = {count: null, highest_severity: "unknown"} | .merge_gate = {mode: "advisory", conclusion: "fail", reason: "fixture crash"}' \
  "$test_root/error/results/two.json" > "$test_root/error/results/two.tmp"
mv "$test_root/error/results/two.tmp" "$test_root/error/results/two.json"
run_case error 1 error fail

make_clean_pair "$test_root/suppressions/results"
jq '.suppressions = {count: 2, sources: ["fixture-policy"]}' \
  "$test_root/suppressions/results/two.json" > "$test_root/suppressions/results/two.tmp"
mv "$test_root/suppressions/results/two.tmp" "$test_root/suppressions/results/two.json"
run_case suppressions 0 complete pass
jq -e '.summary.suppressions_observed == 2 and .summary.suppressions_authoritative == true' \
  "$test_root/suppressions/bundle.json" >/dev/null \
  || { printf 'aggregate-results test failure: suppression summary is incorrect\n' >&2; exit 1; }

make_clean_pair "$test_root/duplicate/results"
jq '.evaluation.id = "fixture-scan"' "$test_root/duplicate/results/two.json" > "$test_root/duplicate/results/two.tmp"
mv "$test_root/duplicate/results/two.tmp" "$test_root/duplicate/results/two.json"
duplicate_exit=0
PROFILE_ID=fixture PROFILE_VERSION=1 REQUIRED_EVALUATIONS='["fixture-scan"]' \
RESULTS_DIRECTORY="$test_root/duplicate/results" BUNDLE_FILE="$test_root/duplicate/bundle.json" \
SUMMARY_FILE="$test_root/duplicate/summary.md" EVALUATION_VALIDATOR="$validator" \
  bash "$aggregator" >/dev/null 2>&1 || duplicate_exit="$?"
[ "$duplicate_exit" -eq 2 ] \
  || { printf 'aggregate-results test failure: duplicate ids were not rejected\n' >&2; exit 1; }

printf 'Evidence Bundle aggregation contract tests passed.\n'

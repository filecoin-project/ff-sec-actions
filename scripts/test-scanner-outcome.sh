#!/usr/bin/env bash
# test-scanner-outcome: verify finding gates remain separate from tool failures.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
adapter="$repo_root/actions/scanner-outcome/scanner-outcome.sh"
contract_checker="$repo_root/scripts/check-evaluation-result.sh"
test_directory="$(mktemp -d)"
trap 'rm -rf "$test_directory"' EXIT

fail() {
  printf 'scanner-outcome test failure: %s\n' "$*" >&2
  exit 1
}

cat > "$test_directory/clean.sarif" <<'JSON'
{"version":"2.1.0","runs":[{"tool":{"driver":{"name":"fixture"}},"results":[]}]}
JSON

cat > "$test_directory/findings.sarif" <<'JSON'
{"version":"2.1.0","runs":[{"tool":{"driver":{"name":"fixture"}},"results":[{"ruleId":"fixture.finding","message":{"text":"planted finding"}}]}]}
JSON

printf '{not-json\n' > "$test_directory/malformed.sarif"

run_case() {
  local name="$1"
  local scanner_outcome="$2"
  local blocking="$3"
  local result_file="$4"
  local expected_exit="$5"
  local expected_completion="$6"
  local expected_result="$7"
  local expected_conclusion="$8"
  local output_file="$test_directory/$name.stdout.json"
  local evaluation_file="$test_directory/$name.evaluation.json"
  local actual_exit=0

  SCANNER_NAME=fixture \
  SCANNER_OUTCOME="$scanner_outcome" \
  BLOCKING="$blocking" \
  RESULT_FILE="$result_file" \
  EVALUATION_RESULT_FILE="$evaluation_file" \
    bash "$adapter" > "$output_file" || actual_exit="$?"

  [ "$actual_exit" -eq "$expected_exit" ] \
    || fail "$name exited $actual_exit, expected $expected_exit"
  jq -e \
    --arg completion "$expected_completion" \
    --arg result "$expected_result" \
    --arg conclusion "$expected_conclusion" \
    '.completion.status == $completion
      and (if $result == "no-findings" then .findings.count == 0 else true end)
      and (if $result == "findings" then .findings.count == 1 else true end)
      and (if $conclusion == "error" then .findings.count == null else true end)' \
    "$evaluation_file" >/dev/null \
    || fail "$name returned the wrong normalized outcome"
  bash "$contract_checker" "$evaluation_file" >/dev/null \
    || fail "$name did not emit a valid Evaluation Result"
}

run_case no-findings success false "$test_directory/clean.sarif" 0 complete no-findings pass
run_case advisory-findings success false "$test_directory/findings.sarif" 0 complete findings pass
run_case gated-findings success true "$test_directory/findings.sarif" 1 complete findings fail
run_case tool-error failure false "$test_directory/findings.sarif" 2 error error error
run_case malformed-output success false "$test_directory/malformed.sarif" 2 error error error
run_case event-skip skipped false "$test_directory/malformed.sarif" 0 skipped skipped skip
run_case cancelled cancelled false "$test_directory/malformed.sarif" 2 incomplete incomplete error

github_output="$test_directory/github-output"
SCANNER_NAME=fixture \
SCANNER_OUTCOME=success \
BLOCKING=false \
RESULT_FILE="$test_directory/findings.sarif" \
EVALUATION_RESULT_FILE="$test_directory/github-evaluation-result.json" \
GITHUB_OUTPUT="$github_output" \
  bash "$adapter" >/dev/null
if ! grep -Fq 'completion=complete' "$github_output" \
  || ! grep -Fq 'result=findings' "$github_output" \
  || ! grep -Fq 'conclusion=pass' "$github_output" \
  || ! grep -Fq 'findings_count=1' "$github_output" \
  || ! grep -Fq 'evaluation_result=' "$github_output"; then
  fail "GitHub Action outputs do not match the normalized result"
fi

printf 'scanner-outcome contract tests passed.\n'

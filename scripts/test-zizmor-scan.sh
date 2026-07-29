#!/usr/bin/env bash
# test-zizmor-scan: prove the permission-free adapter emits SARIF and honest outcomes.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
adapter="$repo_root/actions/zizmor-scan/zizmor-scan.sh"
fixture_root="$repo_root/test/fixtures/actions-security"
test_directory="$(mktemp -d)"
trap 'rm -rf "$test_directory"' EXIT

fail() {
  printf 'zizmor-scan test failure: %s\n' "$*" >&2
  exit 1
}

successful_output_file="$test_directory/findings.outputs"
successful_result_file="$test_directory/findings.sarif"
INPUT_PATH="$fixture_root/mutable-reference.yml" \
CONFIG_PATH="" \
RESULT_FILE="$successful_result_file" \
RUNNER_TEMP="$test_directory/runner" \
GITHUB_OUTPUT="$successful_output_file" \
  bash "$adapter"

grep -Fq 'scanner_outcome=success' "$successful_output_file" \
  || fail "findings were not represented as a successful scanner invocation"
grep -Fq "result_file=${successful_result_file}" "$successful_output_file" \
  || fail "the SARIF path was not exposed through the action interface"
jq -e '
  .version == "2.1.0"
  and ([.runs[] | (.results // [])[]] | length > 0)
' "$successful_result_file" >/dev/null \
  || fail "the planted mutable reference did not produce valid SARIF"

failure_outputs="$test_directory/failure.outputs"
ZIZMOR_BIN=/bin/false \
INPUT_PATH="$fixture_root/mutable-reference.yml" \
CONFIG_PATH="" \
RESULT_FILE="$test_directory/failure.sarif" \
GITHUB_OUTPUT="$failure_outputs" \
  bash "$adapter"
grep -Fq 'scanner_outcome=failure' "$failure_outputs" \
  || fail "an operational scanner error was not represented as failure"

printf 'permission-free Zizmor adapter tests passed.\n'

#!/usr/bin/env bash
# test-evaluation-result: exercise completion semantics for scanner and AI surfaces.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="$repo_root/scripts/check-evaluation-result.sh"
ai_review="$repo_root/actions/ai-code-review/scripts/review.sh"
test_directory="$(mktemp -d)"
trap 'rm -rf "$test_directory"' EXIT

fail() {
  printf 'evaluation-result test failure: %s\n' "$*" >&2
  exit 1
}

for fixture in "$repo_root"/test/fixtures/evaluation-result/valid/*.json; do
  bash "$checker" "$fixture" >/dev/null \
    || fail "valid static fixture was rejected: $fixture"
done

for fixture in "$repo_root"/test/fixtures/evaluation-result/invalid/*.json; do
  if bash "$checker" "$fixture" >/dev/null 2>&1; then
    fail "invalid static fixture was accepted: $fixture"
  fi
done

make_contract_fixture() {
  local kind="$1"
  local status="$2"
  local count=null
  local highest=unknown
  local coverage=unknown
  local gate_conclusion=not-evaluated

  if [ "$status" = complete ]; then
    count=0
    highest=none
    coverage=complete
    gate_conclusion=pass
  elif [ "$status" = skipped ]; then
    coverage=not-applicable
  elif [ "$status" = incomplete ]; then
    coverage=partial
  elif [ "$status" = error ]; then
    gate_conclusion=fail
  fi

  jq -n \
    --arg kind "$kind" \
    --arg status "$status" \
    --argjson count "$count" \
    --arg highest "$highest" \
    --arg coverage "$coverage" \
    --arg gate_conclusion "$gate_conclusion" \
    '{
      schema_version: "1.0.0",
      evaluation: {id: ($kind + "-fixture"), kind: $kind},
      tool: {name: "fixture", version: "1"},
      scope: {repository: "filecoin-project/fixture", ref: "abc123", target: "repository"},
      completion: {status: $status, reason: "contract fixture"},
      coverage: {status: $coverage, included: [], excluded: [], limitations: []},
      findings: {count: $count, highest_severity: $highest},
      suppressions: {count: null, sources: []},
      merge_gate: {mode: "advisory", conclusion: $gate_conclusion, reason: "fixture policy"},
      timing: {started_at: null, completed_at: null, duration_ms: null},
      evidence: [{type: "none", path: null, sha256: null}]
    }' > "$test_directory/${kind}-${status}.json"
}

for kind in scanner ai-review; do
  for status in complete incomplete skipped error; do
    make_contract_fixture "$kind" "$status"
    bash "$checker" "$test_directory/${kind}-${status}.json" >/dev/null \
      || fail "$kind/$status fixture failed validation"
  done
done

jq '.completion.status = "complete" | .findings.count = null' \
  "$test_directory/scanner-error.json" > "$test_directory/invalid-complete.json"
if bash "$checker" "$test_directory/invalid-complete.json" >/dev/null 2>&1; then
  fail "complete evaluations accepted an unknown finding count"
fi

jq '.unexpected = true' \
  "$test_directory/scanner-complete.json" > "$test_directory/invalid-unknown-field.json"
if bash "$checker" "$test_directory/invalid-unknown-field.json" >/dev/null 2>&1; then
  fail "unknown top-level fields were accepted"
fi

jq '.evidence[0] = {type: "none", path: "result.json", sha256: null}' \
  "$test_directory/scanner-complete.json" > "$test_directory/invalid-none-evidence.json"
if bash "$checker" "$test_directory/invalid-none-evidence.json" >/dev/null 2>&1; then
  fail "none evidence with a path was accepted"
fi

mkdir -p "$test_directory/bin" "$test_directory/runner"
printf 'base prompt\n' > "$test_directory/base.md"
printf 'domain prompt\n' > "$test_directory/domain.md"

cat > "$test_directory/bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [ "${GH_FAILURE:-false}" = true ]; then
  exit 1
fi
if [ "${1:-} ${2:-}" = "pr view" ]; then
  printf '%s\n' '{"title":"Fixture PR","body":"","author":{"login":"fixture"},"baseRefName":"main"}'
elif [ "${1:-} ${2:-}" = "pr diff" ]; then
  printf '%s\n' 'diff --git a/src/example.ts b/src/example.ts'
  printf '%s\n' '--- a/src/example.ts'
  printf '%s\n' '+++ b/src/example.ts'
  printf '%s\n' '@@ -1 +1 @@'
  printf '%s\n' '-const safe = true;'
  printf '%s\n' '+const safe = false;'
else
  exit 1
fi
SH

cat > "$test_directory/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
output_file=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) output_file="$2"; shift 2 ;;
    *) shift ;;
  esac
done
cp "$FAKE_RESPONSE_FILE" "$output_file"
printf '200'
SH
chmod +x "$test_directory/bin/gh" "$test_directory/bin/curl"

cat > "$test_directory/findings.json" <<'JSON'
{"summary":"No actionable issue in fixture.","risk_level":"low","findings":[],"positive_observations":[]}
JSON
jq -n --rawfile text "$test_directory/findings.json" \
  '{stop_reason:"end_turn",content:[{type:"text",text:$text}]}' \
  > "$test_directory/complete-response.json"
jq -n --rawfile text "$test_directory/findings.json" \
  '{stop_reason:"max_tokens",content:[{type:"text",text:$text}]}' \
  > "$test_directory/max-tokens-response.json"
printf '%s\n' '{"stop_reason":"refusal","content":[]}' \
  > "$test_directory/refusal-response.json"

run_ai_case() {
  local name="$1"
  local expected_exit="$2"
  local expected_status="$3"
  local api_key="$4"
  local response_file="$5"
  local max_diff_bytes="$6"
  local gh_failure="$7"
  local output_file="$test_directory/${name}.outputs"
  local result_file="$test_directory/${name}-evaluation.json"
  local actual_exit=0

  PATH="$test_directory/bin:$PATH" \
  ANTHROPIC_API_KEY="$api_key" \
  GH_TOKEN=fixture-token \
  PR_NUMBER=42 \
  REPO=filecoin-project/fixture \
  PROMPT_FILE="$test_directory/domain.md" \
  BASE_PROMPT_FILE="$test_directory/base.md" \
  SCHEMA_FILE="$repo_root/actions/ai-code-review/scripts/schema.json" \
  POST_COMMENT=false \
  MAX_DIFF_BYTES="$max_diff_bytes" \
  FAKE_RESPONSE_FILE="$response_file" \
  GH_FAILURE="$gh_failure" \
  RUNNER_TEMP="$test_directory/runner" \
  EVALUATION_RESULT_FILE="$result_file" \
  GITHUB_OUTPUT="$output_file" \
  GITHUB_STEP_SUMMARY="$test_directory/${name}.summary" \
    bash "$ai_review" >/dev/null 2>&1 || actual_exit="$?"

  [ "$actual_exit" -eq "$expected_exit" ] \
    || fail "$name exited $actual_exit, expected $expected_exit"
  [ -f "$result_file" ] || fail "$name did not emit an Evaluation Result"
  jq -e --arg status "$expected_status" '.completion.status == $status' "$result_file" >/dev/null \
    || fail "$name emitted the wrong completion status"
  bash "$checker" "$result_file" >/dev/null \
    || fail "$name emitted an invalid Evaluation Result"
}

run_ai_case complete 0 complete fixture-key "$test_directory/complete-response.json" 400000 false
run_ai_case missing-secret 0 skipped "" "$test_directory/complete-response.json" 400000 false
run_ai_case refusal 0 incomplete fixture-key "$test_directory/refusal-response.json" 400000 false
run_ai_case max-tokens 0 incomplete fixture-key "$test_directory/max-tokens-response.json" 400000 false
run_ai_case truncated 0 incomplete fixture-key "$test_directory/complete-response.json" 32 false
run_ai_case tool-outage 1 error fixture-key "$test_directory/complete-response.json" 400000 true

printf 'evaluation-result scanner and AI contract tests passed.\n'

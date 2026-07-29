#!/usr/bin/env bash
# Aggregate validated Evaluation Result v1 documents into one Evidence Bundle.
set -euo pipefail

: "${RESULTS_DIRECTORY:?RESULTS_DIRECTORY is required}"
: "${PROFILE_ID:?PROFILE_ID is required}"
: "${PROFILE_VERSION:?PROFILE_VERSION is required}"
: "${REQUIRED_EVALUATIONS:?REQUIRED_EVALUATIONS is required}"

REQUIRE_COMPLETE="${REQUIRE_COMPLETE:-true}"
BUNDLE_FILE="${BUNDLE_FILE:-evidence-bundle.json}"
SUMMARY_FILE="${SUMMARY_FILE:-evidence-summary.md}"
EVALUATION_VALIDATOR="${EVALUATION_VALIDATOR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/check-evaluation-result.sh}"
BUNDLE_REPOSITORY="${BUNDLE_REPOSITORY:-${GITHUB_REPOSITORY:-}}"
BUNDLE_REF="${BUNDLE_REF:-${GITHUB_SHA:-}}"

fail() { printf 'aggregate-results error: %s\n' "$*" >&2; exit 2; }
case "$REQUIRE_COMPLETE" in true|false) ;; *) fail "REQUIRE_COMPLETE must be true or false" ;; esac
[ -d "$RESULTS_DIRECTORY" ] || fail "results directory is missing: $RESULTS_DIRECTORY"
[ -f "$EVALUATION_VALIDATOR" ] || fail "Evaluation Result validator is missing"
jq -e 'type == "array" and length > 0 and all(.[]; type == "string" and length > 0) and length == (unique | length)' \
  <<< "$REQUIRED_EVALUATIONS" >/dev/null || fail "required evaluations must be a unique JSON string array"

results='[]'
seen_ids=""
while IFS= read -r result_file; do
  [ -n "$result_file" ] || continue
  bash "$EVALUATION_VALIDATOR" "$result_file" >/dev/null \
    || fail "invalid Evaluation Result: $result_file"
  evaluation_id="$(jq -r '.evaluation.id' "$result_file")"
  grep -Fxq "$evaluation_id" <<< "$seen_ids" \
    && fail "duplicate Evaluation Result id: $evaluation_id"
  seen_ids="${seen_ids}${evaluation_id}"$'\n'
  results="$(jq --argjson result "$(jq '.' "$result_file")" '. + [$result]' <<< "$results")"
done < <(find "$RESULTS_DIRECTORY" -type f -name '*.json' | sort)
results="$(jq 'sort_by(.evaluation.id)' <<< "$results")"

actual_ids="$(jq '[.[].evaluation.id]' <<< "$results")"
missing="$(jq -n --argjson required "$REQUIRED_EVALUATIONS" --argjson actual "$actual_ids" '$required - $actual | sort')"
expected_count="$(jq 'length' <<< "$REQUIRED_EVALUATIONS")"
received_count="$(jq 'length' <<< "$results")"
complete_count="$(jq '[.[] | select(.completion.status == "complete")] | length' <<< "$results")"
incomplete_count="$(jq '[.[] | select(.completion.status == "incomplete")] | length' <<< "$results")"
skipped_count="$(jq '[.[] | select(.completion.status == "skipped")] | length' <<< "$results")"
error_count="$(jq '[.[] | select(.completion.status == "error")] | length' <<< "$results")"
missing_count="$(jq 'length' <<< "$missing")"

completion=complete
completion_reason="all required evaluations completed"
if [ "$error_count" -gt 0 ]; then
  completion=error
  completion_reason="one or more evaluations ended in error"
elif [ "$missing_count" -gt 0 ] || [ "$incomplete_count" -gt 0 ] || [ "$skipped_count" -gt 0 ]; then
  completion=incomplete
  completion_reason="required evaluation coverage is missing, incomplete, or skipped"
fi

findings_observed="$(jq '[.[].findings.count // 0] | add // 0' <<< "$results")"
findings_authoritative="$(jq 'all(.[]; .findings.count != null and .completion.status == "complete")' <<< "$results")"
suppressions_observed="$(jq '[.[].suppressions.count // 0] | add // 0' <<< "$results")"
suppressions_authoritative="$(jq 'all(.[]; .suppressions.count != null)' <<< "$results")"
highest_severity="$(jq -r '
  def rank: {"critical":6,"high":5,"medium":4,"low":3,"info":2,"none":1,"unknown":0}[.] // 0;
  [.[].findings.highest_severity] | if length == 0 then "unknown" else max_by(rank) end
' <<< "$results")"

conclusion=pass
gate_reasons='[]'
if jq -e 'any(.[]; .merge_gate.conclusion == "fail")' <<< "$results" >/dev/null; then
  conclusion=fail
  gate_reasons="$(jq -n '$ARGS.positional' --args "one or more evaluation merge gates failed")"
fi
if [ "$REQUIRE_COMPLETE" = true ] && [ "$completion" != complete ]; then
  conclusion=fail
  gate_reasons="$(jq --arg reason "profile requires complete evaluation coverage" '. + [$reason] | unique' <<< "$gate_reasons")"
fi
if [ "$received_count" -eq 0 ]; then
  conclusion=fail
  gate_reasons="$(jq --arg reason "no Evaluation Results were received" '. + [$reason] | unique' <<< "$gate_reasons")"
fi

repository_json=null
ref_json=null
[ -z "$BUNDLE_REPOSITORY" ] || repository_json="$(jq -Rn --arg value "$BUNDLE_REPOSITORY" '$value')"
[ -z "$BUNDLE_REF" ] || ref_json="$(jq -Rn --arg value "$BUNDLE_REF" '$value')"

mkdir -p "$(dirname "$BUNDLE_FILE")" "$(dirname "$SUMMARY_FILE")"
jq -n \
  --arg profile_id "$PROFILE_ID" \
  --arg profile_version "$PROFILE_VERSION" \
  --argjson required "$REQUIRED_EVALUATIONS" \
  --argjson repository "$repository_json" \
  --argjson ref "$ref_json" \
  --arg completion "$completion" \
  --arg completion_reason "$completion_reason" \
  --argjson missing "$missing" \
  --argjson expected "$expected_count" \
  --argjson received "$received_count" \
  --argjson complete_count "$complete_count" \
  --argjson incomplete_count "$incomplete_count" \
  --argjson skipped_count "$skipped_count" \
  --argjson error_count "$error_count" \
  --argjson findings_observed "$findings_observed" \
  --argjson findings_authoritative "$findings_authoritative" \
  --argjson suppressions_observed "$suppressions_observed" \
  --argjson suppressions_authoritative "$suppressions_authoritative" \
  --arg highest_severity "$highest_severity" \
  --argjson require_complete "$REQUIRE_COMPLETE" \
  --arg conclusion "$conclusion" \
  --argjson gate_reasons "$gate_reasons" \
  --argjson results "$results" \
  '{
    schema_version: "1.0.0",
    profile: {id: $profile_id, version: $profile_version, required_evaluations: $required},
    scope: {repository: $repository, ref: $ref},
    completion: {status: $completion, reason: $completion_reason, missing_evaluations: $missing},
    summary: {
      evaluations_expected: $expected, evaluations_received: $received,
      complete: $complete_count, incomplete: $incomplete_count, skipped: $skipped_count, error: $error_count,
      findings_observed: $findings_observed, findings_authoritative: $findings_authoritative,
      suppressions_observed: $suppressions_observed, suppressions_authoritative: $suppressions_authoritative,
      highest_severity: $highest_severity
    },
    merge_gate: {require_complete: $require_complete, conclusion: $conclusion, reasons: $gate_reasons},
    results: $results
  }' > "$BUNDLE_FILE"

{
  printf '# Security Profile: %s@%s\n\n' "$PROFILE_ID" "$PROFILE_VERSION"
  printf -- '- Completion: **%s** — %s\n' "$completion" "$completion_reason"
  printf -- '- Merge gate: **%s**\n' "$conclusion"
  printf -- '- Evaluations: %s/%s received; %s complete, %s incomplete, %s skipped, %s error\n' \
    "$received_count" "$expected_count" "$complete_count" "$incomplete_count" "$skipped_count" "$error_count"
  printf -- '- Findings observed: %s (authoritative: %s); highest severity: %s\n\n' \
    "$findings_observed" "$findings_authoritative" "$highest_severity"
  printf '| Evaluation | Completion | Findings | Gate | Reason | Scope | Evidence |\n'
  printf '|---|---|---:|---|---|---|---|\n'
  jq -r '
    def clean: tostring | gsub("[\\r\\n|`]"; " ") | gsub("[[:space:]]+"; " ");
    .[]
    | "| `\(.evaluation.id)` | \(.completion.status) | \(.findings.count // "unknown")"
      + " | \(.merge_gate.conclusion) | \(.merge_gate.reason | clean)"
      + " | `\(.scope.target | clean)`"
      + " | `\(.evidence[0].artifact // "not-published" | clean)` / `\(.evidence[0].path // "none" | clean)` |"
  ' <<< "$results"
} > "$SUMMARY_FILE"

[ -z "${GITHUB_STEP_SUMMARY:-}" ] || command cat "$SUMMARY_FILE" >> "$GITHUB_STEP_SUMMARY"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    printf 'completion=%s\n' "$completion"
    printf 'conclusion=%s\n' "$conclusion"
    printf 'evidence_bundle=%s\n' "$BUNDLE_FILE"
    printf 'summary=%s\n' "$SUMMARY_FILE"
  } >> "$GITHUB_OUTPUT"
fi

[ "$conclusion" = pass ] || exit 1

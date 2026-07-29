#!/usr/bin/env bash
# Normalize generic scanner lifecycle and SARIF evidence into Evaluation Result v1.
set -euo pipefail

: "${EVALUATION_ID:?EVALUATION_ID is required}"
: "${TOOL_NAME:?TOOL_NAME is required}"
: "${TOOL_VERSION:?TOOL_VERSION is required}"
: "${TOOL_OUTCOME:?TOOL_OUTCOME is required}"

TOOL_EXIT_CODE="${TOOL_EXIT_CODE:-}"
RAW_EVIDENCE="${RAW_EVIDENCE:-}"
BLOCKING="${BLOCKING:-false}"
SCOPE_TARGET="${SCOPE_TARGET:-repository}"
COVERAGE_INCLUDED="${COVERAGE_INCLUDED:-[]}"
COVERAGE_EXCLUDED="${COVERAGE_EXCLUDED:-[]}"
COVERAGE_LIMITATIONS="${COVERAGE_LIMITATIONS:-[]}"
EVALUATION_REPOSITORY="${EVALUATION_REPOSITORY:-${GITHUB_REPOSITORY:-}}"
EVALUATION_REF="${EVALUATION_REF:-${GITHUB_SHA:-}}"
EVALUATION_RESULT_FILE="${EVALUATION_RESULT_FILE:-${RUNNER_TEMP:-$PWD}/${EVALUATION_ID}-evaluation-result.json}"

case "$BLOCKING" in true|false) ;; *) printf 'evaluation-adapter error: BLOCKING must be true or false\n' >&2; exit 2 ;; esac
case "$TOOL_OUTCOME" in success|failure|cancelled|timed-out|skipped) ;; *) printf 'evaluation-adapter error: invalid TOOL_OUTCOME\n' >&2; exit 2 ;; esac

for coverage_json in "$COVERAGE_INCLUDED" "$COVERAGE_EXCLUDED" "$COVERAGE_LIMITATIONS"; do
  jq -e 'type == "array" and all(.[]; type == "string")' <<< "$coverage_json" >/dev/null \
    || { printf 'evaluation-adapter error: coverage inputs must be JSON string arrays\n' >&2; exit 2; }
done

json_or_null() {
  if [ -n "$1" ]; then jq -Rn --arg value "$1" '$value'; else printf 'null\n'; fi
}

emit_result() {
  local completion="$1"
  local reason="$2"
  local coverage_status="$3"
  local findings_count="$4"
  local highest_severity="$5"
  local gate_conclusion="$6"
  local evidence_type=none
  local evidence_path=null
  local evidence_sha=null
  local gate_mode=advisory

  [ "$BLOCKING" = false ] || gate_mode=blocking
  if [ -n "$RAW_EVIDENCE" ] && [ -s "$RAW_EVIDENCE" ]; then
    evidence_type=sarif
    evidence_path="$(json_or_null "$RAW_EVIDENCE")"
    evidence_sha="$(shasum -a 256 "$RAW_EVIDENCE" | awk '{print $1}')"
    evidence_sha="$(json_or_null "$evidence_sha")"
  fi

  mkdir -p "$(dirname "$EVALUATION_RESULT_FILE")"
  jq -n \
    --arg evaluation_id "$EVALUATION_ID" \
    --arg tool_name "$TOOL_NAME" \
    --arg tool_version "$TOOL_VERSION" \
    --argjson repository "$(json_or_null "$EVALUATION_REPOSITORY")" \
    --argjson ref "$(json_or_null "$EVALUATION_REF")" \
    --arg scope_target "$SCOPE_TARGET" \
    --arg completion "$completion" \
    --arg reason "$reason" \
    --arg coverage_status "$coverage_status" \
    --argjson coverage_included "$COVERAGE_INCLUDED" \
    --argjson coverage_excluded "$COVERAGE_EXCLUDED" \
    --argjson coverage_limitations "$COVERAGE_LIMITATIONS" \
    --argjson findings_count "$findings_count" \
    --arg highest_severity "$highest_severity" \
    --arg gate_mode "$gate_mode" \
    --arg gate_conclusion "$gate_conclusion" \
    --arg evidence_type "$evidence_type" \
    --argjson evidence_path "$evidence_path" \
    --argjson evidence_sha "$evidence_sha" \
    '{
      schema_version: "1.0.0",
      evaluation: {id: $evaluation_id, kind: "scanner"},
      tool: {name: $tool_name, version: $tool_version},
      scope: {repository: $repository, ref: $ref, target: $scope_target},
      completion: {status: $completion, reason: $reason},
      coverage: {
        status: $coverage_status,
        included: $coverage_included,
        excluded: $coverage_excluded,
        limitations: $coverage_limitations
      },
      findings: {count: $findings_count, highest_severity: $highest_severity},
      suppressions: {count: null, sources: []},
      merge_gate: {mode: $gate_mode, conclusion: $gate_conclusion, reason: $reason},
      timing: {started_at: null, completed_at: (now | todateiso8601), duration_ms: null},
      evidence: [{type: $evidence_type, path: $evidence_path, sha256: $evidence_sha}]
    }' > "$EVALUATION_RESULT_FILE"

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
      printf 'completion=%s\n' "$completion"
      printf 'findings_count=%s\n' "$findings_count"
      printf 'merge_conclusion=%s\n' "$gate_conclusion"
      printf 'evaluation_result=%s\n' "$EVALUATION_RESULT_FILE"
    } >> "$GITHUB_OUTPUT"
  fi
}

exit_detail="${TOOL_EXIT_CODE:+ (exit ${TOOL_EXIT_CODE})}"
case "$TOOL_OUTCOME" in
  skipped)
    emit_result skipped "scanner invocation was skipped" not-applicable null unknown not-evaluated
    exit 0
    ;;
  cancelled)
    emit_result incomplete "scanner invocation was cancelled${exit_detail}" partial null unknown fail
    exit 2
    ;;
  timed-out)
    emit_result incomplete "scanner invocation timed out${exit_detail}" partial null unknown fail
    exit 2
    ;;
  failure)
    emit_result error "scanner invocation failed${exit_detail}" unknown null unknown fail
    exit 2
    ;;
esac

if [ -z "$RAW_EVIDENCE" ] || [ ! -s "$RAW_EVIDENCE" ] || ! jq -e '
  .version == "2.1.0"
  and (.runs | type == "array" and length > 0)
  and all(.runs[]; ((.results // []) | type == "array"))
' "$RAW_EVIDENCE" >/dev/null 2>&1; then
  emit_result error "scanner produced missing or malformed SARIF" unknown null unknown fail
  exit 2
fi

findings_count="$(jq '[.runs[] | (.results // [])[]] | length' "$RAW_EVIDENCE")"
highest_severity="$(jq -r '
  [.runs[] | (.results // [])[] | (.level // "unknown")]
  | if length == 0 then "none"
    elif any(.[]; . == "error") then "high"
    elif any(.[]; . == "warning") then "medium"
    elif any(.[]; . == "note") then "info"
    else "unknown" end
' "$RAW_EVIDENCE")"

if [ "$findings_count" -eq 0 ]; then
  emit_result complete "scanner completed with validated SARIF" complete 0 none pass
  exit 0
fi
if [ "$BLOCKING" = true ]; then
  emit_result complete "validated findings met the configured gate" complete "$findings_count" "$highest_severity" fail
  exit 1
fi
emit_result complete "validated findings are advisory" complete "$findings_count" "$highest_severity" pass

#!/usr/bin/env bash
# scanner-outcome: normalize SARIF findings, operational status, and gate policy.
set -euo pipefail

: "${SCANNER_NAME:?SCANNER_NAME is required}"
: "${SCANNER_OUTCOME:?SCANNER_OUTCOME is required}"
: "${RESULT_FILE:?RESULT_FILE is required}"
: "${BLOCKING:?BLOCKING is required}"

SCANNER_VERSION="${SCANNER_VERSION:-}"
EVALUATION_REPOSITORY="${EVALUATION_REPOSITORY:-${GITHUB_REPOSITORY:-}}"
EVALUATION_REF="${EVALUATION_REF:-${GITHUB_SHA:-}}"
EVALUATION_RESULT_FILE="${EVALUATION_RESULT_FILE:-${RUNNER_TEMP:-$PWD}/${SCANNER_NAME}-evaluation-result.json}"

case "$BLOCKING" in
  true|false) ;;
  *) printf 'scanner-outcome error: BLOCKING must be true or false\n' >&2; exit 2 ;;
esac

emit() {
  local completion="$1"
  local result="$2"
  local conclusion="$3"
  local findings_count="$4"
  local reason="$5"
  local coverage_status="$6"
  local gate_mode=advisory
  local gate_conclusion="$conclusion"
  local gate_reason="$reason"
  local highest_severity="unknown"
  local evidence_sha=null
  local tool_version=null
  local repository=null
  local ref=null

  if [ "$findings_count" = "0" ]; then
    highest_severity="none"
  fi
  if [ "$BLOCKING" = true ]; then
    gate_mode=blocking
  fi
  case "$gate_conclusion" in
    pass|fail) ;;
    skip) gate_conclusion=not-evaluated ;;
    error) gate_conclusion=fail ;;
    *) gate_conclusion=not-evaluated ;;
  esac
  if [ -s "$RESULT_FILE" ]; then
    evidence_sha="$(shasum -a 256 "$RESULT_FILE" | awk '{print $1}')"
  fi
  if [ -n "$SCANNER_VERSION" ]; then
    tool_version="$(jq -Rn --arg value "$SCANNER_VERSION" '$value')"
  fi
  if [ -n "$EVALUATION_REPOSITORY" ]; then
    repository="$(jq -Rn --arg value "$EVALUATION_REPOSITORY" '$value')"
  fi
  if [ -n "$EVALUATION_REF" ]; then
    ref="$(jq -Rn --arg value "$EVALUATION_REF" '$value')"
  fi

  mkdir -p "$(dirname "$EVALUATION_RESULT_FILE")"

  jq -n \
    --arg scanner "$SCANNER_NAME" \
    --argjson scanner_version "$tool_version" \
    --argjson repository "$repository" \
    --argjson ref "$ref" \
    --arg completion "$completion" \
    --arg reason "$reason" \
    --arg coverage_status "$coverage_status" \
    --arg result "$result" \
    --arg conclusion "$conclusion" \
    --arg gate_mode "$gate_mode" \
    --arg gate_conclusion "$gate_conclusion" \
    --arg gate_reason "$gate_reason" \
    --arg highest_severity "$highest_severity" \
    --argjson findings_count "$findings_count" \
    --arg evidence_path "$RESULT_FILE" \
    --argjson evidence_sha "$(if [ "$evidence_sha" = null ]; then printf null; else jq -Rn --arg value "$evidence_sha" '$value'; fi)" \
    '{
      schema_version: "1.0.0",
      evaluation: {id: $scanner, kind: "scanner"},
      tool: {name: $scanner, version: $scanner_version},
      scope: {repository: $repository, ref: $ref, target: "repository"},
      completion: {status: $completion, reason: $reason},
      coverage: {status: $coverage_status, included: [], excluded: [], limitations: []},
      findings: {count: $findings_count, highest_severity: $highest_severity},
      suppressions: {count: null, sources: []},
      merge_gate: {mode: $gate_mode, conclusion: $gate_conclusion, reason: $gate_reason},
      timing: {started_at: null, completed_at: (now | todateiso8601), duration_ms: null},
      evidence: [
        if $evidence_sha == null
        then {type: "none", path: null, sha256: null}
        else {type: "sarif", path: $evidence_path, sha256: $evidence_sha}
        end
      ],
      _legacy: {result: $result, conclusion: $conclusion}
    } | del(._legacy)' > "$EVALUATION_RESULT_FILE"

  cat "$EVALUATION_RESULT_FILE"

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
      printf 'completion=%s\n' "$completion"
      printf 'result=%s\n' "$result"
      printf 'conclusion=%s\n' "$conclusion"
      printf 'findings_count=%s\n' "$findings_count"
      printf 'evaluation_result=%s\n' "$EVALUATION_RESULT_FILE"
    } >> "$GITHUB_OUTPUT"
  fi
}

case "$SCANNER_OUTCOME" in
  success) ;;
  skipped)
    emit skipped skipped skip null "scanner was skipped by event or configuration" not-applicable
    exit 0
    ;;
  cancelled)
    emit incomplete incomplete error null "scanner was cancelled before completion" unknown
    printf 'scanner-outcome incomplete: %s was cancelled\n' "$SCANNER_NAME" >&2
    exit 2
    ;;
  *)
    emit error error error null "scanner ended with ${SCANNER_OUTCOME}" unknown
    printf 'scanner-outcome error: %s ended with %s\n' "$SCANNER_NAME" "$SCANNER_OUTCOME" >&2
    exit 2
    ;;
esac

if [ ! -s "$RESULT_FILE" ] || ! jq -e '
  .version == "2.1.0"
  and (.runs | type == "array" and length > 0)
  and all(.runs[]; ((.results // []) | type == "array"))
' "$RESULT_FILE" >/dev/null 2>&1; then
  emit error error error null "scanner produced missing or malformed SARIF" unknown
  printf 'scanner-outcome error: %s produced missing or malformed SARIF\n' "$SCANNER_NAME" >&2
  exit 2
fi

findings_count="$(jq '[.runs[] | (.results // [])[]] | length' "$RESULT_FILE")"
if [ "$findings_count" -eq 0 ]; then
  emit complete no-findings pass 0 "scanner completed with validated SARIF" complete
  exit 0
fi

if [ "$BLOCKING" = "true" ]; then
  emit complete findings fail "$findings_count" "scanner completed; findings met the configured gate" complete
  exit 1
fi

emit complete findings pass "$findings_count" "scanner completed; findings are advisory" complete

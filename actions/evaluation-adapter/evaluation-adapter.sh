#!/usr/bin/env bash
# Normalize generic scanner lifecycle and SARIF evidence into Evaluation Result v1.
set -euo pipefail

: "${EVALUATION_ID:?EVALUATION_ID is required}"
: "${TOOL_NAME:?TOOL_NAME is required}"
: "${TOOL_VERSION:?TOOL_VERSION is required}"
: "${TOOL_OUTCOME:?TOOL_OUTCOME is required}"

TOOL_EXIT_CODE="${TOOL_EXIT_CODE:-}"
RAW_EVIDENCE="${RAW_EVIDENCE:-}"
EVIDENCE_ARTIFACT="${EVIDENCE_ARTIFACT:-}"
REMEDIATION_GUIDANCE="${REMEDIATION_GUIDANCE:-Review the reported rule, correct the affected source, and document any verified false positive.}"
MAX_SUMMARY_FINDINGS="${MAX_SUMMARY_FINDINGS:-20}"
BLOCKING="${BLOCKING:-false}"
SCOPE_TARGET="${SCOPE_TARGET:-repository}"
COVERAGE_INCLUDED="${COVERAGE_INCLUDED:-[]}"
COVERAGE_EXCLUDED="${COVERAGE_EXCLUDED:-[]}"
COVERAGE_LIMITATIONS="${COVERAGE_LIMITATIONS:-[]}"
EVALUATION_REPOSITORY="${EVALUATION_REPOSITORY:-${GITHUB_REPOSITORY:-}}"
EVALUATION_REF="${EVALUATION_REF:-${GITHUB_SHA:-}}"
EVALUATION_RESULT_FILE="${EVALUATION_RESULT_FILE:-${RUNNER_TEMP:-$PWD}/${EVALUATION_ID}-evaluation-result.json}"
SUMMARY_FILE="${SUMMARY_FILE:-${RUNNER_TEMP:-$PWD}/${EVALUATION_ID}-summary.md}"

case "$BLOCKING" in true|false) ;; *) printf 'evaluation-adapter error: BLOCKING must be true or false\n' >&2; exit 2 ;; esac
case "$TOOL_OUTCOME" in success|failure|cancelled|timed-out|skipped) ;; *) printf 'evaluation-adapter error: invalid TOOL_OUTCOME\n' >&2; exit 2 ;; esac
case "$MAX_SUMMARY_FINDINGS" in ''|*[!0-9]*) printf 'evaluation-adapter error: MAX_SUMMARY_FINDINGS must be an integer\n' >&2; exit 2 ;; esac
[ "$MAX_SUMMARY_FINDINGS" -ge 1 ] && [ "$MAX_SUMMARY_FINDINGS" -le 100 ] \
  || { printf 'evaluation-adapter error: MAX_SUMMARY_FINDINGS must be between 1 and 100\n' >&2; exit 2; }

for coverage_json in "$COVERAGE_INCLUDED" "$COVERAGE_EXCLUDED" "$COVERAGE_LIMITATIONS"; do
  jq -e 'type == "array" and all(.[]; type == "string")' <<< "$coverage_json" >/dev/null \
    || { printf 'evaluation-adapter error: coverage inputs must be JSON string arrays\n' >&2; exit 2; }
done

json_or_null() {
  if [ -n "$1" ]; then jq -Rn --arg value "$1" '$value'; else printf 'null\n'; fi
}

sha256_file() {
  local path="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  else
    printf 'evaluation-adapter error: sha256sum or shasum is required\n' >&2
    return 1
  fi
}

render_findings() {
  [ -n "$RAW_EVIDENCE" ] && [ -s "$RAW_EVIDENCE" ] || return 0
  jq -r --argjson limit "$MAX_SUMMARY_FINDINGS" '
    def clean:
      tostring
      | gsub("[\\r\\n|`]"; " ")
      | gsub("[[:space:]]+"; " ");
    [.runs[] as $run
      | (($run.tool.driver.rules // [])
          | map({key: .id, value: (.helpUri // .help.markdown // .help.text // "")})
          | from_entries) as $help
      | ($run.results // [])[]
      | {
          severity: (.level // "unknown" | clean),
          rule: (.ruleId // "unknown" | clean),
          location: (
            ((.locations[0].physicalLocation.artifactLocation.uri // "unknown") | clean)
            + ":"
            + ((.locations[0].physicalLocation.region.startLine // "?") | tostring)
          ),
          message: (.message.text // .message.markdown // "No description supplied" | clean),
          help: (($help[.ruleId] // "See the scanner rule documentation") | clean)
        }
    ][0:$limit][]
    | "| `\(.severity)` | `\(.rule)` | `\(.location)` | \(.message) | \(.help) |"
  ' "$RAW_EVIDENCE"
}

emit_annotations() {
  local annotation=warning
  [ "$BLOCKING" = false ] || annotation=error
  [ -n "$RAW_EVIDENCE" ] && [ -s "$RAW_EVIDENCE" ] || return 0
  jq -r --argjson limit "$MAX_SUMMARY_FINDINGS" '
    def command_data:
      tostring
      | gsub("%"; "%25")
      | gsub("\\r"; "%0D")
      | gsub("\\n"; "%0A");
    def command_property:
      command_data
      | gsub(":"; "%3A")
      | gsub(","; "%2C");
    [.runs[] | (.results // [])[]][0:$limit][]
    | [
        (.locations[0].physicalLocation.artifactLocation.uri // "" | command_property),
        ((.locations[0].physicalLocation.region.startLine // 1)
          | if type == "number" and . >= 1 then floor else 1 end
          | tostring),
        (.ruleId // "security finding" | command_property),
        (.message.text // .message.markdown // "Security finding" | command_data)
      ] | @tsv
  ' "$RAW_EVIDENCE" | while IFS=$'\t' read -r path line rule message; do
    if [ -n "$path" ]; then
      printf '::%s file=%s,line=%s,title=%s::%s\n' "$annotation" "$path" "$line" "$rule" "$message"
    else
      printf '::%s title=%s::%s\n' "$annotation" "$rule" "$message"
    fi
  done
}

render_summary() {
  local completion="$1"
  local reason="$2"
  local findings_count="$3"
  local highest_severity="$4"
  local gate_conclusion="$5"
  local rendered_count=0
  local artifact_display="${EVIDENCE_ARTIFACT:-not-published}"

  [ "$findings_count" = null ] || rendered_count="$findings_count"
  mkdir -p "$(dirname "$SUMMARY_FILE")"
  {
    printf '# Evaluation: %s\n\n' "$EVALUATION_ID"
    printf -- "- Tool: \`%s@%s\`\n" "$TOOL_NAME" "$TOOL_VERSION"
    printf -- '- Completion: **%s** — %s\n' "$completion" "$reason"
    printf -- '- Findings: **%s**; highest severity: **%s**\n' "$findings_count" "$highest_severity"
    printf -- '- Gate: **%s** (%s)\n' "$gate_conclusion" "$([ "$BLOCKING" = true ] && printf blocking || printf advisory)"
    printf -- "- Scope: \`%s\`\n" "$SCOPE_TARGET"
    printf -- "- Evidence artifact: \`%s\`; file: \`%s\`\n" "$artifact_display" "${RAW_EVIDENCE:-none}"
    printf -- '- Coverage included: %s\n' "$(jq -r 'if length == 0 then "none declared" else join("; ") end' <<< "$COVERAGE_INCLUDED")"
    printf -- '- Coverage limitations: %s\n\n' "$(jq -r 'if length == 0 then "none declared" else join("; ") end' <<< "$COVERAGE_LIMITATIONS")"
    if [ "$rendered_count" -gt 0 ] && [ -s "$RAW_EVIDENCE" ]; then
      printf '## Findings\n\n'
      printf '| Severity | Rule | Location | What was found | Rule guidance |\n'
      printf '|---|---|---|---|---|\n'
      render_findings
      if [ "$rendered_count" -gt "$MAX_SUMMARY_FINDINGS" ]; then
        printf "\nShowing %s of %s findings; download \`%s\` for the complete result.\n" \
          "$MAX_SUMMARY_FINDINGS" "$rendered_count" "$artifact_display"
      fi
      printf '\n## How to remediate\n\n%s\n' "$REMEDIATION_GUIDANCE"
    elif [ "$completion" = complete ]; then
      printf '## Findings\n\nNo findings were reported for the declared scope.\n'
    else
      printf '## Next action\n\nResolve the completion error above, then rerun this evaluation.\n'
    fi
  } > "$SUMMARY_FILE"
  [ -z "${GITHUB_STEP_SUMMARY:-}" ] || command cat "$SUMMARY_FILE" >> "$GITHUB_STEP_SUMMARY"
  [ "$rendered_count" -eq 0 ] || emit_annotations
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
  local evidence_artifact=null
  local gate_mode=advisory

  [ "$BLOCKING" = false ] || gate_mode=blocking
  if [ -n "$RAW_EVIDENCE" ] && [ -s "$RAW_EVIDENCE" ]; then
    evidence_type=sarif
    evidence_path="$(json_or_null "$RAW_EVIDENCE")"
    evidence_sha="$(sha256_file "$RAW_EVIDENCE")"
    evidence_sha="$(json_or_null "$evidence_sha")"
    evidence_artifact="$(json_or_null "$EVIDENCE_ARTIFACT")"
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
    --argjson evidence_artifact "$evidence_artifact" \
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
      evidence: [{type: $evidence_type, path: $evidence_path, sha256: $evidence_sha, artifact: $evidence_artifact}]
    }' > "$EVALUATION_RESULT_FILE"

  render_summary "$completion" "$reason" "$findings_count" "$highest_severity" "$gate_conclusion"

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
      printf 'completion=%s\n' "$completion"
      printf 'findings_count=%s\n' "$findings_count"
      printf 'merge_conclusion=%s\n' "$gate_conclusion"
      printf 'evaluation_result=%s\n' "$EVALUATION_RESULT_FILE"
      printf 'evidence_artifact=%s\n' "$EVIDENCE_ARTIFACT"
      printf 'summary=%s\n' "$SUMMARY_FILE"
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

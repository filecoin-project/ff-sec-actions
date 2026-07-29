#!/usr/bin/env bash
# scanner-outcome: normalize SARIF findings, operational status, and gate policy.
set -euo pipefail

: "${SCANNER_NAME:?SCANNER_NAME is required}"
: "${SCANNER_OUTCOME:?SCANNER_OUTCOME is required}"
: "${RESULT_FILE:?RESULT_FILE is required}"
: "${BLOCKING:?BLOCKING is required}"

case "$BLOCKING" in
  true|false) ;;
  *) printf 'scanner-outcome error: BLOCKING must be true or false\n' >&2; exit 2 ;;
esac

emit() {
  local completion="$1"
  local result="$2"
  local conclusion="$3"
  local findings_count="$4"

  jq -n \
    --arg scanner "$SCANNER_NAME" \
    --arg completion "$completion" \
    --arg result "$result" \
    --arg conclusion "$conclusion" \
    --argjson findings_count "$findings_count" \
    '{
      scanner: $scanner,
      completion: $completion,
      result: $result,
      conclusion: $conclusion,
      findings_count: $findings_count
    }'

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
      printf 'completion=%s\n' "$completion"
      printf 'result=%s\n' "$result"
      printf 'conclusion=%s\n' "$conclusion"
      printf 'findings_count=%s\n' "$findings_count"
    } >> "$GITHUB_OUTPUT"
  fi
}

if [ "$SCANNER_OUTCOME" != "success" ]; then
  emit error error error 0
  printf 'scanner-outcome error: %s ended with %s\n' "$SCANNER_NAME" "$SCANNER_OUTCOME" >&2
  exit 2
fi

if [ ! -s "$RESULT_FILE" ] || ! jq -e '
  .version == "2.1.0"
  and (.runs | type == "array" and length > 0)
  and all(.runs[]; ((.results // []) | type == "array"))
' "$RESULT_FILE" >/dev/null 2>&1; then
  emit error error error 0
  printf 'scanner-outcome error: %s produced missing or malformed SARIF\n' "$SCANNER_NAME" >&2
  exit 2
fi

findings_count="$(jq '[.runs[] | (.results // [])[]] | length' "$RESULT_FILE")"
if [ "$findings_count" -eq 0 ]; then
  emit complete no-findings pass 0
  exit 0
fi

if [ "$BLOCKING" = "true" ]; then
  emit complete findings fail "$findings_count"
  exit 1
fi

emit complete findings pass "$findings_count"

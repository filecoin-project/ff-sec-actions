#!/usr/bin/env bash
# Invoke Semgrep only as a source scanner; never invoke Consumer Project tooling.
set -euo pipefail

SCAN_TARGET="${SCAN_TARGET:-.}"
SEMGREP_CONFIG="${SEMGREP_CONFIG:-}"
RESULT_FILE="${RESULT_FILE:-semgrep-baseline.sarif}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/null}"

if [ -z "$SEMGREP_CONFIG" ]; then
  SEMGREP_CONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/rules/ecosystem-baseline.yml"
fi

if [ ! -f "$SEMGREP_CONFIG" ]; then
  printf 'semgrep-scan error: rules file is missing: %s\n' "$SEMGREP_CONFIG" >&2
  printf 'scanner_outcome=failure\nresult_file=%s\n' "$RESULT_FILE" >> "$GITHUB_OUTPUT"
  exit 1
fi

actual_exit=0
semgrep scan \
  --metrics=off \
  --disable-version-check \
  --config "$SEMGREP_CONFIG" \
  --sarif \
  --output "$RESULT_FILE" \
  "$SCAN_TARGET" || actual_exit="$?"

if [ "$actual_exit" -eq 0 ] && [ -s "$RESULT_FILE" ]; then
  printf 'scanner_outcome=success\nresult_file=%s\n' "$RESULT_FILE" >> "$GITHUB_OUTPUT"
  exit 0
fi

printf 'scanner_outcome=failure\nresult_file=%s\n' "$RESULT_FILE" >> "$GITHUB_OUTPUT"
printf 'semgrep-scan error: Semgrep exited %s without validated output\n' "$actual_exit" >&2
exit 1

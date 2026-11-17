#!/usr/bin/env bash
# Invoke Semgrep only as a source scanner; never invoke Consumer Project tooling.
set -euo pipefail

SCAN_TARGET="${SCAN_TARGET:-.}"
SEMGREP_CONFIG="${SEMGREP_CONFIG:-}"
RESULT_FILE="${RESULT_FILE:-semgrep-baseline.sarif}"
BASELINE_REF="${BASELINE_REF:-}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/null}"

RULESET="${RULESET:-ecosystem-baseline}"

# A named ruleset always resolves to a repository-owned file at this action's
# own commit; an explicit SEMGREP_CONFIG (tests and maintainers) overrides it.
if [ -z "$SEMGREP_CONFIG" ]; then
  case "$RULESET" in
    ecosystem-baseline|foc-integrator) ;;
    *)
      printf 'semgrep-scan error: ruleset must be ecosystem-baseline or foc-integrator\n' >&2
      printf 'scanner_outcome=failure\nresult_file=%s\nclassification=not-requested\n' "$RESULT_FILE" >> "$GITHUB_OUTPUT"
      exit 1
      ;;
  esac
  SEMGREP_CONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/rules/${RULESET}.yml"
fi

if [ ! -f "$SEMGREP_CONFIG" ]; then
  printf 'semgrep-scan error: rules file is missing: %s\n' "$SEMGREP_CONFIG" >&2
  printf 'scanner_outcome=failure\nresult_file=%s\nclassification=not-requested\n' "$RESULT_FILE" >> "$GITHUB_OUTPUT"
  exit 1
fi

# Mark each finding new or unchanged relative to BASELINE_REF using SARIF
# baselineState. Any failure leaves the complete, unclassified SARIF in place.
classify_against_baseline() {
  local scan_root new_findings classified
  # Only a full commit SHA is accepted, so the ref can never be read as an option.
  [[ "$BASELINE_REF" =~ ^[0-9a-f]{40}$ ]] || return 1
  scan_root="$(cd "$SCAN_TARGET" && pwd -P)"
  # Semgrep runs git on the untrusted checkout: trust only this directory and
  # never run repository hooks or a filesystem monitor.
  export GIT_CONFIG_COUNT=3
  export GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0="$scan_root"
  export GIT_CONFIG_KEY_1=core.hooksPath GIT_CONFIG_VALUE_1=/dev/null
  export GIT_CONFIG_KEY_2=core.fsmonitor GIT_CONFIG_VALUE_2=false
  git -C "$scan_root" cat-file -e "${BASELINE_REF}^{commit}" 2>/dev/null || return 1

  new_findings="$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/semgrep-new.XXXXXX")"
  classified="$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/semgrep-classified.XXXXXX")"
  if ! (cd "$scan_root" && semgrep scan \
      --metrics=off \
      --disable-version-check \
      --config "$SEMGREP_CONFIG" \
      --baseline-commit "$BASELINE_REF" \
      --sarif \
      --output "$new_findings" \
      .) || [ ! -s "$new_findings" ]; then
    rm -f "$new_findings" "$classified"
    return 1
  fi
  # A finding without a fingerprint is treated as new so it is never hidden.
  if ! jq --slurpfile baseline "$new_findings" '
      ([$baseline[0].runs[]? | (.results // [])[] | .fingerprints["matchBasedId/v1"] // empty]) as $new
      | .runs |= map(.results |= ((. // []) | map(
          (.fingerprints["matchBasedId/v1"] // null) as $id
          | . + {baselineState: (if $id == null or ($new | index($id)) != null then "new" else "unchanged" end)})))
    ' "$RESULT_FILE" > "$classified"; then
    rm -f "$new_findings" "$classified"
    return 1
  fi
  mv "$classified" "$RESULT_FILE"
  rm -f "$new_findings"
}

actual_exit=0
semgrep scan \
  --metrics=off \
  --disable-version-check \
  --config "$SEMGREP_CONFIG" \
  --sarif \
  --output "$RESULT_FILE" \
  "$SCAN_TARGET" || actual_exit="$?"

if [ "$actual_exit" -eq 0 ] && [ -s "$RESULT_FILE" ]; then
  classification=not-requested
  if [ -n "$BASELINE_REF" ]; then
    classification=unavailable
    if classify_against_baseline; then
      classification=classified
    else
      printf 'semgrep-scan warning: findings could not be classified against %s\n' "$BASELINE_REF" >&2
    fi
  fi
  printf 'scanner_outcome=success\nresult_file=%s\nclassification=%s\n' "$RESULT_FILE" "$classification" >> "$GITHUB_OUTPUT"
  exit 0
fi

printf 'scanner_outcome=failure\nresult_file=%s\nclassification=not-requested\n' "$RESULT_FILE" >> "$GITHUB_OUTPUT"
printf 'semgrep-scan error: Semgrep exited %s without validated output\n' "$actual_exit" >&2
exit 1

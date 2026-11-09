#!/usr/bin/env bash
# check-baseline-no-exec: enforce non-executing manifest inspection workflows.
#
# Usage: scripts/check-baseline-no-exec.sh [WORKFLOW ...]
# Optional environment variables:
#   BASELINE_NO_EXEC_ROOT    Root used to resolve workflow paths.
#   BASELINE_NO_EXEC_POLICY  Baseline policy JSON path.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scan_root="${BASELINE_NO_EXEC_ROOT:-$repo_root}"
policy="${BASELINE_NO_EXEC_POLICY:-$scan_root/security/baseline-policy.json}"

fail() {
  printf 'baseline-no-exec error: %s\n' "$*" >&2
  exit 1
}

[ -f "$policy" ] || fail "policy is missing: $policy"
cd "$scan_root"

jq -e '
  .schema_version == 1
  and (.workflows | type == "object" and length > 0)
  and all(.workflows[];
    (.coverage_mode | IN("manifest-and-lockfile", "source-manifest", "git-history", "workflow-definitions"))
    and (.allowed_actions | type == "array" and length > 0)
    and all(.allowed_actions[]; type == "string" and length > 0)
    and (.limitations | type == "array" and length > 0)
    and all(.limitations[]; type == "string" and length > 0))
' "$policy" >/dev/null || fail "policy does not match schema version 1"

if [ "$#" -gt 0 ]; then
  workflows=("$@")
else
  workflows=("")
  while IFS= read -r path; do
    workflows+=("$path")
  done < <(jq -r '.workflows | keys[]' "$policy")
fi

for relative_path in "${workflows[@]}"; do
  [ -n "$relative_path" ] || continue
  workflow="$scan_root/$relative_path"
  [ -f "$workflow" ] || fail "declared baseline workflow is missing: $relative_path"
  jq -e --arg path "$relative_path" '.workflows[$path] != null' "$policy" >/dev/null \
    || fail "baseline workflow is not declared in policy: $relative_path"

  if grep -Eq '^[[:space:]-]*run:[[:space:]]*' "$workflow"; then
    fail "$relative_path contains a shell execution step"
  fi

  if grep -Eq '^[[:space:]]+(package-manager|node-version|audit-level|audit-blocking):' "$workflow"; then
    fail "$relative_path exposes a project package-manager execution input"
  fi

  actual_actions="$({
    sed -nE 's#^[[:space:]-]*uses:[[:space:]]+([^@[:space:]#]+)@[^[:space:]#]+.*$#\1#p' "$workflow"
  } | sort -u)"
  declared_actions="$(jq -r --arg path "$relative_path" \
    '.workflows[$path].allowed_actions[]' "$policy" | sort -u)"
  [ "$actual_actions" = "$declared_actions" ] \
    || fail "$relative_path actions differ from the reviewed baseline policy"
done

# Baseline classification runs git on the untrusted checkout. It must accept
# only a full commit SHA and must disable repository hooks and the filesystem
# monitor for every git invocation Semgrep makes.
semgrep_scan="$scan_root/actions/semgrep-scan/semgrep-scan.sh"
if [ -f "$semgrep_scan" ] && grep -Fq -- '--baseline-commit' "$semgrep_scan"; then
  # shellcheck disable=SC2016 # match literal source text
  for required in \
    'GIT_CONFIG_KEY_0=safe.directory' \
    'GIT_CONFIG_KEY_1=core.hooksPath GIT_CONFIG_VALUE_1=/dev/null' \
    'GIT_CONFIG_KEY_2=core.fsmonitor GIT_CONFIG_VALUE_2=false' \
    'export GIT_CONFIG_COUNT=3' \
    '[[ "$BASELINE_REF" =~ ^[0-9a-f]{40}$ ]]'; do
    grep -Fq -- "$required" "$semgrep_scan" \
      || fail "semgrep-scan baseline classification is missing git hardening: $required"
  done
fi

printf 'baseline no-execution checks passed.\n'

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
    (.coverage_mode | IN("manifest-and-lockfile", "source-manifest"))
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

printf 'baseline no-execution checks passed.\n'

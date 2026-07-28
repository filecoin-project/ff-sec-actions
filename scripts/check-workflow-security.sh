#!/usr/bin/env bash
# check-workflow-security: enforce declared job authority and safe checkout.
#
# Usage: scripts/check-workflow-security.sh [WORKFLOW ...]
# Optional environment variables:
#   WORKFLOW_SECURITY_ROOT    Root used to resolve workflow paths.
#   WORKFLOW_SECURITY_POLICY  Policy JSON path.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scan_root="${WORKFLOW_SECURITY_ROOT:-$repo_root}"
policy="${WORKFLOW_SECURITY_POLICY:-$scan_root/security/workflow-policy.json}"

fail() {
  printf 'workflow-security error: %s\n' "$*" >&2
  exit 1
}

[ -f "$policy" ] || fail "policy is missing: $policy"
cd "$scan_root"

jq -e '
  .schema_version == 1
  and (.workflows | type == "object" and length > 0)
  and all(.workflows[];
    type == "object"
    and all(.[];
      (.permissions | type == "object")
      and all(.permissions[]; IN("read", "write", "none"))))
' "$policy" >/dev/null || fail "policy does not match schema version 1"

if [ "$#" -gt 0 ]; then
  workflows=("$@")
else
  actual_workflows="$({
    find .github/workflows examples -maxdepth 1 -type f -name '*.yml'
  } | sed 's#^./##' | sort)"
  declared_workflows="$(jq -r '.workflows | keys[]' "$policy" | sort)"
  [ "$actual_workflows" = "$declared_workflows" ] \
    || fail "policy must declare every maintained workflow and example"

  workflows=("")
  while IFS= read -r path; do
    workflows+=("$path")
  done < <(jq -r '.workflows | keys[]' "$policy")
fi

for relative_path in "${workflows[@]}"; do
  [ -n "$relative_path" ] || continue
  workflow="$scan_root/$relative_path"
  [ -f "$workflow" ] || fail "declared workflow is missing: $relative_path"
  jq -e --arg path "$relative_path" '.workflows[$path] != null' "$policy" >/dev/null \
    || fail "workflow is not declared in policy: $relative_path"

  actual_jobs="$(awk '
    /^jobs:[[:space:]]*$/ { in_jobs = 1; next }
    in_jobs && /^[^[:space:]#]/ { in_jobs = 0 }
    in_jobs && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
      line = $0
      sub(/^  /, "", line)
      sub(/:[[:space:]]*$/, "", line)
      print line
    }
  ' "$workflow" | sort)"
  declared_jobs="$(jq -r --arg path "$relative_path" \
    '.workflows[$path] | keys[]' "$policy" | sort)"
  [ "$actual_jobs" = "$declared_jobs" ] \
    || fail "$relative_path jobs do not match the authority policy"

  while IFS= read -r job; do
    [ -n "$job" ] || continue
    actual_permissions="$(awk -v selected_job="$job" '
      $0 ~ "^  " selected_job ":[[:space:]]*$" { in_job = 1; next }
      in_job && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ { in_job = 0 }
      in_job && /^    permissions:[[:space:]]*\{\}[[:space:]]*$/ {
        found_permissions = 1
      }
      in_job && /^    permissions:[[:space:]]*$/ {
        found_permissions = 1
        in_permissions = 1
        next
      }
      in_permissions && /^      [a-z-]+:[[:space:]]*(read|write|none)([[:space:]#].*)?$/ {
        line = $0
        sub(/^      /, "", line)
        split(line, fields, ":")
        permission = fields[1]
        value = fields[2]
        sub(/^[[:space:]]*/, "", value)
        sub(/[[:space:]#].*$/, "", value)
        print permission "\t" value
        next
      }
      in_permissions && !/^      / { in_permissions = 0 }
      END {
        if (!found_permissions) exit 42
      }
    ' "$workflow")" || {
      status="$?"
      [ "$status" -eq 42 ] && fail "$relative_path job $job has no explicit permissions"
      fail "could not parse permissions for $relative_path job $job"
    }

    actual_permissions_json="$(printf '%s\n' "$actual_permissions" | jq -Rn '
      [inputs | select(length > 0) | split("\t") | {(.[0]): .[1]}] | add // {}
    ')"
    declared_permissions_json="$(jq -c --arg path "$relative_path" --arg job "$job" \
      '.workflows[$path][$job].permissions' "$policy")"
    [ "$(jq -Sc . <<< "$actual_permissions_json")" = "$(jq -Sc . <<< "$declared_permissions_json")" ] \
      || fail "$relative_path job $job permissions differ from policy"
  done <<< "$actual_jobs"

  awk '
    function finish_checkout() {
      if (in_checkout && !safe_checkout) {
        in_checkout = 0
        print "checkout is missing persist-credentials: false" > "/dev/stderr"
        exit 43
      }
      in_checkout = 0
      safe_checkout = 0
    }
    /^[[:space:]]*-[[:space:]]+uses:[[:space:]]+actions\/checkout@/ {
      finish_checkout()
      in_checkout = 1
      checkout_indent = match($0, /-/) - 1
      next
    }
    in_checkout && /^[[:space:]]*-[[:space:]]+(name:|uses:|run:)/ {
      indent = match($0, /-/) - 1
      if (indent <= checkout_indent) finish_checkout()
    }
    in_checkout && /^[[:space:]]+persist-credentials:[[:space:]]+false([[:space:]#]|$)/ {
      safe_checkout = 1
    }
    END { finish_checkout() }
  ' "$workflow" >/dev/null \
    || fail "$relative_path contains an unsafe checkout"
done

printf 'workflow-security checks passed.\n'

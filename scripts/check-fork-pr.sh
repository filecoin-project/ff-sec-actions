#!/usr/bin/env bash
# Validate the fork-PR consumer fixture and every pinned baseline workflow it calls.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="${FORK_PR_FIXTURE_ROOT:-$repo_root/test/fixtures/fork-pr}"
workflow="$fixture_root/workflow.yml"
event="$fixture_root/event.json"
expectations="$fixture_root/expectations.json"
baseline_policy="$repo_root/security/baseline-policy.json"
repository="filecoin-project/ff-sec-actions"

fail() {
  printf 'fork-pr error: %s\n' "$*" >&2
  exit 1
}

for required in "$workflow" "$event" "$expectations" "$baseline_policy"; do
  [ -f "$required" ] || fail "required fixture input is missing: $required"
done

jq -e '
  .event_name == "pull_request"
  and .pull_request.head.repo.fork == true
  and (.pull_request.head.repo.full_name != .repository)
' "$event" >/dev/null || fail "event must model an external pull_request fork"

jq -e '
  .schema_version == 1
  and .event == "pull_request"
  and .fork == true
  and .caller_permissions == {"contents":"read"}
  and (.declared_baseline_workflows | type == "array" and length > 0)
  and (.forbidden_boundaries | type == "array" and length > 0)
' "$expectations" >/dev/null || fail "expectations do not match schema version 1"

grep -Eq '^[[:space:]]+pull_request:[[:space:]]*$' "$workflow" \
  || fail "consumer fixture does not use the ordinary pull_request event"

for path in "$workflow" "$repo_root/.github/workflows" "$repo_root/examples"; do
  if grep -R -Eq '^[[:space:]]*pull_request_target:' "$path"; then
    fail "pull_request_target is forbidden on consumer evaluation paths: $path"
  fi
done

if grep -Eq '^[[:space:]]+(contents|actions|checks|deployments|discussions|issues|packages|pages|pull-requests|security-events|statuses|id-token):[[:space:]]+write([[:space:]#]|$)|^[[:space:]]*permissions:[[:space:]]+write-all' "$workflow"; then
  fail "fork caller grants write authority"
fi

contents_read_count="$(grep -Ec '^[[:space:]]+contents:[[:space:]]+read([[:space:]#]|$)' "$workflow")"
[ "$contents_read_count" -eq 6 ] \
  || fail "top-level and all five fork jobs must cap authority at contents:read"

if grep -Eq '\$\{\{[[:space:]]*secrets\.|^[[:space:]]+secrets:[[:space:]]+(inherit|$)' "$workflow"; then
  fail "fork caller references or forwards a secret"
fi
if grep -Eq '^[[:space:]]+id-token:[[:space:]]+write([[:space:]#]|$)' "$workflow"; then
  fail "fork caller grants OIDC authority"
fi
if grep -Eq 'actions/cache@|^[[:space:]]+cache:[[:space:]]+([^f#]|f[^a]|fa[^l]|fal[^s]|fals[^e])' "$workflow"; then
  fail "fork caller enables a cache"
fi
if grep -Eq '^[[:space:]]*runs-on:.*self-hosted' "$workflow"; then
  fail "fork caller selects a self-hosted runner"
fi
if grep -Eq '^[[:space:]-]*run:[[:space:]]*|persist-credentials:[[:space:]]+true' "$workflow"; then
  fail "fork caller executes consumer code or persists checkout credentials"
fi

actual_workflows="$(
  sed -nE "s#^[[:space:]]*uses:[[:space:]]+${repository}/([^@]+)@[0-9a-f]{40}.*#\1#p" "$workflow" \
    | sort -u
)"
declared_workflows="$(jq -r '.declared_baseline_workflows[]' "$expectations" | sort -u)"
policy_workflows="$(jq -r '.workflows | keys[]' "$baseline_policy" | sort -u)"
[ "$actual_workflows" = "$declared_workflows" ] \
  || fail "fixture does not run every declared baseline evaluation"
[ "$declared_workflows" = "$policy_workflows" ] \
  || fail "fork expectations and baseline policy have drifted"

while IFS= read -r uses_ref; do
  [ -n "$uses_ref" ] || continue
  [[ "$uses_ref" =~ ^${repository}/(.+)@([0-9a-f]{40})$ ]] \
    || fail "fork fixture uses a mutable or foreign workflow: $uses_ref"
  referenced_path="${BASH_REMATCH[1]}"
  referenced_ref="${BASH_REMATCH[2]}"
  referenced_content="$(git -C "$repo_root" show "$referenced_ref:$referenced_path" 2>/dev/null)" \
    || fail "referenced baseline workflow does not exist: $uses_ref"

  jq -e --arg path "$referenced_path" '.workflows[$path] != null' "$baseline_policy" >/dev/null \
    || fail "$uses_ref is not in the reviewed baseline policy"
  grep -Eq '^[[:space:]]+workflow_call:[[:space:]]*$' <<< "$referenced_content" \
    || fail "$uses_ref is not callable"
  if grep -Eq '\$\{\{[[:space:]]*secrets\.|pull_request_target:|id-token:[[:space:]]+write|actions/cache@|runs-on:.*self-hosted|^[[:space:]-]*run:[[:space:]]*' <<< "$referenced_content"; then
    fail "$uses_ref crosses a forbidden fork boundary"
  fi
  if grep -Fq 'actions/checkout@' <<< "$referenced_content" \
    && ! grep -Eq 'persist-credentials:[[:space:]]+false' <<< "$referenced_content"; then
    fail "$uses_ref persists checkout credentials"
  fi
  if grep -Eq '^[[:space:]]+ref:[[:space:]]+' <<< "$referenced_content"; then
    fail "$uses_ref overrides the pull_request checkout ref"
  fi
done < <(sed -nE 's/^[[:space:]]*uses:[[:space:]]+([^[:space:]#]+).*/\1/p' "$workflow")

for sentinel in fork-code-executed fork-lifecycle-executed fork-secret-probe fork-oidc-probe fork-token-probe; do
  [ ! -e "$fixture_root/untrusted/$sentinel" ] \
    || fail "untrusted fork probe executed: $sentinel"
done
grep -Fq 'attack-probes.sh' "$fixture_root/untrusted/package.json" \
  || fail "malicious lifecycle probe is missing"
grep -Fq 'attack-probes.sh' "$fixture_root/untrusted/.github/workflows/pwn.yml" \
  || fail "malicious workflow probe is missing"

printf 'fork pull-request boundary checks passed.\n'

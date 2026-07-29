#!/usr/bin/env bash
# test-consumer-alpha: validate the one-file pilot interface and hosted canary contract.
# Required environment: none.
# Optional environment: none.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
example="$repo_root/examples/consumer-ecosystem-baseline.yml"
canary="$repo_root/.github/workflows/consumer-alpha-canary.yml"
quickstart="$repo_root/docs/consumers/quickstart.md"
repository="filecoin-project/ff-sec-actions"

fail() {
  printf 'consumer-alpha test failure: %s\n' "$*" >&2
  exit 1
}

for required in "$example" "$canary" "$quickstart"; do
  [ -f "$required" ] || fail "required consumer surface is missing: $required"
done

release_ref() {
  local workflow="$1"
  sed -nE "s#^[[:space:]]*uses:[[:space:]]+${repository}/.github/workflows/ecosystem-baseline.yml@([0-9a-f]{40}).*#\1#p" "$workflow"
}

example_ref="$(release_ref "$example")"
canary_ref="$(release_ref "$canary")"
[ -n "$example_ref" ] || fail "consumer example does not use an immutable Ecosystem Baseline"
[ "$example_ref" = "$canary_ref" ] || fail "hosted canary and consumer example select different releases"
git -C "$repo_root" cat-file -e "$example_ref:.github/workflows/ecosystem-baseline.yml" \
  || fail "consumer release commit is unavailable in repository history"

# GitHub validates every nested workflow's complete permission envelope before
# evaluating job conditions. Prove the immutable baseline graph never asks the
# read-only caller to elevate authority, including in disabled jobs.
baseline_content="$(git -C "$repo_root" show "$example_ref:.github/workflows/ecosystem-baseline.yml")"
while IFS='|' read -r nested_path nested_ref; do
  [ -n "$nested_path" ] || continue
  nested_content="$(git -C "$repo_root" show "$nested_ref:$nested_path")" \
    || fail "baseline nested workflow is unavailable: $nested_path@$nested_ref"
  if grep -Eq '^[[:space:]]+[a-z-]+:[[:space:]]+write([[:space:]#]|$)' <<< "$nested_content"; then
    fail "read-only baseline calls a workflow with write authority: $nested_path@$nested_ref"
  fi
done < <(
  sed -nE "s#^[[:space:]]*uses:[[:space:]]+${repository}/(\.github/workflows/[^@]+)@([0-9a-f]{40}).*#\1|\2#p" \
    <<< "$baseline_content"
)

for workflow in "$example" "$canary"; do
  grep -Fq 'require-complete: true' "$workflow" \
    || fail "$workflow does not require complete evaluation"
  grep -Fq 'actions-security-blocking: false' "$workflow" \
    || fail "$workflow does not start workflow findings advisory"
  grep -Fq 'secrets-blocking: false' "$workflow" \
    || fail "$workflow does not start historical secret findings advisory"
  if grep -Eq 'pull_request_target:|security-events:[[:space:]]+write|id-token:[[:space:]]+write|secrets:[[:space:]]+(inherit|$)' "$workflow"; then
    fail "$workflow crosses the read-only, secretless pilot boundary"
  fi
done

grep -Eq '^[[:space:]]+-[[:space:]]+optimization[[:space:]]*$' "$canary" \
  || fail "hosted canary does not run when the optimization release candidate is pushed"

for required_text in 'Profile Conclusion' 'ecosystem-baseline-evidence' '## Upgrade' '## Roll Back' 'ENABLE_GHAS'; do
  grep -Fq "$required_text" "$quickstart" \
    || fail "quickstart does not explain: $required_text"
done

printf 'consumer alpha installation contract tests passed.\n'

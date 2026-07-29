#!/usr/bin/env bash
# test-output-contract: prove consumable evaluation surfaces are release requirements.
# Required environment: none.
# Optional environment: none.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="$repo_root/scripts/check-output-contract.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/ff-sec-output-contract.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail() { printf 'output-contract test failure: %s\n' "$*" >&2; exit 1; }

bash "$checker" >/dev/null || fail "the maintained repository violates its output contract"

mkdir -p "$fixture_root/.github/workflows" "$fixture_root/actions" "$fixture_root/security" "$fixture_root/scripts"
cp -R "$repo_root/.github/workflows/." "$fixture_root/.github/workflows/"
cp -R "$repo_root/actions/." "$fixture_root/actions/"
cp "$repo_root/security/output-contract.json" "$fixture_root/security/output-contract.json"
cp "$repo_root/scripts/test-evaluation-adapter.sh" "$fixture_root/scripts/test-evaluation-adapter.sh"

sed '/remediation-guidance:/d' \
  "$fixture_root/.github/workflows/sec-secrets.yml" > "$fixture_root/sec-secrets.tmp"
mv "$fixture_root/sec-secrets.tmp" "$fixture_root/.github/workflows/sec-secrets.yml"

output=""
if output="$(OUTPUT_CONTRACT_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a normalized evaluation without remediation guidance was accepted"
fi
grep -Fq "remediation-guidance" <<< "$output" \
  || fail "the rejection did not explain the missing remediation surface"

cp "$repo_root/.github/workflows/sec-secrets.yml" \
  "$fixture_root/.github/workflows/sec-secrets.yml"
sed '/tool-outcome:/d' \
  "$fixture_root/.github/workflows/sec-secrets.yml" > "$fixture_root/sec-secrets.tmp"
mv "$fixture_root/sec-secrets.tmp" "$fixture_root/.github/workflows/sec-secrets.yml"
output=""
if output="$(OUTPUT_CONTRACT_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a normalized evaluation without public lifecycle wiring was accepted"
fi
grep -Fq "tool-outcome" <<< "$output" \
  || fail "the rejection did not explain the missing lifecycle mapping"

cp "$repo_root/.github/workflows/sec-secrets.yml" \
  "$fixture_root/.github/workflows/sec-secrets.yml"
printf '%s\n' \
  'name: Undeclared evaluation' \
  'on:' \
  '  workflow_call:' \
  > "$fixture_root/.github/workflows/undeclared-evaluation.yaml"
if OUTPUT_CONTRACT_ROOT="$fixture_root" bash "$checker" >/dev/null 2>&1; then
  fail "an undeclared reusable .yaml workflow was accepted"
fi

rm -f "$fixture_root/.github/workflows/undeclared-evaluation.yaml"
mkdir -p "$fixture_root/actions/undeclared"
cp "$repo_root/actions/semgrep-scan/action.yml" \
  "$fixture_root/actions/undeclared/action.yaml"
if OUTPUT_CONTRACT_ROOT="$fixture_root" bash "$checker" >/dev/null 2>&1; then
  fail "an undeclared action.yaml action was accepted"
fi

printf 'consumable output contract tests passed.\n'

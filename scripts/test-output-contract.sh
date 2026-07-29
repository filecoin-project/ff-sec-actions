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

mkdir -p "$fixture_root/.github/workflows" "$fixture_root/actions" "$fixture_root/security"
cp -R "$repo_root/.github/workflows/." "$fixture_root/.github/workflows/"
cp -R "$repo_root/actions/." "$fixture_root/actions/"
cp "$repo_root/security/output-contract.json" "$fixture_root/security/output-contract.json"

sed '/remediation-guidance:/d' \
  "$fixture_root/.github/workflows/sec-secrets.yml" > "$fixture_root/sec-secrets.tmp"
mv "$fixture_root/sec-secrets.tmp" "$fixture_root/.github/workflows/sec-secrets.yml"

output=""
if output="$(OUTPUT_CONTRACT_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a normalized evaluation without remediation guidance was accepted"
fi
grep -Fq "remediation-guidance" <<< "$output" \
  || fail "the rejection did not explain the missing remediation surface"

printf 'consumable output contract tests passed.\n'

#!/usr/bin/env bash
# Prove the reusable workflow documentation contract rejects drift.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="$repo_root/scripts/check-workflow-docs.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/ff-sec-workflow-docs.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail() {
  printf 'workflow-documentation test failure: %s\n' "$*" >&2
  exit 1
}

bash "$checker" >/dev/null \
  || fail "the maintained workflow documentation catalog is invalid"

mkdir -p "$fixture_root/.github/workflows" "$fixture_root/docs/workflows"
cp -R "$repo_root/.github/workflows/." "$fixture_root/.github/workflows/"
cp -R "$repo_root/docs/workflows/." "$fixture_root/docs/workflows/"

rm -f "$fixture_root/docs/workflows/sec-actions.md"
output=""
if output="$(WORKFLOW_DOCS_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a reusable workflow without a contract page was accepted"
fi
grep -Fq 'one-to-one' <<< "$output" \
  || fail "the missing-page rejection did not explain the catalog mapping"

cp "$repo_root/docs/workflows/sec-actions.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
sed '/## Completion And Gating/d' \
  "$fixture_root/docs/workflows/sec-actions.md" \
  > "$fixture_root/sec-actions-without-completion.md"
mv "$fixture_root/sec-actions-without-completion.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
output=""
if output="$(WORKFLOW_DOCS_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a workflow page without completion and gate behavior was accepted"
fi
grep -Fq 'Completion And Gating' <<< "$output" \
  || fail "the missing-section rejection did not name the required section"

cp "$repo_root/docs/workflows/sec-actions.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
# Backticks are literal Markdown delimiters in this fixture mutation.
# shellcheck disable=SC2016
sed 's/`config-path`/configuration path/' \
  "$fixture_root/docs/workflows/sec-actions.md" \
  > "$fixture_root/sec-actions-without-input.md"
mv "$fixture_root/sec-actions-without-input.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
output=""
if output="$(WORKFLOW_DOCS_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a workflow page missing a declared input was accepted"
fi
grep -Fq 'config-path' <<< "$output" \
  || fail "the missing-input rejection did not name the undocumented input"

cp "$repo_root/docs/workflows/sec-actions.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
sed '/## Compatibility/d' \
  "$fixture_root/docs/workflows/sec-actions.md" \
  > "$fixture_root/sec-actions-without-compatibility.md"
mv "$fixture_root/sec-actions-without-compatibility.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
output=""
if output="$(WORKFLOW_DOCS_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a workflow page without compatibility guidance was accepted"
fi
grep -Fq 'Compatibility' <<< "$output" \
  || fail "the missing-section rejection did not name compatibility"

printf 'reusable workflow documentation contract tests passed.\n'

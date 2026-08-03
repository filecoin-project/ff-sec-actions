#!/usr/bin/env bash
# Prove the reusable workflow documentation contract rejects drift.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="$repo_root/scripts/check-workflow-docs.sh"
extractor="$repo_root/scripts/extract-workflow-doc-examples.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/ff-sec-workflow-docs.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail() {
  printf 'workflow-documentation test failure: %s\n' "$*" >&2
  exit 1
}

bash "$checker" >/dev/null \
  || fail "the maintained workflow documentation catalog is invalid"

WORKFLOW_DOC_EXAMPLE_DIR="$fixture_root/examples" bash "$extractor" >/dev/null \
  || fail "runnable examples could not be extracted from the maintained pages"
example_count="$(find "$fixture_root/examples" -type f -name '*.yml' | wc -l | tr -d ' ')"
expected_example_count="$(
  grep -l '^[[:space:]]*workflow_call:' "$repo_root"/.github/workflows/*.yml \
    | wc -l \
    | tr -d ' '
)"
[ "$example_count" = "$expected_example_count" ] \
  || fail "expected $expected_example_count extracted workflow examples, found $example_count"

mkdir -p "$fixture_root/.github/workflows" "$fixture_root/docs/workflows"
cp -R "$repo_root/.github/workflows/." "$fixture_root/.github/workflows/"
cp -R "$repo_root/docs/workflows/." "$fixture_root/docs/workflows/"
export WORKFLOW_DOCS_GIT_ROOT="$repo_root"

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

cp "$repo_root/docs/workflows/sec-actions.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
# Backticks are literal Markdown delimiters in this fixture mutation.
# shellcheck disable=SC2016
sed 's/| `blocking` | `false` |/| `blocking` | `true` |/' \
  "$fixture_root/docs/workflows/sec-actions.md" \
  > "$fixture_root/sec-actions-with-wrong-default.md"
mv "$fixture_root/sec-actions-with-wrong-default.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
output=""
if output="$(WORKFLOW_DOCS_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a workflow page with an incorrect input default was accepted"
fi
grep -Fq 'blocking' <<< "$output" \
  || fail "the default-drift rejection did not name the affected input"

cp "$repo_root/docs/workflows/ai-code-review.md" \
  "$fixture_root/docs/workflows/ai-code-review.md"
sed 's/anthropic-api-key/provider-credential/g' \
  "$fixture_root/docs/workflows/ai-code-review.md" \
  > "$fixture_root/ai-code-review-without-secret.md"
mv "$fixture_root/ai-code-review-without-secret.md" \
  "$fixture_root/docs/workflows/ai-code-review.md"
output=""
if output="$(WORKFLOW_DOCS_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a workflow page missing a declared secret was accepted"
fi
grep -Fq 'anthropic-api-key' <<< "$output" \
  || fail "the missing-secret rejection did not name the undocumented secret"
cp "$repo_root/docs/workflows/ai-code-review.md" \
  "$fixture_root/docs/workflows/ai-code-review.md"

cp "$repo_root/docs/workflows/sec-actions.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
# Backticks are literal Markdown delimiters in this fixture mutation.
# shellcheck disable=SC2016
sed '/| `blocking` |/a\
| `invented-input` | `false` | This input does not exist |' \
  "$fixture_root/docs/workflows/sec-actions.md" \
  > "$fixture_root/sec-actions-with-invented-input.md"
mv "$fixture_root/sec-actions-with-invented-input.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
output=""
if output="$(WORKFLOW_DOCS_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a workflow page with an invented input was accepted"
fi
grep -Fq 'input table' <<< "$output" \
  || fail "the invented-input rejection did not explain the table mismatch"

cp "$repo_root/docs/workflows/sec-actions.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
# Backticks are literal Markdown delimiters in this fixture mutation.
# shellcheck disable=SC2016
sed 's/`contents: read`/`contents: write`/g' \
  "$fixture_root/docs/workflows/sec-actions.md" \
  > "$fixture_root/sec-actions-with-wrong-permission.md"
mv "$fixture_root/sec-actions-with-wrong-permission.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
output=""
if output="$(WORKFLOW_DOCS_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a workflow page with incorrect permissions was accepted"
fi
grep -Fq 'contents: read' <<< "$output" \
  || fail "the permission-drift rejection did not name the required permission"
cp "$repo_root/docs/workflows/sec-actions.md" \
  "$fixture_root/docs/workflows/sec-actions.md"

# Backticks are literal Markdown delimiters in this fixture mutation.
# shellcheck disable=SC2016
sed 's/| `contents: read` |/| `contents: read`, `contents: write` |/' \
  "$fixture_root/docs/workflows/sec-actions.md" \
  > "$fixture_root/sec-actions-with-extra-permission.md"
mv "$fixture_root/sec-actions-with-extra-permission.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
output=""
if output="$(WORKFLOW_DOCS_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a workflow page with an extra permission was accepted"
fi
grep -Fq 'exactly match' <<< "$output" \
  || fail "the extra-permission rejection did not explain the set mismatch"
cp "$repo_root/docs/workflows/sec-actions.md" \
  "$fixture_root/docs/workflows/sec-actions.md"

cp "$repo_root/docs/workflows/sec-dependency-review.md" \
  "$fixture_root/docs/workflows/sec-dependency-review.md"
sed '/^on:$/d' \
  "$fixture_root/docs/workflows/sec-dependency-review.md" \
  > "$fixture_root/dependency-review-without-event.md"
mv "$fixture_root/dependency-review-without-event.md" \
  "$fixture_root/docs/workflows/sec-dependency-review.md"
output=""
if output="$(WORKFLOW_DOCS_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a workflow page with a non-runnable usage fragment was accepted"
fi
grep -Fq 'on:' <<< "$output" \
  || fail "the incomplete-usage rejection did not name the missing event"
cp "$repo_root/docs/workflows/sec-dependency-review.md" \
  "$fixture_root/docs/workflows/sec-dependency-review.md"

cp "$repo_root/docs/workflows/sec-actions.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
sed 's/^\*\*Introduced:\*\*.*/**Introduced:** pre-v1/' \
  "$fixture_root/docs/workflows/sec-actions.md" \
  > "$fixture_root/sec-actions-without-introducing-commit.md"
mv "$fixture_root/sec-actions-without-introducing-commit.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
output=""
if output="$(WORKFLOW_DOCS_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a workflow page without an exact introducing commit was accepted"
fi
grep -Fq 'introducing commit' <<< "$output" \
  || fail "the lifecycle rejection did not explain the required commit metadata"

cp "$repo_root/docs/workflows/sec-actions.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
# Backticks are literal Markdown delimiters in this fixture mutation.
# shellcheck disable=SC2016
sed 's/^\*\*Introduced:\*\*.*/**Introduced:** commit `0000000000000000000000000000000000000000`<br>/' \
  "$fixture_root/docs/workflows/sec-actions.md" \
  > "$fixture_root/sec-actions-with-false-introducing-commit.md"
mv "$fixture_root/sec-actions-with-false-introducing-commit.md" \
  "$fixture_root/docs/workflows/sec-actions.md"
output=""
if output="$(WORKFLOW_DOCS_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a workflow page with a false introducing commit was accepted"
fi
grep -Fq 'first add commit' <<< "$output" \
  || fail "the false-commit rejection did not explain the historical mismatch"
cp "$repo_root/docs/workflows/sec-actions.md" \
  "$fixture_root/docs/workflows/sec-actions.md"

cp "$repo_root/docs/workflows/ai-code-review.md" \
  "$fixture_root/docs/workflows/ai-code-review.md"
# Backticks are literal Markdown delimiters in this fixture mutation.
# shellcheck disable=SC2016
sed 's/(optional)/(optional), `invented-secret`/' \
  "$fixture_root/docs/workflows/ai-code-review.md" \
  > "$fixture_root/ai-code-review-with-extra-secret.md"
mv "$fixture_root/ai-code-review-with-extra-secret.md" \
  "$fixture_root/docs/workflows/ai-code-review.md"
output=""
if output="$(WORKFLOW_DOCS_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a workflow page with an invented secret was accepted"
fi
grep -Fq 'secret declaration' <<< "$output" \
  || fail "the invented-secret rejection did not explain the set mismatch"
cp "$repo_root/docs/workflows/ai-code-review.md" \
  "$fixture_root/docs/workflows/ai-code-review.md"

# Backticks are literal Markdown delimiters in this fixture mutation.
# shellcheck disable=SC2016
sed 's/`evidence-artifact-url`$/`evidence-artifact-url`, `invented-output`/' \
  "$fixture_root/docs/workflows/ai-code-review.md" \
  > "$fixture_root/ai-code-review-with-extra-output.md"
mv "$fixture_root/ai-code-review-with-extra-output.md" \
  "$fixture_root/docs/workflows/ai-code-review.md"
output=""
if output="$(WORKFLOW_DOCS_ROOT="$fixture_root" bash "$checker" 2>&1)"; then
  fail "a workflow page with an invented output was accepted"
fi
grep -Fq 'output declaration' <<< "$output" \
  || fail "the invented-output rejection did not explain the set mismatch"

printf 'reusable workflow documentation contract tests passed.\n'

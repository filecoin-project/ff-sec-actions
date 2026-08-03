#!/usr/bin/env bash
# Extract each workflow page's complete Immutable Usage example for Actionlint.
# Required: WORKFLOW_DOC_EXAMPLE_DIR points to a disposable output directory.
set -euo pipefail

: "${WORKFLOW_DOC_EXAMPLE_DIR:?WORKFLOW_DOC_EXAMPLE_DIR is required}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
documentation_directory="$repo_root/docs/workflows"

fail() {
  printf 'workflow-example extraction error: %s\n' "$*" >&2
  exit 1
}

[ -d "$documentation_directory" ] \
  || fail "workflow documentation directory is missing"
mkdir -p "$WORKFLOW_DOC_EXAMPLE_DIR"

count=0
while IFS= read -r page; do
  output="$WORKFLOW_DOC_EXAMPLE_DIR/$(basename "$page" .md).yml"
  awk '
    /^## Immutable Usage[[:space:]]*$/ { in_usage = 1; next }
    in_usage && /^```yaml[[:space:]]*$/ { in_fence = 1; next }
    in_fence && /^```[[:space:]]*$/ { exit }
    in_fence { print }
  ' "$page" > "$output"

  [ -s "$output" ] \
    || fail "$(basename "$page") has no YAML Immutable Usage example"
  count=$((count + 1))
done < <(
  find "$documentation_directory" -maxdepth 1 -type f -name '*.md' \
    ! -name README.md \
    | sort
)

[ "$count" -gt 0 ] || fail "no workflow examples were extracted"
printf 'extracted %s reusable workflow examples.\n' "$count"

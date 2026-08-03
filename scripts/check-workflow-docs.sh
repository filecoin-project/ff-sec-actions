#!/usr/bin/env bash
# Require one reviewable contract page for every reusable workflow_call surface.
set -euo pipefail

repo_root="${WORKFLOW_DOCS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
workflow_directory="$repo_root/.github/workflows"
documentation_directory="$repo_root/docs/workflows"
index="$documentation_directory/README.md"

fail() {
  printf 'workflow-documentation error: %s\n' "$*" >&2
  exit 1
}

[ -d "$workflow_directory" ] || fail "workflow directory is missing"
[ -d "$documentation_directory" ] || fail "documentation directory is missing: docs/workflows"
[ -f "$index" ] || fail "workflow documentation index is missing"

reusable_workflows="$(
  while IFS= read -r workflow; do
    grep -q '^[[:space:]]*workflow_call:' "$workflow" \
      && printf '%s\n' "${workflow#"$repo_root/"}"
  done < <(find "$workflow_directory" -maxdepth 1 -type f -name '*.yml' | sort)
)"

expected_pages="$(
  while IFS= read -r workflow; do
    [ -n "$workflow" ] || continue
    base="$(basename "$workflow" .yml)"
    printf 'docs/workflows/%s.md\n' "$base"
  done <<< "$reusable_workflows"
)"

actual_pages="$(
  find "$documentation_directory" -maxdepth 1 -type f -name '*.md' \
    ! -name README.md \
    | sed "s#^$repo_root/##" \
    | sort
)"

[ "$actual_pages" = "$expected_pages" ] \
  || fail "catalog pages must map one-to-one with reusable workflow_call files"

workflow_inputs() {
  awk '
    /^    inputs:[[:space:]]*$/ { in_inputs = 1; next }
    in_inputs && (/^    (secrets|outputs):[[:space:]]*$/ || /^jobs:[[:space:]]*$/) {
      in_inputs = 0
    }
    in_inputs && /^      [A-Za-z0-9_-]+:[[:space:]]*$/ {
      name = $0
      sub(/^      /, "", name)
      sub(/:[[:space:]]*$/, "", name)
      print name
    }
  ' "$1"
}

workflow_outputs() {
  awk '
    /^    outputs:[[:space:]]*$/ { in_outputs = 1; next }
    in_outputs && (/^    [A-Za-z]+:[[:space:]]*$/ || /^jobs:[[:space:]]*$/) {
      in_outputs = 0
    }
    in_outputs && /^      [A-Za-z0-9_-]+:[[:space:]]*$/ {
      name = $0
      sub(/^      /, "", name)
      sub(/:[[:space:]]*$/, "", name)
      print name
    }
  ' "$1"
}

required_sections=(
  "**Workflow:**"
  "**Status:**"
  "**Introduced:**"
  "**Owner:**"
  "**Use when:**"
  "## Authority And Execution"
  "## Inputs"
  "## Outputs And Evidence"
  "## Completion And Gating"
  "## Immutable Usage"
  "## Limitations"
  "## Compatibility"
  "## Source"
)

while IFS= read -r workflow; do
  [ -n "$workflow" ] || continue
  base="$(basename "$workflow" .yml)"
  page="$repo_root/docs/workflows/$base.md"

  for section in "${required_sections[@]}"; do
    grep -Fq "$section" "$page" \
      || fail "docs/workflows/$base.md is missing required contract section: $section"
  done

  grep -Fq "(../../$workflow)" "$page" \
    || fail "docs/workflows/$base.md does not link to its workflow source"
  grep -Fq "($base.md)" "$index" \
    || fail "docs/workflows/README.md does not link to $base.md"

  while IFS= read -r input; do
    [ -n "$input" ] || continue
    grep -Fq "\`$input\`" "$page" \
      || fail "docs/workflows/$base.md does not document input: $input"
  done < <(workflow_inputs "$repo_root/$workflow")

  while IFS= read -r output; do
    [ -n "$output" ] || continue
    grep -Fq "\`$output\`" "$page" \
      || fail "docs/workflows/$base.md does not document output: $output"
  done < <(workflow_outputs "$repo_root/$workflow")
done <<< "$reusable_workflows"

printf 'reusable workflow documentation checks passed (%s pages).\n' \
  "$(wc -l <<< "$reusable_workflows" | tr -d ' ')"

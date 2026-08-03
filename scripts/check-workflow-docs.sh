#!/usr/bin/env bash
# Require one reviewable contract page for every reusable workflow_call surface.
set -euo pipefail

repo_root="${WORKFLOW_DOCS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
git_root="${WORKFLOW_DOCS_GIT_ROOT:-$repo_root}"
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

workflow_input_defaults() {
  awk '
    function emit_input() {
      if (input_name == "") {
        return
      }

      if (has_default) {
        normalized_default = input_default
        if ((substr(normalized_default, 1, 1) == "\"" && substr(normalized_default, length(normalized_default), 1) == "\"") ||
            (substr(normalized_default, 1, 1) == "\047" && substr(normalized_default, length(normalized_default), 1) == "\047")) {
          normalized_default = substr(normalized_default, 2, length(normalized_default) - 2)
        }
        if (normalized_default == "") {
          normalized_default = "Empty"
        }
      } else {
        normalized_default = "Required"
      }

      print input_name "\t" normalized_default
      input_name = ""
      input_default = ""
      has_default = 0
    }

    /^    inputs:[[:space:]]*$/ { in_inputs = 1; next }
    in_inputs && (/^    (secrets|outputs):[[:space:]]*$/ || /^jobs:[[:space:]]*$/) {
      emit_input()
      in_inputs = 0
    }
    in_inputs && /^      [A-Za-z0-9_-]+:[[:space:]]*$/ {
      emit_input()
      input_name = $0
      sub(/^      /, "", input_name)
      sub(/:[[:space:]]*$/, "", input_name)
      next
    }
    in_inputs && /^        default:[[:space:]]*/ {
      input_default = $0
      sub(/^        default:[[:space:]]*/, "", input_default)
      has_default = 1
    }

    END { emit_input() }
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

workflow_secrets() {
  awk '
    /^    secrets:[[:space:]]*$/ { in_secrets = 1; next }
    in_secrets && (/^    (inputs|outputs):[[:space:]]*$/ || /^jobs:[[:space:]]*$/) {
      in_secrets = 0
    }
    in_secrets && /^      [A-Za-z0-9_-]+:[[:space:]]*$/ {
      name = $0
      sub(/^      /, "", name)
      sub(/:[[:space:]]*$/, "", name)
      print name
    }
  ' "$1"
}

documented_inputs() {
  awk '
    /^## Inputs[[:space:]]*$/ { in_inputs = 1; next }
    in_inputs && /^## / { exit }
    in_inputs && /^\| `[A-Za-z0-9_-]+` \|/ {
      name = $0
      sub(/^\| `/, "", name)
      sub(/`.*/, "", name)
      print name
    }
  ' "$1"
}

documented_permissions() {
  awk '
    /^## Authority And Execution[[:space:]]*$/ { in_authority = 1; next }
    in_authority && /^## / { exit }
    in_authority {
      line = $0
      while (match(line, /`[a-z-]+: (read|write|none)`/)) {
        permission = substr(line, RSTART + 1, RLENGTH - 2)
        print permission
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' "$1" | sort -u
}

documented_secrets() {
  awk '
    /^\*\*Declared secrets:\*\*/ {
      line = $0
      while (match(line, /`[A-Za-z0-9_-]+`/)) {
        secret = substr(line, RSTART + 1, RLENGTH - 2)
        print secret
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' "$1" | sort -u
}

documented_outputs() {
  awk '
    /^\*\*Declared workflow outputs:\*\*/ {
      line = $0
      while (match(line, /`[A-Za-z0-9_-]+`/)) {
        output = substr(line, RSTART + 1, RLENGTH - 2)
        print output
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' "$1" | sort -u
}

workflow_permissions() {
  awk '
    /^    permissions:[[:space:]]*$/ { in_permissions = 1; next }
    in_permissions && /^      [a-z-]+:[[:space:]]+(read|write|none)[[:space:]]*$/ {
      permission = $0
      sub(/^      /, "", permission)
      print permission
      next
    }
    in_permissions && !/^      / { in_permissions = 0 }
  ' "$1" | sort -u
}

required_sections=(
  "**Workflow:**"
  "**Status:**"
  "**Introduced:**"
  "**Owner:**"
  "**Use when:**"
  "## Authority And Execution"
  "## Inputs"
  "**Declared secrets:**"
  "## Outputs And Evidence"
  "**Declared workflow outputs:**"
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

  # Backticks are literal Markdown delimiters in the required metadata line.
  # shellcheck disable=SC2016
  grep -Eq '^\*\*Introduced:\*\* commit `[0-9a-f]{40}`<br>$' "$page" \
    || fail "docs/workflows/$base.md must name the exact introducing commit"
  documented_introduced="$(
    # Backticks are literal Markdown delimiters in the metadata line.
    # shellcheck disable=SC2016
    sed -n 's/^\*\*Introduced:\*\* commit `\([0-9a-f]\{40\}\)`<br>$/\1/p' "$page"
  )"
  expected_introduced="$(
    git -C "$git_root" log --follow --format=%H -- "$workflow" | tail -n 1
  )"
  [ -n "$expected_introduced" ] \
    || fail "$workflow has no introducing commit in $git_root"
  [ "$documented_introduced" = "$expected_introduced" ] \
    || fail "docs/workflows/$base.md introducing commit must be the workflow's first add commit: $expected_introduced"

  immutable_usage="$(
    awk '
      /^## Immutable Usage[[:space:]]*$/ { in_usage = 1; next }
      in_usage && /^## / { exit }
      in_usage { print }
    ' "$page"
  )"
  for usage_key in name on jobs; do
    grep -Eq "^${usage_key}:" <<< "$immutable_usage" \
      || fail "docs/workflows/$base.md Immutable Usage is missing runnable workflow key: ${usage_key}:"
  done

  grep -Fq "(../../$workflow)" "$page" \
    || fail "docs/workflows/$base.md does not link to its workflow source"
  grep -Fq "($base.md)" "$index" \
    || fail "docs/workflows/README.md does not link to $base.md"

  expected_input_names="$(
    workflow_input_defaults "$repo_root/$workflow" | cut -f1 | sort
  )"
  documented_input_names="$(documented_inputs "$page" | sort)"
  [ "$documented_input_names" = "$expected_input_names" ] \
    || fail "docs/workflows/$base.md input table does not exactly match workflow_call inputs; expected [$expected_input_names], documented [$documented_input_names]"

  while IFS=$'\t' read -r input input_default; do
    [ -n "$input" ] || continue
    if [ "$input_default" = "Empty" ] || [ "$input_default" = "Required" ]; then
      documented_row="| \`$input\` | $input_default |"
    else
      documented_row="| \`$input\` | \`$input_default\` |"
    fi
    grep -Fq "$documented_row" "$page" \
      || fail "docs/workflows/$base.md does not document input/default: $input ($input_default)"
  done < <(workflow_input_defaults "$repo_root/$workflow")

  expected_secrets="$(workflow_secrets "$repo_root/$workflow" | sort)"
  page_secrets="$(documented_secrets "$page")"
  [ "$page_secrets" = "$expected_secrets" ] \
    || fail "docs/workflows/$base.md secret declaration must exactly match workflow_call secrets; expected [$expected_secrets], documented [$page_secrets]"

  expected_permissions="$(workflow_permissions "$repo_root/$workflow")"
  page_permissions="$(documented_permissions "$page")"
  [ "$page_permissions" = "$expected_permissions" ] \
    || fail "docs/workflows/$base.md Authority permissions must exactly match workflow jobs; expected [$expected_permissions], documented [$page_permissions]"

  expected_outputs="$(workflow_outputs "$repo_root/$workflow" | sort)"
  page_outputs="$(documented_outputs "$page")"
  [ "$page_outputs" = "$expected_outputs" ] \
    || fail "docs/workflows/$base.md output declaration must exactly match workflow_call outputs; expected [$expected_outputs], documented [$page_outputs]"
done <<< "$reusable_workflows"

printf 'reusable workflow documentation checks passed (%s pages).\n' \
  "$(wc -l <<< "$reusable_workflows" | tr -d ' ')"

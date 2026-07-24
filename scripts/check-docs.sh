#!/usr/bin/env bash
# check-docs: validate the repository's documentation navigation contract.
# Safe to run locally and in CI; reads repository files and makes no writes.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

failures=0

report_error() {
  printf 'documentation error: %s\n' "$*" >&2
  failures=$((failures + 1))
}

require_file() {
  local path="$1"
  [ -f "$path" ] || report_error "required page is missing: $path"
}

require_text() {
  local path="$1"
  local expected="$2"
  grep -Fq "$expected" "$path" \
    || report_error "$path does not contain required navigation target: $expected"
}

required_pages=(
  "README.md"
  ".github/workflows/docs.yml"
  "docs/README.md"
  "docs/consumers/quickstart.md"
  "docs/consumers/choose-a-profile.md"
  "docs/consumers/understand-results.md"
  "docs/consumers/permissions-and-secrets.md"
  "docs/consumers/troubleshooting.md"
  "docs/maintainers/README.md"
  "docs/operators/README.md"
  "docs/reference/README.md"
  "docs/reference/current-contracts.md"
  "docs/DOCUMENTATION-ARCHITECTURE.md"
  "docs/ECOSYSTEM-SECURITY-DECISION-MAP.md"
)

for path in "${required_pages[@]}"; do
  require_file "$path"
done

if [ -f "README.md" ]; then
  require_text "README.md" "(docs/consumers/quickstart.md)"
  require_text "README.md" "(docs/maintainers/README.md)"
  require_text "README.md" "(docs/operators/README.md)"
  require_text "README.md" "(docs/README.md)"
fi

if [ -f ".github/workflows/docs.yml" ]; then
  require_text ".github/workflows/docs.yml" "bash scripts/check-docs.sh"
  require_text ".github/workflows/docs.yml" "github.com/rhysd/actionlint/cmd/actionlint@914e7df21a07ef503a81201c76d2b11c789d3fca"
  require_text ".github/workflows/docs.yml" "contents: read"
  require_text ".github/workflows/docs.yml" "persist-credentials: false"
fi

if grep -REq '^[[:space:]-]*uses:.*@v1([[:space:]]|$)' examples; then
  report_error "consumer examples reference @v1, but the repository is explicitly pre-v1"
fi

if grep -REq '^[[:space:]-]*uses:.*ai-code-review@main([[:space:]]|$)' examples; then
  report_error "AI consumer examples must use a reviewed immutable pilot commit"
fi

if grep -Eq '^[[:space:]]+package-manager:[[:space:]]+(npm|pnpm)' examples/consumer-security-pipeline.yml; then
  report_error "the baseline security example must not execute package-manager install hooks"
fi

if grep -Eq '^[[:space:]]+id-token:[[:space:]]+write' examples/consumer-security-pipeline.yml; then
  report_error "the baseline security example must not grant OIDC authority"
fi

if [ -f "docs/README.md" ]; then
  while IFS= read -r page; do
    [ "$page" = "docs/README.md" ] && continue
    relative_path="${page#docs/}"
    require_text "docs/README.md" "(${relative_path})"
  done < <(find docs -type f -name '*.md' | sort)
fi

while IFS= read -r task_page; do
  require_text "$task_page" "**For:**"
  require_text "$task_page" "**Outcome:**"
  require_text "$task_page" "## Next"
done < <(find docs/consumers -type f -name '*.md' | sort)

while IFS= read -r document; do
  document_dir="$(dirname "$document")"

  while IFS= read -r target; do
    case "$target" in
      ""|\#*|http://*|https://*|mailto:*|app://*) continue ;;
    esac

    target="${target#<}"
    target="${target%>}"
    target="${target%%#*}"
    target="${target%%\?*}"
    [ -n "$target" ] || continue

    if [[ "$target" = /* ]]; then
      resolved=".$target"
    else
      resolved="$document_dir/$target"
    fi

    [ -e "$resolved" ] \
      || report_error "$document links to missing local target: $target"
  done < <(
    grep -Eo '\[[^]]+\]\([^)]+\)' "$document" 2>/dev/null \
      | sed -E 's/^.*\(([^)]+)\)$/\1/' \
      || true
  )
done < <(find . -type f -name '*.md' -not -path './.git/*' -not -path './scripts/dev/fixtures/*' | sort)

if [ "$failures" -gt 0 ]; then
  printf 'documentation checks failed with %s error(s).\n' "$failures" >&2
  exit 1
fi

printf 'documentation checks passed.\n'

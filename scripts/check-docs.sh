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
  "actions/scanner-outcome/action.yml"
  "actions/scanner-outcome/scanner-outcome.sh"
  "actions/semgrep-scan/action.yml"
  "actions/semgrep-scan/semgrep-scan.sh"
  "actions/gitleaks-scan/action.yml"
  "actions/gitleaks-scan/gitleaks-scan.sh"
  "actions/evaluation-adapter/action.yml"
  "actions/evaluation-adapter/evaluation-adapter.sh"
  "actions/aggregate-results/action.yml"
  "actions/aggregate-results/aggregate-results.sh"
  ".github/workflows/docs.yml"
  ".github/workflows/evaluation-pipeline.yml"
  ".github/workflows/ecosystem-baseline.yml"
  ".github/workflows/g0-contract.yml"
  ".github/workflows/sec-actions.yml"
  "docs/README.md"
  "docs/consumers/quickstart.md"
  "docs/consumers/ecosystem-baseline.md"
  "docs/consumers/choose-a-profile.md"
  "docs/consumers/understand-results.md"
  "docs/consumers/permissions-and-secrets.md"
  "docs/consumers/troubleshooting.md"
  "docs/maintainers/README.md"
  "docs/maintainers/g0-gate.md"
  "docs/operators/README.md"
  "docs/reference/README.md"
  "docs/reference/current-contracts.md"
  "docs/reference/execution-trust.md"
  "docs/reference/evaluation-result.md"
  "docs/reference/evaluation-adapter.md"
  "docs/reference/evidence-bundle.md"
  "docs/reference/ecosystem-baseline-rules.md"
  "docs/reference/release-integrity.md"
  "docs/reference/fork-pr-safety.md"
  "docs/DOCUMENTATION-ARCHITECTURE.md"
  "docs/ECOSYSTEM-SECURITY-DECISION-MAP.md"
  "docs/decisions/distribution-model.md"
  "roadmap/README.md"
  "roadmap/state.json"
  "schemas/evaluation-result.schema.json"
  "schemas/evidence-bundle.schema.json"
  "security/execution-trust.json"
  "security/baseline-policy.json"
  "security/scanner-gates.json"
  "security/release-graph.json"
  "rules/ecosystem-baseline.yml"
  "security/workflow-policy.json"
  "scripts/check-baseline-no-exec.sh"
  "scripts/check-scanner-gates.sh"
  "scripts/check-execution-trust.sh"
  "scripts/check-evaluation-result.sh"
  "scripts/check-release-graph.sh"
  "scripts/check-fork-pr.sh"
  "scripts/check-workflow-security.sh"
  "scripts/roadmap.sh"
  "scripts/test-roadmap.sh"
  "scripts/test-baseline-no-exec.sh"
  "scripts/test-evaluation-result.sh"
  "scripts/test-evaluation-adapter.sh"
  "scripts/test-aggregate-results.sh"
  "scripts/test-ecosystem-baseline.sh"
  "scripts/test-gitleaks-scan.sh"
  "scripts/test-consumer-actions-security.sh"
  "scripts/test-release-graph.sh"
  "scripts/test-fork-pr.sh"
  "scripts/test-scanner-outcome.sh"
  "scripts/test-workflow-security.sh"
  "test/fixtures/evaluation-result/valid/complete.json"
  "test/fixtures/evaluation-result/invalid/unknown-field.json"
  "threat-model/execution-trust/threat-model-report.md"
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
  require_text ".github/workflows/docs.yml" "bash scripts/check-workflow-security.sh"
  require_text ".github/workflows/docs.yml" "bash scripts/test-workflow-security.sh"
  require_text ".github/workflows/docs.yml" "bash scripts/check-baseline-no-exec.sh"
  require_text ".github/workflows/docs.yml" "bash scripts/test-baseline-no-exec.sh"
  require_text ".github/workflows/docs.yml" "bash scripts/check-scanner-gates.sh"
  require_text ".github/workflows/docs.yml" "bash scripts/test-scanner-outcome.sh"
  require_text ".github/workflows/docs.yml" "bash scripts/test-evaluation-result.sh"
  require_text ".github/workflows/docs.yml" "bash scripts/test-evaluation-adapter.sh"
  require_text ".github/workflows/docs.yml" "bash scripts/test-aggregate-results.sh"
  require_text ".github/workflows/docs.yml" "bash scripts/test-ecosystem-baseline.sh"
  require_text ".github/workflows/docs.yml" "bash scripts/test-gitleaks-scan.sh"
  require_text ".github/workflows/docs.yml" "bash scripts/test-consumer-actions-security.sh"
  require_text ".github/workflows/docs.yml" "bash scripts/check-release-graph.sh"
  require_text ".github/workflows/docs.yml" "bash scripts/test-release-graph.sh"
  require_text ".github/workflows/docs.yml" "bash scripts/check-fork-pr.sh"
  require_text ".github/workflows/docs.yml" "bash scripts/test-fork-pr.sh"
  require_text ".github/workflows/docs.yml" "github.com/rhysd/actionlint/cmd/actionlint@914e7df21a07ef503a81201c76d2b11c789d3fca"
  require_text ".github/workflows/docs.yml" "contents: read"
  require_text ".github/workflows/docs.yml" "persist-credentials: false"
fi

if [ -f ".github/workflows/g0-contract.yml" ]; then
  require_text ".github/workflows/g0-contract.yml" "bash scripts/check-workflow-security.sh"
  require_text ".github/workflows/g0-contract.yml" "bash scripts/test-workflow-security.sh"
  require_text ".github/workflows/g0-contract.yml" "bash scripts/check-baseline-no-exec.sh"
  require_text ".github/workflows/g0-contract.yml" "bash scripts/test-baseline-no-exec.sh"
  require_text ".github/workflows/g0-contract.yml" "bash scripts/check-scanner-gates.sh"
  require_text ".github/workflows/g0-contract.yml" "bash scripts/test-scanner-outcome.sh"
  require_text ".github/workflows/g0-contract.yml" "bash scripts/test-evaluation-result.sh"
  require_text ".github/workflows/g0-contract.yml" "bash scripts/test-evaluation-adapter.sh"
  require_text ".github/workflows/g0-contract.yml" "bash scripts/test-aggregate-results.sh"
  require_text ".github/workflows/g0-contract.yml" "bash scripts/test-gitleaks-scan.sh"
  require_text ".github/workflows/g0-contract.yml" "bash scripts/test-consumer-actions-security.sh"
  require_text ".github/workflows/g0-contract.yml" "bash scripts/check-release-graph.sh"
  require_text ".github/workflows/g0-contract.yml" "bash scripts/test-release-graph.sh"
  require_text ".github/workflows/g0-contract.yml" "bash scripts/check-fork-pr.sh"
  require_text ".github/workflows/g0-contract.yml" "bash scripts/test-fork-pr.sh"
  require_text ".github/workflows/g0-contract.yml" "bash scripts/test-ecosystem-baseline.sh"
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

if [ -f "roadmap/state.json" ] && [ -f "scripts/roadmap.sh" ]; then
  bash scripts/roadmap.sh validate \
    || report_error "machine-readable roadmap state is invalid"
fi

if [ -f "security/execution-trust.json" ] && [ -f "scripts/check-execution-trust.sh" ]; then
  bash scripts/check-execution-trust.sh \
    || report_error "execution-trust classification is invalid or stale"
fi

if [ -f "security/workflow-policy.json" ] && [ -f "scripts/check-workflow-security.sh" ]; then
  bash scripts/check-workflow-security.sh \
    || report_error "workflow authority or checkout policy is invalid or stale"
fi

if [ -f "security/baseline-policy.json" ] && [ -f "scripts/check-baseline-no-exec.sh" ]; then
  bash scripts/check-baseline-no-exec.sh \
    || report_error "baseline no-execution policy is invalid or stale"
fi

if [ -f "security/scanner-gates.json" ] && [ -f "scripts/check-scanner-gates.sh" ]; then
  bash scripts/check-scanner-gates.sh \
    || report_error "scanner gate policy is invalid or stale"
fi

if [ "$failures" -gt 0 ]; then
  printf 'documentation checks failed with %s error(s).\n' "$failures" >&2
  exit 1
fi

printf 'documentation checks passed.\n'

#!/usr/bin/env bash
# Validate profile composition and optionally execute cross-language Semgrep fixtures.
# Required environment: none.
# Optional environment:
#   BASELINE_RUN_DETECTION=true enables planted-fixture result validation.
#   BASELINE_RESULT_FILE points to an existing Semgrep JSON result; when empty,
#   the script runs an installed semgrep executable itself.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$repo_root/.github/workflows/ecosystem-baseline.yml"
actions_workflow="$repo_root/.github/workflows/sec-actions.yml"
dependencies_workflow="$repo_root/.github/workflows/sec-dependencies.yml"
privileged_pipeline="$repo_root/.github/workflows/security-pipeline.yml"
consumer_example="$repo_root/examples/consumer-ecosystem-baseline.yml"
rules="$repo_root/rules/ecosystem-baseline.yml"
fixture="$repo_root/test/fixtures/ecosystem-baseline/monorepo"

fail() { printf 'ecosystem-baseline test failure: %s\n' "$*" >&2; exit 1; }

expected_workflows=(sec-actions sec-dependencies sec-iac sec-secrets sec-semgrep)
for expected in "${expected_workflows[@]}"; do
  grep -Eq "uses: filecoin-project/ff-sec-actions/.github/workflows/${expected}\\.yml@[0-9a-f]{40}" "$workflow" \
    || fail "profile does not immutably compose $expected"
done

expected_evaluations=(zizmor-actions trivy-dependencies gitleaks trivy-iac semgrep-baseline)
for expected in "${expected_evaluations[@]}"; do
  grep -Fq "\"$expected\"" "$workflow" \
    || fail "Profile Conclusion does not require $expected"
done

grep -Eq 'uses: filecoin-project/ff-sec-actions/actions/zizmor-scan@[0-9a-f]{40}' "$actions_workflow" \
  || fail "workflow-definition evaluation does not use the immutable permission-free adapter"
grep -Fq "tool-outcome: \${{ steps.scan.outputs.scanner-outcome || 'failure' }}" "$actions_workflow" \
  || fail "workflow-definition evaluation does not forward scanner outcome with a fail-closed fallback"
grep -Eq '^[[:space:]]+blocking:[[:space:]]*$' "$actions_workflow" \
  || fail "workflow-definition findings do not expose an advisory-to-blocking input"
grep -Fq "blocking: \${{ inputs.blocking }}" "$actions_workflow" \
  || fail "workflow-definition findings do not honor the consumer-selected gate"
if grep -Eq 'advanced-security:[[:space:]]+true|zizmorcore/zizmor-action@' "$actions_workflow"; then
  fail "workflow-definition evaluation still couples SARIF creation to privileged upload"
fi
grep -Fq "blocking: \${{ inputs.actions-security-blocking }}" "$workflow" \
  || fail "the Ecosystem Baseline does not forward its workflow-definition gate"
grep -Fq "blocking: \${{ inputs.actions-security-blocking }}" "$privileged_pipeline" \
  || fail "the privileged pipeline does not forward its workflow-definition gate"
grep -Fq "blocking: \${{ inputs.secrets-blocking }}" "$workflow" \
  || fail "the Ecosystem Baseline does not forward its secret finding gate"
grep -Fq "blocking: \${{ inputs.secrets-blocking }}" "$privileged_pipeline" \
  || fail "the privileged pipeline does not forward its secret finding gate"

if grep -Eq 'security-events:[[:space:]]+write|publish-sarif:' "$dependencies_workflow"; then
  fail "dependency evaluation still mixes read-only inspection with SARIF publication"
fi
grep -Eq '^  publish-dependency-sarif:[[:space:]]*$' "$privileged_pipeline" \
  || fail "dependency SARIF publication is not isolated in the privileged pipeline"
grep -Fq "if: always() && inputs.enable-dependencies && inputs.publish-sarif" "$privileged_pipeline" \
  || fail "privileged dependency publication does not honor explicit consumer policy"
grep -Fq "needs: dependencies" "$privileged_pipeline" \
  || fail "privileged dependency publication is not ordered after inspection"
if grep -Eq 'security-events:[[:space:]]+write|publish-sarif:' "$workflow" "$consumer_example"; then
  fail "the Ecosystem Baseline requests privileged SARIF publication"
fi

expected_rules=(
  filecoin.javascript.shell-command-construction
  filecoin.go.insecure-tls-verification
  filecoin.rust.shell-command-construction
  filecoin.solidity.tx-origin-authorization
  filecoin.docker.remote-script-execution
)
for expected in "${expected_rules[@]}"; do
  grep -Fq "id: $expected" "$rules" || fail "ruleset is missing $expected"
  grep -R -Fq "ruleid: $expected" "$fixture" || fail "fixture is missing $expected"
done

# Each finding gate is an independent consumer input that defaults to advisory,
# completeness defaults to required, and the profile conclusion always runs.
for gate in actions-security dependency secrets iac static-analysis; do
  sed -n "/^      ${gate}-blocking:/,/default:/p" "$workflow" | grep -Eq 'default:[[:space:]]+false' \
    || fail "${gate}-blocking is not an advisory-by-default input"
  grep -Fq "blocking: \${{ inputs.${gate}-blocking }}" "$workflow" \
    || fail "${gate}-blocking is not wired to its evaluation"
done
sed -n '/^      require-complete:/,/default:/p' "$workflow" | grep -Eq 'default:[[:space:]]+true' \
  || fail "require-complete does not default to true"
sed -n '/^  profile-conclusion:/,/^    steps:/p' "$workflow" | grep -Fq 'if: always()' \
  || fail "Profile Conclusion does not run when an evaluation job fails"

# Static analysis never reads Consumer Project Semgrep configuration: the scan
# always passes an explicit repository-owned rules file and the baseline
# workflow never forwards a consumer-supplied config.
semgrep_script="$repo_root/actions/semgrep-scan/semgrep-scan.sh"
# shellcheck disable=SC2016 # match the literal variable reference in the script
grep -Fq -- '--config "$SEMGREP_CONFIG"' "$semgrep_script" \
  || fail "semgrep-scan does not pass an explicit rules file"
grep -Fq 'rules/ecosystem-baseline.yml' "$semgrep_script" \
  || fail "semgrep-scan does not default to the versioned baseline rules"
if sed -n '/actions\/semgrep-scan@/,/^      - /p' "$repo_root/.github/workflows/sec-semgrep.yml" | grep -Eq '^[[:space:]]+config:'; then
  fail "the baseline Semgrep workflow forwards a rules config"
fi

if [ "${BASELINE_RUN_DETECTION:-false}" = true ]; then
  result="${BASELINE_RESULT_FILE:-}"
  if [ -z "$result" ]; then
    command -v semgrep >/dev/null 2>&1 || fail "Semgrep is required when BASELINE_RESULT_FILE is not provided"
    detection_root="$(mktemp -d "${TMPDIR:-/tmp}/ff-sec-baseline-detection.XXXXXX")"
    result="$detection_root/result.json"
    trap 'rm -rf "$detection_root"' EXIT
    mkdir -p "$detection_root/rules" "$detection_root/fixture"
    cp "$rules" "$detection_root/rules/ecosystem-baseline.yml"
    cp -R "$fixture/." "$detection_root/fixture/"
    semgrep scan --metrics=off --disable-version-check \
      --config "$detection_root/rules/ecosystem-baseline.yml" \
      --json --output "$result" "$detection_root/fixture"
    # A planted consumer .semgrep.yml must not add or replace rules.
    cat > "$detection_root/fixture/.semgrep.yml" <<'YAML'
rules:
  - id: consumer-planted-rule
    pattern: tx.origin
    message: consumer-planted rule
    languages: [solidity]
    severity: ERROR
YAML
    consumer_result="$detection_root/consumer.json"
    (cd "$detection_root/fixture" && semgrep scan --metrics=off --disable-version-check \
      --config "$detection_root/rules/ecosystem-baseline.yml" \
      --json --output "$consumer_result" .)
    if jq -e 'any(.results[]; .check_id | endswith("consumer-planted-rule"))' "$consumer_result" >/dev/null; then
      fail "a consumer .semgrep.yml rule ran inside the baseline"
    fi
  fi
  [ -s "$result" ] || fail "Semgrep detection result is missing or empty: $result"
  for expected in "${expected_rules[@]}"; do
    jq -e --arg id "$expected" 'any(.results[]; .check_id | endswith($id))' "$result" >/dev/null \
      || fail "Semgrep did not detect planted fixture: $expected"
  done
fi

printf 'Ecosystem Baseline composition%s checks passed.\n' "$([ "${BASELINE_RUN_DETECTION:-false}" = true ] && printf ' and detection' || true)"

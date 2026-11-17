#!/usr/bin/env bash
# check-scanner-gates: verify scanner gate inputs and umbrella forwarding.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
policy="$repo_root/security/scanner-gates.json"
cd "$repo_root"

fail() {
  printf 'scanner-gates error: %s\n' "$*" >&2
  exit 1
}

[ -f "$policy" ] || fail "policy is missing: security/scanner-gates.json"

jq -e '
  .schema_version == 1
  and (.umbrella | type == "string" and length > 0)
  and (.scanners | type == "object" and length > 0)
  and all(.scanners[];
    (.workflow | type == "string" and length > 0)
    and (.gate_mode | IN("configurable", "always-blocking", "advisory", "provider-policy"))
    and if .gate_mode == "configurable" then
      (.workflow_input | type == "string" and length > 0)
      and (.umbrella_input | type == "string" and length > 0)
      and (.enforcement_marker | type == "string" and length > 0)
    else
      (.note | type == "string" and length > 0)
    end)
' "$policy" >/dev/null || fail "policy does not match schema version 1"

umbrella="$(jq -r '.umbrella' "$policy")"
[ -f "$umbrella" ] || fail "umbrella workflow is missing: $umbrella"

while IFS=$'\t' read -r scanner workflow workflow_input umbrella_input marker; do
  [ -f "$workflow" ] || fail "$scanner workflow is missing: $workflow"
  grep -Fq "      ${workflow_input}:" "$workflow" \
    || fail "$scanner workflow does not expose $workflow_input: $workflow"
  grep -Fq "      ${umbrella_input}:" "$umbrella" \
    || fail "umbrella does not expose $umbrella_input for $scanner"
  grep -Fq "${workflow_input}: \${{ inputs.${umbrella_input} }}" "$umbrella" \
    || fail "umbrella does not forward $umbrella_input to $scanner"
  grep -Fq "$marker" "$workflow" \
    || fail "$scanner workflow does not enforce its declared gate: $scanner"
done < <(jq -r '
  .scanners | to_entries[]
  | select(.value.gate_mode == "configurable")
  | [.key, .value.workflow, .value.workflow_input, .value.umbrella_input, .value.enforcement_marker]
  | @tsv
' "$policy")

# An advisory evaluation that names its evaluation id must be wired with a
# literal blocking: false in the adapter step that emits it, so no consumer
# input can turn it into a blocking gate.
while IFS=$'\t' read -r scanner workflow evaluation_id; do
  [ -f "$workflow" ] || fail "$scanner workflow is missing: $workflow"
  step="$(awk -v id="evaluation-id: $evaluation_id" '
    /^      - / { if (found) exit; block = "" }
    { block = block $0 "\n" }
    index($0, id) { found = 1 }
    END { if (found) printf "%s", block }
  ' "$workflow")"
  [ -n "$step" ] || fail "$scanner advisory evaluation $evaluation_id is not emitted by $workflow"
  grep -Eq '^[[:space:]]+blocking:[[:space:]]*false[[:space:]]*$' <<< "$step" \
    || fail "$scanner advisory evaluation $evaluation_id is not wired with blocking: false"
  if grep -Fq 'inputs.' <<< "$(grep -E '^[[:space:]]+blocking:' <<< "$step")"; then
    fail "$scanner advisory evaluation $evaluation_id reads its gate from an input"
  fi
done < <(jq -r '
  .scanners | to_entries[]
  | select(.value.gate_mode == "advisory" and (.value.evaluation_id // "") != "")
  | [.key, .value.workflow, .value.evaluation_id]
  | @tsv
' "$policy")

if grep -Eq 'continue-on-error:[[:space:]]+true([[:space:]#]|$)' \
  .github/workflows/sec-codeql.yml \
  .github/workflows/sec-dependency-review.yml \
  .github/workflows/sec-scorecard.yml \
  .github/workflows/sec-secrets.yml \
  .github/workflows/sec-slither.yml; then
  fail "a scanner without outcome normalization masks operational failure"
fi

printf 'scanner gate checks passed.\n'

#!/usr/bin/env bash
# check-output-contract: enforce consumable output interfaces for released evaluations.
# Required environment: none.
# Optional environment:
#   OUTPUT_CONTRACT_ROOT overrides the repository root for fixtures.
#   OUTPUT_CONTRACT_MANIFEST overrides the output-contract manifest path.
set -euo pipefail

repo_root="${OUTPUT_CONTRACT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
manifest="${OUTPUT_CONTRACT_MANIFEST:-$repo_root/security/output-contract.json}"

fail() { printf 'output-contract error: %s\n' "$*" >&2; exit 1; }
[ -f "$manifest" ] || fail "manifest is missing: $manifest"

jq -e '
  .schema_version == 1
  and (.contract.requirement | type == "string" and length > 0)
  and (.contract.normalized_surfaces | type == "array" and length > 0)
  and (.workflows | type == "object" and length > 0 and all(.[];
    (.mode | IN("normalized-evaluation", "provider-native", "profile-aggregate", "evaluation-collection"))
    and (.consumer_surface | type == "string" and length > 0)
    and (.remediation_surface | type == "string" and length > 0)
    and (if .mode == "normalized-evaluation"
      then (.lifecycle_test | type == "string" and length > 0)
        and (.failure_capture | IN("scanner-output", "continue-on-error"))
      else true end)))
  and (.actions | type == "object" and length > 0 and all(.[];
    (.mode | IN("consumer-evaluation", "scanner-invocation", "profile-aggregate", "profile-detection", "legacy-compatibility"))
    and (.required_outputs | type == "array" and length > 0)
    and (.consumer_surface | type == "string" and length > 0)
    and (.remediation_surface | type == "string" and length > 0)
    and (if .mode == "scanner-invocation"
      then (.consumer_workflow | type == "string" and length > 0)
      else true end)))
' "$manifest" >/dev/null || fail "manifest does not match schema version 1"

actual_workflows="$(while IFS= read -r path; do
  grep -q 'workflow_call:' "$path" && printf '%s\n' "${path#"$repo_root/"}"
done < <(find "$repo_root/.github/workflows" -maxdepth 1 -type f \
  \( -name '*.yml' -o -name '*.yaml' \) | sort))"
declared_workflows="$(jq -r '.workflows | keys[]' "$manifest" | sort)"
[ "$actual_workflows" = "$declared_workflows" ] \
  || fail "every reusable workflow must declare a consumable output interface"

while IFS= read -r workflow; do
  [ -n "$workflow" ] || continue
  path="$repo_root/$workflow"
  mode="$(jq -r --arg workflow "$workflow" '.workflows[$workflow].mode' "$manifest")"
  if [ "$mode" = normalized-evaluation ]; then
    evaluation_id="$(jq -r --arg workflow "$workflow" '.workflows[$workflow].evaluation_id' "$manifest")"
    raw_artifact="$(jq -r --arg workflow "$workflow" '.workflows[$workflow].raw_artifact' "$manifest")"
    normalized_artifact="$(jq -r --arg workflow "$workflow" '.workflows[$workflow].normalized_artifact' "$manifest")"
    lifecycle_test="$(jq -r --arg workflow "$workflow" '.workflows[$workflow].lifecycle_test' "$manifest")"
    failure_capture="$(jq -r --arg workflow "$workflow" '.workflows[$workflow].failure_capture' "$manifest")"
    grep -Fq 'filecoin-project/ff-sec-actions/actions/evaluation-adapter@' "$path" \
      || fail "$workflow does not use the shared consumable Evaluation Adapter"
    grep -Fq "evaluation-id: $evaluation_id" "$path" \
      || fail "$workflow does not expose its stable evaluation id: $evaluation_id"
    grep -Fq "evidence-artifact: $raw_artifact" "$path" \
      || fail "$workflow does not map raw evidence to artifact: $raw_artifact"
    grep -Fq 'remediation-guidance:' "$path" \
      || fail "$workflow does not provide remediation-guidance"
    grep -Fq 'tool-outcome:' "$path" \
      || fail "$workflow does not map scanner lifecycle into tool-outcome"
    grep -Fq 'raw-evidence:' "$path" \
      || fail "$workflow does not map scanner output into raw-evidence"
    grep -Fq "blocking: \${{ inputs.blocking }}" "$path" \
      || fail "$workflow does not map its public blocking policy"
    if [ "$failure_capture" = continue-on-error ]; then
      grep -Fq 'continue-on-error: true' "$path" \
        || fail "$workflow does not preserve scanner failure for normalization"
    else
      grep -Fq "tool-outcome: \${{ steps.scan.outputs.scanner-outcome || 'failure' }}" "$path" \
        || fail "$workflow does not default a missing scanner outcome to failure"
    fi
    grep -Fq "name: $raw_artifact" "$path" \
      || fail "$workflow does not publish raw evidence artifact: $raw_artifact"
    grep -Fq "name: $normalized_artifact" "$path" \
      || fail "$workflow does not publish normalized artifact: $normalized_artifact"
    [ -f "$repo_root/$lifecycle_test" ] \
      || fail "$workflow does not name an executable lifecycle contract test"
  else
    marker="$(jq -r --arg workflow "$workflow" '.workflows[$workflow].consumer_marker' "$manifest")"
    grep -Fq "$marker" "$path" \
      || fail "$workflow does not expose its declared provider-native output surface"
  fi
done <<< "$declared_workflows"

actual_actions="$(find "$repo_root/actions" -mindepth 2 -maxdepth 2 -type f \
  \( -name action.yml -o -name action.yaml \) \
  | sed "s#^$repo_root/##" | sort)"
declared_actions="$(jq -r '.actions | keys[]' "$manifest" | sort)"
[ "$actual_actions" = "$declared_actions" ] \
  || fail "every action must declare its consumable outputs and remediation surface"

while IFS= read -r action; do
  [ -n "$action" ] || continue
  outputs="$(awk '
    /^outputs:[[:space:]]*$/ { in_outputs = 1; next }
    in_outputs && /^[^[:space:]#]/ { in_outputs = 0 }
    in_outputs && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
      line = $0
      sub(/^  /, "", line)
      sub(/:[[:space:]]*$/, "", line)
      print line
    }
  ' "$repo_root/$action")"
  while IFS= read -r required_output; do
    [ -n "$required_output" ] || continue
    grep -Fxq "$required_output" <<< "$outputs" \
      || fail "$action does not expose required output: $required_output"
  done < <(jq -r --arg action "$action" '.actions[$action].required_outputs[]' "$manifest")

  mode="$(jq -r --arg action "$action" '.actions[$action].mode' "$manifest")"
  if [ "$mode" = scanner-invocation ]; then
    grep -Fxq scanner-outcome <<< "$outputs" \
      || fail "$action scanner invocation does not expose scanner-outcome"
    grep -Fxq result-file <<< "$outputs" \
      || fail "$action scanner invocation does not expose result-file"
    consumer_workflow="$(jq -r --arg action "$action" '.actions[$action].consumer_workflow' "$manifest")"
    jq -e --arg workflow "$consumer_workflow" \
      '.workflows[$workflow].mode == "normalized-evaluation"' "$manifest" >/dev/null \
      || fail "$action does not name an owning normalized workflow"
    action_directory="${action%/action.y*ml}"
    grep -Fq "filecoin-project/ff-sec-actions/$action_directory@" "$repo_root/$consumer_workflow" \
      || fail "$action is not composed by its owning normalized workflow"
  elif [ "$mode" = consumer-evaluation ]; then
    grep -Fxq evaluation-result <<< "$outputs" \
      || fail "$action consumer evaluation does not expose evaluation-result"
  elif [ "$mode" = profile-aggregate ]; then
    grep -Fxq summary <<< "$outputs" \
      || fail "$action profile aggregate does not expose summary"
  elif [ "$mode" = profile-detection ]; then
    grep -Fxq profiles-json <<< "$outputs" \
      || fail "$action profile detection does not expose selected profiles"
    grep -Fxq coverage-gaps-count <<< "$outputs" \
      || fail "$action profile detection does not expose coverage gaps"
  elif [ "$mode" = legacy-compatibility ] && [ "$action" != actions/scanner-outcome/action.yml ]; then
    fail "$action introduces a new legacy compatibility surface"
  fi
done <<< "$declared_actions"

printf 'consumable output contract checks passed.\n'

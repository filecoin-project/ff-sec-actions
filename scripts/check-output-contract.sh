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
    (.mode | IN("normalized-evaluation", "provider-native"))
    and (.consumer_surface | type == "string" and length > 0)
    and (.remediation_surface | type == "string" and length > 0)))
  and (.actions | type == "object" and length > 0 and all(.[];
    (.required_outputs | type == "array" and length > 0)
    and (.consumer_surface | type == "string" and length > 0)
    and (.remediation_surface | type == "string" and length > 0)))
' "$manifest" >/dev/null || fail "manifest does not match schema version 1"

actual_workflows="$(find "$repo_root/.github/workflows" -maxdepth 1 -type f -name 'sec-*.yml' \
  | sed "s#^$repo_root/##" | sort)"
declared_workflows="$(jq -r '.workflows | keys[]' "$manifest" | sort)"
[ "$actual_workflows" = "$declared_workflows" ] \
  || fail "every sec-* evaluation workflow must declare a consumable output interface"

while IFS= read -r workflow; do
  [ -n "$workflow" ] || continue
  path="$repo_root/$workflow"
  mode="$(jq -r --arg workflow "$workflow" '.workflows[$workflow].mode' "$manifest")"
  if [ "$mode" = normalized-evaluation ]; then
    evaluation_id="$(jq -r --arg workflow "$workflow" '.workflows[$workflow].evaluation_id' "$manifest")"
    raw_artifact="$(jq -r --arg workflow "$workflow" '.workflows[$workflow].raw_artifact' "$manifest")"
    normalized_artifact="$(jq -r --arg workflow "$workflow" '.workflows[$workflow].normalized_artifact' "$manifest")"
    grep -Fq 'filecoin-project/ff-sec-actions/actions/evaluation-adapter@' "$path" \
      || fail "$workflow does not use the shared consumable Evaluation Adapter"
    grep -Fq "evaluation-id: $evaluation_id" "$path" \
      || fail "$workflow does not expose its stable evaluation id: $evaluation_id"
    grep -Fq "evidence-artifact: $raw_artifact" "$path" \
      || fail "$workflow does not map raw evidence to artifact: $raw_artifact"
    grep -Fq 'remediation-guidance:' "$path" \
      || fail "$workflow does not provide remediation-guidance"
    grep -Fq "name: $raw_artifact" "$path" \
      || fail "$workflow does not publish raw evidence artifact: $raw_artifact"
    grep -Fq "name: $normalized_artifact" "$path" \
      || fail "$workflow does not publish normalized artifact: $normalized_artifact"
  else
    marker="$(jq -r --arg workflow "$workflow" '.workflows[$workflow].consumer_marker' "$manifest")"
    grep -Fq "$marker" "$path" \
      || fail "$workflow does not expose its declared provider-native output surface"
  fi
done <<< "$declared_workflows"

actual_actions="$(find "$repo_root/actions" -mindepth 2 -maxdepth 2 -type f -name action.yml \
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
done <<< "$declared_actions"

printf 'consumable output contract checks passed.\n'

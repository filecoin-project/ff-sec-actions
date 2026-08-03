#!/usr/bin/env bash
# Detect Filecoin Security Profiles without executing Consumer Project code.
set -euo pipefail

REPOSITORY_PATH="${REPOSITORY_PATH:-.}"
RESULT_FILE="${RESULT_FILE:-profile-detection.json}"
SUMMARY_FILE="${SUMMARY_FILE:-profile-detection-summary.md}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/null}"
GITHUB_STEP_SUMMARY="${GITHUB_STEP_SUMMARY:-}"

fail() {
  printf 'profile-detection error: %s\n' "$*" >&2
  exit 1
}

set_output() {
  printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"
}

command -v jq >/dev/null 2>&1 || fail "jq is required"
[ -d "$REPOSITORY_PATH" ] || fail "repository path is not a directory: $REPOSITORY_PATH"

repository_root="$(cd "$REPOSITORY_PATH" && pwd -P)"
work_directory="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ff-sec-profile-detection.XXXXXX")"
trap 'rm -rf "$work_directory"' EXIT
detections_file="$work_directory/detections.ndjson"
candidates_file="$work_directory/candidates.ndjson"
: > "$detections_file"
: > "$candidates_file"

relative_path() {
  local absolute_path="$1"
  if [ "$absolute_path" = "$repository_root" ]; then
    printf '.\n'
  else
    printf '%s\n' "${absolute_path#"$repository_root"/}"
  fi
}

find_component_root() {
  local directory="$1"
  while [ "$directory" != "$repository_root" ]; do
    if [ -f "$directory/foundry.toml" ] \
      || [ -f "$directory/hardhat.config.js" ] \
      || [ -f "$directory/hardhat.config.ts" ] \
      || [ -f "$directory/package.json" ]; then
      printf '%s\n' "$directory"
      return
    fi
    directory="$(dirname "$directory")"
  done
  printf '%s\n' "$repository_root"
}

emit_detection() {
  local component_path="$1"
  local profile_id="$2"
  local profile_label="$3"
  local confidence="$4"
  local evidence_path="$5"
  local reason="$6"

  jq -cn \
    --arg component_path "$component_path" \
    --arg profile_id "$profile_id" \
    --arg profile_label "$profile_label" \
    --arg confidence "$confidence" \
    --arg evidence_path "$evidence_path" \
    --arg reason "$reason" \
    '{
      component_path: $component_path,
      profile: {
        id: $profile_id,
        label: $profile_label,
        confidence: $confidence,
        evidence: [{path: $evidence_path, reason: $reason}]
      }
    }' >> "$detections_file"
}

while IFS= read -r -d '' marker; do
  case "$(basename "$marker")" in
    *.yml|*.yaml)
      if ! LC_ALL=C grep -Eiq \
        '(^[[:space:]]*kind:[[:space:]]*(Deployment|StatefulSet|DaemonSet|Pod|Service|Ingress|CronJob)|lotus-miner|boostd?|curio|venus-sealer|FULLNODE_API_INFO|MINER_API_INFO|LOTUS_(API|MINER)|FIL_PROOFS_PARAMETER_CACHE)' \
        "$marker"; then
        continue
      fi
      ;;
  esac
  component_path="$(relative_path "$(dirname "$marker")")"
  marker_path="$(relative_path "$marker")"
  jq -cn \
    --arg component_path "$component_path" \
    --arg marker_path "$marker_path" \
    '{component_path: $component_path, evidence: {path: $marker_path}}' \
    >> "$candidates_file"
done < <(
  find "$repository_root" \
    \( -type d \( -name .git -o -name node_modules -o -name vendor -o -name target -o -name dist -o -name out \) -prune \) \
    -o \( -type f \( \
      -name go.mod \
      -o -name Cargo.toml \
      -o -name package.json \
      -o -name pyproject.toml \
      -o -name requirements.txt \
      -o -name pom.xml \
      -o -name build.gradle \
      -o -name build.gradle.kts \
      -o -name mix.exs \
      -o -name composer.json \
      -o -name foundry.toml \
      -o -name hardhat.config.js \
      -o -name hardhat.config.ts \
      -o -name '*.tf' \
      -o -name '*.yml' \
      -o -name '*.yaml' \
      -o -name Dockerfile \
      -o -name 'Dockerfile.*' \
    \) -print0 \)
)

while IFS= read -r -d '' manifest; do
  if LC_ALL=C grep -Eq \
    'github\.com/(filecoin-project/(lotus|go-state-types)|ipfs-force-community/(venus|venus-shared))' \
    "$manifest"; then
    component_path="$(relative_path "$(dirname "$manifest")")"
    manifest_path="$(relative_path "$manifest")"
    emit_detection "$component_path" "go-node" "Go node" "high" \
      "$manifest_path" "declares a Lotus or Filecoin node dependency"
  fi

done < <(
  find "$repository_root" \
    \( -type d \( -name .git -o -name node_modules -o -name vendor -o -name target -o -name dist \) -prune \) \
    -o \( -type f -name go.mod -print0 \)
)

while IFS= read -r -d '' manifest; do
  if LC_ALL=C grep -Eq \
    '(^|[^A-Za-z0-9_-])(fvm_sdk|fvm_shared|fil_actors_runtime|fil_actor_[A-Za-z0-9_-]+)([^A-Za-z0-9_-]|$)' \
    "$manifest"; then
    component_path="$(relative_path "$(dirname "$manifest")")"
    manifest_path="$(relative_path "$manifest")"
    emit_detection "$component_path" "fvm-actor" "FVM actor" "high" \
      "$manifest_path" "declares an FVM actor SDK or shared runtime dependency"
  fi

done < <(
  find "$repository_root" \
    \( -type d \( -name .git -o -name node_modules -o -name vendor -o -name target -o -name dist \) -prune \) \
    -o \( -type f -name Cargo.toml -print0 \)
)

while IFS= read -r -d '' source_file; do
  if LC_ALL=C grep -Eq \
    '(@zondax/filecoin-solidity|filecoin-solidity|FilecoinAPI|MarketAPI|MinerAPI|SendAPI|0xfe000000000000000000000000000000000000)' \
    "$source_file"; then
    component_root="$(find_component_root "$(dirname "$source_file")")"
    component_path="$(relative_path "$component_root")"
    source_path="$(relative_path "$source_file")"
    emit_detection "$component_path" "fevm-contract" "FEVM contract" "high" \
      "$source_path" "imports a Filecoin Solidity API or precompile library"
  fi

done < <(
  find "$repository_root" \
    \( -type d \( -name .git -o -name node_modules -o -name vendor -o -name target -o -name dist -o -name out \) -prune \) \
    -o \( -type f -name '*.sol' -print0 \)
)

while IFS= read -r -d '' manifest; do
  if LC_ALL=C grep -Eq \
    '"(express|fastify|@nestjs/(core|platform-express)|koa|hapi|apollo-server|start)"[[:space:]]*:' \
    "$manifest"; then
    component_path="$(relative_path "$(dirname "$manifest")")"
    manifest_path="$(relative_path "$manifest")"
    emit_detection "$component_path" "service" "Service application" "medium" \
      "$manifest_path" "declares a network service runtime or framework"
  fi

  if LC_ALL=C grep -Eiq \
    '(@web3-storage/|web3\.storage|nft\.storage|filecoin-storage|@filecoin-shipyard/lotus-client-provider|lighthouse-web3|ipfs-http-client)' \
    "$manifest"; then
    component_path="$(relative_path "$(dirname "$manifest")")"
    manifest_path="$(relative_path "$manifest")"
    emit_detection "$component_path" "storage-application" "Storage application" "high" \
      "$manifest_path" "declares a Filecoin or IPFS storage application dependency"
  fi
done < <(
  find "$repository_root" \
    \( -type d \( -name .git -o -name node_modules -o -name vendor -o -name target -o -name dist -o -name out \) -prune \) \
    -o \( -type f -name package.json -print0 \)
)

while IFS= read -r -d '' infrastructure_file; do
  infrastructure_path="$(relative_path "$infrastructure_file")"
  component_path="$(relative_path "$(dirname "$infrastructure_file")")"
  infrastructure_reason=""
  case "$(basename "$infrastructure_file")" in
    *.tf) infrastructure_reason="contains Terraform infrastructure configuration" ;;
    Dockerfile|Dockerfile.*) infrastructure_reason="contains container build infrastructure" ;;
    *.yml|*.yaml)
      if LC_ALL=C grep -Eq '^[[:space:]]*kind:[[:space:]]*(Deployment|StatefulSet|DaemonSet|Pod|Service|Ingress|CronJob)' "$infrastructure_file"; then
        infrastructure_reason="contains Kubernetes workload or network configuration"
      fi
      ;;
  esac

  if [ -n "$infrastructure_reason" ]; then
    emit_detection "$component_path" "infrastructure" "Infrastructure" "medium" \
      "$infrastructure_path" "$infrastructure_reason"
  fi

  if LC_ALL=C grep -Eiq \
    '(lotus-miner|boostd?|curio|venus-sealer|FULLNODE_API_INFO|MINER_API_INFO|LOTUS_(API|MINER)|FIL_PROOFS_PARAMETER_CACHE)' \
    "$infrastructure_file"; then
    emit_detection "$component_path" "storage-provider-infrastructure" \
      "Storage-provider infrastructure" "high" "$infrastructure_path" \
      "configures Filecoin storage-provider software or API authority"
  fi
done < <(
  find "$repository_root" \
    \( -type d \( -name .git -o -name node_modules -o -name vendor -o -name target -o -name dist -o -name out \) -prune \) \
    -o \( -type f \( -name '*.tf' -o -name '*.yml' -o -name '*.yaml' -o -name 'Dockerfile' -o -name 'Dockerfile.*' \) -print0 \)
)

mkdir -p "$(dirname "$RESULT_FILE")" "$(dirname "$SUMMARY_FILE")"

jq -n \
  --arg target "$REPOSITORY_PATH" \
  --slurpfile detections "$detections_file" \
  --slurpfile candidates "$candidates_file" \
  '
    ([
      $candidates[].component_path,
      $detections[].component_path
    ] | unique) as $component_paths
    | [
        $component_paths[] as $component_path
        | ($detections | map(select(.component_path == $component_path))) as $matches
        | ($candidates
            | map(select(.component_path == $component_path) | .evidence)
            | unique_by(.path)) as $candidate_evidence
        | if ($matches | length) > 0 then
            {
              path: $component_path,
              status: "classified",
              profiles: (
                $matches
                | sort_by(.profile.id)
                | group_by(.profile.id)
                | map({
                    id: .[0].profile.id,
                    label: .[0].profile.label,
                    confidence: .[0].profile.confidence,
                    evidence: ([.[].profile.evidence[]] | unique_by(.path, .reason))
                  })
              )
            }
          else
            {
              path: $component_path,
              status: "unsupported",
              profiles: [],
              evidence: $candidate_evidence
            }
          end
      ] as $components
    | {
        schema_version: 1,
        detector: {name: "detect-filecoin-profile", version: "0.1.0"},
        completion: "complete",
        target: $target,
        components: $components,
        selected_profiles: (
          [
            $components[] as $component
            | $component.profiles[]
            | {id: .id, path: $component.path}
          ]
          | sort_by(.id, .path)
          | group_by(.id)
          | map({id: .[0].id, paths: map(.path)})
        ),
        coverage: {
          included: ($components | map(select(.status == "classified") | .path)),
          gaps: ($components | map(
            select(.status == "unsupported")
            | {
                path: .path,
                reason: "recognized component has no supported Filecoin Security Profile",
                remediation: "select a profile manually or add a detector rule with fixtures"
              }
          )),
          limitations: [
            "classification is based on repository files and declared dependencies; project code is not executed",
            "directories without a recognized project or infrastructure marker may require manual profile selection"
          ]
        }
      }
  ' > "$RESULT_FILE"

{
  printf '# Filecoin Security Profile Detection\n\n'
  printf 'Completion: **complete**  \n'
  printf 'Components: **%s**  \n' "$(jq '.components | length' "$RESULT_FILE")"
  printf 'Coverage gaps: **%s**\n\n' "$(jq '.coverage.gaps | length' "$RESULT_FILE")"
  printf '| Path | Security Profile | Confidence | Selection reason |\n'
  printf '|---|---|---|---|\n'
  jq -r '
    .components[]
    | if (.profiles | length) == 0 then
        [.path, "Unsupported", "n/a", "manual profile selection required"]
      else
        . as $component
        | .profiles[]
        | [
            $component.path,
            .label,
            .confidence,
            ([.evidence[].reason] | unique | join("; "))
          ]
      end
    | @tsv
  ' "$RESULT_FILE" | while IFS=$'\t' read -r path label confidence reason; do
    # shellcheck disable=SC2016 # Markdown backticks are literal table syntax.
    printf '| `%s` | %s | %s | %s |\n' "$path" "$label" "$confidence" "$reason"
  done
} > "$SUMMARY_FILE"

if [ -n "$GITHUB_STEP_SUMMARY" ]; then
  cat "$SUMMARY_FILE" >> "$GITHUB_STEP_SUMMARY"
fi

jq -r '
  .coverage.gaps[].path
  | gsub("%"; "%25")
  | gsub("\\r"; "%0D")
  | gsub("\\n"; "%0A")
  | gsub(":"; "%3A")
  | gsub(","; "%2C")
' "$RESULT_FILE" | while IFS= read -r gap_path; do
  printf '::warning file=%s::No supported Filecoin Security Profile was detected; select one manually or add a detector rule with fixtures.\n' "$gap_path"
done

profiles_json="$(jq -c '.selected_profiles' "$RESULT_FILE")"
component_count="$(jq '.components | length' "$RESULT_FILE")"
coverage_gaps_count="$(jq '.coverage.gaps | length' "$RESULT_FILE")"

set_output result_file "$RESULT_FILE"
set_output summary "$SUMMARY_FILE"
set_output profiles_json "$profiles_json"
set_output component_count "$component_count"
set_output coverage_gaps_count "$coverage_gaps_count"

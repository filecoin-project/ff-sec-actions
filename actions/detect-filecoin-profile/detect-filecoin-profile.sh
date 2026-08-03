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

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
control_root="$(cd "$script_directory/../.." && pwd -P)"
PROFILE_CATALOG="${PROFILE_CATALOG:-$control_root/profiles/filecoin-project-profiles.json}"
[ -f "$PROFILE_CATALOG" ] || fail "profile catalog is missing: $PROFILE_CATALOG"
jq -e '
  .schema_version == 1
  and (.catalog_version | type == "string" and length > 0)
  and (.profiles | type == "array" and length > 0)
  and ([.profiles[].id] | length == (unique | length))
  and all(.profiles[];
    (.id | type == "string" and length > 0)
    and (.label | type == "string" and length > 0))
' "$PROFILE_CATALOG" >/dev/null || fail "profile catalog is invalid"

repository_root="$(cd "$REPOSITORY_PATH" && pwd -P)"
work_directory="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ff-sec-profile-detection.XXXXXX")"
trap 'rm -rf "$work_directory"' EXIT
detections_file="$work_directory/detections.ndjson"
candidates_file="$work_directory/candidates.ndjson"
ambiguities_file="$work_directory/ambiguities.ndjson"
: > "$detections_file"
: > "$candidates_file"
: > "$ambiguities_file"

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
  local parent
  local fallback="$directory"

  while [ "$directory" != "$repository_root" ]; do
    if [ -f "$directory/foundry.toml" ] \
      || [ -f "$directory/hardhat.config.js" ] \
      || [ -f "$directory/hardhat.config.ts" ] \
      || [ -f "$directory/package.json" ]; then
      printf '%s\n' "$directory"
      return
    fi
    parent="$(dirname "$directory")"
    if [ "$parent" = "$repository_root" ]; then
      fallback="$directory"
    fi
    directory="$parent"
  done

  if [ -f "$repository_root/foundry.toml" ] \
    || [ -f "$repository_root/hardhat.config.js" ] \
    || [ -f "$repository_root/hardhat.config.ts" ] \
    || [ -f "$repository_root/package.json" ]; then
    fallback="$repository_root"
  fi
  printf '%s\n' "$fallback"
}

emit_candidate() {
  local component_path="$1"
  local evidence_path="$2"
  local reason="${3:-}"

  jq -cn \
    --arg component_path "$component_path" \
    --arg evidence_path "$evidence_path" \
    --arg reason "$reason" \
    '{
      component_path: $component_path,
      evidence: ({path: $evidence_path} + if $reason == "" then {} else {reason: $reason} end)
    }' >> "$candidates_file"
}

emit_ambiguity() {
  local component_path="$1"
  local evidence_path="$2"
  local reason="$3"

  jq -cn \
    --arg component_path "$component_path" \
    --arg evidence_path "$evidence_path" \
    --arg reason "$reason" \
    '{component_path: $component_path, evidence: {path: $evidence_path, reason: $reason}}' \
    >> "$ambiguities_file"
}

emit_detection() {
  local component_path="$1"
  local profile_id="$2"
  local confidence="$3"
  local evidence_path="$4"
  local reason="$5"
  local profile_label

  profile_label="$(jq -er --arg id "$profile_id" \
    '.profiles[] | select(.id == $id) | .label' "$PROFILE_CATALOG")" \
    || fail "detector references an unknown profile: $profile_id"

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

while IFS= read -r -d '' project_file; do
  file_name="$(basename "$project_file")"
  file_path="$(relative_path "$project_file")"
  component_root="$(dirname "$project_file")"
  component_path="$(relative_path "$component_root")"

  case "$file_name" in
    go.mod)
      emit_candidate "$component_path" "$file_path"
      if LC_ALL=C grep -Eq \
        'github\.com/(filecoin-project/lotus|ipfs-force-community/(venus|venus-shared))' \
        "$project_file"; then
        emit_detection "$component_path" "go-node" "high" "$file_path" \
          "declares a Lotus or Filecoin node dependency"
      elif LC_ALL=C grep -Eq 'github\.com/filecoin-project/go-state-types' "$project_file"; then
        emit_ambiguity "$component_path" "$file_path" \
          "go-state-types is used by nodes, libraries, and tooling"
      fi
      ;;
    Cargo.toml)
      emit_candidate "$component_path" "$file_path"
      if LC_ALL=C grep -Eq \
        '(^|[^A-Za-z0-9_-])(fvm_sdk|fil_actors_runtime|fil_actor_[A-Za-z0-9_-]+)([^A-Za-z0-9_-]|$)' \
        "$project_file"; then
        emit_detection "$component_path" "fvm-actor" "high" "$file_path" \
          "declares an FVM actor SDK or actor runtime dependency"
      elif LC_ALL=C grep -Eq \
        '(^|[^A-Za-z0-9_-])fvm_shared([^A-Za-z0-9_-]|$)' "$project_file"; then
        emit_ambiguity "$component_path" "$file_path" \
          "fvm_shared is used by actors, clients, libraries, and tooling"
      fi
      ;;
    package.json)
      emit_candidate "$component_path" "$file_path"
      if LC_ALL=C grep -Eq \
        '"(express|fastify|@nestjs/(core|platform-express)|koa|hapi|apollo-server)"[[:space:]]*:' \
        "$project_file"; then
        emit_detection "$component_path" "service" "medium" "$file_path" \
          "declares a network service framework"
      elif LC_ALL=C grep -Eq '"start"[[:space:]]*:' "$project_file"; then
        emit_ambiguity "$component_path" "$file_path" \
          "a start script does not distinguish a service from an application or tool"
      fi
      if LC_ALL=C grep -Eiq \
        '(@web3-storage/|web3\.storage|nft\.storage|filecoin-storage|@filecoin-shipyard/lotus-client-provider|lighthouse-web3|ipfs-http-client)' \
        "$project_file"; then
        emit_detection "$component_path" "storage-application" "high" "$file_path" \
          "declares a Filecoin or IPFS storage application dependency"
      fi
      ;;
    *.sol)
      component_root="$(find_component_root "$(dirname "$project_file")")"
      component_path="$(relative_path "$component_root")"
      emit_candidate "$component_path" "$file_path"
      if LC_ALL=C grep -Eq \
        '(@zondax/filecoin-solidity|filecoin-solidity|FilecoinAPI|MarketAPI|MinerAPI|SendAPI|0xfe000000000000000000000000000000000000)' \
        "$project_file"; then
        emit_detection "$component_path" "fevm-contract" "high" "$file_path" \
          "imports a Filecoin Solidity API or precompile library"
      fi
      ;;
    *.tf)
      emit_candidate "$component_path" "$file_path"
      emit_detection "$component_path" "infrastructure" "medium" "$file_path" \
        "contains Terraform infrastructure configuration"
      if LC_ALL=C grep -Eiq \
        '(lotus-miner|boostd?|curio|venus-sealer|FULLNODE_API_INFO|MINER_API_INFO|LOTUS_(API|MINER)|FIL_PROOFS_PARAMETER_CACHE)' \
        "$project_file"; then
        emit_detection "$component_path" "storage-provider-infrastructure" "high" \
          "$file_path" "configures Filecoin storage-provider software or API authority"
      fi
      ;;
    Dockerfile|Dockerfile.*)
      emit_candidate "$component_path" "$file_path"
      emit_detection "$component_path" "infrastructure" "medium" "$file_path" \
        "contains container build infrastructure"
      if LC_ALL=C grep -Eiq \
        '(lotus-miner|boostd?|curio|venus-sealer|FULLNODE_API_INFO|MINER_API_INFO|LOTUS_(API|MINER)|FIL_PROOFS_PARAMETER_CACHE)' \
        "$project_file"; then
        emit_detection "$component_path" "storage-provider-infrastructure" "high" \
          "$file_path" "configures Filecoin storage-provider software or API authority"
      fi
      ;;
    *.yml|*.yaml)
      infrastructure_reason=""
      if LC_ALL=C grep -Eq \
        '^[[:space:]]*kind:[[:space:]]*(Deployment|StatefulSet|DaemonSet|Pod|Service|Ingress|CronJob)' \
        "$project_file"; then
        infrastructure_reason="contains Kubernetes workload or network configuration"
      fi
      if LC_ALL=C grep -Eiq \
        '(lotus-miner|boostd?|curio|venus-sealer|FULLNODE_API_INFO|MINER_API_INFO|LOTUS_(API|MINER)|FIL_PROOFS_PARAMETER_CACHE)' \
        "$project_file"; then
        emit_candidate "$component_path" "$file_path"
        emit_detection "$component_path" "storage-provider-infrastructure" "high" \
          "$file_path" "configures Filecoin storage-provider software or API authority"
      elif [ -n "$infrastructure_reason" ]; then
        emit_candidate "$component_path" "$file_path"
      else
        continue
      fi
      if [ -n "$infrastructure_reason" ]; then
        emit_detection "$component_path" "infrastructure" "medium" "$file_path" \
          "$infrastructure_reason"
      fi
      ;;
    *)
      emit_candidate "$component_path" "$file_path"
      ;;
  esac
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
      -o -name Gemfile \
      -o -name Rakefile \
      -o -name '*.gemspec' \
      -o -name mix.exs \
      -o -name composer.json \
      -o -name Package.swift \
      -o -name CMakeLists.txt \
      -o -name meson.build \
      -o -name WORKSPACE \
      -o -name WORKSPACE.bazel \
      -o -name BUILD \
      -o -name BUILD.bazel \
      -o -name '*.cabal' \
      -o -name foundry.toml \
      -o -name hardhat.config.js \
      -o -name hardhat.config.ts \
      -o -name '*.sol' \
      -o -name '*.tf' \
      -o -name '*.yml' \
      -o -name '*.yaml' \
      -o -name Dockerfile \
      -o -name 'Dockerfile.*' \
    \) -print0 \)
)

if [ ! -s "$candidates_file" ]; then
  emit_candidate "." "." "no recognized project or infrastructure marker was found"
fi

mkdir -p "$(dirname "$RESULT_FILE")" "$(dirname "$SUMMARY_FILE")"

jq -n \
  --arg target "$REPOSITORY_PATH" \
  --slurpfile detections "$detections_file" \
  --slurpfile candidates "$candidates_file" \
  --slurpfile ambiguities "$ambiguities_file" \
  '
    ([
      $candidates[].component_path,
      $detections[].component_path,
      $ambiguities[].component_path
    ] | unique) as $component_paths
    | [
        $component_paths[] as $component_path
        | ($detections | map(select(.component_path == $component_path))) as $matches
        | ($ambiguities | map(select(.component_path == $component_path))) as $uncertainties
        | ($candidates
            | map(select(.component_path == $component_path) | .evidence)
            | unique_by(.path, .reason)) as $candidate_evidence
        | ($matches
            | sort_by(.profile.id)
            | group_by(.profile.id)
            | map({
                id: .[0].profile.id,
                label: .[0].profile.label,
                confidence: .[0].profile.confidence,
                evidence: ([.[].profile.evidence[]] | unique_by(.path, .reason))
              })) as $profiles
        | if ($uncertainties | length) > 0 then
            {
              path: $component_path,
              status: "ambiguous",
              profiles: $profiles,
              evidence: ([$uncertainties[].evidence] | unique_by(.path, .reason))
            }
          elif ($profiles | length) > 0 then
            {path: $component_path, status: "classified", profiles: $profiles}
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
          included: ($components | map(select((.profiles | length) > 0) | .path)),
          gaps: ($components | map(
            select(.status == "unsupported" or .status == "ambiguous")
            | if .status == "ambiguous" then
                {
                  path: .path,
                  reason: "component signals do not identify one supported Filecoin Security Profile",
                  remediation: "select a profile manually or add a stronger fixture-backed detector rule"
                }
              else
                {
                  path: .path,
                  reason: "recognized component has no supported Filecoin Security Profile",
                  remediation: "select a profile manually or add a detector rule with fixtures"
                }
              end
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
    def markdown_cell:
      gsub("&"; "&amp;")
      | gsub("<"; "&lt;")
      | gsub(">"; "&gt;")
      | gsub("[|]"; "&#124;")
      | gsub("`"; "&#96;");
    .components[]
    | . as $component
    | (
        if .status == "ambiguous" then
          [[.path, "Ambiguous", "n/a", ([.evidence[].reason] | unique | join("; "))]]
        elif .status == "unsupported" then
          [[.path, "Unsupported", "n/a", "manual profile selection required"]]
        else
          []
        end
        + [
            .profiles[]
            | [
                $component.path,
                .label,
                .confidence,
                ([.evidence[].reason] | unique | join("; "))
              ]
          ]
      )[]
    | map(markdown_cell)
    | @tsv
  ' "$RESULT_FILE" | while IFS=$'\t' read -r path label confidence reason; do
    printf '| <code>%s</code> | %s | %s | %s |\n' \
      "$path" "$label" "$confidence" "$reason"
  done
} > "$SUMMARY_FILE"

if [ -n "$GITHUB_STEP_SUMMARY" ]; then
  cat "$SUMMARY_FILE" >> "$GITHUB_STEP_SUMMARY"
fi

jq -r '
  .coverage.gaps[]
  | [
      (.path
        | gsub("%"; "%25")
        | gsub("\\r"; "%0D")
        | gsub("\\n"; "%0A")
        | gsub(":"; "%3A")
        | gsub(","; "%2C")),
      .reason
    ]
  | @tsv
' "$RESULT_FILE" | while IFS=$'\t' read -r gap_path gap_reason; do
  printf '::warning file=%s::Filecoin Security Profile coverage gap: %s.\n' \
    "$gap_path" "$gap_reason"
done

profiles_json="$(jq -c '.selected_profiles' "$RESULT_FILE")"
component_count="$(jq '.components | length' "$RESULT_FILE")"
coverage_gaps_count="$(jq '.coverage.gaps | length' "$RESULT_FILE")"

set_output completion complete
set_output result_file "$RESULT_FILE"
set_output summary "$SUMMARY_FILE"
set_output profiles_json "$profiles_json"
set_output component_count "$component_count"
set_output coverage_gaps_count "$coverage_gaps_count"

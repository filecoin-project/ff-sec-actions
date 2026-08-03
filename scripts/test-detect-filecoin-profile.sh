#!/usr/bin/env bash
# test-detect-filecoin-profile: prove profile routing through the public script interface.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
detector="$repo_root/actions/detect-filecoin-profile/detect-filecoin-profile.sh"
action_metadata="$repo_root/actions/detect-filecoin-profile/action.yml"
profile_catalog="$repo_root/profiles/filecoin-project-profiles.json"
fixture_root="$repo_root/test/fixtures/profile-detection"
test_directory="$(mktemp -d "${TMPDIR:-/tmp}/ff-sec-profile-detection.XXXXXX")"
trap 'rm -rf "$test_directory"' EXIT

fail() {
  printf 'profile-detection test failure: %s\n' "$*" >&2
  exit 1
}

[ -f "$action_metadata" ] || fail "the composite action interface is missing"
[ -f "$profile_catalog" ] || fail "the versioned profile catalog is missing"
jq -e '
  .schema_version == 1
  and .catalog_version == "0.1.0"
  and ([.profiles[].id] == [
    "fevm-contract",
    "fvm-actor",
    "go-node",
    "infrastructure",
    "service",
    "storage-application",
    "storage-provider-infrastructure"
  ])
  and all(.profiles[];
    (.label | type == "string" and length > 0)
    and (.description | type == "string" and length > 0)
    and (.confidence_basis | type == "string" and length > 0)
    and (.planned_evaluations | type == "array")
  )
' "$profile_catalog" >/dev/null \
  || fail "the profile catalog does not expose the detector's versioned profile contract"

for output in result-file summary profiles-json component-count coverage-gaps-count; do
  awk '
    /^outputs:[[:space:]]*$/ { in_outputs = 1; next }
    in_outputs && /^[^[:space:]#]/ { in_outputs = 0 }
    in_outputs && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
      name = $0
      sub(/^  /, "", name)
      sub(/:[[:space:]]*$/, "", name)
      print name
    }
  ' "$action_metadata" | grep -Fxq "$output" \
    || fail "the composite action does not expose required output: $output"
done

grep -Fq 'runner.temp' "$action_metadata" \
  || fail "the composite action does not default evidence into runner-controlled storage"

lotus_result="$test_directory/lotus.json"
lotus_summary="$test_directory/lotus.md"
lotus_outputs="$test_directory/lotus.outputs"
lotus_job_summary="$test_directory/lotus-job-summary.md"
REPOSITORY_PATH="$fixture_root/lotus-node" \
RESULT_FILE="$lotus_result" \
SUMMARY_FILE="$lotus_summary" \
GITHUB_OUTPUT="$lotus_outputs" \
GITHUB_STEP_SUMMARY="$lotus_job_summary" \
  bash "$detector"

jq -e '
  .schema_version == 1
  and .completion == "complete"
  and (.components | length == 1)
  and .components[0].path == "."
  and .components[0].status == "classified"
  and (.components[0].profiles | map(.id) == ["go-node"])
  and (.components[0].profiles[0].evidence | any(
    .path == "go.mod"
    and .reason == "declares a Lotus or Filecoin node dependency"
  ))
  and (.coverage.gaps | length == 0)
' "$lotus_result" >/dev/null \
  || fail "a Lotus-style Go project was not classified with path-scoped evidence"

grep -Fq 'profiles_json=[{"id":"go-node","paths":["."]}]' "$lotus_outputs" \
  || fail "the selected profile was not exposed through the action interface"
# shellcheck disable=SC2016 # Markdown backticks are literal table syntax.
grep -Fq '| `.` | Go node | high |' "$lotus_summary" \
  || fail "the readable profile table did not describe the selected component"
cmp -s "$lotus_summary" "$lotus_job_summary" \
  || fail "the readable table was not appended to the GitHub job summary"

fvm_result="$test_directory/fvm.json"
REPOSITORY_PATH="$fixture_root/fvm-actor" \
RESULT_FILE="$fvm_result" \
SUMMARY_FILE="$test_directory/fvm.md" \
GITHUB_OUTPUT="$test_directory/fvm.outputs" \
  bash "$detector"

jq -e '
  (.components | length == 1)
  and .components[0].path == "."
  and (.components[0].profiles | map(.id) == ["fvm-actor"])
  and (.components[0].profiles[0].evidence | any(
    .path == "Cargo.toml"
    and .reason == "declares an FVM actor SDK or shared runtime dependency"
  ))
' "$fvm_result" >/dev/null \
  || fail "an FVM Rust project was not classified with manifest evidence"

fevm_result="$test_directory/fevm.json"
REPOSITORY_PATH="$fixture_root/fevm-contract" \
RESULT_FILE="$fevm_result" \
SUMMARY_FILE="$test_directory/fevm.md" \
GITHUB_OUTPUT="$test_directory/fevm.outputs" \
  bash "$detector"

jq -e '
  (.components | length == 1)
  and .components[0].path == "."
  and (.components[0].profiles | map(.id) == ["fevm-contract"])
  and (.components[0].profiles[0].evidence | any(
    .path == "src/DealClient.sol"
    and .reason == "imports a Filecoin Solidity API or precompile library"
  ))
' "$fevm_result" >/dev/null \
  || fail "an FEVM contract was not classified from Filecoin Solidity evidence"

service_result="$test_directory/service.json"
REPOSITORY_PATH="$fixture_root/service" \
RESULT_FILE="$service_result" \
SUMMARY_FILE="$test_directory/service.md" \
GITHUB_OUTPUT="$test_directory/service.outputs" \
  bash "$detector"

jq -e '
  (.components | length == 1)
  and .components[0].path == "."
  and (.components[0].profiles | map(.id) == ["service"])
  and (.components[0].profiles[0].evidence | any(
    .path == "package.json"
    and .reason == "declares a network service runtime or framework"
  ))
' "$service_result" >/dev/null \
  || fail "a service application was not classified from runtime manifest evidence"

infrastructure_result="$test_directory/infrastructure.json"
REPOSITORY_PATH="$fixture_root/storage-provider-infrastructure" \
RESULT_FILE="$infrastructure_result" \
SUMMARY_FILE="$test_directory/infrastructure.md" \
GITHUB_OUTPUT="$test_directory/infrastructure.outputs" \
  bash "$detector"

jq -e '
  (.components | length == 1)
  and .components[0].path == "."
  and (.components[0].profiles | map(.id) == ["infrastructure", "storage-provider-infrastructure"])
  and (.components[0].profiles[] | select(.id == "infrastructure") | .evidence | any(
    .path == "main.tf"
    and .reason == "contains Terraform infrastructure configuration"
  ))
  and (.components[0].profiles[] | select(.id == "storage-provider-infrastructure") | .evidence | any(
    .path == "main.tf"
    and .reason == "configures Filecoin storage-provider software or API authority"
  ))
' "$infrastructure_result" >/dev/null \
  || fail "storage-provider infrastructure did not compose general and specialized profiles"

storage_result="$test_directory/storage-application.json"
REPOSITORY_PATH="$fixture_root/storage-application" \
RESULT_FILE="$storage_result" \
SUMMARY_FILE="$test_directory/storage-application.md" \
GITHUB_OUTPUT="$test_directory/storage-application.outputs" \
  bash "$detector"

jq -e '
  (.components | length == 1)
  and (.components[0].profiles | map(.id) == ["service", "storage-application"])
  and (.components[0].profiles[] | select(.id == "storage-application") | .evidence | any(
    .path == "package.json"
    and .reason == "declares a Filecoin or IPFS storage application dependency"
  ))
' "$storage_result" >/dev/null \
  || fail "a storage application did not compose service and storage profiles"

mixed_result="$test_directory/mixed.json"
mixed_log="$test_directory/mixed.log"
REPOSITORY_PATH="$fixture_root/mixed" \
RESULT_FILE="$mixed_result" \
SUMMARY_FILE="$test_directory/mixed.md" \
GITHUB_OUTPUT="$test_directory/mixed.outputs" \
  bash "$detector" > "$mixed_log"

jq -e '
  (.components | length == 3)
  and ([.components[] | select(.path == "node") | .profiles[].id] == ["go-node"])
  and ([.components[] | select(.path == "actor") | .profiles[].id] == ["fvm-actor"])
  and ([.components[] | select(.path == "unsupported-tool")][0] | (
    .status == "unsupported"
    and (.profiles | length == 0)
    and (.evidence | any(.path == "unsupported-tool/pom.xml"))
  ))
  and (.selected_profiles == [
    {"id": "fvm-actor", "paths": ["actor"]},
    {"id": "go-node", "paths": ["node"]}
  ])
  and (.coverage.included == ["actor", "node"])
  and (.coverage.gaps == [{
    "path": "unsupported-tool",
    "reason": "recognized component has no supported Filecoin Security Profile",
    "remediation": "select a profile manually or add a detector rule with fixtures"
  }])
' "$mixed_result" >/dev/null \
  || fail "a mixed repository did not preserve path-scoped profiles and unsupported gaps"

grep -Fq '::warning file=unsupported-tool::No supported Filecoin Security Profile was detected' "$mixed_log" \
  || fail "the unsupported component did not produce a coverage-gap annotation"
# shellcheck disable=SC2016 # Markdown backticks are literal table syntax.
grep -Fq '| `unsupported-tool` | Unsupported | n/a |' "$test_directory/mixed.md" \
  || fail "the readable table hid the unsupported component"

printf 'profile detection tests passed.\n'

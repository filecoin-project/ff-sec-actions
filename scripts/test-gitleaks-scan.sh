#!/usr/bin/env bash
# test-gitleaks-scan: prove secretless PR-range and full-history behavior.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
adapter="$repo_root/actions/gitleaks-scan/gitleaks-scan.sh"
test_directory="$(mktemp -d)"
trap 'rm -rf "$test_directory"' EXIT

fail() {
  printf 'gitleaks-scan test failure: %s\n' "$*" >&2
  exit 1
}

fixture_repo="$test_directory/fork-repository"
mkdir -p "$fixture_repo"
git -C "$fixture_repo" init -q -b main
git -C "$fixture_repo" config user.name fixture
git -C "$fixture_repo" config user.email fixture@example.com
printf 'safe fixture\n' > "$fixture_repo/README.md"
git -C "$fixture_repo" add README.md
git -C "$fixture_repo" -c commit.gpgsign=false commit -qm "safe base"
base_sha="$(git -C "$fixture_repo" rev-parse HEAD)"

cat > "$fixture_repo/planted.env" <<'SECRET'
AWS_ACCESS_KEY_ID=AKIA7QWERTY8ZXCVBNM2
AWS_SECRET_ACCESS_KEY=7xQwErTyUiOpAsDfGhJkLzXcVbNm1234567890ab
SECRET
git -C "$fixture_repo" add planted.env
git -C "$fixture_repo" -c commit.gpgsign=false commit -qm "plant fixture secret"
head_sha="$(git -C "$fixture_repo" rev-parse HEAD)"

run_scan() {
  local name="$1"
  local scope="$2"
  local event_name="$3"
  local base="$4"
  local head="$5"
  local output_file="$test_directory/${name}.outputs"
  local result_file="$test_directory/${name}.sarif"

  (
    cd "$fixture_repo"
    unset GITLEAKS_LICENSE
    SCAN_SCOPE="$scope" \
    EVENT_NAME="$event_name" \
    BASE_SHA="$base" \
    HEAD_SHA="$head" \
    RESULT_FILE="$result_file" \
    CONFIG_PATH=.gitleaks.toml \
    RUNNER_TEMP="$test_directory/runner" \
    GITHUB_OUTPUT="$output_file" \
      bash "$adapter"
  ) >/dev/null

  grep -Fq 'scanner_outcome=success' "$output_file" \
    || fail "$name did not report successful scanner execution"
  [ -s "$result_file" ] || fail "$name did not emit SARIF"
  jq -e '.version == "2.1.0" and ([.runs[] | (.results // [])[]] | length > 0)' \
    "$result_file" >/dev/null \
    || fail "$name did not detect the planted secret"
}

run_scan fork-pr auto pull_request "$base_sha" "$head_sha"

git -C "$fixture_repo" rm -q planted.env
git -C "$fixture_repo" -c commit.gpgsign=false commit -qm "remove fixture secret"
run_scan scheduled-history auto schedule "" ""

invalid_outputs="$test_directory/invalid.outputs"
(
  cd "$fixture_repo"
  SCAN_SCOPE=invalid \
  RESULT_FILE="$test_directory/invalid.sarif" \
  GITHUB_OUTPUT="$invalid_outputs" \
    bash "$adapter"
) >/dev/null 2>&1
grep -Fq 'scanner_outcome=failure' "$invalid_outputs" \
  || fail "invalid scope was not represented as an operational failure"

if grep -Eq '\$\{\{[[:space:]]*secrets\.|GITLEAKS_LICENSE' \
  "$repo_root/.github/workflows/sec-secrets.yml" \
  "$repo_root/examples/consumer-security-pipeline.yml"; then
  fail "consumer secret scanning still depends on a mapped secret"
fi

printf 'secretless fork PR and full-history fixtures passed.\n'

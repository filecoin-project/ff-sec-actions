#!/usr/bin/env bash
# test-baseline-no-exec: prove baseline workflow policy rejects lifecycle execution.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="$repo_root/scripts/check-baseline-no-exec.sh"
test_directory="$(mktemp -d)"
trap 'rm -rf "$test_directory"' EXIT

fail() {
  printf 'baseline-no-exec test failure: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$test_directory/project" "$test_directory/security"

cat > "$test_directory/project/package.json" <<'JSON'
{
  "name": "hostile-consumer-fixture",
  "scripts": {
    "preinstall": "touch lifecycle-hook-executed"
  }
}
JSON

cat > "$test_directory/safe.yml" <<'YAML'
name: Manifest-only evaluation
on: pull_request
jobs:
  inspect:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@0123456789012345678901234567890123456789
        with:
          persist-credentials: false
      - uses: scanner/manifest-inspection@0123456789012345678901234567890123456789
        with:
          scan-ref: project
YAML

cat > "$test_directory/unsafe.yml" <<'YAML'
name: Lifecycle-executing evaluation
on: pull_request
jobs:
  inspect:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - run: npm ci
        working-directory: project
YAML

cat > "$test_directory/security/baseline-policy.json" <<'JSON'
{
  "schema_version": 1,
  "workflows": {
    "safe.yml": {
      "coverage_mode": "manifest-and-lockfile",
      "allowed_actions": ["actions/checkout", "scanner/manifest-inspection"],
      "limitations": ["Installed dependency and build-generated package evidence is excluded."]
    },
    "unsafe.yml": {
      "coverage_mode": "manifest-and-lockfile",
      "allowed_actions": ["actions/checkout"],
      "limitations": ["Installed dependency and build-generated package evidence is excluded."]
    }
  }
}
JSON

BASELINE_NO_EXEC_ROOT="$test_directory" \
BASELINE_NO_EXEC_POLICY="$test_directory/security/baseline-policy.json" \
  bash "$checker" safe.yml \
  || fail "manifest-only inspection was rejected"

[ ! -e "$test_directory/project/lifecycle-hook-executed" ] \
  || fail "the malicious package lifecycle hook executed"

if BASELINE_NO_EXEC_ROOT="$test_directory" \
  BASELINE_NO_EXEC_POLICY="$test_directory/security/baseline-policy.json" \
    bash "$checker" unsafe.yml >/dev/null 2>&1; then
  fail "a baseline workflow that invokes npm was accepted"
fi

printf 'baseline no-execution tests passed.\n'

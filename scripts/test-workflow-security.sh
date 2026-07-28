#!/usr/bin/env bash
# test-workflow-security: exercise the workflow policy through its CLI seam.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="$repo_root/scripts/check-workflow-security.sh"
test_directory="$(mktemp -d)"
trap 'rm -rf "$test_directory"' EXIT

fail() {
  printf 'workflow-security test failure: %s\n' "$*" >&2
  exit 1
}

expect_rejected() {
  local workflow="$1"
  if WORKFLOW_SECURITY_ROOT="$test_directory" \
    WORKFLOW_SECURITY_POLICY="$test_directory/security/workflow-policy.json" \
      bash "$checker" "$workflow" >/dev/null 2>&1; then
    fail "unsafe workflow was accepted: $workflow"
  fi
}

mkdir -p "$test_directory/security"

cat > "$test_directory/safe.yml" <<'YAML'
name: Safe consumer evaluation
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
      - run: scanner --no-exec
YAML

cat > "$test_directory/missing-permissions.yml" <<'YAML'
name: Missing job authority
on: pull_request
jobs:
  inspect:
    runs-on: ubuntu-latest
    steps:
      - run: scanner --no-exec
YAML

cat > "$test_directory/persisted-credential.yml" <<'YAML'
name: Persisted checkout credential
on: pull_request
jobs:
  inspect:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@0123456789012345678901234567890123456789
YAML

cat > "$test_directory/excess-authority.yml" <<'YAML'
name: Excess job authority
on: pull_request
jobs:
  inspect:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - run: scanner --no-exec
YAML

cat > "$test_directory/security/workflow-policy.json" <<'JSON'
{
  "schema_version": 1,
  "workflows": {
    "safe.yml": {
      "inspect": {
        "permissions": {"contents": "read"}
      }
    },
    "missing-permissions.yml": {
      "inspect": {
        "permissions": {"contents": "read"}
      }
    },
    "persisted-credential.yml": {
      "inspect": {
        "permissions": {"contents": "read"}
      }
    },
    "excess-authority.yml": {
      "inspect": {
        "permissions": {"contents": "read"}
      }
    }
  }
}
JSON

WORKFLOW_SECURITY_ROOT="$test_directory" \
WORKFLOW_SECURITY_POLICY="$test_directory/security/workflow-policy.json" \
  bash "$checker" safe.yml \
  || fail "a least-privilege workflow with safe checkout was rejected"

expect_rejected missing-permissions.yml
expect_rejected persisted-credential.yml
expect_rejected excess-authority.yml

cp "$test_directory/safe.yml" "$test_directory/unlisted.yml"
if WORKFLOW_SECURITY_ROOT="$test_directory" \
  WORKFLOW_SECURITY_POLICY="$test_directory/security/workflow-policy.json" \
    bash "$checker" >/dev/null 2>&1; then
  fail "an unlisted workflow bypassed the authority policy"
fi

printf 'workflow-security contract tests passed.\n'

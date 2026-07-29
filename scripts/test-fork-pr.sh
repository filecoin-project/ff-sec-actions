#!/usr/bin/env bash
# Prove each fork boundary has a rejecting fixture mutation.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_fixture="$repo_root/test/fixtures/fork-pr"
checker="$repo_root/scripts/check-fork-pr.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/ff-sec-fork-pr.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

run_check() {
  FORK_PR_FIXTURE_ROOT="$1" bash "$checker"
}

expect_rejection() {
  local name="$1"
  local marker="$2"
  local fixture="$test_root/$name"
  cp -R "$source_fixture" "$fixture"
  printf '%s\n' "$marker" >> "$fixture/workflow.yml"
  if run_check "$fixture" >/dev/null 2>&1; then
    printf 'fork-pr test failure: %s mutation was accepted\n' "$name" >&2
    exit 1
  fi
}

run_check "$source_fixture" >/dev/null
expect_rejection write-token 'permissions: write-all'
expect_rejection secret-context '  secrets: inherit'
expect_rejection oidc '  id-token: write'
expect_rejection cache '  uses: actions/cache@0123456789012345678901234567890123456789'
expect_rejection self-hosted '  runs-on: self-hosted'
expect_rejection consumer-execution 'run: bash untrusted/attack-probes.sh'
expect_rejection checkout-credentials 'persist-credentials: true'
expect_rejection privileged-trigger '  pull_request_target:'

printf 'fork pull-request boundary contract tests passed.\n'

#!/usr/bin/env bash
# test-consumer-actions-security: verify the pinned analyzer catches baseline defects.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_directory="$repo_root/test/fixtures/actions-security"
test_directory="$(mktemp -d)"
trap 'rm -rf "$test_directory"' EXIT

fail() {
  printf 'consumer-actions-security test failure: %s\n' "$*" >&2
  exit 1
}

if [ -n "${ZIZMOR_BIN:-}" ]; then
  zizmor_command=("$ZIZMOR_BIN")
elif command -v uvx >/dev/null 2>&1; then
  export UV_CACHE_DIR="${UV_CACHE_DIR:-$test_directory/uv-cache}"
  export UV_TOOL_DIR="${UV_TOOL_DIR:-$test_directory/uv-tools}"
  export UV_PYTHON_INSTALL_DIR="${UV_PYTHON_INSTALL_DIR:-$test_directory/uv-python}"
  zizmor_command=(uvx --from zizmor==1.28.0 zizmor)
elif command -v pipx >/dev/null 2>&1; then
  export PIPX_HOME="${PIPX_HOME:-$test_directory/pipx-home}"
  export PIPX_BIN_DIR="${PIPX_BIN_DIR:-$test_directory/pipx-bin}"
  zizmor_command=(pipx run --spec zizmor==1.28.0 zizmor)
else
  fail "uvx or pipx is required to run pinned zizmor 1.28.0"
fi

run_fixture() {
  local fixture="$1"
  local expected_audit="$2"
  local output_file="$test_directory/${fixture%.yml}.json"

  "${zizmor_command[@]}" \
    --offline \
    --no-config \
    --strict-collection \
    --persona auditor \
    --min-confidence low \
    --min-severity medium \
    --format json \
    "$fixture_directory/$fixture" > "$output_file" || true

  jq -e --arg audit "$expected_audit" --arg fixture "$fixture" '
    any(.[];
      .ident == $audit
      and (.url | type == "string" and length > 0)
      and any(.locations[];
        .concrete.location.start_point.row >= 0
        and (.symbolic.key.Local.verbatim_path | endswith($fixture))))
  ' "$output_file" >/dev/null \
    || fail "$fixture did not produce actionable $expected_audit output"
}

run_fixture mutable-reference.yml unpinned-uses
run_fixture pwn-request.yml dangerous-triggers
run_fixture template-injection.yml template-injection
run_fixture excessive-permissions.yml excessive-permissions
run_fixture persisted-credentials.yml artipacked
run_fixture oidc-exposure.yml excessive-permissions

if "${zizmor_command[@]}" \
  --offline \
  --no-config \
  --strict-collection \
  "$fixture_directory/invalid-syntax.yml" >/dev/null 2>&1; then
  fail "invalid workflow syntax was accepted"
fi

printf 'consumer GitHub Actions security fixtures passed.\n'

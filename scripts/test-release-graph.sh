#!/usr/bin/env bash
# Contract tests for recursive release-graph validation.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="$repo_root/scripts/check-release-graph.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/ff-sec-release-graph.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

mkdir -p "$fixture_root/.github/workflows" "$fixture_root/actions/demo" "$fixture_root/security"
git -C "$fixture_root" init -q
git -C "$fixture_root" config user.name "Release Graph Test"
git -C "$fixture_root" config user.email "release-graph@example.invalid"

cat > "$fixture_root/actions/demo/action.yml" <<'YAML'
name: Demo
runs:
  using: composite
  steps:
    - shell: bash
      run: bash "${GITHUB_ACTION_PATH}/run.sh"
YAML
printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture_root/actions/demo/run.sh"
git -C "$fixture_root" add actions
git -C "$fixture_root" -c commit.gpgsign=false commit -qm "fixture action"
action_ref="$(git -C "$fixture_root" rev-parse HEAD)"

cat > "$fixture_root/.github/workflows/leaf.yml" <<YAML
name: Leaf
on: workflow_call
jobs:
  scan:
    runs-on: ubuntu-latest
    container:
      image: example.invalid/scanner:1@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    steps:
      - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0
      - uses: example/control/actions/demo@$action_ref
YAML
git -C "$fixture_root" add .github/workflows/leaf.yml
git -C "$fixture_root" -c commit.gpgsign=false commit -qm "fixture leaf"
leaf_ref="$(git -C "$fixture_root" rev-parse HEAD)"

cat > "$fixture_root/.github/workflows/root.yml" <<YAML
name: Root
on: workflow_call
jobs:
  leaf:
    uses: example/control/.github/workflows/leaf.yml@$leaf_ref
YAML
cat > "$fixture_root/security/release-graph.json" <<'JSON'
{
  "schema_version": 1,
  "repository": "example/control",
  "entrypoints": [".github/workflows/root.yml"],
  "expected_assets": {
    "actions/demo": ["actions/demo/action.yml", "actions/demo/run.sh"]
  },
  "required_markers": {}
}
JSON
git -C "$fixture_root" add .github/workflows/root.yml security/release-graph.json
git -C "$fixture_root" -c commit.gpgsign=false commit -qm "fixture root"

run_checker() {
  RELEASE_GRAPH_ROOT="$fixture_root" \
    RELEASE_GRAPH_MANIFEST="$fixture_root/security/release-graph.json" \
    RELEASE_GRAPH_REF="${1:-HEAD}" \
    bash "$checker"
}

expect_rejection() {
  local expected="$1"
  local output
  if output="$(run_checker WORKTREE 2>&1)"; then
    printf 'release-graph test failure: expected rejection containing %s\n' "$expected" >&2
    exit 1
  fi
  grep -Fq "$expected" <<< "$output" || {
    printf 'release-graph test failure: missing rejection %s in: %s\n' "$expected" "$output" >&2
    exit 1
  }
}

run_checker HEAD >/dev/null

sed -i.bak 's/@[0-9a-f]\{40\}/@main/' "$fixture_root/.github/workflows/root.yml"
expect_rejection "mutable action or workflow reference"
mv "$fixture_root/.github/workflows/root.yml.bak" "$fixture_root/.github/workflows/root.yml"

sed -i.bak 's/@sha256:[0-9a-f]\{64\}/:latest/' "$fixture_root/.github/workflows/leaf.yml"
git -C "$fixture_root" add .github/workflows/leaf.yml
git -C "$fixture_root" -c commit.gpgsign=false commit -qm "fixture mutable container"
bad_leaf_ref="$(git -C "$fixture_root" rev-parse HEAD)"
sed -i.bak "s/$leaf_ref/$bad_leaf_ref/" "$fixture_root/.github/workflows/root.yml"
expect_rejection "container without a sha256 digest"
mv "$fixture_root/.github/workflows/root.yml.bak" "$fixture_root/.github/workflows/root.yml"
mv "$fixture_root/.github/workflows/leaf.yml.bak" "$fixture_root/.github/workflows/leaf.yml"

jq '.expected_assets["actions/demo"] += ["actions/demo/missing.sh"]' \
  "$fixture_root/security/release-graph.json" > "$fixture_root/security/release-graph.tmp"
mv "$fixture_root/security/release-graph.tmp" "$fixture_root/security/release-graph.json"
expect_rejection "does not select expected asset"

printf 'release-graph contract tests passed.\n'

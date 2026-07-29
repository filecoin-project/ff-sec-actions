#!/usr/bin/env bash
# check-execution-trust: compare security/execution-trust.json with current surfaces.
# Safe to run locally and in CI; reads repository files and makes no writes.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$repo_root/security/execution-trust.json"
reference="$repo_root/docs/reference/execution-trust.md"
cd "$repo_root"

fail() {
  printf 'execution-trust error: %s\n' "$*" >&2
  exit 1
}

[ -f "$manifest" ] || fail "classification manifest is missing: security/execution-trust.json"
[ -f "$reference" ] || fail "human-readable contract is missing: docs/reference/execution-trust.md"

jq -e '
  .schema_version == 1
  and (.tiers | type == "object" and all(.[];
    (.release_allowed | type == "boolean")
    and (.cache | type == "string" and length > 0)
    and (.runner | type == "string" and length > 0)
    and (.external_transfer | type == "string" and length > 0)))
  and (.surfaces | type == "array" and length > 0)
  and all(.surfaces[];
    (.path | type == "string" and length > 0)
    and (.scope | IN("consumer", "example", "control-repository"))
    and (.current_tier | type == "string" and length > 0)
    and (.target_tier | type == "string" and length > 0)
    and (.observed.checkout | type == "boolean")
    and (.observed.persists_checkout_credentials | type == "boolean")
    and (.observed.explicit_permissions | type == "boolean")
    and (.observed.secret_context | type == "boolean")
    and (.observed.write_permissions | type == "array")
    and (.observed.execution_markers | type == "array")
    and (.observed.mutable_references | type == "boolean")
    and (.observed.mutable_container | type == "boolean")
    and (.observed.oidc | type == "boolean")
    and (.observed.cache | type == "boolean")
    and (.observed.self_hosted_runner | type == "boolean")
    and (.network | type == "array" and length > 0)
    and (.migration | type == "array" and length > 0)
  )
' "$manifest" >/dev/null || fail "classification manifest does not match schema version 1"

jq -e '
  .tiers as $tiers
  | ([.surfaces[].path] | length == (unique | length))
    and all(.surfaces[];
      $tiers[.current_tier] != null
      and $tiers[.target_tier] != null
      and if .scope == "control-repository"
        then .target_tier == "control-repository-ci"
        else $tiers[.target_tier].release_allowed == true
        end)
' "$manifest" >/dev/null \
  || fail "surface paths must be unique and targets must reference an eligible tier"

jq -e '
  all(.surfaces[];
    if .current_tier == "ecosystem-baseline" then
      (.observed.persists_checkout_credentials | not)
      and (.observed.secret_context | not)
      and (.observed.oidc | not)
      and (.observed.cache | not)
      and (.observed.self_hosted_runner | not)
      and (.observed.write_permissions | length == 0)
      and (.observed.execution_markers | length == 0)
    elif .current_tier == "privileged-publisher" then
      (.observed.checkout | not)
      and (.observed.cache | not)
      and (.observed.self_hosted_runner | not)
      and (.observed.execution_markers | length == 0)
    elif .current_tier == "privileged-build-analysis" then
      (.observed.persists_checkout_credentials | not)
      and (.observed.secret_context | not)
      and (.observed.oidc | not)
      and (.observed.cache | not)
      and (.observed.self_hosted_runner | not)
      and (.observed.write_permissions | length == 0)
    elif .current_tier == "privileged-external-analysis" then
      (.observed.checkout | not)
      and (.observed.cache | not)
      and (.observed.self_hosted_runner | not)
      and (.observed.execution_markers | length == 0)
    else true
    end)
' "$manifest" >/dev/null \
  || fail "a release-allowed current tier violates its authority or execution contract"

while IFS= read -r tier; do
  grep -Fq "$tier" "$reference" \
    || fail "human-readable contract does not name declared tier: $tier"
done < <(jq -r '.tiers | keys[]' "$manifest")

actual_surfaces="$(
  {
    find .github/workflows examples -maxdepth 1 -type f -name '*.yml'
    find actions -mindepth 2 -maxdepth 2 -type f -name 'action.yml'
  } | sed 's#^./##' | sort
)"
declared_surfaces="$(jq -r '.surfaces[].path' "$manifest" | sort)"

[ "$actual_surfaces" = "$declared_surfaces" ] \
  || fail "manifest must classify every workflow, example, and action metadata file"

while IFS= read -r path; do
  grep -Fq "$path" "$reference" \
    || fail "human-readable contract does not classify declared surface: $path"
done <<< "$declared_surfaces"

boolean_pattern() {
  local path="$1"
  local pattern="$2"
  if grep -Eq "$pattern" "$path"; then
    printf 'true\n'
  else
    printf 'false\n'
  fi
}

assert_boolean() {
  local path="$1"
  local field="$2"
  local actual="$3"
  local expected
  expected="$(jq -r --arg path "$path" --arg field "$field" \
    '.surfaces[] | select(.path == $path) | .observed[$field]' "$manifest")"
  [ "$actual" = "$expected" ] \
    || fail "$path observed.$field is $expected but implementation is $actual"
}

while IFS= read -r path; do
  checkout="$(boolean_pattern "$path" '^[[:space:]-]*uses:[[:space:]]+actions/checkout@')"
  explicit_permissions="$(boolean_pattern "$path" '^[[:space:]]*permissions:[[:space:]]*$')"
  secret_context="$(boolean_pattern "$path" '\$\{\{[[:space:]]*secrets\.')"
  mutable_references="$(boolean_pattern "$path" '^[[:space:]-]*uses:[[:space:]]+[^[:space:]#]+@(main|master|v[0-9]+)([[:space:]#]|$)')"
  mutable_container="$(boolean_pattern "$path" 'default:[[:space:]]+[^[:space:]]+/[^[:space:]]+:[^@[:space:]]+')"
  oidc="$(boolean_pattern "$path" '^[[:space:]]+id-token:[[:space:]]+write([[:space:]#]|$)')"
  cache=false
  if awk '
    /actions\/cache@/ { enabled = 1 }
    /^[[:space:]]+cache:[[:space:]]/ {
      value = $0
      sub(/^.*cache:[[:space:]]*/, "", value)
      sub(/[[:space:]#].*$/, "", value)
      gsub(/["\047]/, "", value)
      if (value != "false") enabled = 1
    }
    END { exit(enabled ? 0 : 1) }
  ' "$path"; then
    cache=true
  fi
  self_hosted_runner="$(boolean_pattern "$path" '^[[:space:]]*runs-on:.*self-hosted')"

  persists_checkout_credentials=false
  if [ "$checkout" = true ] \
    && ! grep -Eq '^[[:space:]]+persist-credentials:[[:space:]]+false([[:space:]#]|$)' "$path"; then
    persists_checkout_credentials=true
  fi

  assert_boolean "$path" checkout "$checkout"
  assert_boolean "$path" persists_checkout_credentials "$persists_checkout_credentials"
  assert_boolean "$path" explicit_permissions "$explicit_permissions"
  assert_boolean "$path" secret_context "$secret_context"
  assert_boolean "$path" mutable_references "$mutable_references"
  assert_boolean "$path" mutable_container "$mutable_container"
  assert_boolean "$path" oidc "$oidc"
  assert_boolean "$path" cache "$cache"
  assert_boolean "$path" self_hosted_runner "$self_hosted_runner"

  actual_write_permissions="$(
    sed -nE 's/^[[:space:]]+([a-z-]+):[[:space:]]+write([[:space:]#].*)?$/\1/p' "$path" \
      | sort -u | jq -Rsc 'split("\n") | map(select(length > 0)) | sort'
  )"
  declared_write_permissions="$(
    jq -c --arg path "$path" \
      '.surfaces[] | select(.path == $path) | .observed.write_permissions | sort' "$manifest"
  )"
  [ "$actual_write_permissions" = "$declared_write_permissions" ] \
    || fail "$path observed.write_permissions does not match implementation"

  # Bash 3.2 treats an empty array expansion as unbound under `set -u`.
  execution_markers=("")
  grep -Eq '^[[:space:]]+(npm ci|pnpm install)([[:space:]]|$)' "$path" \
    && execution_markers+=(package-install)
  grep -Fq 'github/codeql-action/autobuild@' "$path" \
    && execution_markers+=(codeql-autobuild)
  grep -Fq 'crytic/slither-action@' "$path" \
    && execution_markers+=(slither-analysis)
  grep -Eq '^[[:space:]]+submodules:[[:space:]]+recursive' "$path" \
    && execution_markers+=(recursive-submodules)
  grep -Eq '^[[:space:]]+run:[[:space:]]+bash scripts/' "$path" \
    && execution_markers+=(control-script)
  grep -Eq '^[[:space:]-]*uses:[[:space:]]+\./actions/' "$path" \
    && execution_markers+=(local-action)

  actual_execution_markers="$(printf '%s\n' "${execution_markers[@]}" \
    | jq -Rsc 'split("\n") | map(select(length > 0)) | sort')"
  declared_execution_markers="$(jq -c --arg path "$path" \
    '.surfaces[] | select(.path == $path) | .observed.execution_markers | sort' "$manifest")"
  [ "$actual_execution_markers" = "$declared_execution_markers" ] \
    || fail "$path observed.execution_markers does not match implementation"
done <<< "$actual_surfaces"

printf 'execution-trust classification checks passed.\n'

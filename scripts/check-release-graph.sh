#!/usr/bin/env bash
# Recursively validate immutable consumer workflow, action, asset, and image pins.
set -euo pipefail

repo_root="${RELEASE_GRAPH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
graph_ref="${RELEASE_GRAPH_REF:-HEAD}"
manifest="${RELEASE_GRAPH_MANIFEST:-$repo_root/security/release-graph.json}"

fail() {
  printf 'release-graph error: %s\n' "$*" >&2
  exit 1
}

[ -f "$manifest" ] || fail "manifest is missing: $manifest"

jq -e '
  .schema_version == 1
  and (.repository | type == "string" and length > 0)
  and (.entrypoints | type == "array" and length > 0 and all(.[]; type == "string" and length > 0))
  and (.expected_assets | type == "object" and all(.[]; type == "array" and length > 0))
  and (.required_markers | type == "object" and all(.[]; type == "array" and length > 0))
' "$manifest" >/dev/null || fail "manifest does not match schema version 1"

repository="$(jq -r '.repository' "$manifest")"

load_file() {
  local ref="$1"
  local path="$2"
  if [ "$ref" = WORKTREE ]; then
    [ -f "$repo_root/$path" ] || return 1
    command cat "$repo_root/$path"
  else
    git -C "$repo_root" show "$ref:$path" 2>/dev/null
  fi
}

assert_markers() {
  local path="$1"
  local content="$2"
  local marker
  while IFS= read -r marker; do
    [ -n "$marker" ] || continue
    grep -Fq "$marker" <<< "$content" \
      || fail "$path does not contain required immutable tool marker: $marker"
  done < <(jq -r --arg path "$path" '.required_markers[$path][]?' "$manifest")
}

declare -a queue=()
while IFS= read -r entrypoint; do
  queue+=("$graph_ref|$entrypoint")
done < <(jq -r '.entrypoints[]' "$manifest")

visited_keys=""
visited_count=0
index=0
while [ "$index" -lt "${#queue[@]}" ]; do
  item="${queue[$index]}"
  index=$((index + 1))
  ref="${item%%|*}"
  path="${item#*|}"
  key="$ref:$path"
  grep -Fxq "$key" <<< "$visited_keys" && continue
  visited_keys="${visited_keys}${key}"$'\n'
  visited_count=$((visited_count + 1))

  content="$(load_file "$ref" "$path")" \
    || fail "$path is missing at $ref"
  assert_markers "$path" "$content"

  while IFS= read -r image_ref; do
    [ -n "$image_ref" ] || continue
    image_ref="${image_ref%\"}"
    image_ref="${image_ref#\"}"
    image_ref="${image_ref%\'}"
    image_ref="${image_ref#\'}"
    [[ "$image_ref" =~ @sha256:[0-9a-f]{64}$ ]] \
      || fail "$path at $ref uses a container without a sha256 digest: $image_ref"
  done < <(
    sed -nE \
      -e 's/^[[:space:]]*image:[[:space:]]*([^[:space:]#]+).*/\1/p' \
      -e 's/^[[:space:]]*container:[[:space:]]*([^[:space:]#{]+).*/\1/p' \
      <<< "$content"
  )

  while IFS= read -r uses_ref; do
    [ -n "$uses_ref" ] || continue
    uses_ref="${uses_ref%\"}"
    uses_ref="${uses_ref#\"}"
    uses_ref="${uses_ref%\'}"
    uses_ref="${uses_ref#\'}"

    case "$uses_ref" in
      ./*) fail "$path at $ref uses a worktree-relative action: $uses_ref" ;;
      docker://*)
        [[ "$uses_ref" =~ @sha256:[0-9a-f]{64}$ ]] \
          || fail "$path at $ref uses a Docker action without a sha256 digest: $uses_ref"
        continue
        ;;
    esac

    [[ "$uses_ref" =~ @[0-9a-f]{40}$ ]] \
      || fail "$path at $ref uses a mutable action or workflow reference: $uses_ref"

    if [[ "$uses_ref" =~ ^${repository}/(.+)@([0-9a-f]{40})$ ]]; then
      child_path="${BASH_REMATCH[1]}"
      child_ref="${BASH_REMATCH[2]}"
      if [[ "$child_path" == .github/workflows/*.yml ]]; then
        queue+=("$child_ref|$child_path")
      elif [[ "$child_path" == actions/* ]]; then
        queue+=("$child_ref|$child_path/action.yml")
        asset_count=0
        while IFS= read -r asset; do
          [ -n "$asset" ] || continue
          asset_count=$((asset_count + 1))
          load_file "$child_ref" "$asset" >/dev/null \
            || fail "$uses_ref does not select expected asset: $asset"
          queue+=("$child_ref|$asset")
        done < <(jq -r --arg action "$child_path" '.expected_assets[$action][]?' "$manifest")
        [ "$asset_count" -gt 0 ] \
          || fail "$uses_ref has no expected-assets contract"
      else
        fail "$path at $ref uses an unsupported repository-local target: $uses_ref"
      fi
    fi
  done < <(sed -nE 's/^[[:space:]-]*uses:[[:space:]]+([^[:space:]#]+).*/\1/p' <<< "$content")
done

printf 'release graph checks passed (%s immutable files traversed).\n' "$visited_count"

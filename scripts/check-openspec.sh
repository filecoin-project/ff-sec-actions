#!/usr/bin/env bash
# check-openspec: strictly validate OpenSpec main specs and every active change
# whose planning has started. A freshly scaffolded change (no proposal.md yet)
# is legitimate in-flight state and is reported, not validated.
# Requires the openspec CLI on PATH; reads repository files and makes no writes.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
  printf 'openspec contract error: %s\n' "$*" >&2
  exit 1
}

command -v openspec >/dev/null 2>&1 || fail "the openspec CLI is required"
[ -f openspec/config.yaml ] || fail "openspec/config.yaml is missing"

if compgen -G "openspec/specs/*/spec.md" >/dev/null; then
  openspec validate --specs --strict --no-interactive \
    || fail "main specs failed strict validation"
fi

for change_directory in openspec/changes/*/; do
  [ -d "$change_directory" ] || continue
  change="$(basename "$change_directory")"
  [ "$change" = archive ] && continue
  if [ ! -f "$change_directory/proposal.md" ]; then
    printf 'openspec: %s is scaffolded without a proposal; skipping validation.\n' "$change"
    continue
  fi
  openspec validate "$change" --type change --strict --no-interactive \
    || fail "change $change failed strict validation"
done

printf 'OpenSpec contract checks passed.\n'

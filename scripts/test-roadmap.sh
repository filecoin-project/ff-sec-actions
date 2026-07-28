#!/usr/bin/env bash
# test-roadmap: exercise the public roadmap state interface against isolated copies.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
roadmap_command="$repo_root/scripts/roadmap.sh"
canonical_state="$repo_root/roadmap/state.json"
test_directory="$(mktemp -d)"
trap 'rm -rf "$test_directory"' EXIT

fail() {
  printf 'roadmap test failure: %s\n' "$*" >&2
  exit 1
}

fresh_state() {
  local name="$1"
  jq '
    .current_task_id = null
    | .tasks |= map(
        if .id == "FOUND-01" or .id == "STATE-01" then .
        else .status = "pending"
          | .started_at = null
          | .completed_at = null
        end)
  ' "$canonical_state" > "$test_directory/$name.json"
  printf '%s\n' "$test_directory/$name.json"
}

state_file="$(fresh_state transitions)"
ROADMAP_STATE_FILE="$state_file" bash "$roadmap_command" validate

ROADMAP_STATE_FILE="$state_file" bash "$roadmap_command" next \
  | jq -e '.id == "G0-01"' >/dev/null \
  || fail "G0-01 should be the first actionable task"

if ROADMAP_STATE_FILE="$state_file" bash "$roadmap_command" set-status G0-01 in_progress 2>/dev/null; then
  fail "state mutation succeeded without ROADMAP_ALLOW_WRITE=true"
fi

ROADMAP_STATE_FILE="$state_file" ROADMAP_ALLOW_WRITE=true \
  bash "$roadmap_command" set-status G0-01 in_progress

if ROADMAP_STATE_FILE="$state_file" ROADMAP_ALLOW_WRITE=true \
  bash "$roadmap_command" set-status G0-02 in_progress 2>/dev/null; then
  fail "a second or dependency-blocked task was claimed"
fi

ROADMAP_STATE_FILE="$state_file" ROADMAP_ALLOW_WRITE=true \
  bash "$roadmap_command" set-status G0-01 "done"

ROADMAP_STATE_FILE="$state_file" bash "$roadmap_command" next \
  | jq -e '.id == "G0-02"' >/dev/null \
  || fail "G0-02 should become next after G0-01 completes"

invalid_state="$(fresh_state invalid-transition)"
if ROADMAP_STATE_FILE="$invalid_state" ROADMAP_ALLOW_WRITE=true \
  bash "$roadmap_command" set-status G0-01 "done" 2>/dev/null; then
  fail "a pending task skipped directly to done"
fi

invalid_state="$(fresh_state forward-dependency)"
jq '(.tasks[] | select(.id == "G0-01") | .blocked_by) = ["G0-02"]' \
  "$invalid_state" > "$test_directory/mutated.json"
mv "$test_directory/mutated.json" "$invalid_state"
if ROADMAP_STATE_FILE="$invalid_state" bash "$roadmap_command" validate 2>/dev/null; then
  fail "a forward dependency passed validation"
fi

invalid_state="$(fresh_state duplicate-id)"
jq '(.tasks[] | select(.id == "G0-02") | .id) = "G0-01"' \
  "$invalid_state" > "$test_directory/mutated.json"
mv "$test_directory/mutated.json" "$invalid_state"
if ROADMAP_STATE_FILE="$invalid_state" bash "$roadmap_command" validate 2>/dev/null; then
  fail "a duplicate task id passed validation"
fi

printf 'roadmap contract tests passed.\n'

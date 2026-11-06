#!/usr/bin/env bash
# test-roadmap: exercise the public roadmap state interface against isolated
# copies of the state file and an isolated OpenSpec changes directory.
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

# A fresh fixture: FOUND-01 and STATE-01 delivered by an archived change, every
# other task unlinked. Returns the fixture directory.
fresh_fixture() {
  local name="$1"
  local directory="$test_directory/$name"
  mkdir -p "$directory/changes/archive/2026-01-01-foundation"
  jq '
    .tasks |= map(
      if .id == "FOUND-01" or .id == "STATE-01" then .change = "foundation"
      else .change = null end
      | del(.cancelled))
  ' "$canonical_state" > "$directory/state.json"
  printf '%s\n' "$directory"
}

run() {
  local directory="$1"
  shift
  ROADMAP_STATE_FILE="$directory/state.json" ROADMAP_CHANGES_DIR="$directory/changes" \
    bash "$roadmap_command" "$@"
}

run_write() {
  local directory="$1"
  shift
  ROADMAP_ALLOW_WRITE=true run "$directory" "$@"
}

status_of() {
  run "$1" list | awk -F '\t' -v id="$2" '$2 == id { print $3 }'
}

mutate() {
  local directory="$1"
  local filter="$2"
  jq "$filter" "$directory/state.json" > "$directory/mutated.json"
  mv "$directory/mutated.json" "$directory/state.json"
}

expect_invalid() {
  local directory="$1"
  local message="$2"
  if run "$directory" validate 2>/dev/null; then
    fail "$message"
  fi
}

# Canonical state is valid against the real OpenSpec changes directory.
bash "$roadmap_command" validate

# Derived statuses: done, pending, blocked.
fixture="$(fresh_fixture derivation)"
run "$fixture" validate
[ "$(status_of "$fixture" FOUND-01)" = "done" ] || fail "an archived change should derive done"
[ "$(status_of "$fixture" G0-01)" = pending ] || fail "a ready unlinked task should derive pending"
[ "$(status_of "$fixture" G0-02)" = blocked ] || fail "a task with unfinished dependencies should derive blocked"
run "$fixture" next | jq -e '.id == "G0-01"' >/dev/null \
  || fail "G0-01 should be the first actionable task"

# Stored status fields from schema v1 are rejected.
fixture="$(fresh_fixture stored-status)"
mutate "$fixture" '(.tasks[] | select(.id == "G0-01")) += {status: "pending"}'
expect_invalid "$fixture" "a v2 task with a stored status passed validation"

fixture="$(fresh_fixture stored-current)"
mutate "$fixture" '.current_task_id = null'
expect_invalid "$fixture" "a v2 state with current_task_id passed validation"

fixture="$(fresh_fixture old-schema)"
mutate "$fixture" '.schema_version = 1'
expect_invalid "$fixture" "a schema v1 state passed v2 validation"

# Claim: write mode, change existence, lifecycle, single in-progress.
fixture="$(fresh_fixture claim)"
if run "$fixture" claim G0-01 define-trust-tiers 2>/dev/null; then
  fail "claim succeeded without ROADMAP_ALLOW_WRITE=true"
fi
if run_write "$fixture" claim G0-01 define-trust-tiers 2>/dev/null; then
  fail "claim succeeded before the change existed"
fi
mkdir -p "$fixture/changes/define-trust-tiers" "$fixture/changes/least-privilege"
if run_write "$fixture" claim G0-02 least-privilege 2>/dev/null; then
  fail "a dependency-blocked task was claimed"
fi
run_write "$fixture" claim G0-01 define-trust-tiers
[ "$(status_of "$fixture" G0-01)" = in_progress ] || fail "an active change should derive in_progress"
if run_write "$fixture" claim G0-01 least-privilege 2>/dev/null; then
  fail "an in-progress task was claimed again"
fi

# Archiving the change completes the task and unblocks dependants.
mv "$fixture/changes/define-trust-tiers" "$fixture/changes/archive/2026-02-01-define-trust-tiers"
[ "$(status_of "$fixture" G0-01)" = "done" ] || fail "archiving the change should derive done"
[ "$(status_of "$fixture" G0-02)" = pending ] || fail "completing a dependency should unblock its dependant"
run_write "$fixture" claim G0-02 least-privilege
mkdir -p "$fixture/changes/remove-lifecycle"
if run_write "$fixture" claim G0-03 remove-lifecycle 2>/dev/null; then
  fail "a second task was claimed while one was in progress"
fi

# Cancellation overrides every other derivation.
fixture="$(fresh_fixture cancelled)"
mutate "$fixture" '(.tasks[] | select(.id == "G0-02")) += {cancelled: true}'
[ "$(status_of "$fixture" G0-02)" = cancelled ] || fail "cancelled: true should derive cancelled"

# Invariants on derived status.
fixture="$(fresh_fixture two-active)"
mkdir -p "$fixture/changes/first" "$fixture/changes/second"
mutate "$fixture" '(.tasks[] | select(.id == "G0-01") | .change) = "first"
  | (.tasks[] | select(.id == "G0-02") | .change) = "second"'
expect_invalid "$fixture" "an in-progress task with unfinished dependencies passed validation"

fixture="$(fresh_fixture parallel-active)"
mkdir -p "$fixture/changes/first" "$fixture/changes/second"
mutate "$fixture" '(.tasks[] | select(.id == "G0-01") | .change) = "first"
  | (.tasks[] | select(.id == "G0-01") | .blocked_by) = []
  | (.tasks[] | select(.id == "STATE-01") | .change) = "second"'
expect_invalid "$fixture" "two in-progress tasks passed validation"

fixture="$(fresh_fixture done-on-unfinished)"
mkdir -p "$fixture/changes/archive/2026-03-01-early"
mutate "$fixture" '(.tasks[] | select(.id == "G0-02") | .change) = "early"'
expect_invalid "$fixture" "a done task depending on an unfinished task passed validation"

fixture="$(fresh_fixture missing-change)"
mutate "$fixture" '(.tasks[] | select(.id == "G0-01") | .change) = "no-such-change"'
expect_invalid "$fixture" "a link to a nonexistent change passed validation"

# The bootstrap migration exemption is gone: an active change with that name
# gets no special treatment.
fixture="$(fresh_fixture no-exemption)"
mkdir -p "$fixture/changes/bootstrap-security-gate-specs"
mutate "$fixture" '(.tasks[] | select(.id == "G0-01") | .change) = "foundation"
  | (.tasks[] | select(.id == "G0-02" or .id == "G0-03") | .change)
    = "bootstrap-security-gate-specs"'
expect_invalid "$fixture" "tasks linked to an active bootstrap change bypassed the single in-progress rule"

# Structural invariants.
fixture="$(fresh_fixture forward-dependency)"
mutate "$fixture" '(.tasks[] | select(.id == "G0-01") | .blocked_by) = ["G0-02"]'
expect_invalid "$fixture" "a forward dependency passed validation"

fixture="$(fresh_fixture duplicate-id)"
mutate "$fixture" '(.tasks[] | select(.id == "G0-02") | .id) = "G0-01"'
expect_invalid "$fixture" "a duplicate task id passed validation"

printf 'roadmap contract tests passed.\n'

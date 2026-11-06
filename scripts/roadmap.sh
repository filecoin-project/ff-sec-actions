#!/usr/bin/env bash
# roadmap: validate, query, and claim tasks in the machine-readable implementation queue.
#
# Task status is derived, never stored. Each task may link to an OpenSpec
# change; the change lifecycle decides the task's status:
#   cancelled: true                              -> cancelled
#   <changes>/archive/YYYY-MM-DD-<change>/       -> done
#   <changes>/<change>/                          -> in_progress
#   otherwise, any blocked_by dependency not done -> blocked
#   otherwise                                    -> pending
#
# Optional environment variables:
#   ROADMAP_STATE_FILE   Override the state file (defaults to roadmap/state.json).
#   ROADMAP_CHANGES_DIR  Override the OpenSpec changes directory
#                        (defaults to openspec/changes).
#   ROADMAP_ALLOW_WRITE  Set to "true" to permit claim mutations.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
state_file="${ROADMAP_STATE_FILE:-$repo_root/roadmap/state.json}"
changes_dir="${ROADMAP_CHANGES_DIR:-$repo_root/openspec/changes}"

# Migration exemption: tasks completed before OpenSpec link to the bootstrap
# change. Until it is archived they count as done for dependency checks and do
# not occupy the single in-progress slot. Remove after the bootstrap archive.
bootstrap_change="bootstrap-security-gate-specs"

fail() {
  printf 'roadmap error: %s\n' "$*" >&2
  exit 1
}

change_names() {
  local mode="$1"
  local directory
  local name

  {
    if [ "$mode" = active ]; then
      for directory in "$changes_dir"/*/; do
        [ -d "$directory" ] || continue
        name="$(basename "$directory")"
        [ "$name" = archive ] && continue
        printf '%s\n' "$name"
      done
    else
      for directory in "$changes_dir"/archive/*/; do
        [ -d "$directory" ] || continue
        name="$(basename "$directory")"
        [[ "$name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-(.+)$ ]] || continue
        printf '%s\n' "${BASH_REMATCH[1]}"
      done
    fi
  } | jq -R . | jq -s 'unique'
}

# Print the state document with a derived .status and .satisfied on each task.
derived_state() {
  local active archived
  active="$(change_names active)"
  archived="$(change_names archived)"

  jq --argjson active "$active" --argjson archived "$archived" \
    --arg bootstrap "$bootstrap_change" '
    def lifecycle:
      if .cancelled == true then "cancelled"
      elif .change != null and (.change | IN($archived[])) then "done"
      elif .change != null and (.change | IN($active[])) then "in_progress"
      else "unclaimed" end;
    def exempt: .change == $bootstrap and lifecycle == "in_progress";

    .tasks |= map(. + {lifecycle: lifecycle, exempt: exempt})
    | .tasks as $tasks
    | .tasks |= map(
        . as $task
        | ([$task.blocked_by[] as $dependency
            | any($tasks[]; .id == $dependency and (.lifecycle == "done" or .exempt))]
           | all) as $ready
        | .satisfied = (.lifecycle == "done" or .exempt)
        | .ready = $ready
        | .status = (if .lifecycle == "unclaimed"
            then (if $ready then "pending" else "blocked" end)
            else .lifecycle end)
        | del(.lifecycle))
  ' "$state_file"
}

validate() {
  local derived

  [ -f "$state_file" ] || fail "state file does not exist: $state_file"

  jq -e '
    .schema_version == 2
    and (.roadmap_id | type == "string" and length > 0)
    and (.goal | type == "string" and length > 0)
    and (.updated_at | type == "string" and length > 0)
    and (has("current_task_id") | not)
    and (.tasks | type == "array" and length > 0)
    and all(.tasks[];
      (.id | type == "string" and test("^[A-Z][A-Z0-9]*-[0-9]{2}$"))
      and (.order | type == "number")
      and (.phase | type == "string" and length > 0)
      and (.priority | IN("P0", "P1", "P2", "P3"))
      and (.kind | IN("decision", "implementation", "verification", "governance", "rollout"))
      and (has("status") | not)
      and (has("started_at") | not)
      and (has("completed_at") | not)
      and (.change == null or (.change | type == "string" and test("^[a-z0-9]+(-[a-z0-9]+)*$")))
      and ((has("cancelled") | not) or (.cancelled | type == "boolean"))
      and (.title | type == "string" and length > 0)
      and (.objective | type == "string" and length > 0)
      and (.blocked_by | type == "array")
      and (.decision_refs | type == "array")
      and (.acceptance_criteria | type == "array" and length > 0)
      and (.verification | type == "array" and length > 0)
      and (.artifacts | type == "array")
    )
  ' "$state_file" >/dev/null || fail "state file does not match the roadmap v2 contract"

  jq -e '
    .tasks as $tasks
    | ([.tasks[].id] | length == (unique | length))
      and ([.tasks[].order] | length == (unique | length))
      and all(.tasks | to_entries[]; .value.order == (.key + 1))
      and ([
        range(0; $tasks | length) as $index
        | $tasks[$index].blocked_by[] as $dependency
        | any($tasks[0:$index][]; .id == $dependency)
      ] | all)
  ' "$state_file" >/dev/null || fail "task ids/orders must be unique and dependencies must point backward"

  derived="$(derived_state)"

  jq -e --argjson active "$(change_names active)" --argjson archived "$(change_names archived)" '
    all(.tasks[] | select(.change != null and .cancelled != true);
      .change | IN($active[], $archived[]))
  ' <<< "$derived" >/dev/null || fail "a linked change does not exist under the OpenSpec changes directory"

  jq -e '
    [.tasks[] | select(.status == "in_progress" and (.exempt | not))] | length <= 1
  ' <<< "$derived" >/dev/null || fail "only one task may be in progress"

  jq -e '
    all(.tasks[] | select(.status == "in_progress" and (.exempt | not)); .ready)
  ' <<< "$derived" >/dev/null || fail "an in-progress task depends on unfinished tasks"

  jq -e '
    all(.tasks[] | select(.status == "done"); .ready)
  ' <<< "$derived" >/dev/null || fail "completed tasks cannot depend on incomplete tasks"
}

next_task() {
  validate
  derived_state | jq -c '
    first(.tasks[] | select(.status == "pending") | del(.satisfied, .ready, .exempt)) // null
  '
}

list_tasks() {
  local requested_status="${1:-}"
  validate
  derived_state | jq -r --arg status "$requested_status" '
    ["ORDER", "ID", "STATUS", "PRIORITY", "PHASE", "CHANGE", "TITLE"],
    (.tasks[]
      | select($status == "" or .status == $status)
      | [(.order | tostring), .id, .status, .priority, .phase, (.change // "-"), .title])
    | @tsv
  '
}

claim() {
  local task_id="${1:-}"
  local change="${2:-}"
  local derived
  local status
  local now
  local temporary_file

  [ "${ROADMAP_ALLOW_WRITE:-false}" = "true" ] \
    || fail "set ROADMAP_ALLOW_WRITE=true to mutate roadmap state"
  [ -n "$task_id" ] || fail "claim requires a task id"
  [ -n "$change" ] || fail "claim requires an OpenSpec change name"

  validate
  derived="$(derived_state)"
  jq -e --arg id "$task_id" 'any(.tasks[]; .id == $id)' <<< "$derived" >/dev/null \
    || fail "unknown task id: $task_id"

  status="$(jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .status' <<< "$derived")"
  case "$status" in
    pending) ;;
    blocked) fail "task $task_id depends on unfinished tasks" ;;
    *) fail "task $task_id is $status and cannot be claimed" ;;
  esac

  if [ "$change" = archive ] || [ ! -d "$changes_dir/$change" ]; then
    fail "create the change first: openspec new change \"$change\""
  fi
  jq -e '[.tasks[] | select(.status == "in_progress" and (.exempt | not))] | length == 0' \
    <<< "$derived" >/dev/null || fail "another task is already in progress"

  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  temporary_file="$(mktemp "${state_file}.tmp.XXXXXX")"
  trap 'rm -f "$temporary_file"' EXIT

  jq --arg id "$task_id" --arg change "$change" --arg now "$now" '
    .updated_at = $now
    | .tasks |= map(if .id == $id then .change = $change else . end)
  ' "$state_file" > "$temporary_file"

  chmod 0644 "$temporary_file"
  mv "$temporary_file" "$state_file"
  trap - EXIT
  validate
}

usage() {
  cat <<'EOF'
Usage: scripts/roadmap.sh COMMAND [ARGUMENTS]

Commands:
  validate                  Validate schema, change links, and derived-status invariants.
  list [STATUS]             List all tasks with derived status, optionally filtered.
  next                      Print the next actionable task as compact JSON.
  claim ID CHANGE           Link a pending task to an existing OpenSpec change
                            (requires ROADMAP_ALLOW_WRITE=true).
EOF
}

command="${1:-help}"
case "$command" in
  validate) validate ;;
  list) list_tasks "${2:-}" ;;
  next) next_task ;;
  claim) claim "${2:-}" "${3:-}" ;;
  help|-h|--help) usage ;;
  *) usage >&2; fail "unknown command: $command" ;;
esac

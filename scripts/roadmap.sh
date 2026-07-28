#!/usr/bin/env bash
# roadmap: validate, query, and update the machine-readable implementation queue.
#
# Optional environment variables:
#   ROADMAP_STATE_FILE  Override the state file (defaults to roadmap/state.json).
#   ROADMAP_ALLOW_WRITE Set to "true" to permit set-status mutations.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
state_file="${ROADMAP_STATE_FILE:-$repo_root/roadmap/state.json}"

fail() {
  printf 'roadmap error: %s\n' "$*" >&2
  exit 1
}

validate() {
  [ -f "$state_file" ] || fail "state file does not exist: $state_file"

  jq -e '
    .schema_version == 1
    and (.roadmap_id | type == "string" and length > 0)
    and (.goal | type == "string" and length > 0)
    and (.updated_at | type == "string" and length > 0)
    and (.current_task_id == null or (.current_task_id | type == "string"))
    and (.tasks | type == "array" and length > 0)
    and all(.tasks[];
      (.id | type == "string" and test("^[A-Z][A-Z0-9]*-[0-9]{2}$"))
      and (.order | type == "number")
      and (.phase | type == "string" and length > 0)
      and (.priority | IN("P0", "P1", "P2", "P3"))
      and (.kind | IN("decision", "implementation", "verification", "governance", "rollout"))
      and (.status | IN("pending", "in_progress", "blocked", "done", "cancelled"))
      and (.title | type == "string" and length > 0)
      and (.objective | type == "string" and length > 0)
      and (.blocked_by | type == "array")
      and (.decision_refs | type == "array")
      and (.acceptance_criteria | type == "array" and length > 0)
      and (.verification | type == "array" and length > 0)
      and (.artifacts | type == "array")
    )
  ' "$state_file" >/dev/null || fail "state file does not match the roadmap contract"

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

  jq -e '
    [.tasks[] | select(.status == "in_progress") | .id] as $active
    | if .current_task_id == null
      then ($active | length) == 0
      else ($active == [.current_task_id])
      end
  ' "$state_file" >/dev/null || fail "current_task_id must match the single in-progress task"

  jq -e '
    .tasks as $tasks
    | all(.tasks[] | select(.status == "done");
        . as $task
        | ([
            $task.blocked_by[] as $dependency
            | any($tasks[]; .id == $dependency and .status == "done")
          ] | all)
      )
  ' "$state_file" >/dev/null || fail "completed tasks cannot depend on incomplete tasks"
}

next_task() {
  validate
  jq -c '
    .tasks as $tasks
    | first(
        .tasks[]
        | select(.status == "pending")
        | . as $task
        | select([
            $task.blocked_by[] as $dependency
            | any($tasks[]; .id == $dependency and .status == "done")
          ] | all)
      ) // null
  ' "$state_file"
}

list_tasks() {
  local requested_status="${1:-}"
  validate
  jq -r --arg status "$requested_status" '
    ["ORDER", "ID", "STATUS", "PRIORITY", "PHASE", "TITLE"],
    (.tasks[]
      | select($status == "" or .status == $status)
      | [(.order | tostring), .id, .status, .priority, .phase, .title])
    | @tsv
  ' "$state_file"
}

set_status() {
  local task_id="${1:-}"
  local new_status="${2:-}"
  local old_status
  local now
  local temporary_file

  [ "${ROADMAP_ALLOW_WRITE:-false}" = "true" ] \
    || fail "set ROADMAP_ALLOW_WRITE=true to mutate roadmap state"
  [ -n "$task_id" ] || fail "set-status requires a task id"
  case "$new_status" in
    pending|in_progress|blocked|done|cancelled) ;;
    *) fail "invalid status: $new_status" ;;
  esac

  validate
  jq -e --arg id "$task_id" 'any(.tasks[]; .id == $id)' "$state_file" >/dev/null \
    || fail "unknown task id: $task_id"

  old_status="$(jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .status' "$state_file")"
  case "${old_status}:${new_status}" in
    pending:in_progress|pending:blocked|pending:cancelled|\
    in_progress:pending|in_progress:blocked|in_progress:done|in_progress:cancelled|\
    blocked:pending|blocked:in_progress|blocked:cancelled|\
    done:pending|cancelled:pending|\
    pending:pending|in_progress:in_progress|blocked:blocked|done:done|cancelled:cancelled) ;;
    *) fail "invalid task transition: ${old_status} -> ${new_status}" ;;
  esac

  if [ "$new_status" = "in_progress" ]; then
    jq -e --arg id "$task_id" '
      .tasks as $tasks
      | (.current_task_id == null or .current_task_id == $id)
        and ([
          .tasks[] | select(.id == $id) | .blocked_by[] as $dependency
          | any($tasks[]; .id == $dependency and .status == "done")
        ] | all)
    ' "$state_file" >/dev/null \
      || fail "task is blocked or another task is already in progress"
  fi

  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  temporary_file="$(mktemp "${state_file}.tmp.XXXXXX")"
  trap 'rm -f "$temporary_file"' EXIT

  jq --arg id "$task_id" --arg status "$new_status" --arg now "$now" '
    .updated_at = $now
    | .current_task_id = (if $status == "in_progress" then $id
        elif .current_task_id == $id then null else .current_task_id end)
    | .tasks |= map(
        if .id != $id then .
        else .status = $status
          | if $status == "in_progress" and .started_at == null
            then .started_at = $now else . end
          | if $status == "done" then .completed_at = $now
            elif $status != "done" then .completed_at = null else . end
        end)
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
  validate                  Validate schema and dependency/status invariants.
  list [STATUS]             List all tasks, optionally filtered by status.
  next                      Print the next actionable task as compact JSON.
  set-status ID STATUS      Update a task (requires ROADMAP_ALLOW_WRITE=true).
EOF
}

command="${1:-help}"
case "$command" in
  validate) validate ;;
  list) list_tasks "${2:-}" ;;
  next) next_task ;;
  set-status) set_status "${2:-}" "${3:-}" ;;
  help|-h|--help) usage ;;
  *) usage >&2; fail "unknown command: $command" ;;
esac

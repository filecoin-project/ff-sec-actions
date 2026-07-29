#!/usr/bin/env bash
# check-evaluation-result: dependency-free validation for the pre-v1 JSON contract.
set -euo pipefail

if [ "$#" -eq 0 ]; then
  printf 'usage: %s RESULT.json [RESULT.json ...]\n' "$0" >&2
  exit 2
fi

for result_file in "$@"; do
  jq -e '
    .schema_version == "0.1.0"
    and (.evaluation.id | type == "string" and length > 0)
    and (.evaluation.kind | IN("scanner", "ai-review"))
    and (.tool.name | type == "string" and length > 0)
    and (.tool.version == null or (.tool.version | type == "string"))
    and (.scope.repository == null or (.scope.repository | type == "string"))
    and (.scope.ref == null or (.scope.ref | type == "string"))
    and (.scope.target | type == "string" and length > 0)
    and (.completion.status | IN("complete", "incomplete", "skipped", "error"))
    and (.completion.reason | type == "string" and length > 0)
    and (.coverage.status | IN("complete", "partial", "not-applicable", "unknown"))
    and (.coverage.included | type == "array" and all(.[]; type == "string"))
    and (.coverage.excluded | type == "array" and all(.[]; type == "string"))
    and (.findings.count == null or (.findings.count | type == "number" and floor == . and . >= 0))
    and (.findings.highest_severity | IN("critical", "high", "medium", "low", "info", "none", "unknown"))
    and (.suppressions.count == null or (.suppressions.count | type == "number" and floor == . and . >= 0))
    and (.timing.started_at == null or (.timing.started_at | type == "string"))
    and (.timing.completed_at == null or (.timing.completed_at | type == "string"))
    and (.timing.duration_ms == null or (.timing.duration_ms | type == "number" and floor == . and . >= 0))
    and (.evidence | type == "array")
    and all(.evidence[];
      (.type | IN("sarif", "json", "log", "none"))
      and (.path == null or (.path | type == "string"))
      and (.sha256 == null or (.sha256 | type == "string" and test("^[a-f0-9]{64}$")))
    )
    and (if .completion.status == "complete" then (.findings.count | type == "number") else true end)
  ' "$result_file" >/dev/null \
    || { printf 'evaluation-result error: invalid contract: %s\n' "$result_file" >&2; exit 1; }
done

printf 'evaluation-result contract valid for %s file(s).\n' "$#"

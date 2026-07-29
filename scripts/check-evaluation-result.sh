#!/usr/bin/env bash
# check-evaluation-result: dependency-free validation for the v1 JSON contract.
set -euo pipefail

if [ "$#" -eq 0 ]; then
  printf 'usage: %s RESULT.json [RESULT.json ...]\n' "$0" >&2
  exit 2
fi

for result_file in "$@"; do
  jq -e '
    def exact($allowed): ((keys_unsorted - $allowed) | length) == 0;
    .schema_version as $result_version |
    (type == "object" and exact([
      "schema_version", "evaluation", "tool", "scope", "completion", "coverage",
      "findings", "suppressions", "merge_gate", "timing", "evidence"
    ]))
    and (.schema_version | IN("1.0.0", "1.1.0"))
    and (.evaluation | type == "object" and exact(["id", "kind"]))
    and (.evaluation.id | type == "string" and length > 0)
    and (.evaluation.kind | IN("scanner", "ai-review"))
    and (.tool | type == "object" and exact(["name", "version"]))
    and (.tool.name | type == "string" and length > 0)
    and (.tool.version == null or (.tool.version | type == "string" and length > 0))
    and (.scope | type == "object" and exact(["repository", "ref", "target"]))
    and (.scope.repository == null or (.scope.repository | type == "string"))
    and (.scope.ref == null or (.scope.ref | type == "string"))
    and (.scope.target | type == "string" and length > 0)
    and (.completion | type == "object" and exact(["status", "reason"]))
    and (.completion.status | IN("complete", "incomplete", "skipped", "error"))
    and (.completion.reason | type == "string" and length > 0)
    and (.coverage | type == "object" and exact(["status", "included", "excluded", "limitations"]))
    and (.coverage.status | IN("complete", "partial", "not-applicable", "unknown"))
    and (.coverage.included | type == "array" and all(.[]; type == "string"))
    and (.coverage.excluded | type == "array" and all(.[]; type == "string"))
    and (.coverage.limitations | type == "array" and all(.[]; type == "string" and length > 0))
    and (.findings | type == "object" and exact(["count", "highest_severity"]))
    and (.findings.count == null or (.findings.count | type == "number" and floor == . and . >= 0))
    and (.findings.highest_severity | IN("critical", "high", "medium", "low", "info", "none", "unknown"))
    and (.suppressions | type == "object" and exact(["count", "sources"]))
    and (.suppressions.count == null or (.suppressions.count | type == "number" and floor == . and . >= 0))
    and (.suppressions.sources | type == "array" and all(.[]; type == "string" and length > 0))
    and (.merge_gate | type == "object" and exact(["mode", "conclusion", "reason"]))
    and (.merge_gate.mode | IN("advisory", "blocking"))
    and (.merge_gate.conclusion | IN("pass", "fail", "not-evaluated"))
    and (.merge_gate.reason | type == "string" and length > 0)
    and (.timing | type == "object" and exact(["started_at", "completed_at", "duration_ms"]))
    and (.timing.started_at == null or (.timing.started_at | type == "string"))
    and (.timing.completed_at == null or (.timing.completed_at | type == "string"))
    and (.timing.duration_ms == null or (.timing.duration_ms | type == "number" and floor == . and . >= 0))
    and (.evidence | type == "array" and length > 0)
    and all(.evidence[];
      (type == "object"
        and (if $result_version == "1.0.0"
          then exact(["type", "path", "sha256"])
          else exact(["type", "path", "sha256", "artifact"]) and has("artifact") end))
      and (.type | IN("sarif", "json", "log", "none"))
      and (.path == null or (.path | type == "string"))
      and (.sha256 == null or (.sha256 | type == "string" and test("^[a-f0-9]{64}$")))
      and (if $result_version == "1.1.0"
        then (.artifact == null or (.artifact | type == "string" and length > 0))
        else true end)
      and (if .type == "none"
        then .path == null and .sha256 == null
        else (.path | type == "string" and length > 0)
          and (.sha256 | type == "string" and test("^[a-f0-9]{64}$"))
        end)
    )
    and (if .completion.status == "complete"
      then (.findings.count | type == "number") and (.merge_gate.conclusion != "not-evaluated")
      elif .completion.status == "skipped"
      then .findings.count == null and .findings.highest_severity == "unknown"
        and .merge_gate.conclusion == "not-evaluated"
      elif .completion.status == "error"
      then .merge_gate.conclusion == "fail"
      else true end)
    and (if .findings.count == null then .findings.highest_severity == "unknown"
      elif .findings.count == 0 then .findings.highest_severity == "none"
      else .findings.highest_severity != "none" end)
  ' "$result_file" >/dev/null \
    || { printf 'evaluation-result error: invalid contract: %s\n' "$result_file" >&2; exit 1; }
done

printf 'evaluation-result contract valid for %s file(s).\n' "$#"

#!/usr/bin/env bash
# AI code review: PR diff -> Claude API (structured findings) -> sticky PR comment.
# Operates on the diff via the GitHub API only; never checks out or executes PR code.
set -euo pipefail

MODEL="${MODEL:-claude-opus-4-8}"
EFFORT="${EFFORT:-high}"
MAX_TOKENS="${MAX_TOKENS:-16000}"
MAX_DIFF_BYTES="${MAX_DIFF_BYTES:-400000}"
FAIL_ON_SEVERITY="${FAIL_ON_SEVERITY:-none}"
POST_COMMENT="${POST_COMMENT:-true}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/null}"
GITHUB_STEP_SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"
MARKER="<!-- ff-sec-action:ai-code-review -->"
EVALUATION_RESULT_FILE="${EVALUATION_RESULT_FILE:-${RUNNER_TEMP:-$PWD}/ai-code-review-evaluation-result.json}"
evaluation_emitted=false

DEFAULT_EXCLUDE_RE='(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock|go\.sum|flake\.lock|poetry\.lock|Gemfile\.lock)$|(^|/)(vendor|node_modules|dist|build|target)/|\.min\.(js|css)$|\.(svg|png|jpe?g|gif|ico|woff2?|ttf|pdf|lock)$|\.pb\.(go|rs)$|_generated\.|\.gen\.(go|rs|ts)$'
EXCLUDE_RE="${EXCLUDE_RE:-$DEFAULT_EXCLUDE_RE}"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

set_output() { printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"; }

emit_evaluation() {
  local completion="$1"
  local reason="$2"
  local findings_count="$3"
  local highest_severity="$4"
  local coverage_status="$5"
  local evidence_type="$6"
  local evidence_path="$7"
  local evidence_sha=null
  local repository=null
  local ref=null
  local gate_mode=advisory
  local gate_conclusion=not-evaluated
  local gate_reason="$reason"
  local severity_rank=0
  local threshold_rank=0

  if [ "$FAIL_ON_SEVERITY" != none ]; then
    gate_mode=blocking
  fi
  if [ "$completion" = error ]; then
    gate_conclusion=fail
  elif [ "$completion" = complete ]; then
    gate_conclusion=pass
  fi
  if [ "$gate_mode" = blocking ] && [ "$findings_count" != null ]; then
    severity_rank="$(case "$highest_severity" in critical) printf 5 ;; high) printf 4 ;; medium) printf 3 ;; low) printf 2 ;; info) printf 1 ;; *) printf 0 ;; esac)"
    threshold_rank="$(case "$FAIL_ON_SEVERITY" in critical) printf 5 ;; high) printf 4 ;; medium) printf 3 ;; low) printf 2 ;; info) printf 1 ;; *) printf 0 ;; esac)"
    if [ "$severity_rank" -ge "$threshold_rank" ]; then
      gate_conclusion=fail
      gate_reason="findings met the configured severity threshold"
    fi
  fi

  if [ -n "$evidence_path" ] && [ -s "$evidence_path" ]; then
    evidence_sha="$(shasum -a 256 "$evidence_path" | awk '{print $1}')"
  fi
  if [ -n "${REPO:-}" ]; then
    repository="$(jq -Rn --arg value "$REPO" '$value')"
  fi
  if [ -n "${GITHUB_SHA:-}" ]; then
    ref="$(jq -Rn --arg value "$GITHUB_SHA" '$value')"
  fi

  mkdir -p "$(dirname "$EVALUATION_RESULT_FILE")"
  jq -n \
    --arg model "$MODEL" \
    --argjson repository "$repository" \
    --argjson ref "$ref" \
    --arg target "pull-request:${PR_NUMBER:-unknown}" \
    --arg completion "$completion" \
    --arg reason "$reason" \
    --arg coverage_status "$coverage_status" \
    --argjson findings_count "$findings_count" \
    --arg highest_severity "$highest_severity" \
    --arg evidence_type "$evidence_type" \
    --arg evidence_path "$evidence_path" \
    --arg gate_mode "$gate_mode" \
    --arg gate_conclusion "$gate_conclusion" \
    --arg gate_reason "$gate_reason" \
    --argjson evidence_sha "$(if [ "$evidence_sha" = null ]; then printf null; else jq -Rn --arg value "$evidence_sha" '$value'; fi)" \
    '{
      schema_version: "1.0.0",
      evaluation: {id: "ai-code-review", kind: "ai-review"},
      tool: {name: "anthropic-claude", version: $model},
      scope: {repository: $repository, ref: $ref, target: $target},
      completion: {status: $completion, reason: $reason},
      coverage: {
        status: $coverage_status,
        included: ["reviewable pull-request diff"],
        excluded: (if $coverage_status == "partial" then ["diff content beyond configured or model limit"] else [] end),
        limitations: ["diff-only review does not establish repository-wide behavior"]
      },
      findings: {count: $findings_count, highest_severity: $highest_severity},
      suppressions: {count: null, sources: []},
      merge_gate: {mode: $gate_mode, conclusion: $gate_conclusion, reason: $gate_reason},
      timing: {started_at: null, completed_at: (now | todateiso8601), duration_ms: null},
      evidence: [
        if $evidence_sha == null
        then {type: "none", path: null, sha256: null}
        else {type: $evidence_type, path: $evidence_path, sha256: $evidence_sha}
        end
      ]
    }' > "$EVALUATION_RESULT_FILE"

  set_output completion_status "$completion"
  set_output evaluation_result "$EVALUATION_RESULT_FILE"
  evaluation_emitted=true
}

on_error() {
  local exit_code="$?"
  trap - ERR
  set +e
  if [ "$evaluation_emitted" != "true" ]; then
    emit_evaluation error "AI review terminated before producing a valid result" null unknown unknown none ""
  fi
  exit "$exit_code"
}
trap on_error ERR

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "::warning::ANTHROPIC_API_KEY is unavailable; AI review was skipped."
  set_output findings_count ""
  set_output highest_severity unknown
  set_output findings_json ""
  emit_evaluation skipped "required Anthropic API secret is unavailable" null unknown not-applicable none ""
  exit 0
fi

for variable in GH_TOKEN PR_NUMBER REPO PROMPT_FILE BASE_PROMPT_FILE SCHEMA_FILE; do
  if [ -z "${!variable:-}" ]; then
    echo "::error::${variable} is required."
    emit_evaluation error "required input ${variable} is unavailable" null unknown unknown none ""
    exit 1
  fi
done

for f in "$PROMPT_FILE" "$BASE_PROMPT_FILE" "$SCHEMA_FILE"; do
  if [ ! -f "$f" ]; then
    echo "::error::Missing required file: $f"
    emit_evaluation error "required review asset is unavailable" null unknown unknown none ""
    exit 1
  fi
done

# --- 1. Fetch PR metadata and diff ------------------------------------------
gh pr view "$PR_NUMBER" --repo "$REPO" --json title,body,author,baseRefName \
  > "$workdir/pr.json"
gh pr diff "$PR_NUMBER" --repo "$REPO" > "$workdir/full.patch"

# --- 2. Strip excluded paths, then truncate to the size budget ---------------
# EXCLUDE_RE is read via ENVIRON: awk -v would reprocess backslash escapes in the regex.
EXCLUDE_RE="$EXCLUDE_RE" awk '
  /^diff --git / {
    path = $3; sub(/^a\//, "", path)
    keep = (path !~ ENVIRON["EXCLUDE_RE"])
  }
  keep { print }
' "$workdir/full.patch" > "$workdir/filtered.patch"

if [ ! -s "$workdir/filtered.patch" ]; then
  echo "No reviewable changes after filtering (lockfiles/vendored/generated only)."
  set_output findings_count 0
  set_output highest_severity none
  set_output findings_json ""
  emit_evaluation complete "no reviewable changes remained after filtering" 0 none not-applicable none ""
  echo "AI code review: no reviewable changes after filtering." >> "$GITHUB_STEP_SUMMARY"
  exit 0
fi

truncated=false
if [ "$(wc -c < "$workdir/filtered.patch")" -gt "$MAX_DIFF_BYTES" ]; then
  head -c "$MAX_DIFF_BYTES" "$workdir/filtered.patch" > "$workdir/diff.patch"
  truncated=true
else
  cp "$workdir/filtered.patch" "$workdir/diff.patch"
fi

# --- 3. Build the API request -------------------------------------------------
jq -n \
  --arg model "$MODEL" \
  --arg effort "$EFFORT" \
  --argjson max_tokens "$MAX_TOKENS" \
  --rawfile base "$BASE_PROMPT_FILE" \
  --rawfile domain "$PROMPT_FILE" \
  --rawfile diff "$workdir/diff.patch" \
  --slurpfile schema "$SCHEMA_FILE" \
  --slurpfile pr "$workdir/pr.json" \
  --arg repo "$REPO" \
  --arg pr_number "$PR_NUMBER" \
  --arg truncated "$truncated" \
  '{
    model: $model,
    max_tokens: $max_tokens,
    thinking: { type: "adaptive" },
    output_config: {
      effort: $effort,
      format: { type: "json_schema", schema: $schema[0] }
    },
    system: [
      { type: "text", text: $base },
      { type: "text", text: $domain, cache_control: { type: "ephemeral" } }
    ],
    messages: [
      { role: "user",
        content: ("Repository: " + $repo
          + "\nPull request: #" + $pr_number + " — " + $pr[0].title
          + "\nAuthor: " + ($pr[0].author.login // "unknown")
          + "\nTarget branch: " + $pr[0].baseRefName
          + "\n\nPR description:\n" + (if ($pr[0].body // "") == "" then "(none)" else $pr[0].body end)
          + (if $truncated == "true"
             then "\n\nNOTE: the diff below was truncated to fit a size budget; review what is present and add an info-level finding noting the truncation."
             else "" end)
          + "\n\n--- BEGIN UNIFIED DIFF ---\n" + $diff + "\n--- END UNIFIED DIFF ---")
      }
    ]
  }' > "$workdir/request.json"

# --- 4. Call the Claude API with retries on transient errors -----------------
http_code=0
for attempt in 1 2 3; do
  http_code=$(curl -sS -o "$workdir/response.json" -w '%{http_code}' \
    --max-time 900 \
    https://api.anthropic.com/v1/messages \
    -H "x-api-key: ${ANTHROPIC_API_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    --data-binary "@$workdir/request.json") || http_code=000
  case "$http_code" in
    200) break ;;
    429|500|502|503|529|000)
      echo "Attempt ${attempt}: HTTP ${http_code}, retrying..."
      sleep $((attempt * 20)) ;;
    *)
      echo "::error::Claude API returned HTTP ${http_code}: $(jq -r '.error.message // "unknown error"' "$workdir/response.json" 2>/dev/null)"
      emit_evaluation error "Anthropic API returned HTTP ${http_code}" null unknown unknown log "$workdir/response.json"
      exit 1 ;;
  esac
done
if [ "$http_code" != "200" ]; then
  echo "::error::Claude API unavailable after 3 attempts (last HTTP ${http_code})."
  emit_evaluation error "Anthropic API unavailable after retries" null unknown unknown log "$workdir/response.json"
  exit 1
fi

stop_reason=$(jq -r '.stop_reason // "unknown"' "$workdir/response.json")
if [ "$stop_reason" = "refusal" ]; then
  echo "::warning::Model declined to review this diff (stop_reason=refusal). Skipping without failing the build."
  echo "AI code review: model declined this diff; no review posted." >> "$GITHUB_STEP_SUMMARY"
  set_output findings_count ""
  set_output highest_severity unknown
  set_output findings_json ""
  emit_evaluation incomplete "model refused the review" null unknown unknown log "$workdir/response.json"
  exit 0
fi
if [ "$stop_reason" = "max_tokens" ]; then
  echo "::warning::Response hit the max_tokens limit; findings may be incomplete. Consider raising max-tokens."
fi

# --- 5. Extract and validate the structured findings --------------------------
jq -r '[.content[] | select(.type == "text")][0].text' "$workdir/response.json" \
  > "$workdir/findings.raw"
jq -e '.summary and (.findings | type == "array")' "$workdir/findings.raw" > /dev/null \
  || {
    echo "::error::Model output did not match the findings schema."
    emit_evaluation error "model output failed structured-result validation" null unknown unknown log "$workdir/response.json"
    exit 1
  }

findings_json="${RUNNER_TEMP:-$PWD}/ai-review-findings.json"
jq '.' "$workdir/findings.raw" > "$findings_json"

findings_count=$(jq '.findings | length' "$findings_json")
highest_severity=$(jq -r '
  def rank: {"critical":5,"high":4,"medium":3,"low":2,"info":1}[.] // 0;
  [.findings[].severity] | if length == 0 then "none"
  else max_by(rank) end' "$findings_json")

set_output findings_count "$findings_count"
set_output highest_severity "$highest_severity"
set_output findings_json "$findings_json"

completion_status=complete
completion_reason="model returned a validated review"
coverage_status=complete
if [ "$truncated" = "true" ]; then
  completion_status=incomplete
  completion_reason="pull-request diff exceeded max-diff-bytes"
  coverage_status=partial
elif [ "$stop_reason" = "max_tokens" ]; then
  completion_status=incomplete
  completion_reason="model response reached max-tokens"
  coverage_status=partial
fi
emit_evaluation "$completion_status" "$completion_reason" "$findings_count" "$highest_severity" "$coverage_status" json "$findings_json"

# --- 6. Render the review comment ---------------------------------------------
jq -r \
  --arg marker "$MARKER" \
  --arg model "$MODEL" \
  --arg truncated "$truncated" \
  '
  def rank: {"critical":5,"high":4,"medium":3,"low":2,"info":1}[.] // 0;
  def badge: {"critical":"🟥 CRITICAL","high":"🟧 HIGH","medium":"🟨 MEDIUM","low":"🟦 LOW","info":"⬜ INFO"}[.];
  $marker + "\n## 🤖 AI Code Review\n\n"
  + "**Overall risk:** " + (.risk_level | ascii_upcase)
  + " · **Findings:** " + (.findings | length | tostring)
  + " · Model: `" + $model + "`"
  + (if $truncated == "true" then " · ⚠️ diff truncated" else "" end)
  + "\n\n" + .summary + "\n"
  + (if (.findings | length) == 0
     then "\n✅ No issues found.\n"
     else "\n---\n"
       + ([ .findings | sort_by(-(.severity | rank))[] |
           "\n### " + (.severity | badge) + " — " + .title + "\n"
           + "`" + .file + "` (" + .location + ") · " + .category
           + " · confidence: " + .confidence + "\n\n"
           + .description + "\n\n"
           + "**Recommendation:** " + .recommendation + "\n"
         ] | join(""))
     end)
  + (if (.positive_observations | length) > 0
     then "\n---\n**Done well:** " + (.positive_observations | join(" · ")) + "\n"
     else "" end)
  + "\n<sub>Generated by ff-sec-action/ai-code-review. Findings are advisory — verify before acting.</sub>"
  ' "$findings_json" > "$workdir/comment.md"

cat "$workdir/comment.md" >> "$GITHUB_STEP_SUMMARY"

# --- 7. Post or update the sticky PR comment ----------------------------------
if [ "$POST_COMMENT" = "true" ]; then
  existing_id=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" --paginate \
    --jq ".[] | select(.body | startswith(\"${MARKER}\")) | .id" | head -n1 || true)
  if [ -n "$existing_id" ]; then
    gh api --method PATCH "repos/${REPO}/issues/comments/${existing_id}" \
      -F "body=@$workdir/comment.md" > /dev/null
    echo "Updated existing review comment (id ${existing_id})."
  else
    gh pr comment "$PR_NUMBER" --repo "$REPO" --body-file "$workdir/comment.md"
    echo "Posted new review comment."
  fi
fi

# --- 8. Enforce the severity gate ----------------------------------------------
if [ "$FAIL_ON_SEVERITY" != "none" ]; then
  hit=$(jq -r --arg threshold "$FAIL_ON_SEVERITY" '
    def rank: {"critical":5,"high":4,"medium":3,"low":2,"info":1}[.] // 0;
    [.findings[] | select((.severity | rank) >= ($threshold | rank))] | length
  ' "$findings_json")
  if [ "$hit" -gt 0 ]; then
    echo "::error::${hit} finding(s) at or above '${FAIL_ON_SEVERITY}' severity."
    exit 1
  fi
fi

echo "Review complete: ${findings_count} finding(s), highest severity: ${highest_severity}."

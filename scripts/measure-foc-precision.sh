#!/usr/bin/env bash
# Measure FOC integrator pack noise against the FilOzone reference corpus.
#
# Maintainer-only: this script clones public repositories over the network and
# is never run in CI. It scans each repository at a pinned commit with the
# digest-pinned Semgrep image and rewrites rules/foc-integrator-precision.json.
# New findings are recorded with triage "unreviewed"; a maintainer then sets
# each to "true-positive" or "false-positive" with a note. Triage of a finding
# that is still reported (same rule, repository, commit, path, and line) is kept
# across runs. scripts/test-foc-integrator.sh rejects unreviewed entries.
#
# Required: docker, git, jq.
# Optional environment:
#   FOC_PRECISION_RECORD overrides the record path.
#   TMPDIR controls where repositories are cloned.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rules="$repo_root/rules/foc-integrator.yml"
record="${FOC_PRECISION_RECORD:-$repo_root/rules/foc-integrator-precision.json}"
semgrep_image="semgrep/semgrep:1.93.0@sha256:f35c7891e2030110a84a721fdd556ce8f3da6e7e69d7fab1d3660ae1bb334474"

# Reference corpus: audited FilOzone repositories at pinned commits.
corpus=(
  "FilOzone/filecoin-services 32a43799a8e4fd33799fff436ab181da9a043674"
  "FilOzone/pdp 3d486ae9ef6a5040acd55a0430307aa2802103c5"
  "FilOzone/filecoin-pay 04ded6af6c15c4b5d98545f393dc656004d4aede"
  "FilOzone/synapse-sdk c93782351b4bdc5be4f1308bba06e26407d6946f"
)

fail() { printf 'measure-foc-precision error: %s\n' "$*" >&2; exit 1; }
for tool in docker git jq; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is required"
done

work="$(mktemp -d "${TMPDIR:-/tmp}/ff-sec-foc-precision.XXXXXX")"
trap 'rm -rf "$work"' EXIT
cp "$rules" "$work/foc-integrator.yml"
: > "$work/findings.ndjson"
: > "$work/corpus.ndjson"

for entry in "${corpus[@]}"; do
  read -r repository commit <<< "$entry"
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || fail "corpus commit is not a full SHA: $entry"
  checkout="$work/repositories/${repository//\//__}"
  mkdir -p "$checkout"
  git -C "$checkout" init -q
  git -C "$checkout" -c core.hooksPath=/dev/null fetch -q --depth 1 \
    "https://github.com/${repository}.git" "$commit"
  git -C "$checkout" -c core.hooksPath=/dev/null -c advice.detachedHead=false checkout -q FETCH_HEAD
  [ "$(git -C "$checkout" rev-parse HEAD)" = "$commit" ] || fail "$repository did not check out $commit"

  docker run --rm --volume "$work:$work" --workdir "$checkout" "$semgrep_image" \
    semgrep scan --metrics=off --disable-version-check \
      --config "$work/foc-integrator.yml" --json --output "$work/result.json" . >/dev/null 2>&1 \
    || fail "Semgrep failed on $repository"
  # Partial parsing (newer syntax the pinned grammar does not support) is
  # recorded as reduced coverage; any other error fails the measurement.
  jq -e 'all(.errors[]; .level == "warn")' "$work/result.json" >/dev/null \
    || fail "Semgrep reported errors on $repository: $(jq -c '[.errors[] | select(.level != "warn") | .message]' "$work/result.json")"

  jq -cn --arg repository "$repository" --arg commit "$commit" \
    --argjson scanned "$(jq '.paths.scanned | length' "$work/result.json")" \
    --argjson partial "$(jq '[.errors[] | select(.level == "warn") | .path] | unique' "$work/result.json")" \
    '{repository: $repository, commit: $commit, files_scanned: $scanned, partially_parsed: $partial}' \
    >> "$work/corpus.ndjson"
  jq -c --arg repository "$repository" --arg commit "$commit" '
    .results[]
    | {
        rule: (.check_id | sub("^.*?foc\\."; "foc.")),
        repository: $repository,
        commit: $commit,
        path: .path,
        line: .start.line,
        code: (.extra.lines | split("\n")[0] | gsub("^\\s+|\\s+$"; "") | .[0:160])
      }' "$work/result.json" >> "$work/findings.ndjson"
done

previous='{}'
[ -f "$record" ] && previous="$(cat "$record")"
mapfile -t rule_ids < <(sed -n 's/^  - id: \(foc\.[a-z0-9.-]*\)$/\1/p' "$rules")

jq -n \
  --argjson previous "$previous" \
  --slurpfile corpus "$work/corpus.ndjson" \
  --slurpfile findings "$work/findings.ndjson" \
  --args '
    def key: [.rule, .repository, .commit, .path, .line] | tostring;
    ([$previous.rules // {} | to_entries[] | .key as $rule | .value.findings[]?
        | . + {rule: $rule} | {key: key, value: {triage, note}}] | from_entries) as $triaged
    | {
        schema_version: 1,
        ruleset: "rules/foc-integrator.yml",
        scanner: "semgrep 1.93.0",
        corpus: $corpus,
        rules: (
          [$ARGS.positional[] as $rule
            | ($findings | map(select(.rule == $rule))) as $matches
            | {
                key: $rule,
                value: {
                  count: ($matches | length),
                  findings: [$matches[]
                    | key as $key
                    | {repository, commit, path, line, code}
                      + ($triaged[$key] // {triage: "unreviewed", note: ""})]
                }
              }]
          | from_entries)
      }
  ' "${rule_ids[@]}" > "$record.tmp"
mv "$record.tmp" "$record"

printf 'Recorded %s findings across %s repositories in %s.\n' \
  "$(jq '[.rules[].count] | add' "$record")" "${#corpus[@]}" "${record#"$repo_root/"}"
jq -r '.rules | to_entries[] | "  \(.key): \(.value.count)"' "$record"
unreviewed="$(jq '[.rules[].findings[] | select(.triage == "unreviewed")] | length' "$record")"
[ "$unreviewed" -eq 0 ] || printf 'Triage %s unreviewed findings before committing the record.\n' "$unreviewed"

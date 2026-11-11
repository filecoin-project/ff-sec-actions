#!/usr/bin/env bash
# Prove the FOC integrator pack against paired fixtures without executing
# Consumer Project code.
# Required environment: a `semgrep` executable on PATH (G0 supplies a wrapper
#   around the digest-pinned semgrep/semgrep image).
# Optional environment:
#   TMPDIR controls where fixture copies are made. The copy keeps the scan
#   outside any test/ directory that Semgrep ignores by default; in CI it must
#   be inside the directory the Semgrep wrapper mounts.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rules="$repo_root/rules/foc-integrator.yml"
fixture="$repo_root/test/fixtures/foc-integrator"
baseline_fixture="$repo_root/test/fixtures/ecosystem-baseline/monorepo"
precision="${FOC_PRECISION_RECORD:-$repo_root/rules/foc-integrator-precision.json}"

fail() { printf 'foc-integrator test failure: %s\n' "$*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v semgrep >/dev/null 2>&1 || fail "semgrep is required on PATH"
[ -f "$rules" ] || fail "rules file is missing: $rules"

mapfile -t rule_ids < <(sed -n 's/^  - id: \(foc\.[a-z0-9.-]*\)$/\1/p' "$rules")
[ "${#rule_ids[@]}" -gt 0 ] || fail "no foc.* rules found in $rules"

work="$(mktemp -d "${TMPDIR:-/tmp}/ff-sec-foc-integrator.XXXXXX")"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/rules" "$work/fixture" "$work/baseline"
cp "$rules" "$work/rules/foc-integrator.yml"
cp -R "$fixture/." "$work/fixture/"
cp -R "$baseline_fixture/." "$work/baseline/"

scan() {
  # scan <output> <target-directory>
  semgrep scan --metrics=off --disable-version-check --strict \
    --config "$work/rules/foc-integrator.yml" --json --output "$1" "$2"
}

# Every rule has a triaged precision measurement against the reference corpus
# (written by scripts/measure-foc-precision.sh). This needs no scanner.
[ -f "$precision" ] || fail "precision record is missing: $precision"
jq -e '
  .schema_version == 1
  and (.corpus | type == "array" and length > 0)
  and all(.corpus[]; (.repository | type == "string" and length > 0) and (.commit | test("^[0-9a-f]{40}$")))
' "$precision" >/dev/null || fail "precision record does not name a corpus at full commit SHAs"
for id in "${rule_ids[@]}"; do
  jq -e --arg id "$id" '
    (.corpus | map(.repository + "@" + .commit)) as $scanned
    | .rules[$id] as $rule
    | $rule != null
    and ($rule.count == ($rule.findings | length))
    and all($rule.findings[];
      ((.repository + "@" + .commit) | IN($scanned[]))
      and (.triage | IN("true-positive", "false-positive"))
      and (.note | type == "string" and length > 0))
  ' "$precision" >/dev/null \
    || fail "rule $id has no complete, triaged precision record entry"
done

# Every rule has exactly one positive and one clean fixture file.
for id in "${rule_ids[@]}"; do
  [ "$(grep -rl -- "ruleid: $id\$" "$fixture/positive" | wc -l | tr -d ' ')" -ge 1 ] \
    || fail "rule $id has no positive fixture"
  [ "$(grep -rl -- "ok: $id\$" "$fixture/clean" | wc -l | tr -d ' ')" -ge 1 ] \
    || fail "rule $id has no clean fixture"
done

result="$work/result.json"
scan "$result" "$work/fixture"
[ -s "$result" ] || fail "Semgrep produced no result"
jq -e '(.errors | length) == 0' "$result" >/dev/null \
  || fail "Semgrep reported rule or parse errors: $(jq -c '[.errors[].message]' "$result")"

# Every fixture file must reach the rules; a skipped file must not surface as
# a missing or unexpected detection.
fixture_files="$(find "$fixture" -type f | wc -l | tr -d ' ')"
scanned_files="$(jq '.paths.scanned | length' "$result")"
[ "$scanned_files" -eq "$fixture_files" ] \
  || fail "Semgrep scanned $scanned_files of $fixture_files FOC fixture files"

# Expected findings: the line after each `ruleid:` annotation in positive/.
expected="$work/expected.tsv"
actual="$work/actual.tsv"
(cd "$work/fixture" && grep -rn -- 'ruleid: foc\.' positive) \
  | sed -E 's/^([^:]+):([0-9]+):.*ruleid: (foc\.[a-z0-9.-]+)$/\1\t\2\t\3/' \
  | awk -F '\t' '{ printf "%s\t%d\t%s\n", $1, $2 + 1, $3 }' | sort > "$expected"
jq -r --arg root "$work/fixture/" '
  .results[]
  | [(.path | ltrimstr($root)), (.start.line | tostring), (.check_id | sub("^.*?(?<id>foc\\.)"; "foc."))]
  | @tsv' "$result" | sort > "$actual"

# No rule fires on a clean fixture.
if grep -q $'^clean/' "$actual"; then
  fail "rule fired on a clean fixture: $(grep $'^clean/' "$actual" | tr '\t' ' ' | head -n 5 | paste -sd ';' -)"
fi

# Every rule fires on its positive fixture, exactly on the annotated lines.
missing="$(comm -23 "$expected" "$actual")"
[ -z "$missing" ] || fail "planted FOC defect not detected: $(printf '%s' "$missing" | tr '\t' ' ' | paste -sd ';' -)"
unexpected="$(comm -13 "$expected" "$actual")"
[ -z "$unexpected" ] || fail "unannotated FOC finding: $(printf '%s' "$unexpected" | tr '\t' ' ' | paste -sd ';' -)"
for id in "${rule_ids[@]}"; do
  grep -q $'\t'"$id\$" "$actual" || fail "rule $id did not fire on its positive fixture"
done

# The pack stays silent on code that is not FOC-specific.
baseline_result="$work/baseline.json"
scan "$baseline_result" "$work/baseline"
baseline_findings="$(jq '.results | length' "$baseline_result")"
[ "$baseline_findings" -eq 0 ] \
  || fail "FOC pack reported $baseline_findings findings on the non-FOC baseline fixture"

# A planted consumer .semgrep.yml must not add or replace rules.
cat > "$work/fixture/.semgrep.yml" <<'YAML'
rules:
  - id: consumer-planted-rule
    pattern: msg.sender
    message: consumer-planted rule
    languages: [solidity]
    severity: ERROR
YAML
consumer_result="$work/consumer.json"
(cd "$work/fixture" && scan "$consumer_result" .)
if jq -e 'any(.results[]; .check_id | endswith("consumer-planted-rule"))' "$consumer_result" >/dev/null; then
  fail "a consumer .semgrep.yml rule ran inside the FOC pack"
fi
rm -f "$work/fixture/.semgrep.yml"

# New-versus-existing classification through the semgrep-scan action script:
# a base commit with one planted file and a head commit that adds another.
scan_action="$repo_root/actions/semgrep-scan/semgrep-scan.sh"
history="$work/history"
mkdir -p "$history"
git_fixture() {
  git -C "$history" -c user.name=fixture -c user.email=fixture@example.invalid \
    -c commit.gpgsign=false -c init.defaultBranch=main "$@"
}
git_fixture init -q
cp "$fixture/positive/block-randomness.sol" "$history/existing.sol"
git_fixture add existing.sol
git_fixture commit -q -m base
base_sha="$(git_fixture rev-parse HEAD)"
cp "$fixture/positive/hardcoded-gas.sol" "$history/added.sol"
git_fixture add added.sol
git_fixture commit -q -m head

run_scan_action() {
  # run_scan_action <name> <baseline-ref>
  : > "$work/$1.out"
  (cd "$history" && SCAN_TARGET=. SEMGREP_CONFIG="$work/rules/foc-integrator.yml" \
    RESULT_FILE="$work/$1.sarif" BASELINE_REF="$2" GITHUB_OUTPUT="$work/$1.out" \
    bash "$scan_action" >/dev/null 2>&1) || fail "semgrep-scan failed for the $1 case"
  grep -Fq 'scanner_outcome=success' "$work/$1.out" || fail "semgrep-scan did not succeed for the $1 case"
}
state_of() {
  # state_of <sarif> <path> -> sorted "rule state" lines for that path
  jq -r --arg path "$2" '.runs[].results[]
    | select(.locations[0].physicalLocation.artifactLocation.uri == $path)
    | "\(.ruleId | sub("^.*?foc\\."; "foc.")) \(.baselineState // "none")"' "$1" | sort -u
}

run_scan_action classified "$base_sha"
grep -Fq 'classification=classified' "$work/classified.out" \
  || fail "baseline classification was not computed: $(cat "$work/classified.out")"
[ "$(state_of "$work/classified.sarif" added.sol)" = "foc.solidity.hardcoded-gas new" ] \
  || fail "findings added after the base commit are not marked new"
[ "$(state_of "$work/classified.sarif" existing.sol)" = "foc.solidity.block-randomness unchanged" ] \
  || fail "findings present at the base commit are not marked unchanged"

run_scan_action unavailable "$(printf '0%.0s' $(seq 1 40))"
grep -Fq 'classification=unavailable' "$work/unavailable.out" \
  || fail "a missing base commit did not report classification=unavailable"
[ "$(jq '[.runs[].results[]] | length' "$work/unavailable.sarif")" -eq 4 ] \
  || fail "an unclassified scan did not keep every finding"
if jq -e 'any(.runs[].results[]; has("baselineState"))' "$work/unavailable.sarif" >/dev/null; then
  fail "an unclassified scan marked findings"
fi

run_scan_action option-ref '--output=/tmp/injected'
grep -Fq 'classification=unavailable' "$work/option-ref.out" \
  || fail "a non-SHA baseline ref was not rejected"

run_scan_action not-requested ''
grep -Fq 'classification=not-requested' "$work/not-requested.out" \
  || fail "a scan without a baseline ref did not report classification=not-requested"
if jq -e 'any(.runs[].results[]; has("baselineState"))' "$work/not-requested.sarif" >/dev/null; then
  fail "a scan without a baseline ref marked findings"
fi

# Named rulesets resolve only to repository-owned files beside the action.
control="$work/control"
mkdir -p "$control/actions/semgrep-scan" "$control/rules"
cp "$scan_action" "$control/actions/semgrep-scan/semgrep-scan.sh"
cp "$rules" "$control/rules/foc-integrator.yml"
: > "$work/ruleset.out"
(cd "$history" && SCAN_TARGET=. RULESET=foc-integrator RESULT_FILE="$work/ruleset.sarif" \
  GITHUB_OUTPUT="$work/ruleset.out" bash "$control/actions/semgrep-scan/semgrep-scan.sh" >/dev/null 2>&1) \
  || fail "the foc-integrator ruleset did not run from the action's own rules directory"
[ "$(jq '[.runs[].results[]] | length' "$work/ruleset.sarif")" -eq 4 ] \
  || fail "the foc-integrator ruleset did not load the FOC integrator pack"
: > "$work/bad-ruleset.out"
if (cd "$history" && SCAN_TARGET=. RULESET=../../tmp/consumer RESULT_FILE="$work/bad-ruleset.sarif" \
  GITHUB_OUTPUT="$work/bad-ruleset.out" bash "$control/actions/semgrep-scan/semgrep-scan.sh" >/dev/null 2>&1); then
  fail "an unknown ruleset name was accepted"
fi
grep -Fq 'scanner_outcome=failure' "$work/bad-ruleset.out" \
  || fail "an unknown ruleset name was not reported as an operational failure"

printf 'FOC integrator pack checks passed (%s rules, %s fixture files).\n' \
  "${#rule_ids[@]}" "$fixture_files"

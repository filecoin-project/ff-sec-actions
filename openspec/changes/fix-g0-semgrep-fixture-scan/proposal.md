# Proposal

## Why

The G0 Trustworthy Foundation workflow has failed on every recorded run, including every run on `main`. Its "Validate Ecosystem Baseline composition and planted fixtures" step scans `test/fixtures/ecosystem-baseline/monorepo` from inside the repository checkout. The repository has no `.semgrepignore`, so Semgrep applies its built-in ignore list, which skips `test/` directories. Semgrep reports "Ran 5 rules on 0 files: 0 findings", and the detection check then fails on the first planted rule.

As a result, the ecosystem-baseline scenario "Consumer repository contains a Semgrep config" has never been proven in CI. Its planted `.semgrep.yml` check only runs when the test script performs the scan itself, and the G0 step instead passes it a precomputed result. A second failure is hidden behind the first: the next G0 step runs ShellCheck, which exits non-zero on two existing SC2015 notes.

## What Changes

- G0 runs the planted-fixture detection through `scripts/test-ecosystem-baseline.sh`'s own scan path. That path copies the rules and fixture to a temporary directory before scanning, which is how a Consumer Project tree is presented to Semgrep. A digest-pinned Docker wrapper supplies the `semgrep` executable. CI then also runs the planted Consumer Project `.semgrep.yml` check.
- The detection check fails with an explicit message when Semgrep scanned fewer files than the fixture contains. A skipped fixture can no longer surface as an unrelated "did not detect" error, and future rule additions cannot pass by scanning nothing.
- Rewrite the two `A && B || C` expressions flagged by ShellCheck SC2015, at `scripts/test-ecosystem-baseline.sh:141` and `actions/evaluation-adapter/evaluation-adapter.sh:28`, as explicit conditionals with identical behavior.
- G0 passes end to end for the first time.

Out of scope: Semgrep's built-in ignore list also drops `test/` and `tests/` from Consumer Project scans without reporting it. That is the coverage gap BASE-01 already tracks for `.semgrepignore` and `nosemgrep`, and it is fixed there, not here.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. Platform behavior does not change. This change fixes CI and test tooling so that the existing ecosystem-baseline requirements are actually proven. It declares `skip_specs: true`.

## Impact

- `.github/workflows/g0-contract.yml`: the planted-fixture step.
- `scripts/test-ecosystem-baseline.sh`: the scanned-file guard and the SC2015 rewrite.
- `actions/evaluation-adapter/evaluation-adapter.sh`: the SC2015 rewrite only. The exit code and message for an out-of-range `MAX_SUMMARY_FINDINGS` are unchanged.
- No change to workflow or action inputs or outputs, rules, pins, or the roadmap. This is maintenance, not a roadmap task, so no task is claimed.

# Tasks

## 1. Detection guard

- [x] 1.1 In `scripts/test-ecosystem-baseline.sh`, after the result is chosen and before the rule-ID checks, fail with `Semgrep scanned N of M planted fixture files` when `.paths.scanned | length` differs from the count of regular files in the fixture directory (design Decision 2). Verify it two ways. First, feed it the in-place Docker result (`"scanned": []`) through `BASELINE_RESULT_FILE` and confirm it fails with the new message rather than "did not detect". Second, confirm the self-scan path still passes using a local Docker `semgrep` wrapper.
- [x] 1.2 Update the header comment of `scripts/test-ecosystem-baseline.sh` to say that self-scan mode is the CI path and runs the planted `.semgrep.yml` check. Verify that `bash scripts/check-docs.sh` passes.

## 2. G0 workflow

- [x] 2.1 Replace the in-place `docker run ... semgrep scan` in the G0 "Validate Ecosystem Baseline composition and planted fixtures" step with the `$RUNNER_TEMP/bin/semgrep` Docker wrapper from design Decision 1. Set `TMPDIR="$RUNNER_TEMP"`, put the wrapper on `PATH`, and drop `BASELINE_RESULT_FILE`. Keep the literal `BASELINE_RUN_DETECTION=true` and the pinned `semgrep/semgrep:1.93.0@sha256:f35c...` reference that `check-docs.sh` requires. Verify by running the step's commands locally with `RUNNER_TEMP` pointed at a scratch directory: the script prints "composition and detection checks passed" and `test-consumer-alpha.sh` passes.
- [x] 2.2 Verify mutation resistance: temporarily point the wrapper scan back at the in-repo fixture path, or delete one planted line, and confirm the step fails. Restore the change afterwards.

## 3. ShellCheck

- [x] 3.1 Rewrite the SC2015 expression at `scripts/test-ecosystem-baseline.sh:141` as an `if`-assigned suffix (design Decision 3). Verify that the output line is unchanged in both detection modes.
- [x] 3.2 Rewrite the SC2015 expression at `actions/evaluation-adapter/evaluation-adapter.sh:28` as an explicit `if` with the same message and exit code 2. Verify that `bash scripts/test-evaluation-adapter.sh` passes and that `MAX_SUMMARY_FINDINGS=0` and `101` still exit 2.

## 4. Full G0 run

- [x] 4.1 Run every G0 step locally in order: all `run:` commands from `.github/workflows/g0-contract.yml`, then `shellcheck scripts/*.sh actions/*/*.sh actions/*/scripts/*.sh`, then actionlint 1.7.12 through Docker on the workflow, example and fixture set the step lists. Verify that each one exits 0. Report any further failure instead of folding a fix into this change.
- [x] 4.2 Verify that `bash scripts/check-openspec.sh` validates this change (with `skip_specs`) and that `bash scripts/roadmap.sh validate` still passes.

## Workflow follow-up

- Push the branch and confirm G0 passes on the pull request, then on `main` after merge.
- Archive the change with `/opsx:archive`. It has no delta specs.

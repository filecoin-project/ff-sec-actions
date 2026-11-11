# Design

## Context

`scripts/test-ecosystem-baseline.sh` has two detection modes when `BASELINE_RUN_DETECTION=true`:

- **Self-scan:** `BASELINE_RESULT_FILE` is empty and `semgrep` is on `PATH`. The script copies the rules and the fixture into `mktemp -d "${TMPDIR:-/tmp}/..."`, scans that copy, and then runs the planted Consumer Project `.semgrep.yml` check against it. Locally this passes, because the temporary path contains no `test/` segment.
- **Precomputed:** `BASELINE_RESULT_FILE` is set, and the script only checks that result for the expected rule IDs.

The G0 step uses the precomputed mode. It scans `test/fixtures/...` in place with `docker run` and the digest-pinned `semgrep/semgrep:1.93.0` image. The checkout has no `.semgrepignore`, so Semgrep's default ignore list skips the `test/` tree. Reproduced locally with the same image and arguments, the result is `"paths": {"scanned": []}`. Scanning a copy outside `test/` with that image detects all five planted rules.

The G0 runner has Docker but no `semgrep` executable.

## Goals / Non-Goals

**Goals:**
- G0 exercises the same detection path that maintainers run locally, including the planted `.semgrep.yml` check.
- A detection run that scans fewer fixture files than exist fails with a message that names that cause.

**Non-Goals:**
- Changing how the `semgrep-scan` action scans Consumer Projects. Default-ignore coverage reporting belongs to BASE-01.
- Changing the Semgrep image, version or digest.

## Decisions

### 1. Use the script's self-scan path in CI, via a Docker `semgrep` wrapper

The G0 step writes a two-line `semgrep` wrapper to `$RUNNER_TEMP/bin`. The wrapper runs `docker run --rm -v "$RUNNER_TEMP:$RUNNER_TEMP" -w "$PWD" <pinned image> semgrep "$@"`. The step puts `$RUNNER_TEMP/bin` on `PATH`, sets `TMPDIR="$RUNNER_TEMP"` so the script's temporary directory falls inside the mounted path, and runs the script without `BASELINE_RESULT_FILE`.

Alternatives considered:
- **Add a repository `.semgrepignore` that does not ignore `test/`.** Rejected. It would make this repository's own `sec-semgrep` run scan the deliberately vulnerable fixtures, and it would rely on the exact rule for when Semgrep's defaults apply.
- **Copy the fixture to `$RUNNER_TEMP` in the workflow and keep precomputed mode.** Rejected. It fixes the scan but leaves the planted `.semgrep.yml` check unexercised in CI, and it keeps two scan paths that can drift apart.
- **Pass `--no-git-ignore` or an explicit include.** Rejected. Those flags control git-ignore and target filtering, not Semgrep's default ignore list, so they do not address the cause.

The wrapper mounts only `$RUNNER_TEMP`, and the fixture copy and rules both live there. The repository checkout is not mounted, so the scan sees only what the script copied.

### 2. Guard on scanned-file count

In both modes, after the scan the script compares `.paths.scanned | length` with the number of regular files in the fixture directory. A mismatch fails with `Semgrep scanned N of M planted fixture files`. Each planted file exists to trigger a rule, so every one must be scanned. A future fixture file in a language no rule targets would fail this guard on purpose, which forces the fixture and the rules to stay paired.

### 3. Rewrite SC2015 expressions as explicit conditionals

- `scripts/test-ecosystem-baseline.sh:141`: the `"$( [ ... ] && printf ' and detection' || true )"` suffix becomes a variable set by an `if`.
- `actions/evaluation-adapter/evaluation-adapter.sh:28`: `[ a ] && [ b ] || { error; exit 2; }` becomes `if [ "$X" -lt 1 ] || [ "$X" -gt 100 ]; then error; exit 2; fi`. The message and exit code are unchanged. `scripts/test-evaluation-adapter.sh` already covers the range check.

## Risks / Trade-offs

- [Files the container writes into `$RUNNER_TEMP` are root-owned] → The script's `trap 'rm -rf ...'` removes them, because the runner user owns the parent directory, and the runner discards `$RUNNER_TEMP` after the job. Locally, the same wrapper shape has already been exercised.
- [Later G0 steps (ShellCheck, actionlint) have never run in CI and may surface other failures] → The full step sequence is run locally before pushing. Any further failure is reported, not worked around inside this change.
- [The guard couples the fixture file count to the rules] → This is intended (Decision 2), and the error message says what to fix.

## Migration Plan

Merge this change on its own. No consumer impact and no pin change. Rollback is a revert.

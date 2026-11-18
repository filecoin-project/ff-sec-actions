# Design

## Context

See proposal.md for the problem. The current state that shapes this design:

- **Evaluation Result `1.1.0` already models what is missing.** It has `suppressions: {count, sources}` and `coverage: {status, included, excluded, limitations}`.
  - The adapter always writes `suppressions.count: null`.
  - It renders included coverage and limitations in the job summary, but never exclusions.
  - It counts every SARIF result as a finding (`evaluation-adapter.sh:309`).
- **The aggregator already sums suppressions.** It marks the total non-authoritative when any count is `null` (`aggregate-results.sh:62`). Its Markdown summary shows no coverage.
- **Semgrep 1.93.0 behavior, probed during planning against the pinned image:**
  - A `nosemgrep` result stays in SARIF with `suppressions: [{kind: "inSource"}]`.
  - `.semgrepignore` matches, and the default ignore list (used when no `.semgrepignore` exists, and which covers `test/`), are dropped silently from SARIF.
  - Skipped files are listed only in JSON `paths.skipped`, and only with `--verbose`. Each entry has a `reason`: `semgrepignore_patterns_match` or `analysis_failed_parser_or_internal_error`.
  - Partial parses appear as `errors[]` entries with `level: "warn"` and type `PartialParsing`.
  - One run can write both `--sarif-output` and `--json-output`. A planted `tx.origin` inside a partially parsed file was not reported.
- **Detection fixtures cover Semgrep only.** `test-ecosystem-baseline.sh` runs Semgrep through a Docker wrapper in G0 when `BASELINE_RUN_DETECTION=true`. Nothing runs Trivy.
- **The hosted canary has never completed.** `consumer-alpha-canary.yml` runs on push to `optimization`. Its only run (2e14e39, July) ended in `startup_failure`. The cause is not visible without authenticated log access. `optimization` is a strict ancestor of `main`.

## Goals / Non-Goals

**Goals:**
- Every way the baseline loses Semgrep or dependency coverage is computed from files and recorded in the Evaluation Result. It is visible in the evaluation summary and in the Profile Conclusion summary.
- Suppression counts are integers only where the scanner exposes suppressions. Everywhere else they stay `null`.
- Each supported ecosystem has a planted defect that G0 proves is detected.

**Non-Goals:**
- **Overriding consumer ignore files.** `.semgrepignore` and `nosemgrep` stay honored and become reported, as the user chose during planning.
- **Gitleaks `gitleaks:allow`, `.gitleaksignore`, and consumer `.trivyignore`.** Gitleaks and Trivy drop these before SARIF. Their suppression counts stay `null`, which the bundle already reports as non-authoritative. Reporting them needs scanner-specific parsing and is left to PROF tasks.
- **Exposing coverage gaps through the language-specific Security Profiles** (PROF-03 to PROF-07), and fast versus deep lanes (BASE-02).
- **Changing gate defaults.** Every finding gate stays advisory by default.

## Decisions

### 1. The adapter splits suppressed results only when the caller declares a source

The adapter gains a `suppressions-source` input. When it is empty (the default), behavior is unchanged: every result counts and `suppressions.count` is `null`.

When it is set, for example to `semgrep-inline`:
- Results whose `suppressions` array is non-empty are removed from the finding count, highest severity, gate, annotations, and rendered finding list.
- They are counted into `suppressions.count`, with `sources: [<input>]`.
- The summary prints `Suppressed in source: N (<source>)` and a capped list showing rule, path, and line.
- Raw evidence and its digest are untouched.

Only `sec-semgrep.yml` sets the input, for both `semgrep-baseline` and `semgrep-foc`.

New-versus-existing classification counts only unsuppressed results, so `New in this change` never includes a suppressed line.

**Alternatives considered:**
- **Always split on SARIF `suppressions`.** Rejected. Gitleaks, zizmor, and Trivy would report `0` suppressions when they actually hide them upstream, making the bundle total falsely authoritative.
- **Scanner-specific logic in the adapter.** Rejected by `scanner-runtime`: the caller supplies policy and the adapter stays generic.

### 2. Computed coverage enters through two new adapter inputs

The adapter gains `coverage-excluded-computed` and `coverage-limitations-computed`. Both are JSON string arrays that default to `[]` and are validated like the declared inputs:
- They are appended after the declared entries.
- On a `complete` result with any computed entry, `coverage.status` becomes `partial`. Completion Status, the gate, and the exit code do not change.
- The summary gains a `Coverage excluded:` line, which was never rendered before, next to the existing included and limitations lines.

Keeping declared and computed inputs separate keeps the workflows' static literals intact. A workflow cannot concatenate JSON arrays in an expression, so the adapter does the merge.

**Alternative considered:** each scanner action merges static and computed coverage and returns one array. Rejected because every workflow would have to move its declared literals into the action.

### 3. `semgrep-scan` derives exclusions from the same run

The main scan adds `--verbose --json-output "$JSON_FILE"` next to its SARIF output. A `jq` step turns the JSON into two outputs, `coverage-excluded-json` and `coverage-limitations-json`. Rule matching does not change: the extra flags only add report files, and `--verbose` output goes to stderr.

| JSON source | Becomes |
|---|---|
| `paths.skipped[]` with reason `semgrepignore_patterns_match` | One exclusion: `N files excluded by <source>: <first 10 paths>[, and K more]`. `<source>` is `the Consumer Project .semgrepignore` when `$SCAN_TARGET/.semgrepignore` exists, otherwise `the Semgrep default ignore list`. |
| `paths.skipped[]` with reason `exceeded_size_limit`, `too_big`, or `minified` | One limitation: `N files skipped by Semgrep size or minification limits: ...`. |
| `paths.skipped[]` with reason `analysis_failed_parser_or_internal_error`, plus `errors[]` with `level == "warn"` | One limitation: `N files only partly parsed or not parsed; findings in them may be missed: ...`. Paths are de-duplicated. |
| Any other reason (`wrong_language`, `irrelevant_rule`, ...) | Ignored. These are not coverage loss for the declared languages. |

Paths come from the scanner's own report and are emitted only as JSON strings, through `jq --arg` and `tojson`. The adapter escapes them again when rendering, so a hostile filename cannot inject Markdown or workflow commands. A fixture with a backtick and `%0A` in a filename proves this (task 2.4).

If the JSON report is missing or malformed after a successful scan, the outputs are `[]`, plus one limitation saying exclusion reporting was unavailable. This mirrors how classification failure is handled.

**Alternative considered:** a second Semgrep run with `--json --verbose`. Rejected because it doubles scan time and could diverge from the SARIF run.

### 4. A file-only `dependency-coverage` action reports what Trivy cannot see

The new `actions/dependency-coverage` composite action uses only `find`, `test -e`, and `jq`. It needs no network or permission, and never reads file contents beyond `.gitmodules`, which it reads with `grep`. It honors the caller's `skip-dirs` and always prunes `node_modules`, `vendor`, `target`, and `.git`.

It emits `limitations-json` with up to three entries, each capped to 10 paths:
- `package.json` with no `package-lock.json`, `npm-shrinkwrap.json`, `yarn.lock`, `pnpm-lock.yaml`, `bun.lock`, or `bun.lockb` in its directory or any ancestor up to the scan root. Workspace members resolve to the root lockfile, so they are not flagged.
- `Cargo.toml` with no `Cargo.lock` in its directory or any ancestor up to the scan root.
- `foundry.toml` together with a `.gitmodules` that declares a `path = lib/...` submodule, or a `soldeer.lock`. These Solidity dependencies are not scanned.

`sec-dependencies.yml` runs it before the adapter and passes `limitations-json` as `coverage-limitations-computed`.

Execution-trust classification: tier `ecosystem-baseline`, network `none`, no checkout and no execution markers, the same as `detect-filecoin-profile`.

The output contract has no mode for an action without a findings surface, so `check-output-contract.sh` gains a `coverage-helper` mode. It is checked like `scanner-invocation`: the action must expose a `limitations-json` output, name a `consumer_workflow` whose mode is `normalized-evaluation`, and be composed by that workflow. A mutation test that drops the composition must fail the check.

**Alternative considered:** reading Trivy's JSON `Results[].Target` to infer gaps. Rejected because Trivy reports what it found, not what it missed.

### 5. The Profile Conclusion summary adds a "Coverage gaps and suppressions" section

After the evaluation table, `aggregate-results` adds one bullet group per received result that has a non-empty `coverage.excluded` or `coverage.limitations`, or a non-zero or `null` `suppressions.count`. A `null` count renders as `unknown`. If no result qualifies, it prints the single line from the spec. The bundle JSON is unchanged, because it already holds every result.

Gitleaks will therefore always show `suppressions: unknown`. That is accurate: it says the profile cannot see Gitleaks allow-list use.

### 6. Planted defects for Trivy run in G0 through a pinned image

The `test/fixtures/ecosystem-baseline/monorepo/` fixture gains the following.

Dependency files with published high or critical advisories:
- `javascript/package-lock.json` pinning `lodash@4.17.15`.
- `rust/Cargo.lock` pinning a RustSec-advised crate version.
- `go/go.mod` requiring `golang.org/x/crypto` at a version before the CVE-2024-45337 fix.

IaC misconfigurations:
- `infrastructure/main.tf` with a public-read S3 ACL.
- The existing Dockerfile, which has no `USER`.

Exclusion fixtures:
- `.semgrepignore` excluding `ignored/`, plus `ignored/Auth.sol` with a planted `tx.origin`.
- A `nosemgrep` line on a second planted `tx.origin`.
- A `solidity/Partial.sol` that uses `assembly ("memory-safe")`.
- `javascript/no-lock/package.json`, with no lockfile.

`test-ecosystem-baseline.sh` gains a `BASELINE_RUN_TRIVY=true` mode. It runs `trivy fs` and `trivy config` with the same severity defaults as the leaf workflows. It asserts:
- At least one finding per dependency ecosystem path.
- At least one IaC finding on each planted file.

It does not pin exact advisory ids, so the test survives advisory-database churn. The Semgrep detection mode gains assertions for:
- The exclusion entry, with the Consumer Project `.semgrepignore` source and the `ignored/Auth.sol` path.
- The suppression count of 1.
- The partial-parse limitation naming `Partial.sol`.

G0 adds a `trivy` wrapper beside the existing `semgrep` wrapper: `docker run` of `aquasec/trivy:0.70.0@sha256:<digest>`. That is the same version `trivy-action` installs in the leaf workflows. It passes `--db-repository ghcr.io/aquasecurity/trivy-db,public.ecr.aws/aquasecurity/trivy-db` so the GHCR rate limit has a fallback.

**Alternative considered:** running the fixtures only in the hosted canary. Rejected because the canary deliberately skips `test/fixtures`, and fixtures should fail the PR that breaks them.

### 7. Release and canary

The release follows the established layer order, in separate commits on the PR branch, merged with a merge commit:
1. Assets: adapter, `semgrep-scan`, `dependency-coverage`, and `aggregate-results`.
2. Leaf workflows: `sec-semgrep` and `sec-dependencies`, pinned to the asset commit.
3. Umbrella: `ecosystem-baseline` and `security-pipeline`, pinned to the leaf commit, with `profile-version: 1.2.0`.
4. Examples and the canary, pinned to the umbrella.

After merge, with the user's approval, `optimization` is fast-forwarded to the merge commit. That push triggers the canary. A completed run that uploads `ecosystem-baseline-evidence` is recorded in tasks.md with its run URL. If the run ends in `startup_failure` again, the cause is diagnosed before BASE-01 is marked done. Known causes are a caller permission narrower than a callee job, or an unreachable pinned SHA.

### Decision tickets

Both tickets referenced by BASE-01 are resolved, and this design conforms to them:
- **`scanner-runtime`:** a thin invocation followed by the generic adapter, with caller-supplied identity, coverage, and policy. Decisions 1 and 2 add caller-declared inputs and no scanner-specific logic in the adapter. Decision 3 keeps derivation in the scanner action.
- **`execution-trust`:** the new `dependency-coverage` action and the Semgrep JSON side output inspect files only. They need no secret, write permission, OIDC, network, or project execution. `check-baseline-no-exec.sh` and `execution-trust.json` classify the new action as `ecosystem-baseline`.

### Proving checks per scenario

| Spec scenario | Proving check |
|---|---|
| evaluation-adapter: one suppressed / blocking gate / undeclared / computed coverage / malformed computed | New fixture cases in `scripts/test-evaluation-adapter.sh` |
| consumable-output: nosemgrep listed, no annotation | `test-evaluation-adapter.sh` golden summary for the suppressed case |
| consumable-output: exclusions shown | `test-evaluation-adapter.sh` golden summary with computed exclusion |
| evidence-bundle: gaps section / no gaps | New cases in `scripts/test-aggregate-results.sh` |
| ecosystem-baseline: partial parse | `test-ecosystem-baseline.sh` Semgrep detection (`Partial.sol`) and `test-foc-integrator.sh` (FOC scan of the same) |
| ecosystem-baseline: manifest without lockfile / submodules | New `scripts/test-dependency-coverage.sh` fixtures |
| ecosystem-baseline: `.semgrepignore`, default ignore, nosemgrep | `test-ecosystem-baseline.sh` Semgrep detection, plus a `semgrep-scan` case without `.semgrepignore` |
| ecosystem-baseline: vulnerable lockfiles, IaC | `test-ecosystem-baseline.sh` with `BASELINE_RUN_TRIVY=true` in G0 |
| ecosystem-baseline: source defects | Existing Semgrep detection mode |

## Risks / Trade-offs

- **[Consumers can now dismiss a blocking Semgrep finding with `nosemgrep`]** → Every dismissal appears in the evaluation summary, the Profile Conclusion summary, and the Evidence Bundle count. The FOC guide and rules reference say to review new `nosemgrep` lines like code. This is the behavior the user chose.
- **[The Trivy advisory database or GHCR is unavailable during G0]** → A mirror fallback and a pinned image reduce this. A real outage fails G0, which is visible rather than a silent pass.
- **[Advisory data for a planted version is withdrawn]** → Assertions are per ecosystem, not per CVE. Each fixture uses a long-published advisory.
- **[Semgrep default ignore makes many repos show "N files excluded"]** → This is intended. `test/` exclusion has always happened silently, and reporting it is the point. The text names the default list, so it does not read as consumer action.
- **[`coverage.status: partial` on most real repositories]** → Status is informational. Completion and gates are unchanged, and docs explain how to read it.
- **[Workspace detection misses unusual layouts, such as a lockfile in a sibling directory]** → These are reported as a gap, a false limitation rather than a false claim of coverage. The fixture covers the common root-lockfile workspace.
- **[The canary startup failure has an unknown cause]** → The task stays open until a completed run is recorded.

## Migration Plan

Consumers advance one pin, the umbrella SHA in the example. The only behavior change is that `nosemgrep`-marked results move from findings to suppressions. This is noted in the PR body and in `understand-results.md`.

Rollback is the previous umbrella SHA (`d1bef8f`), which stays valid because the merge is a merge commit.

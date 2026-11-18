# Proposal

## Why

The Ecosystem Baseline already runs six non-executing evaluations, but BASE-01's release criteria are not met. Coverage the baseline silently loses is invisible:
- Semgrep skips files matched by `.semgrepignore` or its default ignore list (which includes `test/` and `tests/`) without saying so.
- Files Semgrep only partly parses can drop real findings.
- Manifests without a lockfile and Solidity dependencies vendored as Git submodules are never scanned for vulnerabilities.

Inline `nosemgrep` is also handled inconsistently. Semgrep marks those results as suppressed in SARIF, but the adapter still counts and gates them, and the Evaluation Result reports `suppressions.count: null`. The published FOC usage guide tells consumers that `nosemgrep` dismisses a finding, which is untrue in CI today.

Detection is proven only for Semgrep. No fixture shows that `trivy-dependencies` or `trivy-iac` find a planted defect. The hosted Consumer Alpha Canary has never completed: its only run, on the `optimization` branch in July, was a startup failure, and that branch is now 42 commits behind `main`.

## What Changes

- **In-source suppressions are honored and reported.** The evaluation adapter separates SARIF results that carry `suppressions` from findings:
  - They are excluded from the finding count, gate, and annotations.
  - They are counted in the Evaluation Result's existing `suppressions` field, with a caller-declared source.
  - The job summary lists each one with its rule and location.
  - A caller that cannot see suppressions (Gitleaks drops `gitleaks:allow` before SARIF) keeps `count: null`, so the Evidence Bundle total stays non-authoritative rather than falsely zero.
- **Semgrep reports what it did not scan.** `semgrep-scan` writes a verbose JSON report alongside SARIF from the same run. It turns skipped paths into coverage entries:
  - Files excluded by the Consumer Project's `.semgrepignore`, or by Semgrep's default ignore list when there is none, with a count, the source, and the first paths.
  - Files that failed or only partly parsed, as limitations.
  - This applies to both `semgrep-baseline` and `semgrep-foc`, and closes the partial-parsing gap recorded by FOC-01.
- **Dependency coverage gaps are reported.** A new file-only `dependency-coverage` action finds the following and records each as a `trivy-dependencies` limitation with paths:
  - `package.json` with no lockfile in its directory or an ancestor.
  - `Cargo.toml` with no `Cargo.lock`.
  - Foundry projects whose dependencies are Git submodules.
- **The Profile Conclusion summary shows coverage gaps and suppressions** for every evaluation, so the Evidence Bundle's existing data is visible without downloading it.
- **Cross-language detection fixtures.** The monorepo fixture gains:
  - Vulnerable lockfile entries for JavaScript, Rust, and Go.
  - Planted IaC misconfigurations.
  - A `.semgrepignore`, a `nosemgrep` line, a partially parsed file, and a manifest without a lockfile.
  - G0 runs Trivy against it with a digest-pinned image, as it already runs Semgrep.
- **Hosted canary proof.** Advance the canary and example pins, fast-forward `optimization` to the release commit, and record a completed canary run with `ecosystem-baseline-evidence`.
- **Docs.**
  - Correct the FOC guide and the baseline-rules limitation for the new suppression behavior.
  - Document reading coverage gaps.
  - Claim BASE-01 for this change.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `evaluation-adapter`: SARIF results with in-source suppressions are counted as suppressions with a declared source, not as findings.
- `consumable-output`: The job summary lists suppressed findings and coverage exclusions.
- `evidence-bundle`: The profile summary surfaces each evaluation's limitations, exclusions, and suppression count.
- `ecosystem-baseline`: Consumer exclusions cannot silently remove static-analysis coverage, dependency coverage gaps are reported, and planted defects in every supported ecosystem are detected.

## Impact

- **Actions:**
  - `actions/evaluation-adapter/`: suppression split and the new `suppressions-source` input.
  - `actions/semgrep-scan/`: JSON side output and coverage outputs.
  - New `actions/dependency-coverage/`.
  - `actions/aggregate-results/`: summary.
- **Workflows:** `sec-semgrep.yml`, `sec-dependencies.yml`, `ecosystem-baseline.yml`, `security-pipeline.yml`, and `consumer-alpha-canary.yml`. Examples are repinned in release layers, so the PR must be merged with a merge commit.
- **Manifests:** `security/output-contract.json`, `security/execution-trust.json`, `security/release-graph.json`, `security/scanner-gates.json` (unchanged gates), and `roadmap/state.json` (claim).
- **Tests:** `test-evaluation-adapter.sh`, `test-ecosystem-baseline.sh` (Trivy detection), `test-aggregate-results.sh`, new `test-dependency-coverage.sh`, and `g0-contract.yml` (Trivy wrapper).
- **Behavior change for consumers:** a `nosemgrep`-marked result no longer counts toward the finding total or a blocking static-analysis gate. It is reported as a suppression instead. The profile version advances to 1.2.0.
- **External dependency:** G0 downloads the Trivy vulnerability database during fixture detection. A registry outage fails G0 rather than silently passing.

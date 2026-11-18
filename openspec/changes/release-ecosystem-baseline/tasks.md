# Tasks

## 1. Roadmap

- [ ] 1.1 Claim BASE-01 with `ROADMAP_ALLOW_WRITE=true bash scripts/roadmap.sh claim BASE-01 release-ecosystem-baseline`, then verify `bash scripts/roadmap.sh validate` passes and BASE-01 shows `in_progress` with this change

## 2. Adapter: suppressions and computed coverage

- [ ] 2.1 Add the `suppressions-source` input to `actions/evaluation-adapter/`. When it is set, move SARIF results with non-empty `suppressions` out of the finding count, highest severity, gate, annotations, rendered list, and new/existing classification. Record `suppressions: {count, sources}`. When it is unset, behavior is unchanged with `count: null`. Verify with new `scripts/test-evaluation-adapter.sh` cases:
  - 3 results, 1 suppressed: 2 findings and count 1, with raw evidence unchanged.
  - Blocking with all results suppressed: exit 0 and the gate passes.
  - Undeclared source with 2 results: 2 findings and `null`.
- [ ] 2.2 Render `Suppressed in source: N (<source>)` and a capped rule/path/line list in the adapter summary, with no annotation for suppressed results. Verify with a golden summary fixture under `test/fixtures/evaluation-adapter/` and a check that the annotations output contains no suppressed line.
- [ ] 2.3 Add the `coverage-excluded-computed` and `coverage-limitations-computed` inputs. Validate them as JSON string arrays, append them after the declared entries, and set `coverage.status: partial` on a complete result when any computed entry exists. Render a `Coverage excluded:` summary line. Verify with test cases:
  - One computed exclusion: complete, partial, and ordered last.
  - Malformed computed input: exit 2.
  - The existing unclassified golden output stays byte-identical when the computed inputs are `[]`.
- [ ] 2.4 Verify escaping with a computed exclusion and a suppressed result whose paths contain a backtick, `|`, and `%0A`. The summary must render them inert, and no `::` workflow command may be emitted. Add this as a test case.
- [ ] 2.5 Update `docs/reference/evaluation-adapter.md` and `docs/reference/consumable-output.md` with the new inputs, suppression semantics, and the meaning of `partial`. Verify with `bash scripts/check-docs.sh`.

## 3. Semgrep exclusion reporting

- [ ] 3.1 In `actions/semgrep-scan/semgrep-scan.sh`, add `--verbose --json-output` to the main scan. Derive the `coverage-excluded-json` and `coverage-limitations-json` outputs following design decision 3: the ignore source, the size/minified limitation, and the deduplicated partial-parse limitation, with 10 paths shown plus a count of the rest. Emit `[]` plus one "exclusion reporting unavailable" limitation when the JSON report is missing. Declare the outputs in `action.yml` and verify with `bash scripts/check-output-contract.sh`.
- [ ] 3.2 Extend the monorepo fixture:
  - `.semgrepignore` excluding `ignored/`, plus `ignored/Auth.sol` with a planted `tx.origin`.
  - A second planted `tx.origin` marked `// nosemgrep`.
  - `solidity/Partial.sol` using `assembly ("memory-safe")`.
  
  Update `test-ecosystem-baseline.sh` detection mode to assert:
  - The exclusion names the Consumer Project `.semgrepignore` and `ignored/Auth.sol`.
  - Exactly 1 suppression.
  - The partial-parse limitation names `Partial.sol`.
  - Every existing planted defect is still reported.
  
  Verify by running it locally with the Docker wrapper.
- [ ] 3.3 Add a `semgrep-scan` case with no `.semgrepignore` and a planted file under `test/`, asserting the exclusion is attributed to the Semgrep default ignore list. Add a case where the JSON report is missing, asserting the "unavailable" limitation and a still-successful outcome. Verify both cases run in G0.
- [ ] 3.4 Make `test-foc-integrator.sh` assert that an FOC scan of a partially parsed fixture records the partial-parse limitation, and verify the test passes.
- [ ] 3.5 Commit the asset layer (adapter and `semgrep-scan`) and record its SHA for the leaf pins.

## 4. Dependency coverage

- [ ] 4.1 Create `actions/dependency-coverage/` (`action.yml`, `dependency-coverage.sh`) per design decision 4:
  - Uses only file presence checks, `find`, `grep`, and `jq`.
  - Honors `skip-dirs` and the fixed prunes.
  - Outputs `limitations-json`.
  
  Verify `shellcheck` passes and `bash scripts/check-baseline-no-exec.sh` accepts it.
- [ ] 4.2 Add `scripts/test-dependency-coverage.sh` with fixtures under `test/fixtures/dependency-coverage/` covering:
  - A root lockfile workspace (no limitation).
  - `package.json` without a lockfile.
  - `Cargo.toml` without `Cargo.lock`.
  - A Foundry `lib/` submodule.
  - `soldeer.lock`.
  - Prunes for `node_modules` and `skip-dirs`.
  - The 10-path cap.
  - A hostile path name.
  
  Wire the script into `g0-contract.yml` and `docs.yml`, add it to `check-docs.sh` required pages, and verify all cases pass.
- [ ] 4.3 Add the `coverage-helper` mode to `security/output-contract.json` handling in `scripts/check-output-contract.sh`, and declare `actions/dependency-coverage/action.yml` with `consumer_workflow: .github/workflows/sec-dependencies.yml`. Verify the check passes, and that a mutation removing the workflow's `uses:` of the action makes it fail.
- [ ] 4.4 Classify the action in `security/execution-trust.json` as `ecosystem-baseline` with network `none`, and add it to `security/release-graph.json`. Verify `bash scripts/check-execution-trust.sh` and `bash scripts/check-release-graph.sh` pass.
- [ ] 4.5 Add `javascript/no-lock/package.json` to the monorepo fixture so the baseline fixture also exercises the gap. Verify `test-dependency-coverage.sh` reports it when pointed at the monorepo fixture.
- [ ] 4.6 Fold `dependency-coverage` into the asset-layer commit from 3.5, or into a follow-up asset commit, and record the SHA.

## 5. Trivy planted-defect detection

- [ ] 5.1 Add the following to the monorepo fixture and record each choice and its advisory in a comment or README in the fixture:
  - `javascript/package-lock.json` pinning `lodash@4.17.15`.
  - `rust/Cargo.lock` pinning a RustSec-advised crate with a high or critical advisory.
  - `go/go.mod` requiring a pre-fix `golang.org/x/crypto`.
  - `infrastructure/main.tf` with a public-read S3 ACL.
- [ ] 5.2 Resolve the `aquasec/trivy:0.70.0` image digest and add the `BASELINE_RUN_TRIVY=true` mode to `test-ecosystem-baseline.sh`. It runs `trivy fs` and `trivy config` with the leaf workflows' severity defaults and the GHCR and ECR `--db-repository` list. It asserts at least one finding per dependency ecosystem path and per planted IaC file. Verify locally.
- [ ] 5.3 Add a digest-pinned `trivy` Docker wrapper to `g0-contract.yml` next to the `semgrep` wrapper and enable `BASELINE_RUN_TRIVY=true`. Verify with actionlint (pinned image) and `bash scripts/check-workflow-security.sh`.

## 6. Leaf and umbrella workflows

- [ ] 6.1 Update `sec-semgrep.yml`: pin `semgrep-scan` and the adapter to the asset commit, and pass `suppressions-source: semgrep-inline` plus the scan's computed coverage outputs to both adapter calls (`semgrep-baseline` and `semgrep-foc`). Verify `check-scanner-gates.sh`, `check-output-contract.sh`, and `test-output-contract.sh` pass.
- [ ] 6.2 Update `sec-dependencies.yml`: run `dependency-coverage` with `skip-dirs` before the adapter, pass `coverage-limitations-computed`, and pin the adapter to the asset commit. Verify the same checks pass, along with `bash scripts/check-baseline-no-exec.sh`.
- [ ] 6.3 Update `actions/aggregate-results/` to add the "Coverage gaps and suppressions" summary section (design decision 5). Add `test-aggregate-results.sh` cases:
  - Mixed: exclusion, `2`, and `unknown`.
  - All clean: the single line.
  
  Verify they pass and that the bundle JSON is unchanged for existing fixtures.
- [ ] 6.4 Commit the leaf layer, then update `ecosystem-baseline.yml` and `security-pipeline.yml` to the leaf SHA, the new `aggregate-results` asset SHA, and `profile-version: 1.2.0`. Commit the umbrella layer. Verify `bash scripts/test-ecosystem-baseline.sh` and `bash scripts/check-release-graph.sh` pass.
- [ ] 6.5 Advance `examples/consumer-ecosystem-baseline.yml`, `examples/consumer-security-pipeline.yml`, and `.github/workflows/consumer-alpha-canary.yml` to the umbrella SHA. Verify `bash scripts/test-consumer-alpha.sh` and `bash scripts/extract-workflow-doc-examples.sh` pass.

## 7. Consumer documentation

- [ ] 7.1 Update `docs/reference/foc-integrator-pack.md` (Dismiss section and Known Limitations) and `docs/reference/ecosystem-baseline-rules.md` (remove the known-limitation callout). State that `nosemgrep` and `.semgrepignore` are honored and always reported, and that reviewers should treat new suppressions like code. Verify `bash scripts/check-docs.sh` passes.
- [ ] 7.2 Update `docs/consumers/understand-results.md` and `docs/consumers/ecosystem-baseline.md` with how to read `Suppressed in source`, `Coverage excluded`, `partial` coverage, dependency gaps, and the Profile Conclusion gaps section. Note the `nosemgrep` behavior change for this release. Verify `check-docs.sh` and `check-workflow-docs.sh` pass.
- [ ] 7.3 Update `docs/workflows/sec-semgrep.md`, `docs/workflows/sec-dependencies.md`, and `docs/reference/current-contracts.md` (profile version 1.2.0). Verify `bash scripts/check-workflow-docs.sh` passes.

## 8. Integration and release

- [ ] 8.1 Run every G0 step locally in order, using the pinned actionlint image for `go run` and the Semgrep and Trivy Docker wrappers. Verify all pass.
- [ ] 8.2 Push the branch, open the PR with the release layers and the merge-commit instruction, and verify the G0 and Documentation Contract runs succeed.
- [ ] 8.3 After the PR is merged with a merge commit, get the user's approval and then fast-forward `origin/optimization` to the merge commit. Verify the Consumer Alpha Canary run completes and uploads `ecosystem-baseline-evidence`, and record the run URL here. If it ends in `startup_failure`, diagnose and fix it before checking this box.

## Workflow follow-up

- Archive the change with `/opsx:archive release-ecosystem-baseline` after 8.3 is recorded. Mark BASE-01 done through the roadmap script as part of the archive.

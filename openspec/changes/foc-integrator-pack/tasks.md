# Tasks

## 1. Roadmap and claim

- [x] 1.1 Confirm `archive-bootstrap-specs` is merged into `main`, then rebase this branch onto `main`. Verify with `git log origin/main` that `openspec/changes/archive/2026-11-06-bootstrap-security-gate-specs/` exists and that `bootstrap-security-gate-specs` is no longer active.
- [x] 1.2 Insert FOC-01 into `roadmap/state.json` at order 17 with the fields from design Decision 1, and renumber every later task. Add FOC-01 to FILE-01's `blocked_by`. Set BASE-01's `change` to `null`. Delete `openspec/changes/complete-ecosystem-baseline/`. Verify with `bash scripts/roadmap.sh validate`, and confirm that `bash scripts/roadmap.sh next` reports FOC-01.
- [x] 1.3 Claim FOC-01 with `bash scripts/roadmap.sh claim FOC-01 foc-integrator-pack`. Verify that `bash scripts/roadmap.sh validate` and `bash scripts/test-roadmap.sh` pass and that FOC-01 shows `in_progress`.

## 2. FOC Semgrep rules and fixtures

- [x] 2.1 Spike against `semgrep/semgrep:1.93.0` (pinned digest). For each of the seven rules in design Decision 6, write the pattern and run it on a one-line positive and clean sample. Also confirm the `Synapse.create` and `approveService` call shapes against the current `FilOzone/synapse-sdk` source. Record any rule that must be narrowed or dropped, and if one is dropped, update `specs/foc-integrator-pack/spec.md` before continuing.
- [x] 2.2 Write `rules/foc-integrator.yml` with the seven rules. Give each rule `metadata` (`foc-impact`, `fix`, `references`, `confidence`) and a message that states the impact and the fix. Verify with `semgrep scan --strict --config rules/foc-integrator.yml` in the pinned image, expecting exit 0 and no errors. `--validate` was not usable: it needs a registry lint ruleset and exits 2 offline, even for the existing baseline rules and for a deliberately broken rule.
- [x] 2.3 Add `test/fixtures/foc-integrator/positive/` and `clean/`, with one file per rule and `ruleid:`/`ok:` annotations. The fixtures must include a listener callback with an `msg.sender` check, a `railTerminated` that uses `try`/`catch`, and a server-only environment key. Verify that every rule id appears in both directories.
- [x] 2.4 Write `scripts/test-foc-integrator.sh` covering the checks in design Decision 7, except baseline-state tagging (task 3.3) and precision (task 4.3). The checks are:
  - The scanned-file count equals the fixture count.
  - Every rule fires on its positive fixture.
  - No rule fires on a clean fixture.
  - Zero findings on the baseline monorepo fixture.
  - A planted consumer `.semgrep.yml` adds no rule.

  Verify that it passes through the Docker `semgrep` wrapper, then fails when a positive annotation is removed and when a clean fixture is made to match.
- [x] 2.5 Document the pack in a new `docs/reference/foc-integrator-pack.md`. Cover each rule's impact, fix, and references; the advisory policy; and the promotion criteria. Link it from `docs/reference/README.md` and `docs/reference/ecosystem-baseline-rules.md`. Verify with `bash scripts/check-docs.sh` and `bash scripts/check-workflow-docs.sh`.

## 3. Scanner and adapter changes

- [x] 3.1 Extend `actions/semgrep-scan` with the `baseline-ref` input and the `classification` output (`classified`, `unavailable`, or `not-requested`). The second `--baseline-commit` pass, with git hardened (`safe.directory`, `core.hooksPath=/dev/null`, `core.fsmonitor=false`), tags `baselineState` by `matchBasedId/v1`. With no `baseline-ref`, the SARIF is unchanged. Verify with the tests in task 3.3.
- [x] 3.2 Update `actions/evaluation-adapter` so that, when any result has `baselineState`, it renders the new and existing counts, sorts new findings first, and prints an "existing findings in raw evidence" remainder line. Add SARIF fixtures to `scripts/test-evaluation-adapter.sh`:
  - Mixed new and unchanged findings, more than the cap.
  - No `baselineState`.

  Verify that counts and the gate are unchanged, and that the output without `baselineState` is byte-identical to the current expected output.
- [x] 3.3 Add baseline-state cases to `scripts/test-foc-integrator.sh`:
  - A scratch git repository with two commits yields one `new` and one `unchanged` result.
  - A missing base ref yields `classification=unavailable` with a complete SARIF.

  Add an assertion to `scripts/check-baseline-no-exec.sh` that the hardening flags are present. Verify that both scripts pass.
- [x] 3.4 Add `rules/gitleaks-filecoin.toml` (`[extend] useDefault = true` plus `filecoin-wallet-key-export`). Make `actions/gitleaks-scan` prefer the consumer `.gitleaks.toml` when present, otherwise use the control file, and emit `filecoin-rules=applied|not-applied`. Extend `scripts/test-gitleaks-scan.sh`:
  - A planted hex `secp256k1` export is detected and its value appears in no output.
  - With a consumer `.gitleaks.toml` present, the action emits `not-applied`.

  Verify that the test passes.
- [x] 3.5 Add the `foc` add-on to `profiles/filecoin-project-profiles.json`, with catalog validation and a fail-closed check for unknown add-ons. Implement add-on detection and the `add-ons-json` output in `actions/detect-filecoin-profile`. Add fixtures to `scripts/test-detect-filecoin-profile.sh`:
  - A Synapse SDK `package.json`.
  - A Solidity `PDPListener` import.
  - No FOC signal, which must produce `[]`.
  - An unknown add-on reference, which must make the detector exit nonzero.

  Update `docs/reference/profile-detection.md`. Verify that the test and `bash scripts/check-docs.sh` pass.
- [x] 3.6 Commit the asset layer: rules, actions, catalog, scripts, fixtures, and docs. Push it so the commit SHA is reachable on `origin`. Verify with `git ls-remote origin foc-integrator-pack`.

## 4. Workflow wiring, pins, and precision record

- [x] 4.1 Update the leaf workflows to pin the asset commit from task 3.6:
  - `sec-semgrep.yml`: `fetch-depth: 0` on `pull_request`, a second scan with `rules/foc-integrator.yml`, `baseline-ref` from the PR base SHA, a `semgrep-foc` adapter call with literal `blocking: false`, coverage limitations forwarded when `classification=unavailable`, and `evaluation-result-semgrep-foc` and `semgrep-foc-results` uploads.
  - `sec-secrets.yml`: forward `filecoin-rules=not-applied` as a coverage limitation.

  Update `security/output-contract.json`, `security/scanner-gates.json`, and the execution-trust manifest entries. Assert in `scripts/check-scanner-gates.sh` that `semgrep-foc` is wired with `blocking: false`. Verify that `check-output-contract.sh`, `test-output-contract.sh`, `check-scanner-gates.sh`, `check-execution-trust.sh`, and `actionlint` pass. Commit and push.
- [x] 4.2 Write `scripts/measure-foc-precision.sh` as maintainer-only. It clones `FilOzone/filecoin-services`, `pdp`, `filecoin-pay`, and `synapse-sdk` at pinned SHAs into a temporary directory, scans them with the pinned image, and writes `rules/foc-integrator-precision.json` with `triage: "unreviewed"`. Run it once, triage every finding as `true-positive` or `false-positive` with a note, and commit the record. Verify that the record has an entry for each rule and no `unreviewed` triage.
- [x] 4.3 Add the precision-record check to `scripts/test-foc-integrator.sh`: every rule id has an entry, commits are 40-hex, and no entry is `unreviewed`. Add the script to the G0 planted-fixture step through the existing wrapper, and add it to `docs/maintainers/g0-gate.md`. Verify that it passes, and that it fails when one rule's entry is deleted.
- [x] 4.4 Pin `ecosystem-baseline.yml` and `security-pipeline.yml` to the leaf commit from task 4.1, and add `semgrep-foc` to their required evaluation lists. Update `scripts/test-ecosystem-baseline.sh`'s `expected_evaluations`. Add an aggregation fixture with `semgrep-foc` missing to `scripts/test-aggregate-results.sh`, and assert that the profile fails. Verify that `check-release-graph.sh`, `test-release-graph.sh`, `test-ecosystem-baseline.sh`, and `test-aggregate-results.sh` pass.
- [x] 4.5 Update the consumer docs: in `docs/consumers/understand-results.md`, explain the new and existing counts, the FOC evaluation, and the FOC advisory policy; in `docs/consumers/ecosystem-baseline.md`, change the five evaluations to six. Advance the pins in `examples/consumer-ecosystem-baseline.yml` and the docs. Verify with `check-docs.sh`, `check-workflow-docs.sh`, `test-workflow-docs.sh`, and `check-release-graph.sh`.

## 5. Integration

- [ ] 5.1 Run every step of `.github/workflows/g0-contract.yml` locally in order, using the Docker `semgrep` wrapper. Then push, and verify that the G0 Trustworthy Foundation run on the PR succeeds.
- [ ] 5.2 Run `openspec validate foc-integrator-pack --strict` and `bash scripts/roadmap.sh validate`. Verify that both pass and that every spec scenario's proving check in design Decision 8 exists and ran in task 5.1.

## Workflow follow-up

- Merge the PR with a merge commit, not a squash, so the layered pinned SHAs stay reachable.
- After merge, run `/opsx:archive foc-integrator-pack`. This syncs the specs and marks FOC-01 `done`. BASE-01 becomes `pending`.
- FILE-01 later adopts the rule format, the paired fixtures, and the precision record. Promoting a rule to blocking is decided there or in VERIFY-01.

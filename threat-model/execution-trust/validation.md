# Execution Trust Validation Matrix

Status reflects the repository at G0-01. A passing inventory test proves that
current behavior is described accurately; it does not mean unsafe behavior has
already been remediated.

| SR | Threat | Test | Type | Pass criteria | Status |
|---|---|---|---|---|---|
| SR1 | T1-T4, T8, T14 | `bash scripts/check-execution-trust.sh` | Positive | Every workflow/action/example is classified and observed flags match source | PASS |
| SR1 | T1 | `bash scripts/test-baseline-no-exec.sh` with a sentinel-writing `preinstall` fixture | Negative | Policy accepts manifest inspection, rejects package-manager execution, and the sentinel remains absent | PASS |
| SR1 | T2 | Run a build-marker fixture in baseline and privileged-build tiers | Negative/Positive | Baseline never builds; privileged tier builds with no secret/write/OIDC/persisted credential | UNTESTED |
| SR1 | T3 | `bash scripts/test-workflow-security.sh` persisted-credential fixture | Negative | Every checkout is followed by `persist-credentials: false` | PASS |
| SR1 | T4 | `bash scripts/test-workflow-security.sh` missing/excess-authority fixtures | Negative | CI rejects implicit or policy-incompatible authority | PASS |
| SR2 | T5 | Recursively enumerate `uses:` from a proposed release | Negative | No branch, moving tag, or mismatched self-reference | FAIL |
| SR2 | T6 | Inspect every released container reference | Negative | Every image is pinned by digest | FAIL |
| SR2 | T14 | Change a fixture submodule origin/ref | Negative | Baseline refuses; privileged build records and constrains the origin/ref | UNTESTED |
| SR3 | T7 | Fork PR containing a token/OIDC probe | Negative | Baseline sees no secret/write/OIDC; no privileged trigger executes fork code | UNTESTED |
| SR3 | T9 | Upload a forged low-trust evidence artifact to a publisher fixture | Negative | Publisher rejects run identity/schema/provenance mismatch | UNTESTED |
| SR3 | T13 | `bash scripts/test-evaluation-result.sh` plus secretless fork fixture | Positive | AI reports missing provider secret as skipped while secret scanning still completes | PASS |
| SR4 | T8 | `bash scripts/test-gitleaks-scan.sh` with no configured secrets | Positive | PR-range and scheduled full-history scans both find the planted secret | PASS |
| SR4 | T11 | Observe DNS/HTTP destinations for baseline and external-analysis fixtures | Negative | Only declared destinations receive declared data | UNTESTED |
| SR4 | T12 | Run prompt-injection corpus through AI review | Negative | Injection is reported/contained and findings require independent validation | UNTESTED |
| SR5 | T10 | `bash scripts/test-scanner-outcome.sh` with no findings, findings, tool error, and malformed SARIF | Positive/Negative | Findings obey policy; tool error and malformed evidence are always error | PASS |
| SR5 | T10 | `bash scripts/test-evaluation-result.sh` with refusal, truncation, missing secret, and tool outage | Negative | Each result is incomplete/skipped/error, never zero-findings complete | PASS |
| SR5 | T9, T10, T13 | Aggregate mixed result fixtures | Positive | One Evidence Bundle preserves status, findings, limitations, and policy | UNTESTED |
| SR6 | T15 | Scan released examples/profiles for `self-hosted` and run a negative fixture | Negative | CI rejects self-hosted for baseline/untrusted evaluation | UNTESTED |

## Operational Checks

| Check | Frequency | Method |
|---|---|---|
| Classification drift | Every PR | `bash scripts/check-execution-trust.sh` |
| Workflow syntax and unsafe expressions | Every PR | Actionlint plus the planned workflow-security evaluator |
| Release graph mutability | Every release | Planned `scripts/check-release-graph.sh` |
| Tier permissions and checkout | Every PR/release | Planned G0 workflow-security contract |
| Third-party action/container updates | Weekly and every update PR | Dependency updater plus human review of source/provenance |
| Fork and cache isolation | Every release | G0 adversarial fork fixture |
| Private-source network destinations | Every release and provider change | Egress capture/allowlist test |

## Summary

| Category | Tests | Pass | Fail | Untested |
|---|---:|---:|---:|---:|
| SR1: Tier separation | 5 | 4 | 0 | 1 |
| SR2: Supply-chain immutability | 3 | 0 | 2 | 1 |
| SR3: Fork/shared-state isolation | 3 | 1 | 0 | 2 |
| SR4: Secrets/external transfer | 3 | 1 | 0 | 2 |
| SR5: Evidence/completion | 3 | 2 | 0 | 1 |
| SR6: Runner isolation | 1 | 0 | 0 | 1 |
| **Total** | **18** | **8** | **2** | **8** |

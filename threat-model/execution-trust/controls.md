# Execution Trust Security Requirements And Controls

## SR1: Separate Inspection, Execution, Publication, And External Analysis

**Mitigates:** T1, T2, T3, T4, T8, T14

**Requirement:** Every evaluation must run in exactly one named tier whose
authority is compatible with the way it handles Consumer Project content.

| Control | Implementation | Validates |
|---|---|---|
| Strict baseline | `contents: read`, no secrets/write/OIDC, no persisted credentials, no build/install/local execution | T1, T3, T4, T8 |
| Privileged build isolation | Ephemeral GitHub-hosted job, no secrets/write/OIDC/persisted credentials; project and submodule behavior assumed hostile | T2, T14 |
| Publisher isolation | Publisher consumes validated evidence but never checks out or executes untrusted content | T2, T4 |
| Classification inventory | `security/execution-trust.json` plus `scripts/check-execution-trust.sh` records observed drift and target tier | T1-T4, T8, T14 |

**Residual risk:** Scanner parser vulnerabilities can still execute within an
inspection job; the baseline removes high-value authority but does not make
parsers trustworthy.

**Design decision:** Mixed jobs are `legacy-mixed`, never releasable. Splitting
jobs is preferred to adding exceptions to a tier.

## SR2: Make The Complete Supply Chain Immutable

**Mitigates:** T5, T6, T14

**Requirement:** One reviewed consumer SHA must select every nested workflow,
action, image, prompt, rule, compiler/tool, and policy asset that controls an
evaluation.

| Control | Implementation | Validates |
|---|---|---|
| Full-SHA action/workflow pins | Generate or flatten releases so nested self-references use the same reviewed commit | T5 |
| Container digest pins | OCI digest plus human-readable version annotation | T6 |
| Submodule/tool provenance | Freeze allowed sources and revisions; treat fetched content as hostile build input | T14 |
| Release graph test | Recursively reject moving refs and missing assets | T5, T6, T14 |

**Residual risk:** An already-compromised upstream release can be immutably
pinned. Review, provenance, update monitoring, and revocation remain required.

**Design decision:** Moving major tags may be convenience aliases but are never
the reproducibility or security boundary.

## SR3: Keep Fork And Low-Trust Events Separate From Authority

**Mitigates:** T7, T9, T13

**Requirement:** Fork PRs receive useful secretless evaluation without allowing
untrusted content, caches, or artifacts to reach secrets, writes, OIDC, or a
privileged runner.

| Control | Implementation | Validates |
|---|---|---|
| Normal fork path | Ecosystem Baseline runs on `pull_request` with the strict tier | T7, T13 |
| Privileged fork path | No-checkout API analysis, maintainer approval, or app-mediated flow; never `pull_request_target` plus fork checkout | T7 |
| Shared-state isolation | Treat caches/artifacts from low-trust jobs as attacker input; validate evidence before publication | T9 |
| Explicit status | Missing authority is `skipped` or `incomplete`, never clean | T13 |

**Residual risk:** Repository administrators can weaken fork settings outside
the reusable workflow; rollout policy must detect or document those settings.

**Design decision:** Comment convenience never justifies checking out a fork in
a privileged event.

## SR4: Bound Secrets And External Data Transfer

**Mitigates:** T8, T11, T12

**Requirement:** Secrets and source leave the runner only through a named
Privileged Analysis with minimum credentials, documented destinations, data
scope, retention, and failure behavior.

| Control | Implementation | Validates |
|---|---|---|
| Secretless baseline | Replace secret/license-dependent default evaluation paths | T8 |
| External-analysis contract | Declare provider, fields sent, repository visibility, retention, model/tool, budget, and outputs | T11, T12 |
| No-checkout AI | Fetch only scoped PR metadata/diff through API; never execute project code | T11, T12 |
| Private-source egress gate | Do not claim private-repository baseline support until required outbound endpoints and source-transfer policy are approved | T11 |
| Injection-resistant evidence | Treat model input as hostile and independently validate findings before critical gates | T12 |

**Residual risk:** Providers and scanner endpoints can observe requests they
legitimately receive. Legal/privacy review and provider controls are outside
workflow YAML.

**Design decision:** External analysis remains additive and is not required for
baseline completion.

## SR5: Separate Evidence Completion From Merge Policy

**Mitigates:** T9, T10, T13

**Requirement:** Every evaluation emits a validated result with independent
completion and findings, and only an aggregator applies consumer Merge Gate
policy.

| Control | Implementation | Validates |
|---|---|---|
| Completion Status | `complete`, `incomplete`, `skipped`, or `error` independent of finding severity | T10, T13 |
| Evidence validation | Schema, immutable tool/profile identity, scope, limitations, suppression provenance, and artifact identity | T9, T10 |
| Aggregated required check | One profile conclusion blocks on consumer policy and declared incomplete/error behavior | T10, T13 |
| Publisher validation | Publisher rejects malformed, wrong-run, duplicate, or unsigned/unbound evidence | T9 |

**Residual risk:** A scanner can complete correctly and still miss a defect;
effectiveness measurement is a separate verification responsibility.

**Design decision:** Tool exit code is an adapter input, not the Merge Gate API.

## SR6: Require Ephemeral Runner Isolation

**Mitigates:** T15

**Requirement:** Public and untrusted Consumer Project evaluation runs only on
fresh GitHub-hosted runners unless a separately threat-modeled ephemeral runner
platform provides equivalent isolation.

| Control | Implementation | Validates |
|---|---|---|
| Runner contract | Released profiles specify GitHub-hosted runner labels and reject `self-hosted` in baseline examples | T15 |
| No durable credentials | No runner-level long-lived credentials or local secrets | T15 |
| Future runner review | Any alternate runner requires a new trust boundary, teardown proof, and network/credential model | T15 |

**Residual risk:** GitHub runner image and platform compromise remain upstream
risks managed through provider assurance and immutable job dependencies.

**Design decision:** Performance or specialized hardware needs do not silently
weaken this tier; they create a new Privileged Analysis design.

## Threat Disposition Matrix

| Threat | Disposition | Control or rationale |
|---|---|---|
| T1 | Mitigated | G0-03 removes package-manager execution and tests a malicious lifecycle-hook fixture under SR1 |
| T2 | Follow-on | G0-03/G0-11 enforce build isolation and publication separation under SR1; high priority, medium effort |
| T3 | Mitigated | G0-02 disables persisted credentials and tests negative checkout fixtures under SR1 |
| T4 | Mitigated | G0-02 enforces an exact per-job authority policy and rejects missing/excessive permissions |
| T5 | Follow-on | G0-09 implements SR2 release graph; critical priority, medium effort |
| T6 | Follow-on | G0-09 adds SR2 container digests; high priority, low effort |
| T7 | Follow-on | G0-10/PRIV-01 implement and test SR3; critical priority, medium effort |
| T8 | Follow-on | G0-06 and SR1/SR4 remove baseline secrets; high priority, medium effort |
| T9 | Follow-on | G0-10/EVAL-03 implement SR3/SR5 evidence isolation; high priority, high effort |
| T10 | Follow-on (partial) | G0-04 separates scanner gates/errors; G0-05/EVAL-01 cover all completion modes |
| T11 | Follow-on | SR4 private-source egress decision and PRIV-03; high priority, high effort |
| T12 | Follow-on | PRIV-02/PRIV-03 implement SR4 validation; medium priority, high effort |
| T13 | Follow-on | G0-05/G0-10 implement SR3/SR5 status; high priority, medium effort |
| T14 | Follow-on | G0-10/profile work implements SR1/SR2 submodule policy; high priority, medium effort |
| T15 | Follow-on | G0 contract and profile checks enforce SR6; critical priority, low effort |

## Accepted Risks Register

No execution-trust threats are accepted. T3 and T4 are mitigated by G0-02, and
T1 is mitigated by G0-03. Current `legacy-mixed` behavior remains pre-v1 debt
and cannot pass a release gate.

## Follow-On Controls

| ID | Control | Mitigates | Effort | Priority |
|---|---|---|---|---|
| FO1 | Explicit permissions and no persisted credentials | T2-T4, T14 | Low/Medium | High |
| FO2 | Remove lifecycle hooks from inspection | T1 | Medium | High |
| FO3 | Correct exit/completion semantics | T10, T13 | Medium | High |
| FO4 | Secretless secret detection | T8 | Medium | High |
| FO5 | Immutable release graph and container digests | T5, T6 | Medium | Critical |
| FO6 | Fork, cache, and evidence isolation tests | T7, T9, T13 | High | Critical |
| FO7 | Private-source egress and AI assurance | T11, T12 | High | High |
| FO8 | Self-hosted runner prohibition | T15 | Low | Critical |

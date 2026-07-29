# Execution Trust Tiers

**For:** Consumer Engineers, Platform Maintainers, and Rollout Operators

**Outcome:** Understand which repository surfaces may inspect or execute
Consumer Project content, what authority each surface may receive, and which
current workflows still require remediation before a public v1 release.

This is the human-readable execution-trust contract. The machine-readable
source is [`security/execution-trust.json`](../../security/execution-trust.json),
and CI compares that inventory with the workflow and action source through
[`scripts/check-execution-trust.sh`](../../scripts/check-execution-trust.sh).
Exact per-job authority is separately recorded in
[`security/workflow-policy.json`](../../security/workflow-policy.json).

> **Pre-v1 warning:** a recorded current tier describes behavior; it does not
> approve that behavior. Anything classified as `legacy-mixed` is not
> release-eligible.

## Core Invariant

The Ecosystem Baseline only inspects untrusted repository data. It does not run
package installation, lifecycle hooks, build configuration, compilers, local
actions, or other Consumer Project-controlled behavior. It receives no secret,
write token, or OIDC authority, and checkout credentials do not persist.

An evaluation that must execute Consumer Project behavior belongs in an
explicitly opted-in build-analysis tier. Evidence publication and external
analysis are separate authority boundaries; neither may be silently added to
the baseline.

## Released Tiers

| Tier | Content handling | Authority | Runner, cache, and network contract |
|---|---|---|---|
| `ecosystem-baseline` | Inspect files, history, manifests, and lockfiles; never execute Consumer Project behavior | `contents: read` only; no secrets, writes, or OIDC; `persist-credentials: false` | Fresh GitHub-hosted runner; cache forbidden until its namespace, provenance, and poisoning test are approved; declared public source/scanner queries only. Private-source support requires an approved egress design. |
| `privileged-publisher` | Publish already-produced, validated evidence; never check out or execute untrusted content | Only the named destination permission or credential; OIDC only when that publisher requires it | Fresh GitHub-hosted runner; no cache; only run-bound validated evidence and the declared destination |
| `privileged-build-analysis` | Build, compile, install, fuzz, or execute Consumer Project-controlled behavior and assume it is hostile | No secrets, writes, or OIDC; `persist-credentials: false` | Fresh GitHub-hosted runner only; cache forbidden until profile-specific poisoning tests pass; dependency/tool endpoints declared; output crosses tiers as untrusted evidence |
| `privileged-external-analysis` | Send explicitly scoped metadata or source to one external analysis provider; never execute project code | Provider credential and, if needed, one destination-specific publisher permission | Fresh GitHub-hosted runner; no cache; provider, data scope, retention, cost, and failure behavior documented |

Two inventory-only classifications are not consumer release tiers:

- `legacy-mixed` records a current surface that combines incompatible
  execution or authority and must be split or replaced.
- `control-repository-ci` covers development of this Control Repository, not
  evaluation inside a Consumer Project.

## Boundary Rules

Every released job must satisfy all rules for exactly one tier:

1. Declare permissions explicitly at the narrowest job boundary.
2. Use `persist-credentials: false` whenever content is checked out.
3. Never place secrets, write permissions, or OIDC in a job that executes
   Consumer Project-controlled behavior.
4. Never let a publisher check out or execute untrusted content. Treat incoming
   artifacts, caches, and scanner output as attacker-controlled evidence.
5. Run untrusted evaluation on fresh GitHub-hosted runners. `self-hosted` is
   outside the supported contract until separately threat-modeled.
6. Declare network destinations and the data sent to them. External analysis
   is opt-in and cannot be required for baseline completion.
7. Pin the complete released execution graph: workflows and actions by full
   commit SHA, containers by digest, and fetched tools/rules by verified
   immutable identity.
8. Report missing authority, refusal, timeout, malformed output, or unavailable
   coverage as `skipped`, `incomplete`, or `error`—never as a clean result.

GitHub recommends minimum `GITHUB_TOKEN` permissions and states that a full
commit SHA is the only immutable way to reference an action. Its guidance also
warns against running untrusted code through privileged events such as
`pull_request_target` and against using self-hosted runners for untrusted pull
requests. See [GitHub's secure-use reference](https://docs.github.com/en/actions/reference/security/secure-use).

## Event And Fork Policy

The strict baseline runs on `pull_request`, including forks, with no mapped
secrets and read-only contents access. A missing privileged capability must be
visible in completion status rather than converted to success.

A workflow triggered by `pull_request_target`, `workflow_run`, a trusted
dispatch, or another privileged event must not check out or execute an
untrusted PR head. If a privileged publisher consumes evidence produced by a
low-trust job, it must validate the schema, source run, immutable tool/profile
identity, scope, and artifact identity before publishing.

Repository administrators can alter token and fork settings outside reusable
workflow YAML. Rollout checks therefore need to validate the effective
repository configuration as well as this repository's source contract.

## Current Surface Classification

| Surface | Current tier | Target tier | Required migration |
|---|---|---|---|
| `.github/workflows/ai-code-review.yml` | `privileged-external-analysis` | `privileged-external-analysis` | Keep the internal action pinned; preserve no-checkout/no-execution behavior. |
| `.github/workflows/consumer-alpha-canary.yml` | `control-repository-ci` | `control-repository-ci` | Keep the canary aligned with the immutable public consumer example. |
| `.github/workflows/docs.yml` | `control-repository-ci` | `control-repository-ci` | Keep repository contracts in its validation job. |
| `.github/workflows/ecosystem-baseline.yml` | `ecosystem-baseline` | `ecosystem-baseline` | Keep the profile secretless, non-executing, immutable, and explicit about limitations. |
| `.github/workflows/evaluation-pipeline.yml` | `ecosystem-baseline` | `ecosystem-baseline` | Expand the proven aggregation slice into the multi-evaluation Ecosystem Baseline. |
| `.github/workflows/g0-contract.yml` | `control-repository-ci` | `control-repository-ci` | Require every G0 control and its rejecting fixture before release. |
| `.github/workflows/manual-ai-code-review.yml` | `control-repository-ci` | `control-repository-ci` | Keep checkout pinned and retain trusted manual scope. |
| `.github/workflows/sec-actions.yml` | `ecosystem-baseline` | `ecosystem-baseline` | Pin zizmor and its installer resolution through the immutable release graph. |
| `.github/workflows/sec-codeql.yml` | `legacy-mixed` | `privileged-build-analysis` | Remove write authority from build; publish separately. |
| `.github/workflows/sec-dependencies.yml` | `legacy-mixed` | `ecosystem-baseline` | Move SARIF publication out; keep build-dependent work separate. |
| `.github/workflows/sec-dependency-review.yml` | `legacy-mixed` | `ecosystem-baseline` | Separate baseline evaluation from optional commenting. |
| `.github/workflows/sec-iac.yml` | `ecosystem-baseline` | `ecosystem-baseline` | Keep inspection read-only and publish SARIF only from a separate tier. |
| `.github/workflows/sec-licenses.yml` | `ecosystem-baseline` | `ecosystem-baseline` | Keep build-dependent evidence in a separate Privileged Build Analysis. |
| `.github/workflows/sec-sbom.yml` | `ecosystem-baseline` | `ecosystem-baseline` | Keep build-enhanced SBOM evidence in a separate Privileged Build Analysis. |
| `.github/workflows/sec-scorecard.yml` | `legacy-mixed` | `ecosystem-baseline` | Separate read-only evaluation from the named OIDC/security-event publisher. |
| `.github/workflows/sec-secrets.yml` | `ecosystem-baseline` | `ecosystem-baseline` | Keep nested actions and the verified scanner archive on the immutable graph. |
| `.github/workflows/sec-semgrep.yml` | `ecosystem-baseline` | `ecosystem-baseline` | Keep the image digest-pinned, rules repository-owned, and inspection read-only. |
| `.github/workflows/sec-slither.yml` | `legacy-mixed` | `privileged-build-analysis` | Remove write authority from the build, constrain submodules, and publish separately. |
| `.github/workflows/security-pipeline.yml` | `legacy-mixed` | `ecosystem-baseline` | Keep nested pins immutable; replace the mixed umbrella with a strict baseline and separate opt-in privileged jobs. |
| `examples/consumer-ai-code-review.yml` | `privileged-external-analysis` | `privileged-external-analysis` | Replace the pilot SHA only with a reviewed release SHA. |
| `examples/consumer-ecosystem-baseline.yml` | `ecosystem-baseline` | `ecosystem-baseline` | Advance the profile commit only after release qualification and pilot evidence. |
| `examples/consumer-manual-ai-code-review.yml` | `privileged-external-analysis` | `privileged-external-analysis` | Replace the pilot SHA only with a reviewed release SHA. |
| `examples/consumer-security-pipeline.yml` | `legacy-mixed` | `ecosystem-baseline` | Keep the graph pin immutable; publish a secretless baseline and separate privileged opt-ins. |
| `actions/ai-code-review/action.yml` | `privileged-external-analysis` | `privileged-external-analysis` | Add bounded context, privacy, completion, and result contracts while preserving no checkout/execution. |
| `actions/aggregate-results/action.yml` | `ecosystem-baseline` | `ecosystem-baseline` | Keep aggregation deterministic, local, and fail-closed for ambiguous evidence. |
| `actions/evaluation-adapter/action.yml` | `ecosystem-baseline` | `ecosystem-baseline` | Keep normalization independent from scanner-specific invocation and policy. |
| `actions/gitleaks-scan/action.yml` | `ecosystem-baseline` | `ecosystem-baseline` | Keep the release archive version and checksums immutable and validated. |
| `actions/zizmor-scan/action.yml` | `ecosystem-baseline` | `ecosystem-baseline` | Keep the release archive version and checksums immutable and validated. |
| `actions/scanner-outcome/action.yml` | `ecosystem-baseline` | `ecosystem-baseline` | Pin every consuming reference through the immutable release graph. |
| `actions/semgrep-scan/action.yml` | `ecosystem-baseline` | `ecosystem-baseline` | Keep rules repository-owned and scanner execution isolated from Consumer Project tooling. |

The detailed observed flags, network destinations, and migration statements
live in the machine-readable inventory so automation can detect drift.

## Programmatic Use

Run the contracts locally:

```bash
bash scripts/check-execution-trust.sh
bash scripts/check-workflow-security.sh
bash scripts/test-workflow-security.sh
bash scripts/check-baseline-no-exec.sh
bash scripts/test-baseline-no-exec.sh
bash scripts/check-scanner-gates.sh
bash scripts/test-scanner-outcome.sh
```

The command fails when a workflow, example, or action is unclassified; a
recorded behavioral flag differs from source; a tier is invalid; or this page
no longer names the declared tiers and surfaces. The classification check
proves inventory accuracy only. The validation matrix in the
[execution-trust threat model](../../threat-model/execution-trust/threat-model-report.md)
shows which remediation controls still fail or remain untested.

Observed cache state covers explicit cache configuration and documented
tool-internal `actions/cache` use visible in the surface source. It is not yet a
transitive runtime attestation; G0-09 and G0-10 add release-graph and adversarial
shared-state verification.

The workflow-security command rejects a new or missing workflow/job, implicit
permissions, authority that differs from the reviewed policy, or checkout
without `persist-credentials: false`. Write authority is limited to these
purposes:

| Authority | Allowed purpose |
|---|---|
| `pull-requests: write` | Optional AI or dependency-review pull-request publication |
| `security-events: write` | SARIF publication by the named scanner path; inspection/publication separation remains follow-on work |
| `id-token: write` | OpenSSF Scorecard publication only, outside pull-request execution |

The baseline no-execution contract compares the dependency, license, and SBOM
workflows with [`security/baseline-policy.json`](../../security/baseline-policy.json).
It permits only reviewed manifest-inspection actions and rejects shell steps or
package-manager inputs. Build-enhanced completeness is not currently provided;
its limitations are explicit and any future implementation must be a separate,
opt-in Privileged Build Analysis.

The scanner-gate contract records every supported finding gate and its
umbrella input in [`security/scanner-gates.json`](../../security/scanner-gates.json).
The scanner-outcome module validates SARIF and treats `no-findings`, advisory
`findings`, gated `findings`, operational `error`, and malformed evidence as
separate observable behaviors.

When adding or changing a surface:

1. Decide whether it inspects data, executes project behavior, publishes
   evidence, or sends data to an external provider.
2. Update `security/execution-trust.json` with its current and target tier,
   observed behavior, network destinations, and migration work.
3. Update this table and the threat model if a boundary, asset, or attack path
   changes.
4. Run the execution-trust, documentation, Actionlint, and ShellCheck suites.

## Next

- Consumers should use [permissions and secrets](../consumers/permissions-and-secrets.md)
  before adopting any pre-v1 workflow.
- Maintainers should use the [Platform Maintainer guide](../maintainers/README.md)
  and take the next task from the [machine-readable roadmap](../../roadmap/README.md).
- Rollout Operators may treat surfaces whose current tier equals a
  release-allowed target tier as tier-compatible candidates, not as release
  approval; every other G0 gate still applies.

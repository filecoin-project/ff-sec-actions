# Execution Trust Threat Model Report

Date: 2026-07-28

Scope: Consumer-facing reusable workflows, examples, the AI composite action,
GitHub Actions authority, third-party execution, network transfer, and evidence
publication in `ff-sec-actions`.

## Executive Summary

The target architecture is viable only if file inspection, Consumer Project
code execution, external analysis, and evidence publication are separate trust
tiers. The current pre-v1 repository does not yet meet that boundary: build
workflows still execute project behavior beside publication authority, mutable
references remain, and missing evaluation can appear successful. G0-02 now
enforces exact per-job authority and safe checkout; G0-03 removes lifecycle
execution from dependency, license, and SBOM inspection.

G0-01 establishes six named classifications and a CI-checked inventory for all
18 workflow, example, and action surfaces. Four are consumer release tiers:
`ecosystem-baseline`, `privileged-publisher`,
`privileged-build-analysis`, and `privileged-external-analysis`. Two are
inventory-only: `legacy-mixed` and `control-repository-ci`.

This work identifies 15 threats: 3 critical, 11 high, and 1 medium. None are
accepted; T1, T3, and T4 are now mitigated. The validation matrix currently has
4 passing tests, 2 known failures, and 11 untested security tests. Consequently,
this repository remains pre-v1 and must not
claim that its current umbrella is a safe ecosystem baseline.

## Q1: What Are We Building?

### Security Objective

Independent Filecoin Consumer Projects call a version of this Control
Repository from GitHub Actions. Ephemeral runners inspect or execute project
content, download third-party code, contact network services, and emit evidence
that may affect merging. Untrusted content must never gain a path to secrets,
write tokens, OIDC, persistent runners, or unvalidated privileged publication.

### Components And Owners

| ID | Component | Owner | Security role |
|---|---|---|---|
| C1 | Contributor and repository content | Consumer Project contributors | PR files, history, manifests, configuration, submodules, and build behavior; hostile on PRs |
| C2 | Consumer workflow and settings | Consumer Project maintainers | Select event, permissions, secrets, runner, inputs, and Control Repository version |
| C3 | Control Repository release | Platform Maintainers | Reusable workflows, composite actions, prompts, rules, schemas, and examples |
| C4 | Ephemeral runner | GitHub | Holds job authority and runs inspection, builds, downloads, and evidence production |
| C5 | Third-party supply chain | External maintainers | Actions, containers, tools, compilers, packages, rule registries, and advisory data |
| C6 | GitHub services | GitHub and Consumer Project | API, token, pull requests, Security tab, artifacts, caches, and OIDC |
| C7 | External analysis providers | Provider and Platform Maintainers | Receive scoped data and return or publish analysis |
| C8 | Evidence/policy consumers | Consumer Engineers and Rollout Operators | Interpret summaries, artifacts, SARIF, comments, required checks, and future Merge Gate |

### Data Flows

| ID | Flow | Data and authority |
|---|---|---|
| DF1 | Contributor to consumer event | PR metadata, files, repository ref, and contributor identity |
| DF2 | Consumer workflow to Control Repository | Workflow ref, inputs, permission cap, and explicitly mapped secrets |
| DF3 | Release/supply chain to runner | Workflows, actions, containers, tools, prompts, and rules over Git/OCI/HTTPS |
| DF4 | Repository to runner | Files, history, submodules, configuration, and project-controlled build behavior |
| DF5 | Runner to third parties | Package/tool downloads and vulnerability/rule queries; authentication varies |
| DF6 | Runner to GitHub | Checkout, API calls, comments, SARIF, artifacts, caches, and OIDC |
| DF7 | Runner to external provider | PR metadata, scoped source/diff, evidence, and provider credential |
| DF8 | Runner/services to consumers | Raw and normalized findings, completion, check conclusion, and limitations |

### Trust Boundaries

- **TB1 — contribution/base authority:** an untrusted contributor controls PR
  data but must not control trusted workflow authority.
- **TB2 — caller/reusable permission boundary:** the consumer grants an upper
  permission cap; each called job still needs a narrower explicit contract.
- **TB3 — data/code execution:** parsing files is different from lifecycle
  hooks, autobuild, compilers, local scripts, or recursive submodule behavior.
- **TB4 — reviewed/third-party supply chain:** every workflow, action,
  container, compiler, prompt, and rule becomes trusted code or policy.
- **TB5 — runner/external network:** egress may disclose source, credentials,
  metadata, or findings and can return hostile dependencies or evidence.
- **TB6 — evidence/Merge Gate:** tool output, absent output, and operational
  failure are not independently authoritative policy conclusions.
- **TB7 — low-trust/trusted events and shared state:** fork content, caches, and
  artifacts must not cross into secrets, writes, OIDC, or trusted runners.

Supported tiers assume fresh GitHub-hosted runners. Full commit SHAs are the
Actions immutability boundary. Scanner input and output are hostile. A green
job is not proof of complete evaluation until independent Completion Status
exists.

## Q2: What Can Go Wrong?

| ID | Priority | Boundary | Concrete attack path | Impact |
|---|---|---|---|---|
| T1 | High | TB3 | A PR adds a package lifecycle hook; dependency, license, or SBOM inspection runs an install and executes it. | Runner compromise and exfiltration |
| T2 | High | TB3 | A hostile build file/plugin is invoked by CodeQL autobuild, Slither, Foundry, or a compiler in a publishing job. | Token abuse or forged evidence |
| T3 | High | TB2/TB3 | Checkout stores the token; later project-controlled behavior reads git configuration and reuses it. | Job-authority compromise |
| T4 | High | TB2 | A broad caller cap reaches an inner job with missing permissions or mixed inspection and publication. | Comment/SARIF manipulation and expanded blast radius |
| T5 | Critical | TB4 | A nested branch or moving tag changes after a consumer reviewed the top-level reference. | Ecosystem-wide execution of changed code |
| T6 | High | TB4 | A tagged scanner container is replaced while workflow YAML remains unchanged. | Source disclosure and evidence manipulation |
| T7 | Critical | TB1/TB7 | A privileged `pull_request_target` or `workflow_run` checks out and executes a malicious fork head. | Base repository/secret compromise |
| T8 | High | TB2/TB3 | Hostile repository data exploits a scanner in the same job as a provider or license secret. | Organization credential theft |
| T9 | High | TB6/TB7 | A low-trust run poisons a cache or artifact later executed or trusted by a privileged publisher. | Privilege crossing and durable forged evidence |
| T10 | High | TB6 | Timeout, refusal, malformed output, or missing SARIF is converted to zero findings and a green job. | False assurance and Merge Gate bypass |
| T11 | High | TB5 | A compromised tool reads private source or runner credentials and sends them through broad HTTPS egress. | Confidential source/credential disclosure |
| T12 | Medium | TB5/TB6 | Adversarial instructions in PR text or source redirect an external model or suppress findings. | Misleading AI evidence |
| T13 | High | TB6/TB7 | A fork lacks a secret or publisher authority; the evaluation skips but the aggregate result appears clean. | Systematic false assurance for external contributions |
| T14 | High | TB3/TB4 | A PR changes a recursive submodule URL/ref and a build consumes content outside the reviewed repository. | Hidden supply-chain execution |
| T15 | Critical | TB7 | A fork evaluation runs on a persistent self-hosted runner and leaves compromise for later trusted jobs. | Durable organization/infrastructure compromise |

The complete STRIDE tags, likelihood reasoning, and step-by-step attack traces
are preserved in [`threats.md`](threats.md).

## Q3: What Are We Doing About It?

| Requirement | Required control | Threats | Current disposition |
|---|---|---|---|
| SR1 — separate inspection, execution, publication, and external analysis | One named tier per evaluation; baseline read-only/no execution; hostile builds isolated; publishers never process untrusted content | T1-T4, T8, T14 | Inventory, G0-02 authority/checkout, and G0-03 manifest no-execution controls implemented; build and secret remediation remains |
| SR2 — immutable complete supply chain | Full-SHA action/workflow graph, container digests, constrained submodule/tool provenance, recursive release test | T5, T6, T14 | Follow-on G0-09 |
| SR3 — fork and low-trust event isolation | Secretless `pull_request` baseline, no privileged fork checkout, hostile shared-state handling, explicit skipped/incomplete status | T7, T9, T13 | Follow-on G0-10 and PRIV-01 |
| SR4 — bounded secrets and external transfer | Secretless baseline; named provider, data scope, retention and failure policy; no-checkout AI; private-source egress gate | T8, T11, T12 | Follow-on G0-06, PRIV-02, and PRIV-03 |
| SR5 — completion/evidence separate from Merge Gate | Four-state completion, schema/provenance validation, one consumer-policy aggregator, publisher validation | T9, T10, T13 | Follow-on G0-04, G0-05, EVAL-01, and EVAL-03 |
| SR6 — ephemeral runner isolation | GitHub-hosted runner contract, no durable credentials, separate review for alternative runner platforms | T15 | Contract defined; enforcement follows in G0 workflow checks |

No threat is accepted. T1, T3, and T4 are mitigated; the other 12 have explicit
follow-on owners. `legacy-mixed` is non-releasable debt, not an exception
mechanism.

Residual risks remain even after the controls: parsers can have vulnerabilities,
immutably pinned upstream releases can already be compromised, provider-approved
data remains visible to that provider, repository administrators can weaken
fork settings, and a completed scanner can still miss defects. Release review,
provenance, provider governance, consumer configuration checks, and measured
effectiveness remain necessary.

## Q4: Did We Do A Good Job?

### Validation Matrix Summary

| Area | Tests | Pass | Fail | Untested |
|---|---:|---:|---:|---:|
| SR1 tier separation | 5 | 4 | 0 | 1 |
| SR2 supply-chain immutability | 3 | 0 | 2 | 1 |
| SR3 fork/shared-state isolation | 3 | 0 | 0 | 3 |
| SR4 secrets/external transfer | 3 | 0 | 0 | 3 |
| SR5 evidence/completion | 2 | 0 | 0 | 2 |
| SR6 runner isolation | 1 | 0 | 0 | 1 |
| **Total** | **17** | **4** | **2** | **11** |

The passing contracts are:

```bash
bash scripts/check-execution-trust.sh
bash scripts/check-workflow-security.sh
bash scripts/test-workflow-security.sh
bash scripts/test-baseline-no-exec.sh
```

It proves that every workflow, example, and action metadata file is classified
and that observed checkout, credential, permission, secret, execution, mutable
reference, container, OIDC, cache, and runner behavior agrees with source. The
workflow policy additionally proves exact job authority and safe checkout. The
two current failures are mutable references in the release graph and a
container tag without a digest. The 12 untested cases become
adversarial fixtures in their mapped roadmap tasks.

See [`validation.md`](validation.md) for every positive and negative test and
its exact pass criterion. See [`controls.md`](controls.md) for the complete
control design and threat-disposition matrix.

### Positive Findings

- Every current execution surface is now represented in one machine-readable
  inventory, including its target tier and migration path.
- AI consumer review avoids Consumer Project checkout and project-code
  execution, which provides a viable external-analysis boundary to harden.
- Current workflows use GitHub-hosted rather than self-hosted runners.
- The documentation CI now executes the classification contract, so new or
  changed surfaces cannot silently bypass inventory.

### Priority Remediation Order

1. **G0-04/G0-05/G0-06:** make findings, operational failure, and missing
   secrets honest; provide secretless fork-capable secret detection.
2. **G0-07/G0-09:** evaluate consumer workflow security and make one pin cover
   the complete action/workflow/container graph.
3. **G0-10:** prove token, secret, OIDC, cache, artifact, and checkout isolation
   with an end-to-end fork fixture.
4. **EVAL/PRIV work:** normalize evidence, validate publishers, and bound
   external/AI data transfer before those results influence critical gates.

## Risk Posture

| Disposition | Count |
|---|---:|
| Mitigated | 3 |
| Accepted | 0 |
| Follow-on/deferred with owner task | 12 |
| Unaddressed | 0 |

The posture is intentionally conservative: this report provides a complete
control and task disposition for identified threats without representing
planned work as implemented safety.

## Sources And Artifacts

GitHub's secure-use guidance supports least privilege, full-SHA pinning,
careful privileged-event handling, and avoiding self-hosted runners for
untrusted pull requests: [Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use).
GitHub documents the job-scoped token and fork permission behavior in
[The `GITHUB_TOKEN`](https://docs.github.com/en/actions/concepts/security/github_token)
and [Workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax).
GitHub also warns that cache entries can be accessed from pull requests and
must not contain sensitive data: [Dependency caching](https://docs.github.com/en/actions/concepts/workflows-and-actions/dependency-caching).

Local supporting artifacts:

- [`research-corpus.md`](research-corpus.md) — research and assumptions
- [`architecture.md`](architecture.md) — components, flows, and boundaries
- [`threats.md`](threats.md) — complete threat catalog
- [`controls.md`](controls.md) — requirements and dispositions
- [`validation.md`](validation.md) — test matrix
- [Execution Trust Tiers](../../docs/reference/execution-trust.md) — operational reference
- [`security/execution-trust.json`](../../security/execution-trust.json) — machine-readable classification

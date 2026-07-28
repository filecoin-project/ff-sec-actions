# Ecosystem Security Decision Map

Goal: make `ff-sec-actions` a robust, reusable security-evaluation platform for
independent Filecoin ecosystem projects without turning a green check into a
false claim of safety.

This map is the canonical decision artifact. The
[machine-readable roadmap](../roadmap/README.md) is the canonical implementation
queue for task order, dependencies, acceptance criteria, verification, and
status. Resolve open decision tickets when their corresponding roadmap task is
claimed.

## Target Architecture

1. **Ecosystem Baseline** — secretless, read-only, safe on untrusted PRs.
2. **Security Profiles** — Go node, Rust/FVM actor, Solidity/FEVM, service,
   and infrastructure coverage layered on the baseline.
3. **Privileged Analyses** — AI review, PR comments, publishing, and other
   capabilities isolated behind explicit authority.
4. **Evidence and policy** — every evaluation emits a normalized result and
   completion status; consumers independently choose their Merge Gate.
5. **Documentation system** — Consumer Engineers, Platform Maintainers, and
   Rollout Operators each have a tested path through adoption, operation,
   extension, release, and rollback.

## Release Gates

| Gate | Exit criteria |
|---|---|
| G0 — Trustworthy foundation | No untrusted code runs with write/OIDC authority; transitive workflow code is immutably pinned; scanners cannot silently pass on findings or incomplete execution; examples and trust claims are checked against implementation. |
| G1 — Internal alpha | Ecosystem Baseline and one Security Profile pass adversarial fixtures and run end-to-end in a sandbox Consumer Project through the documented quickstart. |
| G2 — Multi-profile pilot | Go, Rust, Solidity, and service profiles run in representative projects; evidence is normalized; every pilot profile has tested consumer, operator, upgrade, and rollback guidance. |
| G3 — Public v1 | Immutable release, compatibility policy, public access model, governance, support path, migration tooling, audience navigation, and generated reference documentation are operational. |
| G4 — Ecosystem scale | Adoption inventory, health telemetry, profile owners, update automation, documentation feedback, and effectiveness reviews operate continuously. |

## Improvement Push

| Tranche | Scope | Status |
|---|---|---|
| T1 — Navigable foundation | README audience router, documentation home, first consumer/maintainer/operator journeys, reference index, executable pilot examples, local-link contract, and CI enforcement | Implemented on the current branch |
| T2 — G0 trust foundation | Explicit workflow permissions, no unnecessary install hooks, honest scanner gates, completion status, safe fork behavior, and immutable transitive refs | Next |
| T3 — Evaluation platform | Evaluation Result schema, scanner adapter contract, evidence aggregation, and first end-to-end Security Profile | Blocked by open decisions |
| T4 — Privileged analysis | Bounded AI context/threat-model/review pipeline, validation, privacy, cost, and fork handling | Blocked by T3 and open decisions |
| T5 — Release and governance | Verification corpus, CODEOWNERS, vulnerability process, compatibility policy, release automation, revocation, and generated reference | Blocked by earlier tranches |
| T6 — Ecosystem rollout | Representative pilots, migration tooling, adoption inventory, support, effectiveness measures, and recurring review | Blocked by public-v1 readiness |

## known-blockers: Remove Known Unsafe Or Misleading Behavior

Blocked by:
Status: resolved
Type: Research

### Question

Which current defects can be fixed without waiting for product decisions?

### Answer

The initial review established a no-regret remediation lane:

- give every workflow explicit least privilege and use
  `persist-credentials: false`;
- never run package lifecycle scripts merely to inspect dependencies;
- scope OIDC permission to Scorecard only;
- make Trivy gates set a non-zero finding exit code and pass every blocking
  input through the umbrella;
- distinguish `complete`, `incomplete`, `skipped`, and `error` from finding
  severity, including AI refusal and truncated coverage;
- replace mutable or missing self-references with an immutable release graph;
- align examples with refs that exist;
- add automated Actionlint, ShellCheck, schema, workflow-security, and
  documentation-contract checks;
- make the README an audience router and ensure every supported workflow and
  profile has an executable consumer example.

G0 cannot pass until each item has a regression test.

## product-contract: Define What The Platform Promises

Blocked by:
Status: resolved
Type: Grilling

### Question

What does "effective security evaluation for all Filecoin projects" mean, and
what must the platform never claim?

### Answer

The platform provides repeatable evidence and policy inputs; it does not
certify that a project is secure. Every supported Consumer Project receives a
safe Ecosystem Baseline, then selects a Security Profile. Privileged Analyses
are additive and must never be required for baseline coverage. A clean result
means only that the declared evaluations completed their declared scope and
reported no findings at their configured thresholds.

## distribution-model: Choose The Cross-Organization Delivery Model

Blocked by: product-contract
Status: open
Type: Grilling

### Question

Should ecosystem delivery be public reusable workflows alone, a GitHub App
that manages installation and credentials, organization-managed deployment, or
a staged combination?

### Answer

Pending. Recommended starting position: publish immutable public workflows and
profiles for self-service adoption, then add a narrowly scoped GitHub App only
if installation drift, fork coverage, or centralized evidence cannot be solved
cleanly with native Actions.

## release-integrity: Make A Pin Cover The Whole Execution Graph

Blocked by: distribution-model
Status: open
Type: Prototype

### Question

How will a consumer pin one version and be certain that every nested workflow,
composite action, container, prompt, rule, and third-party action is immutable?

### Answer

Pending. Prototype two options: flatten the umbrella into a single released
workflow, or generate release workflows whose internal references contain the
same immutable commit SHA. Compare auditability, maintenance cost, and rollback
behavior. Moving major tags may be offered for convenience but cannot be the
reproducibility boundary.

## execution-trust: Isolate Untrusted Repository Content

Blocked by: product-contract
Status: resolved
Type: Prototype

### Question

Which evaluations only inspect files, which execute Consumer Project code, and
what token, credential, network, runner, and OIDC boundaries apply to each?

### Answer

The [execution-trust contract](reference/execution-trust.md) defines four
release-allowed tiers: a secretless, read-only, non-executing
`ecosystem-baseline`; a no-checkout `privileged-publisher`; an explicitly
opted-in `privileged-build-analysis` with no secrets, writes, OIDC, persisted
credentials, or durable runner; and a no-execution
`privileged-external-analysis` with one declared provider and bounded data
transfer. `legacy-mixed` records pre-v1 violations and is never releasable;
`control-repository-ci` is not a Consumer Project tier.

The machine-readable [`security/execution-trust.json`](../security/execution-trust.json)
classifies every current workflow, example, and action, including its token,
secret, network, runner, cache, and OIDC behavior and target migration. The
[threat model](../threat-model/execution-trust/threat-model-report.md) records
15 threats and their follow-on controls. CI rejects missing surfaces,
implementation/classification drift, or any release-allowed current tier that
violates its execution and authority contract.

## evaluation-contract: Separate Evidence, Completion, And Policy

Blocked by: product-contract
Status: open
Type: Grilling

### Question

What normalized schema should every evaluation emit, and how do incomplete
coverage, tool errors, findings, suppressions, and Merge Gates interact?

### Answer

Pending. Recommended minimum: tool identity and immutable version, profile
version, scope, completion status, coverage limitations, normalized findings,
suppression provenance, timing, and evidence locations. Operational failure
must never be represented as zero findings. Consumers choose gate policy
separately from scanner execution.

## profile-taxonomy: Define Supported Project Classes

Blocked by: product-contract
Status: open
Type: Research

### Question

Which Security Profiles cover the real ecosystem, and which checks are
required, optional, or unsupported for each?

### Answer

Pending. Start with evidence from representative repositories and test five
candidates: Go node, Rust/FVM actor, Solidity/FEVM, service application, and
infrastructure. Define language detection, monorepo composition, Filecoin
invariants, dependency analysis, build requirements, and profile ownership.

## fork-pr-model: Cover External Contributions Safely

Blocked by: distribution-model, execution-trust
Status: open
Type: Prototype

### Question

How will fork PRs receive useful evaluation when secrets and write tokens are
unavailable, without introducing a `pull_request_target` code-execution path?

### Answer

Pending. Test a secretless baseline on `pull_request`, then compare a
no-checkout privileged workflow, maintainer-approved dispatch, and GitHub App
for AI analysis and comments. Every fork must receive an explicit evaluated,
skipped, or pending status.

## scanner-runtime: Build Profile-Aware Deterministic Evaluation

Blocked by: execution-trust, evaluation-contract, profile-taxonomy
Status: open
Type: Prototype

### Question

How should scanners be selected, configured, gated, and normalized so that a
profile is portable without hiding tool failures or producing intolerable
noise?

### Answer

Pending. Implement one vertical slice before generalizing: immutable tool
version, safe checkout, deterministic configuration, explicit exit semantics,
normalized Evaluation Result, artifact retention, summary, and fixture-backed
tests. Use the slice to define the scanner adapter contract.

## ai-assurance: Turn AI Review Into Bounded Evidence

Blocked by: evaluation-contract, execution-trust, fork-pr-model
Status: open
Type: Prototype

### Question

How should context collection, threat modeling, review, validation,
prompt-injection handling, large diffs, refusals, privacy, and cost limits work
without treating model availability as correctness?

### Answer

Pending. Recommended pipeline: deterministic context pack, scoped threat model,
focused review, independent finding validation, and explicit incomplete
status. AI findings remain attributable evidence, not the sole basis for a
Filecoin-critical Merge Gate, until measured against a maintained corpus.

## evidence-interface: Give Humans And Automation One Result Surface

Blocked by: evaluation-contract, profile-taxonomy
Status: open
Type: Prototype

### Question

What should appear in the check summary, PR, Security tab, artifacts, and
machine-readable outputs, and how are results aggregated across nested jobs?

### Answer

Pending. Recommended interface: one profile-level conclusion, a matrix of
evaluation completion and findings, coverage gaps, stable artifact links, and
a versioned Evidence Bundle. PR comments should be optional and update one
sticky summary rather than letting tools compete for attention.

## documentation-system: Make Every User Journey Discoverable

Blocked by: product-contract
Status: resolved
Type: Research

### Question

How should documentation be organized, navigated, tested, and maintained so
that consumers can adopt and operate the platform while maintainers can extend
it without reverse-engineering workflows?

### Answer

Documentation is a first-class product surface, not a subsection of migration.
The durable architecture is recorded in
[DOCUMENTATION-ARCHITECTURE.md](DOCUMENTATION-ARCHITECTURE.md).

The README routes three named audiences: Consumer Engineer, Platform
Maintainer, and Rollout Operator. Documentation then uses progressive
disclosure: quickstart, profile selection, task guides, concepts, generated
reference, and maintainer/operator guidance. Examples are executable contract
fixtures, reference tables are generated from metadata, and documentation
agreement is required at every release gate.

## verification-system: Prove Safety And Detection Before Release

Blocked by: release-integrity, scanner-runtime, ai-assurance, evidence-interface, documentation-system
Status: open
Type: Prototype

### Question

Which tests and adversarial fixtures are required to demonstrate portability,
security, failure semantics, and useful detection for every release?

### Answer

Pending. Include malicious install hooks, token and OIDC probes, fork PRs,
missing secrets, tool outages, malformed SARIF, truncated diffs, prompt
injection, planted Filecoin bugs, monorepos, unsupported languages, noisy
findings, and upgrade/rollback. Define measurable recall, precision,
completion, runtime, and cost thresholds per profile.

## governance-model: Protect The Control Repository

Blocked by: distribution-model, release-integrity, evaluation-contract
Status: open
Type: Grilling

### Question

Who owns profiles, approves policy and prompt changes, handles vulnerabilities,
publishes releases, responds to broken consumers, and can perform emergency
rollback?

### Answer

Pending. Recommended minimum: CODEOWNERS for workflows, actions, prompts, and
profiles; required security review; SECURITY.md; signed immutable releases;
compatibility and deprecation policy; automated dependency updates; change
log; emergency revocation procedure; and named maintainers for each profile.

## consumer-migration: Make Adoption And Upgrades Boring

Blocked by: profile-taxonomy, evidence-interface, documentation-system, verification-system, governance-model
Status: open
Type: Prototype

### Question

How can a project discover its profile, install the correct pinned workflow,
start advisory, tighten gates, customize suppressions, upgrade, and roll back
without copying implementation?

### Answer

Pending. Prototype a profile-selection command or workflow generator that emits
a minimal consumer file and compatibility report. Rollout should progress from
observe, to critical-only gating, to profile policy, with an escape hatch that
is visible and time-bounded.

## ecosystem-rollout: Scale Adoption And Measure Effectiveness

Blocked by: consumer-migration, distribution-model, governance-model
Status: open
Type: Research

### Question

Which projects form the pilot cohorts, how will adoption be supported across
organizations, and which measures prove that the platform is improving
security rather than merely running more jobs?

### Answer

Pending. Use representative low-, medium-, and consensus-critical projects.
Track install and upgrade coverage, completion rate, time to triage, confirmed
finding rate, false-positive suppression, time to remediation, profile drift,
runtime, and cost. G4 requires recurring review with project maintainers and a
published coverage matrix.

## Implementation Sequence

The executable sequence is maintained in [`roadmap/state.json`](../roadmap/state.json)
and validated by `bash scripts/roadmap.sh validate`. At a phase level, work
follows this dependency order:

1. Complete the `known-blockers` remediation lane and enforce G0.
2. Build the immutable release and execution foundations.
3. Establish the audience router, documentation home, page contracts, and
   documentation-contract CI before expanding the public surface.
4. Implement the Evaluation Result contract and one vertical scanner slice.
5. Add Security Profiles and the shared evidence interface.
6. Bound and validate Privileged Analyses, including fork PR behavior.
7. Establish the verification and governance systems.
8. Pilot documented migration across representative projects.
9. Publish v1 only after G3 evidence is reviewed; scale only after pilot
   effectiveness is measured.

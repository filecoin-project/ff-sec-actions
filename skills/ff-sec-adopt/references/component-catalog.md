# Component Catalog For Context-Based Selection

This maps Consumer Project context to `ff-sec-actions` components. It
deliberately contains no commit SHAs or full input lists: copy those from the
Control Repository's `examples/` and `docs/workflows/<workflow>.md` at the time
of adoption.

## Components

| Component | Workflow / action | Authority | Runs project code? | Add when |
|---|---|---|---|---|
| Ecosystem Baseline | `ecosystem-baseline.yml` | `actions: read`, `contents: read` | No | Always. Covers workflow security (Zizmor), secrets (Gitleaks), dependency vulnerabilities (Trivy), IaC (Trivy), and ecosystem Semgrep rules, with one `Profile Conclusion`. |
| Profile detection | `actions/detect-filecoin-profile` | `contents: read` | No | Monorepos, any Filecoin-specific component, or when the team wants classification evidence and coverage gaps tracked over time. |
| Dependency Review | `sec-dependency-review.yml` | `contents: read`, `pull-requests: write` | No | Project takes PRs that change dependencies and wants new vulnerable or disallowed dependencies flagged on the PR. Needs GitHub's dependency graph. |
| License Compliance | `sec-licenses.yml` | `contents: read` | No | Project has a license policy or ships to users who need one. |
| SBOM Generation | `sec-sbom.yml` | `contents: read` | No | Project publishes releases, binaries, or containers and needs an inventory. |
| AI Code Review | `actions/ai-code-review` (examples) | `ANTHROPIC_API_KEY`; `pull-requests: write` | No (reads diff via API) | Team wants Filecoin-aware review on PRs and can provide the key. Skipped on fork PRs; use the manual variant for maintainer-triggered review of fork PRs. |
| Slither | `sec-slither.yml` | `security-events: write` | **Yes** (compiler, submodules) | Solidity/Foundry contracts, especially the `fevm-contract` profile. Ask first. |
| CodeQL | `sec-codeql.yml` | `security-events: write`; GitHub Code Security | **Yes** (autobuild) | Supported languages with GitHub Code Security available, and the team accepts build execution. Ask first. |
| OpenSSF Scorecard | `sec-scorecard.yml` | `security-events: write`, `id-token: write` | No | Public repository wanting supply-chain posture checks. Trigger on `push`/`schedule`/`workflow_dispatch`, not PRs. Ask first. |

Not for new adoption:

- `security-pipeline.yml`: legacy mixed-authority umbrella. Keep only for an
  existing consumer; prefer the baseline plus separate privileged workflows.
- `evaluation-pipeline.yml`: maintainer vertical slice, not a consumer product.
- `sec-actions`, `sec-secrets`, `sec-dependencies`, `sec-iac`, `sec-semgrep`:
  already inside the Ecosystem Baseline; adding them separately duplicates
  work and evidence.

## Profile To Component Map

Detector profile IDs come from `profiles/filecoin-project-profiles.json`.

| Detected profile | Add beyond the baseline | Notes |
|---|---|---|
| `go-node` (Lotus/Venus) | CodeQL (`["go"]`) if Code Security is available; AI review | Consensus-critical; human review remains required. No released Filecoin node rule pack yet. |
| `fvm-actor` (Rust/FVM) | AI review; SBOM if artifacts are published | CodeQL Rust support depends on the pinned CodeQL version; check the doc page before suggesting it. No actor-invariant evaluation released yet. |
| `fevm-contract` | Slither (`target` = contracts dir); AI review | Funds-moving code; human review remains required. Keep Slither off fork `pull_request` triggers. |
| Generic Solidity (detector gap) | Slither | Report as a coverage gap; classify manually only with the user. |
| `service` | Dependency Review; CodeQL (`javascript-typescript` or detected languages); AI review | Closest to current defaults. |
| `storage-application` | Dependency Review; AI review | Content-handling evaluations are planned, not released. |
| `infrastructure` | Baseline IaC covers Terraform/Kubernetes/Dockerfiles; Scorecard if public | Cloud-runtime policy is out of scope. |
| `storage-provider-infrastructure` | Same as infrastructure; prioritize enabling `secrets-blocking` after triage | Privileged API tokens and wallet keys are high impact. |
| No profile / unknown | Baseline only | Still recommend profile detection so the gap is visible. |

## Context Modifiers

| Context | Effect on selection |
|---|---|
| Public repository | Scorecard becomes reasonable. Fork PRs are likely: keep build-executing workflows off `pull_request`. |
| Private/internal repository | Requires org policy permitting public reusable workflows. Scorecard usually not useful. |
| Accepts fork PRs | AI review will be `skipped` on forks (no secret). Offer the manual AI review workflow. Never suggest `pull_request_target`. |
| No GitHub Code Security | Do not add CodeQL. SARIF stays as run artifacts. |
| GitHub Enterprise Server | Cannot call GitHub.com reusable workflows; stop and point to the distribution-model decision (mirroring required). |
| Existing `security-pipeline.yml` consumer | Propose migrating to the baseline plus separate privileged jobs; do not remove the old file without the user's agreement. |
| Many vendored/generated dirs | Extend `skip-dirs`; never skip first-party source to quiet findings. |

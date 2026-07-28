# System Research: GitHub Actions Execution Trust

## 1. System Overview

`ff-sec-actions` supplies reusable workflows and actions to independent
Filecoin Consumer Projects. GitHub-hosted runners inspect repository content,
may execute builds or package hooks, call third-party tools and services, and
publish findings through GitHub. The security objective is to keep untrusted
project content separate from secrets, write tokens, OIDC, and durable trust.

## 2. Architecture Map

- Consumer workflow: selects a control-repository ref, event, inputs, secrets,
  and the maximum `GITHUB_TOKEN` permission set.
- Control Repository: supplies reusable workflows, actions, prompts, rules, and
  examples.
- GitHub-hosted runner: downloads dependencies, checks out content, invokes
  scanners, and holds job-scoped credentials.
- Third-party supply chain: actions, containers, compiler/tool downloads,
  package registries, rule registries, and advisory databases.
- GitHub services: repository API, PR comments, code scanning, artifacts,
  caches, and OIDC.
- External providers: Anthropic, OpenSSF, and scanner-specific services.
- Evidence consumers: engineers, branch protection, Rollout Operators, and
  later aggregation policy.

## 3. Data Flow Traces

1. A Consumer Project event selects a consumer workflow and a control-repository
   ref.
2. GitHub grants each job a token and any explicitly mapped secrets.
3. The runner downloads actions or containers and may check out Consumer
   Project content.
4. An evaluator inspects files or executes build/install behavior.
5. Tools may query registries, advisory databases, GitHub, or an external
   provider.
6. Raw findings flow to job logs, artifacts, SARIF, comments, and outputs.
7. Humans or branch protection interpret job conclusions as policy.

## 4. Security Boundaries

- Untrusted contribution versus base-repository workflow authority.
- Consumer caller permission cap versus called/nested workflow permissions.
- Repository data inspection versus repository-controlled code execution.
- Reviewed control code versus third-party actions, containers, and downloads.
- Runner and source content versus external networks and analysis providers.
- Raw tool output versus normalized evidence and Merge Gate policy.
- Fork/low-trust events versus trusted push, schedule, dispatch, and caches.

## 5. System Security Assumptions

- GitHub-hosted runners are ephemeral; self-hosted runners are outside the
  supported execution boundary.
- Full commit SHAs are the immutable reference boundary for Actions code.
- `pull_request` from a fork normally lacks secrets and receives a reduced
  token, but repository settings can change token behavior.
- Scanner input is hostile data and scanner dependencies may be compromised.
- A green job is not evidence of complete evaluation until Completion Status is
  implemented.
- Current pre-v1 surfaces are not yet release-safe; `legacy-mixed` is an
  inventory state, not an approved tier.

## 6. Threat Actor Inventory

| Actor | Capability | Access | Motivation |
|---|---|---|---|
| External fork author | Controls PR files, metadata, history, submodule refs, and some workflow changes | Fork `pull_request` | Steal authority, poison results, disrupt CI |
| Same-repository contributor | Controls a branch and may receive repository secrets depending on policy | Branch/PR | Abuse automation or bypass evaluation |
| Malicious dependency maintainer | Controls package install hooks, releases, or build inputs | Registry/download | Runner execution, exfiltration, supply-chain compromise |
| Compromised action/container owner | Replaces mutable dependency content or compromises a pinned release upstream | Third-party distribution | Execute inside many consumer jobs |
| Compromised Control Repository maintainer | Changes reusable workflows, prompts, or moving refs | Control Repository write/release | Ecosystem-wide compromise |
| External provider or insider | Observes submitted code/metadata or manipulates returned evidence | Provider service | Data access, result manipulation |
| Misconfigured consumer administrator | Grants broad tokens, secrets, self-hosted runners, or unsafe triggers | Repository settings | Accidental exposure rather than malicious intent |

## 7. Attack Surface Areas

- Workflow triggers and caller permissions
- Checkout credentials, source trees, git history, and recursive submodules
- Package lifecycle hooks, CodeQL autobuild, compilers, and Slither
- Third-party action refs, nested reusable workflows, and container tags
- Secrets, `GITHUB_TOKEN`, OIDC, caches, artifacts, and SARIF upload
- Scanner registries, package registries, advisory databases, and AI providers
- Tool exit codes, malformed output, skipped jobs, and branch-protection checks

## 8. Open Questions

- What egress enforcement is required before private Consumer Project source is
  supported by the Ecosystem Baseline?
- Will evidence publication always be a separate job, or can a proven
  inspection-only tool retain narrowly scoped `security-events: write`?
- Which caches, if any, can cross from untrusted inspection/build jobs into
  trusted publishers?
- Which delivery model will enforce organization settings outside the workflow
  YAML itself?

# Execution Trust Architecture

## System Description

The system is a cross-organization GitHub Actions evaluation platform. A
Consumer Project chooses an event and a control-repository version. GitHub then
creates one or more ephemeral runners with job-scoped authority. Those runners
download reviewed and third-party code, inspect or execute repository content,
contact network services, and emit evidence that may affect merging.

The target separates inspection, code execution, external analysis, and
publication. Authority never flows backward from a publisher into a job that
processes or executes untrusted content.

## Architecture Diagram

```text
TB1: ==== Contribution / Base Repository Authority ====
 C1 Contributor --DF1 PR/event--> C2 Consumer Workflow
                                      |
TB2: ==== Caller / Reusable Permission Boundary =======
                                      | DF2 call + cap
                                      v
                         C3 Control Repository Release
                                      |
TB4: ==== Reviewed / Third-Party Supply Chain =========
                          DF3 actions, images, tools
                                      v
                             C4 Ephemeral Runner
                          /          |           \
TB3: Repository / Execution   TB5: Network     TB6: Evidence / Policy
 C1 --DF4 source/history--> C4 --DF5 queries--> C5 Third Parties
                               --DF6 API-------> C6 GitHub Services
                               --DF7 source----> C7 External Provider
                               --DF8 results--------------------> C8 Consumers

TB7: ==== Fork/Low-Trust Event / Trusted Event & Cache ====
     fork pull_request, push, schedule, dispatch, workflow_run
```

## Component Inventory

| ID | Component | Owner | Description |
|---|---|---|---|
| C1 | Contributor and repository content | Consumer Project contributors | PR metadata, files, git history, manifests, configs, submodules, and build behavior; assumed hostile on PRs |
| C2 | Consumer workflow and settings | Consumer Project maintainers | Selects events, permissions, secrets, runners, inputs, and control-repository version |
| C3 | Control Repository release | Platform Maintainers | Reusable workflows, composite actions, prompts, rules, schemas, and examples |
| C4 | Ephemeral runner | GitHub | Downloads dependencies and performs inspection, builds, network calls, and evidence generation |
| C5 | Third-party supply chain | External maintainers | Actions, containers, compilers, packages, rule registries, and vulnerability databases |
| C6 | GitHub services | GitHub/Consumer Project | Repository API, token, PRs, Security tab, artifacts, caches, and OIDC |
| C7 | External analysis providers | Provider and Platform Maintainers | Receives scoped source/metadata and returns results; currently Anthropic and OpenSSF publishing |
| C8 | Evidence and policy consumers | Consumer Engineers/Rollout Operators | Job summaries, artifacts, SARIF, comments, required checks, and future Merge Gate |

## Data Flow Inventory

| ID | From | To | Data | Protocol | Auth |
|---|---|---|---|---|---|
| DF1 | C1 | C2 | Event, PR metadata, repository ref | GitHub event | GitHub identity |
| DF2 | C2 | C3 | Workflow ref, inputs, permission cap, mapped secrets | `workflow_call`/Actions download | GitHub |
| DF3 | C3 | C4/C5 | Workflow, action, container, tool, prompt, rule | Git/OCI/HTTPS | Usually public; SHA/digest integrity expected |
| DF4 | C1 | C4 | Files, history, submodules, configs, build behavior | Git checkout/API | Job token or public access |
| DF5 | C4 | C5 | Package/tool requests and vulnerability/rule queries | HTTPS | Varies |
| DF6 | C4 | C6 | Checkout, comments, SARIF, artifacts, OIDC, cache | GitHub APIs | Job token/OIDC/runtime token |
| DF7 | C4 | C7 | PR metadata, source diff, evidence | HTTPS | Provider credential or OIDC |
| DF8 | C4/C6/C7 | C8 | Raw and normalized findings, completion, check conclusion | GitHub UI/API/artifacts | Repository authorization |

## Trust Boundaries

TB1: ==== Contribution / Base Repository Authority ====
Untrusted authors control PR data but must not control secrets, write tokens, or
the trusted workflow definition. Failure permits repository takeover.

TB2: ==== Caller / Reusable Permission Boundary ====
Nested workflows cannot receive more authority than the caller grants, but a
broad cap or missing job permissions can expose unnecessary authority.

TB3: ==== Repository Data / Code Execution ====
Parsers should treat repository files as data. Install hooks, autobuild,
compilers, local scripts, and submodule tooling cross into hostile execution.

TB4: ==== Reviewed / Third-Party Supply Chain ====
Every action, nested workflow, container, compiler, prompt, and rule becomes
trusted code or policy inside the job. Mutable references defeat review.

TB5: ==== Runner / External Network ====
Outbound calls may reveal source, metadata, credentials, or findings and may
return malicious dependencies or manipulated evidence.

TB6: ==== Tool Evidence / Merge Policy ====
Tool output, absence of output, and operational failure are not themselves an
authoritative Merge Gate conclusion.

TB7: ==== Fork/Low-Trust / Trusted Events and Shared State ====
Secrets, write tokens, trusted caches, and publisher jobs must not become
reachable from untrusted fork content or artifacts.

## Entry Points

| ID | Entry Point | Trust Level | Notes |
|---|---|---|---|
| EP1 | `pull_request` files and metadata | Untrusted | Primary ecosystem contribution path |
| EP2 | `push`, `schedule`, `workflow_dispatch` | Trusted repository ref, varying operator trust | May enable privileged analyses |
| EP3 | Reusable workflow inputs and secrets | Consumer-maintainer controlled | Inputs select scanners, paths, models, and gates |
| EP4 | Repository scanner configuration | Untrusted on PRs | `.semgrep.yml`, `.trivyignore`, Gitleaks and Slither configs |
| EP5 | Package manifests and lifecycle hooks | Untrusted on PRs | Installation crosses TB3 |
| EP6 | Git submodules | External/untrusted | Recursive checkout adds another origin |
| EP7 | Third-party releases and registries | External | Actions, images, tools, rules, packages, advisories |
| EP8 | Scanner/provider output and artifacts | External/untrusted evidence | Must be validated before policy |

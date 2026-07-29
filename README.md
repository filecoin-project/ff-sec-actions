# Filecoin Ecosystem Security Actions

`ff-sec-actions` is the shared security-evaluation platform for Filecoin
projects. It centralizes reusable GitHub workflows, composite actions,
Filecoin-aware review guidance, and the policy needed to interpret their
results.

The platform produces security evidence. It does not certify that a project is
secure, and a green workflow only has meaning when every enabled evaluation
completed its declared scope.

> **Project status: pre-v1.** The repository is being hardened for ecosystem
> use. There is not yet a stable release. The scanner example now pins a
> transitively immutable execution graph, but use it only in pilot or sandbox
> repositories while the post-G0 evaluation, governance, and release gates are
> completed.

## Where Do You Want To Go?

### Use It In A Project

Start with the [Consumer quickstart](docs/consumers/quickstart.md) to choose a
workflow, understand its authority, and interpret the first result.

- [Choose a security profile](docs/consumers/choose-a-profile.md)
- [Understand results and merge gates](docs/consumers/understand-results.md)
- [Configure permissions and secrets](docs/consumers/permissions-and-secrets.md)

### Change Or Extend The Platform

Start with the [Platform Maintainer guide](docs/maintainers/README.md) before
changing an action, workflow, prompt, profile, schema, or release reference.

### Roll It Out Across Projects

Start with the [Rollout Operator guide](docs/operators/README.md) for pilot
selection, policy, exceptions, health, and rollback.

### Browse Everything

The [documentation home](docs/README.md) is the complete navigation index.

The [machine-readable implementation roadmap](roadmap/README.md) shows the
dependency-ordered work queue and the commands used to claim and complete work.

## What Exists Today?

| Capability | Surface | Current status |
|---|---|---|
| Filecoin-aware AI PR review | Composite action and reusable workflow | Pilot; requires an Anthropic key |
| GitHub Actions security, Semgrep, CodeQL, Trivy, Gitleaks, dependency review, SBOM, Scorecard, Slither | Reusable workflows | Pilot; scanner behavior varies |
| Combined scanner suite | Umbrella reusable workflow | Pilot; transitively immutable at the example commit |
| Filecoin review invariants | Versioned prompts | Available to AI review |
| Ecosystem Security Profiles | Planned profile layer | Not yet released |
| Normalized Evaluation Result | Scanner and AI action outputs | Stable `1.0.0` schema; aggregation is next |

See the [decision map](docs/ECOSYSTEM-SECURITY-DECISION-MAP.md) for release
gates and active design work.

## Repository Map

```text
.github/workflows/       reusable workflows and repository CI
actions/                 composite actions and their implementation
docs/                    consumer, maintainer, operator, and reference guides
examples/                executable consumer workflow examples
prompts/                 shared and Filecoin-specific AI review guidance
scripts/                 local tooling and documentation checks
roadmap/                 canonical machine-readable implementation state
```

## Trust Boundaries

- The AI code-review action reads PR metadata and diffs through the GitHub API;
  it does not checkout or execute PR code.
- Scanner workflows checkout Consumer Project content. Baseline scanners do
  not execute project code; opt-in CodeQL and Slither may build or analyze
  project-controlled behavior. Review
  [permissions and secrets](docs/consumers/permissions-and-secrets.md) before
  enabling them on untrusted PRs.
- Third-party GitHub actions and containers are immutable in the published
  graph. A consumer upgrades or rolls back by changing one reviewed commit.
- Fork PRs do not receive repository or organization secrets.

Do not put suspected vulnerability details or secrets in a public issue. A
formal private reporting route, `SECURITY.md`, and ownership policy are required
before public v1.

# Ecosystem Baseline

**Workflow:** `ecosystem-baseline.yml`<br>
**Status:** consumer-testable pre-v1 alpha<br>
**Introduced:** commit `35cf1a2133cbff03d9cc3039b532f0f4737af9ae`<br>
**Owner:** Filecoin ecosystem security platform maintainers<br>
**Use when:** a project needs the recommended secretless starting point with normalized evidence and one Profile Conclusion.

## Authority And Execution

| Concern | Contract |
|---|---|
| Permissions | Caller cap: `actions: read`, `contents: read` |
| Secrets and writes | None |
| Consumer code execution | Forbidden; scanners inspect repository data only |
| Network | GitHub action/artifact downloads plus scanner databases and verified tool releases |
| Events and forks | Caller-controlled pull request, push, schedule, or manual contexts; fork PRs are supported without secrets |

## Inputs

**Declared secrets:** none

| Input | Default | Purpose |
|---|---:|---|
| `actions-security-blocking` | `false` | Gate Zizmor findings |
| `dependency-blocking` | `false` | Gate dependency findings |
| `secrets-blocking` | `false` | Gate Gitleaks findings |
| `iac-blocking` | `false` | Gate IaC findings |
| `static-analysis-blocking` | `false` | Gate Semgrep findings |
| `require-complete` | `true` | Fail when a required evaluation is missing or incomplete |
| `skip-dirs` | `node_modules,vendor,target,dist` | Comma-separated scanner exclusions |

## Outputs And Evidence

**Declared workflow outputs:** none

The workflow exposes no `workflow_call` outputs. Each evaluation publishes its normalized result and raw evidence. `ecosystem-baseline-evidence` contains `evidence-bundle.json` and `evidence-summary.md`; the job summary renders the Profile Conclusion. Artifacts use the Consumer Project's configured GitHub Actions retention unless a child workflow documents an override.

## Completion And Gating

Five required evaluations—`zizmor-actions`, `trivy-dependencies`, `gitleaks`, `trivy-iac`, and `semgrep-baseline`—must be represented. Finding gates are independently configurable. `require-complete=true` fails closed on missing, skipped, incomplete, or errored results.

## Immutable Usage

```yaml
name: Filecoin ecosystem security baseline

on:
  pull_request:

jobs:
  baseline:
    permissions:
      actions: read
      contents: read
    uses: filecoin-project/ff-sec-actions/.github/workflows/ecosystem-baseline.yml@c95d54087ff3a4783aea814776243990d9778c93
```

## Limitations

This profile does not run builds, package installation, runtime tests, Filecoin protocol invariants, or privileged publication. Manifest-only evidence can be incomplete when dependencies appear only after installation or build generation.

## Compatibility

This is a pre-v1 alpha contract with no deprecated inputs. Changing required evaluation IDs, evidence filenames, inputs, or gate semantics requires migration guidance and a new reviewed immutable pin.

## Source

- [Workflow source](../../.github/workflows/ecosystem-baseline.yml)
- [Adoption guide](../consumers/ecosystem-baseline.md)
- [Evidence Bundle contract](../reference/evidence-bundle.md)
